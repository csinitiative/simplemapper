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
  end
end
