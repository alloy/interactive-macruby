framework "AppKit"
require "mspec"
$:.unshift File.expand_path("../../lib", __FILE__)
require "irb/cocoa/node"

describe :basic_node, :shared => true do
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
end

describe "BasicNode" do
  extend IRB::Cocoa

  before do
    @node = BasicNode.alloc.initWithStringValue("42")
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

  it_behaves_like :basic_node, nil
end

describe "ExpandableNode" do
  before do
    @object = Object.new
    @node = ExpandableNode.alloc.initWithObject(@object, stringValue: "42")
  end

  it_behaves_like :basic_node, nil

  it "returns the object" do
    @node.object.should == @object
  end

  it "is expandable" do
    @node.expandable?.should == true
  end
end
