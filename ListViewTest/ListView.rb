# 1. A ListItemView only deals with the layout of its inner views *and* updates its own height
# 2. The ListView then manages the layout of list items based on their height
# 3. Finally the ListView updates its own height based on the total length
class ListView < NSView
  attr_accessor :representedObjects

  # Only a root ListView should autosize the width when the superview changes width
  def viewDidMoveToSuperview
    self.autoresizingMask = superview.is_a?(ListViewItem) ? NSViewNotSizable : NSViewWidthSizable
    self.autoresizesSubviews = false
  end

  def representedObjects=(array)
    @representedObjects = array
    @representedObjects.each_with_index do |object, i|
      addSubview(ListViewItem.itemWithRepresentedObject(object))
    end
    needsLayout
  end

  def isFlipped
    true
  end

  attr_writer :color
  def color
    @color ||= NSColor.redColor
  end
  def drawRect(rect)
    color.setFill
    NSRectFill(rect)
  end

  def setFrameSize(size)
    super
    needsLayout unless @updatingFrameForNewLayout
  end

  def needsLayout
    needsLayoutStartingAtListItemAtIndex(0)
  end

  def needsLayoutStartingAtListItem(listItem)
    needsLayoutStartingAtListItemAtIndex(subviews.index(listItem))
  end

  def needsLayoutStartingAtListItemAtIndex(listItemIndex)
    return if subviews.empty?

    y = subviews[listItemIndex].frameOrigin.y
    width = frameSize.width

    subviews[listItemIndex..-1].each do |listItem|
      listItem.updateFrameSizeWithWidth(width)
      listItem.frameOrigin = NSMakePoint(0, y)
      y += listItem.frameSize.height
    end

    frame = self.frame
    frame.origin.y   -= y - frame.size.height
    frame.size.height = y
    @updatingFrameForNewLayout = true
    self.frame = frame
    @updatingFrameForNewLayout = false
  end
end

class ListViewItem < NSView
  HORIZONTAL_MARGIN = 8
  DISCLOSURE_TRIANGLE_DIAMETER = 13
  CONTENT_VIEW_X = DISCLOSURE_TRIANGLE_DIAMETER + (HORIZONTAL_MARGIN * 2)

  attr_reader :representedObject

  def self.itemWithRepresentedObject(object)
    alloc.initWithRepresentedObject(object)
  end

  def initWithRepresentedObject(object)
    if init
      @representedObject = object
      self.autoresizingMask = NSViewNotSizable
      self.autoresizesSubviews = false # We manage them in updateFrameWithWidth:
      addDisclosureTriangle if object.respond_to?(:children)
      addTextView
      self
    end
  end

  alias_method :listView, :superview

  def isFlipped
    true
  end

  def updateFrameSizeWithWidth(width)
    frame = @contentView.stringValue.boundingRectWithSize(NSMakeSize(width - CONTENT_VIEW_X, 0),
                                                options:NSStringDrawingUsesLineFragmentOrigin,
                                             attributes:{ NSFontAttributeName => @contentView.font })

    frame.origin.x = CONTENT_VIEW_X
    frame.size.width = width - CONTENT_VIEW_X

    totalFrameHeight = frame.size.height

    @contentView.frame = frame

    if @childListView && @childListView.superview
      frame.origin.y += frame.size.height
      @childListView.frame = frame
      totalFrameHeight += @childListView.frameSize.height
    end

    self.frameSize = NSMakeSize(width, totalFrameHeight)
  end

  def toggleChildrenListView
    if @disclosureTriangle.state == NSOnState
      unless @childListView
        @childListView = ListView.new
        @childListView.color = NSColor.blueColor
      end
      addSubview(@childListView)
    else
      @childListView.removeFromSuperview
    end
    listView.needsLayoutStartingAtListItem(self)
  end

  def addDisclosureTriangle
    frame                          = NSMakeRect(HORIZONTAL_MARGIN, 3, DISCLOSURE_TRIANGLE_DIAMETER, DISCLOSURE_TRIANGLE_DIAMETER)
    @disclosureTriangle            = NSButton.alloc.initWithFrame(frame)
    @disclosureTriangle.bezelStyle = NSDisclosureBezelStyle
    @disclosureTriangle.buttonType = NSOnOffButton
    @disclosureTriangle.title      = nil
    @disclosureTriangle.target     = self
    @disclosureTriangle.action     = :toggleChildrenListView
    addSubview(@disclosureTriangle)
  end

  def addTextView
    @contentView             = NSTextField.new
    @contentView.font        = NSFont.systemFontOfSize(NSFont.systemFontSize)
    @contentView.bezeled     = false
    @contentView.editable    = false
    @contentView.selectable  = true
    @contentView.stringValue = @representedObject.label
    addSubview(@contentView)
  end
end
