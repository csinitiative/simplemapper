class SimpleMapper::Attribute::Pattern < SimpleMapper::Attribute
  include SimpleMapper::Attribute::Collection

  attr_reader :pattern

  def initialize(name, options = {})
    super(name, options)
    self.pattern = options[:pattern]
  end

  def pattern=(value)
    raise SimpleMapper::InvalidPatternException unless value.respond_to?(:match)
    @pattern = value
  end

  def member_key?(key)
    (pattern.match(key.to_s) and true) or false
  end
end
