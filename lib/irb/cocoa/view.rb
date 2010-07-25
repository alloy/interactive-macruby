class IRBView < NSView
  attr_reader :viewController, :outlineView
  
  def initWithViewController(viewController)
    if init
      @outlineView = NSOutlineView.alloc.init
      @outlineView.headerView = nil
      @outlineView.selectionHighlightStyle = NSTableViewSelectionHighlightStyleNone
      
      promptColumn = NSTableColumn.alloc.initWithIdentifier("prompt")
      promptColumn.editable = false
      promptColumn.minWidth = 150.0
      promptColumn.width = 150.0
      @outlineView.addTableColumn(promptColumn)
      @outlineView.addTableColumn(NSTableColumn.alloc.initWithIdentifier("value"))
      
      scrollView = NSScrollView.alloc.init
      scrollView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable
      scrollView.documentView = @outlineView
      addSubview(scrollView)
      
      self.viewController = viewController
      
      self
    end
  end
  
  # http://cocoawithlove.com/2008/07/better-integration-for-nsviewcontroller.html
  def setViewController(viewController)
    @viewController               = viewController
    ownNextResponder              = nextResponder
    self.nextResponder            = @viewController
    @viewController.nextResponder = ownNextResponder
    
    @outlineView.dataSource       = @viewController
    @outlineView.delegate         = @viewController
  end
  
  def setNextResponder(nextResponder)
    @viewController.nextResponder = nextResponder
  end
  
  # def setFrameSize(size)
  #   p size
  #   super
  #   # p subviews.first.frame
  #   p @outlineView.frame
  # end
  
  def drawRect(rect)
    NSColor.blueColor.set
    NSBezierPath.fillRect(rect)
  end
end