require 'delegate'
module SimpleMapper
  module Collection
    module CommonMethods
      attr_accessor :attribute
      attr_accessor :change_tracking

      def simple_mapper_changes
        @simple_mapper_changes ||= SimpleMapper::ChangeHash.new
      end

      def changed_members
        simple_mapper_changes.keys
      end

      def member_changed!(key, value)
        return nil unless change_tracking
        # If the key is new to the collection, we're fine.
        # If the key is already in the collection, then we have to consider
        # whether or not value is itself a mapper.  If it is, we want it to consider
        # all of its attributes changed, since they are all replacing whatever was
        # previously associated with +key+ in the collection.
        if is_member?(key) and ! value.nil? and value.respond_to?(:all_changed!)
          value.all_changed!
        end
        simple_mapper_changes[key] = true
      end

      # Predicate that returns +true+ if _key_ is present in the collection.
      # Returns +nil+ by default; this must be implemented appropriately per
      # class that uses this module.
      def is_member?(key)
        nil
      end

      def []=(key, value)
        member_changed!(key, value)
        super(key, value)
      end

      def build(*args)
        attribute.mapper.new(*args)
      end
    end

    class Hash < DelegateClass(::Hash)
      include CommonMethods

      def is_member?(key)
        key? key
      end

      def initialize(hash = {})
        super(hash)
      end

      def delete(key)
        member_changed!(key, nil)
        super(key)
      end

      def reject!
        changed = false
        each do |key, val|
          if yield(key, val)
            changed = true
            delete(key)
          end
        end
        changed ? self : nil
      end

      def delete_if
        reject! {|k, v| yield(k, v)}
        self
      end
    end

    class Array < DelegateClass(::Array)
      include CommonMethods

      def initialize(array=[])
        super(array)
      end

      def is_member?(key)
        key = key.to_i
        key >= 0 and key < size
      end

      def keys
        (0..size - 1).to_a
      end

      def inject(*args)
        (0..size - 1).inject(*args) {|accum, key| yield(accum, [key, self[key]])}
      end
    end
  end
end
