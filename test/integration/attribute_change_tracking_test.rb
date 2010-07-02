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

    should 'indicate change on nested attribute if nested attribute has a newly-assigned member' do
      @class.maps :nested do
        maps :inner_a
        maps :inner_b
      end
      assert_equal false, @instance.attribute_changed?(:nested)
      @instance.nested.inner_a = 'foo'
      assert_equal true, @instance.attribute_changed?(:nested)
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

      should 'result in nested hash if the class has nested attributes' do
        @class.maps :nested do
          maps :inner_a
          maps :inner_b
        end
        @instance.a = new_a = 'new_a'
        @instance.nested.inner_a = new_inner_a = 'new_inner_a'
        assert_equal({:a => new_a, :nested => {:inner_a => new_inner_a}}, @instance.to_simple(:changed => true))
      end

      context 'and a hash collection attribute' do
        setup do
          @collection_class = Class.new(SimpleMapper::Attribute) do
            include SimpleMapper::Attribute::Collection

            def prefix
              '__'
            end

            def member_key?(key)
              key.to_s[0..1] == prefix
            end

            def from_simple_key(key)
              key.to_s.sub(prefix, '').to_sym
            end

            def to_simple_key(key)
              (prefix + key.to_s).to_sym
            end
          end

          @class.maps :collection, :attribute_class => @collection_class
          @instance = @class.new(@values.clone)
        end

        should 'have no output for the collection if no members were changed' do
          @instance.a = new_a = 'new_a'
          assert_equal({:a => new_a}, @instance.to_simple(:changed => true))
        end

        should 'have output for items added to the collection' do
          @instance.collection[:first] = 'first'
          @instance.collection[:second] = 'second'
          @instance.collection[:third] = 'third'
          assert_equal(
            {
              :__first  => 'first',
              :__second => 'second',
              :__third  => 'third',
            },
            @instance.to_simple(:changed => true)
          )
        end

        should 'have output for items altered in the collection' do
          @instance = @class.new(:__first => 'first', :__second => 'second', :__third => 'third')
          @instance.collection[:second] = 'new second'
          @instance.collection.delete(:third)
          @instance.collection[:fourth] = 'fourth'
          assert_equal(
            {:__second => 'new second',
             :__third  => nil,
             :__fourth => 'fourth'},
            @instance.to_simple(:changed => true)
          )
        end

        context 'with mapped members' do
          setup do
            @mapped_collection_class = Class.new(@collection_class) do
              def prefix
                '--'
              end
            end
            @class.maps :mapped_collection, :attribute_class => @mapped_collection_class do
              maps :name
              maps :id, :type => :simple_uuid, :default => :from_type
            end
          end

          should 'have output for items added to collection' do
            @instance.mapped_collection[:me] = @instance.mapped_collection.build(:name => 'me')
            @instance.mapped_collection[:you] = @instance.mapped_collection.build(:name => 'you')
            expected = {
              :'--me'  => {:name => 'me',  :id => @instance.mapped_collection[:me].id},
              :'--you' => {:name => 'you', :id => @instance.mapped_collection[:you].id},
            }
            assert_equal expected, @instance.to_simple(:changed => true)
          end

          should 'have output for items removed from collection' do
            @instance = @class.new(:'--me' => {:name => 'me'}, :'--you' => {:name => 'you'})
            @instance.mapped_collection.delete(:you)
            assert_equal({:'--you' => nil}, @instance.to_simple(:changed => true))
          end

          should 'have output for all attributes in replaced member' do
            @instance = @class.new(:'--me' => {:name => 'me'})
            @instance.mapped_collection[:me] = @instance.mapped_collection.build
            assert_equal({:'--me' => {:name => nil, :id => @instance.mapped_collection[:me].id}}, @instance.to_simple(:changed => true))
          end
        end
      end

      context 'and an array collection attribute' do
        setup do
        end
      end
    end
  end
end
