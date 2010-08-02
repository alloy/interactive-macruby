class IRBWindowController < NSWindowController
  def self.windowWithObjectAndBinding(args)
    object, binding = args
    alloc.initWithObject(object, binding: binding).showWindow(self)
  end

  def initWithObject(object, binding: binding)
    window = NSWindow.alloc.initWithContentRect(NSMakeRect(100, 100, 800, 600),
                                     styleMask: NSResizableWindowMask | NSClosableWindowMask | NSTitledWindowMask,
                                       backing: NSBackingStoreBuffered,
                                         defer: false)
    if initWithWindow(window)
      @viewController = IRBViewController.alloc.initWithObject(object, binding: binding, delegate: self)
      window.contentView = @viewController.view
      self
    end
  end
  
  def irbViewControllerTerminated(viewController)
    window.close
  end
end
