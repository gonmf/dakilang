# frozen_string_literal: true

module OperatorClauses
  # Arithmetic operator clauses
  def oper_add(args)
    a, b = args

    if !a.is_a?(String) && !b.is_a?(String)
      a + b
    end
  end

  def oper_sub(args)
    a, b = args

    if !a.is_a?(String) && !b.is_a?(String)
      a - b
    end
  end

  def oper_mul(args)
    a, b = args

    if !a.is_a?(String) && !b.is_a?(String)
      a * b
    end
  end

  def oper_div(args)
    a, b = args

    if !a.is_a?(String) && !b.is_a?(String) && b != 0
      a / b
    end
  end

  def oper_mod(args)
    a, b = args

    if !a.is_a?(String) && !b.is_a?(String) && b != 0
      a % b
    end
  end

  def oper_pow(args)
    a, b = args

    if !a.is_a?(String) && !b.is_a?(String)
      a ** b
    end
  end

  def oper_sqrt(args)
    a, = args

    if !a.is_a?(String) && a >= 0
      Math.sqrt(a)
    end
  end

  def oper_log(args)
    a, b = args

    if !a.is_a?(String) && !b.is_a?(String)
      Math.log(a, b)
    end
  end

  def oper_round(args)
    a, b = args

    if !a.is_a?(String) && !b.is_a?(String)
      a.round(b)
    end
  end

  def oper_trunc(args)
    a, = args

    if !a.is_a?(String)
      a.to_i
    end
  end

  def oper_floor(args)
    a, = args

    if !a.is_a?(String)
      a.floor
    end
  end

  def oper_ceil(args)
    a, = args

    if !a.is_a?(String)
      a.ceil
    end
  end

  def oper_abs(args)
    a, = args

    if !a.is_a?(String)
      a.abs
    end
  end

  # Bitwise operator clauses
  def bit_and(args)
    a, b = args

    if a.is_a?(Integer) && b.is_a?(Integer)
      a & b
    end
  end

  def bit_or(args)
    a, b = args

    if a.is_a?(Integer) && b.is_a?(Integer)
      a | b
    end
  end

  def bit_xor(args)
    a, b = args

    if a.is_a?(Integer) && b.is_a?(Integer)
      a ^ b
    end
  end

  def bit_neg(args)
    a, = args

    if a.is_a?(Integer)
      ~a
    end
  end

  def bit_shift_left(args)
    a, b = args

    if a.is_a?(Integer) && b.is_a?(Integer)
      a << b
    end
  end

  def bit_shift_right(args)
    a, b = args

    if a.is_a?(Integer) && b.is_a?(Integer)
      a >> b
    end
  end

  # Equality/order operator clauses
  def oper_eql(args)
    a, b = args

    if a.is_a?(String) == b.is_a?(String) && a == b
      'yes'
    end
  end

  def oper_neq(args)
    a, b = args

    if a.is_a?(String) != b.is_a?(String) || a != b
      'yes'
    end
  end

  def oper_max(args)
    a, b = args

    if a.is_a?(String) == b.is_a?(String)
      [a, b].max
    end
  end

  def oper_min(args)
    a, b = args

    if a.is_a?(String) == b.is_a?(String)
      [a, b].min
    end
  end

  def oper_gt(args)
    a, b = args

    if a.is_a?(String) == b.is_a?(String) && a > b
      'yes'
    end
  end

  def oper_lt(args)
    a, b = args

    if a.is_a?(String) == b.is_a?(String) && a < b
      'yes'
    end
  end

  # Type casting operator clauses
  def oper_string(args)
    a, = args

    a.to_s
  end

  def oper_integer(args)
    a, = args

    a.to_i
  end

  def oper_float(args)
    a, = args

    a.to_f
  end

  # String operators
  def oper_len(args)
    a, = args

    if a.is_a?(String)
      a.size
    end
  end

  def oper_concat(args)
    a, b = args

    if a.is_a?(String) && b.is_a?(String)
      "#{a}#{b}"
    end
  end

  def oper_slice(args)
    a, b, c = args

    if a.is_a?(String) && b.is_a?(Integer) && c.is_a?(Integer)
      a.slice(b, c)
    end
  end

  def oper_index(args)
    a, b, c = args

    if a.is_a?(String) && b.is_a?(String) && c.is_a?(Integer)
      a.index(b, c)
    end
  end

  def oper_ord(args)
    a, = args

    if a.is_a?(String)
      a[0]&.ord
    end
  end

  def oper_char(args)
    a, = args

    if a.is_a?(Integer)
      a.to_i.chr
    end
  end

  # Other operator clauses
  def oper_rand(_)
    rand
  end

  def oper_type(args)
    a, = args

    a.class.to_s.downcase
  end

  def oper_print(args)
    a, = args

    puts a

    'yes'
  end

  def oper_time(_)
    (Time.now.to_f * 1000).to_i
  end
end
