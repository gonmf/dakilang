# frozen_string_literal: true

begin
  # Just for development
  require 'rb-readline'
  require 'pry'
rescue Exception
end

require 'set'

Dir['**/*.rb'].each do |filename|
  filename.sub!('src/', '')
  next if ['parser_test.rb', 'dakilang.rb', 'interpreter.rb'].include?(filename)

  require_relative filename
end

module DakiLang
  class Interpreter
    include OperatorClauses

    VERSION = '0.29'

    MAX_FUNC_ARITY = 20

    OPERATOR_CLAUSES = [
      # Arithmetic
      ['add',        3, true], # Variable arity
      ['sub',        3],
      ['mul',        3, true], # Variable arity
      ['div',        3],
      ['mod',        3],
      ['pow',        3],
      ['sqrt',       2],
      ['log',        3],
      ['round',      3],
      ['trunc',      2],
      ['floor',      2],
      ['ceil',       2],
      ['abs',        2],
      ['eval',       3, true], # Variable arity
      # Equality and comparison
      ['eql',        3],
      ['neq',        3],
      ['max',        2, true], # Variable arity
      ['min',        2, true], # Variable arity
      ['gt',         3],
      ['lt',         3],
      ['gte',        3],
      ['lte',        3],
      # Casts
      ['as_string',  2],
      ['as_string',  3],
      ['as_integer', 2],
      ['as_integer', 3],
      ['as_float',   2],
      # Strings
      ['ord',        2],
      ['char',       2],
      ['split',      3],
      # Strings and Lists
      ['len',        2],
      ['concat',     3, true], # Variable arity
      ['slice',      4],
      ['index',      4],
      # Lists
      ['head',       2],
      ['tail',       2],
      ['push',       3],
      ['append',     3],
      ['put',        4],
      ['unique',     2],
      ['reverse',    2],
      ['sort',       2],
      ['sum',        2],
      ['join',       3],
      ['init',       3],
      # Other
      ['set',        2],
      ['rand',       1],
      ['type',       2],
      ['print',      2],
      ['print',      3],
      ['time',       1],
      ['time',       2]
    ].freeze

    HEX_CHARS = (('0'..'9').to_a + ('a'..'f').to_a).freeze
    OCTAL = ('0'..'7').to_a.freeze
    NUMERIC = ('0'..'9').to_a.freeze
    NUMERIC_ALLOWED_CHARS = (['-', '.', 'b', 'x'] + ('0'..'9').to_a + ('a'..'f').to_a + ('A'..'F').to_a).freeze

    NAME_ALLOWED_FIRST_CHARS = (('a'..'z').to_a + ('A'..'Z').to_a).freeze
    NAME_ALLOWED_REMAINING_CHARS = (['_'] + ('a'..'z').to_a + ('A'..'Z').to_a + ('0'..'9').to_a).freeze

    WHITESPACE_CHARS = ["\r", "\t", ' '].freeze
    INLINE_OPERATORS = ['-', '+', '-', '*', '/', '%', '&', '|', '^', '~'].freeze

    COMPATIBLE_CONDITIONS = {
      '<' => {
        'string' => {
          'string' => true, 'list' => false, 'integer' => false, 'float' => false
        },
        'list' => {
          'string' => false, 'list' => true, 'integer' => false, 'float' => false
        },
        'integer' => {
          'string' => false, 'list' => false, 'integer' => true, 'float' => true
        },
        'float' => {
          'string' => false, 'list' => false, 'integer' => true, 'float' => true
        }
      },
      '<=' => {
        'string' => {
          'string' => true, 'list' => false, 'integer' => false, 'float' => false
        },
        'list' => {
          'string' => false, 'list' => true, 'integer' => false, 'float' => false
        },
        'integer' => {
          'string' => false, 'list' => false, 'integer' => true, 'float' => true
        },
        'float' => {
          'string' => false, 'list' => false, 'integer' => true, 'float' => true
        }
      },
      '>' => {
        'string' => {
          'string' => true, 'list' => false, 'integer' => false, 'float' => false
        },
        'list' => {
          'string' => false, 'list' => true, 'integer' => false, 'float' => false
        },
        'integer' => {
          'string' => false, 'list' => false, 'integer' => true, 'float' => true
        },
        'float' => {
          'string' => false, 'list' => false, 'integer' => true, 'float' => true
        }
      },
      '>=' => {
        'string' => {
          'string' => true, 'list' => false, 'integer' => false, 'float' => false
        },
        'list' => {
          'string' => false, 'list' => true, 'integer' => false, 'float' => false
        },
        'integer' => {
          'string' => false, 'list' => false, 'integer' => true, 'float' => true
        },
        'float' => {
          'string' => false, 'list' => false, 'integer' => true, 'float' => true
        }
      },
      '!=' => {
        'string' => {
          'string' => true, 'list' => false, 'integer' => false, 'float' => false
        },
        'list' => {
          'string' => false, 'list' => true, 'integer' => false, 'float' => false
        },
        'integer' => {
          'string' => false, 'list' => false, 'integer' => true, 'float' => true
        },
        'float' => {
          'string' => false, 'list' => false, 'integer' => true, 'float' => true
        }
      }
    }.freeze

    attr_accessor :search_time_limit, :debug

    def initialize
      @search_time_limit = 3.0 # Seconds

      @table = {}
      @memo_tree = {}
      @to_memo = {}

      init_oper_clauses

      select_table('0', false)
    end

    def enter_interactive_mode
      @interactive = true

      loop do
        print '> '
        input = STDIN.gets.chomp

        run_commands([input], [])
      end
    end

    def consult_file(filename, consult_chain = [])
      if !filename || filename.size == 0
        puts 'File name is missing or invalid'
        puts
      elsif consult_chain.include?(filename)
        puts 'Circular file consult invocation detected'
        puts
      else
        contents = file_read(filename)

        if contents
          run_commands(contents, consult_chain + [filename])
        else
          puts 'File not found or cannot be read'
          puts
        end
      end
    end

    def print_version
      puts "dakilang interpreter v#{VERSION}"
      puts
    end

    def print_help
      puts 'USE'
      puts '    ./dakilang [OPTIONS]'
      puts
      puts 'OPTIONS'
      puts '-h, --help                 # Print out the program manual and exit'
      puts '-v, --version              # Print out the program name and version, and exit'
      puts '-c file, --consult file    # Read file with path "file" and interpret each line'
      puts '-i, --interactive          # Activate interactive mode after finishing consulting all files'
      puts '-d, --debug                # Activate debug mode, which shows extra output and disables some performance improvements'
      puts '-t seconds, --time seconds # Changes the default query timeout time; "seconds" is a floating point value in seconds'
      puts
    end

    def debug_tokenizer(line)
      @test_mode = true

      token_set = tokenizer(line)

      token_set.map do |tokens|
        tokens.map { |token| token[1] ? "#{token[0]}(#{token[1].to_s})" : token[0] }.join(' | ')
      end.join(' OR ')
    rescue ParserError => e
      e.to_s
    end

    private

    def run_commands(lines, consult_chain)
      lines.each do |line|
        puts "> #{line}".strip unless @interactive

        down_line = line.split('#').first.to_s.strip.downcase

        if down_line == 'quit'
          if @interactive
            exit(0)
          else
            return
          end
        end

        if down_line == 'help'
          print_help
          next
        end

        if down_line == 'select_table' || down_line.start_with?('select_table ')
          select_table(line.split(' ')[1], true)
          next
        end
        if down_line.start_with?('add_memo ')
          add_memo(line.split(' ')[1])
          next
        end
        if down_line.start_with?('rem_memo ')
          rem_memo(line.split(' ')[1])
          next
        end
        if down_line == 'list_memo'
          list_memo
          next
        end
        if down_line == 'clear_memo'
          clear_memo
          next
        end
        if down_line == 'listing'
          table_listing
          next
        end
        if down_line.start_with?('consult ')
          consult_file(line.split(' ')[1], consult_chain)
          next
        end
        if down_line.start_with?('retract ')
          retract_rule_by_index(line.split(' ')[1])
          next
        end

        token_set = tokenizer(line)
        next if token_set.flatten.empty?

        token_set.each do |tokens|
          puts tokens.map { |a| a.join(':') }.join(', ') if @debug

          case tokens.last.first
          when 'clause_finish'
            add_rule(tokens, token_set.count == 1)
          when 'short_query_finish'
            execute_query(token_set.first, true)
          when 'full_query_finish'
            execute_query(token_set.first, false)
          when 'retract_finish'
            retract_rule_by_full_match(token_set.first)
            puts
          end
        end
      end
    end

    def retract_rule_by_index(idx_str)
      idx = idx_str.to_i
      if idx.to_s != idx_str || idx < 0 || idx >= @table[@table_name].count
        puts 'Invalid clause index'
        puts
        return
      end

      @table[@table_name][idx] = nil
      @table[@table_name] = @table[@table_name].compact

      puts 'Clause removed'
      puts
    end

    def retract_rule_by_full_match(tokens)
      head, last_idx = build_fact(tokens)

      if head && @operator_clauses.include?(head.arity_name)
        puts 'Built-in operator clause cannot be removed'
        return
      end

      arr1 = [head].compact
      while last_idx != -1
        body, last_idx = build_fact(tokens, last_idx)
        arr1.push(body) if body
      end

      @table[@table_name].each.with_index do |rule, idx|
        arr2 = [rule[0]] + rule[1]

        next if arr1.count != arr2.count

        are_equal = true
        arr1.each.with_index do |head1, i|
          head2 = arr2[i]

          unless head1.eql?(head2)
            are_equal = false
            break
          end
        end

        if are_equal
          @table[@table_name][idx] = nil
          @table[@table_name] = @table[@table_name].compact
          puts 'Clause removed'
          return
        end
      end

      puts 'Clause not found'
    end

    def execute_query(tokens, stop_early)
      head, = build_fact(tokens)

      solutions = search(head, stop_early)

      if solutions.nil?
        puts 'Search timeout'
      elsif solutions.any?
        printed_any = false

        solutions.uniq.each do |solution|
          printed = Set.new

          head.arg_list.each.with_index do |arg, idx|
            if !arg.const?
              printed_any = true
              value = solution.arg_list[idx]
              text = "#{arg.name} = #{value}"

              if !printed.include?(text)
                printed.add(text)
                puts text
              end
            end
          end

          puts if printed_any
        end

        unless printed_any
          puts 'Yes'
          puts
        end
      else
        puts 'No'
        puts
      end
    end

    def add_rule(tokens, warn_if_exists)
      head, last_idx = build_fact(tokens)

      if head && @operator_clauses.include?(head.arity_name)
        puts 'Built-in operator clause already exists'
        puts
        return
      end

      bodies = []
      while last_idx != -1
        body, last_idx = build_fact(tokens, last_idx)
        bodies.push(body) if body
      end

      table_add_clause(head, bodies, warn_if_exists)
    end

    def build_fact(tokens, start_index = 0)
      name = nil
      arguments = []
      end_index = -1

      start_found = false
      tokens.each.with_index do |token, idx|
        next if idx < start_index

        if start_found
          if token[0] == 'args_end'
            end_index = idx
            break
          end

          arguments.push(token[1])
        else
          if token[0] == 'args_start'
            name = tokens[idx - 1]

            if name[0] != 'name'
              raise 'Unexpected error 1'
            end

            start_found = true
          end

          next
        end
      end

      if name && arguments.any?
        [Fact.new(name[1], arguments), end_index]
      else
        [nil, -1]
      end
    end

    def add_memo(name)
      name = name.to_s

      n, arity, more = name.split('/')

      if name.size == 0 || !arity || more || arity != arity.to_i.to_s || arity.to_i < 1
        puts 'Clause name is invalid'
      elsif @to_memo[@table_name].include?(name)
        puts 'Clause is already being memoized'
      elsif @operator_clauses.include?(name)
        puts 'Cannot memoize built-in operator clause'
      else
        @to_memo[@table_name].add(name)
        puts 'OK'
      end

      puts
    end

    def rem_memo(name)
      if !name && name.size == 0
        puts 'Clause name is invalid'
      elsif @to_memo[@table_name].include?(name)
        @to_memo[@table_name].delete(name)
        @memo_tree[@table_name][name] = nil
        @memo_tree[@table_name] = @memo_tree[@table_name].compact
        puts 'OK'
      else
        puts 'Clause was not being memoized'
      end

      puts
    end

    def list_memo
      @to_memo[@table_name].sort.each do |name|
        puts name
      end

      puts
    end

    def clear_memo
      @memo_tree[@table_name] = {}
    end

    def invert_operator(str)
      if str[0] == '<'
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

    def all_chars?(str, chars)
      str.chars.all? { |c| chars.include?(c) }
    end

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
            parser_error("Syntax error at #{text}", 'expected :-')
          end
        end

        if c == ']'
          if list_mode_count <= 0
            parser_error("Syntax error at #{text}", 'unexpected ] character')
          end

          if last_non_whitespace == ','
            parser_error("Syntax error at #{text}", 'unexpected dangling comma at end of list')
          end

          if string.size > 0
            if number_mode
              number = parse_numeric(string)

              if number.nil?
                parser_error("Syntax error at #{text}", 'unexpected ] character')
              end

              tokens.push(['const', number])

              number_mode = false
            else
              parser_error("Syntax error at #{text}", 'unexpected ] character')
            end

            string = ''
          end

          tokens.push(['const_list_end'])
          list_mode_count -= 1
          next
        end

        if string_mode
          if escape_mode
            if c == '\\' || c == string_delimiter
              string += c
              escape_mode = false
              next
            else
              parser_error("Syntax error at #{text}", 'string literal escape of unsupported character')
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
            parser_error("Syntax error at #{text}", "illegal numeric format at #{string}")
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
              parser_error("Syntax error at #{text}", 'clause conditions at clause tail instead of head')
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

          parser_error("Syntax error at #{text}", 'unexpected [ character')
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
            parser_error("Syntax error at #{text}", 'unexpected . character')
          end

          tokens.push(['clause_finish'])
          next
        end

        if c == '?'
          if tokens.any? { |a| a[0].end_with?('_finish') }
            parser_error("Syntax error at #{text}", 'unexpected ? character')
          end
          if tokens.include?(['sep'])
            parser_error("Syntax error at #{text}", 'unexpected ? character for rule with tail')
          end

          tokens.push(['full_query_finish'])
          next
        end

        if c == '!'
          if tokens.any? { |a| a[0].end_with?('_finish') }
            parser_error("Syntax error at #{text}", 'unexpected ! character')
          end
          if tokens.include?(['sep'])
            parser_error("Syntax error at #{text}", 'unexpected ! character for rule with tail')
          end

          tokens.push(['short_query_finish'])
          next
        end

        if c == '"' || c == "'"
          if string.size > 0
            parser_error("Syntax error at #{text}", 'unexpected end of string')
          end

          string_delimiter = c
          string_mode = true
          next
        end

        if c == '('
          if string.empty?
            parser_error("Syntax error at #{text}", 'unexpected start of argument list')
          end

          arg_list_mode = true
          tokens.push(['name', string])
          string = ''
          tokens.push(['args_start'])
          next
        end

        if c == '~'
          if tokens.any? { |a| a[0].end_with?('_finish') }
            parser_error("Syntax error at #{text}", 'unexpected ~ character')
          end

          tokens.push(['retract_finish'])
          next
        end

        if c == ')'
          if !arg_list_mode
            parser_error("Syntax error at #{text}", 'unexpected end of empty argument list')
          end

          if last_non_whitespace == ','
            parser_error("Syntax error at #{text}", 'unexpected dangling comma at end of argument list')
          end

          arg_list_mode = false
          if string.size > 0
            tokens.push(['var', string.strip])
            string = ''
          elsif tokens.last == ['args_start']
            parser_error("Syntax error at #{text}", 'unexpected end of empty argument list')
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
              parser_error("Syntax error at #{text}", 'invalid , at argument list start')
            end
          else
            if !tokens.include?(['sep'])
              parser_error("Syntax error at #{text}", 'invalid , character before clause head/tail separator')
            end

            if tokens.include?(['or'])
              parser_error("Syntax error at #{text}", 'mixing of , and ; logical operators')
            end

            if string.size > 0
              parser_error("Syntax error at #{text}", 'unexpected , character')
            end

            tokens.push(['and'])
            next
          end

          next
        end

        if c == ';'
          if !tokens.include?(['sep'])
            parser_error("Syntax error at #{text}", 'invalid ; character before clause head/tail separator')
          end

          if tokens.include?(['and'])
            parser_error("Syntax error at #{text}", 'mixing of ; and & logical operators')
          end

          if string.size > 0
            parser_error("Syntax error at #{text}", 'unexpected ; character')
          end

          tokens.push(['or'])
          next
        end

        if c == ':' && !separator_mode
          if arg_list_mode
            parser_error("Syntax error at #{text}", 'duplicate :- separator')
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
        parser_error("Syntax error at #{text}", 'unterminated text')
      end

      if tokens.any? && !['clause_finish', 'short_query_finish', 'full_query_finish', 'retract_finish'].include?(tokens.last&.first)
        parser_error("Syntax error at #{text}", 'unterminated clause')
      end

      # Reorder and fix clause conditions
      tokens.each.with_index do |s, idx|
        next if s.nil? || s[0] != 'oper'

        if ['>=', '<=', '=', '>', '<', '<>', ':'].include?(s[1])
          var1 = tokens[idx - 1]
          var2 = tokens[idx + 1]

          if !var1 || !var2 || ((var1[0] == 'var') == (var2[0] == 'var'))
            parser_error("Syntax error at #{text}", 'invalid clause condition format')
          end

          var = var1[0] == 'var' ? var1 : var2
          const = var1[0] == 'var' ? var2 : var1

          if var2[0] == 'var'
            s[1] = invert_operator(s[1])
          end

          if s[1] == ':' && !['integer', 'float', 'string', 'list'].include?(const[1])
            parser_error("Syntax error at #{text}", 'invalid argument for : operator')
          end

          tokens[idx - 1] = ['var', Variable.new(var[1], s[1], const[1].class.to_s.downcase, const[1])]
          tokens[idx] = nil
          tokens[idx + 1] = nil
        else
          parser_error("Syntax error at #{text}", 'unknown clause condition operator')
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
          parser_error("Syntax error at #{text}", 'unexpected , character')
        elsif s[0] == 'name' && (tokens[idx + 1].nil? || tokens[idx + 1][0] != 'args_start')
          parser_error("Syntax error at #{text}", 'clause without arguments list')
        elsif s[0] == 'args_start' && tokens[idx + 1] && tokens[idx + 1][0] == 'args_end'
          parser_error("Syntax error at #{text}", 'empty arguments list')
        elsif s[0] == 'name'
          chrs = s[1].chars

          if !NAME_ALLOWED_FIRST_CHARS.include?(chrs.first) || chrs.slice(1, chrs.count).any? { |c| !NAME_ALLOWED_REMAINING_CHARS.include?(c) }
            parser_error("Syntax error at #{text}", 'illegal character in clause name')
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
              parser_error("Syntax error at #{text}", 'unexpected ; character')
            end

            part.push(tokens.last)
            parts.push(part)
            part = []
          else
            part.push(token)
          end
        end

        if part.empty?
          parser_error("Syntax error at #{text}", 'unexpected ; character')
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
                parser_error("Syntax error at #{text}", 'illegal character in variable name')
              end

              parts[part_id] = number.to_s
            else
              parser_error("Syntax error at #{text}", 'illegal character in variable name')
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

      # Validate maximum number of variables in a clause
      token_set.each do |tokens|
        vars_in_same_clause = 0
        tokens.each.with_index do |token, idx|
          if token[0] == 'var'
            vars_in_same_clause += 1

            if vars_in_same_clause > MAX_FUNC_ARITY
              parser_error("Syntax error at #{text}", "Too many arguments in a single clause (max is #{MAX_FUNC_ARITY}): this is an interpreter-specific setting")
            end
          elsif token[0] == 'args_start'
            vars_in_same_clause = 0
          end
        end
      end

      token_set
    rescue ParserError => e
      raise if @test_mode

      puts e

      if @interactive
        puts
      else
        exit(1)
      end

      []
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

    def init_oper_clauses
      @operator_clauses = Set.new

      OPERATOR_CLAUSES.each do |clause|
        name, arity, variable_arity = clause

        if variable_arity
          (arity..MAX_FUNC_ARITY).each do |alt_arity|
            @operator_clauses.add("#{name}/#{alt_arity}")
          end
        else
          @operator_clauses.add("#{name}/#{arity}")
        end
      end
    end

    def select_table(name, output)
      if name && name.size > 0
        @table_name = name

        @table[@table_name] ||= []
        @memo_tree[@table_name] ||= {}
        @to_memo[@table_name] ||= Set.new

        puts "Table changed to #{@table_name}" if output
      else
        puts "Current table is #{@table_name}" if output
      end

      puts if output
    end

    def table_listing
      indent = 1
      count = @table[@table_name].count
      while count > 10
        count /= 10
        indent += 1
      end

      @table[@table_name].each.with_index do |arr, idx|
        puts "#{idx.to_s.rjust(indent)}: #{arr[0]}#{arr[1].any? ? " :- #{arr[1].join(', ')}" : ''}."
      end

      puts
    end

    def deep_clone(obj)
      case obj
      when Array
        obj.map { |o| deep_clone(o) }
      when Hash
        ret = {}
        obj.each { |k, v| ret[k] = deep_clone(v) }
        ret
      when Fact
        Fact.new(obj.name, obj.arg_list.dup)
      when Atom
        obj.clone
      else
        obj
      end
    end

    def file_read(name)
      ret = []

      remainder = ''

      File.foreach(name) do |line|
        line = line.to_s.strip
        if line.size == 0
          ret.push('')
          remainder = ''
          next
        end

        if line.end_with?('\\')
          remainder += " #{line.chomp('\\')}"
          next
        end

        line = remainder + line

        ret.push(line.strip)
        remainder = ''
      end

      ret
    rescue StandardError
      nil
    end

    def clause_match_built_in_eval(head)
      arity = head.arg_list.count

      other_args = head.arg_list.slice(0, arity - 1)
      return false if other_args.any? { |var| !var.const? } # Not ready to be unified

      value = send("oper_#{head.name}", other_args.map(&:value))
      return nil unless value

      value = Literal.new(value)

      return nil if head.arg_list.last.const? && !value.eql?(head.arg_list.last)

      [Fact.new(head.name, other_args + [value])]
    end

    def clauses_match(h1, h2, h1_has_body)
      return false unless h1.arity_name == h2.arity_name
      return true if !h1_has_body && h1.hash == h2.hash

      h1.arg_list.each.with_index do |var1, idx|
        var2 = h2.arg_list[idx]

        return false if var1.const? && var2.const? && !var1.eql?(var2)

        if var1.const? != var2.const?
          const = var1.const? ? var1 : var2
          var = var1.const? ? var2 : var1

          next if var.condition.nil?

          h1.arg_list.each do |var3|
            next if var3.const? || var3.name != var.name || var3.condition.nil?

            # Numeric types only unify with numeric types; same for strings
            if (var3.condition == ':')
              if const.type != var3.condition_value
                return false
              end
            else
              if !COMPATIBLE_CONDITIONS[var3.condition][const.type][var3.condition_type] || !const.value.send(var3.condition, var3.condition_value)
                return false
              end
            end
          end

          h2.arg_list.each do |var3|
            next if var3.const? || var3.name != var.name || var3.condition.nil?

            # Numeric types only unify with numeric types; same for strings
            if (var3.condition == ':')
              if const.type != var3.condition_value
                return false
              end
            else
              if !COMPATIBLE_CONDITIONS[var3.condition][const.type][var3.condition_type] || !const.value.send(var3.condition, var3.condition_value)
                return false
              end
            end
          end
        end
      end

      # Ensure there are no incompatible substitutions
      list1 = deep_clone(h1.arg_list)
      list2 = deep_clone(h2.arg_list)

      list1.each.with_index do |var1, idx|
        var2 = list2[idx]

        if var1.const?
          if !var2.const?
            replace_var_with_const(var1, list2, list1, var2.name, nil)
          end
        elsif var2.const?
          replace_var_with_const(var2, list1, list2, var1.name, nil)
        end
      end

      list1.each.with_index do |var1, idx|
        next unless var1.const?

        var2 = list2[idx]

        return false if var1.value != var2.value
      end

      true
    end

    def replace_var_with_const(const, list1, list2, list1_var_name, list2_var_name)
      list1.each.with_index do |var1, idx|
        if !var1.const? && var1.name == list1_var_name
          list1[idx] = const

          var2 = list2[idx]
          if !var2.const? && (list2_var_name.nil? || var2.name == list2_var_name)
            replace_var_with_const(const, list2, list1, list2_var_name || var2.name, list1_var_name)
          end
        end
      end
    end

    def replace_variable_with_literal(var_name, literal, head)
      new_literal = Literal.new(literal)

      head.arg_list.each.with_index do |var1, idx|
        if !var1.const? && var1.name == var_name
          head.arg_list[idx] = new_literal
        end
      end
    end

    def replace_variable_with_variable(var_name, new_var_name, head)
      new_var = Variable.new(new_var_name)

      head.arg_list.each.with_index do |var1, idx|
        if !var1.const? && var1.name == var_name
          head.arg_list[idx] = new_var
        end
      end
    end

    def unique_var_names(clauses)
      unique_vars = Set.new

      clauses.each do |head|
        head = head[0]
        head.arg_list.each do |var1|
          next if var1.const? || unique_vars.include?(var1.name)

          if var1.name[0] >= '0' && var1.name[0] <= '9'
            unique_vars.add(var1.name)
            next
          end

          @vari += 1
          new_var_name = @vari.to_s
          new_var = Variable.new(new_var_name)
          unique_vars.add(var1.name)

          clauses.each do |head1|
            head1 = head1[0]

            head1.arg_list.each.with_index do |var2, idx|
              head1.arg_list[idx] = new_var if !var2.const? && var1.name == var2.name
            end
          end
        end
      end

      clauses
    end

    def substitute_variables(solution, removed_clause, new_clauses)
      new_clauses = new_clauses.flatten

      new_clauses[0].arg_list.each.with_index do |var1, idx1|
        var2 = removed_clause.arg_list[idx1]

        if var1.const?
          if !var2.const?
            # Replace variable in solution
            solution.each do |arr|
              replace_variable_with_literal(var2.name, var1.value, arr[0])
            end
          end
        elsif var2.const?
          # Replace variable in new_clauses
          new_clauses.each do |clause|
            replace_variable_with_literal(var1.name, var2.value, clause)
          end
        else
          # Replace variable in new_clauses
          new_clauses.each do |clause|
            replace_variable_with_variable(var1.name, var2.name, clause)
          end
        end
      end

      new_clauses
    end

    def memoed_fact(memo, arguments)
      return [] if arguments.empty?

      var = arguments.first

      if var.const?
        if memo[var]
          arguments = arguments.slice(1, arguments.count)

          if arguments.any?
            return [var, memoed_fact(memo[var], arguments)]
          else
            [var]
          end
        else
          return nil
        end
      else
        arguments = arguments.slice(1, arguments.count)

        memo.each do |value, sol|
          se = memoed_fact(sol, arguments)

          return [value, se] if se
        end

        return nil
      end
    end

    def search(head, stop_early)
      @vari = 0
      iteration = 0
      solution_set_hashes = Set.new
      time_limit = Time.now + @search_time_limit

      dummy_head = Fact.new('0', deep_clone(head.arg_list))
      dummy_vars = (0...head.arg_list.size).map { |i| Variable.new(('A'.ord + i).chr) }
      dummy_clause = [Fact.new(dummy_head.name, dummy_vars), [Fact.new(head.name, dummy_vars)]]

      @table[@table_name] = [dummy_clause] + @table[@table_name]
      head = dummy_head

      solution_set = [unique_var_names([[deep_clone(head), false]])]

      while Time.now < time_limit
        if @debug
          iteration += 1

          puts "Iteration #{iteration}"
          solution_set.each.with_index do |solution, idx|
            puts "  Solution #{idx + 1}"
            solution.each do |head1|
              puts "    #{head1[1] ? '*' : ''}#{head1[0].to_s(true)}."
            end
          end
        end

        first_solution_idx = solution_set.find_index do |solution|
          solution.any? do |solution_clause|
            !solution_clause[1]
          end
        end

        if first_solution_idx.nil? || (stop_early && first_solution_idx > 0)
          successful_solutions = solution_set.select do |solution|
            !solution.any? do |solution_clause|
              solution_clause[0].arg_list.any? { |v| !v.const? }
            end
          end

          successful_solutions = [successful_solutions[0]] if stop_early && successful_solutions.any?

          return successful_solutions.map { |sol| sol[0][0] }
        end

        first_solution = solution_set[first_solution_idx]
        try_again = false

        first_solution_clause_by_builtin_idx = nil
        first_solution_clause_idx = nil
        built_in_response = nil

        first_solution.each.with_index do |solution_clause, idx|
          next if solution_clause[1]

          if @operator_clauses.include?(solution_clause[0].arity_name)
            built_in_response = clause_match_built_in_eval(solution_clause[0])
            if built_in_response
              first_solution_clause_by_builtin_idx = idx
              break
            elsif built_in_response != false
              # Solution can never be unified
              try_again = true
              solution_set[first_solution_idx] = nil
              solution_set = solution_set.compact
              break
            end
          else
            # Why = instead of ||=? For some reason, in practise, the performance is much worse if
            # start by expanding the upper clauses.
            first_solution_clause_idx = idx
          end
        end

        next if try_again

        first_solution_clause_idx = first_solution_clause_by_builtin_idx || first_solution_clause_idx
        first_solution_clause = first_solution[first_solution_clause_idx]
        first_solution_clause[1] = true
        matching_clauses = nil

        if first_solution_clause_by_builtin_idx
          matching_clauses = [built_in_response]
        else
          head = first_solution_clause[0]
          matching_clauses = nil

          if @to_memo[@table_name].include?(head.arity_name)
            memo_solution = @memo_tree[@table_name][head.arity_name]

            if memo_solution
              memoed = memoed_fact(memo_solution, head.arg_list)

              if memoed
                matching_clauses = [[Fact.new(head.name, memoed.flatten), []]]
              end
            end
          end

          matching_clauses ||= @table[@table_name].select do |table_clause|
            clauses_match(table_clause[0], head, table_clause[1].any?)
          end
        end

        solution_set[first_solution_idx] = nil
        solution_set = solution_set.compact

        if matching_clauses.any?
          matching_clauses.each.with_index do |clause, matching_clause_idx|
            new_solution = deep_clone(first_solution)

            new_clauses = substitute_variables(new_solution, first_solution_clause[0], deep_clone(clause))

            impossible_solution = false
            prev_count = new_solution.count
            new_clauses.each.with_index do |line, idx|
              next if idx == 0

              if @operator_clauses.include?(line.arity_name) || @table[@table_name].any? { |table_entry| table_entry[0].arity_name == line.arity_name }
                new_solution.push([line, false])
              else
                impossible_solution = true
                break
              end
            end

            if impossible_solution
              solution_set[first_solution_idx] = nil
              solution_set = solution_set.compact
              break
            end

            if matching_clause_idx > 0 && new_clauses.count == 1
              new_solution[first_solution_clause_idx][1] = false
            end

            # Truncate solution to first clause and clauses still to be resolved (it not debugging)
            new_solution = new_solution.select.with_index do |rule, idx|
              memoized_func = @to_memo[@table_name].include?(rule[0].arity_name)

              kept = idx == 0 || !rule[1] || memoized_func

              # If can be memoized and the rule is finished, memoize it
              if rule[1] && memoized_func && rule[0].arg_list.all? { |v| v.const? }
                @memo_tree[@table_name][rule[0].arity_name] ||= {}
                root = @memo_tree[@table_name][rule[0].arity_name]

                arity = rule[0].arg_list.count
                rule[0].arg_list.slice(0, arity - 1).each do |val|
                  root[val] ||= {}
                  root = root[val]
                end

                root[rule[0].arg_list.last] = true
              end

              @debug || kept
            end

            new_solution = unique_var_names(new_solution)

            # TODO: can performance be improved?
            new_solution_hash = new_solution.map { |l| l[0] }.hash

            unless solution_set_hashes.include?(new_solution_hash)
              solution_set_hashes.add(new_solution_hash)

              solution_set.push(new_solution)
            end
          end
        end
      end

      nil # Timeout
    ensure
      @table[@table_name] = @table[@table_name].slice(1, @table[@table_name].size)
    end

    def table_add_clause(head, body, warn_if_exists)
      if !head
        puts 'Invalid clause format'
        return
      end

      @table[@table_name].each do |arr|
        table_head = arr[0]
        table_body = arr[1]

        if table_head.hash == head.hash && table_body.map(&:hash).sort == body.map(&:hash).sort
          if warn_if_exists
            puts 'Clause already exists'
            puts
          end
          return
        end
      end

      @table[@table_name].push([head, body])
    end

    def parser_error(msg, detail = nil)
      raise ParserError.new([msg, detail].compact.join(': '))
    end
  end
end
