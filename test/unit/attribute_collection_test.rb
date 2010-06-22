require 'test_helper'
class AttributeCollectionTest < Test::Unit::TestCase
  context 'A collection-type attribute' do
    setup do
      @class = Class.new(SimpleMapper::Attribute) do
        include SimpleMapper::Attribute::Collection
      end
      @name = :me_collection_attribute
      @instance = @class.new(@name)
      @source = {}
      @object = stub('object', :simple_mapper_source => @source)
    end

    context 'transforming a value from source' do
      should 'prepare value marked for tracking changes' do
        collection = @instance.transformed_source_value(@object)
        assert_equal true, collection.change_tracking
      end

      should 'prepare value with no changes marked' do
        @source.merge!({'a' => 'A', 'b' => 'B'})
        collection = @instance.transformed_source_value(@object)
        assert_equal [], collection.changed_members
      end
    end

  end
end
