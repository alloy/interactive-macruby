class ListView < NSView
  def initWithFrame(frame)
    #puts "Init with frame: #{frame.inspect}"
    if super
      self.autoresizingMask = NSViewWidthSizable
      self.autoresizesSubviews = false # We manage them in setFrameSize
      self
    end
  end

  # configure enclosing scroll view
  def viewDidMoveToSuperview
    if superview.is_a?(NSClipView)
      scrollView = enclosingScrollView
      scrollView.autohidesScrollers = true
      scrollView.hasHorizontalScroller = false
    end
  end

  attr_accessor :representedObjects

  def representedObjects=(array)
    @representedObjects = array
  end
end
