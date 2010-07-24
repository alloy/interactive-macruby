class IRBViewController < NSViewController
  def initWithObject(object, binding: binding)
    if init
      self
    end
  end
  
  def loadView
    self.view = IRBView.alloc.initWithViewController(self)
  end
end