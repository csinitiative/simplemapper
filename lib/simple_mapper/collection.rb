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

      def <<(value)
        member_changed!(size, value)
        super(value)
      end

      def push(*values)
        values.each {|val| self << val }
        self
      end

      def slice!(start_or_range, length=1)
        result = nil
        original_size = size
        case start_or_range
          when Range
            result = super(start_or_range)
            if result
              change_min = start_or_range.min
            end
          else
            result = super(start_or_range, length)
            if result
              change_min = start_or_range < 0 ? original_size + start_or_range : start_or_range
            end
        end
        if result
          change_min = 0 if change_min < 0
          (change_min..original_size - 1).each {|index| member_changed!(index, self[index]) }
        end
        result
      end

      alias_method :_delete, :delete_at
      private :_delete

      def delete_at(index)
        original_size = size
        result = _delete(index)
        if size != original_size
          (index..original_size - 1).each {|idx| member_changed!(idx, self[idx])}
        end
        result
      end

      def reject!
        first = nil
        last = size - 1
        index = 0
        while index < size
          if yield(self[index])
            first ||= index
            _delete(index)
          else
            index += 1
          end
        end
        if first
          (first..last).each {|idx| member_changed!(idx, self[idx])}
          self
        else
          nil 
        end
      end

      def delete_if
        reject! {|x| yield(x)}
        self
      end
    end
  end
end
