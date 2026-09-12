# frozen_string_literal: true

require_relative 'atom'

module DakiLang
  class Variable < Atom
    # Daki condition operators and their Ruby method equivalents
    CONDITION_ALIASES = { '<>' => '!=', '=' => '==' }.freeze
    CONDITION_DISPLAY = CONDITION_ALIASES.invert.freeze

    attr_reader :name, :condition, :condition_type, :condition_value

    def initialize(name, condition = nil, condition_type = nil, condition_value = nil)
      @name = name
      @condition = CONDITION_ALIASES.fetch(condition, condition)
      @condition_type = condition_type
      @condition_value = condition_value
    end

    def to_s(debug = false)
      if debug
        @to_s_debug ||= begin
          if condition
            value = condition_value

            if condition_type == 'string'
              s = rand.to_s

              value = "'#{value.gsub('\'', "\\ #{s}'")}'".gsub(" #{s}", '')
            end

            "##{name} #{condition_to_s} #{value}"
          else
            "##{name}"
          end
        end
      else
        @to_s ||= begin
          if condition
            value = condition_value

            if condition_type == 'string'
              s = rand.to_s

              value = "'#{value.gsub('\'', "\\ #{s}'")}'".gsub(" #{s}", '')
            end

            "#{name} #{condition_to_s} #{value}"
          else
            name[0] == '_' ? '_' : name
          end
        end
      end
    end

    def condition_to_s
      CONDITION_DISPLAY.fetch(condition, condition)
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
