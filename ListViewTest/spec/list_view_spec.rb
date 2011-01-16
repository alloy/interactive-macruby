require File.expand_path("../spec_helper", __FILE__)

describe "ListView" do
  before do
    @scrollView = NSScrollView.alloc.initWithFrame(NSMakeRect(0, 0, 400, 400))
    @listView = ListView.alloc.initWithFrame(NSMakeRect(0, 0, 400, 0))
    @scrollView.documentView = @listView

    @objects = Array.new(4) { |i| Model.new("Object #{i}") }
    @listView.representedObjects = @objects
  end

  it "takes an array of represented objects" do
    @listView.representedObjects.should == @objects
  end

  describe "configures so that" do
    it "only autoresizes horizontally" do
      @listView.autoresizingMask.should == NSViewWidthSizable
    end

    it "does not autoresize its subviews" do
      @listView.autoresizesSubviews.should == false
    end

    it "has a flipped coordinate" do
      
    end

    describe "its enclosing NSScrollView" do
      it "autohides the scrollers" do
        @scrollView.autohidesScrollers.should == true
      end

      it "has no horizontal scroller" do
        @scrollView.hasHorizontalScroller.should == false
      end
    end
  end
end

Bacon.run
