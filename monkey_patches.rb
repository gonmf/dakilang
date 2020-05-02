class String
  def const?
    self[0] != '%'
  end

  def class_is(str)
    self.class.name.downcase == str
  end
end

class Integer
  def const?
    true
  end

  def class_is(str)
    self.class.name.downcase == str
  end
end

class Float
  def const?
    true
  end

  def class_is(str)
    self.class.name.downcase == str
  end
end
