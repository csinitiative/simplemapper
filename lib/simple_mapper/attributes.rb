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
      def attributes
        @attributes ||= {}
      end

      def maps(attr)
        attribute = create_attribute(attr)
        install_attribute attr, attribute
      end

      def create_attribute(attr)
        SimpleMapper::Attribute.new(attr)
      end

      def install_attribute(attr, object)
        attr_accessor attr
        attributes[attr] = object
      end
    end
  end
end
