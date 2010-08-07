require File.expand_path("../spec_helper", __FILE__)
require "irb/cocoa/objc_ext"

describe "NSString" do
  it "escapes entities for html" do
    "<div>".htmlEscapeEntities.should == "&lt;div&gt;"
  end
end

describe "NSImage" do
  it "returns a jpeg data representation" do
    image = NSImage.imageNamed('NSNetwork')

    bitmap = NSBitmapImageRep.imageRepWithData(image.TIFFRepresentation)
    expectedData = bitmap.representationUsingType(NSJPEGFileType, properties: { NSImageCompressionFactor => 0.7 })

    image.JFIFData(0.7).should == expectedData
  end
end

describe "DOMHTMLElement" do
  before do
    webView = WebView.alloc.init
    @document = webView.mainFrame.DOMDocument
    @element = @document.createElement('div')
    @element['class'] = 'red brown'
  end

  it "coerces an object to a string and sets the attribute through the #[]= method" do
    @element['class'] = 42
    @element.className.should == '42'
  end

  it "returns an attribute through the #[] method" do
    @element['class'].should == 'red brown'
  end

  it "returns wheter or not an element has a given class name" do
    @element.hasClassName?('red').should == true
    @element.hasClassName?('ed').should == false
  end

  it "replaces a className with another" do
    @element.replaceClassName('red', 'green')
    @element['class'].should == 'green brown'
  end

  it "hides an element" do
    @element.hide!
    @element.style.display.should == 'none'
  end

  it "shows an element" do
    @element.hide!
    @element.show!
    @element.style.display.should == 'block'
  end

  it "iterates over a collection" do
    table = @document.createElement('table')
    row = @document.createElement('tr')
    row.className = "foo"
    table.appendChild(row)
    row = @document.createElement('tr')
    row.className = "bar"
    table.appendChild(row)

    yielded = []
    table.children.each { |child| p child; yielded << child.className }
    yielded.should == %w{ foo bar }
  end
end
