class Model
  attr_reader :label

  def initialize(label)
    @label = label
  end
end

class CollapsibleModel < Model
  attr_reader :children

  def initialize(label, children)
    super(label)
    @children = children
  end
end
