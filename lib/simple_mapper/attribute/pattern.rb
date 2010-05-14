class SimpleMapper::Attribute::Pattern < SimpleMapper::Attribute
  attr_reader :pattern

  def initialize(name, options = {})
    super(name, options)
    self.pattern = options[:pattern]
  end

  def pattern=(value)
    raise SimpleMapper::InvalidPatternException unless value.respond_to?(:match)
    @pattern = value
  end

  def source_value(object)
    object.simple_mapper_source.inject(new_collection) do |hash, keyval|
      hash[from_simple_key(keyval[0])] = keyval[1] if pattern.match(keyval[0].to_s)
      hash
    end
  end

  def transformed_source_value(object)
    val = source_value(object)
    val = default_value(object) if val.nil?
    type ? apply_type(val) : val
  end

  def apply_type(value)
    converter = self.converter
    value.inject(new_collection) do |hash, keyval|
      hash[keyval[0]] = converter.decode(keyval[1])
      hash
    end
  end

  def new_collection
    h = SimpleMapper::Collection::Hash.new
    h.attribute = self
    h
  end

  def from_simple_key(key)
    key
  end

  def to_simple_key(key)
    key
  end

  def to_simple(object, container, options = {})
    val = value(object)
    mapper = self.mapper
    strings = options[:string_keys] || false
    val.inject(container) do |hash, keyvalue|
      key = to_simple_key(keyvalue[0])
      container[strings ? key.to_s : key] = mapper ? keyvalue[1].to_simple(options) : encode(keyvalue[1])
      container
    end
  end
end
