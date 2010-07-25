TOPLEVEL_OBJECT = self

class ApplicationDelegate
  def applicationWillFinishLaunching(notification)
    irb(TOPLEVEL_OBJECT, TOPLEVEL_BINDING.dup)
  end
end