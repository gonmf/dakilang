require_relative 'variable'

class Fact
  attr_reader :name, :arg_list

  def initialize(name, arg_list)
    @name = name
    @arg_list = arg_list
  end

  def arity_name
    @arity_name ||= "#{name}/#{arg_list.count}"
  end

  def to_s
    "#{name}(#{arg_list.map(&:to_s).join(', ')})"
  end

  def eql?(other)
    other.is_a?(Fact) && name == other.name && hash == other.hash
  end

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
