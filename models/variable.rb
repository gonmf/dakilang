require_relative 'atom'

class Variable < Atom
  attr_reader :name, :condition, :condition_type, :condition_value, :real_condition

  def initialize(name, condition = nil, condition_type = nil, condition_value = nil)
    @name = name
    @condition = condition
    @condition_type = condition_type
    @condition_value = condition_value

    if condition == '<>'
      @real_condition = '!='
    else
      @real_condition = condition
    end
  end

  def to_s
    @to_s ||= begin
      if condition
        value = condition_value

        if condition_type == 'string'
          s = "#{rand}#{rand}#{rand}".tr('0', '')

          value = "'#{value.gsub('\'', "\\ #{s}'")}'".gsub(" #{s}", '')
        end

        "#{name} #{condition} #{value}"
      else
        name.to_s
      end
    end
  end

  def const?
    false
  end

  def clone
    Variable.new(name, condition, condition_type, condition_value)
  end

  def hash
    @hash ||= [name, real_condition, condition_type, condition_value].hash
  end
end
