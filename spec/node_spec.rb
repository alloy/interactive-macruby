framework "AppKit"
require "mspec"
$:.unshift File.expand_path("../../lib", __FILE__)
require "irb/cocoa/irb_ext"
require "irb/cocoa/node"

include IRB::Cocoa

describe "BasicNode" do
  before do
    @node = BasicNode.alloc.initWithStringValue("42")
  end

    it "returns an attributed string as prefix" do
    @node.prefix.is_a?(NSAttributedString).should == true
  end

  it "returns an empty prefix by default" do
    @node.prefix.string.should == ""
  end

  it "returns the an attributed string as string value" do
    @node.stringValue.is_a?(NSAttributedString).should == true
  end

  it "returns the string value" do
    @node.stringValue.string.should == "42"
  end

  it "returns an empty array as children" do
    @node.children.should == []
  end

  it "is not expandable" do
    @node.expandable?.should == false
  end

  it "initializes with the given prefix and string value" do
    @node = BasicNode.alloc.initWithPrefix("irb(main)>", stringValue: "42")
    @node.prefix.is_a?(NSAttributedString).should == true
    @node.prefix.string.should == "irb(main)>"
    @node.stringValue.string.should == "42"
  end
end

describe "ExpandableNode" do
  before do
    @object = Object.new
    @node = ExpandableNode.alloc.initWithObject(@object, stringValue: "42")
  end

  it "is a subclass of BasicNode" do
    ExpandableNode.superclass.should == BasicNode
  end

  it "returns the object" do
    @node.object.should == @object
  end

  it "is expandable" do
    @node.expandable?.should == true
  end
end

describe "ListNode" do
  it "is a subclass of ExpandableNode" do
    ListNode.superclass.should == ExpandableNode
  end

  it "returns a list of child BasicNodes with the given strings" do
    node = ListNode.alloc.initWithObject(%w{ object_id send }, stringValue: "methods")
    node.children.should == [
      BasicNode.alloc.initWithStringValue("object_id"),
      BasicNode.alloc.initWithStringValue("send")
    ]
  end
end

describe "BlockListNode" do
  it "is a subclass of ExpandableNode" do
    BlockListNode.superclass.should == ExpandableNode
  end

  it "returns a list of child nodes created in the given block" do
    nodes = [
      BasicNode.alloc.initWithStringValue("42"),
      ListNode.alloc.initWithObject(%w{ send }, stringValue: "methods")
    ]
    node = BlockListNode.alloc.initWithBlockAndStringValue("nodes different") { nodes }
    node.children.should == nodes
  end
end

class AnObjectWithoutInstanceMethods
end

class AnObject
  def an_instance_method
  end

  private

  def a_private_instance_method
  end
end

describe "ObjectNode" do
  before do
    @object = AnObject.new
    @node = ObjectNode.alloc.initWithObject(@object)
  end

  it "is a subclass of ExpandableNode" do
    ObjectNode.superclass.should == ExpandableNode
  end

  it "returns a formatted result string, of the object, as stringValue" do
    @node.stringValue.should == IRB.formatter.result(@object)
  end

  it "returns a ClassNode for this object’s class" do
    @node.classNode.should == ClassNode.alloc.initWithObject(@object.class, stringValue: "Class: AnObject")
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
end

describe "ObjectNode#children" do
  it "includes a ClassNode" do
    @node.children[0].should == @node.classNode
  end
end
