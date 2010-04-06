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

    context 'when creating new attributes should' do
      setup do
        @class = Class.new
        @instance.applies_to = @class
      end

      should 'pass :type option through to attribute object' do
        type_a = mock('type_a')
        attrib = @instance.create_attribute(:attrib, :type => type_a)
        assert_equal type_a, attrib.type
      end

      should 'pass :key option through if provided' do
        attrib = @instance.create_attribute(:attrib, :key => :not_attrib)
        assert_equal :not_attrib, attrib.key
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

    context 'instance method' do
      setup do
        @instance = @class.new
        @class.maps :foo
      end
      context 'reset_attribute should' do
        should 'restore the specified attribute to its source value' do
          @instance = @class.new(:foo => 'Foo!')
          @instance.write_attribute(:foo, 'new val')
          assert_equal 'new val', @instance.read_attribute(:foo)
          @instance.reset_attribute(:foo)
          assert_equal 'Foo!', @instance.read_attribute(:foo)
        end
      end
      context 'read_attribute should' do
        setup do
          @instance = @class.new(:foo => 'Foo!', :some_attr => 'Some Attr')
        end

        should 'return the source attribute by default' do
          assert_equal 'Foo!', @instance.read_attribute(:foo)
        end

        should 'return the updated attribute if one exists' do
          @instance.write_attribute(:foo, 'Blah!')
          assert_equal 'Blah!', @instance.read_attribute(:foo)
        end

        should 'transform the source attribute if a type was specified' do
          type_a = mock('type_a')
          type_a.expects(:decode).with('Foo!').returns('_foo_')
          @class.simple_mapper.attributes[:foo].type = type_a
          assert_equal '_foo_', @instance.read_attribute(:foo)
        end

        should 'not transform a written attribute when type was specified' do
          type_a = mock('type_a')
          type_a.expects(:decode).never
          @class.simple_mapper.attributes[:foo].type = type_a
          @instance.write_attribute(:foo, 'blahblah')
          assert_equal 'blahblah', @instance.read_attribute(:foo)
        end
      end
      context 'read_source_attribute' do
        setup do
          @instance = @class.new(:foo => 'Foo!')
        end

        should 'return the attribute specified from the source hash' do
          assert_equal 'Foo!', @instance.read_source_attribute(:foo)
        end

        should 'return the attribute from source even if updated locally' do
          @instance.write_attribute(:foo, 'Blah!')
          assert_equal 'Blah!', @instance.read_attribute(:foo)
          assert_equal 'Foo!', @instance.read_source_attribute(:foo)
        end
      end
      context 'write_attribute should' do
        should 'set the attribute as an instance variable' do
          @instance.write_attribute(:foo_attr, 'Foo!')
          assert_equal 'Foo!', @instance.instance_variable_get(:@foo_attr)
        end
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

      should 'accept a :type option that carries over to the Attribute instance' do
        type_a = stub('type_a')
        @class.maps :foo, :type => type_a
        type_b = stub('type_b')
        @class.maps :bar, :type => type_b

        assert_equal type_a, @class.simple_mapper.attributes[:foo].type
        assert_equal type_b, @class.simple_mapper.attributes[:bar].type
      end
    end
  end
end
