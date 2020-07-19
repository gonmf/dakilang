# frozen_string_literal: true

module DakiLang
  module Parser
    # TODO: support subset of ruby and C escaped characters and unicode
    STRING_ESCAPED_CHARACTERS = {
      '\'' => '\'',
      '\"' => '"',
      'n' => "\n",
      'r' => "\r",
      't' => "\t",
      'b' => "\b",
      'f' => "\f",
      'v' => "\v",
      '0' => "\0",
      '\\' => '\\'
    }.freeze

    def parse(text)
      text.strip!

      text, strings_table = extract_strings(text)

      text = text.split('#').first.strip
      return nil if text == ''

      text, instruction_type = extract_type_of_instruction(text)

      text.tr!(" \t", '')

      text, lists_table = extract_lists(text)

      facts, logical_oper = text.include?(':-') ? parse_facts(text) : [[text], 'and']

      head, *body = facts

      head = parse_head_fact(head)
      body = body.map { |fact| parse_body_fact(fact) }

      if logical_oper == 'and'
        [instruction_type, [[head] + body]]
      else # or
        [instruction_type, body.map { |body_fact| [head, body_fact] }]
      end
    end

    def parser(text)
      # TODO: to continue
      new_token_set = parse(text.dup) rescue nil # TODO: remove dup

      # TODO: to replace
      token_set = tokenizer(text)

      token_set = if token_set.flatten.any?
                    token_set = token_set.map { |tokens| parse_tokens(tokens) }

                    [token_set.first.first, token_set.map { |tokens| tokens.slice(1, tokens.count) }]
                  else
                    nil
                  end

      binding.pry rescue nil

      # TODO: simplify this
      token_set
    end

    def clause_to_s(obj)
      if obj.is_a?(Array)
        "(#{obj.map { |o| clause_to_s(o) }.join(' ')})"
      elsif obj.is_a?(Fact)
        "(#{obj.name} #{clause_to_s(obj.arg_list)})"
      elsif obj.is_a?(Variable)
        "(var #{obj.to_s})"
      elsif obj.is_a?(Literal)
        "(#{obj.type} #{obj.to_s})"
      else
        obj.to_s
      end
    end

    private

    def parse_head_fact(text)
      name = extract_fact_name(text)

      args_list = extract_args_list(text.slice(name.size + 1, text.size - name.size - 2))

      # TODO: clause conditions and with inverse order

      args_list = args_list.map { |arg| Tokenizer::NAME_ALLOWED_FIRST_CHARS.include?(arg[0]) ? Variable.new(arg) : Literal.new(arg) }

      Fact.new(name, args_list)
    end

    def parse_body_fact(text)
      name = extract_fact_name(text)

      args_list = extract_args_list(text.slice(name.size + 1, text.size - name.size - 2))

      # TODO: inline operations

      args_list = args_list.map { |arg| Tokenizer::NAME_ALLOWED_FIRST_CHARS.include?(arg[0]) ? Variable.new(arg) : Literal.new(arg) }

      Fact.new(name, args_list)
    end

    def extract_fact_name(text)
      text_chars = text.chars
      name = ''

      text_chars.each.with_index do |c, idx|
        if idx == 0
          if Tokenizer::NAME_ALLOWED_FIRST_CHARS.include?(c)
            name = c
            next
          else
            raise "Unexpected #{c} character"
          end
        elsif Tokenizer::NAME_ALLOWED_REMAINING_CHARS.include?(c)
          name += c
          next
        elsif c == '('
          break
        else
          raise "Unexpected #{c} character"
        end
      end

      name
    end

    def extract_args_list(text)
      chars = text.chars
      args_list = []
      string = ''

      depth = 0
      chars.each.with_index do |c, idx|
        if depth == 0 && c == ','
          string.strip!
          raise "Unexpected #{c} character" if string == ''

          args_list.push(string)
          string = ''
          next
        end

        string += c

        if c == '('
          depth += 1
        elsif c == ')'
          raise 'Unexpected ) character' if depth == 0

          depth -= 1
        end
      end

      string.strip!
      raise 'Unexpected end of arguments list' if string == ''

      args_list.push(string)

      args_list
    end

    def parse_facts(text)
      text.sub!(':-', ',')

      chars = text.chars
      facts = []
      string = ''
      logical_oper = nil

      depth = 0
      chars.each.with_index do |c, idx|
        if depth == 0 && logical_oper.nil? && [',', ';'].include?(c)
          logical_oper = c

          string.strip!
          raise "Unexpected #{c} character" if string == ''

          facts.push(string)
          string = ''
          next
        end

        if depth == 0 && [',', ';'].include?(c)
          raise "Unexpected #{c} character" if c != logical_oper

          string.strip!
          raise "Unexpected #{c} character" if string == ''

          facts.push(string)
          string = ''
          next
        end

        string += c

        if c == '('
          depth += 1
        elsif c == ')'
          raise 'Unexpected ) character' if depth == 0

          depth -= 1
        end
      end

      raise 'Unexpected end of clause' if string == ''
      facts.push(string)

      [facts, logical_oper == ';' ? 'or' : 'and']
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
                      raise 'Unterminated instruction'
                    end

      [text.chop, instruction]
    end

    def extract_lists(text)
      lists_table = []
      chars = text.chars
      depth = 0
      string = ''

      chars.each.with_index do |c, idx|
        if c == '['
          if depth == 0
            string = ''
          end

          string += c
          depth += 1
          next
        end

        if c == ']'
          raise 'Bad list format' if depth == 0

          string += c
          depth -= 1

          if depth == 0
            text.sub!(string, "$L#{lists_table.count}$")

            lists_table.push(string)
          end

          next
        end

        if depth > 0
          string += c
        end
      end

      raise 'Unterminated array' if depth > 0

      [text, lists_table]
    end

    def extract_strings(text)
      strings_table = []
      chars = text.chars

      string_delimiter = nil
      in_string = false
      string = ''
      orig_string = ''
      escape_mode = false

      chars.each.with_index do |c, idx|
        if in_string
          if escape_mode
            if STRING_ESCAPED_CHARACTERS.include?(c) || string_delimiter == c
              string += STRING_ESCAPED_CHARACTERS[c]
              orig_string += c
              next
            else
              string += '\\'
            end

            escape_mode = false
          elsif c == '\\'
            escape_mode = true
            orig_string += c
            next
          end

          if c == string_delimiter
            text.sub!("#{string_delimiter}#{orig_string}#{string_delimiter}", "$S#{strings_table.count}$")
            strings_table.push(string)

            in_string = false
            next
          end

          string += c
          orig_string += c
        elsif ['"', '\''].include?(c)
          string_delimiter = c
          in_string = true
          string = ''
          orig_string = ''
        end
      end

      raise 'Unterminated string' if in_string

      [text, strings_table]
    end

    def parse_tokens(tokens)
      ret = []

      ret.push(tokens.last[0].sub('_finish', ''))

      last_idx = 0

      loop do
        fact, last_idx = parse_fact_tokens(tokens, last_idx)
        break unless last_idx

        ret.push(fact)
      end

      facts = []

      ret.slice(1, ret.count).each do |part|
        facts.push(Fact.new(part[0], part[1]))
      end

      [ret.first] + facts
    end

    def parse_fact_tokens(tokens, idx)
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
  end
end
