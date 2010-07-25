require 'irb_ext'

class IRBViewController < NSViewController
  DEFAULT_ATTRIBUTES = { NSFontAttributeName => NSFont.fontWithName("Menlo Regular", size: 11) }
  
  PROMPT = "prompt"
  VALUE  = "value"
  EMPTY  = ""
  
  attr_reader :output
  
  def initWithObject(object, binding: binding, delegate: delegate)
    if init
      @rows = []
      @delegate = delegate
      
      @colorizationFormatter = IRB::Cocoa::ColoredFormatter.new
      setupIRBForObject(object, binding: binding)
      
      font = DEFAULT_ATTRIBUTES[NSFontAttributeName]
      
      @resultCell = NSTextFieldCell.alloc.init
      @resultCell.font = font
      @resultCell.editable = false
      
      @inputCell = NSTextFieldCell.alloc.init
      @inputCell.font = font
      @inputCell.editable = true
      @inputCell.bordered = false
      @inputCell.focusRingType = NSFocusRingTypeNone
      
      # TODO is this the best way to make the input cell become key?
      performSelector('editInputCell', withObject: nil, afterDelay: 0)
      
      self
    end
  end
  
  def loadView
    self.view = IRBView.alloc.initWithViewController(self)
  end
  
  # context callback methods
  
  def needsMoreInput
    updateOutlineView
  end
  
  def receivedResult(result)
    colorizedResultValue = @colorizationFormatter.result(result)
    addRowWithPrompt(IRB::Formatter::RESULT_PREFIX, value: colorizedResultValue)
    updateOutlineView
  end
  
  def receivedException(exception)
    addRowWithPrompt(EMPTY, value: @colorizationFormatter.exception(exception))
    updateOutlineView
  end
  
  def receivedOutput(output)
    addRowWithPrompt(EMPTY, value: output)
    updateOutlineView
  end
  
  def terminate
    @delegate.send(:irbViewControllerTerminated, self)
  end
  
  # delegate method of the current input cell
  
  def control(control, textView: textView, completions: completions, forPartialWordRange: range, indexOfSelectedItem: item)
    @completion.call(textView.string).map { |s| s[range.location..-1] }
  end
  
  # outline view data source and delegate methods
  
  def outlineView(outlineView, numberOfChildrenOfItem: item)
    if item == nil
      # add one extra which is the input row
      @rows.size + 1
    end
  end
  
  def outlineView(outlineView, isItemExpandable: item)
    false
  end
  
  def outlineView(outlineView, child: index, ofItem: item)
    if item == nil
      if index == @rows.size
        :input
      else
        @rows[index]
      end
    end
  end
  
  def outlineView(outlineView, objectValueForTableColumn: column, byItem: item)
    result = if item == :input
      if column.identifier == PROMPT
        rightAlignedString(@context.prompt)
      else
        ""
      end
    elsif item
      item[column.identifier]
    end
    # make sure the prompt column is still wide enough
    if column.identifier == PROMPT
      width = result.size.width
      column.width = width if width > column.width
    end
    result
  end
  
  def outlineView(outlineView, setObjectValue: input, forTableColumn: column, byItem: item)
    addRowWithPrompt(@context.prompt, value: input)
    processInput(input)
  end
  
  def outlineView(outlineView, dataCellForTableColumn: column, item: item)
    if column
      if item == :input && column.identifier == VALUE
        @inputCell
      else
        @resultCell
      end
    end
  end
  
  private
  
  def processInput(input)
    @thread[:input] = input
    @thread.run
  end
  
  def setupIRBForObject(object, binding: binding)
    @context = IRB::Cocoa::Context.new(self, object, binding)
    @output = IRB::Cocoa::Output.new(self)
    @completion = IRB::Completion.new(@context)
    
    @thread = Thread.new(self, @context) do |controller, context|
      IRB::Driver.current = controller
      Thread.stop # stop now, there's no input yet
      
      loop do
        if input = Thread.current[:input]
          Thread.current[:input] = nil
          unless context.process_line(input)
            controller.performSelectorOnMainThread("terminate",
                                        withObject: nil,
                                     waitUntilDone: false)
          end
          Thread.stop # done processing, stop and await new input
        end
      end
    end
  end
  
  def updateOutlineView
    view.outlineView.reloadData
    editInputCell
  end
  
  def editInputCell
    if @registered.nil? && window = view.window
      @registered = true
      NSNotificationCenter.defaultCenter.addObserver(self,
                                           selector: 'editInputCell',
                                               name: NSWindowDidBecomeKeyNotification,
                                             object: window)
    end
    view.outlineView.editColumn(1, row: @rows.size, withEvent: nil, select: false)
  end
  
  # TODO create immutable versions
  def rightAlignedString(string)
    attributedString = NSMutableAttributedString.alloc.initWithString(string, attributes: DEFAULT_ATTRIBUTES)
    attributedString.setAlignment(NSRightTextAlignment, range:NSMakeRange(0, string.size))
    attributedString
  end
  
  def addRowWithPrompt(prompt, value: value)
    @rows << { PROMPT => rightAlignedString(prompt), VALUE => value }
  end
end

module Kernel
  def irb(object, binding = nil)
    controller = IRBWindowController.alloc.initWithObject(object, binding: binding)
    controller.showWindow(self)
    nil
  end
  
  private :irb
end