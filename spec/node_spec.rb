framework "AppKit"
require "mspec"
$:.unshift File.expand_path("../../lib", __FILE__)
require "irb/cocoa/node"

describe "BasicNode" do
  extend IRB::Cocoa

  before do
    @node = BasicNode.alloc.initWithStringRepresentation("42")
  end

  it "returns an attributed string as prefix" do
    @node.prefix.is_a?(NSAttributedString).should == true
  end

  it "returns an empty prefix by default" do
    @node.prefix.string.should == ""
  end

  it "returns the an attributed string as string representation" do
    @node.stringRepresentation.is_a?(NSAttributedString).should == true
  end

  it "returns the string representation" do
    @node.stringRepresentation.string.should == "42"
  end

  it "is not expandable" do
    @node.expandable?.should == false
  end

  it "returns an empty array as children" do
    @node.children.should == []
  end
end
