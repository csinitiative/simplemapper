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

    context 'freeze_for' do
      should 'do nothing for regular attributes' do
        target = mock('target')
        target.expects(:freeze).never
        @instance.freeze_for(target)
      end

      should "invoke freeze on instance's nested mapper" do
        target = mock('mapper target')
        target.stubs(@instance.name).returns(mapped_obj = mock('mapped instance'))
        mapped_obj.expects(:freeze).once.with
        @instance.stubs(:mapper).returns(:some_mapper)
        @instance.freeze_for(target)
      end
    end

    should 'use target object :simple_mapper_changes as state hash of :change_tracking_for' do
      changes = {}
      object = mock('object', :simple_mapper_changes => changes)
      result = @instance.change_tracking_for(object)
      assert_equal result.object_id, changes.object_id
    end

    context 'change tracking' do
      setup do
        @changes = {}
        @object = stub('object')
        @instance.stubs(:change_tracking_for).with(@object).returns(@changes)
      end

      should 'mark the attribute as changed within an instance.simple_mapper_changes hash when instance given to :changed!' do
        @instance.changed!(@object)
        assert_equal({@name => true}, @changes)
      end

      should 'remove the attribute from changes hash when instance given to :changed! along with false' do
        @changes[@name] = true
        @instance.changed!(@object, false)
        assert_equal({}, @changes)
      end

      should 'return truth of changed state for attribute on instance provided to :changed? based on instance.simple_mapper_changes' do
        assert_equal false, @instance.changed?(@object)
        @changes[@name] = true
        assert_equal true, @instance.changed?(@object)
      end

      should 'delegate :changed? call to mapped object if attribute has a mapper' do
        @instance.stubs(:mapper).returns(:foo)
        seq = sequence('value calls')
        true_mapper = stub('mapped object with true')
        false_mapper = stub('mapped object with false')
        # value must be checked to retrieve mapped object, so this is a reasonable expectation
        @instance.expects(:value).with(@object).in_sequence(seq).returns(true_mapper)
        true_mapper.expects(:changed?).with.in_sequence(seq).returns(true)
        @instance.expects(:value).with(@object).in_sequence(seq).returns(false_mapper)
        false_mapper.expects(:changed?).with.in_sequence(seq).returns(false)
        result = [@instance.changed?(@object), @instance.changed?(@object)]
        assert_equal [true, false], result
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

    context 'using its default_value method' do
      setup do
        @default_name = :default_method
        @default_value = 'some default'
        @object = stub('object', @default_name => @default_value)
      end

      should 'return nil if there is no default' do
        assert_equal nil, @instance.default_value(@object)
      end

      should 'return the default value if there is one by invoking the default on the target object' do
        @instance.default = @default_name
        assert_equal @default_value, @instance.default_value(@object)
      end

      context 'with a default of :from_type' do
        setup do
          @expected_value = 'the default value'
          @type = stub('type', :name => :some_type, :encode => :blah, :decode => :blah)
          @type.expects(:default).once.with.returns(@expected_value)
          @instance.default = :from_type
        end

        should 'invoke :default on type if it is able' do
          @instance.type = @type
          result = @instance.default_value(@object)
          assert_equal @expected_value, result
        end

        should 'invoke :default on registered type if type is registered' do
          @instance.type = @type.name
          SimpleMapper::Attributes.stubs(:types).with.returns({@type.name => {
            :name           => @type.name,
            :expected_class => @type.class,
            :converter      => @type,
          }})
          result = @instance.default_value(@object)
          assert_equal @expected_value, result
        end
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

  context 'A SimpleMapper::Attribute working with a SimpleMapper::Attributes-based object' do
    setup do
      @class = SimpleMapper::Attribute
      @key      = :some_key
      @value    = :some_value
      @name     = :some_attribute
      @instance = @class.new(@name, :key => @key)

      @source = {}
      @object.stubs(:simple_mapper_source).with.returns(@source)
    end

    context 'using the :source_value method' do
      should 'return object source value by key symbol' do
        @source[@key] = @value
        assert_equal @value, @instance.source_value(@object)
      end

      should 'return object source value by key string if symbol does not exist' do
        @source[@key.to_s] = @value
        assert_equal @value, @instance.source_value(@object)
      end
    end

    context 'using the :transformed_source_value method' do
      should 'return the source value directly' do
        @instance.expects(:source_value).with(@object).returns(@value)
        assert_equal @value, @instance.transformed_source_value(@object)
      end

      should 'return the default value if the source value is undefined' do
        @instance.stubs(:source_value).with(@object).returns(nil)
        @instance.expects(:default_value).with(@object).returns(:my_default)
        result = @instance.transformed_source_value(@object)
        #assert_equal :my_default, result
      end

      context 'with a typed attribute' do
        setup do
          @type = stub('type', :name => :sooper_speshil_tipe)
          @registry = {:name => @type.name, :converter => @type}
          SimpleMapper::Attributes.stubs(:type_for).with(@type.name).returns(@registry)
        end

        context 'and a type that supports :decode' do
          setup do
            @instance.type = @type
            @type.expects(:decode).with(@value).returns( @encoded = :encoded )
          end

          should 'return the decoded source value' do
            @instance.stubs(:source_value).with(@object).returns(@value)
            @instance.expects(:default_value).with(@object).never
            assert_equal @encoded, @instance.transformed_source_value(@object)
          end

          should 'return the decoded default value if no source defined' do
            @instance.stubs(:source_value).with(@object).returns(nil)
            @instance.stubs(:default_value).with(@object).returns(@value)
            result = @instance.transformed_source_value(@object)
            # assert_equal @encoded, result
          end
        end

        context 'and an expected type' do
          setup do
            @instance.type = @type.name
            @registry[:expected_type] = @value.class
            @type.expects(:decode).never
          end

          should 'return the source value if it matches' do
            @instance.stubs(:source_value).with(@object).returns(@value)
            assert_equal @value, @instance.transformed_source_value(@object)
          end

          should 'return the default value if no source defined and default matches' do
            @instance.stubs(:source_value).with(@object).returns(nil)
            @instance.expects(:default_value).with(@object).returns(@value)
            result = @instance.transformed_source_value(@object)
            # assert_equal @value, result
          end
        end

        should 'return the decoded source value via the registered type' do
          @instance.type = @type.name
          @instance.stubs(:source_value).with(@object).returns(@value)
          @type.expects(:decode).with(@value).returns( encoded = :encoded )
          result = @instance.transformed_source_value(@object)
          assert_equal encoded, result
        end
      end
    end
  end
end
