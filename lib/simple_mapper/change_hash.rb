module SimpleMapper
  class ChangeHash < Hash
    attr_reader :all

    def all_changed!
      @all = true
    end

    def clear
      @all = false
      super
    end
  end
end
