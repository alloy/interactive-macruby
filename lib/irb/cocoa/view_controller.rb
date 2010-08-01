framework 'WebKit'
require 'irb_ext'
require 'node'

class DOMHTMLElement
  def hasClassName?(name)
    className.include?(name)
  end

  def replaceClassName(old, new)
    self.className = className.sub(old, new)
  end

  def id
    getAttribute('id')
  end

  def id=(id)
    send("setAttribute::", "id", id.to_s)
  end

  def hide!
    style.display = 'none'
  end

  def show!
    style.display = 'block'
  end
end

class IRBViewController < NSViewController
  include IRB::Cocoa

  INPUT_FIELD_HEIGHT = 22

  attr_reader :output

  def initWithObject(object, binding: binding, delegate: delegate)
    if init
      @delegate = delegate
      #@history = []
      #@currentHistoryIndex = 0
      @expandableRowToNodeMap = {}

      setupIRBForObject(object, binding: binding)

      self
    end
  end
  
  def loadView
    NSUserDefaults.standardUserDefaults.registerDefaults('WebKitDeveloperExtras' => true)
    
    webView = WebView.alloc.init
    webView.frameLoadDelegate = self

    @inputField = NSTextField.alloc.init
    @inputField.bordered = false
    @inputField.font = NSFont.fontWithName('Menlo Regular', size: 11)
    @inputField.target = self
    @inputField.action = "inputFromInputField:"

    splitView = NSSplitView.alloc.init
    splitView.delegate = self
    splitView.vertical = false
    splitView.dividerStyle = NSSplitViewDividerStylePaneSplitter
    splitView.addSubview(webView)
    splitView.addSubview(@inputField)
    self.view = splitView

    resourcePath = File.dirname(__FILE__)
    path = File.join(resourcePath, 'inspector.html')
    webView.mainFrame.loadHTMLString(File.read(path), baseURL: NSURL.fileURLWithPath(resourcePath))

    # TODO: possibly move this to a subclass
    def splitView.viewDidMoveToWindow
      super
      window.makeFirstResponder(subviews.last)
    end
  end

  # splitView delegate methods

  def splitView(splitView, constrainSplitPosition: position, ofSubviewAt: index)
    max = view.frameSize.height - INPUT_FIELD_HEIGHT - splitView.dividerThickness
    position > max ? max : position
  end

  def splitView(splitView, resizeSubviewsWithOldSize: oldSize)
    splitView.adjustSubviews

    newSize = splitView.frameSize
    webView, inputField = splitView.subviews

    if oldSize.width == 0 || inputField.frameSize.height < INPUT_FIELD_HEIGHT
      dividerThickness  = splitView.dividerThickness      
      webView.frameSize = NSMakeSize(newSize.width, newSize.height - (INPUT_FIELD_HEIGHT + dividerThickness))
      inputField.frame  = NSMakeRect(0, newSize.height - INPUT_FIELD_HEIGHT, newSize.width, INPUT_FIELD_HEIGHT)
    end
  end

  # WebView related methods

  def webView(webView, didFinishLoadForFrame: frame)
    @document = webView.mainFrame.DOMDocument
    @console = @document.getElementById('console')
    @console.send("addEventListener:::", 'click', self, false)

    # TODO: this is a hack to make sure the method is exposed to the objc runtime
    respondsToSelector('childrenTableForNode:')
  end

  def self.webScriptNameForSelector(sel)
    'childrenTableForNode' if sel == :'childrenTableForNode:'
  end

  def self.isSelectorExcludedFromWebScript(sel)
    sel != :"childrenTableForNode:"
  end

  # Expands, or collapses, an expandable node
  def handleEvent(event)
    prefix = event.target
    if prefix.hasClassName?('expandable')
      row   = prefix.parentNode
      value = row.lastChild
      if prefix.hasClassName?('not-expanded')
        # if there is a table, show it, otherwise create and add one
        if (table = value.lastChild) && table.is_a?(DOMHTMLTableElement)
          table.show!
        else
          value.appendChild(childrenTableForNode(row.id.to_i))
        end
        prefix.replaceClassName('not-expanded', 'expanded')
      else
        prefix.replaceClassName('expanded', 'not-expanded')
        value.lastChild.hide!
      end
    end
  end

  # DOM element related methods

  def addNode(node, toElement: element)
    @expandableRowToNodeMap[node.id] = node if node.expandable?
    element.appendChild(rowForNode(node))
  end

  def addConsoleNode(node)
    addNode(node, toElement: @console)
  end

  def childrenTableForNode(id)
    puts "Get children for node: #{id}"
    node = @expandableRowToNodeMap[id]
    table = @document.createElement('table')
    node.children.each { |childNode| addNode(childNode, toElement: table) }
    table
  end

  def rowForNode(node)
    row    = @document.createElement("tr")
    prefix = @document.createElement("td")
    value  = @document.createElement("td")

    row.id           = node.id
    prefix.className = "prefix#{' expandable not-expanded' if node.expandable?}"
    value.className  = "value"
    prefix.innerHTML = node.prefix
    value.innerHTML  = node.value

    row.appendChild(prefix)
    row.appendChild(value)
    row
  end

  # input/output related methods

  def inputFromInputField(inputField)
    input = inputField.stringValue
    unless input.empty?
      inputField.enabled = false
      processInput(input)
    end
  end

  def processInput(input)
    #addToHistory(input)

    node = BasicNode.alloc.initWithPrefix(@context.prompt, value: input)
    addConsoleNode(node)

    @thread[:input] = input
    @thread.run
  end

  def receivedResult(result)
    addConsoleNode(ObjectNode.nodeForObject(result))
    @inputField.stringValue = ''
    @inputField.enabled = true
    view.window.makeFirstResponder(@inputField)
  end

  def receivedOutput(output)
    addConsoleNode(BasicNode.alloc.initWithvalue(output))
  end

  def receivedException(exception)
    string = IRB.formatter.exception(exception)
    addConsoleNode(BasicNode.alloc.initWithvalue(string))
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

  def addToHistory(line)
    @history << line
    @currentHistoryIndex = @history.size
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
end

module Kernel
  def irb(object, binding = nil)
    controller = IRBWindowController.alloc.initWithObject(object, binding: binding)
    controller.showWindow(self)
    nil
  end
  
  private :irb
end
