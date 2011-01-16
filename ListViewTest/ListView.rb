class ListViewLayoutManager < NSView
  attr_reader :rootListView

  def initWithFrame(frame)
    puts "Init with frame: #{frame.inspect}"
    if super
      self.autoresizingMask = NSViewWidthSizable #| NSViewHeightSizable
      #self.autoresizesSubviews = false # We manage them in setFrameSize

      #@containerView = NSView.alloc.initWithFrame(frame)
      #addSubview(@containerView)

      @rootListView = ListView.alloc.initWithFrame(NSMakeRect(0, 0, frame.size.width, 0))
      #@containerView.addSubview(@rootListView)
      addSubview(@rootListView)

      self
    end
  end

  #def viewWillMoveToSuperview(superview)
    #if superview.is_a?(NSClipView) && !superview.is_a?(ClipView)
      #scrollView = superview.superview
      #p scrollView.contentView.frame
      #scrollView.contentView = ClipView.alloc.initWithFrame(NSMakeRect(1, 1, scrollView.contentView.frameSize.width, scrollView.contentView.frameSize.height))
      #scrollView.documentView = self
      ##scrollView.autohidesScrollers = true
      ##scrollView.hasHorizontalScroller = false
    #end
  #end

  def viewDidMoveToSuperview
    superview.autoresizesSubviews = false if superview
  end

  # configure enclosing scroll view
  #def viewDidMoveToSuperview
    #if superview.is_a?(NSClipView)
      #scrollView = enclosingScrollView
      #p scrollView.contentView.frame
      #scrollView.contentView = ClipView.alloc.initWithFrame(NSMakeRect(1, 1, scrollView.contentView.frameSize.width, scrollView.contentView.frameSize.height))
      #scrollView.documentView = self
      ##scrollView.autohidesScrollers = true
      ##scrollView.hasHorizontalScroller = false
    #end
  #end

  #def isFlipped
    #true
  #end

  #def setFrame(frame)
    #frame.origin = NSZeroPoint
    #super(frame)
  #end

  def needsLayout
    lastListItem = @rootListView.subviews.last
    p lastListItem.frame
    size = self.frameSize
    #self.bounds = NSMakeRect(0, 0, size.width, lastListItem.frame.origin.y + lastListItem.frame.size.height)
    #self.frameSize = NSMakeSize(size.width, lastListItem.frame.origin.y + lastListItem.frame.size.height)
    #self.frame = NSMakeRect(0, 0, size.width, lastListItem.frame.origin.y + lastListItem.frame.size.height)
    #@containerView.frame = NSMakeRect(0, 0, size.width, lastListItem.frame.origin.y + lastListItem.frame.size.height)
    #@rootListView.bounds = NSMakeRect(0, 0, size.width, lastListItem.frame.origin.y + lastListItem.frame.size.height)
    #self.needsDisplay = true
  end

  def drawRect(rect)
    NSColor.redColor.setFill
    NSRectFill(rect)
  end
end

#class ContainerView < NSView
  #def isFlipped
    #true
  #end

  #def drawRect(rect)
    #NSColor.redColor.setFill
    #NSRectFill(rect)
  #end
#end

# * A ListItemView only deals with the layout of its inner views *and* updates its own height
# * The ListView then manages the layout of list items based on their height
class ListView < NSView
  attr_accessor :representedObjects

  def initWithFrame(frame)
    if super
      self.autoresizingMask = NSViewMaxYMargin
      self
    end
  end

  def representedObjects=(array)
    @representedObjects = array

    size = self.frameSize

    @representedObjects.each_with_index do |object, i|
      view = NSTextField.alloc.initWithFrame(NSMakeRect(0, i * 20, size.width, 20))
      #view.stringValue = object.label
      view.stringValue = "Item #{i}"
      addSubview(view)
    end

    superview.needsLayout
  end

  def isFlipped
    true
  end
end
