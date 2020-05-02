class Fact
  attr_reader :name, :variables

  def initialize(name, variables)
    @name = name
    @variables = variables
  end

  def format(friendly)
    friendly_variables = variables.map do |var|
      if var.const?
        case var
        when String
          "'#{var}'"
        when Float, Integer
          var.to_s
        end
      else
        next var unless friendly

        start, name, oper, const_type, _ = var.split('%')
        next name unless oper

        const_value = var.slice([start, name, oper, const_type].join('_').size + 1, var.size)
        const_value = "'#{const_value}'" if const_type == 's'

        "#{name} #{oper} #{const_value}"
      end
    end

    "#{name}(#{friendly_variables.join(', ')})"
  end

  def to_s
    format(true)
  end

  def eql?(other)
    other.is_a?(Fact) && name == other.name && hash == other.hash
  end

  def hash
    vari = 0

    vars = variables.map do |var_name|
      if var_name.const?
        "#{var_name.class.to_s[0]}#{var_name}"
      else
        var_name
      end
    end

    vars.each do |var_name|
      next if var_name.const?

      vari += 1
      new_name = "%#{vari}"

      vars.each.with_index do |name, idx|
        vars[idx] = new_name if name == var_name
      end
    end

    ([name] + vars).join(';').hash
  end
end
