# frozen_string_literal: true

module DakiLang
  module Parser
    INLINE_OPERATORS = ['-', '+', '-', '*', '/', '%', '&', '|', '^', '~', '(', ')'].freeze
    HEX_CHARS = (('0'..'9').to_a + ('a'..'f').to_a).freeze
    OCTAL = ('0'..'7').to_a.freeze
    NUMERIC = ('0'..'9').to_a.freeze
    NUMERIC_ALLOWED_CHARS = (['-', '.', 'b', 'x'] + ('0'..'9').to_a + ('a'..'f').to_a + ('A'..'F').to_a).freeze

    NAME_ALLOWED_FIRST_CHARS = (('a'..'z').to_a + ('A'..'Z').to_a).freeze
    NAME_ALLOWED_REMAINING_CHARS = (['_'] + ('a'..'z').to_a + ('A'..'Z').to_a + ('0'..'9').to_a).freeze

    STRING_ESCAPED_CHARACTERS = {
      "'" => "'",
      '"' => '"',
      'n' => "\n",
      'r' => "\r",
      't' => "\t",
      '\\' => '\\'
    }.freeze

    def parser(text)
      orig_text = text
      @parser_var_gen_idx = 0

      text = text.strip

      text, lists_table = extract_lists(text)
      text, strings_table = extract_strings(text)

      text = text.split('#').first&.strip
      return nil if text.nil? || text == ''

      text, instruction_type = extract_type_of_instruction(text)
      is_query = instruction_type.include?('_query')
      text = text.tr(" \t", '')

      # Transform AND/OR mixed clauses into exclusive AND clauses
      head, tails = expand_logical_relations(text, strings_table, lists_table, is_query)

      parser_error('Query clause must not have a tail') if tails.any? && is_query

      tails = tails.map do |tail|
        tail.map { |fact| parse_body_fact(fact, strings_table, lists_table) }.flatten
      end

      if tails.any?
        [instruction_type, tails.map { |tail| [head] + tail }]
      else
        [instruction_type, [[head]]]
      end
    end

    def clause_to_s(obj)
      case obj
      when Array
        "(#{obj.map { |o| clause_to_s(o) }.join(' ')})"
      when Fact
        "(#{obj.name} #{clause_to_s(obj.arg_list)})"
      when Variable
        "(var #{obj.to_s})"
      when Literal
        "(#{obj.type} #{obj.to_s})"
      else
        obj.to_s
      end
    end

    private

    def expand_logical_relations(text, strings_table, lists_table, is_query)
      head, tail = text.split(':-')
      head = parse_head_fact(head, strings_table, lists_table, is_query)
      return [head, []] unless tail

      tail = parse_relations_tree(tail, '(', ')', [',', ';'])

      tails = recursive_build_and_clauses(tail)

      [head, tails]
    end

    def recursive_build_and_clauses(oper_w_tail)
      if oper_w_tail.is_a?(String)
        return [[oper_w_tail]]
      end

      operation, *tail = oper_w_tail

      if operation == ',' # and

        tail_and_parts = tail.map { |part| recursive_build_and_clauses(part) }
        return tail_and_parts.first if tail_and_parts.count == 1

        ret = join_tail_and_parts(tail_and_parts)

        ret
      else # or
        ret = []

        tail.each do |part|
          ret = ret + recursive_build_and_clauses(part)
        end

        ret
      end
    end

    def join_tail_and_parts(parts)
      start_part = parts[0]

      parts.slice(1..-1).each do |part|
        expanded = start_part.map { |p| part.map { |p2| p + p2 } }

        start_part = []

        expanded.each do |part|
          start_part += part
        end

        start_part
      end

      start_part
    end

    def splitter(str, arrs)
      parts = [" #{str} "]

      arrs.each do |c|
        parts = parts.map { |s| s == c ? s : s.split(c).map { |v| [c, " #{v} "] }.flatten.slice(1..-1) }.flatten.compact
      end

      parts.map { |s| s.strip }.select { |s| s.size > 0 }
    end

    def invert_operator(str)
      if str == '<>'
        str
      elsif str[0] == '<'
        str.sub('<', '>')
      elsif str[0] == '>'
        str.sub('>', '<')
      else
        str
      end
    end

    def parse_argument(arg, strings_table, lists_table)
      if arg.start_with?('$L')
        list_id = arg.slice(2..-1).to_i

        parse_list(lists_table[list_id])
      elsif arg.start_with?('$S')
        string_id = arg.slice(2..-1).to_i

        strings_table[string_id]
      else
        parse_numeric(arg)
      end
    end

    def parse_list(text)
      recursive_parse_list(text.chars.slice(1..-1), 0).first
    end

    def recursive_parse_list(chars, idx)
      ret = []

      c = nil
      prev_c = nil
      string_delimiter = nil
      escape_mode = false
      escaped_string = ''
      string_mode = false
      string = ''

      while chars[idx] do
        prev_c = c
        c = chars[idx]

        if string_mode
          if escaped_string.size == 4
            if HEX_CHARS.include?(c.downcase)
              escaped_string += c.downcase
              begin
                string += escaped_string.slice(1..-1).to_i(16).chr(Encoding::UTF_8)
                escaped_string = ''
                escape_mode = false
              rescue
                unexpected_char(c)
              end
            else
              unexpected_char(c)
            end
          elsif escaped_string.size == 3
            if HEX_CHARS.include?(c.downcase)
              escaped_string += c.downcase
            else
              unexpected_char(c)
            end
          elsif escaped_string.size == 2
            if HEX_CHARS.include?(c.downcase)
              escaped_string += c.downcase
              if escaped_string[0] == 'x'
                begin
                  string += escaped_string.slice(1..-1).to_i(16).chr
                  escaped_string = ''
                  escape_mode = false
                rescue
                  unexpected_char(c)
                end
              end
            else
              unexpected_char(c)
            end
          elsif escaped_string.size == 1
            if HEX_CHARS.include?(c.downcase)
              escaped_string += c.downcase
            else
              unexpected_char(c)
            end
          elsif escape_mode
            if c == 'x' || c == 'u'
              escaped_string = c
            elsif STRING_ESCAPED_CHARACTERS[c]
              string += STRING_ESCAPED_CHARACTERS[c]
              escape_mode = false
            else
              unexpected_char('\\')
            end
          elsif c == '\\'
            escape_mode = true
          elsif c == string_delimiter
            ret.push(string)
            string = ''
            string_mode = false
          else
            string += c
          end

          idx += 1
          next
        elsif c == "'" || c == '"'
          unexpected_char(c) if string.strip.size > 0

          unexpected_char(string.strip[0]) if string.strip.size > 0

          string = ''
          string_delimiter = c
          string_mode = true
          idx += 1
          next
        end

        if c == '['
          sub_list, idx = recursive_parse_list(chars, idx + 1)

          ret.push(sub_list)
          next
        end

        if c == ']'
          if string.strip.size > 0
            ret.push(parse_numeric(string.strip))
            string = ''
          end

          return [ret, idx + 1]
        end

        if c == ','
          unexpected_char(',') if prev_c == ','

          if string.strip.size > 0
            ret.push(parse_numeric(string.strip))
            string = ''
          end

          idx += 1
          next
        end

        string += c
        idx += 1
      end

      parser_error('Unterminated list')
    end

    def parse_numeric(text)
      if text.start_with?('.')
        text = "0#{text}"
      end

      orig_text = text

      text = text.slice(1, text.size) if text[0] == '-'

      unexpected_char('-') if text.size == 0

      if text.include?('.') # Floating point
        integer, decimal, err = text.split('.')
        unexpected_char('.') if !decimal || err

        if all_chars?(integer, NUMERIC) && all_chars?(decimal, NUMERIC)
          orig_text.to_f
        else
          unexpected_char((integer + decimal).chars.find { |c| !NUMERIC.include?(c) })
        end
      elsif text.start_with?('0x') # Hexadecimal
        rest = text.slice(2, text.size)

        if rest.size == 0
          parser_error('Unterminated integer in hexadecimal format')
        elsif all_chars?(rest.downcase, HEX_CHARS)
          orig_text.to_i(16)
        else
          unexpected_char(rest.chars.find { |c| !HEX_CHARS.include?(c) })
        end
      elsif text.start_with?('0b') # Binary
        rest = text.slice(2, text.size)

        if rest.size == 0
          parser_error('Unterminated integer in binary format')
        elsif all_chars?(rest, ['0', '1'])
          orig_text.to_i(2)
        else
          unexpected_char(rest.chars.find { |c| !['0', '1'].include?(c) })
        end
      elsif text[0] == '0' # Octal
        if all_chars?(text, OCTAL)
          orig_text.to_i(8)
        else
          unexpected_char(text.chars.find { |c| !OCTAL.include?(c) })
        end
      elsif all_chars?(text, NUMERIC)
        orig_text.to_i # Decimal
      else
        unexpected_char(text.chars.find { |c| !NUMERIC.include?(c) })
      end
    end

    def parse_head_fact(text, strings_table, lists_table, is_query)
      name = extract_fact_name(text)
      arg_list = extract_arg_list(text.slice(name.size + 1, text.size - name.size - 2))
      arg_list = arg_list.map do |arg|
        operator = ['>=', '<=', '=', '<>', '>', '<', ':'].find { |o| arg.include?(o) }
        if operator
          op_index = arg.index(operator)
          var = arg.slice(0, op_index)
          const = arg.slice(op_index + operator.size, arg.size)

          is_var1 = NAME_ALLOWED_FIRST_CHARS.any? { |c| var.start_with?(c) }
          is_var2 = NAME_ALLOWED_FIRST_CHARS.any? { |c| const.start_with?(c) }
          parser_error('Invalid clause condition - must be between a variable and a literal') if is_var1 == is_var2

          if is_var2
            tmp = var
            var = const
            const = tmp
            operator = invert_operator(operator)
          end

          const = parse_argument(const, strings_table, lists_table)

          if operator == ':' && !['integer', 'float', 'string', 'list'].include?(const)
            parser_error('Invalid argument for : operator')
          end

          Variable.new(var, operator, const.class.to_s.downcase, const)
        elsif NAME_ALLOWED_FIRST_CHARS.include?(arg[0]) && arg.slice(1..-1).chars.all? { |c| NAME_ALLOWED_REMAINING_CHARS.include?(c) }
          Variable.new(arg)
        elsif arg == '_'
          unexpected_char('_') unless is_query

          new_var_name = "_#{@parser_var_gen_idx.to_s(16)}"
          @parser_var_gen_idx += 1
          Variable.new(new_var_name)
        else
          Literal.new(parse_argument(arg, strings_table, lists_table))
        end
      end

      Fact.new(name, arg_list)
    end

    def parse_body_fact(text, strings_table, lists_table)
      name = extract_fact_name(text)

      arg_list = extract_arg_list(text.slice(name.size + 1, text.size - name.size - 2))

      added_facts = []

      arg_list = arg_list.map do |arg|

        operator = ['>=', '<=', '=', '<>', '>', '<', ':'].find { |o| arg.include?(o) }
        if operator
          unexpected_char(operator[0])
        end

        if NAME_ALLOWED_FIRST_CHARS.include?(arg[0]) && arg.slice(1..-1).chars.all? { |c| NAME_ALLOWED_REMAINING_CHARS.include?(c) }
          Variable.new(arg)
        else
          literal_value = parse_argument(arg, strings_table, lists_table) rescue nil

          if literal_value
            Literal.new(literal_value)
          else
            var_names = []

            equ = arg
            parts = splitter(arg, INLINE_OPERATORS + [' '])

            parts.each.with_index do |part, part_id|
              next if INLINE_OPERATORS.include?(part)

              chrs = part.chars
              if NAME_ALLOWED_FIRST_CHARS.include?(chrs.first) && chrs.slice(1, chrs.count).all? { |c| NAME_ALLOWED_REMAINING_CHARS.include?(c) }
                unless var_names.include?(part)
                  var_names.push(part)
                end
              elsif (NUMERIC + ['-', '.']).include?(chrs[0])
                number = parse_numeric(part)

                if number.nil?
                  parser_error('Illegal character in variable name')
                end

                parts[part_id] = number.to_s
              else
                parser_error('Illegal character in variable name')
              end
            end

            equ = parts.join('')

            var_names = var_names.sort_by { |name| -name.size }
            var_names.each.with_index do |var_name, idx2|
              equ = equ.gsub(var_name, "$#{idx2}")
            end

            new_var_name = "$#{@parser_var_gen_idx.to_s(16)}"
            @parser_var_gen_idx += 1
            new_fact = Fact.new('eval', var_names.map { |n| Variable.new(n) } + [Literal.new(equ), Variable.new(new_var_name)])
            added_facts.push(new_fact)

            Variable.new(new_var_name)
          end
        end
      end

      added_facts.push(Fact.new(name, arg_list))

      added_facts
    end

    def extract_fact_name(text)
      text_chars = text.chars
      name = ''

      text_chars.each.with_index do |c, idx|
        if idx == 0
          if NAME_ALLOWED_FIRST_CHARS.include?(c)
            name = c
            next
          else
            unexpected_char(c)
          end
        elsif NAME_ALLOWED_REMAINING_CHARS.include?(c)
          name += c
          next
        elsif c == '('
          break
        else
          unexpected_char(c)
        end
      end

      name
    end

    def extract_arg_list(text)
      parser_error('Invalid fact without arguments') if text.nil?

      chars = text.chars
      arg_list = []
      string = ''

      depth = 0
      chars.each.with_index do |c, idx|
        if depth == 0 && c == ','
          string = string.strip
          unexpected_char(c) if string == ''

          arg_list.push(string)
          string = ''
          next
        end

        string += c

        if c == '('
          depth += 1
        elsif c == ')'
          unexpected_char(chars[idx + 1] || ')') if depth == 0

          depth -= 1
        end
      end

      string = string.strip
      parser_error('Unexpected end of arguments list') if string == ''

      arg_list.push(string)

      arg_list
    end

    def extract_type_of_instruction(text)
      instruction = case text[text.size - 1]
                    when '.'
                      'clause'
                    when '!'
                      'short_query'
                    when '?'
                      'full_query'
                    when '~'
                      'retract'
                    else
                      parser_error('Unterminated instruction')
                    end

      [text.chop, instruction]
    end

    def extract_lists(text)
      lists_table = []
      chars = text.chars
      depth = 0
      string = ''
      string_mode = false
      string_delimiter = nil
      escaped = false

      chars.each.with_index do |c, idx|
        if string_mode
          if escaped
            escaped = false
          elsif c == '\\'
            escaped = true
          elsif c == string_delimiter
            string_mode = false
          end

          string += c
          next
        elsif c == "'" || c == '"'
          string_delimiter = c
          string_mode = true

          string += c
          next
        end

        if c == '\\'
          unexpected_char('\\')
        end

        if c == '['
          if depth == 0
            string = ''
          end

          string += c
          depth += 1
          next
        end

        if c == ']'
          parser_error('Bad list format') if depth == 0

          string += c
          depth -= 1

          if depth == 0
            text = text.sub(string, "$L#{lists_table.count}")

            lists_table.push(string)
          end

          next
        end

        if depth > 0
          string += c
        end
      end

      parser_error('Unterminated array') if depth > 0

      [text, lists_table]
    end

    def extract_strings(text)
      strings_table = []
      chars = text.chars

      string_delimiter = nil
      in_string = false
      escaped_string = ''
      string = ''
      orig_string = ''
      escape_mode = false

      chars.each.with_index do |c, idx|
        if in_string
          if escaped_string.size == 4
            if HEX_CHARS.include?(c.downcase)
              orig_string += c
              escaped_string += c.downcase
              begin
                string += escaped_string.slice(1..-1).to_i(16).chr(Encoding::UTF_8)
                escaped_string = ''
                escape_mode = false
              rescue
                unexpected_char(c)
              end
            else
              unexpected_char(c)
            end
          elsif escaped_string.size == 3
            if HEX_CHARS.include?(c.downcase)
              orig_string += c
              escaped_string += c.downcase
            else
              unexpected_char(c)
            end
          elsif escaped_string.size == 2
            if HEX_CHARS.include?(c.downcase)
              orig_string += c
              escaped_string += c.downcase
              if escaped_string[0] == 'x'
                begin
                  string += escaped_string.slice(1..-1).to_i(16).chr
                  escaped_string = ''
                  escape_mode = false
                rescue
                  unexpected_char(c)
                end
              end
            else
              unexpected_char(c)
            end
          elsif escaped_string.size == 1
            if HEX_CHARS.include?(c.downcase)
              orig_string += c
              escaped_string += c.downcase
            else
              unexpected_char(c)
            end
          elsif escape_mode
            if c == 'x' || c == 'u'
              escaped_string = c
            elsif STRING_ESCAPED_CHARACTERS[c]
              string += STRING_ESCAPED_CHARACTERS[c]
              escape_mode = false
            else
              unexpected_char('\\')
              escape_mode = false
            end

            orig_string += c
          elsif c == '\\'
            escape_mode = true
            orig_string += c
          elsif c == string_delimiter
            text = text.sub("#{string_delimiter}#{orig_string}#{string_delimiter}", "$S#{strings_table.count}")
            strings_table.push(string)

            in_string = false
          else
            string += c
            orig_string += c
          end
        elsif ['"', "'"].include?(c)
          string_delimiter = c
          in_string = true
          string = ''
          orig_string = ''
        elsif c == '\\'
          unexpected_char('\\')
        end
      end

      parser_error('Unterminated string') if in_string

      [text, strings_table]
    end

    def parse_relations_tree(text, start_character, end_character, separator_characters)
      chars = text.chars
      arg_list = [nil]
      string = ''

      depth = 0
      chars.each.with_index do |c, idx|
        if depth == 0 && separator_characters.include?(c)
          if arg_list[0].nil?
            arg_list[0] = c
          elsif arg_list[0] != c
            unexpected_char(c)
          end

          string = string.strip
          unexpected_char(c) if string == ''

          arg_list.push(string.start_with?(start_character) && string.end_with?(end_character) ? parse_relations_tree(string.slice(1..-2), start_character, end_character, separator_characters) : string)
          string = ''
          next
        end

        string += c

        if c == start_character
          depth += 1
        elsif c == end_character
          unexpected_char(end_character) if depth == 0

          depth -= 1
        end
      end

      string = string.strip
      parser_error('Unexpected end of clause') if string == '' || depth > 0

      arg_list[0] ||= separator_characters.first
      arg_list.push(string.start_with?(start_character) && string.end_with?(end_character) ? parse_relations_tree(string.slice(1..-2), start_character, end_character, separator_characters) : string)

      arg_list
    end

    def unexpected_char(char)
      if char == ' '
        char = 'space'
      elsif char == "\n"
        char = 'new line'
      elsif char == "\t"
        char = 'tab'
      elsif char == "\r"
        char = 'carriage return'
      end

      parser_error("Unexpected #{char} character")
    end

    def parser_error(msg)
      raise ParserError.new(msg)
    end
  end
end
