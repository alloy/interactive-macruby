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
      output(formatter.result(result))
    end

    def report_exception(exception)
      output(formatter.exception(exception))
    end

    def process_line(line)
      prompt_and_line = formatter.reindent_last_line(self) { @source << line }
      yield(*prompt_and_line) if prompt_and_line && block_given?

      return false if @source.terminate?

      if @source.syntax_error?
        line, error = @line, @source.syntax_error
        @source.pop
        report_syntax_error(line, error)
      elsif @source.code_block?
        evaluate(@source)
        clear_buffer
      end
      @line += 1
      @level = source.level
      
      true
    end

    def report_syntax_error(line, error)
      output(formatter.syntax_error(line, error))
    end
  end

  class Formatter
    def filter_backtrace(backtrace)
      backtrace.reject do |line|
        @filter_from_backtrace.any? { |pattern| pattern.match(line) }
      end.map do |line|
        if m = line.match(/^.+?(\(irb\).+)/)
          m[1]
        else
          line
        end
      end
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

      def report_syntax_error(line, error)
        send_to_view_controller("receivedSyntaxError:", [line, error])
      end
    end

    class ColoredFormatter < IRB::ColoredFormatter
      # TODO add custom colors that are now just aliased
      def color_scheme=(scheme)
        super
        @colors = @colors.inject({}) do |colors, (token_type, color)|
          colors[token_type] = case color
          when :white                 then NSColor.whiteColor
          when :red, :light_red       then NSColor.redColor
          when :green, :light_green   then NSColor.greenColor
          when :brown                 then NSColor.brownColor
          when :blue, :light_blue     then NSColor.blueColor
          when :cyan, :light_cyan     then NSColor.cyanColor
          when :purple, :light_purple then NSColor.purpleColor
          when :light_gray            then NSColor.lightGrayColor
          when :dark_gray             then NSColor.darkGrayColor
          when :yellow                then NSColor.yellowColor
          else
            NSColor.blackColor
          end
          colors
        end
      end

      def colorize_token(type, token)
        attrs = { NSForegroundColorAttributeName => color(type) || NSColor.blackColor }
        NSAttributedString.alloc.initWithString(token, attributes:attrs)
      end

      def colorize(str)
        result = NSMutableAttributedString.new
        Ripper.lex(str).each do |_, type, token|
          result.appendAttributedString(colorize_token(type, token))
        end
        result
      end

      def result(object)
        colorize(inspect_object(object))
      end
    end
  end
end

IRB.formatter = IRB::Cocoa::ColoredFormatter.new
IRB.formatter.color_scheme = :light_background

# TODO This is a bug in MacRuby, for some reason __FILE__ in irb/formatter.rb expand to this file
actual_irb_location = $:.find { |p| File.exist?(File.join(p, 'irb')) }
IRB.formatter.filter_from_backtrace[0] = Regexp.new("^#{actual_irb_location}/irb")

IRB.formatter.filter_from_backtrace << Regexp.new("^#{NSBundle.mainBundle.bundlePath}")
$stdout = IRB::Driver::OutputRedirector.new
