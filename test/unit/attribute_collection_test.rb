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

    context 'changed?' do
      setup do
        @collection = {}
        @instance.stubs(:value).with(@object).returns(@collection)
      end

      context 'with empty changed_members' do
        setup do
          @collection.stubs(:changed_members).returns(SimpleMapper::ChangeHash.new)
        end

        should 'be false' do
          assert_equal false, @instance.changed?(@object)
        end

        context 'and a mapper' do
          setup do
            @mapper = stub('mapper')
            @instance.mapper = @mapper
            @keys = [:a, :b, :c]
            @keys.each do |key|
              item = stub('item_' + key.to_s)
              @collection[key] = item
            end
          end

          should 'be false if no mapped values are changed' do
            @collection.values.each {|item| item.stubs(:changed?).with.returns(false)}
            assert_equal false, @instance.changed?(@object)
          end

          should 'be true if any mapped values are changed' do
            item = @keys.pop
            @collection[item].stubs(:changed?).with.returns(true)
            @keys.each {|x| @collection[x].stubs(:changed?).with.returns(false)}
            assert_equal true, @instance.changed?(@object)
          end
        end
      end

      should 'be true if changed_members is populated' do
        hash = SimpleMapper::ChangeHash.new
        hash[:foo] = true
        @collection.stubs(:changed_members).returns(hash)
        assert_equal true, @instance.changed?(@object)
      end
    end

    should 'pass keys through unchanged for :to_simple_key' do
      items = ['a string', :a_symbol, 666]
      assert_equal(items, items.collect {|item| @instance.to_simple_key(item)})
    end

    should 'pass keys through unchanged for :from_simple_key' do
      items = ['another string', :another_symbol, 444]
      assert_equal(items, items.collect {|item| @instance.from_simple_key(item)})
    end

    context 'for source value' do
      should 'get its container value from :new_collection' do
        @instance.expects(:new_collection).returns(container = stub('container'))
        assert_equal(container, @instance.source_value(@object))
      end

      should 'determine keys for the mapped structure via :from_simple_key' do
        source_additional = {:a => 'A', :abc => 'ABC', :aarp => 'AARP'}
        @instance.stubs(:member_key).returns(false)
        expected = source_additional.inject({}) do |hash, keyval|
          @instance.stubs(:member_key?).with(keyval[0]).returns(true)
          key = keyval[0].to_s + ' transformed'
          hash[key] = keyval[1]
          @instance.expects(:from_simple_key).with(keyval[0]).returns(key)
          hash
        end
        @source.merge! source_additional
        result = @instance.source_value(@object)
        assert_equal expected, result
      end

      should 'return empty hash if no keys in the source pass the member_key? test' do
        # note that this depends on member_key? being a default-false method in the module
        assert_equal({}, @instance.source_value(@object))
      end

      should 'return hash with key/value pairs for only the keys passing member_key? test' do
        expected = {:a => 'A', :abc => 'ABC', :aarp => 'AARP'}
        @source.merge! expected
        @instance.stubs(:member_key).returns(false)
        expected.keys.each do |key|
          @instance.expects(:member_key?).with(key).returns(true)
        end
        assert_equal expected, @instance.source_value(@object)
      end
    end


    context 'for transformed_source_value' do
      setup do
        @expected_source  = {:a => 'A', :aa => 'AA'}
        @expected_default = {:a => 'Default A', :aa => 'Default AA'}
        @instance.stubs(:default_value).with(@object).returns(@expected_default)
      end

      should 'return the source value if there is no type and source is non-empty' do
        @instance.stubs(:source_value).with(@object).returns(@expected_source)
        assert_equal @expected_source, @instance.transformed_source_value(@object)
      end

      should 'return the default value if there is no type and source is empty' do
        @instance.stubs(:source_value).with(@object).returns(nil)
        assert_equal @expected_default, @instance.transformed_source_value(@object)
      end

      context 'with a type' do
        setup do
          @instance.type = stub('type')
        end

        should 'return the result of apply type given the source value' do
          @instance.expects(:apply_type).with(@expected_source).returns( expected = {:a => 'Foo'})
          @instance.stubs(:source_value).with(@object).returns(@expected_source)
          result = @instance.transformed_source_value(@object)
          assert_equal expected, result
        end

        should 'return the result of the apply type given the default value and empty source' do
          @instance.expects(:apply_type).with(@expected_default).returns( expected = {:a => 'Default'} )
          @instance.stubs(:source_value).with(@object).returns(nil)
          result = @instance.transformed_source_value(@object)
          assert_equal expected, result
        end
      end
    end

    context 'for freeze_for' do
      setup do
        @collection = [:a, :b, :c].inject({}) {|hash, name| hash[name] = stub(name.to_s); hash}
        @object = stub('object')
        @instance.stubs(:value).with(@object).returns(@collection)
      end

      context 'with simple values' do
        should 'freeze the collection and leave members alone' do
          @collection.values.each {|member| member.expects(:freeze).never}
          @collection.expects(:freeze).with.once
          @instance.freeze_for(@object)
        end
      end

      context 'with mapped values' do
        setup do
          @instance.mapper = stub('mapper', :encode => 'foo')
          @instance.type = @instance.mapper
        end

        should 'freeze the collection and each collection member' do
          @collection.values.each {|member| member.expects(:freeze).with.once}
          @collection.expects(:freeze).with.once
          @instance.freeze_for(@object)
        end
      end
    end

    context 'for to_simple' do
      context 'with simple values' do
        setup do
          @container_extra = {:foo => 'foo', :bar => 'bar'}
          @container_added = {:a => 'A', :ab => 'AB'}
          @value = @container_added.clone
          @changed_members = SimpleMapper::ChangeHash.new
          @value.stubs(:simple_mapper_changes).returns(@changed_members)
        end

        should 'add keys and values to container' do
          @instance.expects(:value).with(@object).returns(@value)
          result = @instance.to_simple(@object, @container_extra.clone)
          assert_equal @container_extra.merge(@container_added), result
        end

        should 'filters keys through :to_simple_key when adding to container' do
          @instance.expects(:value).with(@object).returns(@value)
          expectation = {}
          @container_added.each do |k, v|
            key = k.to_s + ' transformed'
            expectation[key] = v
            @instance.expects(:to_simple_key).with(k).returns(key)
          end
          result = @instance.to_simple(@object, @container_extra.clone)
          assert_equal @container_extra.merge(expectation), result
        end

        should 'encode typed values' do
          @instance.type = mock('type')
          @instance.expects(:value).with(@object).returns(@value)
          expectation = {}
          @container_added.each do |k, v|
            expectation[k] = v + ' encoded'
            @instance.type.expects(:encode).with(v).returns(expectation[k])
          end
          result = @instance.to_simple(@object, @container_extra.clone)
          assert_equal @container_extra.merge(expectation), result
        end

        context 'with changes' do
          setup do
            @instance.expects(:value).with(@object).returns(@value)
            @value.instance_eval do
              def is_member?(key)
                key? key
              end
            end
          end

          context 'and :changed option' do
            should 'not include any unchanged members' do
              result = @instance.to_simple(@object, @container_extra.clone, :changed => true)
              assert_equal @container_extra, result
            end

            should 'include members that are changed' do
              key = @container_added.keys.first
              @changed_members[key] = true
              result = @instance.to_simple(@object, @container_extra.clone, :changed => true)
              assert_equal @container_extra.merge(key => @container_added[key]), result
            end

            should 'include members that are deleted' do
              @changed_members[:removed_a] = true
              @changed_members[:removed_b] = true
              result = @instance.to_simple(@object, @container_extra.clone, :changed => true)
              deletes = @changed_members.keys.inject({}) {|m,k| m[k] = nil; m}
              assert_equal @container_extra.merge(deletes), result
            end
          end

          context 'and :all option' do
            setup do
              @changed_members[:removed_a] = true
              @changed_members[:removed_b] = true
            end

            should 'include all members included deleted ones' do
              result = @instance.to_simple(@object, @container_extra.clone, :all => true)
              deletes = @changed_members.keys.inject({}) {|m,k| m[k] = nil; m}
              assert_equal @container_extra.merge(@container_added).merge(deletes), result
            end

            should 'not included deleted members if :defined option present' do
              result = @instance.to_simple(@object, @container_extra.clone, :all => true, :defined => true)
              assert_equal @container_extra.merge(@container_added), result
            end
          end
        end
      end

      context 'with mapped values' do
        setup do
          @instance.mapper = stub('mapper', :encode => 'foo')
          @instance.type = @instance.mapper
          @base_value = {}
          @changed_members = SimpleMapper::ChangeHash.new
          @base_value.stubs(:simple_mapper_changes).returns(@changed_members)
          @expected_value = {}
          @container = {}
        end

        should 'apply to_simple on values' do
          [:a, :ab, :abc].each do |sym|
            val = sym.to_s.upcase
            expect = val + ' simplified'
            @expected_value[sym] = {sym => expect}
            @base_value[sym] = mock(val)
            @base_value[sym].expects(:to_simple).with({}).returns(@expected_value[sym].clone)
          end
          @instance.expects(:value).with(@object).returns(@base_value)
          result = @instance.to_simple(@object, @container) || {}
          assert_equal @expected_value, result
        end

        should 'apply to_simple on values and use string keys on collection when requested' do
          [:a, :ab, :abc].each do |sym|
            val = sym.to_s.upcase
            expect = val + ' simplified'
            @expected_value[sym.to_s] = {sym.to_s => expect}
            @base_value[sym] = mock(val)
            @base_value[sym].expects(:to_simple).with({:string_keys => true}).returns(@expected_value[sym.to_s].clone)
          end
          @instance.expects(:value).with(@object).returns(@base_value)
          result = @instance.to_simple(@object, @container, :string_keys => true) || {}
          assert_equal @expected_value, result
        end

        context 'with :changed' do
          should 'include members marked as changed in the collection and members that identify themselves as changed' do
            [:collection_changed, :item_changed, :not_changed].each do |sym|
              val = sym.to_s.upcase
              expect = val + ' simplified'
              @expected_value[sym] = {sym => expect}
              @base_value[sym] = mock(val)
              @base_value[sym].stubs(:to_simple).with({:changed => true}).returns(@expected_value[sym].clone)
              @base_value.instance_eval do
                def is_member?(key)
                  key? key
                end
              end
            end
            @base_value[:item_changed].expects(:changed?).with.returns(true)
            @base_value[:not_changed].expects(:changed?).with.returns(false)
            @base_value[:collection_changed].expects(:changed?).never
            @changed_members[:collection_changed] = true
            @instance.expects(:value).with(@object).returns(@base_value)
            result = @instance.to_simple(@object, @container, :changed => true)
            @expected_value.delete(:not_changed)
            assert_equal @expected_value, result
          end
        end
      end
    end

    context 'when applying type to a source/default value' do
      setup do
        @input    = {:a => 'A', :abc => 'ABC', :aabb => 'AABB'}
        @expected = @input.inject({}) {|h, kv| h[kv[0]] = kv[1] + ' encoded'; h}
        @type     = stub('type')
        @instance.stubs(:converter).returns(@type)
      end

      should 'decode all values in the input hash' do
        @expected.each do |key, value|
          @type.expects(:decode).with(@input[key]).returns(value)
        end
        @instance.apply_type(@input)
      end

      should 'return new collection hash of keys mapped to decoded values' do
        @expected.each do |key, value|
          @type.stubs(:decode).with(@input[key]).returns(value)
        end
        result = @instance.apply_type(@input)
        assert_equal @expected, result
        assert_equal SimpleMapper::Collection::Hash, result.class
      end

      should 'initialize collection hash with the attribute instance' do
        @expected.each do |key, value|
          @type.stubs(:decode).with(@input[key]).returns(value)
        end
        result = @instance.apply_type(@input)
        assert_equal @instance, result.attribute
      end
    end
  end
end
