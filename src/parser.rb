# frozen_string_literal: true

module DakiLang
  module Parser
    def parser(text)
      token_set = tokenizer(text)

      if token_set.flatten.any?
        token_set.map { |tokens| parse_tokens(tokens) }
      else
        nil
      end
    end

    def clause_to_s(obj)
      if obj.is_a?(Array)
        "(#{obj.map { |o| clause_to_s(o) }.join(' ')})"
      elsif obj.is_a?(Variable)
        "(var #{obj.to_s})"
      elsif obj.is_a?(Literal)
        "(#{obj.type} #{obj.to_s})"
      else
        obj.to_s
      end
    end

    private

    def parse_tokens(tokens)
      ret = []

      ret.push(tokens.last[0].sub('_finish', ''))

      last_idx = 0

      loop do
        fact, last_idx = parse_fact_tokens(tokens, last_idx)
        break unless last_idx

        ret.push(fact)
      end

      ret
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
