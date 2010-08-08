require 'objc_ext'
require 'irb_ext'
require 'node'

class CompletionView < NSTextView
  def drawRect(rect)
  end
end

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

      clearBuffer!

      setupIRBForObject(object, binding: binding)

      self
    end
  end
  
  def loadView
    NSUserDefaults.standardUserDefaults.registerDefaults('WebKitDeveloperExtras' => true)
    
    @webView = WebView.alloc.init
    @webView.frameLoadDelegate = self
    @webView.setUIDelegate(self)

    resourcePath = File.dirname(__FILE__)
    path = File.join(resourcePath, 'inspector.html')
    @webView.mainFrame.loadHTMLString(File.read(path), baseURL: NSURL.fileURLWithPath(resourcePath))

    @completionView = CompletionView.alloc.initWithFrame(NSMakeRect(0, 0, 0, 0))
    @completionView.hidden = true
    @completionView.richText = false
    @completionView.delegate = self
    @completionView.textContainer.widthTracksTextView = false
    @completionView.textContainer.containerSize = NSMakeSize(1000000, 1)
    @webView.addSubview(@completionView)

    self.view = @webView
  end

  # actions

  def webView(webView, contextMenuItemsForElement: element, defaultMenuItems: defaultItems)
    fullScreenLabel = @webView.isInFullScreenMode ? "Exit Full Screen" : "Enter Full Screen"
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

  def clearBuffer!
    @sourceBuffer = IRB::Source.new
    @codeBlockRows = []
  end

  def clearConsole(sender)
    @console.innerHTML = ''
    @expandableRowToNodeMap = {}
    @context.clear_buffer
    clearBuffer!
    setCodeBlockClassesWithCurrentInputFieldSource
    makeInputFieldPromptForInput(false)
  end

  def makeTextLarger(sender)
    @webView.makeTextLarger(sender)
  end

  def makeTextSmaller(sender)
    @webView.makeTextSmaller(sender)
  end

  def toggleFullScreenMode(sender)
    if @webView.isInFullScreenMode
      @webView.exitFullScreenModeWithOptions({})
    else
      @webView.enterFullScreenMode(NSScreen.mainScreen, withOptions: {})
    end
    makeInputFieldPromptForInput(false)
  end

  # WebView related methods

  def webView(webView, didFinishLoadForFrame: frame)
    @webViewDataSource = webView.mainFrame.dataSource
    @document = webView.mainFrame.DOMDocument
    @bottomDiv = @document.getElementById('bottom')
    @console = @document.getElementById('console')
    @console.send("addEventListener:::", 'click', self, false)

    @inputField = @document.getElementById('inputField')
    @inputField.send("addEventListener:::", "keypress", self, false)
    @inputRow = @document.getElementById('inputRow')
    @inputLineNumber = @document.getElementById('inputLineNumber')

    makeInputFieldPromptForInput
  end

  def scrollWebViewToBottom
    @bottomDiv.scrollIntoView(true)
  end

  def makeInputFieldPromptForInput(clear = true)
    @inputField.value = '' if clear
    @inputRow.style.display = 'table-row' # show! currently only sets to 'block'
    @inputField.focus
  end

  def handleEvent(event)
    element = event.target
    case element
    when DOMHTMLInputElement
      handleKeyEvent(event)
    when DOMHTMLTableCellElement
      toggleExpandableNode(element, recursiveClose: event.altKey) if element.hasClassName?('expandable')
    when DOMHTMLAnchorElement
      newContextWithObjectOfNode(element)
    end
  end

  TAB_KEY = 9
  RETURN_KEY = 13
  DELETE_KEY = 63272
  IGNORE_KEYS = [
    63232, 63233, 63234, 63235, # arrow keys
    (63236..63247).to_a, # F1..F12
    63248, # print screen
    63273, 63275, # home, end
    63276, 63277, # page up/down
    63289, # numlock
    63302, #insert
  ].flatten
  
  def handleKeyEvent(event)
    return if IGNORE_KEYS.include?(event.keyCode)

    input = @inputField.value
    if event.charCode >= 32 && event.keyCode != DELETE_KEY
      # ugh
      input += event.charCode.chr.force_encoding('UTF-8')
    end
    #p input
    #p event.keyCode

    source = IRB::Source.new(@sourceBuffer.buffer.dup)
    source << input

    case event.keyCode
    when RETURN_KEY
      if source.syntax_error?
        NSBeep()
      else
        currentLine = @context.line + @codeBlockRows.size
        @inputLineNumber.innerText = (currentLine + 1).to_s
        node = BasicNode.alloc.initWithPrefix(currentLine.to_s, value: input.htmlEscapeEntities)
        row = addConsoleNode(node)
        @codeBlockRows << row
        if source.code_block?
          removeCodeBlockStatusClasses
          clearBuffer!
          @inputRow.hide!
          processInput(source.buffer)
        else
          @sourceBuffer = source
          setCodeBlockClassesWithSource(source)
          makeInputFieldPromptForInput
        end
      end
    when TAB_KEY
      if @inputField.value.empty?
        NSBeep()
      else
        @completionView.string = source.to_s
        @completionView.complete(self)
      end
    else
      setCodeBlockClassesWithSource(source)
    end
  end

  def removeCodeBlockStatusClasses
    @codeBlockRows.each { |r| r.className = '' }
    @inputRow.className = ''
  end

  def setCodeBlockClassesWithCurrentInputFieldSource
    setCodeBlockClassesWithSource(IRB::Source.new([@inputField.value]))
  end

  def setCodeBlockClassesWithSource(source)
    if @codeBlockRows.empty?
      if source.to_s.empty?
        @inputRow.className = ""
      else
        if source.syntax_error?
          @inputRow.className = "code-block start end syntax-error"
        elsif source.code_block?
          @inputRow.className = "code-block start end"
        else
          @inputRow.className = "code-block start end incomplete"
        end
      end
    else
      if source.syntax_error?
        @codeBlockRows.first.className = "code-block start syntax-error"
        @codeBlockRows[1..-1].each { |r| r.className = "code-block syntax-error" }
        @inputRow.className = "code-block end syntax-error"
      elsif source.code_block?
        @codeBlockRows.first.className = "code-block start"
        @codeBlockRows[1..-1].each { |r| r.className = "code-block" }
        @inputRow.className = "code-block end"
      else
        @codeBlockRows.first.className = "code-block start incomplete"
        @codeBlockRows[1..-1].each { |r| r.className = "code-block incomplete" }
        @inputRow.className = "code-block end incomplete"
      end
    end
  end

  def toggleExpandableNode(expandNode, recursiveClose: recursiveClose)
    row   = expandNode.parentNode
    value = row.lastChild
    if expandNode.hasClassName?('not-expanded')
      unless recursiveClose
        # if there is a table, show it, otherwise create and add one
        if (table = value.lastChild) && table.is_a?(DOMHTMLTableElement)
          table.show!
        else
          value.appendChild(childrenTableForNode(row['id'].to_i))
        end
        expandNode.replaceClassName('not-expanded', 'expanded')
      end
    else
      expandNode.replaceClassName('expanded', 'not-expanded')
      value.lastChild.hide!
      if recursiveClose
        value.lastChild.children.each do |row|
          node = row.firstChild
          toggleExpandableNode(node, recursiveClose: true) if node.hasClassName?('expanded')
        end
      end
    end
  end

  def newContextWithObjectOfNode(anchor)
    row = anchor.parentNode.parentNode
    object_id = row['id'].to_i
    object = @expandableRowToNodeMap[object_id].object
    irb(object)
  end

  # DOM element related methods

  def addNode(node, toElement: element, includeLineNumberColumn: includeLineNumberColumn)
    @expandableRowToNodeMap[node.id] = node if node.expandable?
    row = rowForNode(node, includeLineNumberColumn: includeLineNumberColumn)
    element.appendChild(row)
    row
  end

  def addConsoleNode(node)
    addNode(node, toElement: @console, includeLineNumberColumn: true)
  end

  def childrenTableForNode(id)
    node = @expandableRowToNodeMap[id]
    table = @document.createElement('table')
    node.children.each { |childNode| addNode(childNode, toElement: table, includeLineNumberColumn: false) }
    table
  end

  def rowForNode(node, includeLineNumberColumn: includeLineNumberColumn)
    row        = @document.createElement("tr")
    expandNode = @document.createElement("td")
    value      = @document.createElement("td")

    if includeLineNumberColumn
      lineNumber = @document.createElement("td")
      lineNumber.className = "lineNumber"
      lineNumber.innerHTML = node.prefix
      row.appendChild(lineNumber)
    end

    row['id'] = node.id
    expandNode.className = "expandNode#{' expandable not-expanded' if node.expandable?}"
    value.className = "value"

    if node.is_a?(NSImageNode)
      value.appendChild(imageElementForNode(node))
    else
      value.innerHTML = node.value
    end

    row.appendChild(expandNode)
    row.appendChild(value)
    row
  end

  # Adds the image data as a WebResource to the webview's data source and
  # returns a IMG element, referencing the image.
  def imageElementForNode(node)
    image = node.object
    url = "NSImage://#{image.object_id}.jpg"

    @webViewDataSource.addSubresource(WebResource.alloc.initWithData(image.JFIFData(0.75),
                                                                URL: NSURL.URLWithString(url),
                                                           MIMEType: "image/jpeg",
                                                   textEncodingName: nil,
                                                          frameName: nil))

    element = @document.createElement('img')
    element['src'] = url
    element
  end

  # input/output related methods

  def processInput(lines)
    #p lines
    #lines.each { |line| addToHistory(line) }
    @thread[:inputLines] = lines.dup
    @thread.run
  end

  def addToHistory(line)
    @history << line
    @currentHistoryIndex = @history.size
  end

  def receivedResult(result)
    #p result
    addConsoleNode(ObjectNode.nodeForObject(result))
    @delegate.receivedResult(self)

    makeInputFieldPromptForInput
    scrollWebViewToBottom
  end

  def receivedOutput(output)
    addConsoleNode(BasicNode.alloc.initWithValue(output.htmlEscapeEntities))
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

  def textView(textView, completions: completions, forPartialWordRange: range, indexOfSelectedItem: item)
    # get the position of the top-left corner of the bottom div from the top-left corner of the document
    x = y = 0
    node = @bottomDiv
    begin
      x += node.offsetLeft
      y += node.offsetTop
    end while node = node.offsetParent
    # offset the y coord by the scrolled offset
    # TODO is there a better way to get this?
    scrollY = @webView.windowScriptObject.evaluateWebScript('window.scrollY')
    y -= scrollY
    # flip the y coord and move the text view a bit more up (15px)
    frame = NSMakeRect(x, (@webView.frameSize.height - y) + 15, 0, 0)
    p frame
    @completionView.frame = frame

    @completion.call(textView.string).map { |s| s[range.location..-1] }
  end

  def textViewDidChangeSelection(notification)
    range = @completionView.selectedRanges.first.rangeValue
    @inputField.value = @completionView.string
    @inputField.selectionStart = range.location
    @inputField.selectionEnd = range.location + range.length
  end

  def control(control, textView: textView, doCommandBySelector: selector)
    #p selector
    case selector
    when :"cancelOperation:"
      toggleFullScreenMode(nil) if @splitView.isInFullScreenMode
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
        textView.string = line ? line : ''
      else
        NSBeep()
      end
    else
      return false
    end
    true
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
        if lines = Thread.current[:inputLines]
          Thread.current[:inputLines] = nil
          lines.each do |line|
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
