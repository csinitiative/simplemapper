module SimpleMapper
  class Attribute
    Options = [
      :default,
      :key,
      :type,
      :mapper,
    ]
    attr_accessor :key, :name, :default, :mapper

    def type=(new_type)
      @type = new_type
    end

    def type
      @type || mapper
    end

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

    def to_simple(object, container, options = {})
      raw_value = self.value(object)
      value = mapper ? raw_value.to_simple(options) : encode(raw_value)
      container[options[:string_keys] ? key.to_s : key] = value unless value.nil? and options[:defined]
    end

    def changed!(object)
      object.simple_mapper_changes[name] = true
    end

    def changed?(object)
      (object.simple_mapper_changes[name] && true) || false
    end
  end

end
