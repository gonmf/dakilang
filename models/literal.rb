require_relative 'atom'

class Literal < Atom
  attr_reader :value

  def initialize(value)
    @value = value
  end

  def type
    @type ||= value.class.to_s.downcase
  end

  def to_s
    @to_s ||= begin
      if value.is_a?(String)
        s = "#{rand}#{rand}#{rand}".tr('0', '')

        "'#{value.gsub('\'', "\\ #{s}'")}'".gsub(" #{s}", '')
      else
        value
      end
    end
  end

  def const?
    true
  end

  def clone
    Literal.new(value)
  end

  def hash
    @hash ||= value.hash
  end
end
