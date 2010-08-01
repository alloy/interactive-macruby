module IRB
  module Cocoa
    class BasicNode
      EMPTY_STRING = ""
      EMPTY_ARRAY = []

      attr_reader :value

      def initWithValue(value)
        if init
          @value = value
          self
        end
      end

      def initWithPrefix(prefix, value: value)
        if initWithValue(value)
          @prefix = prefix
          self
        end
      end

      alias_method :id, :object_id

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
        other.class == self.class && other.prefix == prefix && other.value == value
      end

      def to_s
        value
      end
    end

    class ExpandableNode < BasicNode
      attr_reader :object

      def initWithObject(object, value: value)
        if initWithValue(value)
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
        @children ||= @object.map { |s| BasicNode.alloc.initWithValue(s) }
      end
    end

    class BlockListNode < ExpandableNode
      def initWithBlockAndvalue(value, &block)
        if initWithValue(value)
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
        def nodeForObject(object)
          klass = case object
          when Module then ModNode
          when NSImage then NSImageNode
          else
            ObjectNode
          end
          klass.alloc.initWithObject(object)
        end

        attr_accessor :children
      end

      self.children = [
        :descriptionNode,
        :classNode,
        :publicMethodsNode,
        :objcMethodsNode,
        :instanceVariablesNode
      ]

      def initWithObject(object)
        if init
          @object = object
          @showDescriptionNode = false
          self
        end
      end

      def initWithObject(object, value: value)
        if super
          @showDescriptionNode = true
          self
        end
      end

      def value
        @value ||= objectDescription
      end

      def objectDescription
        IRB.formatter.result(@object)
      end

      def children
        @children ||= self.class.children.map { |m| send(m) }.compact
      end

      def descriptionNode
        if @showDescriptionNode
          ListNode.alloc.initWithObject([objectDescription], value: "Description")
        end
      end

      def classNode
        ModNode.alloc.initWithObject(@object.class,
                        value: "Class: #{@object.class.name}")
      end

      def publicMethodsNode
        methods = @object.methods(false)
        unless methods.empty?
          ListNode.alloc.initWithObject(methods, value: "Public methods")
        end
      end

      def objcMethodsNode
        methods = @object.methods(false, true) - @object.methods(false)
        unless methods.empty?
          ListNode.alloc.initWithObject(methods, value: "Objective-C methods")
        end
      end

      def instanceVariablesNode
        variables = @object.instance_variables
        unless variables.empty?
          BlockListNode.alloc.initWithBlockAndvalue("Instance variables") do
            variables.map do |name|
              obj = @object.instance_variable_get(name)
              ObjectNode.alloc.initWithObject(obj, value: name)
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
        BasicNode.alloc.initWithValue("Type: #{@object.class == Class ? 'Class' : 'Module'}")
      end

      def ancestorNode
        BlockListNode.alloc.initWithBlockAndvalue("Ancestors") do
          @object.ancestors[1..-1].map do |mod|
            ModNode.alloc.initWithObject(mod, value: mod.name)
          end
        end
      end
    end

    class NSImageNode < ObjectNode
      self.children = [:classNode, :publicMethodsNode, :objcMethodsNode, :instanceVariablesNode]

      def value
        @object
      end
    end
  end
end
