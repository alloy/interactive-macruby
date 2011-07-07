# 1. A ListItemView only deals with the layout of its inner views *and* updates its own height
# 2. The ListView then manages the layout of list items based on their height
# 3. Finally the ListView updates its own height based on the total length

class NestedListView < NSView
  attr_accessor :representedObjects

  def self.nestedListViewWithRepresentedObjects(objects)
    NestedListView.alloc.initNestedListViewWithRepresentedObjects(objects)
  end

  def initNestedListViewWithRepresentedObjects(objects)
    if init
      self.autoresizingMask    = NSViewNotSizable
      self.autoresizesSubviews = false
      self.representedObjects  = objects
      self
    end
  end

  alias_method :addListItem, :addSubview

  def representedObjects=(array)
    @representedObjects = array
    @representedObjects.each_with_index do |object, i|
      addListItem(ListViewItem.itemWithRepresentedObject(object))
    end
    needsLayout
  end

  def isFlipped
    true
  end

  def nested?
    true
  end

  def enclosingListView
    superview.listView
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
    enclosingListView.needsLayoutAfterChildListViewToggledStartingAtListItem(superview)
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
    frame.size.width  = width
    frame.size.height = y
    @updatingFrameForNewLayout = true
    self.frame = frame
    @updatingFrameForNewLayout = false
  end
end

class ListView < NestedListView
  FONT = NSFont.fontWithName('Menlo Regular', size: 11)

  def initWithFrame(frame)
    if super
      self.autoresizingMask    = NSViewWidthSizable | NSViewMinYMargin
      self.autoresizesSubviews = false
      @inputFieldContainer = ListViewInputField.new
      addSubview(@inputFieldContainer)
      self
    end
  end

  def inputField
    @inputFieldContainer.contentView
  end

  def nested?
    false
  end

  def enclosingListView
  end

  def addListItem(item)
    addSubview(item, positioned:NSWindowBelow, relativeTo:@inputField)
  end

  def needsLayoutAfterChildListViewToggledStartingAtListItem(listItem)
    needsLayoutStartingAtListItem(listItem)
  end
end

class ScrollableListView < NSScrollView
  class ClipViewWithGutter < NSClipView
    def drawRect(_)
      super
      gutterRect = self.bounds
      gutterRect.size.width = ListViewItem::ROOT_LIST_ITEM_CONTENT_VIEW_X
      NSColor.lightGrayColor.setFill # TODO this is still too dark!
      NSRectFill(gutterRect)
    end
  end

  attr_reader :listView

  def init
    if super
      self.backgroundColor = NSColor.whiteColor
      self.hasHorizontalScroller = false

      clipFrame = contentView.frame
      self.contentView = ClipViewWithGutter.alloc.initWithFrame(clipFrame)
      self.documentView = @listView = ListView.alloc.initWithFrame(clipFrame)

      self
    end
  end
end

class ListViewItem < NSView
  HORIZONTAL_MARGIN = 8
  DISCLOSURE_TRIANGLE_DIAMETER = 13
  NESTED_LIST_ITEM_CONTENT_VIEW_X = DISCLOSURE_TRIANGLE_DIAMETER + HORIZONTAL_MARGIN
  ROOT_LIST_ITEM_CONTENT_VIEW_X = NESTED_LIST_ITEM_CONTENT_VIEW_X + HORIZONTAL_MARGIN

  attr_reader :representedObject
  attr_reader :contentView

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
      @childListView ||= ListView.nestedListViewWithRepresentedObjects(@representedObject.children)
      addSubview(@childListView)
    else
      @childListView.removeFromSuperview
    end
    listView.needsLayoutAfterChildListViewToggledStartingAtListItem(self)
  end

  def addDisclosureTriangle
    frame                          = NSMakeRect(disclosureTriangleX, 3, *([DISCLOSURE_TRIANGLE_DIAMETER] * 2))
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
    @contentView.font        = ListView::FONT
    @contentView.bezeled     = false
    @contentView.editable    = false
    @contentView.selectable  = true
    @contentView.stringValue = @representedObject.label
    addSubview(@contentView)
  end
end

class ListViewInputField < NSView
  attr_reader :contentView

  def init
    if super
      self.autoresizingMask    = NSViewNotSizable
      self.autoresizesSubviews = false # We manage them in updateFrameWithWidth:

      @contentView             = NSTextField.new
      @contentView.font        = ListView::FONT
      @contentView.bezeled     = false
      @contentView.editable    = true
      @contentView.selectable  = true

      cell = @contentView.cell
      cell.wraps = false
      cell.scrollable = true

      addSubview(@contentView)
      self
    end
  end

  def updateFrameSizeWithWidth(width)
    contentViewX = ListViewItem::ROOT_LIST_ITEM_CONTENT_VIEW_X
    @contentView.frame = NSMakeRect(contentViewX, 0, width - contentViewX, 22)
    self.frameSize = NSMakeSize(width, 22)
  end
end
