require 'test_helper'

class AttributesTest < Test::Unit::TestCase
  context 'A SimpleMapper::Attributes::Manager' do
    setup do
      @instance = SimpleMapper::Attributes::Manager.new
    end

    should 'has an empty attributes hash' do
      assert @instance.respond_to?(:attributes)
      assert_equal({}, @instance.attributes)
    end

    should 'has an applies_to attribute' do
      assert @instance.respond_to?(:applies_to)
      assert_equal nil, @instance.applies_to
      @instance.applies_to = self
      assert_equal self, @instance.applies_to
    end

    should 'allows specification of applies_to through constructor' do
      @instance = @instance.class.new(self.class)
      assert_equal self.class, @instance.applies_to
    end

    context 'when installing attributes should' do
      setup do
        @class = Class.new
        @instance.applies_to = @class
        @object = @instance.create_attribute(:some_attribute)
        @instance.install_attribute(:some_attribute, @object)
      end

      should 'allow addition of instance attribute to applies_to' do
        assert @class.new.respond_to?(:some_attribute)
        assert @class.new.respond_to?(:some_attribute=)
      end

      should 'add attribute object to attributes list' do
        attribs = @instance.attributes.inject({}) do |a, kvp|
          key, val = kvp
          a[key] = [ val.key, val.class ]
          a
        end
        assert_equal({
            :some_attribute => [:some_attribute, SimpleMapper::Attribute],
          },
          attribs)
      end
    end
  end

  context 'SimpleMapper::Attributes module' do
    setup do
      @class = Class.new do
        include SimpleMapper::Attributes
      end
    end

    context 'inclusion should' do
      should 'provide a maps class method' do
        assert @class.respond_to?(:maps)
      end

      should 'provide a simple_mapper attribute manager' do
        assert @class.respond_to?(:simple_mapper)
        assert_equal SimpleMapper::Attributes::Manager, @class.simple_mapper.class
        assert_equal @class, @class.simple_mapper.applies_to
      end
    end

    context 'maps method should' do
      should 'install an attribute reader on the class' do
        instance = @class.new
        assert ! instance.respond_to?(:some_attr)
        @class.maps :some_attr
        assert instance.respond_to?(:some_attr)
      end

      should 'install an attribute writer on the class' do
        instance = @class.new
        assert ! instance.respond_to?(:some_attr=)
        @class.maps :some_attr
        assert instance.respond_to?(:some_attr=)
      end

      should 'place an Attribute instance in the class manager attributes hash' do
        @class.maps :some_attr
        @class.maps :some_other_attr
        attr_class = SimpleMapper::Attribute
        attribs = @class.simple_mapper.attributes.inject({}) do |a, kvp|
          key, val = kvp
          a[key] = [ val.key, val.class ]
          a
        end
        assert_equal({
            :some_attr => [:some_attr, attr_class],
            :some_other_attr => [:some_other_attr, attr_class],
          },
          attribs)
      end
    end
  end
end
