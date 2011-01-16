# 1. A ListItemView only deals with the layout of its inner views *and* updates its own height
# 2. The ListView then manages the layout of list items based on their height
# 3. Finally the ListView updates its own height based on the total length
#
# TODO: It might be better to create a NestedListView class which does not have 8 pixels of margin
#       before its items and a regular ListView does add it. This way we don't need to check if the
#       listView.nested? everytime when calculating the margins in ListViewItem#updateFrameSizeWithWidth
class ListView < NSView
  attr_accessor :representedObjects

  def self.nestedListViewWithRepresentedObjects(objects)
    alloc.initNestedListViewWithRepresentedObjects(objects)
  end

  def initWithFrame(frame)
    if super
      @nested                  = false
      self.autoresizingMask    = NSViewWidthSizable | NSViewMinYMargin
      self.autoresizesSubviews = false
      self
    end
  end

  def initNestedListViewWithRepresentedObjects(objects)
    if init
      @nested                  = true
      self.autoresizingMask    = NSViewNotSizable
      self.autoresizesSubviews = false
      self.representedObjects  = objects
      self
    end
  end

  def viewDidMoveToSuperview
    if superview.is_a?(NSClipView)
      enclosingScrollView.hasHorizontalScroller = false
    end
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

  def nested?
    @nested
  end

  def enclosingListView
    if nested?
      superview.listView
    end
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

  def updateFrameSizeWithWidth(width)
    needsLayoutStartingAtListItemAtIndex(0, withWidth:width)
  end

  def needsLayout
    needsLayoutStartingAtListItemAtIndex(0)
  end

  def needsLayoutAfterChildListViewToggledStartingAtListItem(listItem)
    needsLayoutStartingAtListItem(listItem)
    if listView = enclosingListView
      listView.needsLayoutAfterChildListViewToggledStartingAtListItem(superview)
    end
  end

  def needsLayoutStartingAtListItem(listItem)
    needsLayoutStartingAtListItemAtIndex(subviews.index(listItem))
  end

  def needsLayoutStartingAtListItemAtIndex(listItemIndex)
    needsLayoutStartingAtListItemAtIndex(listItemIndex, withWidth:frameSize.width)
  end

  def needsLayoutStartingAtListItemAtIndex(listItemIndex, withWidth:width)
    return if !superview || subviews.empty?

    y = subviews[listItemIndex].frameOrigin.y

    subviews[listItemIndex..-1].each do |listItem|
      listItem.updateFrameSizeWithWidth(width)
      listItem.frameOrigin = NSMakePoint(0, y)
      y += listItem.frameSize.height
    end

    frame = self.frame
    frame.origin.y   -= y - frame.size.height unless nested?
    frame.size.width  = width
    frame.size.height = y
    @updatingFrameForNewLayout = true
    self.frame = frame
    @updatingFrameForNewLayout = false
  end
end

class ListViewItem < NSView
  HORIZONTAL_MARGIN = 8
  DISCLOSURE_TRIANGLE_DIAMETER = 13
  NESTED_LIST_ITEM_CONTENT_VIEW_X = DISCLOSURE_TRIANGLE_DIAMETER + HORIZONTAL_MARGIN
  ROOT_LIST_ITEM_CONTENT_VIEW_X = NESTED_LIST_ITEM_CONTENT_VIEW_X + HORIZONTAL_MARGIN

  attr_reader :representedObject

  def self.itemWithRepresentedObject(object)
    alloc.initWithRepresentedObject(object)
  end

  def initWithRepresentedObject(object)
    if init
      @representedObject = object
      self.autoresizingMask = NSViewNotSizable
      self.autoresizesSubviews = false # We manage them in updateFrameWithWidth:
      addTextView
      self
    end
  end

  alias_method :listView, :superview

  def isFlipped
    true
  end

  # we add the disclosure triangle here, because otherwise we can't ask the listView yet if it's nested.
  def viewDidMoveToSuperview
    addDisclosureTriangle if @representedObject.respond_to?(:children)
  end

  def disclosureTriangleX
    listView.nested? ? 0 : HORIZONTAL_MARGIN
  end

  def contentViewX
    listView.nested? ? NESTED_LIST_ITEM_CONTENT_VIEW_X : ROOT_LIST_ITEM_CONTENT_VIEW_X
  end

  def updateFrameSizeWithWidth(width)
    contentViewX = self.contentViewX
    contentWidth = width - contentViewX

    frame = @contentView.stringValue.boundingRectWithSize(NSMakeSize(contentWidth, 0),
                                                options:NSStringDrawingUsesLineFragmentOrigin,
                                             attributes:{ NSFontAttributeName => @contentView.font })

    frame.origin.x = contentViewX
    frame.size.width = contentWidth

    totalFrameHeight = frame.size.height

    @contentView.frame = frame

    if @childListView && @childListView.superview
      @childListView.updateFrameSizeWithWidth(contentWidth)
      @childListView.frameOrigin = NSMakePoint(contentViewX, totalFrameHeight)
      totalFrameHeight += @childListView.frameSize.height
    end

    self.frameSize = NSMakeSize(width, totalFrameHeight)
  end

  def toggleChildrenListView
    if @disclosureTriangle.state == NSOnState
      unless @childListView
        @childListView = ListView.nestedListViewWithRepresentedObjects(@representedObject.children)
        @childListView.color = NSColor.blueColor
      end
      addSubview(@childListView)
    else
      @childListView.removeFromSuperview
    end
    listView.needsLayoutAfterChildListViewToggledStartingAtListItem(self)
  end

  def addDisclosureTriangle
    frame                          = NSMakeRect(disclosureTriangleX, 3, DISCLOSURE_TRIANGLE_DIAMETER, DISCLOSURE_TRIANGLE_DIAMETER)
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
