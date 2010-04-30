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

      should 'return new hash of keys mapped to decoded values' do
        @expected.each do |key, value|
          @type.stubs(:decode).with(@input[key]).returns(value)
        end
        assert_equal @expected, @instance.apply_type(@input)
      end
    end
  end
end
