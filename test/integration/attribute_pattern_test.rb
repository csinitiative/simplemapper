require 'test_helper'

# basic end-to-end tests for the SimpleMapper::Attribute::Pattern attribute class.
class AttributePatternIntegrationTest < Test::Unit::TestCase
  context 'A SimpleMapper::Attribute::Pattern attribute' do
    setup do
      @target_class = SimpleMapper::Attribute::Pattern
      @class = Class.new do
        include SimpleMapper::Attributes
      end
    end

    context 'with simple values' do
      setup do
        @class.maps :simple, :attribute_class => @target_class, :pattern => /^simple_/
        @class.maps :float,  :attribute_class => @target_class, :pattern => /^float_/, :type => :float
        @simple = {:simple_a => 'a', :simple_b => 'b', :simple_c => 'c'}
        @float  = {:float_a => 1.0, :float_b => 100.1, :float_c => 99.99999}
        @object = @class.new( @simple.merge( @float.inject({}) {|h, kv| h[kv[0]] = kv[1].to_s; h} ) )      end

      should 'map untyped pairs to the patterned collection attribute' do
        assert_equal @simple, @object.simple
      end

      should 'map typed pairs to the patterned collection attribute' do
        assert_equal @float, @object.float
      end
    end

    context 'with a nested mapper' do
      setup do
        @class.maps :not_nested
        @class.maps :nested, :attribute_class => @target_class, :pattern => /^nested_/ do
          maps :foo
          maps :bar
        end

        @input = {:nested_a => {:foo => 'foo_a', :bar => 'bar_a'},
                  :nested_b => {:foo => 'foo_b', :bar => 'bar_b'},
                  :nested_c => {:foo => 'foo_c', :bar => 'bar_c'},
                  :not_nested => 'blah'}
        @object = @class.new(@input)
      end

      should 'convert nested source values to type defined by block per item in patterned collection attribute' do
        result = @object.nested.inject({}) do |hash, keyval|
          hash[keyval[0]] = {:foo => keyval[1].foo, :bar => keyval[1].bar}
          hash
        end
        expected = @input.clone
        expected.delete :not_nested
        assert_equal expected, result
      end

      should 'still map simple attributes too' do
        assert_equal @input[:not_nested], @object.not_nested.to_s
      end
    end
  end
end
