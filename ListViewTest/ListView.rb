# 1. A ListItemView only deals with the layout of its inner views *and* updates its own height
# 2. The ListView then manages the layout of list items based on their height
# 3. Finally the ListView updates its own height based on the total length
class ListView < NSView
  attr_accessor :representedObjects

  def initWithFrame(frame)
    if super
      #puts "ListView init with frame: #{frame.inspect}"
      self.autoresizingMask = NSViewWidthSizable
      self.autoresizesSubviews = false
      self
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

  #def drawRect(rect)
    #NSColor.redColor.setFill
    #NSRectFill(rect)
  #end

  def setFrameSize(size)
    super
    needsLayout unless @updatingFrameForNewLayout
  end

  def needsLayout
    y = 0
    width = frameSize.width

    subviews.each do |listItem|
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
  MARGIN = 8
  DISCLOSURE_TRIANGLE_DIAMETER = 13
  CONTENT_VIEW_X = DISCLOSURE_TRIANGLE_DIAMETER + (MARGIN * 2)

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

  def isFlipped
    true
  end

  def updateFrameSizeWithWidth(width)
    frame = @contentView.stringValue.boundingRectWithSize(NSMakeSize(width - CONTENT_VIEW_X, 0),
                                                options:NSStringDrawingUsesLineFragmentOrigin,
                                             attributes:{ NSFontAttributeName => @contentView.font })

    frame.origin.x = CONTENT_VIEW_X
    frame.size.width = width - CONTENT_VIEW_X

    @contentView.frame = frame

    self.frameSize = NSMakeSize(width, frame.size.height)
  end

  def toggleChildrenListView
    if @disclosureTriangle.state = NSOnState
      puts "SHOW!"
    else
      puts "HIDE!"
    end
  end

  def addDisclosureTriangle
    frame                          = NSMakeRect(MARGIN, MARGIN, DISCLOSURE_TRIANGLE_DIAMETER, DISCLOSURE_TRIANGLE_DIAMETER)
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
