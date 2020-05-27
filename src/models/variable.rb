# frozen_string_literal: true

require_relative 'atom'

module DakiLang
  class Variable < Atom
    attr_reader :name, :condition, :condition_type, :condition_value

    def initialize(name, condition = nil, condition_type = nil, condition_value = nil)
      @name = name
      @condition = condition == '<>' ? '!=' : condition
      @condition_type = condition_type
      @condition_value = condition_value
    end

    def to_s(debug = false)
      if debug
        if condition
          value = condition_value

          if condition_type == 'string'
            s = rand.to_s.tr('.', '')

            value = "'#{value.gsub('\'', "\\ #{s}'")}'".gsub(" #{s}", '')
          end

          "#{debug ? '#' : ''}#{name} #{condition == '!=' ? '<>' : condition} #{value}"
        else
          "#{debug ? '#' : ''}#{name}"
        end
      else
        @to_s ||= begin
          if condition
            value = condition_value

            if condition_type == 'string'
              s = rand.to_s.tr('.', '')

              value = "'#{value.gsub('\'', "\\ #{s}'")}'".gsub(" #{s}", '')
            end

            "#{name} #{condition == '!=' ? '<>' : condition} #{value}"
          else
            "#{name}"
          end
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
      @hash ||= [name, condition, condition_type, condition_value].hash
    end
  end
end
