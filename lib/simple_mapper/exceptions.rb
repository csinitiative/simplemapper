module SimpleMapper
  class Exception < ::Exception
  end
  class TypeConversionException < Exception
  end
  class InvalidTypeException < Exception
  end
end
