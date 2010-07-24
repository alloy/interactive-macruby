class IRBWindowController < NSWindowController
  def initWithObject(object, binding: binding)
    window = NSWindow.alloc.initWithContentRect(NSMakeRect(100, 100, 800, 600),
                                     styleMask: NSResizableWindowMask | NSClosableWindowMask | NSTitledWindowMask,
                                       backing: NSBackingStoreBuffered,
                                         defer: false)
    if initWithWindow(window)
      @viewController = IRBViewController.alloc.initWithObject(object, binding: binding)
      window.contentView = @viewController.view
      self
    end
  end
end