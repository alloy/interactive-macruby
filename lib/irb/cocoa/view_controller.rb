require 'irb'
require 'irb/driver'

module IRB
  class CocoaFormatter < Formatter
    def result(object)
      inspect_object(object)
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
  
  def initWithObject(object, binding: binding)
    if init
      @rows = []
      
      @resultCell = NSTextFieldCell.alloc.init
      @resultCell.editable = false
      
      @inputCell = NSTextFieldCell.alloc.init
      @inputCell.editable = true
      @inputCell.bordered = false
      @inputCell.focusRingType = NSFocusRingTypeNone
      
      setupContextForObject(object, binding: binding)
      performSelector('editInputCell', withObject: nil, afterDelay: 0)
      
      self
    end
  end
  
  def loadView
    self.view = IRBView.alloc.initWithViewController(self)
  end
  
  def receivedOutput(output)
    addRowWithPrompt(IRB::Formatter::RESULT_PREFIX, value: output)
    view.outlineView.reloadData
    editInputCell
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
    @thread[:input] = input
  end
  
  # outline view delegate methods
  
  def outlineView(outlineView, dataCellForTableColumn: column, item: item)
    if column
      if item == :input
        @inputCell
      else
        @resultCell
      end
    end
  end
  
  private
  
  def setupContextForObject(object, binding: binding)
    @context = IRB::Context.new(object, binding)
    @context.formatter = IRB::CocoaFormatter.new
    @output = Output.new(self)
    
    @thread = Thread.new(self, @context) do |controller, context|
      IRB::Driver.current = controller
      
      loop do
        if input = Thread.current[:input]
          Thread.current[:input] = nil
          context.process_line(input)
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
  end
  
  private :irb
end