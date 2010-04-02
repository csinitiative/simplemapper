require 'test_helper'

class AttributesTest < Test::Unit::TestCase
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

      should 'provide an attributes class list' do
        assert @class.respond_to?(:attributes)
        assert_equal({}, @class.attributes)
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

      should 'place an Attribute instance in the class attributes hash' do
        @class.maps :some_attr
        @class.maps :some_other_attr
        attr_class = SimpleMapper::Attribute
        attribs = @class.attributes.inject({}) do |a, kvp|
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
