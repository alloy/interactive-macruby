require 'irb'
require 'irb/driver'

module IRB
  class CocoaFormatter < Formatter
    def result(object)
      inspect_object(object)
    end
  end
  
  module Driver
    class Cocoa
      class Output
        def initialize(viewController)
          @controller = viewController
        end
        
        def write(string)
          @controller.performSelectorOnMainThread("receivedOutput:", withObject: string, waitUntilDone: false)
        end
      end
      
      attr_reader :output
      
      def initialize(viewController)
        @controller = viewController
        @output = Output.new(viewController)
      end
    end
  end
end

$stdout = IRB::Driver::OutputRedirector.new

class IRBViewController < NSViewController
  def initWithObject(object, binding: binding)
    if init
      @rows = []
      
      @resultCell = NSTextFieldCell.alloc.init
      @resultCell.editable = false
      @inputCell = NSTextFieldCell.alloc.init
      @inputCell.editable = true
      
      setupContextForObject(object, binding: binding)
      
      self
    end
  end
  
  def loadView
    self.view = IRBView.alloc.initWithViewController(self)
  end
  
  def receivedOutput(output)
    @rows << { "prompt" => rightAlignedString("=>"), "result" => output }
    view.outlineView.reloadData
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
      if column.identifier == "prompt"
        rightAlignedString(@context.prompt)
      else
        ""
      end
    elsif item
      item[column.identifier]
    end
  end
  
  def outlineView(outlineView, setObjectValue: input, forTableColumn: column, byItem: item)
    @rows << { "prompt" => rightAlignedString(@context.prompt), "result" => input }
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
    @driver = IRB::Driver::Cocoa.new(self)
    
    @thread = Thread.new do
      IRB::Driver.current = @driver
      Thread.current[:running] = false
      loop do
        if input = Thread.current[:input]
          Thread.current[:input] = nil
          Thread.current[:running] = true
          @context.process_line(input)
          Thread.current[:running] = false
        end
      end
    end
  end
  
  def rightAlignedString(string)
    attributedString = NSMutableAttributedString.alloc.initWithString(string)
    attributedString.setAlignment(NSRightTextAlignment, range:NSMakeRange(0, string.size))
    attributedString
  end
end