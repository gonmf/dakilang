# frozen_string_literal: true

module DakiLang
  module OperatorClauses
    # Arithmetic operator clauses
    def oper_add(args)
      if args.all? { |a| numeric?(a) }
        args.sum
      end
    end

    def oper_sub(args)
      a, b = args

      if numeric?(a) && numeric?(b)
        a - b
      end
    end

    def oper_mul(args)
      if args.all? { |a| numeric?(a) }
        res = 1

        args.each do |arg|
          res += arg
        end

        res
      end
    end

    def oper_div(args)
      a, b = args

      if numeric?(a) && numeric?(b) && b != 0
        a / b
      end
    end

    def oper_mod(args)
      a, b = args

      if numeric?(a) && numeric?(b) && b != 0
        a % b
      end
    end

    def oper_pow(args)
      a, b = args

      if numeric?(a) && numeric?(b) && b >= 0
        a ** b
      end
    end

    def oper_sqrt(args)
      a, = args

      if numeric?(a) && a >= 0
        Math.sqrt(a)
      end
    end

    def oper_log(args)
      a, b = args

      if numeric?(a) && numeric?(b) && a > 0 && b > 1
        Math.log(a, b)
      end
    end

    def oper_round(args)
      a, b = args

      if numeric?(a) && numeric?(b) && b >= 0
        a.round(b)
      end
    end

    def oper_trunc(args)
      a, = args

      if numeric?(a)
        a.to_i
      end
    end

    def oper_floor(args)
      a, = args

      if numeric?(a)
        a.floor
      end
    end

    def oper_ceil(args)
      a, = args

      if numeric?(a)
        a.ceil
      end
    end

    def oper_abs(args)
      a, = args

      if numeric?(a)
        a.abs
      end
    end

    def oper_eval(args)
      vars = args.slice(0, args.size - 1)
      str = args.last

      if vars.all? { |a| numeric?(a) } && str.is_a?(String)
        expr = str.tr(' ', '')

        vars.each.with_index do |_, idx|
          idx = vars.count - idx - 1
          val = vars[idx]
          new_expr = expr.gsub("$#{idx}", val.to_s)

          if expr == new_expr # Some variable was not unified
            return nil
          end

          expr = new_expr
        end

        if !expr.include?('$') # Some variable was not unified
          expr_eval(expr)
        end
      end
    end

    # Bitwise operator clauses
    def oper_bit_and(args)
      a, b = args

      if a.is_a?(Integer) && b.is_a?(Integer)
        a & b
      end
    end

    def oper_bit_or(args)
      a, b = args

      if a.is_a?(Integer) && b.is_a?(Integer)
        a | b
      end
    end

    def oper_bit_xor(args)
      a, b = args

      if a.is_a?(Integer) && b.is_a?(Integer)
        a ^ b
      end
    end

    def oper_bit_neg(args)
      a, = args

      if a.is_a?(Integer)
        ~a
      end
    end

    def oper_bit_shift_left(args)
      a, b = args

      if a.is_a?(Integer) && b.is_a?(Integer)
        a << b
      end
    end

    def oper_bit_shift_right(args)
      a, b = args

      if a.is_a?(Integer) && b.is_a?(Integer)
        a >> b
      end
    end

    # Equality/order operator clauses
    def oper_eql(args)
      a, b = args

      if a == b
        'Yes'
      end
    end

    def oper_neq(args)
      a, b = args

      if a != b
        'Yes'
      end
    end

    def oper_gt(args)
      a, b = args

      if ((a.is_a?(String) == b.is_a?(String)) || (numeric?(a) && numeric?(b))) && a > b
        'Yes'
      end
    end

    def oper_lt(args)
      a, b = args

      if ((a.is_a?(String) == b.is_a?(String)) || (numeric?(a) && numeric?(b))) && a < b
        'Yes'
      end
    end

    def oper_gte(args)
      a, b = args

      if ((a.is_a?(String) == b.is_a?(String)) || (numeric?(a) && numeric?(b))) && a >= b
        'Yes'
      end
    end

    def oper_lte(args)
      a, b = args

      if ((a.is_a?(String) == b.is_a?(String)) || (numeric?(a) && numeric?(b))) && a <= b
        'Yes'
      end
    end

    # Type casting operator clauses
    def oper_as_string(args)
      a, b = args

      if b
        a.to_s(b) if a.is_a?(Integer) && b.is_a?(Integer)
      else
        a.to_s
      end
    end

    def oper_as_integer(args)
      a, b = args

      if b
        if a.is_a?(String) && b.is_a?(Integer)
          a.to_i(b)
        end
      elsif a.is_a?(Array)
        a.count
      else
        a.to_i
      end
    end

    def oper_as_float(args)
      a, = args

      if a.is_a?(Array)
        a.count.to_f
      else
        a.to_f
      end
    end

    # String and list operators
    def oper_len(args)
      a, = args

      if a.is_a?(String) || a.is_a?(Array)
        a.size
      end
    end

    def oper_concat(args)
      if args.all? { |a| a.is_a?(String) }
        args.join
      elsif args.all? { |a| a.is_a?(Array) }
        res = []

        args.each do |a|
          res += a
        end

        res
      end
    end

    def oper_slice(args)
      a, b, c = args

      if (a.is_a?(String) || a.is_a?(Array)) && b.is_a?(Integer) && c.is_a?(Integer) && b >= 0 && c >= b
        a.slice(b, c - 2)
      end
    end

    def oper_index(args)
      a, b, c = args

      if a.is_a?(String) && b.is_a?(String) && c.is_a?(Integer)
        a.index(b, c) || -1
      elsif a.is_a?(Array) && c.is_a?(Integer)
        idx = a.slice(c, a.count)&.index(b)

        idx ? idx + c : -1
      end
    end

    # String operators
    def oper_ord(args)
      a, = args

      if a.is_a?(String)
        a[0]&.ord
      end
    rescue StandardError
      nil
    end

    def oper_char(args)
      a, = args

      if a.is_a?(Integer) && a >= 0
        a.chr
      end
    rescue StandardError
      nil
    end

    def oper_split(args)
      a, b = args

      if a.is_a?(String) && b.is_a?(String)
        a.split(b)
      end
    end

    # List operator clauses
    def oper_head(args)
      a, = args

      if a.is_a?(Array)
        a[0]
      end
    end

    def oper_tail(args)
      a, = args

      if a.is_a?(Array)
        a.slice(1, a.count)
      end
    end

    def oper_push(args)
      a, b = args

      if a.is_a?(Array)
        [b] + a
      end
    end

    def oper_append(args)
      a, b = args

      if a.is_a?(Array)
        a + [b]
      end
    end

    def oper_put(args)
      a, b, c = args

      if a.is_a?(Array) && c.is_a?(Integer) && c >= 0 && c <= a.count
        a.slice(0, c) + [b] + a.slice(c, a.count)
      end
    end

    def oper_unique(args)
      a, = args

      if a.is_a?(Array)
        unique = []

        a.each do |element|
          unique.push(element) unless unique.include?(element)
        end

        unique
      end
    end

    def oper_reverse(args)
      a, = args

      if a.is_a?(Array)
        a.reverse
      end
    end

    def oper_sort(args)
      a, = args

      if a.is_a?(Array)
        a.sort
      end
    rescue StandardError
      nil
    end

    def oper_sum(args)
      a, = args

      if a.is_a?(Array)
        a.sum
      end
    rescue StandardError
      nil
    end

    def oper_max(args)
      if args.count == 1
        a, = args

        if a.is_a?(Array)
          a.max
        end
      elsif similar_types?(args)
        args.max
      end
    rescue StandardError
      nil
    end

    def oper_min(args)
      if args.count == 1
        a, = args

        if a.is_a?(Array)
          a.min
        end
      elsif similar_types?(args)
        args.min
      end
    rescue StandardError
      nil
    end

    def oper_join(args)
      a, b = args

      if a.is_a?(Array) && b.is_a?(String)
        a.join(b)
      end
    end

    def oper_init(args)
      a, b = args

      if a.is_a?(Integer) && a >= 0
        Array.new(a, b)
      end
    end

    # Other operator clauses
    def oper_set(args)
      a, = args

      a
    end

    def oper_rand(_)
      rand
    end

    def oper_type(args)
      a, = args

      if a.is_a?(Array)
        'list'
      else
        a.class.to_s.downcase
      end
    end

    def oper_print(args)
      a, = args

      puts a

      'Yes'
    end

    def oper_time(_)
      (Time.now.to_f * 1000).to_i
    end

    private

    def numeric?(obj)
      obj.is_a?(Integer) || obj.is_a?(Float)
    end

    def similar_types?(args)
      a = args.first

      args.all? do |b|
        (numeric?(a) && numeric?(b)) || (a.is_a?(String) && b.is_a?(String)) || (a.is_a?(Array) && b.is_a?(Array))
      end
    end

    def expr_val(str)
      str.include?('.') ? str.to_f : str.to_i
    end

    def sub_exp(str)
      depth = 0

      str.chars.each.with_index do |c, i|
        if c == ')'
          if depth == 0
            return str.slice(0, i)
          elsif depth > 0
            depth -= 1
          else
            break
          end
        elsif c == '('
          depth += 1
        end
      end

      nil
    end

    def expr_eval(str)
      string = ''
      value = nil
      op = nil

      str.chars.each.with_index do |c, i|
        if c == '('
          exp = sub_exp(str.slice(i + 1, str.size))
          return nil unless exp

          val = expr_eval(exp)
          return nil unless val

          new_exp = str.sub("(#{exp})", val.to_s)

          return expr_eval(new_exp)
        end

        if c == ')'
          return nil
        end

        if c == '~'
          if value || op || string.size > 0
            return nil
          end

          op = '~'
          next
        end

        if ['+', '-', '*', '/', '%', '&', '|', '^'].include?(c)
          if c == '-' && value && op && string == ''
            string += '-'
            next
          end
          if ['+', '-'].include?(c) && value.nil? && string == ''
            value = 0
            op = '-'
            next
          end

          if !value && string.size > 0
            if op == '~'
              begin
                value = expr_val(string).send('~')
              rescue StandardError
                return nil
              end
            else
              value = expr_val(string)
            end

            op = c
            string = ''
            next
          elsif value && string.size > 0
            begin
              value = value.send(op, expr_val(string))
            rescue StandardError
              return nil
            end

            op = c
            string = ''
            next
          else
            next
          end
        end

        string += c
      end

      if string.size > 0
        if op == '~'
          return nil if value

          begin
            value = expr_val(string).send('~')
          rescue StandardError
            return nil
          end
        elsif op && value
          begin
            value = value.send(op, expr_val(string))
          rescue StandardError
            return nil
          end
        elsif !op && !value
          value = expr_val(string)
        end
      end

      value
    end
  end
end
