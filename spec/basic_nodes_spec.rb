require File.expand_path("../spec_helper", __FILE__)

describe "BasicNode" do
  before do
    @node = BasicNode.alloc.initWithvalue("42")
  end

    it "returns an attributed string as prefix" do
    @node.prefix.is_a?(NSAttributedString).should == true
  end

  it "returns an empty prefix by default" do
    @node.prefix.string.should == ""
  end

  it "returns the an attributed string as string value" do
    @node.value.is_a?(NSAttributedString).should == true
  end

  it "returns the string value" do
    @node.value.string.should == "42"
  end

  it "returns an empty array as children" do
    @node.children.should == []
  end

  it "is not expandable" do
    @node.expandable?.should == false
  end

  it "initializes with the given prefix and string value" do
    @node = BasicNode.alloc.initWithPrefix("irb(main)>", value: "42")
    @node.prefix.is_a?(NSAttributedString).should == true
    @node.prefix.string.should == "irb(main)>"
    @node.value.string.should == "42"
  end

  it "returns NSTextFieldCell as the type of data cell to use to display prefix and value" do
    @node.dataCellTypeForColumn('prefix').should == NSTextFieldCell
    @node.dataCellTypeForColumn('value').should == NSTextFieldCell
  end
end

describe "ExpandableNode" do
  before do
    @object = Object.new
    @node = ExpandableNode.alloc.initWithObject(@object, value: "42")
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
    node = ListNode.alloc.initWithObject(%w{ object_id send }, value: "methods")
    node.children.should == [
      BasicNode.alloc.initWithvalue("object_id"),
      BasicNode.alloc.initWithvalue("send")
    ]
  end
end

describe "BlockListNode" do
  it "is a subclass of ExpandableNode" do
    BlockListNode.superclass.should == ExpandableNode
  end

  it "returns a list of child nodes created in the given block" do
    nodes = [
      BasicNode.alloc.initWithvalue("42"),
      ListNode.alloc.initWithObject(%w{ send }, value: "methods")
    ]
    node = BlockListNode.alloc.initWithBlockAndvalue("nodes different") { nodes }
    node.children.should == nodes
  end
end
