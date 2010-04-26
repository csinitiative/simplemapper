require 'test_helper'

# Change tracking is done at the attribute object level
# via SimpleMapper::Attribute methods +changed?+ and +changed!+,
# but the basic attribute object depends on the +simple_mapper_changes+
# hash attribute provided by SimpleMapper::Attributes to including classes.
#
# The unit tests mock out this interdependency, so we need this simple
# integration test to verify the basics.
class AttributeChangeTrackingTest < Test::Unit::TestCase
  context 'Objects built using SimpleMapper::Attributes' do
    setup do
      @class = Class.new do
        include SimpleMapper::Attributes
        maps :a
        maps :b
      end
      @values = {:a => 'A', :b => 'B'}
      @instance = @class.new(@values.clone)
    end

    should 'indicate no change on attribute objects for not-newly-assigned attributes' do
      assert_equal false, @class.simple_mapper.attributes[:a].changed?(@instance)
      assert_equal false, @class.simple_mapper.attributes[:b].changed?(@instance)
    end

    should 'indicate no change on instance via :attribute_changed? for not-newly-assigned attributes' do
      assert_equal false, @instance.attribute_changed?(:a)
      assert_equal false, @instance.attribute_changed?(:b)
    end

    should 'indicate change on attribute objects for newly-assigned attributes' do
      @instance.a = 'something else'
      assert_equal true, @class.simple_mapper.attributes[:a].changed?(@instance)
      assert_equal false, @class.simple_mapper.attributes[:b].changed?(@instance)
    end

    should 'indicate change on instance via :attribute_changed? for newly-assigned attributes' do
      @instance.a = 'something else'
      assert_equal true, @instance.attribute_changed?(:a)
      assert_equal false, @instance.attribute_changed?(:b)
    end

    context 'when converting :to_simple with :changed' do
      should 'result in an empty hash if no attributes have been changed' do
        assert_equal({}, @instance.to_simple(:changed => true))
      end

      should 'result in hash with one member if only one member was changed' do
        @instance.a = new_a = 'new a'
        assert_equal({:a => new_a}, @instance.to_simple(:changed => true))
      end

      should 'result in hash with multiple members if multiple members were changed' do
        @instance.a = new_a = 'new_a'
        @instance.b = new_b = 'new_b'
        assert_equal({:a => new_a, :b => new_b}, @instance.to_simple(:changed => true))
      end
    end
  end
end
