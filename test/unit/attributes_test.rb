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

      should 'install attribute reader wrapping the read_attribute method' do
        @mapper_instance = @class.new
        @mapper_instance.expects(:read_attribute).with(:some_attribute).once
        @mapper_instance.some_attribute
      end

      should 'install attribute writer wrapping the write_attribute method' do
        @mapper_instance = @class.new
        @mapper_instance.expects(:write_attribute).with(:some_attribute, :some_value).once
        @mapper_instance.some_attribute = :some_value
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

    context 'types registry' do
      setup do
        @fake_type = stub('fake_type')
        @fake_expected_type = Class.new { attr_accessor :value }
        @fake_type_symbol = :fake_for_test
        @fake_registry_entry = {:name          => @fake_type_symbol,
                                :expected_type => @fake_expected_type,
                                :converter     => @fake_type,}
      end

      should 'provide a types registry hash' do
        assert_equal Hash, SimpleMapper::Attributes.types.class
      end

      should 'provide type registration through :register_type' do
        SimpleMapper::Attributes.register_type(@fake_type_symbol,
                                               @fake_expected_type,
                                               @fake_type)

        assert_equal(@fake_registry_entry,
                     SimpleMapper::Attributes.types[@fake_type_symbol])
      end

      should 'allow lookup of type info by name' do
        SimpleMapper::Attributes.register_type(@fake_type_symbol,
                                               @fake_expected_type,
                                               @fake_type)
        assert_equal(@fake_registry_entry,
                     SimpleMapper::Attributes.type?(@fake_type_symbol))
      end

      should 'return nil on type lookup for unknown type' do
        assert_equal nil, SimpleMapper::Attributes.type?(:i_do_not_exist)
      end

      teardown do
        SimpleMapper::Attributes.types.delete @fake_type_symbol
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

    should 'return an empty hash for to_simple on an instance with no attributes' do
      assert_equal({}, @class.new.to_simple)
    end

    context 'to_simple instance method' do
      setup do
        @class.maps :no_type
      end

      should 'return a hash with key/value per known attribute' do
        @class.maps :other
        @instance = @class.new( :no_type => 'no type', :other => 'Other!' )
        assert_equal( {:no_type => 'no type', :other => 'Other!'}, @instance.to_simple )
      end

      should 'return hash whose key/value pairs follow attribute state' do
        @class.maps :other
        @instance = @class.new( :no_type => 'original', :other => 'original' )
        @instance.other = 'updated'
        assert_equal({:no_type => 'original', :other => 'updated'}, @instance.to_simple)
      end

      should 'map attributes to specified keys in returned hash' do
        @class.maps :other, :key => :alt_key
        @instance = @class.new
        @instance.no_type = 'no type'
        @instance.other = 'alt key'
        assert_equal({:no_type => 'no type', :alt_key => 'alt key'}, @instance.to_simple)
      end

      should 'return a hash with strings for keys when :string_keys option is true' do
        @class.maps :other, :key => :alt_key
        @instance = @class.new
        @instance.no_type = 'no type'
        @instance.other = 'alt key'
        assert_equal({'no_type' => 'no type', 'alt_key' => 'alt key'},
                     @instance.to_simple(:string_keys => true))
      end

      should 'encode typed attribute values for converter types' do
        @type = Object.new
        @type.instance_eval do
          def encode(value)
            "encoded: #{value}"
          end
          def decode(value)
            value
          end
        end
        @class.maps :typed, :type => @type
        @instance = @class.new( :typed => 'typed!' )
        assert_equal 'encoded: typed!', @instance.to_simple[:typed]
      end

      should 'encode typed attribute values for registered types' do
        @type = mock('type')
        @type.expects(:encode).once.with('typed!').returns('encoded!')
        @type.stubs(:decode).returns('typed!')
        SimpleMapper::Attributes.expects(:type?).with(:type).at_least_once.returns({
          :name          => :type,
          :expected_type => @type.class,
          :converter     => @type,
        })
        @class.maps :typed, :type => :type
        @instance = @class.new( :typed => 'typed!' )
        assert_equal 'encoded!', @instance.to_simple[:typed]
      end

      context 'with :defined argument' do
        should 'return a hash with key/value per defined attribute' do
          @class.maps :undefined
          assert_equal({:no_type => 'nt'}, @class.new({:no_type => 'nt'}).to_simple(:defined => true))
        end

        should 'return an empty hash if no attributes were set' do
          assert_equal({}, @class.new.to_simple(:defined => true))
        end
      end

      context 'with :changes argument' do
        setup do
          @class.maps :other
          @instance = @class.new({:typed => 'typed', :other => 'other'})
        end

        should 'return an empty hash if no attributes were changed' do
          assert_equal({}, @instance.to_simple(:changed => true))
        end

        should 'return a hash of only the key/value pairs that were changed' do
          @instance.other = 'udder'
          assert_equal({:other => 'udder'}, @instance.to_simple(:changed => true))
        end
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
          @instance.expects(:get_attribute_default).with(:foo).returns('foo default')
          assert_equal 'foo default', @instance.read_attribute(:foo)
        end

        context 'with a type converter' do
          setup do
            @expected_out = '_foo_'
            @expected_in = 'Foo!'
            @type_a = mock('type_a')
            @type_a.expects(:decode).with(@expected_in).returns(@expected_out)
            @class.simple_mapper.attributes[:foo].type = @type_a
          end

          should 'transform the source attribute if a type converter was specified' do
            assert_equal @expected_out, @instance.read_attribute(:foo)
          end

          should 'transform the default value if a type converter was specified' do
            @instance = @class.new
            @instance.stubs(:get_attribute_default).with(:foo).returns(@expected_in)
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
            @instance.stubs(:get_attribute_default).with(:foo).returns(@expected_in)
            assert_equal @expected_out, @instance.read_attribute(:foo)
          end
        end

        should 'not transform the source attr if it is already of the expected type' do
          foo_type = mock('foo too type')
          foo_type.expects(:decode).never
          SimpleMapper::Attributes.expects(:type?).with(:foo_type).returns({
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
      context 'write_attribute should' do
        should 'set the attribute as an instance variable' do
          @instance.write_attribute(:foo_attr, 'Foo!')
          assert_equal 'Foo!', @instance.instance_variable_get(:@foo_attr)
        end
      end
      context 'get_attribute_default' do
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
            @type = stub('type', :encode => nil, :decode => nil, :name => @name)
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

    context 'change tracking' do
      setup do
        @class.maps :change_me
        @class.maps :do_not_change_me
        @instance = @class.new(:change_me => 'change me', :do_not_change_me => 'no changing')
      end

      should 'mark an attribute as unchanged if it has not been assigned' do
        assert_equal false, @instance.attribute_changed?(:change_me)
      end

      should 'mark an attribute as changed once it has been assigned to' do
        @instance.change_me = 'Thou art changed'
        assert_equal true, @instance.attribute_changed?(:change_me)
      end

      should 'mark an attribute as changed via the :attribute_changed! method' do
        assert_equal false, @instance.attribute_changed?(:change_me)
        @instance.attribute_changed! :change_me
        assert_equal true, @instance.attribute_changed?(:change_me)
      end

      should 'return empty list for :changed_attributes when nothing has been assigned' do
        assert_equal [], @instance.changed_attributes
      end

      should 'return single-item list for :changed_attributes when one attribute was assigned' do
        @instance.change_me = 'foo'
        assert_equal [:change_me], @instance.changed_attributes
      end

      should 'return two-item list for :changed_attributes when both attrs were assigned' do
        @instance.change_me = 'changed!'
        @instance.do_not_change_me = 'I defy you'
        assert_equal([:change_me, :do_not_change_me], @instance.changed_attributes.sort_by {|sym| sym.to_s})
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
