class String
  def const?
    self[0] != '%'
  end
end

class Integer
  def const?
    true
  end
end

class Float
  def const?
    true
  end
end
