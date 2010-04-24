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

    def value(object)
      object.send(name)
    end

    def converter
      return nil unless type
      converter = type.respond_to?(:encode) ? type : (t = SimpleMapper::Attributes.type_for(type) and t[:converter])
      raise SimpleMapper::InvalidTypeException unless converter
      converter
    end

    def encode(value)
      return value unless c = converter
      c.encode(value)
    end
  end

end
