require 'test_helper'

class AttributeMetaInteractionTest < Test::Unit::TestCase
  context 'Object attribute / meta attribute method' do
    setup do
      @class = Class.new do
        include SimpleMapper::Attributes
        maps :foo
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

      should 'return the source attribute via string key if symbol key does not exist' do
        @class.maps :some_attr
        @instance = @class.new('foo' => 'Foo!', :some_attr => 'Some Attr')
        assert_equal 'Foo!', @instance.read_attribute(:foo)
        assert_equal 'Some Attr', @instance.read_attribute(:some_attr)
      end
    end

    context 'read_attribute' do
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

      should 'return the attribute default if source attribute is nil' do
        @instance = @class.new
        @instance.attribute_object_for(:foo).expects(:default_value).with(@instance).returns('foo default')
        result = @instance.read_attribute(:foo)
        assert_equal 'foo default', result
      end

      context 'with a type converter' do
        setup do
          @expected_out = '_foo_'
          @expected_in = 'Foo!'
          @type_a = mock('type_a')
          @type_a.expects(:decode).with(@expected_in).returns(@expected_out)
          @class.simple_mapper.attributes[:foo].type = @type_a
        end

        should 'transform the source attribute' do
          assert_equal @expected_out, @instance.read_attribute(:foo)
        end

        should 'transform the default value if no source value is defined' do
          @instance = @class.new
          @instance.attribute_object_for(:foo).default = :get_default
          @instance.stubs(:get_default).returns(@expected_in)
          assert_equal @expected_out, @instance.read_attribute(:foo)
        end
      end

      context 'with a type name' do
        setup do
          foo_type = mock('foo_type')
          foo_class = foo_type.class
          @expected_in = 'Foo!'
          @expected_out = 'Foo on Ewe!'
          foo_type.expects(:decode).once.with(@expected_in).returns(@expected_out)
          SimpleMapper::Attributes.stubs(:types).with.returns({:foo_type => {
            :name          => :foo_type,
            :expected_type => foo_class,
            :converter     => foo_type,
          }})
          @class.simple_mapper.attributes[:foo].type = :foo_type
        end

        should 'transform the source attribute if a type name was specified' do
          assert_equal @expected_out, @instance.read_attribute(:foo)
        end

        should 'transform the default value if the source is nil' do
          @instance = @class.new
          @instance.attribute_object_for(:foo).default = :get_default
          @instance.stubs(:get_default).returns(@expected_in)
          assert_equal @expected_out, @instance.read_attribute(:foo)
        end
      end

      should 'not transform the source attr if it is already of the expected type' do
        foo_type = mock('foo too type')
        foo_type.expects(:decode).never
        SimpleMapper::Attributes.expects(:type_for).with(:foo_type).returns({
          :name          => :foo_type,
          :expected_type => String,
          :converter     => foo_type,
        })
        @class.simple_mapper.attributes[:foo].type = :foo_type
        assert_equal 'Foo!', @instance.read_attribute(:foo)
      end

      should 'not transform a written attribute when type was specified' do
        type_a = mock('type_a')
        type_a.expects(:decode).never
        @class.simple_mapper.attributes[:foo].type = type_a
        @instance.write_attribute(:foo, 'blahblah')
        assert_equal 'blahblah', @instance.read_attribute(:foo)
      end
    end

    context 'get_attribute_default' do
      setup do
        @instance = @class.new(:foo => 'foo')
      end

      should 'return nil if the attribute has no default specified' do
        @class.maps :without_default
        assert_equal nil, @instance.get_attribute_default(:without_default)
      end

      should 'invoke specified default symbol on instance if attr has default specified' do
        @class.maps :with_default, :default => :some_default
        @instance.expects(:some_default).once.with.returns('the default value')
        assert_equal 'the default value', @instance.get_attribute_default(:with_default)
      end

      context 'with :default of :from_type' do
        setup do
          @expected_val = 'some default value'
          @name = :with_default
          @type = stub('type', :name => :type_name, :decode => :foo, :encode => :foo2)
          @type.expects(:default).once.with.returns(@expected_val)
        end

        should 'invoke :default on type converter if default is :from_type and :type is object' do
          @class.maps :with_default, :type => @type, :default => :from_type
          assert_equal @expected_val, @instance.get_attribute_default(:with_default)
        end

        should 'invoke :default on registered type if default is :from_type and :type is registered' do
          begin
            SimpleMapper::Attributes.stubs(:types).with.returns({@name => {
              :name           => @name,
              :expected_class => @type.class,
              :converter      => @type}})
            @class.maps :with_default, :type => @name, :default => :from_type
            assert_equal @expected_val, @instance.get_attribute_default(:with_default)
          ensure
            SimpleMapper::Attributes.types.delete @type.name
          end
        end
      end
    end
  end
end
