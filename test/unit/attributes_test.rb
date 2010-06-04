require 'test_helper'

class AttributesTest < Test::Unit::TestCase
  def stub_out_attributes(klass, *attrs)
    attrs.each do |attr|
      attr_obj = klass.simple_mapper.attributes[attr]
      attr_obj.stubs(:changed?)
      attr_obj.stubs(:changed!)
    end
  end

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

    context 'when creating an anonymous mapper' do
      should 'return a class that is mapper-enabled' do
        result = @instance.create_anonymous_mapper
        assert_equal Class, result.class
        assert result.respond_to?(:maps)
        assert result.new.respond_to?(:to_simple)
        assert result.respond_to?(:decode)
        # decode should just wrap the constructor
        assert_equal result, result.decode.class
      end

      should 'eval a block within the context of the anonymous class' do
        result = @instance.create_anonymous_mapper do
          def self.platypus; 'platypus?'; end
          def walrus; 'walrus?'; end
        end
        assert_equal 'platypus?', result.platypus
        assert_equal 'walrus?', result.new.walrus
      end
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

      should 'default the attribute class to SimpleMapper::Attribute' do
        assert_equal SimpleMapper::Attribute, @instance.create_attribute(:some_attr).class
      end

      should 'allow specification of attribute class via the :attribute_class option' do
        attr_class = Class.new(SimpleMapper::Attribute)
        attrib = @instance.create_attribute(:some_attr, :attribute_class => attr_class)
        assert_equal attr_class, attrib.class
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
                     SimpleMapper::Attributes.type_for(@fake_type_symbol))
      end

      should 'return nil on type lookup for unknown type' do
        assert_equal nil, SimpleMapper::Attributes.type_for(:i_do_not_exist)
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
        @class.maps :a
        @class.maps :b
        @attrib_a = @class.simple_mapper.attributes[:a]
        @attrib_b = @class.simple_mapper.attributes[:b]
        # traditional mocking is not sufficiently
        # expressive for this, so we'll just implement
        # methods directly.
        @options = {}
        [@attrib_a, @attrib_b].each do |attr|
          attr.instance_eval do
            def to_simple(obj, container, options = {})
              # like an expectation; verifies that
              # options are passed along properly
              raise Exception unless options == obj.expected_options
              container[key] = obj.read_attribute(name)
              container
            end
          end
        end
        @values = {:a => 'A', :b => 'B'}
        @instance = @class.new(@values.clone)
        @instance.stubs(:expected_options).returns(@options)
      end

      should 'accumulate results from :to_simple on each attribute object' do
        @attrib_a.expects(:changed?).never
        @attrib_b.expects(:changed?).never
        assert_equal @values, @instance.to_simple(@options)
      end

      should 'accumulate results from :to_simple on changed attributes only when :changed => true is passed' do
        expectation = @values.clone
        expectation.delete :b
        @attrib_a.expects(:changed?).with(@instance).returns(true)
        @attrib_b.expects(:changed?).with(@instance).returns(false)
        @options[:changed] = true
        assert_equal expectation, @instance.to_simple(@options)
      end
    end

    context 'simpler_mapper_source' do
      should 'provide an empty hash by default' do
        @instance = @class.new
        assert_equal({}, @instance.simple_mapper_source)
      end

      should 'provide the source hash with which the instance was created' do
        values = {:foo => 'foo', :boo => 'boo'}
        @instance = @class.new(values)
        assert_equal values, @instance.simple_mapper_source
      end
    end

    context 'instance method' do
      setup do
        @instance = @class.new
        @class.maps :foo
        stub_out_attributes @class, :foo
      end

      context 'reset_attribute should' do
        should 'restore the specified attribute to its source value' do
          @instance = @class.new
          @class.simple_mapper.attributes[:foo].expects(:source_value).with(@instance).once.returns('Foo!')

          @instance.write_attribute(:foo, 'new val')
          assert_equal 'new val', @instance.read_attribute(:foo)
          @instance.reset_attribute(:foo)
          assert_equal 'Foo!', @instance.read_attribute(:foo)
        end

        should 'clear the changed? status of the specified attribute' do
          @instance = @class.new
          seq = sequence('change states')
          attrib = @class.simple_mapper.attributes[:foo]
          attrib.expects(:changed!).with(@instance, true).once.in_sequence(seq).returns(true)
          attrib.expects(:changed!).with(@instance, false).once.in_sequence(seq).returns(false)
          @instance.write_attribute(:foo, 'new val')
          @instance.reset_attribute(:foo)
        end
      end

      # keep me
      context 'transform_source_attribute' do
        setup do
          @instance = @class.new(:foo => 'foo')
        end

        should 'delegate source value transformation to underlying attribute object' do
          @class.simple_mapper.attributes[:foo].expects(:transformed_source_value).with(@instance).returns(:foopy)
          result = @instance.transform_source_attribute(:foo)
          assert_equal :foopy, result
        end
      end

      # keep me
      context 'read_source_attribute' do
        setup do
          @instance = @class.new(:foo => 'Foo!')
        end

        should 'delegate source value retrieval to the underlying attribute object' do
          @class.simple_mapper.attributes[:foo].expects(:source_value).with(@instance).returns('foo')
          result = @instance.read_source_attribute(:foo)
          assert_equal 'foo', result
        end
      end

      context 'write_attribute should' do
        should 'set the attribute as an instance variable' do
          @instance.write_attribute(:foo, 'Foo!')
          assert_equal 'Foo!', @instance.instance_variable_get(:@foo)
        end
      end

      context 'get_attribute_default' do
        should 'delegate default value to attribute object' do
          @class.maps :with_default, :default => :foo
          @class.simple_mapper.attributes[:with_default].expects(:default_value).once.with(@instance).returns(:expected_default)
          result = @instance.get_attribute_default(:with_default)
          assert_equal :expected_default, result
        end
      end

      context 'freeze' do
        setup do
          @instance = @class.new(:foo => @value = 'foo')
        end

        should 'prevent further attribute writes' do
          @instance.freeze
          assert_raises(RuntimeError) { @instance.foo = :x }
          # verify that value is unchanged
          assert_equal @value, @instance.foo
        end

        should 'allow attribute reads' do
          @instance.freeze
          assert_equal @value, @instance.foo
        end

        should 'support per-attribute handling via :freeze_for per attribute' do
          @class.maps :foo2
          @class.maps :foo3
          [:foo, :foo2, :foo3].each do |attrib|
            @instance.attribute_object_for(attrib).expects(:freeze_for).with(@instance)
          end
          @instance.freeze
        end
      end

      context 'frozen?' do
        setup do
          @instance = @class.new(:foo => 'foo')
        end

        should 'default to false' do
          assert_equal false, @instance.frozen?
        end

        should 'be true after a :freeze call' do
          @instance.freeze
          assert_equal true, @instance.frozen?
        end
      end
    end

    context 'change tracking' do
      setup do
        @class.maps :change_me
        @class.maps :do_not_change_me
        @instance = @class.new(:change_me => 'change me', :do_not_change_me => 'no changing')
      end

      should 'automatically instantiate an empty changes hash per instance' do
        assert_equal({}, @instance.simple_mapper_changes)
        @other = @class.new
        assert_equal({}, @other.simple_mapper_changes)
        assert_not_equal @instance.simple_mapper_changes.object_id, @other.simple_mapper_changes.object_id
      end

      should 'indicate an attribute is unchanged if it has not been assigned, based on attribute object' do
        @instance.class.simple_mapper.attributes[:change_me].expects(:changed?).with(@instance).returns(false)
        assert_equal false, @instance.attribute_changed?(:change_me)
      end

      should 'mark an attribute as changed once it has been assigned to' do
        @instance.class.simple_mapper.attributes[:change_me].expects(:changed!).with(@instance, true)
        @instance.change_me = 'Thou art changed'
      end

      should 'mark an attribute as changed via the :attribute_changed! method' do
        @instance.class.simple_mapper.attributes[:change_me].expects(:changed!).with(@instance, true)
        @instance.attribute_changed! :change_me
      end

      should 'return empty list for :changed_attributes when nothing has been assigned' do
        @instance.class.simple_mapper.attributes.each do |key, attr|
          attr.expects(:changed?).with(@instance).returns(false)
        end
        assert_equal [], @instance.changed_attributes
      end

      should 'return single-item list for :changed_attributes when an attribute is marked as changed' do
        @instance.class.simple_mapper.attributes.each do |key, attr|
          attr.expects(:changed?).with(@instance).returns(key == :change_me ? true : false)
        end
        assert_equal [:change_me], @instance.changed_attributes
      end

      should 'return two-item list for :changed_attributes when both attrs were assigned' do
        changes = [:change_me, :do_not_change_me]
        @instance.class.simple_mapper.attributes.each do |key, attr|
          attr.expects(:changed?).with(@instance).returns(changes.include?(key) ? true : false)
        end
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

      should 'create an anonymous mapper as the type when given a block' do
        @class.maps :outer do; end
        assert @class.simple_mapper.attributes[:outer].type.respond_to?(:maps)
        assert @class.simple_mapper.attributes[:outer].type.respond_to?(:new)
        assert @class.simple_mapper.attributes[:outer].type.respond_to?(:decode)
      end

      should 'assign anonymous mapper as the mapper of the attribute object when given a block' do
        mapper = stub('mapper')
        @class.simple_mapper.expects(:create_anonymous_mapper).returns(mapper)
        @class.maps :outer do; end
        assert_equal mapper, @class.simple_mapper.attributes[:outer].mapper
      end
    end
  end

  context 'with full nested mappers' do
    setup do
      @class = Class.new do
        include SimpleMapper::Attributes
        maps :id
        maps :email
        maps :home_address do
          maps :address
          maps :city
          maps :state
          maps :zip
        end
      end
      @source = {:id           => 'foo',
                 :email        => 'aardvark@pyongyang.yumm.com',
                 :home_address => {
                   :address    => '54 Gorgeous Gorge Parkway',
                   :city       => 'Here',
                   :state      => 'TX',
                   :zip        => '04435'}}
      @instance = @class.new(@source)
    end

    should 'map to instance appropriately' do
      assert_equal @class, @instance.class
      assert_equal @source[:id], @instance.id
      assert_equal @source[:email], @instance.email
      assert_equal @source[:home_address][:address], @instance.home_address.address
      assert_equal @source[:home_address][:city], @instance.home_address.city
      assert_equal @source[:home_address][:state], @instance.home_address.state
      assert_equal @source[:home_address][:zip], @instance.home_address.zip
    end

    should 'map back to simple structure' do
      assert_equal @source, @instance.to_simple
    end

    should 'freeze nested mappers when frozen from containing object' do
      @instance.freeze
      assert_equal true, @instance.home_address.frozen?
    end
  end
end
