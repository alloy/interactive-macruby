require 'irb_ext'
require 'node'

class IRBViewController < NSViewController
  include IRB::Cocoa::Helper
  include IRB::Cocoa
  
  PROMPT = "prompt"
  VALUE  = "value"
  EMPTY  = Helper.attributedString("")
  
  attr_reader :output
  
  def initWithObject(object, binding: binding, delegate: delegate)
    if init
      @rows = []
      @delegate = delegate
      
      @history = []
      @currentHistoryIndex = 0
      
      @colorizationFormatter = IRB::Cocoa::ColoredFormatter.new
      setupIRBForObject(object, binding: binding)
      
      setupDataCells
      
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
    @rows << ObjectNode.nodeForObject(result)
    p @rows.last
    updateOutlineView
  end
  
  def receivedException(exception)
    string = @colorizationFormatter.exception(exception)
    @rows << BasicNode.alloc.initWithvalue(string)
    updateOutlineView
  end
  
  def receivedOutput(output)
    @rows << BasicNode.alloc.initWithvalue(output)
    updateOutlineView
  end
  
  def terminate
    @delegate.send(:irbViewControllerTerminated, self)
  end
  
  # delegate methods of the input cell
  
  def control(control, textView: textView, completions: completions, forPartialWordRange: range, indexOfSelectedItem: item)
    @completion.call(textView.string).map { |s| s[range.location..-1] }
  end
  
  def control(control, textView: textView, doCommandBySelector: selector)
    # p selector
    case selector
    when :"insertTab:"
      textView.complete(self)
    when :"moveUp:"
      if @currentHistoryIndex > 0
        @currentHistoryIndex -= 1
        textView.string = @history[@currentHistoryIndex]
      else
        NSBeep()
      end
    when :"moveDown:"
      if @currentHistoryIndex < @history.size
        @currentHistoryIndex += 1
        line = @history[@currentHistoryIndex]
        textView.string = line ? line : EMPTY
      else
        NSBeep()
      end
    else
      return false
    end
    true
  end
  
  # outline view data source and delegate methods
  
  def outlineView(outlineView, numberOfChildrenOfItem: item)
    #puts 'count' #, item, ''
    if item == nil
      # add one extra which is the input row
      @rows.size + 1
    else
      item.children.size
    end
  end
  
  def outlineView(outlineView, isItemExpandable: item)
    #puts 'expandable' #, item, ''
    case item
    when BasicNode
      item.expandable?
    end
  end
  
  def outlineView(outlineView, child: index, ofItem: item)
    #puts 'child' #, item, ''
    if item == nil
      if index == @rows.size
        :input
      else
        @rows[index]
      end
    else
      item.children[index]
    end
  end
  
  def outlineView(outlineView, objectValueForTableColumn: column, byItem: item)
    #puts 'objectValue' #, item, ''
    result = case item
    when :input
      column.identifier == PROMPT ? @context.prompt : EMPTY
    when BasicNode
      column.identifier == PROMPT ? item.prefix : item.value
    end
    
    # make sure the prompt column is still wide enough
    if result && column.identifier == PROMPT
      width = result.size.width + view.outlineView.indentationPerLevel + 10
      column.width = width if width > column.width
    end
    
    result #|| EMPTY
  end
  
  def outlineView(outlineView, setObjectValue: input, forTableColumn: column, byItem: item)
    @rows << BasicNode.alloc.initWithPrefix(@context.prompt, value: input)
    processInput(input)
  end
  
  def outlineView(outlineView, dataCellForTableColumn: column, item: item)
    #puts 'dataCell' #, item, ''
    if column
      if item == :input
        column.identifier == VALUE ? @inputCell : @dataCells[NSTextFieldCell]
      else
        @dataCells[item.dataCellTypeForColumn(column.identifier)]
      end
    end
  end
  
  private
  
  def addToHistory(line)
    @history << line
    @currentHistoryIndex = @history.size
  end
  
  def processInput(input)
    addToHistory(input)
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
  
  def setupDataCells
    font = IRB::Cocoa::DEFAULT_ATTRIBUTES[NSFontAttributeName]
    
    textCell = NSTextFieldCell.alloc.init
    textCell.font = font
    # textCell.selectable = true
    textCell.editable = false

    imageCell = NSImageCell.alloc.init
    imageCell.imageAlignment = NSImageAlignLeft

    @dataCells = { NSTextFieldCell => textCell, NSImageCell => imageCell }

    @inputCell = NSTextFieldCell.alloc.init
    @inputCell.font = font
    @inputCell.editable = true
    @inputCell.bordered = false
    @inputCell.focusRingType = NSFocusRingTypeNone
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
end

module Kernel
  def irb(object, binding = nil)
    controller = IRBWindowController.alloc.initWithObject(object, binding: binding)
    controller.showWindow(self)
    nil
  end
  
  private :irb
end
