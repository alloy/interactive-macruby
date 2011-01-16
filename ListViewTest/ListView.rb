# 1. A ListItemView only deals with the layout of its inner views *and* updates its own height
# 2. The ListView then manages the layout of list items based on their height
# 3. Finally the ListView updates its own height based on the total length
class ListView < NSView
  attr_accessor :representedObjects

  def initWithFrame(frame)
    if super
      #puts "ListView init with frame: #{frame.inspect}"
      self.autoresizingMask = NSViewWidthSizable
      self
    end
  end

  def representedObjects=(array)
    @representedObjects = array
    @representedObjects.each_with_index do |object, i|
      addSubview(ListViewItem.itemWithRepresentedObject("Item #{i}"))
      #addSubview(ListViewItem.itemWithRepresentedObject(object))
    end
    needsLayout
  end

  def isFlipped
    true
  end

  def drawRect(rect)
    NSColor.redColor.setFill
    NSRectFill(rect)
  end

  def setFrameSize(size)
    super
    needsLayout
  end

  def needsLayout
    y = 0
    width = frameSize.width
    subviews.each do |listItem|
      listItem.updateFrameWithWidth(width)
      listItem.frameOrigin = NSMakePoint(0, y)
      y += listItem.frameSize.height
    end

    lastListItem = subviews.last
    self.bounds = NSMakeRect(0, 0, width, lastListItem.frameOrigin.y + lastListItem.frameSize.height)
    #p lastListItem.frame
    #p bounds
    #p frame
  end
end

class ListViewItem < NSView
  attr_reader :representedObject

  def self.itemWithRepresentedObject(object)
    alloc.initWithRepresentedObject(object)
  end

  def initWithRepresentedObject(object)
    if init
      @representedObject = object
      self.autoresizingMask = NSViewNotSizable
      self.autoresizesSubviews = false # We manage them in updateFrameWithWidth:top:
      
      @view = NSTextField.new
      @view.bezeled = false
      @view.editable = false
      @view.selectable = true
      #@view.stringValue = @representedObject.label
      @view.stringValue = @representedObject
      addSubview(@view)

      self
    end
  end

  def updateFrameWithWidth(width)
    @view.frame = NSMakeRect(0, 0, width, 22)
    self.frameSize = NSMakeSize(width, 22)
  end
end

class ColoredView < NSView
  def drawRect(rect)
    NSColor.greenColor.setFill
    NSRectFill(rect)
  end
end
