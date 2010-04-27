require 'test_helper'

# The :to_simple method of the SimpleMapper::Attributes
# module ultimately depends on the :to_simple
# implementation of the attribute objects for a given
# mapper class.
#
# Consequently, the integration test is necessary,
# as other :to_simple tests at the unit level rely on
# mocks for this interdependency.
class ToSimpleTest < Test::Unit::TestCase
  context "The mapper's :to_simple method" do
    setup do
      @class = Class.new do
        include SimpleMapper::Attributes
        maps :no_type
      end
    end

    should 'return a hash with key/value per known attribute' do
      @class.maps :other
      @instance = @class.new( :no_type => 'no type', :other => 'Other!' )
      assert_equal( {:no_type => 'no type', :other => 'Other!'}, @instance.to_simple )
    end

    should 'return hash whose key/value pairs follow attribute state' do
      @class.maps :other
      @instance = @class.new( :no_type => 'original', :other => 'original' )
      @instance.other = 'updated'
      assert_equal({:no_type => 'original', :other => 'updated'}, @instance.to_simple)
    end

    should 'map attributes to specified keys in returned hash' do
      @class.maps :other, :key => :alt_key
      @instance = @class.new
      @instance.no_type = 'no type'
      @instance.other = 'alt key'
      assert_equal({:no_type => 'no type', :alt_key => 'alt key'}, @instance.to_simple)
    end

    should 'return a hash with strings for keys when :string_keys option is true' do
      @class.maps :other, :key => :alt_key
      @instance = @class.new
      @instance.no_type = 'no type'
      @instance.other = 'alt key'
      assert_equal({'no_type' => 'no type', 'alt_key' => 'alt key'},
                    @instance.to_simple(:string_keys => true))
    end

    should 'encode typed attribute values for converter types' do
      @type = Object.new
      @type.instance_eval do
        def encode(value)
          "encoded: #{value}"
        end
        def decode(value)
          value
        end
      end
      @class.maps :typed, :type => @type
      @instance = @class.new( :typed => 'typed!' )
      assert_equal 'encoded: typed!', @instance.to_simple[:typed]
    end

    should 'encode typed attribute values for registered types' do
      @type = mock('type')
      @type.expects(:encode).once.with('typed!').returns('encoded!')
      @type.stubs(:decode).returns('typed!')
      SimpleMapper::Attributes.expects(:type_for).with(:type).at_least_once.returns({
        :name          => :type,
        :expected_type => @type.class,
        :converter     => @type,
      })
      @class.maps :typed, :type => :type
      @instance = @class.new( :typed => 'typed!' )
      assert_equal 'encoded!', @instance.to_simple[:typed]
    end

    context 'with :defined argument' do
      should 'return a hash with key/value per defined attribute' do
        @class.maps :undefined
        assert_equal({:no_type => 'nt'}, @class.new({:no_type => 'nt'}).to_simple(:defined => true))
      end

      should 'return an empty hash if no attributes were set' do
        assert_equal({}, @class.new.to_simple(:defined => true))
      end
    end

    context 'with :changes argument' do
      setup do
        @class.maps :other
        @instance = @class.new({:typed => 'typed', :other => 'other'})
      end

      should 'return an empty hash if no attributes were changed' do
        assert_equal({}, @instance.to_simple(:changed => true))
      end

      should 'return a hash of only the key/value pairs that were changed' do
        @instance.other = 'udder'
        @instance.class.simple_mapper.attributes[:other].stubs(:changed?).with(@instance).returns(true)
        assert_equal({:other => 'udder'}, @instance.to_simple(:changed => true))
      end
    end

    context 'with an attribute value that supports to_simple' do
      setup do
        @class.maps :other
        @instance = @class.new({:no_type => 'no type',
                                :other => (@mock = stub('to_simple_supporter'))})
      end

      should 'invoke to_simple on attribute value rather than encode' do
        @mock.expects(:to_simple).returns('to simple')
        assert_equal({:no_type => 'no type', :other => 'to simple'},
                      @instance.to_simple)
      end

      should 'pass outer to_simple arguments along to inner to_simple' do
        options = {:foo => 'floppy', :foot => 'fungi'}
        @mock.expects(:to_simple).with(options).returns(nil)
        @instance.to_simple(options)
      end
    end
  end
end
