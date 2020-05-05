class Fact
  attr_reader :name, :arg_list

  def initialize(name, arg_list)
    @name = name
    @arg_list = arg_list
  end

  def arity_name
    @arity_name ||= "#{name}/#{arg_list.count}"
  end

  def format(friendly)
    s = "#{rand}#{rand}#{rand}".tr('.0', '')

    friendly_args = arg_list.map do |var|
      if var.const?
        case var
        when String
          "'#{var.gsub('\'', "\\ #{s}'")}'".gsub(" #{s}", '')
        when Float, Integer
          var.to_s
        end
      else
        next var unless friendly

        start, name, oper, const_type, = var.split('%')
        next name unless oper

        const_value = var.slice([start, name, oper, const_type].join('_').size + 1, var.size)
        const_value = "'#{const_value.gsub('\'', "\\ #{s}'")}'".gsub(" #{s}", '') if const_type == 's'

        "#{name} #{oper} #{const_value}"
      end
    end

    "#{name}(#{friendly_args.join(', ')})"
  end

  def to_s
    format(true)
  end

  def eql?(other)
    other.is_a?(Fact) && name == other.name && hash == other.hash
  end

  def hash
    vari = 0

    args = arg_list.clone

    args.each do |var_name|
      next if var_name.const?

      vari += 1
      new_name = vari.to_s

      args.each.with_index do |name, idx|
        args[idx] = new_name if name == var_name
      end
    end

    ([name] + args).hash
  end
end
