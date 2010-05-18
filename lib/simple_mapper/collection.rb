require 'delegate'
module SimpleMapper
  module Collection
    module CommonMethods
      attr_accessor :attribute

      def build(*args)
        attribute.mapper.new(*args)
      end
    end

    class Hash < DelegateClass(::Hash)
      include CommonMethods

      def initialize(hash = {})
        super(hash)
      end
    end

    class Array < DelegateClass(::Array)
      include CommonMethods

      def initialize(array=[])
        super(array)
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
