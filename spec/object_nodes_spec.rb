require File.expand_path("../spec_helper", __FILE__)

describe "ObjectNode" do
  it "is a subclass of ExpandableNode" do
    ObjectNode.superclass.should == ExpandableNode
  end

  it "returns an instance of the appropriate ObjectNode subclass for a given object" do
    ObjectNode.nodeForObject(Object.new).class.should == ObjectNode
    ObjectNode.nodeForObject(String).class.should == ModNode
    ObjectNode.nodeForObject(Kernel).class.should == ModNode
    ObjectNode.nodeForObject(NSImage.alloc.init).class.should == NSImageNode
  end
end

describe "An ObjectNode instance" do
  before do
    @object = AnObject.new
    @node = ObjectNode.alloc.initWithObject(@object)
  end

  it "returns a formatted result string, of the object, as stringValue" do
    @node.objectDescription.should == IRB.formatter.result(@object)
  end

  it "returns a ModNode for this object’s class" do
    @node.classNode.should == ModNode.alloc.initWithObject(@object.class, stringValue: "Class: AnObject")
  end

  it "returns a BlockListNode with public method names, only define on the object's class" do
    @node.publicMethodsNode.to_s.should == "Public methods"
    @node.publicMethodsNode.children.should ==
      [BasicNode.alloc.initWithStringValue("an_instance_method")]
  end

  it "returns nil if there are no public methods defined on the object's class" do
    @node = ObjectNode.alloc.initWithObject(AnObjectWithoutInstanceMethods.new)
    @node.publicMethodsNode.should == nil
  end

  it "returns a BlockListNode with Objective-C method names, only defined on the object's class" do
    objc = Helper.attributedString("42")
    @node = ObjectNode.alloc.initWithObject(objc)
    @node.objcMethodsNode.to_s.should == "Objective-C methods"

    methods = objc.methods(false, true) - objc.methods(false)
    @node.objcMethodsNode.children.should == methods.map do |name|
      BasicNode.alloc.initWithStringValue(name)
    end
  end

  it "returns a BlockListNode with the object's instance variables" do
    @node.instanceVariablesNode.should == nil

    var = Object.new
    @object.instance_variable_set(:@an_instance_variable, var)

    # TODO: No idea why this fails... Work around it by testing individual parts
    #@node.instanceVariablesNode.children.should == [
      #ObjectNode.alloc.initWithObject(var, stringValue: "@an_instance_variable")
    #]

    child = @node.instanceVariablesNode.children.first
    node = ObjectNode.alloc.initWithObject(var, stringValue: "@an_instance_variable")
    child.stringValue.should == node.stringValue
    child.object.should == node.object
    child.children.should == node.children
    child.class.should == node.class
    child.prefix.should == node.prefix
  end

  it "collects all children nodes, without nil values" do
    def @node.called; @called ||= []; end

    def @node.descriptionNode;       called << :descriptionNode;       nil;                    end
    def @node.classNode;             called << :classNode;             :classNode;             end
    def @node.publicMethodsNode;     called << :publicMethodsNode;     :publicMethodsNode;     end
    def @node.objcMethodsNode;       called << :objcMethodsNode;       nil;                    end
    def @node.instanceVariablesNode; called << :instanceVariablesNode; :instanceVariablesNode; end

    @node.children.should == [:classNode, :publicMethodsNode, :instanceVariablesNode]
    @node.called.should ==   [:descriptionNode, :classNode, :publicMethodsNode, :objcMethodsNode, :instanceVariablesNode]
  end
end

describe "An ObjectNode instance, initialized with a stringValue" do
  before do
    @object = AnObject.new
    @node = ObjectNode.alloc.initWithObject(@object, stringValue: "An object")
  end

  it "returns the stringValue it was initialized with" do
    @node.stringValue.string.should == "An object"
  end

  it "returns a descriptionNode" do
    @node.descriptionNode.children.should ==
      [BasicNode.alloc.initWithStringValue(@node.objectDescription)]
  end
end

describe "An ObjectNode instance, initialized without a stringValue" do
  before do
    @object = AnObject.new
    @node = ObjectNode.alloc.initWithObject(@object)
  end

  it "returns the object description as the stringValue" do
    @node.stringValue.should == @node.objectDescription
  end

  it "returns nil as description node" do
    @node.descriptionNode.should == nil
  end
end

describe "ModNode" do
  it "is a subclass of ObjectNode" do
    ModNode.superclass.should == ObjectNode
  end

  it "returns the mod type" do
    node = ModNode.alloc.initWithObject(String)
    node.modTypeNode.should == BasicNode.alloc.initWithStringValue("Type: Class")

    node = ModNode.alloc.initWithObject(Kernel)
    node.modTypeNode.should == BasicNode.alloc.initWithStringValue("Type: Module")
  end

  it "returns the ancestors" do
    node = ModNode.alloc.initWithObject(String)
    node.ancestorNode.stringValue.string.should == "Ancestors"
    node.ancestorNode.children.should == String.ancestors[1..-1].map do |mod|
      ModNode.alloc.initWithObject(mod, stringValue: mod.name)
    end
  end

  it "returns a list of children" do
    ModNode.children.should == [
      :modTypeNode, :ancestorNode,
      :publicMethodsNode, :objcMethodsNode,
      :instanceVariablesNode
    ]
  end
end

describe "NSImageNode" do
  it "returns an image dataCell" do
    flunk "TODO"
  end
end
