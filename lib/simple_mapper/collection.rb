require 'delegate'
module SimpleMapper
  module Collection
    class Hash < DelegateClass(::Hash)
      attr_accessor :attribute

      def initialize(hash = {})
        super(hash)
      end

      def build(*args)
        attribute.mapper.new(*args)
      end
    end
  end
end
