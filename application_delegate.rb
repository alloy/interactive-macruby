TOPLEVEL_OBJECT = self

class ApplicationDelegate
  def applicationWillFinishLaunching(notification)
    controller = IRBWindowController.alloc.initWithObject(TOPLEVEL_OBJECT, binding: TOPLEVEL_BINDING.dup)
    controller.showWindow(self)
  end
end