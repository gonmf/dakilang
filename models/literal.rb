# frozen_string_literal: true

require_relative 'atom'

module DakiLang
  class Literal < Atom
    attr_reader :value

    def initialize(value)
      @value = value
    end

    def type
      @type ||= value.is_a?(Array) ? 'list' : value.class.to_s.downcase
    end

    def to_s(debug = false)
      @to_s ||= begin
        if value.is_a?(Array)
          values = value.map do |val|
            Literal.new(val).to_s
          end

          "[#{values.join(', ')}]"
        elsif value.is_a?(String)
          s = "#{rand}#{rand}#{rand}".tr('0', '')

          "'#{value.gsub('\'', "\\ #{s}'")}'".gsub(" #{s}", '')
        elsif value.is_a?(Float)
          s = sprintf('%0.12f', value)

          while s.end_with?('0') && !s.end_with?('.0')
            s = s.chomp('0')
          end

          s
        else
          value.to_s
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
end
