module SimpleMapper::Attributes::Types
  module Float
    PATTERN = /^([0-9]+)(?:(\.)([0-9]*))?$/
    def self.decode(value)
      return nil if value.to_s.length == 0
      return value if Float === value
      match = value.match(PATTERN)
      raise(SimpleMapper::TypeConversionException, "Cannot decode '#{value}' to Float.") unless match
      value = match[1]
      value += match[2] + match[3] if match[3].to_s.length > 0
      value.to_f
    end

    def self.encode(value)
      return nil if value.nil?
      raise(SimpleMapper::TypeConversionException, "Cannot encode '#{value}' as Float.") if value.respond_to?(:match) and not value.match(PATTERN)
      value.to_f.to_s
    end
  end
  SimpleMapper::Attributes.register_type(:float, ::Float, Float)

  module String
    def self.decode(value)
      return nil if value.nil?
      value.to_s
    end

    def self.encode(value)
      return nil if value.nil?
      value.to_s
    end
  end
  SimpleMapper::Attributes.register_type(:string, ::String, String)

  module SimpleUUID
    require 'simple_uuid'
    EXPECTED_CLASS = ::SimpleUUID::UUID

    def self.encode(value)
      value.nil? ? nil : value.to_s
    end

    def self.decode(value)
      value.nil? ? nil : EXPECTED_CLASS.new(value)
    end
  end
  SimpleMapper::Attributes.register_type(:simple_uuid, SimpleUUID::EXPECTED_CLASS, SimpleUUID)
end
