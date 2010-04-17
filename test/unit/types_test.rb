require 'test_helper'
require 'date'

class AttributesTypesTest < Test::Unit::TestCase
  context 'The Float type' do
    setup do
      @type = SimpleMapper::Attributes::Types::Float
    end

    should 'decode the empty string to nil' do
      assert_equal nil, @type.decode('')
    end

    should 'decode simple integer strings' do
      [1, 2, 3, 5, 7, 11, 13, 17, 21129].each do |num|
        result = @type.decode(num.to_s)
        assert_equal Float, result.class
        assert_equal num.to_f, result
      end
    end

    should 'decode actual integers' do
      [1, 13, 21000, 4600].each do |num|
        result = @type.decode(num)
        assert_equal Float, result.class
        assert_equal num.to_f, result
      end
    end

    should 'decode valid floats' do
      [1.31, 46.723, 0.00290004, 16.161616].each do |num|
        result = @type.decode(num.to_s)
        assert_equal Float, result.class
        assert_equal num, result
      end
    end

    should 'handle float with decimal point but not fractional portion' do
      assert_equal 21.0, @type.decode('21.')
    end

    should 'throw a TypeConversionException given invalid decode input' do
      ['total junk', :more_garbage, '12a32b23c', '   '].each do |value|
        assert_raise(SimpleMapper::TypeConversionException) { @type.decode(value) }
      end
    end

    should 'encode numeric inputs to a string' do
      [1, 1.0, 0, 0.0, 21129, 46.723, 15.1515].each do |num|
        assert_equal num.to_f.to_s, @type.encode(num)
      end
    end

    should 'encode nil as nil' do
      assert_equal nil, @type.encode(nil)
    end

    should 'throw a TypeConversionException given non-numeric inputs for encode' do
      ['', :xyz, 'abc', '  0 . 77asd '].each do |input|
        assert_raise(SimpleMapper::TypeConversionException) { @type.encode(input) }
      end
    end

    should 'provide a default of nil' do
      assert_equal nil, @type.default
    end

    should 'be registered as :float' do
      assert_equal({:name          => :float,
                    :expected_type => Float,
                    :converter     => @type,}, SimpleMapper::Attributes.type_for(:float))
    end
  end

  context 'the String type' do
    setup do
      @type = SimpleMapper::Attributes::Types::String
    end

    should 'encode nil as nil' do
      assert_equal nil, @type.encode(nil)
    end

    should 'decode nil as nil' do
      assert_equal nil, @type.decode(nil)
    end

    context 'given input with to_s' do
      setup do
        @value = 'to_s result'
        @input = mock('input')
        @input.expects(:to_s).with.returns(@value)
      end

      should 'return result of :to_s on input for :encode' do
        assert_equal @value, @type.encode(@input)
      end

      should 'return result of :to_s on input for :decode' do
        assert_equal @value, @type.decode(@input)
      end
    end

    should 'provide empty string for the default' do
      assert_equal '', @type.default
    end

    should 'be registered as :string' do
      assert_equal({:name          => :string,
                    :expected_type => String,
                    :converter     => @type,}, SimpleMapper::Attributes.type_for(:string))
    end
  end

  context 'the SimpleUUID type' do
    setup do
      @type = SimpleMapper::Attributes::Types::SimpleUUID
      @class = SimpleUUID::UUID
    end

    should 'decode and encode nil as nil' do
      [:decode, :encode].each {|op| assert_equal nil, @type.send(op, nil)}
    end

    should 'return GUID string representation for :encode of actual UUID object' do
      @uuid = @class.new
      result = @type.encode(@uuid)
      assert_equal String, result.class
      assert_equal @uuid.to_guid, result
    end

    should 'return GUID string representation for :encode of a GUID-conforming string' do
      @uuid = @class.new
      result = @type.encode(@uuid.to_guid)
      assert_equal String, result.class
      assert_equal @uuid.to_guid, result
    end

    should 'parse string and return GUID-conforming string for :decode' do
      @uuid = @class.new
      assert_equal @uuid.to_guid, @type.decode(@uuid.to_guid)
    end

    should ':decode a SimpleUUID::UUID instance to a GUID string' do
      @uuid = @class.new
      assert_equal @uuid.to_guid, @type.decode(@uuid)
    end

    should 'a new SimpleUUID::UUID-based GUID string for the default' do
      assert_equal String, (first = @type.default).class
      assert_equal String, (second = @type.default).class
      assert_not_equal first, second
      assert_not_equal @class.new(first).to_guid, @class.new(second).to_guid
      assert_equal first, @class.new(first).to_guid
      assert_equal second, @class.new(second).to_guid
    end

    should 'be registered as :simple_uuid' do
      assert_equal({:name          => :simple_uuid,
                    :expected_type => nil,
                    :converter     => @type}, SimpleMapper::Attributes.type_for(:simple_uuid))
    end
  end

  context 'the Timestamp type' do
    setup do
      @type = SimpleMapper::Attributes::Types::Timestamp
      @class = DateTime
      @format = '%Y-%m-%d %H:%M:%S%z'
      # get time with appropriate resolution
      @now = @class.strptime(@class.now.strftime(@format), @format)
    end

    should ':decode a timestamp string with %Y-%m-%d %H:%M:%S%z' do
      result = @type.decode(@now.strftime(@format))
      assert_equal @now, result
    end

    should ':encode a timestamp as string with %Y-%m-%d %H:%M:%S%z structure' do
      assert_equal @now.strftime(@format), @type.encode(@now)
    end

    should 'pass nil through untouched for :encode and :decode' do
      assert_equal nil, @type.encode(nil)
      assert_equal nil, @type.decode(nil)
    end

    should 'provide current date/time as default' do
      # yes, if another process/thread preempts this one on a heavily-loaded server,
      # there's a possibility that these won't match.  I'm willing to live with that.
      assert_equal @now.strftime(@format), (default = @type.default) && default.strftime(@format)
    end

    should ':decode a DateTime instance as identity (pass through)' do
      assert_equal @now, @type.decode(@now)
    end

    should 'be registered as :timestamp type' do
      assert_equal({:name          => :timestamp,
                    :expected_type => @class,
                    :converter     => @type}, SimpleMapper::Attributes.type_for(:timestamp))
    end
  end
end
