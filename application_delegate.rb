TOPLEVEL_OBJECT = self

class ApplicationDelegate
  def applicationWillFinishLaunching(notification)
    newTopLevelObjectSession(nil)
  end

  def newTopLevelObjectSession(sender)
    irb(TOPLEVEL_OBJECT, TOPLEVEL_BINDING.dup)
  end
end
