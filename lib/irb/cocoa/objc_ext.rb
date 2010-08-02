framework 'CoreFoundation'
framework 'WebKit'

class NSString
  def htmlEscapeEntities
    result = CFXMLCreateStringByEscapingEntities(nil, self, nil)
    CFMakeCollectable(result)
    result
  end
end

class NSImage
  # Returns jpeg file interchange format encoded data for an NSImage regardless of the
  # original NSImage encoding format.  compressionValue is between 0 and 1.
  # values 0.6 thru 0.7 are fine for most purposes.
  def JFIFData(compressionValue)
    bitmap = NSBitmapImageRep.imageRepWithData(self.TIFFRepresentation)
    bitmap.representationUsingType(NSJPEGFileType, properties: { NSImageCompressionFactor => compressionValue })
  end
end

class DOMHTMLElement
  def []=(key, value)
    send('setAttribute::', key, value.to_s)
  end

  alias_method :[], :getAttribute

  def hasClassName?(name)
    className.split(' ').include?(name)
  end

  def replaceClassName(old, new)
    self.className = className.sub(old, new)
  end

  def hide!
    style.display = 'none'
  end

  def show!
    style.display = 'block'
  end
end
