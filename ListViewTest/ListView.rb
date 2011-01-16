# 1. A ListItemView only deals with the layout of its inner views *and* updates its own height
# 2. The ListView then manages the layout of list items based on their height
# 3. Finally the ListView updates its own height based on the total length
class ListView < NSView
  attr_accessor :representedObjects

  def self.listViewWithRepresentedObjects(objects)
    listView = new
    listView.representedObjects = objects
    listView
  end

  # Only a root ListView should autosize the width when the superview changes width
  def viewDidMoveToSuperview
    self.autoresizingMask = superview.is_a?(ListViewItem) ? NSViewNotSizable : (NSViewWidthSizable | NSViewMinYMargin)
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

  def enclosingListView
    if superview.is_a?(ListViewItem)
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
    frame.origin.y   -= y - frame.size.height unless superview.is_a?(ListViewItem)
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
      @childListView.updateFrameSizeWithWidth(width - CONTENT_VIEW_X)
      @childListView.frameOrigin = NSMakePoint(CONTENT_VIEW_X, totalFrameHeight)
      totalFrameHeight += @childListView.frameSize.height
    end

    self.frameSize = NSMakeSize(width, totalFrameHeight)
  end

  def toggleChildrenListView
    if @disclosureTriangle.state == NSOnState
      unless @childListView
        @childListView = ListView.listViewWithRepresentedObjects(@representedObject.children)
        @childListView.color = NSColor.blueColor
      end
      addSubview(@childListView)
    else
      @childListView.removeFromSuperview
    end
    listView.needsLayoutAfterChildListViewToggledStartingAtListItem(self)
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
