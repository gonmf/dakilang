# frozen_string_literal: true

require 'rb-readline'
require 'pry'
require 'set'

require_relative 'monkey_patches'
require_relative 'built_in_operators'
require_relative 'parser_error'
require_relative 'fact'

class DakiLangInterpreter
  include OperatorClauses

  VERSION = '0.18'

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
    'len/2',
    'concat/3',
    'slice/4',
    'index/4',
    'ord/2',
    'char/2',
    # Other
    'rand/1',
    'type/2',
    'print/2',
    'time/1',
    'time/2'
  ]).freeze

  NAME_ALLOWED_FIRST_CHARS = (('a'..'z').to_a + ('A'..'Z').to_a).freeze
  NAME_ALLOWED_REMAINING_CHARS = (['_'] + ('a'..'z').to_a + ('A'..'Z').to_a + ('0'..'9').to_a).freeze
  WHITESPACE_CHARS = ["\r", "\t", ' '].freeze

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

    tokens.map { |token| token[1] ? "#{token[0]}(#{token[1]})" : token[0] }.join(' | ')
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
        retract_rule(tokens)
      end
    end
  end

  def retract_rule(tokens)
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
      solutions.uniq.each do |arr1|
        puts "#{arr1}."
      end
    else
      puts 'No solution'
    end

    puts
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

  def tokenizer(text)
    text_chars = text.chars

    tokens = []

    arg_list_mode = false
    string_mode = false
    escape_mode = false
    number_mode = false
    floating_point_mode = false
    separator_mode = false
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
          tokens.push(['string_const', string])
          string = ''
          string_mode = false
        else
          string += c
        end

        next
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
          tokens.push(['float_const', string.to_f])
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

          tokens.push(['integer_const', string.to_i(base)])
        end

        string = ''
        number_mode = false
      end

      if operator_mode
        if ['<', '>', '='].include?(c)
          string += c
          next
        else
          tokens.push(['oper', string])
          string = ''
          operator_mode = false
        end
      elsif ['<', '>', ':'].include?(c) && arg_list_mode
        if string.size > 0
          tokens.push(['var', "%#{string}"])
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

      if c == '%' # Comment
        break
      end

      if WHITESPACE_CHARS.include?(c) # Whitespace is ignored outside of string literals
        if string.size > 0
          if arg_list_mode
            tokens.push(['var', "%#{string}"])
            string = ''
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
          tokens.push(['var', "%#{string}"])
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
            tokens.push(['var', "%#{string}"])
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

        if s[1] == ':' && (const[0][0] != 's' || !['integer', 'float', 'string'].include?(const[1]))
          parser_error("Syntax error at #{text}", 'invalid argument for : operator')
        end

        new_var = "#{var[1]}%#{s[1]}%#{const[0][0]}%#{const[1]}"
        tokens[idx - 1] = ['var', new_var]
        tokens[idx] = nil
        tokens[idx + 1] = nil
      else
        parser_error("Syntax error at #{text}", 'unknown clause condition operator')
      end
    end

    tokens = tokens.compact

    tokens.each.with_index do |s, idx|
      if s[0] == 'name' && (tokens[idx + 1].nil? || tokens[idx + 1][0] != 'args_start')
        parser_error("Syntax error at #{text}", 'clause without arguments list')
      end
      if s[0] == 'args_start' && tokens[idx + 1] && tokens[idx + 1][0] == 'args_end'
        parser_error("Syntax error at #{text}", 'empty arguments list')
      end

      next if s[0] != 'var' && s[0] != 'name'

      if s[0] == 'var'
        chrs = s[1].split('%')[1].chars

        if !NAME_ALLOWED_FIRST_CHARS.include?(chrs.first) || chrs.slice(1, chrs.count).any? { |c| !NAME_ALLOWED_REMAINING_CHARS.include?(c) }
          parser_error("Syntax error at #{text}", "illegal character in variable name")
        end
      elsif s[0] == 'name'
        chrs = s[1].chars

        if !NAME_ALLOWED_FIRST_CHARS.include?(chrs.first) || chrs.slice(1, chrs.count).any? { |c| !NAME_ALLOWED_REMAINING_CHARS.include?(c) }
          parser_error("Syntax error at #{text}", "illegal character in clause name")
        end
      else
        next
      end
    end

    tokens
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
    @table[@table_name].each do |arr|
      puts "#{arr[0]}#{arr[1].any? ? " :- #{arr[1].join(', ')}" : ''}."
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

    value = send("oper_#{name}", other_args)

    if head.arg_list.last.const?
      return nil if value.class != head.arg_list.last.class || value != head.arg_list.last
    end

    value ? [Fact.new(name, other_args + [value])] : nil
  end

  def parse_variable_condition(varname)
    start, name, oper, const_type, = varname.split('%')
    return [varname] unless oper

    const_value = varname.slice([start, name, oper, const_type].join('_').size + 1, varname.size)

    if oper == '<>'
      oper = '!='
    elsif oper == ':'
      oper = 'class_is'
    end

    case const_type
    when 'i'
      const_value = const_value.to_i
    when 'f'
      const_value = const_value.to_f
    when 's'
      const_value = const_value.to_s
    end

    [name, oper, const_value]
  end

  def clauses_match(h1, h2)
    return false unless h1.arity_name == h2.arity_name

    h1.arg_list.each.with_index do |var1, idx|
      var2 = h2.arg_list[idx]

      return false if var1.const? && var2.const? && (var1.class != var2.class || var1 != var2)

      if var1.const? != var2.const?
        const = var1.const? ? var1 : var2
        var = var1.const? ? var2 : var1
        var, oper = parse_variable_condition(var)

        next if oper.nil?

        h1.arg_list.each do |var3|
          next if var3.const?

          var3, oper2, comp2 = parse_variable_condition(var3)

          if var3 == var && oper2 # Numeric types only unify with numeric types; same for strings
            return false if (oper2 != 'class_is' && const.is_a?(String) != comp2.is_a?(String)) || !const.send(oper2, comp2)
          end
        end

        h2.arg_list.each do |var3|
          next if var3.const?

          var3, oper2, comp2 = parse_variable_condition(var3)

          if var3 == var && oper2 # Numeric types only unify with numeric types; same for strings
            return false if (oper2 != 'class_is' && const.is_a?(String) != comp2.is_a?(String)) || !const.send(oper2, comp2)
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
    dummy_count = 0
    h1.arg_list.each.with_index do |var1, idx1|
      var2 = h2.arg_list[idx1]

      if var1.const?
        unless var2.const?
          name_only = var2.split('%')[1]

          replace_variable(name_only, var1, h2)
        end
      elsif var2.const?
        name_only = var1.split('%')[1]

        replace_variable(name_only, var2, h1)
      else
        dummy_count += 1
        dummy_value = "_#{dummy_count}"

        name_only = var1.split('%')[1]
        replace_variable(name_only, dummy_value, h1)

        name_only = var2.split('%')[1]
        replace_variable(name_only, dummy_value, h2)
      end
    end

    h1.arg_list.each.with_index do |var, idx|
      return false if var != h2.arg_list[idx]
    end

    true
  end

  def replace_variable(var_name, literal, head)
    head.arg_list.each.with_index do |var1, idx|
      if !var1.const? && var1.split('%')[1] == var_name
        head.arg_list[idx] = literal
      end
    end
  end

  def unique_var_names(clauses)
    unique_vars = Set.new

    clauses.each do |head|
      head = head[0]
      head.arg_list.each do |var_name1|
        next if var_name1.const? || unique_vars.include?(var_name1)

        if var_name1[1] >= '0' && var_name1[1] <= '9'
          unique_vars.add(var_name1)
          next
        end

        @vari += 1
        new_var_name = "%#{@vari}"
        unique_vars.add(var_name1)

        clauses.each do |head1|
          head1 = head1[0]

          head1.arg_list.each.with_index do |var_name2, idx|
            head1.arg_list[idx] = new_var_name if var_name1 == var_name2
          end
        end
      end
    end

    clauses
  end

  def substitute_variables(solution, removed_clause, new_clauses)
    new_clauses = new_clauses.flatten

    new_clauses[0].arg_list.each.with_index do |var_name1, i1|
      var_name2 = removed_clause.arg_list[i1]

      if var_name1.const?
        if !var_name2.const?
          name_only = var_name2.split('%')[1]

          # Replace variable in solution
          solution.each do |arr|
            replace_variable(name_only, var_name1, arr[0])
          end
        end
      elsif var_name2.const?
        name_only = var_name1.split('%')[1]

        # Replace variable in new_clauses
        new_clauses.each do |clause|
          replace_variable(name_only, var_name2, clause)
        end
      else
        name_only = var_name1.split('%')[1]

        # Replace variable in new_clauses
        new_clauses.each do |clause|
          replace_variable(name_only, var_name2, clause)
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
            puts "    #{head1[1] ? '*' : ''}#{head1[0].format(false)}."
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
          first_solution_clause_idx = idx
        end
      end

      next if try_again

      first_solution_clause = first_solution[first_solution_clause_by_builtin_idx || first_solution_clause_idx]
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

ARGV.each.with_index do |command, idx|
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
    ARGV[idx] = nil
  end

  if command == '-i' || command == '--interactive'
    enter_interactive = true
    ARGV[idx] = nil
  end
end

ARGV.compact.each.with_index do |command, idx|
  next if command.nil?

  if command == '-t' || command == '--time'
    new_time = ARGV[idx + 1].to_f

    if ARGV[idx + 1] && new_time > 0
      interpreter.search_time_limit = new_time
      ARGV[idx] = nil
      ARGV[idx + 1] = nil
    else
      puts "Illegal time limit argument #{ARGV[idx + 1]}"
      exit(1)
    end
  end
end

to_consult = []

ARGV.compact.each.with_index do |command, idx|
  next if command.nil?

  if command == '-c' || command == '--command'
    to_consult.push(ARGV[idx + 1])
    ARGV[idx] = nil
    ARGV[idx + 1] = nil
  end
end

if ARGV.compact.any?
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
