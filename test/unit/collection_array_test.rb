require 'test_helper'
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

  end
end
