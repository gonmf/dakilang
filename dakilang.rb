# frozen_string_literal: true

begin
  require 'rb-readline'
  require 'pry'
rescue Exception
end

require 'set'

Dir['**/*.rb'].each do |filename|
  next if ['test.rb', 'dakilang.rb'].include?(filename)

  require_relative filename
end

class DakiLangInterpreter
  include OperatorClauses

  VERSION = '0.22'

  OPERATOR_CLAUSES = Set.new([
    # Arithmetic
    'add/3',
    'sub/3',
    'mul/3',
    'div/3',
    'mod/3',
    'pow/3',
    'sqrt/2',
    'log/3',
    'round/3',
    'trunc/2',
    'floor/2',
    'ceil/2',
    'abs/2',
    # Equality/order
    'eql/3',
    'neq/3',
    'max/3',
    'min/3',
    'gt/3',
    'lt/3',
    'gte/3',
    'lte/3',
    # Casts
    'as_string/2',
    'as_string/3',
    'as_integer/2',
    'as_integer/3',
    'as_float/2',
    # Strings
    'ord/2',
    'char/2',
    'split/3',
    # Strings and Lists
    'len/2',
    'concat/3',
    'slice/4',
    'index/4',
    # Lists
    'head/2',
    'tail/2',
    'push/3',
    'append/3',
    'put/4',
    'unique/2',
    'reverse/2',
    'sort/2',
    'sum/2',
    'max/2',
    'min/2',
    'join/3',
    'init/3',
    # Other
    'rand/1',
    'type/2',
    'print/2',
    'print/3',
    'time/1',
    'time/2',
    # Private
    '_eval/3'
  ]).freeze

  NAME_ALLOWED_FIRST_CHARS = (('a'..'z').to_a + ('A'..'Z').to_a).freeze
  NAME_ALLOWED_REMAINING_CHARS = (['_'] + ('a'..'z').to_a + ('A'..'Z').to_a + ('0'..'9').to_a).freeze
  VAR_EQUATION_CHARS = (["\r", "\t", ' ', '-', '_', '(', ')', '+', '-', '*', '/', '.', 'x'] + ('a'..'f').to_a + ('A'..'F').to_a + ('0'..'9').to_a).join(' ').freeze
  WHITESPACE_CHARS = ["\r", "\t", ' '].freeze

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
    '<>' => {
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
    puts "dakilang #{VERSION}"
    puts
  end

  def print_help
    puts 'USE'
    puts '    ./dakilang [OPTIONS]'
    puts
    puts 'OPTIONS'
    puts '-h, --help                 % Print out the program manual and exit'
    puts '-v, --version              % Print out the program name and version, and exit'
    puts '-c file, --consult file    % Read file with path "file" and interpret each line'
    puts '-i, --interactive          % Activate interactive mode after finishing consulting all files'
    puts '-d, --debug                % Activate debug mode, which shows extra output and disables some performance improvements'
    puts '-t seconds, --time seconds % Changes the default query timeout time; "seconds" is a floating point value in seconds'
    puts
  end

  def debug_tokenizer(line)
    @test_mode = true

    tokens = tokenizer(line)

    tokens.map { |token| token[1] ? "#{token[0]}(#{token[1].to_s})" : token[0] }.join(' | ')
  rescue ParserError => e
    e.to_s
  end

  private

  def run_commands(lines, consult_chain)
    lines.each do |line|
      puts "> #{line}" unless @interactive

      down_line = line.split('%').first.to_s.strip.downcase
      if down_line == 'quit'
        if @interactive
          exit(0)
        else
          return
        end
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
      if down_line == 'version'
        print_version
        next
      end
      if down_line == 'help'
        print_help
        next
      end

      tokens = tokenizer(line)
      next if tokens.empty?

      puts tokens.map { |a| a.join(':') }.join(', ') if @debug

      case tokens.last.first
      when 'clause_finish'
        add_rule(tokens)
      when 'short_query_finish'
        execute_query(tokens, true)
      when 'full_query_finish'
        execute_query(tokens, false)
      when 'retract_finish'
        retract_rule_by_full_match(tokens)
        puts
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

    if head && OPERATOR_CLAUSES.include?(head.arity_name)
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
        head.arg_list.each.with_index do |arg, idx|
          if !arg.const?
            printed_any = true
            value = solution.arg_list[idx]

            puts "#{arg.name} = #{value}"
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

  def add_rule(tokens)
    head, last_idx = build_fact(tokens)

    if head && OPERATOR_CLAUSES.include?(head.arity_name)
      puts 'Built-in operator clause already exists'
      puts
      return
    end

    bodies = []
    while last_idx != -1
      body, last_idx = build_fact(tokens, last_idx)
      bodies.push(body) if body
    end

    if tokens.include?(['or'])
      bodies.each do |body|
        table_add_clause(head, [body], bodies.count == 1)
      end
    else
      table_add_clause(head, bodies.any? ? bodies : [], true)
    end
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
    elsif OPERATOR_CLAUSES.include?(name)
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

  def tokenizer(text)
    text_chars = text.chars

    tokens = []

    arg_list_mode = false
    string_mode = false
    escape_mode = false
    number_mode = false
    floating_point_mode = false
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
            if floating_point_mode
              tokens.push(['const', string.to_f])
              floating_point_mode = false
            else
              tokens.push(['const', string.to_i])
            end
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

        if !['\'', '"'].any? { |v| atom.include?(v) } && ['+', '-', '*', '/'].any? { |v| atom.include?(v) }
          tested_part = text_chars.slice(idx, text_chars.count).join

          text_chars = (text_chars.slice(0, idx).join + (' ' * (1 + atom.size)) + tested_part.slice(1 + atom.size, tested_part.size)).split('')

          tokens.push(['var', atom.strip])
          next
        end
      end

      if number_mode
        if floating_point_mode
          if c == '.'
            parser_error("Syntax error at #{text}", 'illegal floating point format')
          elsif c >= '0' && c <= '9'
            string += c
            next
          end

          if ['-', '.'].include?(string.chars.last)
            parser_error("Syntax error at #{text}", "illegal floating point format at #{string}")
          end
          tokens.push(['const', string.to_f])
        else
          c_d = c.downcase

          if c_d == '.'
            floating_point_mode = true
            string += c_d
            next
          elsif c_d == 'b' || c_d == 'x' # Binary or hexadecimal mode
            if string == '0'
              string += c_d
              next
            else
              parser_error("Syntax error at #{text}", "illegal integer format at #{string}")
            end
          elsif c_d >= '0' && c_d <= '9'
            if string[0] == '0' && string[1] != 'b' && string[1] != 'x' # Octal mode
              if c_d > '7'
                parser_error("Syntax error at #{text}", "illegal integer octal format at #{string}")
              else
                string += c_d
                next
              end
            end

            if string[0] == '0' && string[1] == 'b' && c_d > '1' # Binary mode
              parser_error("Syntax error at #{text}", "illegal integer binary format at #{string}")
            end

            string += c_d
            next
          elsif c_d >= 'a' && c_d <= 'z'
            if c_d <= 'f' && string[1] == 'x' # Hexadecimal mode
              string += c_d
              next
            else
              parser_error("Syntax error at #{text}", "illegal integer hexadecimal format at #{string}")
            end
          end

          if ['-', '.'].include?(string.chars.last)
            parser_error("Syntax error at #{text}", "illegal integer format at #{string}")
          end

          base = 10
          if string[0] == '0'
            if string[1] == 'x'
              base = 16
            elsif string[1] == 'b'
              base = 2
            else
              base = 8
            end
          end

          tokens.push(['const', string.to_i(base)])
        end

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
        floating_point_mode = false
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

      if c == '%' # Comment
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

      if c == '~'
        if tokens.any? { |a| a[0].end_with?('_finish') }
          parser_error("Syntax error at #{text}", 'unexpected ~ character')
        end

        tokens.push(['retract_finish'])
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

    if string.size > 0
      parser_error("Syntax error at #{text}", 'unterminated text')
    end

    if tokens.any? && !['clause_finish', 'short_query_finish', 'full_query_finish', 'retract_finish'].include?(tokens.last&.first)
      parser_error("Syntax error at #{text}", 'unterminated clause')
    end

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

    tokens.each.with_index do |token, idx|
      if token && token[0] == 'var' && (token[1].is_a?(String) || token[1].is_a?(Array))
        tokens[idx] = ['var', Variable.new(token[1])]
      end
    end

    vari = 0
    tokens = tokens.compact
    new_tokens = tokens.dup
    sep_token_idx = tokens.index { |t| t == ['sep'] }

    tokens.each.with_index do |s, idx|
      if s[0] == 'name' && (tokens[idx + 1].nil? || tokens[idx + 1][0] != 'args_start')
        parser_error("Syntax error at #{text}", 'clause without arguments list')
      end
      if s[0] == 'args_start' && tokens[idx + 1] && tokens[idx + 1][0] == 'args_end'
        parser_error("Syntax error at #{text}", 'empty arguments list')
      end

      if s[0] == 'var'

        chrs = s[1].name.chars

        if !NAME_ALLOWED_FIRST_CHARS.include?(chrs.first) || chrs.slice(1, chrs.count).any? { |c| !NAME_ALLOWED_REMAINING_CHARS.include?(c) }
          if sep_token_idx.nil? || (sep_token_idx > idx && !chrs.any? { |c| !VAR_EQUATION_CHARS.include?(c) })
            parser_error("Syntax error at #{text}", 'illegal character in variable name')
          elsif tokens.include?(['or'])
            parser_error("Syntax error at #{text}", 'illegal to mix logical OR clauses with inlined variable operations')
          else
            # Variable equation
            equ = s[1].name.tr(' ', '')

            var_name_mode = false
            var_names = []
            string = ''
            equ.chars.each.with_index do |c, idx2|
              if var_name_mode
                if NAME_ALLOWED_REMAINING_CHARS.include?(c)
                  string += c
                else
                  var_names.push(string)
                  string = ''
                  var_name_mode = false
                end
              else
                if NAME_ALLOWED_FIRST_CHARS.include?(c)
                  var_name_mode = true
                  string += c
                end
              end
            end

            if var_name_mode
              var_names.push(string)
            end

            var_names = var_names.uniq

            if var_names.count == 0
              parser_error("Syntax error at #{text}", 'equation missing variable name')
            end
            if var_names.count > 1
              parser_error("Syntax error at #{text}", 'multiple variable names in single variable equation')
            end

            var_name = var_names.first

            vari += 1
            new_var_name = "$#{vari.to_s(16)}"
            equation = equ.gsub(var_name, '$')

            new_clause = [
              ['name', '_eval'],
              ['args_start'],
              ['var', Variable.new(var_name)],
              ['const', Literal.new(equation)],
              ['var', Variable.new(new_var_name)],
              ['args_end'],
              ['and']
            ]
            s[1] = Variable.new(new_var_name)

            new_tokens = new_tokens.slice(0, sep_token_idx + 1) + new_clause + new_tokens.slice(sep_token_idx + 1, new_tokens.count)
          end
        end
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

    tokens = new_tokens

    tokens.each.with_index do |token, idx|
      if token && token[0] == 'const_list_start'
        val = recursive_build_array(tokens, idx)

        tokens[idx] = ['const', Literal.new(val)]
      end
    end

    tokens.compact
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

  def clause_match_built_in_ready(head)
    arity = head.arg_list.count

    head.arg_list.slice(0, arity - 1).all? { |v| v.const? }
  end

  def clause_match_built_in_eval(head)
    name = head.name
    arity = head.arg_list.count

    other_args = head.arg_list.slice(0, arity - 1)
    return nil if other_args.any? { |var| !var.const? }

    value = send("oper_#{name}", other_args.map(&:value))
    return nil unless value

    value = Literal.new(value)

    return nil if head.arg_list.last.const? && !value.eql?(head.arg_list.last)

    [Fact.new(name, other_args + [value])]
  end

  def clauses_match(h1, h2)
    return false unless h1.arity_name == h2.arity_name

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
            if !COMPATIBLE_CONDITIONS[var3.condition][const.type][var3.condition_type] || !const.value.send(var3.real_condition, var3.condition_value)
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
            if !COMPATIBLE_CONDITIONS[var3.condition][const.type][var3.condition_type] || !const.value.send(var3.real_condition, var3.condition_value)
              return false
            end
          end
        end
      end
    end

    # Ensure there are no incompatible substitutions, like
    # a(A, A).
    # matching
    # a(A, B).

    h1 = deep_clone(h1)
    h2 = deep_clone(h2)
    dummy_value = rand

    h1.arg_list.each.with_index do |var1, idx1|
      var2 = h2.arg_list[idx1]

      if var1.const?
        unless var2.const?
          replace_variable_with_literal(var2.name, var1.value, h2)
        end
      elsif var2.const?
        replace_variable_with_literal(var1.name, var2.value, h1)
      else
        replace_variable_with_literal(var1.name, dummy_value, h1)
        replace_variable_with_literal(var2.name, dummy_value, h2)

        dummy_value += 1
      end
    end

    h1.arg_list.each.with_index do |var, idx|
      return false if var.value != h2.arg_list[idx].value
    end

    true
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
    time_limit = Time.now + @search_time_limit

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

        successful_solutions = [successful_solutions[0]] if stop_early

        return successful_solutions.map { |sol| sol[0][0] }
      end

      first_solution = solution_set[first_solution_idx]
      try_again = false

      first_solution_clause_by_builtin_idx = nil
      first_solution_clause_idx = nil
      built_in_response = nil
      first_solution.each.with_index do |solution_clause, idx|
        next if solution_clause[1]

        if OPERATOR_CLAUSES.include?(solution_clause[0].arity_name)
          built_in_response = clause_match_built_in_eval(solution_clause[0])
          if built_in_response
            first_solution_clause_by_builtin_idx = idx
            break
          elsif clause_match_built_in_ready(solution_clause[0])
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
      if first_solution_clause_idx.nil?
        return []
      end

      first_solution_clause = first_solution[first_solution_clause_idx]
      first_solution_clause[1] = true

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
          clauses_match(table_clause[0], head)
        end
      end

      if matching_clauses.any?
        matching_clauses.each do |clause|
          new_solution = deep_clone(first_solution)

          new_clauses = substitute_variables(new_solution, first_solution_clause[0], deep_clone(clause))

          new_clauses.each.with_index do |line, idx|
            next if idx == 0

            new_solution.push([line, false])
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

          solution_set.push(unique_var_names(new_solution))
        end
      end

      solution_set[first_solution_idx] = nil
      solution_set = solution_set.compact
    end

    nil # Timeout
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

interpreter = DakiLangInterpreter.new
enter_interactive = false
argv = ARGV.dup

argv.each.with_index do |command, idx|
  if command == '-h' || command == '--help'
    interpreter.print_help
    exit(0)
  end

  if command == '-v' || command == '--version'
    interpreter.print_version
    exit(0)
  end

  if command == '-d' || command == '--debug'
    interpreter.debug = true
    argv[idx] = nil
  end

  if command == '-i' || command == '--interactive'
    enter_interactive = true
    argv[idx] = nil
  end
end

argv = argv.compact

argv.each.with_index do |command, idx|
  next if command.nil?

  if command == '-t' || command == '--time'
    new_time = argv[idx + 1].to_f

    if argv[idx + 1] && new_time > 0
      interpreter.search_time_limit = new_time
      argv[idx] = nil
      argv[idx + 1] = nil
    else
      puts "Illegal time limit argument #{argv[idx + 1]}"
      exit(1)
    end
  end
end

argv = argv.compact
to_consult = []

argv.each.with_index do |command, idx|
  next if command.nil?

  if command == '-c' || command == '--command'
    to_consult.push(argv[idx + 1])
    argv[idx] = nil
    argv[idx + 1] = nil
  end
end

if argv.compact.any?
  puts 'Illegal arguments'
  puts
  exit(1)
end

to_consult.each do |file|
  interpreter.consult_file(file)
end

if enter_interactive
  interpreter.enter_interactive_mode
end
