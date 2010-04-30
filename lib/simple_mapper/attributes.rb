module SimpleMapper
  module Attributes
    self.instance_eval do
      def types
        @types ||= {}
      end

      def type_for(name)
        types[name]
      end

      def register_type(name, expected_type, converter)
        types[name] = {:name => name, :expected_type => expected_type, :converter => converter}
      end
    end

    def self.included(klass)
      klass.extend ClassMethods
    end

    module ClassMethods
      def simple_mapper
        @simple_mapper ||= SimpleMapper::Attributes::Manager.new(self)
      end

      def maps(attr, *args, &block)
        if block_given?
          hash = args.last
          args << (hash = {}) unless hash.instance_of? Hash
          mapper = simple_mapper.create_anonymous_mapper(&block)
          hash[:type] ||= mapper
          hash[:mapper] = mapper
        end
        attribute = simple_mapper.create_attribute(attr, *args)
        simple_mapper.install_attribute attr, attribute
      end
    end

    def attribute_object_for(attr)
      self.class.simple_mapper.attributes[attr]
    end

    def key_for(attr)
      attribute_object_for(attr).key
    end

    def reset_attribute(attr)
      @simple_mapper_init.delete attr
      remove_instance_variable(:"@#{attr}")
    end

    def write_attribute(attr, value)
      instance_variable_set(:"@#{attr}", value)
      @simple_mapper_init[attr] = true
      attribute_changed! attr
      value
    end

    def transform_source_attribute(attr)
      attribute_object_for(attr).transformed_source_value(self)
    end

    def read_source_attribute(attr)
      attribute_object_for(attr).source_value(self)
    end

    def read_attribute(attr)
      if @simple_mapper_init[attr]
        instance_variable_get(:"@#{attr}")
      else
        result = instance_variable_set(:"@#{attr}", transform_source_attribute(attr))
        @simple_mapper_init[attr] = true
        result
      end
    end

    def get_attribute_default(attr)
      attribute_object_for(attr).default_value(self)
    end

    def simple_mapper_changes
      @simple_mapper_changes ||= {}
    end

    def attribute_changed!(attr)
      attribute_object_for(attr).changed!(self)
    end

    def attribute_changed?(attr)
      attribute_object_for(attr).changed?(self)
    end

    def changed_attributes
      self.class.simple_mapper.attributes.inject([]) do |list, keyval|
        list << keyval[0] if keyval[1].changed?(self)
        list
      end
    end

    attr_reader :simple_mapper_source

    def initialize(values = {})
      @simple_mapper_source = values
      @simple_mapper_init = {}
      @simple_mapper_changes = {}
    end

    def to_simple(options = {})
      changes = (options[:changed] && true) || false
      self.class.simple_mapper.attributes.values.inject({}) do |container, attrib|
        attrib.to_simple(self, container, options) if !changes or attrib.changed?(self)
        container
      end
    end

    class Manager
      attr_accessor :applies_to

      def initialize(apply_to = nil)
        self.applies_to = apply_to if apply_to
      end

      def attributes
        @attributes ||= {}
      end

      def create_attribute(name, options = {})
        attrib_class = options[:attribute_class] || SimpleMapper::Attribute
        attrib_class.new(name, options)
      end

      def install_attribute(attr, object)
        read_body = Proc.new { read_attribute(attr) }
        write_body = Proc.new {|value| write_attribute(attr, value)}
        applies_to.module_eval do
          define_method(attr, &read_body)
          define_method(:"#{attr}=", &write_body)
        end
        attributes[attr] = object
      end

      def create_anonymous_mapper(&block)
        mapper = Class.new do
          include SimpleMapper::Attributes
          def self.decode(*arg)
            new(*arg)
          end
        end
        mapper.module_eval &block if block_given?
        mapper
      end
    end
  end
end

require 'simple_mapper/exceptions'
require 'simple_mapper/attributes/types'

