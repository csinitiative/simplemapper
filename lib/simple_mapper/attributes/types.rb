module SimpleMapper::Attributes::Types
  # Provides basic support for floating point numbers, closely tied to
  # the core Ruby :Float:.
  #
  # Registered as type <tt>:float</tt>
  #
  # This is intended to be reasonably flexible and work with inputs
  # that look numeric whether or not they literally appear to be "floats".
  module Float
    PATTERN = /^([0-9]+)(?:(\.)([0-9]*))?$/

    # Decode a numeric-looking +value+ (whether a string or otherwise) into
    # a +Float+.
    #
    # String inputs for +value+ should be numeric and may or may not have
    # a decimal point, with or without digits following the decimal point.
    # Therefore, the following values would all decode nicely:
    #  * +"14"+ to +14.0+
    #  * +"0"+ to +0.0+
    #  * +"123."+ to +123.0+
    #  * +"100.22022"+ to +100.22022+
    #  * +"0.0001"+ to +0.0001+
    #  * +14+ to +14.0+
    #  * +0+ to +0.0+
    #
    # The empty string will result in a value of +nil+
    def self.decode(value)
      return nil if (str = value.to_s).length == 0
      return value if Float === value
      match = str.match(PATTERN)
      raise(SimpleMapper::TypeConversionException, "Cannot decode '#{value}' to Float.") unless match
      value = match[1]
      value += match[2] + match[3] if match[3].to_s.length > 0
      value.to_f
    end

    # Encodes a float-like +value+ as a string, conforming to the basic
    # syntax used for +decode+.
    def self.encode(value)
      return nil if value.nil?
      raise(SimpleMapper::TypeConversionException, "Cannot encode '#{value}' as Float.") if value.respond_to?(:match) and not value.match(PATTERN)
      value.to_f.to_s
    end

    # Returns the type default value of +nil+.
    def self.default
      nil
    end
  end
  SimpleMapper::Attributes.register_type(:float, ::Float, Float)

  # Provides simple string type support.
  #
  # Registered as <tt>:string</tt>.
  #
  # This is intended to be quite flexible and rely purely on duck typing.
  # It should work with any input that supports <tt>:to_s</tt>, and is
  # not strictly limited to actual +String+ instances.
  module String
    # Decodes +value+ into a +String+ object via the <tt>:to_s</tt> of
    # +value+.  Passes nils through unchanged.  For the majority use case,
    # most of the time the result and the input will be equal.
    def self.decode(value)
      return nil if value.nil?
      value.to_s
    end

    # Encodes +value+ as a string via its <tt>:to_s</tt> method.  Passes nils
    # through unchanged.
    def self.encode(value)
      return nil if value.nil?
      value.to_s
    end

    # Returns the empty string for a "default".
    def self.default
      ''
    end
  end
  SimpleMapper::Attributes.register_type(:string, ::String, String)

  # Provides basic UUID type support derived from the +simple_uuid+ gem.
  #
  # Passes nils through unchanged, but otherwise expects to work with
  # instances of <tt>SimpleUUID::UUID</tt>.  Encoding/decoding converts
  # between instances of this class and a byte string (which the class
  # itself supports).
  #
  # Registered as <tt>:simple_uuid</tt>.
  module SimpleUUID
    require 'simple_uuid'
    EXPECTED_CLASS = ::SimpleUUID::UUID

    # Encoded a <tt>SimpleUUID::UUID</tt> instance as a byte string.
    # Passes nils through unchanged.
    def self.encode(value)
      value.nil? ? nil : value.to_s
    end

    # Decode a byte string into a <tt>SimpleUUID::UUID</tt> instance.
    # Passes nils through unchanged.
    def self.decode(value)
      value.nil? ? nil : EXPECTED_CLASS.new(value)
    end

    # Returns a new <tt>SimpleUUID::UUID</tt> instance.
    def self.default
      EXPECTED_CLASS.new
    end
  end
  SimpleMapper::Attributes.register_type(:simple_uuid, SimpleUUID::EXPECTED_CLASS, SimpleUUID)
end
