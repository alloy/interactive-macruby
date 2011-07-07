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
  end

  # actions

  def webView(webView, contextMenuItemsForElement: element, defaultMenuItems: defaultItems)
    fullScreenLabel = @splitView.isInFullScreenMode ? "Exit Full Screen" : "Enter Full Screen"
    menuItems = [
      NSMenuItem.alloc.initWithTitle("Clear console", action: "clearConsole:", keyEquivalent: ""),
      NSMenuItem.separatorItem,
      NSMenuItem.alloc.initWithTitle(fullScreenLabel, action: "toggleFullScreenMode:", keyEquivalent: ""),
      NSMenuItem.alloc.initWithTitle("Zoom In", action: "makeTextLarger:", keyEquivalent: ""),
      NSMenuItem.alloc.initWithTitle("Zoom Out", action: "makeTextSmaller:", keyEquivalent: ""),
    ]
    menuItems.each { |i| i.target = self }
    menuItems
  end

  def clearConsole(sender)
    @console.innerHTML = ''
    @expandableRowToNodeMap = {}
    @context.clear_buffer
    makeInputFieldPromptForInput(false)
  end

  def makeTextLarger(sender)
    @webView.makeTextLarger(sender)
  end

  def makeTextSmaller(sender)
    @webView.makeTextSmaller(sender)
  end

  def toggleFullScreenMode(sender)
    if @splitView.isInFullScreenMode
      @splitView.exitFullScreenModeWithOptions({})
    else
      @splitView.enterFullScreenMode(NSScreen.mainScreen, withOptions: {})
    end
    makeInputFieldPromptForInput(false)
  end

  def newContextWithObjectOfNode(anchor)
    row = anchor.parentNode.parentNode
    object_id = row['id'].to_i
    object = @expandableRowToNodeMap[object_id].object
    irb(object)
  end

  # DOM element related methods

  def addNode(node, toElement: listView)
    @expandableRowToNodeMap[node.id] = node if node.expandable?
    listView.addNode(node)
  end

  def addConsoleNode(node)
    addNode(node, toElement: view.listView)
  end

  # input/output related methods

  def makeInputFieldPromptForInput(clear = true)
    @inputField.enabled = true
    view.window.makeFirstResponder(@inputField)
  end

  def processSourceBuffer!
    currentLineCount = @context.line

    @sourceBuffer.buffer.each_with_index do |line, offset|
      addToHistory(line)
      node = BasicNode.alloc.initWithPrefix((currentLineCount + offset).to_s, value:line)
      addConsoleNode(node)
    end

    @thread[:input] = @sourceBuffer.buffer
    @thread.run
  end

  def addToHistory(line)
    @history << line
    @currentHistoryIndex = @history.size
  end

  def receivedResult(result)
    addConsoleNode(ObjectNode.nodeForObject(result))
    @delegate.receivedResult(self)
    makeInputFieldPromptForInput
  end

  def receivedOutput(output)
    addConsoleNode(BasicNode.alloc.initWithValue(output))
  end

  def receivedException(exception)
    string = IRB.formatter.exception(exception)
    addConsoleNode(BasicNode.alloc.initWithValue(string))
    makeInputFieldPromptForInput
    scrollWebViewToBottom
  end

  def terminate
    @delegate.send(:irbViewControllerTerminated, self)
  end

  # delegate methods of the input cell

  def control(control, textView: textView, completions: completions, forPartialWordRange: range, indexOfSelectedItem: item)
    @completion.call(textView.string).map { |s| s[range.location..-1] }
  end
  
  def control(control, textView: textView, doCommandBySelector: selector)
    #p selector
    case selector
    when :"insertNewline:"
      @sourceBuffer = IRB::Source.new(textView.string.split("\n"))
      if @sourceBuffer.code_block?
        processSourceBuffer!
      else
        textView.string = "#{textView.string}\n"
        sizeInputFieldToFit!
      end

    when :"cancelOperation:"
      toggleFullScreenMode(nil) if @splitView.isInFullScreenMode

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

  def sizeInputFieldToFit!
    currentSize = @inputField.frameSize
    @sizeTextField.attributedStringValue = @inputField.attributedStringValue
    height = @sizeTextField.cell.cellSizeForBounds(NSMakeRect(0, 0, currentSize.width, 1000000)).height
    unless height < currentSize.height
      @heightBeforeSizeToFit ||= currentSize.height
      p @heightBeforeSizeToFit
      # the calculation that comes out isn't perfect imo,
      # so add 2 more points for each line in the source buffer
      height += (2 * @sourceBuffer.buffer.size) + 1
      @inputField.frameSize = NSMakeSize(@inputField.frameSize.width, height)
    end
  end

  private

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
          input.each do |line|
            unless context.process_line(line)
              controller.performSelectorOnMainThread("terminate",
                                          withObject: nil,
                                       waitUntilDone: false)
            end
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
end
