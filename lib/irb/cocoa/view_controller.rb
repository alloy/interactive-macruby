require 'irb_ext'

module IRB
  module Cocoa
    class BasicNode
      EMPTY_ARRAY = []
      
      attr_reader :string
      
      def initWithStringRepresentation(string)
        if init
          @string = string
          self
        end
      end
      
      def expandable?
        false
      end
      
      def children
        EMPTY_ARRAY
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
      
      private
      
      def attributedString(string)
        NSAttributedString.alloc.initWithString(string, attributes: IRBViewController::DEFAULT_ATTRIBUTES)
      end
    end
    
    class ListNode < ExpandableNode
      def children
        @children ||= @object.map do |x|
          BasicNode.alloc.initWithStringRepresentation(attributedString(x))
        end
      end
    end
    
    class ResultNode < ExpandableNode
      def children
        @children ||= [
          classDescriptionNode,
          methodsDescriptionNode,
        ]
      end
      
      def classDescriptionNode
        string = attributedString("Class: #{@object.class.name}")
        BasicNode.alloc.initWithStringRepresentation(string)
      end
      
      def methodsDescriptionNode
        string = attributedString("Methods")
        ListNode.alloc.initWithObject(@object.public_methods(false), stringRepresentation: string)
      end
    end
  end
end

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
    string = @colorizationFormatter.result(result)
    value = IRB::Cocoa::ResultNode.alloc.initWithObject(result, stringRepresentation: string)
    addRowWithPrompt(EMPTY, value: value)
    updateOutlineView
  end
  
  def receivedException(exception)
    addRowWithPrompt(EMPTY, value: @colorizationFormatter.exception(exception))
    updateOutlineView
  end
  
  def receivedOutput(output)
    value = IRB::Cocoa::BasicNode.alloc.initWithStringRepresentation(output)
    addRowWithPrompt(EMPTY, value: value)
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
    # p item
    if item == nil
      # add one extra which is the input row
      @rows.size + 1
    else
      item.children.size
    end
  end
  
  def outlineView(outlineView, isItemExpandable: item)
    # p item
    case item
    when IRB::Cocoa::BasicNode
      item.expandable?
    end
  end
  
  def outlineView(outlineView, child: index, ofItem: item)
    # p item
    if item == nil
      if index == @rows.size
        :input
      elsif item.is_a?(Hash)
        item[VALUE]
      else
        @rows[index]
      end
    else
      item.children[index]
    end
  end
  
  def outlineView(outlineView, objectValueForTableColumn: column, byItem: item)
    # p item
    # result = case item
    # when nil then nil
    # when :input
    #   rightAlignedString(@context.prompt) if column.identifier == PROMPT
    #   
    # when IRB::Cocoa::BasicNode
    #   item.string if column.identifier == VALUE
    #   
    # else
    #   value = item[column.identifier]
    #   column.identifier == PROMPT ? value : value.string
    # end
    
    if item
      result = if column.identifier == PROMPT
        p item
        case item
        when :input
          rightAlignedString(@context.prompt)
        when Hash
          p item
          item[PROMPT]
        end
      else
        case item
        when :input
          EMPTY
        when IRB::Cocoa::BasicNode
          item.string
        when Hash
          item[VALUE].string
        end
      end
    end
    
    # result = case item
    # when nil
    #   value = item[column.identifier]
    #   column.identifier == PROMPT ? value : value.string
    # when :input
    #   column.identifier == PROMPT ? rightAlignedString(@context.prompt) : EMPTY
    # when 
    
    # make sure the prompt column is still wide enough
    if result && column.identifier == PROMPT
      width = result.size.width
      column.width = width if width > column.width
    end
    
    result || EMPTY
  end
  
  def outlineView(outlineView, setObjectValue: input, forTableColumn: column, byItem: item)
    value = IRB::Cocoa::BasicNode.alloc.initWithStringRepresentation(input)
    addRowWithPrompt(@context.prompt, value: value)
    processInput(input)
  end
  
  def outlineView(outlineView, dataCellForTableColumn: column, item: item)
    # p item
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
    font = DEFAULT_ATTRIBUTES[NSFontAttributeName]
    
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