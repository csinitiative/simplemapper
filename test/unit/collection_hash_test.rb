require 'test_helper'

class CollectionHashTest < Test::Unit::TestCase
  context 'A SimpleMapper::Collection::Hash' do
    setup do
      @class = SimpleMapper::Collection::Hash
    end

    should 'be equivalent to a hash passed to the constructor' do
      hash = {:a => 'A', :b => 'B'}
      instance = @class.new(hash)
      assert_equal hash, instance
      assert_equal @class, instance.class
    end

    should 'allow hash-style lookups, assignments, etc.' do
      instance = @class.new
      assert_equal nil, instance[:foo]
      assert_equal :bar, instance[:foo] = :bar
      assert_equal :bar, instance[:foo]
      assert_equal true, instance.has_key?(:foo)
      assert_equal false, instance.has_key?(:blah)
      assert_equal :blee, instance[:boo] = :blee
      assert_equal :blee, instance[:boo]
      assert_equal([:boo, :foo], instance.keys.sort_by {|k| k.to_s})
    end

    should 'have an :attribute attribute' do
      instance = @class.new
      assert_equal nil, instance.attribute
      attrib = stub('attribute_object')
      assert_equal attrib, instance.attribute = attrib
      assert_equal attrib, instance.attribute
    end

    should 'allow construction of new mapper instances through :build' do
      mapper = stub('mapper')
      attrib = stub('attribute_object', :mapper => mapper)
      seq = sequence('build invocations')
      mapper.expects(:new).with.in_sequence(seq).returns(:one)
      mapper.expects(:new).with(:a => 'A').in_sequence(seq).returns(:two)
      mapper.expects(:new).with(:foo, :bar, :a => 'A', :b => 'B').in_sequence(seq).returns(:three)
      instance = @class.new
      instance.attribute = attrib
      result = []
      result << instance.build
      result << instance.build(:a => 'A')
      result << instance.build(:foo, :bar, :a => 'A', :b => 'B')
      assert_equal [:one, :two, :three], result
    end

    context 'tracking changes' do
      should 'be off by default' do
        instance = @class.new
        assert_equal false, (instance.change_tracking || false)
      end

      context 'for assignment' do
        should 'mark newly-assigned key as changed' do
          instance = @class.new
          instance.change_tracking = true
          assert_equal([], instance.changed_members)
          instance[:a] = 'A'
          assert_equal([:a], instance.changed_members)
        end

        should 'mark replaced key as changed' do
          instance = @class.new({:a => 'A'})
          instance.change_tracking = true
          assert_equal([], instance.changed_members)
          instance[:a] = 'Aprime'
          assert_equal([:a], instance.changed_members)
        end

        should 'mark replaced key as changed and mark entire value as changed if new value supports :all_changed!' do
          instance = @class.new({:a => 'A'})
          instance.change_tracking = true
          assert_equal([], instance.changed_members)
          obj = stub('new value')
          obj.expects(:all_changed!).with.returns(true)
          instance[:a] = obj
          assert_equal([:a], instance.changed_members)
        end

        should 'not track any changes on assignment if track_changes is false' do
          instance = @class.new({:a => 'A', :b => 'B'})
          instance.change_tracking = false
          assert_equal([], instance.changed_members)
          instance[:a] = 'A prime'
          instance[:b] = nil
          instance[:c] = 'C'
          assert_equal([], instance.changed_members)
        end
      end

      context 'for deletion' do
        setup do
          @key = :delete_me
          @value = 'delete me!' 
          @keep_key = :keep_me
          @keep_value = 'keep me!'
          @instance = @class.new({@key => @value, @keep_key => @keep_value})
          @instance.change_tracking = true
        end

        should 'mark key as changed when key is specified in a :delete' do
          assert_equal @value, @instance.delete(@key)
          assert_equal false, @instance.key?(@key)
          assert_equal [@key], @instance.changed_members
        end

        should 'mark key as changed when key is removed via :delete_if' do
          assert_equal({@keep_key => @keep_value}, @instance.delete_if {|k,v| k == @key})
          assert_equal false, @instance.key?(@key)
          assert_equal [@key], @instance.changed_members
        end

        should 'mark key as changed when key is removed via :reject!' do
          assert_equal({@keep_key => @keep_value}, @instance.reject! {|k,v| k == @key})
          assert_equal false, @instance.key?(@key)
          assert_equal [@key], @instance.changed_members
        end

        should 'mark nothing as changed if change_tracking is false at delete time' do
          @instance.change_tracking = false
          @instance.delete(:a)
          @instance.delete_if {|k, v| true}
          assert_equal [], @instance.changed_members
        end
      end
    end

  end
end
