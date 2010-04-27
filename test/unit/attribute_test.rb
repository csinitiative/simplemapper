require 'test_helper'

class AttributeTest < Test::Unit::TestCase
  context 'A SimpleMapper::Attribute instance' do
    setup do
      @name = :some_name
      @instance = SimpleMapper::Attribute.new(@name)
    end

    should 'have a name attribute' do
      assert_equal @name, @instance.name
      assert_equal :foo, @instance.name = :foo
      assert_equal :foo, @instance.name
    end

    should 'have a key attribute that defaults to the name' do
      assert_equal @name, @instance.key
      assert_equal :some_key, @instance.key = :some_key
      assert_equal :some_key, @instance.key
    end

    should 'have a type attribute' do
      assert_equal nil, @instance.type
      assert_equal :some_type, @instance.type = :some_type
      assert_equal :some_type, @instance.type
    end

    should 'have a default attribute' do
      assert_equal nil, @instance.default
      assert_equal :some_default, @instance.default = :some_default
      assert_equal :some_default, @instance.default
    end

    should 'have a mapper attribute' do
      assert_equal nil, @instance.mapper
      assert_equal :some_mapper, @instance.mapper = :some_mapper
      assert_equal :some_mapper, @instance.mapper
    end

    should 'get value from instance argument' do
      target = mock('target')
      target.stubs(@name).with.returns(:foo)
      assert_equal :foo, @instance.value(target)
    end

    context 'change tracking' do
      setup do
        @changes = {}
        @object = stub('object', :simple_mapper_changes => @changes)
      end

      should 'mark the attribute as changed within an instance.simple_mapper_changes hash when instance given to :changed!' do
        @instance.changed!(@object)
        assert_equal({@name => true}, @changes)
      end

      should 'return truth of changed state for attribute on instance provided to :changed? based on instance.simple_mapper_changes' do
        assert_equal false, @instance.changed?(@object)
        @changes[@name] = true
        assert_equal true, @instance.changed?(@object)
      end
    end

    context 'when encoding' do
      should 'pass through the value when type is undefined' do
        assert_equal :foo, @instance.encode(:foo)
      end

      should 'convert the value with type.encode if type is a convertor' do
        type = stub('type')
        type.expects(:encode).with(:foo).returns(:foo_too)
        @instance.type = type
        assert_equal :foo_too, @instance.encode(:foo)
      end

      should 'convert the value with type from registry if type is registered' do
        type = stub('type')
        type.expects(:encode).with(:foo).returns(:foo_too)
        SimpleMapper::Attributes.expects(:type_for).with(:some_type).returns({:converter => type})
        @instance.type = :some_type
        assert_equal :foo_too, @instance.encode(:foo)
      end

      should 'throw an InvalidTypeException if type is specified but is not a convertor' do
        @instance.type = stub('no type')
        assert_raise(SimpleMapper::InvalidTypeException) { @instance.encode(:foo) }
      end
    end
  end

  context 'the SimpleMapper::Attribute constructor' do
    setup do
      @class = SimpleMapper::Attribute
    end

    should 'allow specification of key in constructor' do
      instance = @class.new(:name, :key => :some_key)
      assert_equal :some_key, instance.key
    end

    should 'allow specification of type in constructor' do
      instance = @class.new(:name, :type => :some_type)
      assert_equal :some_type, instance.type
    end

    should 'allow specification of default in constructor' do
      instance = @class.new(:name, :default => :some_default)
      assert_equal :some_default, instance.default
    end

    should 'allow specification of mapper in constructor' do
      instance = @class.new(:name, :mapper => :some_mapper)
      assert_equal :some_mapper, instance.mapper
    end
  end

  context 'the SimpleMapper::Attribute :to_simple method' do
    setup do
      @name      = :some_attribute
      @key       = :some_attribute_key
      @class     = SimpleMapper::Attribute
      @instance  = @class.new(@name, :key => @key)
      @value     = 'some_attribute_value'

      # the container is provided in each :to_simple call; it's where the
      # simplified representation of the attribute/value should go.
      # We want it to start as non-empty so the test can verify that the
      # to_simple operation is additive rather than destructive
      @container = {:preserve_me => :or_else}

      @object    = stub('object')
      @object.stubs(@name).returns(@value)
    end

    context 'for an untyped attribute' do
      should 'assign the attribute value as key/pair to the provided container' do
        result = @container.clone
        result[@key] = @value
        @instance.to_simple @object, @container
        assert_equal result, @container
      end

      should 'not assign key/value if :defined is true and value is nil' do
        @object.stubs(@name).returns(nil)
        result = @container.clone
        @instance.to_simple @object, @container, :defined => true
        assert_equal result, @container
      end

      should 'assign attr value as key/val pair if :defined is true and value is !nil' do
        result = @container.clone
        result[@key] = @value
        @instance.to_simple @object, @container, :defined => true
        assert_equal result, @container
      end

      should 'use string keys instead of symbols if :string_keys option is true' do
        result = @container.clone
        result[@key.to_s] = @value
        @instance.to_simple @object, @container, :string_keys => true
        assert_equal result, @container
      end

      should 'invoke to_simple on value rather than encoding if mapper is set' do
        @instance.mapper = mapper = mock('mapper')
        options = {:some_useless_option => :me}
        @value.expects(:to_simple).with(options).returns(:something_simple)
        result = @container.clone
        result[@key] = :something_simple
        @instance.to_simple @object, @container, options
        assert_equal result, @container
      end

      should 'use the mapper as type if a mapper is set' do
        @instance.mapper = mapper = mock('mapper')
        assert_equal mapper, @instance.type
      end
    end

    context 'for a typed attribute' do
      setup do
        @type = stub('type')
        @type.stubs(:encode).with(@value).returns(@encoded_value = :some_encoded_value)
        @instance.type = @type
      end

      should 'assign the encoded attribute value as key/pair to the provided container' do
        result = @container.clone
        result[@key] = @encoded_value
        @instance.to_simple @object, @container
        assert_equal result, @container
      end

      should 'not assign key/value if :defined is true and encoded value is nil' do
        @type.stubs(:encode).with(@value).returns(nil)
        result = @container.clone
        @instance.to_simple @object, @container, :defined => true
        assert_equal result, @container
      end

      should 'assign encoded attr value as key/val pair if :defined is true and value is !nil' do
        result = @container.clone
        result[@key] = @encoded_value
        @instance.to_simple @object, @container, :defined => true
        assert_equal result, @container
      end

      should 'use string keys instead of symbols if :string_keys option is true' do
        result = @container.clone
        result[@key.to_s] = @encoded_value
        @instance.to_simple @object, @container, :string_keys => true
        assert_equal result, @container
      end

      should 'use specified type when set rather than using the mapper' do
        @instance.mapper = mapper = mock('mapper')
        assert_equal @type, @instance.type
      end
    end
  end
end