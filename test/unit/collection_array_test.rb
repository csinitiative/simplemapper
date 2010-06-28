require 'test_helper'
require 'delegate'
class CollectionArrayTest < Test::Unit::TestCase
  context 'A SimpleMapper::Collection::Array' do
    setup do
      @class = SimpleMapper::Collection::Array
    end

    should 'be equivalent to a standard Array' do
      array = [:a, :b, :c]
      instance = @class.new(array)
      assert_equal array, instance
      assert_equal @class, instance.class
    end

    should 'allow array-style assignments, lookups, size checks, etc' do
      instance = @class.new
      assert_equal 0, instance.size
      instance << :a
      assert_equal 1, instance.size
      assert_equal :a, instance[0]
      instance[4] = :b
      assert_equal 5, instance.size
      assert_equal [:a, nil, nil, nil, :b], instance
    end

    should 'disallow non-integer indexes' do
      instance = @class.new
      assert_raise(TypeError) { instance[:a] = 'a' }
    end

    should 'provide list of indexes via :keys' do
      assert_equal (0..3).to_a, @class.new([:a, :b, :c, :d]).keys
    end

    should 'yield key/value pairs instead of just value for :inject' do
      source = [:a, :b, :c, :d, :e]
      expected = (0..(source.size - 1)).to_a.collect {|key| [key, source[key]]}
      result = @class.new(source).inject([]) {|a, pair| a << pair; a}
      assert_equal expected, result
    end

    should 'have an :attribute attribute' do
      instance = @class.new
      assert_equal nil, instance.attribute
      attrib = stub('attribute')
      assert_equal attrib, instance.attribute = attrib
      assert_equal attrib, instance.attribute
    end

    should 'allow creation of new mapper instances through :build' do
      mapper = stub('mapper')
      attrib = stub('attrib', :mapper => mapper)
      seq    = sequence('build invocations')
      mapper.expects(:new).with.in_sequence(seq).returns(:one)
      mapper.expects(:new).with(:a => 'A').in_sequence(seq).returns(:two)
      mapper.expects(:new).with(:a, :b, :c).in_sequence(seq).returns(:three)
      instance = @class.new
      instance.attribute = attrib
      result = []
      result << instance.build
      result << instance.build(:a => 'A')
      result << instance.build(:a, :b, :c)
      assert_equal [:one, :two, :three], result
    end

    context 'with change_tracking true' do
      context 'when appending to the array' do
        setup do
          @instance = @class.new
          @instance.attribute = stub('attrib', :mapper => nil)
          @instance.change_tracking = false
          @values = [:a, :b, :c]
          @instance.push(*@values)
          @instance.change_tracking = true
        end

        should 'mark new item for :<< as changed' do
          @instance << :zzz
          assert_equal [@values.size], @instance.changed_members
        end

        should 'mark new items for :push as changed' do
          @instance.push(:xxx, :yyy, :zzz)
          assert_equal [@values.size, @values.size + 1, @values.size + 2], @instance.changed_members
        end
      end
    end

    context 'when deleting from the array' do
      setup do
        @instance = @class.new
        @instance.attribute = stub('attrib', :mapper => nil)
        @instance.change_tracking = false
        @values = ('a'..'z').to_a
        @instance.push(*@values)
        @instance.change_tracking = true
      end

      context 'with slice! given a range' do
        should 'identify all indexes from the range minimum to the original size as changed' do
          range = 5..10
          expected_list = @values.clone
          expected_slice = expected_list.slice!(range)
          expected_changes = (5..(@values.size - 1)).to_a
          assert_equal expected_slice, @instance.slice!(range)
          assert_equal expected_list, @instance
          assert_equal expected_changes, @instance.changed_members
        end

        should 'not mark changes for indexes outside the original size' do
          range = (@values.size - 2)..(@values.size + 1)
          expected_list = @values.clone
          expected_slice = expected_list.slice!(range)
          assert_equal expected_slice, @instance.slice!(range)
          assert_equal expected_list, @instance
          assert_equal [@values.size - 2, @values.size - 1], @instance.changed_members
        end
      end

      context 'with slice! given a start index and length' do
        should 'identify all indexes from start up to original size as changed' do
          start = @values.size - 5
          expected_list = @values.clone
          expected_slice = expected_list.slice!(start, 3)
          assert_equal expected_slice, @instance.slice!(start, 3)
          assert_equal expected_list, @instance
          assert_equal ((@values.size - 5)..(@values.size - 1)).to_a, @instance.changed_members
        end

        should 'not mark changes for indexes outside the original size' do
          start = @values.size - 2
          expected_list = @values.clone
          expected_slice = expected_list.slice!(start, 1000)
          assert_equal expected_slice, @instance.slice!(start, 1000)
          assert_equal expected_list, @instance
          assert_equal [@values.size - 2, @values.size - 1], @instance.changed_members
        end

        should 'handle negative start index properly' do
          expected_list = @values.clone
          expected_slice = expected_list.slice!(-5, 1)
          assert_equal expected_slice, @instance.slice!(-5, 1)
          assert_equal expected_list, @instance
          assert_equal ((@values.size - 5)..(@values.size - 1)).to_a, @instance.changed_members
        end
      end

      context 'with delete_at' do
        should 'return deleted item and marked index to end as changed if index is in range' do
          index = @values.size - 5
          assert_equal @values[index], @instance.delete_at(index)
          assert_equal @values.slice(0, index) + @values.slice(index + 1, 4), @instance
          assert_equal (index..@values.size - 1).to_a, @instance.changed_members
        end

        should 'do nothing but return nil if index out of range' do
          assert_equal nil, @instance.delete_at(@values.size)
          assert_equal @values, @instance
          assert_equal [], @instance.changed_members
        end
      end

      context 'with reject!' do
        should 'return the altered list and mark all items as changed from first removed to end' do
          start_index = @values.size - 10
          expected_values = @values.clone.reject! {|x| x >= @values[start_index]}
          assert_equal(expected_values, @instance.reject! {|val| val >= @values[start_index]})
          assert_equal (start_index..@values.size - 1).to_a, @instance.changed_members
        end

        should 'do nothing but return nil if nothing is deleted' do
          assert_equal(nil, @instance.reject! {|v| false})
          assert_equal [], @instance.changed_members
        end
      end

      context 'with delete_if' do
        should 'return the altered list and mark all items as changed from first removed to end' do
          start = @values.size - 10
          key   = @values[start]
          expected_values = @values.find_all {|x| x < key}
          assert_equal(expected_values, @instance.delete_if {|val| val >= key})
          assert_equal (start..@values.size-1).to_a, @instance.changed_members
        end

        should 'do nothing but return unchanged list if nothing is deleted' do
          assert_equal(@values, @instance.delete_if {|val| false})
          assert_equal [], @instance.changed_members
        end
      end
    end
  end
end
