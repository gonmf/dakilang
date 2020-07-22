# frozen_string_literal: true

require_relative 'variable'

module DakiLang
  class Fact
    attr_reader :name, :arity, :arg_list

    def initialize(name, arg_list)
      @name = name
      @arity = arg_list.count
      @arg_list = arg_list
    end

    def arity_name
      @arity_name ||= "#{name}/#{arity}"
    end

    def to_s(debug = false)
      if debug
        @to_s_debug ||= begin
          "#{name}(#{arg_list.map { |var| var.to_s(true) }.join(', ')})"
        end
      else
        @to_s ||= begin
          "#{name}(#{arg_list.map { |var| var.to_s(false) }.join(', ')})"
        end
      end
    end

    def eql?(other)
      other.is_a?(Fact) && name == other.name && hash == other.hash
    end

    # A fact can be modified in it's variables; that's why we don't remember the hash value
    def hash
      vari = 0

      args = arg_list.clone

      args.each do |var1|
        next if var1.const?

        vari += 1
        new_var = Variable.new(vari.to_s)

        args.each.with_index do |var2, idx|
          args[idx] = new_var if !var2.const? && var2.name == var1.name
        end
      end

      ([name] + args).map { |v| v.hash }.hash
    end
  end
end
