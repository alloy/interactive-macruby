class IRBWindowController < NSWindowController
  def self.windowWithObjectAndBinding(args)
    object, binding = args
    alloc.initWithObject(object, binding: binding).showWindow(self)
  end

  def initWithObject(object, binding: binding)
    if keyWindow = NSApp.keyWindow
      # This has got to be easier
      keyWindowFrame  = keyWindow.frame
      point           = NSMakePoint(NSMinX(keyWindowFrame), NSMaxY(keyWindowFrame))
      point           = keyWindow.cascadeTopLeftFromPoint(point)
      point.y        -= NSHeight(keyWindowFrame)
      frame           = keyWindow.contentRectForFrameRect(keyWindowFrame)
      frame.origin.x  = point.x
      frame.origin.y  = point.y
    else
      frame = NSMakeRect(100, 100, 600, 400)
    end

    window = NSWindow.alloc.initWithContentRect(frame,
                                     styleMask: NSResizableWindowMask | NSClosableWindowMask | NSTitledWindowMask,
                                       backing: NSBackingStoreBuffered,
                                         defer: false)

    if initWithWindow(window)
      @viewController = IRBViewController.alloc.initWithObject(object, binding: binding, delegate: self)
      window.contentView = @viewController.view
      receivedResult(@viewController)
      self
    end
  end

  def receivedResult(viewController)
    window.title = viewController.context.object.inspect
  end

  def clearConsole(sender)
    @viewController.clearConsole(sender)
  end

  def makeTextLarger(sender)
    @viewController.makeTextLarger(sender)
  end

  def makeTextSmaller(sender)
    @viewController.makeTextSmaller(sender)
  end

  def cancelOperation(sender)
    @viewController.toggleFullScreenMode(sender)
  end

  def toggleFullScreenMode(sender)
    @viewController.toggleFullScreenMode(sender)
  end

  def irbViewControllerTerminated(viewController)
    window.close
  end
end
