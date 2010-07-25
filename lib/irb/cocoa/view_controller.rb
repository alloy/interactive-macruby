require 'irb'
require 'irb/driver'
require 'irb/ext/completion'
require 'irb/ext/colorize'

module IRB
  # class CocoaFormatter < ColoredFormatter
  #   def result(object)
  #     string = inspect_object(object)
  #     attributedString = NSMutableAttributedString.alloc.initWithString(string)
  #     # p attributedString
  #     attributedString.addAttributes({ NSForegroundColorAttributeName => NSColor.redColor }, range: NSMakeRange(0, string.size))
  #     attributedString
  #   end
  # end
  
  class CocoaFormatter < Formatter
    def result(object)
      inspect_object(object)
    end
  end
  
  class CocoaColoredFormatter < ColoredFormatter
    def colorize_token(type, token)
      if color = color(type)
        "#{Color.escape(color)}#{token}#{Color::CLEAR}"
      else
        token
      end
    end
  end
end

module IRB
  class Completion
    def initialize(context = nil)
      @context = context
    end
    
    def context
      @context || IRB::Driver.current.context
    end
  end
end

$stdout = IRB::Driver::OutputRedirector.new

class IRBViewController < NSViewController
  class Output
    NEW_LINE = "\n"
    
    def initialize(viewController)
      @controller = viewController
    end
    
    def write(string)
      unless string == NEW_LINE
        @controller.performSelectorOnMainThread("receivedOutput:",
                                    withObject: string,
                                 waitUntilDone: false)
      end
    end
  end
  
  PROMPT = "prompt"
  VALUE  = "value"
  
  attr_reader :output
  
  def initWithObject(object, binding: binding, delegate: delegate)
    if init
      @rows = []
      @delegate = delegate
      
      @colorizationFormatter = IRB::CocoaColoredFormatter.new
      setupIRBForObject(object, binding: binding)
      
      @resultCell = NSTextFieldCell.alloc.init
      @resultCell.editable = false
      
      @inputCell = NSTextFieldCell.alloc.init
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
  
  def colorize(string)
    p @colorizationFormatter.colorize(string)
    attributedString = NSMutableAttributedString.alloc.initWithString(string)
    attributedString.addAttributes({ NSForegroundColorAttributeName => NSColor.redColor }, range: NSMakeRange(0, string.size))
    attributedString
  end
  
  def receivedOutput(output)
    addRowWithPrompt(IRB::Formatter::RESULT_PREFIX, value: colorize(output))
    view.outlineView.reloadData
    editInputCell
  end
  
  def terminate
    @delegate.send(:irbViewControllerTerminated, self)
  end
  
  def control(control, textView: textView, completions: completions, forPartialWordRange: range, indexOfSelectedItem: item)
    @completion.call(textView.string).map { |s| s[range.location..-1] }
  end
  
  # outline view data source methods
  
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
    if item == :input
      if column.identifier == PROMPT
        rightAlignedString(@context.prompt)
      else
        ""
      end
    elsif item
      item[column.identifier]
    end
  end
  
  def outlineView(outlineView, setObjectValue: input, forTableColumn: column, byItem: item)
    addRowWithPrompt(@context.prompt, value: input)
    processInput(input)
  end
  
  # outline view delegate methods
  
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
    @context = IRB::Context.new(object, binding)
    @context.formatter = IRB::CocoaFormatter.new
    @output = Output.new(self)
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
  
  def rightAlignedString(string)
    attributedString = NSMutableAttributedString.alloc.initWithString(string)
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