framework "AppKit"
require "mspec"
$:.unshift File.expand_path("../../lib", __FILE__)
require "irb/cocoa/irb_ext"
require "irb/cocoa/node"

include IRB::Cocoa

class AnObjectWithoutInstanceMethods
end

class AnObject
  def an_instance_method
  end

  private

  def a_private_instance_method
  end
end

