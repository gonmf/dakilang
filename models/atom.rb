class Atom
  def eql?(obj)
    self.class == obj.class && hash == obj.hash
  end
end
