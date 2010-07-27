require 'irb'
require 'irb/driver'
require 'irb/ext/completion'
require 'irb/ext/colorize'

module IRB
  # TODO changes to core classes that need to go back into dietrb
  
  class Context
    def evaluate(source)
      result = __evaluate__(source.to_s, '(irb)', @line - @source.buffer.size + 1)
      unless result == IGNORE_RESULT
        store_result(result)
        report_result(result)
        result
      end
    rescue Exception => e
      store_exception(e)
      report_exception(e)
    end
    
    def report_result(result)
      puts(formatter.result(result))
    end
    
    def report_exception(exception)
      puts(formatter.exception(exception))
    end
  end
  
  class ColoredFormatter
    def colorize_tokens(str)
      Ripper.lex(str).map { |_, type, token| colorize_token(type, token) }
    end
    
    def colorize(str)
      colorize_tokens.join
    end
  end
  
  class Completion
    def initialize(context = nil)
      @context = context
    end
    
    def context
      @context || IRB::Driver.current.context
    end
  end
  
  # The normal support classes
  module Cocoa
    class Output
      NEW_LINE = "\n"
      
      def initialize(viewController)
        @controller = viewController
      end
      
      def write(string)
        unless string == NEW_LINE
          @controller.performSelectorOnMainThread("receivedOutput:",
                                      withObject: string,
                                   waitUntilDone: false)
        end
      end
    end
    
    class Context < IRB::Context
      attr_accessor :view_controller
      
      def initialize(view_controller, object, binding = nil)
        @view_controller = view_controller
        super(object, binding)
      end
      
      def process_line(line)
        result = super
        send_to_view_controller("needsMoreInput") if @source.level > 0
        result
      end
      
      def send_to_view_controller(method, arg = nil)
        @view_controller.performSelectorOnMainThread(method,
                                    withObject: arg,
                                 waitUntilDone: false)
      end
      
      def report_result(result)
        send_to_view_controller("receivedResult:", result)
      end
      
      def report_exception(exception)
        send_to_view_controller("receivedException:", exception)
      end
    end
    
    class ColoredFormatter < IRB::ColoredFormatter
      # TODO finish colors
      COLORS = {
        :nothing      => NSColor.blackColor,
        :black        => NSColor.blackColor,
        :red          => NSColor.redColor,
        :green        => NSColor.greenColor,
        :brown        => NSColor.brownColor,
        :blue         => NSColor.blueColor,
        :cyan         => NSColor.cyanColor,
        :purple       => NSColor.purpleColor,
        :light_gray   => NSColor.lightGrayColor,
        :dark_gray    => NSColor.darkGrayColor,
        # :light_red    => '1;31',
        # :light_green  => '1;32',
        :light_red    => NSColor.redColor,
        :light_green  => NSColor.greenColor,
        :yellow       => NSColor.yellowColor,
        # :light_blue   => '1;34',
        # :light_cyan   => '1;36',
        # :light_purple => '1;35',
        :light_blue   => NSColor.blueColor,
        :light_cyan   => NSColor.cyanColor,
        :light_purple => NSColor.purpleColor,
        :white        => NSColor.whiteColor,
      }
      
      def colorize_token(type, token)
        if color = color(type)
          attributes = IRB::Cocoa::DEFAULT_ATTRIBUTES.merge(NSForegroundColorAttributeName => COLORS[color])
          NSAttributedString.alloc.initWithString(token, attributes: attributes)
        else
          NSAttributedString.alloc.initWithString(token)
        end
      end
      
      def colorize(str)
        tokens = colorize_tokens(str)
        result = NSMutableAttributedString.alloc.init
        tokens.each { |token| result.appendAttributedString(token) }
        result
      end
      
      def result(object)
        colorize(inspect_object(object))
      end
    end
  end
end

IRB.formatter = IRB::Cocoa::ColoredFormatter.new
$stdout = IRB::Driver::OutputRedirector.new
