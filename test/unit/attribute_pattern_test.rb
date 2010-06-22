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
    end
  end
end
