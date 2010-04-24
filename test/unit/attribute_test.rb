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
end
