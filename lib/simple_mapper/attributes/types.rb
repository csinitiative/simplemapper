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
      value.to_s.to_f
    end

    # Encodes a float-like +value+ as a string, conforming to the basic
    # syntax used for +decode+.
    def self.encode(value)
      return nil if value.nil?
      if ! value.respond_to?(:to_f) or value.respond_to?(:match) && ! value.match(PATTERN)
        raise(SimpleMapper::TypeConversionException, "Cannot encode '#{value}' as Float.")
      end
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
  # instances of <tt>SimpleUUID::UUID</tt> or GUID strings.  Attributes
  # using this type will store the data simply as a GUID-conforming string
  # as implemented by +SimpleUUID::UUID#to_guid+.  For both decoding and
  # encoding, a GUID string or an actual +SimpleUUID::UUID+ instance may
  # be provided, but the result is always the corresponding GUID string.
  #
  # Registered as <tt>:simple_uuid</tt>.
  module SimpleUUID
    require 'simple_uuid'
    EXPECTED_CLASS = ::SimpleUUID::UUID

    # Encoded a <tt>SimpleUUID::UUID</tt> instance, or a GUID string,
    # as a GUID string.  GUID strings for +value+ will be validated by
    # +SimpleUUID::UUID+ prior to passing through as the result.
    #
    # Passes nils through unchanged.
    def self.encode(value)
      normalize(value)
    end

    # Decode a <tt>SimpleUUID::UUID</tt> instance or GUID string into
    # validated GUID string; strings will be validated by +SimpleUUID::UUID+
    # prior to passing through as the result.
    #
    # Passes nils through unchanged.
    def self.decode(value)
      normalize(value)
    end

    def self.normalize(value)
      value.nil? ? nil : EXPECTED_CLASS.new(value).to_guid
    end

    # Returns a new GUID string value.
    def self.default
      EXPECTED_CLASS.new.to_guid
    end
  end
  SimpleMapper::Attributes.register_type(:simple_uuid, nil, SimpleUUID)

  # Provides timezone-aware second-resolution timestamp support for
  # basic attributes.
  #
  # Attributes of this type will have values that are instances of +DateTime+.
  # These +DateTime+ values will be reduced to strings of format +'%Y-%m-%d %H:%M:%S%z'+
  # when converting to a simple structure.
  #
  # On input, a +DateTime+ instance or a string matching the above format will be
  # accepted and map to the proper +DateTime+.
  #
  # Decoding or encoding nils will simply pass nil through.
  #
  # Registered as type +:timestamp+
  module Timestamp
    require 'date'

    FORMAT = '%Y-%m-%d %H:%M:%S%z'

    # Encode a +DateTime+ _value_ as a string of format +'%Y-%m-%d %H:%M:%S%z'+.
    # Given +nil+ for _value, +nil+ will be returned.
    def self.encode(value)
     return nil if value.nil?
     value.strftime FORMAT
    end

    # Decode a _value_ string of format +'%Y-%m-%d %H:%M:%S%z' into a +DateTime+ instance.
    # If given a +DateTime+ instance for _value_, that instance will be returned.
    # Given +nil+ for _value_, +nil+ will be returned.
    def self.decode(value)
      return nil if value.nil?
      return value if value.instance_of? DateTime
      DateTime.strptime(value, FORMAT)
    end

    # Return a new +DateTime+ instance representing the current time.  Note that this
    # will include fractional seconds; this precision is lost when encoded to string,
    # as the string representation only has a precision to the second.
    def self.default
      DateTime.now
    end
  end
  SimpleMapper::Attributes.register_type(:timestamp, DateTime, Timestamp)
end
