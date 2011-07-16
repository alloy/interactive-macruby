# 1. A ListItemView only deals with the layout of its inner views *and* updates its own height
# 2. The ListView then manages the layout of list items based on their height
# 3. Finally the ListView updates its own height based on the total length

# TODO use a data source, in this case the view controller, to get the nodes and line numbers?

class ScrollableListView < NSScrollView
  class ClipViewWithGutter < NSClipView
    GUTTER_COLOR = NSColor.colorWithCalibratedWhite(0.9, alpha:1)

    def drawRect(_)
      super
      gutterRect = self.bounds
      gutterRect.size.width = ListViewItem::ROOT_LIST_ITEM_CONTENT_VIEW_X
      GUTTER_COLOR.setFill
      NSRectFill(gutterRect)
    end
  end

  attr_reader :listView

  def init
    if super
      self.backgroundColor = NSColor.whiteColor
      self.hasHorizontalScroller = false
      self.hasVerticalScroller = true

      clipFrame = contentView.frame
      self.contentView = ClipViewWithGutter.alloc.initWithFrame(clipFrame)
      self.documentView = @listView = ListView.alloc.initWithFrame(clipFrame)

      self
    end
  end
end

class NestedListView < NSView
  attr_accessor :nodes

  def self.nestedListViewWithNodes(nodes)
    NestedListView.alloc.initNestedListViewWithNodes(nodes)
  end

  def initNestedListViewWithNodes(nodes)
    if init
      self.autoresizingMask    = NSViewNotSizable
      self.autoresizesSubviews = false
      self.nodes               = nodes
      self
    end
  end

  alias_method :addListItem, :addSubview
  alias_method :listViewItems, :subviews

  def nodes=(array)
    listViewItems.each(&:removeFromSuperview)
    @nodes = array.dup
    @nodes.each_with_index do |node, i|
      addListItem(ListViewItem.itemWithNode(node))
    end
    needsLayout
  end

  def nodes
    @nodes ||= []
  end

  def addNode(node)
    nodes << node
    addListItem(ListViewItem.itemWithNode(node))
    needsLayoutStartingAtListItemAtIndex(@nodes.size - 1)
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

  def font
    enclosingListView.font
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

    subviews = self.subviews

    # In case the first subview is not at the top, we need to reset them all
    firstView = subviews.first
    if firstView.frameOrigin.y != 0
      listItemIndex = 0
      frame = firstView.frame
      frame.origin.y = 0
      firstView.frame = frame
    end

    y = subviews[listItemIndex].frameOrigin.y
    subviews[listItemIndex..-1].each do |listItem|
      listItem.updateFrameSizeWithWidth(width)
      listItem.frameOrigin = NSMakePoint(0, y)
      y += listItem.frameSize.height
    end

    frame = self.frame
    frame.origin.y   -= y - frame.size.height unless nested? # TODO or unless expanding
    frame.size.width  = width
    frame.size.height = y
    @updatingFrameForNewLayout = true
    self.frame = frame
    @updatingFrameForNewLayout = false
  end
end

class ListView < NestedListView
  attr_reader :inputFieldListItem

  def initWithFrame(frame)
    if super
      self.autoresizingMask    = NSViewWidthSizable | NSViewMinYMargin
      self.autoresizesSubviews = false
      @inputFieldListItem = ListViewInputField.new
      addSubview(@inputFieldListItem)
      self
    end
  end

  def inputField
    @inputFieldListItem.contentView
  end

  def nested?
    false
  end

  def enclosingListView
  end

  def clear
    self.nodes = []
  end

  def font
    @font ||= NSFont.fontWithName('Menlo Regular', size:12)
  end

  def font=(font)
    @font = font
    needsLayout
  end

  def makeTextLarger(sender)
    self.font = NSFont.fontWithName(@font.fontName, size:@font.pointSize * 2)
  end

  def makeTextSmaller(sender)
    self.font = NSFont.fontWithName(@font.fontName, size:@font.pointSize / 2)
  end

  def validateUserInterfaceItem(item)
    item.action == :'makeTextSmaller:' ? canMakeTextSmaller? : true
  end

  def canMakeTextSmaller?
    (@font.pointSize / 2) > 10
  end

  def highlightCurrentBlockWithColor(color)
    if @highlightColor = color
      listViewItems.reverse.each do |item|
        if Fixnum === item.node.prefix
          item.highlightWithColor(color)
        else
          break
        end
      end
    else
      listViewItems.each do |item|
        item.highlightWithColor(color)
      end
    end
    @inputFieldListItem.highlightWithColor(color)
  end

  def listViewItems
    views = subviews.dup
    views.delete(@inputFieldListItem)
    views
  end

  def addListItem(item)
    items = subviews
    if items.size == 1
      addSubview(item, positioned:NSWindowBelow, relativeTo:@inputField)
    else
      addSubview(item, positioned:NSWindowAbove, relativeTo:items[-2])
    end
    highlightCurrentBlockWithColor(Fixnum === item.node.prefix ? @highlightColor : nil)
  end

  def needsLayoutAfterChildListViewToggledStartingAtListItem(listItem)
    needsLayoutStartingAtListItem(listItem)
  end

  def needsLayoutStartingAtListItemAtIndex(listItemIndex)
    super(listItemIndex == 0 ? 0 : listItemIndex - 1) # offset for @inputFieldListItem
  end
end

class ListViewItem < NSView
  class TextField < NSTextField
    def menu
      enclosingScrollView.contentView.menu
    end
  end

  HORIZONTAL_MARGIN = 8
  DISCLOSURE_TRIANGLE_DIAMETER = 13
  NESTED_LIST_ITEM_CONTENT_VIEW_X = DISCLOSURE_TRIANGLE_DIAMETER + HORIZONTAL_MARGIN
  ROOT_LIST_ITEM_CONTENT_VIEW_X = NESTED_LIST_ITEM_CONTENT_VIEW_X + HORIZONTAL_MARGIN

  attr_reader :node
  attr_reader :contentView

  def self.itemWithNode(node)
    alloc.initWithNode(node)
  end

  def initWithNode(node)
    if init
      @node = node
      self.autoresizingMask = NSViewNotSizable
      self.autoresizesSubviews = false # We manage them in updateFrameWithWidth:
      @node.value.is_a?(NSImage) ? addImageView : addTextView
      self
    end
  end

  alias_method :listView, :superview

  def isFlipped
    true
  end

  # we add the disclosure triangle here, because otherwise we can't ask the listView yet if it's nested.
  def viewDidMoveToSuperview
    addDisclosureTriangle if superview && @node.expandable?
  end

  def menu
   enclosingScrollView.contentView.menu
  end

  def disclosureTriangleX
    listView.nested? ? 0 : HORIZONTAL_MARGIN
  end

  def contentViewX
    listView.nested? ? NESTED_LIST_ITEM_CONTENT_VIEW_X : ROOT_LIST_ITEM_CONTENT_VIEW_X
  end

  def image?
    @node.value.is_a?(NSImage)
  end

  def updateFrameSizeWithWidth(width)
    contentViewX = self.contentViewX
    contentWidth = width - contentViewX

    frame = nil
    if image?
      frame = NSMakeRect(0, 0, 0, 0)
      frame.size = @node.value.size
    else
      # always update the font, it might have changed in the meantime
      @contentView.font = font = listView.font
      frame = @contentView.stringValue.boundingRectWithSize(NSMakeSize(contentWidth, 0),
                                                    options:NSStringDrawingUsesLineFragmentOrigin,
                                                 attributes:{ NSFontAttributeName => font })
      frame.size.width = contentWidth
    end

    frame.origin.x = contentViewX
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
      @childListView ||= ListView.nestedListViewWithNodes(@node.children)
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
    @contentView             = TextField.new
    @contentView.bezeled     = false
    @contentView.editable    = false
    @contentView.selectable  = true
    @contentView.stringValue = @node.value
    addSubview(@contentView)
  end

  def addImageView
    @contentView = NSImageView.new
    @contentView.image = @node.value
    addSubview(@contentView)
  end

  def lineNumber
    @node.prefix
  end

  RIGHT_ALIGN = NSMutableParagraphStyle.new.tap { |p| p.alignment = NSRightTextAlignment }
  LINE_NUMBER_COLOR = NSColor.colorWithCalibratedWhite(0.5, alpha:1)
  LINE_NUMBER_RECT = NSMakeRect(4, 0, 21, 22)
  LINE_NUMBER_FONT_SIZE = 12

  def highlightWithColor(color)
    @highlightColor = color
    self.needsDisplay = true
  end

  def drawRect(_)
    if @highlightColor
      bounds = self.bounds
      @highlightColor.setFill
      NSRectFill(bounds)
    end

    lineNumber.to_s.drawInRect(LINE_NUMBER_RECT, withAttributes:{
      NSFontAttributeName => NSFont.fontWithName(listView.font.fontName, size:LINE_NUMBER_FONT_SIZE),
      NSForegroundColorAttributeName => @highlightColor ? NSColor.whiteColor : LINE_NUMBER_COLOR,
      NSParagraphStyleAttributeName => RIGHT_ALIGN
    })
  end
end

class ListViewInputField < ListViewItem
  attr_accessor :lineNumber

  def init
    if super
      self.autoresizingMask    = NSViewNotSizable
      self.autoresizesSubviews = false # We manage them in updateFrameWithWidth:

      @lineNumber = 1

      @contentView             = NSTextField.new
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

  def viewDidMoveToSuperview
  end

  def image?
    false
  end
end
