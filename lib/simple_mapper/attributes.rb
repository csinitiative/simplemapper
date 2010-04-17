module SimpleMapper
  class Attribute
    Options = [
      :default,
      :key,
      :type,
    ]
    attr_accessor :key, :name, :type, :default

    def initialize(name, options = {})
      self.key = self.name = name
      process_options(options)
    end

    def process_options(options = {})
      Options.each do |option|
        self.send(:"#{option.to_s}=", options[option]) if options[option]
      end
    end

    def encode(value)
      return value unless type
      converter = type.respond_to?(:encode) ? type : SimpleMapper::Attributes.type_for(type)[:converter]
      converter.encode(value)
    end
  end

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

      def maps(attr, *args)
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
      val = read_source_attribute(attr)
      val = get_attribute_default(attr) if val.nil?
      if type = self.class.simple_mapper.attributes[attr].type
        return type.decode(val) if type.respond_to?(:decode)
        registration = SimpleMapper::Attributes.type_for(type)
        if expected = registration[:expected_type] and val.instance_of? expected
          val
        else
          registration[:converter].decode(val)
        end
      else
        val
      end
    end

    def read_source_attribute(attr)
      key = key_for(attr)
      @simple_mapper_source.has_key?(key) ? @simple_mapper_source[key] : @simple_mapper_source[key.to_s]
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
      attribute = self.class.simple_mapper.attributes[attr]
      case default = attribute.default
        when :from_type
          type = attribute.type
          type = SimpleMapper::Attributes.type_for(type)[:converter] unless type.respond_to?(:default)
          type.default
        when Symbol
          self.send(default)
        else
          nil
      end
    end

    def attribute_changed!(attr)
      @simple_mapper_changes[attr] = true
    end

    def attribute_changed?(attr)
      @simple_mapper_changes.has_key? attr
    end

    def changed_attributes
      @simple_mapper_changes.keys
    end

    def initialize(values = {})
      @simple_mapper_source = values
      @simple_mapper_init = {}
      @simple_mapper_changes = {}
    end

    def to_simple(options = {})
      all = ! options[:defined]
      if options[:changed]
        changes = changed_attributes
        attribs = changes.size > 0 ? self.class.simple_mapper.attributes.values_at(*changes) : []
      else
        attribs = self.class.simple_mapper.attributes.values
      end
      identifier = options[:string_keys] ? Proc.new {|item| item.key.to_s} : Proc.new {|item| item.key}
      attribs.inject({}) do |accum, attrib|
        val = read_attribute(attrib.name)
        if val.respond_to?(:to_simple)
          val = val.to_simple(options.clone)
        elsif attrib.type
          val = attrib.encode(val)
        end
        if all or ! val.nil?
          accum[identifier.call(attrib)] = val
        end
        accum
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

      def create_attribute(*args)
        SimpleMapper::Attribute.new(*args)
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
    end
  end
end

require 'simple_mapper/exceptions'
require 'simple_mapper/attributes/types'

