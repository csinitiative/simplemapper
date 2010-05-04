require 'test_helper'

class SimpleMapperAttributePatternTest < Test::Unit::TestCase
  context 'A SimpleMapper::Attribute::Pattern instance' do
    setup do
      @class = SimpleMapper::Attribute::Pattern
      @pattern = /^a+/
      @instance = @class.new(@name = :pattern_collection, :pattern => @pattern)
    end

    should 'extend SimpleMapper::Attribute' do
      assert_equal true, @instance.is_a?(SimpleMapper::Attribute)
    end

    should 'have a pattern attribute' do
      assert_equal @pattern, @instance.pattern
      new_pattern = /foo/
      @instance.pattern = new_pattern
      assert_equal new_pattern, @instance.pattern
    end

    should 'require a pattern value' do
      # no problem if it has a :match method
      item = stub('item', :match => true)
      @instance.pattern = item
      assert_equal item, @instance.pattern

      # no rikey if no :match
      item = stub('bad bad not-a-pattern')
      assert_raise(SimpleMapper::InvalidPatternException) do
        @instance.pattern = item
      end
    end

    context 'with a SimpleMapper::Attributes-derived object' do
      setup do
        # initialize with non-matching keys
        @source_values = {:b => 'Bad', :c => 'Cows', :d => 'Deathdog'}
        @object = stub('object', :simple_mapper_source => @source_values)
      end

      context 'for source value' do
        should 'return empty hash if no keys in the source match the pattern' do
          assert_equal({}, @instance.source_value(@object))
        end

        should 'return hash with key/value pairs for only the keys matching pattern' do
          expected = {:a => 'A', :abc => 'ABC', :aarp => 'AARP'}
          @source_values.merge! expected
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

        should 'apply to_simple on mapped values' do
          @instance.mapper = stub('mapper', :encode => 'foo')
          @instance.type = @instance.mapper
          base_value = {}
          expected_value = {}
          container = {}
          [:a, :ab, :abc].each do |sym|
            val = sym.to_s.upcase
            expect = val + ' simplified'
            expected_value[sym] = {sym => expect}
            base_value[sym] = mock(val)
            base_value[sym].expects(:to_simple).with({}).returns(expected_value[sym].clone)
          end
          @instance.expects(:value).with(@object).returns(base_value)
          result = @instance.to_simple(@object, container) || {}
          assert_equal expected_value, result
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
