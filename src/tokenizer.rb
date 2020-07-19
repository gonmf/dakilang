# frozen_string_literal: true

module DakiLang
  module Tokenizer
    HEX_CHARS = (('0'..'9').to_a + ('a'..'f').to_a).freeze
    OCTAL = ('0'..'7').to_a.freeze
    NUMERIC = ('0'..'9').to_a.freeze
    NUMERIC_ALLOWED_CHARS = (['-', '.', 'b', 'x'] + ('0'..'9').to_a + ('a'..'f').to_a + ('A'..'F').to_a).freeze

    NAME_ALLOWED_FIRST_CHARS = (('a'..'z').to_a + ('A'..'Z').to_a).freeze
    NAME_ALLOWED_REMAINING_CHARS = (['_'] + ('a'..'z').to_a + ('A'..'Z').to_a + ('0'..'9').to_a).freeze

    WHITESPACE_CHARS = ["\r", "\t", ' '].freeze
    INLINE_OPERATORS = ['-', '+', '-', '*', '/', '%', '&', '|', '^', '~'].freeze

    def tokenizer(text)
      text_chars = text.chars

      tokens = []

      arg_list_mode = false
      string_mode = false
      escape_mode = false
      number_mode = false
      separator_mode = false
      list_mode_count = 0
      operator_mode = false

      string_delimiter = nil
      string = ''

      c = nil
      prev_c = nil
      last_non_whitespace = nil

      text_chars.each.with_index do |_, idx|
        prev_c = c
        last_non_whitespace = prev_c unless WHITESPACE_CHARS.include?(prev_c)
        c = text_chars[idx]

        if separator_mode
          if c == '-'
            tokens.push(['sep'])
            separator_mode = false
            next
          else
            parser_error(text, 'expected :-')
          end
        end

        if string_mode
          if escape_mode
            if c == '\\' || c == string_delimiter
              string += c
              escape_mode = false
              next
            else
              parser_error(text, 'string literal escape of unsupported character')
            end
          elsif c == '\\'
            escape_mode = true
            next
          end

          if c == string_delimiter
            tokens.push(['const', string])
            string = ''
            string_mode = false
          else
            string += c
          end

          next
        end

        if c == ']'
          if list_mode_count <= 0
            parser_error(text, 'unexpected ] character')
          end

          if last_non_whitespace == ','
            parser_error(text, 'unexpected dangling comma at end of list')
          end

          if string.size > 0
            if number_mode
              number = parse_numeric(string)

              if number.nil?
                parser_error(text, 'unexpected ] character')
              end

              tokens.push(['const', number])

              number_mode = false
            else
              parser_error(text, 'unexpected ] character')
            end

            string = ''
          end

          tokens.push(['const_list_end'])
          list_mode_count -= 1
          next
        end

        if arg_list_mode && tokens.include?(['sep'])
          atom = look_ahead(text_chars, idx)

          if !['\'', '"'].any? { |v| atom.include?(v) } && ['+', '-', '*', '/', '%', '&', '|', '^', '~'].any? { |v| atom.include?(v) }
            tested_part = text_chars.slice(idx, text_chars.count).join

            text_chars = (text_chars.slice(0, idx).join + (' ' * atom.size) + tested_part.slice(atom.size, tested_part.size)).split('')

            string = atom.strip
            last_non_whitespace = string.chars.last
            next
          end
        end

        if number_mode
          if NUMERIC_ALLOWED_CHARS.include?(c)
            string += c
            next
          end

          number = parse_numeric(string)

          if number.nil?
            parser_error(text, "illegal numeric format at #{string}")
          end

          tokens.push(['const', number])

          string = ''
          number_mode = false
        end

        if operator_mode
          if ['<', '>', '='].include?(c)
            string += c
            next
          else
            if tokens.include?(['sep'])
              parser_error(text, 'clause conditions at clause tail instead of head')
            end

            tokens.push(['oper', string])
            string = ''
            operator_mode = false
          end
        elsif ['<', '>', ':'].include?(c) && arg_list_mode
          if string.size > 0
            tokens.push(['var', string.strip])
            string = ''
          end

          operator_mode = true
          string = c
          next
        end

        if c == '-' || (c >= '0' && c <= '9') && string.size == 0
          number_mode = true
          string = c
          next
        end

        if c == '['
          if string.size == 0 && arg_list_mode
            tokens.push(['const_list_start'])
            list_mode_count += 1
            next
          end

          parser_error(text, 'unexpected [ character')
        end

        if c == '#' # Comment
          break
        end

        if WHITESPACE_CHARS.include?(c) # Whitespace is ignored outside of string literals
          if string.size > 0
            if arg_list_mode
              string += c
              next
            else
              tokens.push(['name', string])
              string = ''
            end
          end

          next
        end

        if c == '.'
          if tokens.any? { |a| a[0].end_with?('_finish') }
            parser_error(text, 'unexpected . character')
          end

          tokens.push(['clause_finish'])
          next
        end

        if c == '?'
          if tokens.any? { |a| a[0].end_with?('_finish') }
            parser_error(text, 'unexpected ? character')
          end
          if tokens.include?(['sep'])
            parser_error(text, 'unexpected ? character for rule with tail')
          end

          tokens.push(['full_query_finish'])
          next
        end

        if c == '!'
          if tokens.any? { |a| a[0].end_with?('_finish') }
            parser_error(text, 'unexpected ! character')
          end
          if tokens.include?(['sep'])
            parser_error(text, 'unexpected ! character for rule with tail')
          end

          tokens.push(['short_query_finish'])
          next
        end

        if c == '"' || c == "'"
          if string.size > 0
            parser_error(text, 'unexpected end of string')
          end

          string_delimiter = c
          string_mode = true
          next
        end

        if c == '('
          if string.empty?
            parser_error(text, 'unexpected start of argument list')
          end

          arg_list_mode = true
          tokens.push(['name', string])
          string = ''
          tokens.push(['args_start'])
          next
        end

        if c == '~'
          if tokens.any? { |a| a[0].end_with?('_finish') }
            parser_error(text, 'unexpected ~ character')
          end

          tokens.push(['retract_finish'])
          next
        end

        if c == ')'
          if !arg_list_mode
            parser_error(text, 'unexpected end of empty argument list')
          end

          if last_non_whitespace == ','
            parser_error(text, 'unexpected dangling comma at end of argument list')
          end

          arg_list_mode = false
          if string.size > 0
            tokens.push(['var', string.strip])
            string = ''
          elsif tokens.last == ['args_start']
            parser_error(text, 'unexpected end of empty argument list')
          end

          tokens.push(['args_end'])
          next
        end

        if c == ','
          if arg_list_mode
            if string.size > 0
              tokens.push(['var', string.strip])
              string = ''
            elsif tokens.last == ['args_start']
              parser_error(text, 'invalid , at argument list start')
            end
          else
            if !tokens.include?(['sep'])
              parser_error(text, 'invalid , character before clause head/tail separator')
            end

            if tokens.include?(['or'])
              parser_error(text, 'mixing of , and ; logical operators')
            end

            if string.size > 0
              parser_error(text, 'unexpected , character')
            end

            tokens.push(['and'])
            next
          end

          next
        end

        if c == ';'
          if !tokens.include?(['sep'])
            parser_error(text, 'invalid ; character before clause head/tail separator')
          end

          if tokens.include?(['and'])
            parser_error(text, 'mixing of ; and & logical operators')
          end

          if string.size > 0
            parser_error(text, 'unexpected ; character')
          end

          tokens.push(['or'])
          next
        end

        if c == ':' && !separator_mode
          if arg_list_mode
            parser_error(text, 'duplicate :- separator')
          end

          if string.size > 0
            tokens.push(['name', string])
            string = ''
          end

          separator_mode = true
          next
        end

        string += c
      end

      # Some global validations
      if string.size > 0
        parser_error(text, 'unterminated text')
      end

      if tokens.any? && !['clause_finish', 'short_query_finish', 'full_query_finish', 'retract_finish'].include?(tokens.last&.first)
        parser_error(text, 'unterminated clause')
      end

      # Reorder and fix clause conditions
      tokens.each.with_index do |s, idx|
        next if s.nil? || s[0] != 'oper'

        if ['>=', '<=', '=', '>', '<', '<>', ':'].include?(s[1])
          var1 = tokens[idx - 1]
          var2 = tokens[idx + 1]

          if !var1 || !var2 || ((var1[0] == 'var') == (var2[0] == 'var'))
            parser_error(text, 'invalid clause condition format')
          end

          var = var1[0] == 'var' ? var1 : var2
          const = var1[0] == 'var' ? var2 : var1

          if var2[0] == 'var'
            s[1] = invert_operator(s[1])
          end

          if s[1] == ':' && !['integer', 'float', 'string', 'list'].include?(const[1])
            parser_error(text, 'invalid argument for : operator')
          end

          tokens[idx - 1] = ['var', Variable.new(var[1], s[1], const[1].class.to_s.downcase, const[1])]
          tokens[idx] = nil
          tokens[idx + 1] = nil
        else
          parser_error(text, 'unknown clause condition operator')
        end
      end

      # Type conversion
      tokens.each.with_index do |token, idx|
        if token && token[0] == 'var' && (token[1].is_a?(String) || token[1].is_a?(Array))
          tokens[idx] = ['var', Variable.new(token[1])]
        end
      end

      # Further validations
      tokens = tokens.compact
      tokens.each.with_index do |s, idx|
        if s[0] == 'and' && tokens[idx + 1] == ['and']
          parser_error(text, 'unexpected , character')
        elsif s[0] == 'name' && (tokens[idx + 1].nil? || tokens[idx + 1][0] != 'args_start')
          parser_error(text, 'clause without arguments list')
        elsif s[0] == 'args_start' && tokens[idx + 1] && tokens[idx + 1][0] == 'args_end'
          parser_error(text, 'empty arguments list')
        elsif s[0] == 'name'
          chrs = s[1].chars

          if !NAME_ALLOWED_FIRST_CHARS.include?(chrs.first) || chrs.slice(1, chrs.count).any? { |c| !NAME_ALLOWED_REMAINING_CHARS.include?(c) }
            parser_error(text, 'illegal character in clause name')
          end
        elsif s[0] == 'const'
          s[1] = Literal.new(s[1])
        else
          next
        end
      end

      # Separate clause into multiple clauses for logical OR tail dependencies
      sep_index = tokens.index(['sep'])
      if sep_index.nil? || tokens.index(['and']).to_i > sep_index
        # Logical AND or no tail
        token_set = [tokens]
      else
        # Logical OR
        tokens_head = tokens.slice(0, sep_index + 1)
        tokens_body = tokens.slice(sep_index + 1, tokens.count - 2 - sep_index)

        parts = []
        part = []
        tokens_body.each do |token|
          if token == ['or']
            if part.empty?
              parser_error(text, 'unexpected ; character')
            end

            part.push(tokens.last)
            parts.push(part)
            part = []
          else
            part.push(token)
          end
        end

        if part.empty?
          parser_error(text, 'unexpected ; character')
        end

        part.push(tokens.last)
        parts.push(part)

        token_set = parts.map { |p| tokens_head + p }
      end

      token_set.each.with_index do |tokens, token_set_idx|
        # Validate variable names and inline operations
        vari = 0
        new_tokens = tokens.dup
        sep_token_idx = tokens.index { |t| t == ['sep'] }

        tokens.each.with_index do |s, idx|
          next unless s[0] == 'var'

          var_names = []
          chrs = s[1].name.chars

          if NAME_ALLOWED_FIRST_CHARS.include?(chrs.first) && chrs.slice(1, chrs.count).all? { |c| NAME_ALLOWED_REMAINING_CHARS.include?(c) }
            next
          end

          # Variable inline operation
          equ = s[1].name
          parts = splitter(s[1].name, INLINE_OPERATORS + [' ', '(', ')'])

          parts.each.with_index do |part, part_id|
            next if (INLINE_OPERATORS + ['(', ')']).include?(part)

            chrs = part.chars
            if NAME_ALLOWED_FIRST_CHARS.include?(chrs.first) && chrs.slice(1, chrs.count).all? { |c| NAME_ALLOWED_REMAINING_CHARS.include?(c) }
              unless var_names.include?(part)
                var_names.push(part)
              end
            elsif (NUMERIC + ['-', '.']).include?(chrs[0])
              number = parse_numeric(part)

              if number.nil?
                parser_error(text, 'illegal character in variable name')
              end

              parts[part_id] = number.to_s
            else
              parser_error(text, 'illegal character in variable name')
            end
          end

          equ = parts.join('')

          vari += 1
          new_var_name = "$#{vari.to_s(16)}"
          var_names = var_names.sort_by { |name| -name.size }
          var_names.each.with_index do |var_name, idx2|
            equ = equ.gsub(var_name, "$#{idx2}")
          end

          equ = equ.tr(' ', '')

          new_clause = [
            ['name', 'eval'],
            ['args_start']
          ] + var_names.map { |var_name| ['var', Variable.new(var_name)] } + [
            ['const', Literal.new(equ)],
            ['var', Variable.new(new_var_name)],
            ['args_end'],
            ['and']
          ]

          s[1] = Variable.new(new_var_name)

          new_tokens = new_tokens.slice(0, sep_token_idx + 1) + new_clause + new_tokens.slice(sep_token_idx + 1, new_tokens.count)
        end

        token_set[token_set_idx] = new_tokens
        tokens = token_set[token_set_idx]

        # Parse array constants
        tokens.each.with_index do |token, idx|
          if token && token[0] == 'const_list_start'
            val = recursive_build_array(tokens, idx)

            tokens[idx] = ['const', Literal.new(val)]
          end
        end

        token_set[token_set_idx] = new_tokens.compact
      end

      token_set
    end

    private

    def convert_tokens_format(tokens)
      ret = []

      ret.push(tokens.last[0].sub('_finish', ''))

      last_idx = 0

      loop do
        fact, last_idx = convert_fact_format(tokens, last_idx)
        break unless last_idx

        ret.push(fact)
      end

      ret
    end

    def convert_fact_format(tokens, idx)
      name = nil
      arg_list = []

      while tokens[idx] do
        if tokens[idx][0] == 'args_start'
          name = tokens[idx - 1][1]
        elsif name
          break if tokens[idx][0] == 'args_end'

          arg_list.push(tokens[idx][1])
        end

        idx += 1
      end

      name && arg_list.any? ? [[name, arg_list], idx] : nil
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

    def parse_numeric(str)
      if str.end_with?('.')
        return nil
      end

      if str.start_with?('.')
        str = "0#{str}"
      end

      orig_str = str

      str = str.slice(1, str.size) if str[0] == '-'

      return nil if str.size == 0

      if str.include?('.') # Floating point
        integer, decimal, err = str.split('.')
        decimal ||= '0'

        if all_chars?(integer, NUMERIC) && all_chars?(decimal, NUMERIC) && !err
          orig_str.to_f
        end
      elsif str.start_with?('0x') # Hexadecimal
        a = str.slice(2, str.size)

        if a.size > 0 && all_chars?(a.downcase, HEX_CHARS)
          orig_str.to_i(16)
        end
      elsif str.start_with?('0b') # Binary
        if all_chars?(str.slice(2, str.size), ['0', '1'])
          orig_str.to_i(2)
        end
      elsif str[0] == '0' # Octal
        if all_chars?(str, OCTAL)
          orig_str.to_i(8)
        end
      elsif all_chars?(str, NUMERIC)
        orig_str.to_i # Decimal
      end
    end

    def look_ahead(text_chars, start_idx)
      string = ''
      depth_counter = 0

      text_chars.slice(start_idx, text_chars.count).each do |c|
        if c == ','
          break
        elsif c == '('
          depth_counter += 1
        elsif c == ')'
          depth_counter -= 1

          break if depth_counter < 0
        end

        string += c
      end

      string
    end

    def splitter(str, arrs)
      parts = [" #{str} "]

      arrs.each do |c|
        parts = parts.map { |s| s == c ? s : s.split(c).map { |v| [c, " #{v} "] }.flatten.slice(1..-1) }.flatten.compact
      end

      parts.map { |s| s.strip }.select { |s| s.size > 0 }
    end

    def recursive_build_array(tokens, idx)
      ret = []

      ((idx + 1)..tokens.count).each do |idx2|
        type, value = tokens[idx2]

        if type == 'const_list_start'
          tokens[idx2] = nil
          ret.push(recursive_build_array(tokens, idx2))
        elsif type == 'const_list_end'
          tokens[idx2] = nil
          break
        elsif type == 'const'
          ret.push(tokens[idx2][1].value)
          tokens[idx2] = nil
        end
      end

      ret
    end

    def parser_error(msg, detail = nil)
      raise ParserError.new(["Syntax error at #{msg}", detail].compact.join(': '))
    end
  end
end
