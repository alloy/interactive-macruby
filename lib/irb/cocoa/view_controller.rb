require 'objc_ext'
require 'irb_ext'
require 'node'
require 'list_view'

class IRBViewController < NSViewController
  include IRB::Cocoa

  INPUT_FIELD_HEIGHT = 22

  attr_reader :output
  attr_reader :context

  def initWithObject(object, binding: binding, delegate: delegate)
    if init
      @delegate = delegate
      @history = []
      @currentHistoryIndex = 0
      @expandableRowToNodeMap = {}

      setupIRBForObject(object, binding: binding)

      self
    end
  end
  
  def loadView
    self.view = ScrollableListView.new
    @inputField = view.listView.inputField
    @inputField.delegate = self
    @inputField.target = self
    @inputField.action = "inputFromInputField:"
    @inputField.continuous = true
    setupContextualMenu
  end

  # actions

  def setupContextualMenu
    menu = NSMenu.new
    menu.addItemWithTitle("Clear console", action:"clearConsole:",         keyEquivalent: "k").target = self
    menu.addItem(NSMenuItem.separatorItem)
    menu.addItemWithTitle("",              action:"toggleFullScreenMode:", keyEquivalent: "F").target = self
    menu.addItemWithTitle("Zoom In",       action:"makeTextLarger:",       keyEquivalent: "+").target = view.listView
    menu.addItemWithTitle("Zoom Out",      action:"makeTextSmaller:",      keyEquivalent: "-").target = view.listView
    view.contentView.menu = menu
  end

  def validateUserInterfaceItem(item)
    if item.action == :'toggleFullScreenMode:'
      item.title = view.isInFullScreenMode ? "Exit Full Screen" : "Enter Full Screen"
    end
    true
  end

  def clearConsole(sender)
    view.listView.clear
    @expandableRowToNodeMap = {}
    @context.clear_buffer
    makeInputFieldPromptForInput(false)
  end

  def toggleFullScreenMode(sender)
    if view.isInFullScreenMode
      view.exitFullScreenModeWithOptions({})
    else
      view.enterFullScreenMode(NSScreen.mainScreen, withOptions: {})
    end
    makeInputFieldPromptForInput(false)
  end

  #def newContextWithObjectOfNode(anchor)
    #row = anchor.parentNode.parentNode
    #object_id = row['id'].to_i
    #object = @expandableRowToNodeMap[object_id].object
    #irb(object)
  #end

  def addNode(node, toListView:listView)
    @expandableRowToNodeMap[node.id] = node if node.expandable?
    listView.addNode(node)
  end

  def addConsoleNode(node, updateCurrentLine:updateCurrentLine)
    view.listView.inputFieldListItem.lineNumber = @context.line + 1 if updateCurrentLine
    addNode(node, toListView:view.listView)
  end

  # input/output related methods

  def makeInputFieldPromptForInput(clear = true)
    @inputField.stringValue = '' if clear
    #@inputField.enabled = true
    view.window.makeFirstResponder(@inputField)
  end

  def processInput(line)
    return if line.empty?
    addToHistory(line)
    node = BasicNode.alloc.initWithPrefix(@context.line, value:line)
    addConsoleNode(node, updateCurrentLine:true)

    @thread[:input] = line
    @thread.run

    @sourceValidationBuffer << line
    if @sourceValidationBuffer.code_block? && !@sourceValidationBuffer.syntax_error?
      @sourceValidationBuffer = IRB::Source.new
    end

    makeInputFieldPromptForInput(true)
  end

  def addToHistory(line)
    @history << line
    @currentHistoryIndex = @history.size
  end

  def receivedResult(result)
    addConsoleNode(ObjectNode.nodeForObject(result), updateCurrentLine:false)
    @delegate.receivedResult(self)
    makeInputFieldPromptForInput
  end

  def receivedOutput(output)
    addConsoleNode(BasicNode.alloc.initWithValue(output), updateCurrentLine:false)
  end

  def receivedException(exception)
    string = IRB.formatter.exception(exception)
    addConsoleNode(BasicNode.alloc.initWithValue(string), updateCurrentLine:false)
    makeInputFieldPromptForInput
  end

  def receivedSyntaxError(lineAndError)
    string = IRB.formatter.syntax_error(*lineAndError)
    addConsoleNode(BasicNode.alloc.initWithValue(string), updateCurrentLine:false)
    makeInputFieldPromptForInput
  end

  def terminate
    @delegate.send(:irbViewControllerTerminated, self)
  end

  # delegate methods of the input cell

  def controlTextDidChange(notification)
    sourceValidationWithCurrentSource do |source|
      color = nil
      begin
        if source.syntax_error?
          color NSColor.redColor
        elsif source.code_block?
          unless source.buffer.empty?
            color = NSColor.greenColor
          end
        else
          color = NSColor.cyanColor
        end
      rescue IndexError # ripper takes apart unicode chars
        color = NSColor.cyanColor
      end
      view.listView.highlightCurrentBlockWithColor(color)
    end
  end

  def control(control, textView:textView, completions:completions, forPartialWordRange:range, indexOfSelectedItem:item)
    @completion.call(textView.string).map { |s| s[range.location..-1] }
  end
  
  def control(control, textView: textView, doCommandBySelector: selector)
    #p selector
    case selector
    when :"insertNewline:"
      processInput(textView.string.dup)
    when :"cancelOperation:"
      toggleFullScreenMode(nil) if view.isInFullScreenMode
    when :"insertTab:"
      textView.complete(self)
    when :"moveUp:"
      lineCount = textView.string.strip.split("\n").size
      if lineCount > 1
        return false
      else
        if @currentHistoryIndex > 0
          @currentHistoryIndex -= 1
          textView.string = @history[@currentHistoryIndex]
        else
          NSBeep()
        end
      end
    when :"moveDown:"
      lineCount = textView.string.strip.split("\n").size
      if lineCount > 1
        return false
      else
        if @currentHistoryIndex < @history.size
          @currentHistoryIndex += 1
          line = @history[@currentHistoryIndex]
          textView.string = line ? line : ''
        else
          NSBeep()
        end
      end
    else
      return false
    end
    true
  end

  private

  def sourceValidationWithCurrentSource
    unless empty = @inputField.stringValue.empty?
      @sourceValidationBuffer << @inputField.stringValue
    end
    yield @sourceValidationBuffer
    @sourceValidationBuffer.pop unless empty
  end

  def setupIRBForObject(object, binding: binding)
    @context      = IRB::Cocoa::Context.new(self, object, binding)
    @output       = IRB::Cocoa::Output.new(self)
    @completion   = IRB::Completion.new(@context)
    @sourceValidationBuffer = IRB::Source.new

    @thread = Thread.new(self, @context) do |controller, context|
      IRB::Driver.current = controller
      Thread.stop # stop now, there's no input yet
      
      loop do
        if line = Thread.current[:input]
          Thread.current[:input] = nil
          unless context.process_line(line)
            controller.performSelectorOnMainThread("terminate",
                                        withObject: nil,
                                     waitUntilDone: false)
          end
          Thread.stop # done processing, stop and await new input
        end
      end
    end
  end
end

module Kernel
  def irb(object, binding = nil)
    IRBWindowController.performSelectorOnMainThread("windowWithObjectAndBinding:",
                                                    withObject: [object, binding],
                                                    waitUntilDone: true)
    nil
  end
  private :irb

  def window(frame = NSMakeRect(50, 50, 640, 480))
    window = NSWindow.alloc.initWithContentRect(frame,
                                      styleMask:NSResizableWindowMask | NSClosableWindowMask | NSTitledWindowMask,
                                        backing:NSBackingStoreBuffered,
                                          defer:false)
    window.title = "Window for: #{NSApp.mainWindow.title}"
    window.orderWindow(NSWindowBelow, relativeTo:NSApp.mainWindow.windowNumber)
  end
  private :window
end
