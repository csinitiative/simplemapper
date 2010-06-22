require 'test_helper'
class AttributeCollectionTest < Test::Unit::TestCase
  context 'A collection-type attribute' do
    setup do
      @class = Class.new(SimpleMapper::Attribute) do
        include SimpleMapper::Attribute::Collection
      end
      @name = :me_collection_attribute
      @instance = @class.new(@name)
      @source = {}
      @object = stub('object', :simple_mapper_source => @source)
    end

    context 'transforming a value from source' do
      should 'prepare value marked for tracking changes' do
        collection = @instance.transformed_source_value(@object)
        assert_equal true, collection.change_tracking
      end

      should 'prepare value with no changes marked' do
        @source.merge!({'a' => 'A', 'b' => 'B'})
        collection = @instance.transformed_source_value(@object)
        assert_equal [], collection.changed_members
      end
    end

    should 'pass keys through unchanged for :to_simple_key' do
      items = ['a string', :a_symbol, 666]
      assert_equal(items, items.collect {|item| @instance.to_simple_key(item)})
    end

    should 'pass keys through unchanged for :from_simple_key' do
      items = ['another string', :another_symbol, 444]
      assert_equal(items, items.collect {|item| @instance.from_simple_key(item)})
    end

    context 'for source value' do
      should 'get its container value from :new_collection' do
        @instance.expects(:new_collection).returns(container = stub('container'))
        assert_equal(container, @instance.source_value(@object))
      end

      should 'determine keys for the mapped structure via :from_simple_key' do
        source_additional = {:a => 'A', :abc => 'ABC', :aarp => 'AARP'}
        @instance.stubs(:member_key).returns(false)
        expected = source_additional.inject({}) do |hash, keyval|
          @instance.stubs(:member_key?).with(keyval[0]).returns(true)
          key = keyval[0].to_s + ' transformed'
          hash[key] = keyval[1]
          @instance.expects(:from_simple_key).with(keyval[0]).returns(key)
          hash
        end
        @source.merge! source_additional
        result = @instance.source_value(@object)
        assert_equal expected, result
      end

      should 'return empty hash if no keys in the source pass the member_key? test' do
        # note that this depends on member_key? being a default-false method in the module
        assert_equal({}, @instance.source_value(@object))
      end

      should 'return hash with key/value pairs for only the keys passing member_key? test' do
        expected = {:a => 'A', :abc => 'ABC', :aarp => 'AARP'}
        @source.merge! expected
        @instance.stubs(:member_key).returns(false)
        expected.keys.each do |key|
          @instance.expects(:member_key?).with(key).returns(true)
        end
        assert_equal expected, @instance.source_value(@object)
      end
    end


    context 'for transformed_source_value' do
      setup do
        @expected_source  = {:a => 'A', :aa => 'AA'}
        @expected_default = {:a => 'Default A', :aa => 'Default AA'}
        @instance.stubs(:default_value).with(@object).returns(@expected_default)
      end

      should 'return the source value if there is no type and source is non-empty' do
        @instance.stubs(:source_value).with(@object).returns(@expected_source)
        assert_equal @expected_source, @instance.transformed_source_value(@object)
      end

      should 'return the default value if there is no type and source is empty' do
        @instance.stubs(:source_value).with(@object).returns(nil)
        assert_equal @expected_default, @instance.transformed_source_value(@object)
      end

      context 'with a type' do
        setup do
          @instance.type = stub('type')
        end

        should 'return the result of apply type given the source value' do
          @instance.expects(:apply_type).with(@expected_source).returns( expected = {:a => 'Foo'})
          @instance.stubs(:source_value).with(@object).returns(@expected_source)
          result = @instance.transformed_source_value(@object)
          assert_equal expected, result
        end

        should 'return the result of the apply type given the default value and empty source' do
          @instance.expects(:apply_type).with(@expected_default).returns( expected = {:a => 'Default'} )
          @instance.stubs(:source_value).with(@object).returns(nil)
          result = @instance.transformed_source_value(@object)
          assert_equal expected, result
        end
      end
    end

    context 'for freeze_for' do
      setup do
        @collection = [:a, :b, :c].inject({}) {|hash, name| hash[name] = stub(name.to_s); hash}
        @object = stub('object')
        @instance.stubs(:value).with(@object).returns(@collection)
      end

      context 'with simple values' do
        should 'freeze the collection and leave members alone' do
          @collection.values.each {|member| member.expects(:freeze).never}
          @collection.expects(:freeze).with.once
          @instance.freeze_for(@object)
        end
      end

      context 'with mapped values' do
        setup do
          @instance.mapper = stub('mapper', :encode => 'foo')
          @instance.type = @instance.mapper
        end

        should 'freeze the collection and each collection member' do
          @collection.values.each {|member| member.expects(:freeze).with.once}
          @collection.expects(:freeze).with.once
          @instance.freeze_for(@object)
        end
      end
    end

    context 'for to_simple' do
      context 'with simple values' do
        setup do
          @container_extra = {:foo => 'foo', :bar => 'bar'}
          @container_added = {:a => 'A', :ab => 'AB'}
        end

        should 'add keys and values to container' do
          @instance.expects(:value).with(@object).returns(@container_added.clone)
          result = @instance.to_simple(@object, @container_extra.clone)
          assert_equal @container_extra.merge(@container_added), result
        end

        should 'filters keys through :to_simple_key when adding to container' do
          @instance.expects(:value).with(@object).returns(@container_added.clone)
          expectation = {}
          @container_added.each do |k, v|
            key = k.to_s + ' transformed'
            expectation[key] = v
            @instance.expects(:to_simple_key).with(k).returns(key)
          end
          result = @instance.to_simple(@object, @container_extra.clone)
          assert_equal @container_extra.merge(expectation), result
        end

        should 'encode typed values' do
          @instance.type = mock('type')
          @instance.expects(:value).with(@object).returns(@container_added.clone)
          expectation = {}
          @container_added.each do |k, v|
            expectation[k] = v + ' encoded'
            @instance.type.expects(:encode).with(v).returns(expectation[k])
          end
          result = @instance.to_simple(@object, @container_extra.clone)
          assert_equal @container_extra.merge(expectation), result
        end
      end

      context 'with mapped values' do
        setup do
          @instance.mapper = stub('mapper', :encode => 'foo')
          @instance.type = @instance.mapper
          @base_value = {}
          @expected_value = {}
          @container = {}
        end

        should 'apply to_simple on values' do
          [:a, :ab, :abc].each do |sym|
            val = sym.to_s.upcase
            expect = val + ' simplified'
            @expected_value[sym] = {sym => expect}
            @base_value[sym] = mock(val)
            @base_value[sym].expects(:to_simple).with({}).returns(@expected_value[sym].clone)
          end
          @instance.expects(:value).with(@object).returns(@base_value)
          result = @instance.to_simple(@object, @container) || {}
          assert_equal @expected_value, result
        end

        should 'apply to_simple on values and use string keys on collection when requested' do
          [:a, :ab, :abc].each do |sym|
            val = sym.to_s.upcase
            expect = val + ' simplified'
            @expected_value[sym.to_s] = {sym.to_s => expect}
            @base_value[sym] = mock(val)
            @base_value[sym].expects(:to_simple).with({:string_keys => true}).returns(@expected_value[sym.to_s].clone)
          end
          @instance.expects(:value).with(@object).returns(@base_value)
          result = @instance.to_simple(@object, @container, :string_keys => true) || {}
          assert_equal @expected_value, result
        end
      end
    end

    context 'when applying type to a source/default value' do
      setup do
        @input    = {:a => 'A', :abc => 'ABC', :aabb => 'AABB'}
        @expected = @input.inject({}) {|h, kv| h[kv[0]] = kv[1] + ' encoded'; h}
        @type     = stub('type')
        @instance.stubs(:converter).returns(@type)
      end

      should 'decode all values in the input hash' do
        @expected.each do |key, value|
          @type.expects(:decode).with(@input[key]).returns(value)
        end
        @instance.apply_type(@input)
      end

      should 'return new collection hash of keys mapped to decoded values' do
        @expected.each do |key, value|
          @type.stubs(:decode).with(@input[key]).returns(value)
        end
        result = @instance.apply_type(@input)
        assert_equal @expected, result
        assert_equal SimpleMapper::Collection::Hash, result.class
      end

      should 'initialize collection hash with the attribute instance' do
        @expected.each do |key, value|
          @type.stubs(:decode).with(@input[key]).returns(value)
        end
        result = @instance.apply_type(@input)
        assert_equal @instance, result.attribute
      end
    end
  end
end
