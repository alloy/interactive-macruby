require 'irb_ext'

module IRB
  module Cocoa
    DEFAULT_ATTRIBUTES = { NSFontAttributeName => NSFont.fontWithName("Menlo Regular", size: 11) }
    
    module Helper
      def attributedString(string)
        NSAttributedString.alloc.initWithString(string, attributes: DEFAULT_ATTRIBUTES)
      end
      module_function :attributedString
    end
    
    class BasicNode
      include Helper
      
      EMPTY_STRING = Helper.attributedString("")
      EMPTY_ARRAY = []
      
      attr_reader :string
      
      def initWithStringRepresentation(string)
        if init
          @string = string
          self
        end
      end
      
      def prompt
        EMPTY_STRING
      end
      
      def expandable?
        false
      end
      
      def children
        EMPTY_ARRAY
      end
    end
    
    class RowNode < BasicNode
      def initWithPrompt(prompt, stringRepresentation: string)
        if initWithStringRepresentation(string)
          @prompt = attributedString(prompt)
          self
        end
      end
      
      def prompt
        @prompt
      end
    end
    
    class ExpandableNode < BasicNode
      def initWithObject(object, stringRepresentation: string)
        if initWithStringRepresentation(string)
          @object = object
          self
        end
      end
      
      def expandable?
        true
      end
    end
    
    class ListNode < ExpandableNode
      def children
        @children ||= @object.map do |x|
          BasicNode.alloc.initWithStringRepresentation(attributedString(x))
        end
      end
    end
    
    class BlockListNode < ExpandableNode
      def initWithBlockAndStringRepresentation(string, &block)
        if initWithStringRepresentation(string)
          @block = block
          self
        end
      end
      
      def children
        @children ||= @block.call
      end
    end
    
    class ResultNode < ExpandableNode
      def children
        @children ||= [
          classDescriptionNode,
          methodsDescriptionNode,
          instanceVariablesNode,
        ].compact
      end
      
      def classDescriptionNode
        string = attributedString("Class: #{@object.class.name}")
        BasicNode.alloc.initWithStringRepresentation(string)
      end
      
      def methodsDescriptionNode
        methods = @object.methods(false)
        unless methods.empty?
          string = attributedString("Methods")
          ListNode.alloc.initWithObject(methods, stringRepresentation: string)
        end
      end
      
      def instanceVariablesNode
        variables = @object.instance_variables
        unless variables.empty?
          string = attributedString("Instance variables")
          BlockListNode.alloc.initWithBlockAndStringRepresentation(string) do
            variables.map do |variable|
              ResultNode.alloc.initWithObject(@object.instance_variable_get(variable),
                        stringRepresentation: attributedString(variable))
            end
          end
        end
      end
    end
  end
end

class IRBViewController < NSViewController
  include IRB::Cocoa::Helper
  
  PROMPT = "prompt"
  VALUE  = "value"
  EMPTY  = ""
  
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
    @rows << IRB::Cocoa::ResultNode.alloc.initWithObject(result,
                                   stringRepresentation: @colorizationFormatter.result(result))
    updateOutlineView
  end
  
  def receivedException(exception)
    string = @colorizationFormatter.exception(exception)
    @rows << IRB::Cocoa::RowNode.alloc.initWithStringRepresentation(string)
    updateOutlineView
  end
  
  def receivedOutput(output)
    @rows << IRB::Cocoa::RowNode.alloc.initWithStringRepresentation(output)
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
    if item == nil
      # add one extra which is the input row
      @rows.size + 1
    else
      item.children.size
    end
  end
  
  def outlineView(outlineView, isItemExpandable: item)
    case item
    when IRB::Cocoa::BasicNode
      item.expandable?
    end
  end
  
  def outlineView(outlineView, child: index, ofItem: item)
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
    result = case item
    when :input
      column.identifier == PROMPT ? attributedString(@context.prompt) : EMPTY
    when IRB::Cocoa::BasicNode
      column.identifier == PROMPT ? item.prompt : item.string
    end
    
    # make sure the prompt column is still wide enough
    if result && column.identifier == PROMPT
      width = result.size.width
      column.width = width if width > column.width
    end
    
    result || EMPTY
  end
  
  def outlineView(outlineView, setObjectValue: input, forTableColumn: column, byItem: item)
    @rows << IRB::Cocoa::RowNode.alloc.initWithPrompt(@context.prompt,
                                stringRepresentation: input)
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
    
    @resultCell = NSTextFieldCell.alloc.init
    @resultCell.font = font
    # @resultCell.selectable = true
    @resultCell.editable = false
    
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