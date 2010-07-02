# Include in a SimpleMapper::Attribute to give it collection behaviors:
#  * have an attribute be a collection (i.e. a hash or array) of values
#    rather than a single value
#  * map N keys from a source value to the attribute, based on the +:member_key?+ test
#  * map keys/values from the collection object back to a "source" structure
module SimpleMapper::Attribute::Collection
  # Given an _object_ that has the attribute represented by the receiver,
  # returns the source value for the attribute after applying defaults and types.
  # The type check is applied to either the raw source value (if one exists) or
  # the default value (if no source exists and a default was specified for the attribute).
  #
  # Type checking is not enforced here; it is expected that +:source_value+,
  # +:default_value+, and +:apply_type+ will all return objects of the expected collection
  # type (or consistent interface).
  def transformed_source_value(object)
    val = source_value(object)
    val = default_value(object) if val.nil?
    val = apply_type(val) if type
    val.change_tracking = true if val.respond_to?(:change_tracking)
    val
  end

  def member_key?(key)
    false
  end

  def source_value(object)
    object.simple_mapper_source.inject(new_collection) do |hash, keyval|
      hash[from_simple_key(keyval[0])] = keyval[1] if member_key?(keyval[0])
      hash
    end
  end

  # If the receiver has a valid type specified, returns a new collection based on
  # _value_, with the key/value pairs from _value_ but each value encoded by
  # the type converter.
  def apply_type(value)
    converter = self.converter
    value.inject(new_collection) do |hash, keyval|
      hash[keyval[0]] = converter.decode(keyval[1])
      hash
    end
  end

  # Returns a new collection object to be used as the basis for building the attribute's
  # value collection; by default, returns instances of SimpleMapper::Collection::Hash.
  # Override this to alter the kinds of collections your attributes work with.
  def new_collection
    h = SimpleMapper::Collection::Hash.new
    h.attribute = self
    h
  end

  # Given a _key_ from the source structure (the "simple structure"), returns a
  # transformed key as it will be entered in the attribute's collection value.
  # By default, this simply passes through _key_, but it can be overridden to
  # allow for more sophisticated source/object mappings.
  def from_simple_key(key)
    key
  end

  # The reverse of +:to_simple_key+, given a _key_ from the attribute collection,
  # returns the transformed version of that key as it should appear in the "simple"
  # representation of the object.
  def to_simple_key(key)
    key
  end

  def freeze_for(object)
    val = value(object)
    if val
      if mapper
        if val.respond_to?(:values)
          val.values.each {|member| member.freeze}
        else
          val.each {|member| member.freeze}
        end
      end
      val.freeze
    end
  end

  def changed?(object)
    val = value(object)
    return true if val.changed_members.size > 0
    return true if mapper and val.find {|keyval| keyval[1].changed?}
    false
  end

  # Converts the _object_'s attribute value into its simple representation,
  # putting the keys/values into _container_.  This is conceptually consistent
  # with +SimpleMapper::Attributes#to_simple+, but adds a few collection-oriented
  # concerns:
  #  * the attribute's value is assumed to be a collection with N key/value pairs
  #    to be mapped into _container_
  #  * the keys are transformed via +:to_simple_key+ on their way into _container_.
  #
  # This will work with any kind of _container_ that can be assigned to via +[]=+,
  # and any value for the attribute that supports +:inject+ in the same manner as
  # a Hash (yields the accumulated value and a key/value pair to the block).
  def to_simple(object, container, options = {})
    val = value(object)
    mapper = self.mapper
    strings = options[:string_keys] || false
    changed_members = change_tracking_for(val)
    if options[:changed]
      if mapper
        change_proc = Proc.new do |key, val|
          changed_members[key] or (! val.nil? and val.changed?)
        end
      else
        change_proc = Proc.new {|k, v| changed_members[k]}
      end
    else
      change_proc = nil
    end
    changes = options[:changed] || false
    container = val.inject(container) do |hash, keyvalue|
      key = to_simple_key(keyvalue[0])
      hash[strings ? key.to_s : key] = mapper ? keyvalue[1].to_simple(options) : encode(keyvalue[1]) if ! change_proc or change_proc.call(*keyvalue)
      hash
    end
    if (change_proc or options[:all]) and ! options[:defined]
      changed_members.keys.find_all {|x| ! val.is_member?(x)}.each do |key|
        container[to_simple_key(key)] = nil
      end
    end
    container
  end
end
