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

    should 'get value from instance argument' do
      target = mock('target')
      target.stubs(@name).with.returns(:foo)
      assert_equal :foo, @instance.value(target)
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
  end

  context 'the SimpleMapper::Attribute :to_simple method' do
    setup do
      @name      = :some_attribute
      @key       = :some_attribute_key
      @class     = SimpleMapper::Attribute
      @instance  = @class.new(@name, :key => @key)
      @value     = :some_attribute_value

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
    end

    context 'for a typed attribute' do
      setup do
        @type = stub('type')
        @type.stubs(:encode).with(@value).returns(@encoded_value = :some_encoded_value)
        @instance.stubs(:type).returns(@type)
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
    end
  end
end
