# frozen_string_literal: true

module DakiLang
  class Atom
    def eql?(obj)
      self.class == obj.class && hash == obj.hash
    end
  end
end
