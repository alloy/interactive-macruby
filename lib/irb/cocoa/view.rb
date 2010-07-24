class IRBView < NSView
  attr_reader :viewController
  
  def initWithViewController(viewController)
    if init
      self.viewController = viewController
      
      @outlineView = NSOutlineView.alloc.init
      
      scrollView = NSScrollView.alloc.init
      scrollView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable
      scrollView.documentView = @outlineView
      addSubview(scrollView)
      
      self
    end
  end
  
  # http://cocoawithlove.com/2008/07/better-integration-for-nsviewcontroller.html
  def setViewController(viewController)
    @viewController = viewController
    ownNextResponder = nextResponder
    self.nextResponder = @viewController
    @viewController.nextResponder = ownNextResponder
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