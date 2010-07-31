module IRB
  module Cocoa
    DEFAULT_ATTRIBUTES = { NSFontAttributeName => NSFont.fontWithName("Menlo Regular", size: 11) }

    module Helper
      def attributedString(string)
        NSAttributedString.alloc.initWithString(string, attributes: DEFAULT_ATTRIBUTES)
      end
      module_function :attributedString
    end

    class BasicNode
      include Helper

      EMPTY_STRING = Helper.attributedString("")
      EMPTY_ARRAY = []

      attr_reader :stringValue

      def initWithStringValue(stringValue)
        if init
          @stringValue = stringValue.is_a?(NSAttributedString) ? stringValue : attributedString(stringValue)
          self
        end
      end

      def initWithPrefix(prefix, stringValue: stringValue)
        if initWithStringValue(stringValue)
          @prefix = prefix.is_a?(NSAttributedString) ? prefix : attributedString(prefix)
          self
        end
      end

      def prefix
        @prefix || EMPTY_STRING
      end

      def expandable?
        false
      end

      def children
        EMPTY_ARRAY
      end

      def ==(other)
        other.class == self.class && other.prefix == prefix && other.stringValue == stringValue
      end

      def to_s
        stringValue.string
      end
    end

    class ExpandableNode < BasicNode
      attr_reader :object

      def initWithObject(object, stringValue: stringValue)
        if initWithStringValue(stringValue)
          @object = object
          self
        end
      end

      def expandable?
        true
      end

      def ==(other)
        super && other.object == object
      end
    end

    class ListNode < ExpandableNode
      def children
        @children ||= @object.map { |s| BasicNode.alloc.initWithStringValue(s) }
      end
    end

    class BlockListNode < ExpandableNode
      def initWithBlockAndStringValue(stringValue, &block)
        if initWithStringValue(stringValue)
          @block = block
          self
        end
      end

      def children
        @children ||= @block.call
      end
    end

    # Object wrapper nodes

    class ObjectNode < ExpandableNode
      class << self
        attr_accessor :children
      end

      self.children = [
        :classNode,
        :publicMethodsNode,
        :objcMethodsNode,
        :instanceVariablesNode
      ]

      def initWithObject(object)
        if init
          @object = object
          self
        end
      end

      def stringValue
        @stringValue ||= IRB.formatter.result(@object)
      end

      def children
        @children ||= self.class.children.map { |m| send(m) }.compact
      end

      def classNode
        ModNode.alloc.initWithObject(@object.class,
                        stringValue: "Class: #{@object.class.name}")
      end

      def publicMethodsNode
        methods = @object.methods(false)
        unless methods.empty?
          BlockListNode.alloc.initWithBlockAndStringValue("Public methods") do
            methods.map { |name| BasicNode.alloc.initWithStringValue(name) }
          end
        end
      end

      def objcMethodsNode
        methods = @object.methods(false, true) - @object.methods(false)
        unless methods.empty?
          BlockListNode.alloc.initWithBlockAndStringValue("Objective-C methods") do
            methods.map { |name| BasicNode.alloc.initWithStringValue(name) }
          end
        end
      end

      def instanceVariablesNode
        variables = @object.instance_variables
        unless variables.empty?
          BlockListNode.alloc.initWithBlockAndStringValue("Instance variables") do
            variables.map do |name|
              obj = @object.instance_variable_get(name)
              ObjectNode.alloc.initWithObject(obj, stringValue: name)
            end
          end
        end
      end
    end

    class ModNode < ObjectNode
      self.children = [
        :modTypeNode,
        :ancestorNode,
        :publicMethodsNode,
        :objcMethodsNode,
        :instanceVariablesNode
      ]

      def modTypeNode
        BasicNode.alloc.initWithStringValue("Type: #{@object.class == Class ? 'Class' : 'Module'}")
      end

      def ancestorNode
        BlockListNode.alloc.initWithBlockAndStringValue("Ancestors") do
          @object.ancestors[1..-1].map do |mod|
            ModNode.alloc.initWithObject(mod, stringValue: mod.name)
          end
        end
      end
    end
  end
end
