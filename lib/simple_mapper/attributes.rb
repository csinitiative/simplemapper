module SimpleMapper
  class Attribute
    attr_accessor :key, :name

    def initialize(name, options = {})
      self.key = self.name = name
    end
  end

  module Attributes
    def self.included(klass)
      klass.extend ClassMethods
    end

    module ClassMethods
      def simple_mapper
        @simple_mapper ||= SimpleMapper::Attributes::Manager.new(self)
      end

      def maps(attr)
        attribute = simple_mapper.create_attribute(attr)
        simple_mapper.install_attribute attr, attribute
      end

      def create_attribute(attr)
        SimpleMapper::Attribute.new(attr)
      end

      def install_attribute(attr, object)
        attr_accessor attr
        attributes[attr] = object
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

      def create_attribute(attr)
        SimpleMapper::Attribute.new(attr)
      end

      def install_attribute(attr, object)
        applies_to.module_eval do
          attr_accessor attr
        end
        attributes[attr] = object
      end
    end
  end
end
