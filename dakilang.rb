class String
  def const?
    self[0] != '%'
  end
end

class Integer
  def const?
    true
  end
end

class Float
  def const?
    true
  end
end

class DakiLangInterpreter
  class Fact
    attr_accessor :name, :variables

    def initialize(name, variables)
      @name = name
      @variables = variables
    end

    def format(friendly)
      friendly_variables = variables.map do |s|
        if s.const?
          case s
          when String
            "'#{s}'"
          when Float, Integer
            s.to_s
          end
        else
          friendly ? "#{s.slice(1, s.size)}" : s
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

  def initialize
    @iteration_limit = 500
    @debug = false
    @table = {}
    @table_name = '0'
  end

  def enter_interactive_mode
    @interactive = true

    while true
      print '> '
      input = STDIN.gets.chomp

      run_commands([input], [])
    end
  end

  def consult_file(filename, consult_chain = [])
    if consult_chain.include?(filename)
      puts 'Circular file consult invocation detected'
    else
      contents = file_read(filename)

      if contents
        run_commands(contents, consult_chain + [filename])
      else
        puts 'File not found or cannot be read'
      end
    end

    puts
  end

  def print_version
    puts 'dakilang 0.5'
    puts
  end

  def print_help
    # TODO:
    raise 'NotImplementedError'
  end

  private

  def run_commands(lines, consult_chain)
    lines.each do |line|
      puts "> #{line}" unless @interactive

      if line == 'quit' || line == 'exit'
        if @interactive
          exit(0)
        else
          return
        end
      end
      if line == 'select_table' || line.start_with?('select_table ')
        select_table(line.split(' ')[1])
        next
      end
      if line == 'listing'
        table_listing
        next
      end
      if line.start_with?('consult ')
        consult_file(line.split(' ')[1], consult_chain)
        next
      end
      if line == 'version'
        print_version
        next
      end
      if line == 'help'
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

    arr1 = [head].compact
    while last_idx != -1
      body, last_idx = build_fact(tokens, last_idx)
      arr1.push(body) if body
    end

    table.each.with_index do |rule, idx|
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
        table[idx] = nil
        @table[@table_name] = table.compact
        puts 'Clause removed'
        return
      end
    end

    puts 'Clause not found'
  end

  def execute_query(tokens, stop_early)
    head, _ = build_fact(tokens)

    solutions = search(head, stop_early)

    if solutions.any?
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
    variables = []
    end_index = -1

    start_found = false
    tokens.each.with_index do |token, idx|
      next if idx < start_index

      if start_found
        if token[0] == 'varlist_end'
          end_index = idx
          break
        end

        variables.push(token[1])
      else
        if token[0] == 'varlist_start'
          name = tokens[idx - 1]

          if name[0] != 'name'
            raise 'Unexpected error 1'
          end

          start_found = true
        end

        next
      end
    end

    if name && variables.any?
      [Fact.new(name[1], variables), end_index]
    else
      [nil, -1]
    end
  end

  def tokenizer(text)
    text_chars = text.chars

    tokens = []

    var_list = false
    string_mode = false
    escape_mode = false
    number_mode = false
    floating_point = false
    separator_mode = false
    string_char = nil
    string = ''
    name = ''

    text_chars.each.with_index do |c, idx|
      if separator_mode
        if c == '-'
          tokens.push(['sep'])
          separator_mode = false
          next
        else
          err("Syntax error at #{text} around", 'expected :-')
        end
      end

      if string_mode
        if escape_mode
          if c == "\\" || c == string_char
            string += c
            escape_mode = false
            next
          else
            err("Syntax error at #{text}", 'string literal escape of unsupported character')
          end
        elsif c == "\\"
          escape_mode = true
          next
        end

        if c == string_char
          if string.empty?
            err("Syntax error at #{text}", 'empty string literal')
          end

          tokens.push(['string_const', string])
          string = ''
          string_mode = false
        else
          string += c
        end

        next
      end

      if number_mode
        if floating_point
          if c == '.'
            err("Syntax error at #{text}", 'illegal floating point format')
          elsif c >= '0' && c <= '9'
            string += c
            next
          end

          if ['-', '.'].include?(string.chars.last)
            err("Syntax error at #{text}", "illegal floating point format at #{string}")
          end
          tokens.push(['float_const', string.to_f])
        else
          if c == '.'
            floating_point = true
            string += c
            next
          elsif c >= '0' && c <= '9'
            string += c
            next
          end

          if ['-', '.'].include?(string.chars.last)
            err("Syntax error at #{text}", "illegal integer format at #{string}")
          end
          tokens.push(['integer_const', string.to_i])
        end

        string = ''
        number_mode = false
      end

      if c == '-' || (c >= '0' && c <= '9') && name.size == 0
        number_mode = true
        floating_point = false
        string = c
        next
      end

      if c == '%' # Comment
        break
      end

      next if c == ' ' || c == "\t" || c == "\r" # Whitespace are ignored outside of string literals

      if c == '.'
        if tokens.any? { |a| a[0].end_with?('_finish') }
          err("Syntax error at #{text}", 'unexpected . character')
        end

        tokens.push(['clause_finish'])
        next
      end

      if c == '?'
        if tokens.any? { |a| a[0].end_with?('_finish') }
          err("Syntax error at #{text}", 'unexpected ? character')
        end
        if tokens.include?(['sep'])
          err("Syntax error at #{text}", 'unexpected ? character for rule with tail')
        end

        tokens.push(['full_query_finish'])
        next
      end

      if c == '!'
        if tokens.any? { |a| a[0].end_with?('_finish') }
          err("Syntax error at #{text}", 'unexpected ! character')
        end
        if tokens.include?(['sep'])
          err("Syntax error at #{text}", 'unexpected ! character for rule with tail')
        end

        tokens.push(['short_query_finish'])
        next
      end

      if c == '~'
        if tokens.any? { |a| a[0].end_with?('_finish') }
          err("Syntax error at #{text}", 'unexpected ~ character')
        end

        tokens.push(['retract_finish'])
        next
      end

      if c == '"' || c == "'"
        if name.size > 0
          err("Syntax error at #{text}", 'unexpected end of name')
        end

        string_char = c
        string_mode = true
        next
      end

      if c == '('
        if name.empty?
          err("Syntax error at #{text}", 'unexpected start of argument list')
        end

        var_list = true
        tokens.push(['name', name])
        name = ''
        tokens.push(['varlist_start'])
        next
      end

      if c == ')'
        if !var_list
          err("Syntax error at #{text}", 'unexpected end of empty argument list')
        end

        var_list = false
        if name.size > 0
          tokens.push(['var', "%#{name}"])
          name = ''
        elsif tokens.last == ['varlist_start']
          err("Syntax error at #{text}", 'unexpected end of empty argument list')
        end

        tokens.push(['varlist_end'])
        next
      end

      if c == ','
        if var_list
          if name.size > 0
            tokens.push(['var', "%#{name}"])
            name = ''
          elsif tokens.last == ['varlist_start']
            err("Syntax error at #{text}", 'invalid , at argument list start')
          end
        else
          if !tokens.include?(['sep'])
            err("Syntax error at #{text}", 'invalid , character before clause head/tail separator')
          end

          if tokens.include?(['or'])
            err("Syntax error at #{text}", 'mixing of ; and , logical operators')
          end

          if name.size > 0
            tokens.push(['name', name])
            name = ''
          end
          tokens.push(['and'])
        end
        next
      end

      if c == ';'
        if !tokens.include?(['sep'])
          err("Syntax error at #{text}", 'invalid ; character before clause head/tail separator')
        end

        if tokens.include?(['and'])
          err("Syntax error at #{text}", 'mixing of ; and , logical operators')
        end

        if name.size > 0
          tokens.push(['name', name])
          name = ''
        end
        tokens.push(['or'])
        next
      end

      if c == ':' && !separator_mode
        if var_list
          err("Syntax error at #{text}", 'duplicate :- separator')
        end

        if name.size > 0
          tokens.push(['name', name])
          name = ''
        end

        separator_mode = true
        next
      end

      name += c
    end

    if name.size > 0
      err("Syntax error at #{text}", 'unterminated text')
    end

    if tokens.any? && !['clause_finish', 'short_query_finish', 'full_query_finish', 'retract_finish'].include?(tokens.last&.first)
      err("Syntax error at #{text}", 'unterminated clause')
    end

    tokens
  end

  def select_table(name)
    if name && name.size > 0
      @table_name = name
      puts "Table changed to #{name}"
    else
      puts "Current table is #{@table_name}"
    end

    puts
  end

  def table_listing
    table.each do |arr|
      puts "#{arr[0]}#{arr[1].any? ? " :- #{arr[1].map { |part| part.to_s }.join(' & ')}" : ''}."
    end

    puts
  end

  def table
    @table[@table_name] ||= []
  end

  def deep_clone(obj)
    if obj.is_a? Array
      obj.map { |o| deep_clone(o) }
    elsif obj.is_a? Hash
      ret = {}
      obj.each { |k, v| ret[k] = deep_clone(v) }
      ret
    elsif obj.is_a? Fact
      Fact.new(obj.name, deep_clone(obj.variables))
    else
      obj
    end
  end

  def file_read(name)
    ret = []

    remainder = ''

    File.foreach(name).with_index do |line, line_num|
      line = line.to_s.strip
      if line.size == 0
        ret.push('')
        remainder = ''
        next
      end

      if line.end_with?("\\")
        remainder += " #{line.chomp("\\")}"
        next
      end

      line = remainder + line

      ret.push(line.strip)
      remainder = ''
    end

    ret
  rescue
    nil
  end

  def clauses_match(h1, h2)
    return false unless h1.name == h2.name && h1.variables.count == h2.variables.count && h1.variables.uniq.count == h2.variables.uniq.count

    h1.variables.each.with_index do |var1, idx|
      var2 = h2.variables[idx]

      return false if var1.const? && var2.const? && (var1.class != var2.class || var1 != var2)
    end

    true
  end

  def replace_variable(var_name, literal, head)
    head.variables.each.with_index do |var1, idx|
      head.variables[idx] = literal if var1 == var_name
    end
  end

  def unique_var_names(arr, iteration)
    variables = []

    arr.each do |head|
      head[0].variables.each.with_index do |var_name1, i1|
        next if var_name1.const? || variables.include?(var_name1)

        @vari += 1
        new_var_name = "%#{@vari}"
        variables.push(var_name1)

        head[0].variables.each.with_index do |var_name2, i2|
          head[0].variables[i2] = new_var_name if var_name1 == var_name2
        end
      end
    end

    arr
  end

  def substitute_variables(solution, removed_clause, new_clauses)
    new_clauses = new_clauses.flatten

    new_clauses[0].variables.each.with_index do |var_name1, i1|
      var_name2 = removed_clause.variables[i1]

      if var_name1.const? && !var_name2.const?
        # Replace variable in solution
        solution.map { |l| l[0] }.each do |clause|
          replace_variable(var_name2, var_name1, clause)
        end
      elsif !var_name1.const? && var_name2.const?
        # Replace variable in new_clauses
        new_clauses.each do |clause|
          replace_variable(var_name1, var_name2, clause)
        end
      elsif !var_name1.const? && !var_name2.const?
        # Replace variable in new_clauses
        new_clauses.each do |clause|
          replace_variable(var_name1, var_name2, clause)
        end
      end
    end

    new_clauses
  end

  def search(head, stop_early)
    @vari = 0
    iteration = 0

    solution_set = [unique_var_names([[deep_clone(head), false]], iteration)]

    while iteration < @iteration_limit
      iteration += 1

      if @debug
        puts "Iteration #{iteration}"
        solution_set.each.with_index do |solution, idx|
          puts "  Solution #{idx + 1}"
          solution.each do |head|
            puts "    #{head[1] ? '*' : ''}#{head[0].format(false)}."
          end
        end
      end

      anything_expanded = false

      first_solution_idx = solution_set.find_index do |solution|
        solution.any? do |solution_clause|
          !solution_clause[1]
        end
      end

      if first_solution_idx.nil? || (stop_early && first_solution_idx > 0)
        successful_solutions = solution_set.select do |solution|
          !solution.any? do |solution_clause|
            solution_clause[0].variables.any? { |v| !v.const? }
          end
        end

        successful_solutions = [successful_solutions[0]] if stop_early

        return successful_solutions.map { |sol| sol[0][0] }
      end

      first_solution = solution_set[first_solution_idx]

      first_solution_clause_idx = first_solution.find_index do |solution_clause|
        !solution_clause[1]
      end
      first_solution_clause = first_solution[first_solution_clause_idx]

      unless first_solution_clause
        raise 'Unexpected error 2'
      end

      head = first_solution_clause[0]

      matching_clauses = table.select do |table_clause|
        clauses_match(table_clause[0], head)
      end

      first_solution_clause[1] = true

      if matching_clauses.any?
        anything_expanded = true

        matching_clauses.each do |clause|
          new_solution = deep_clone(first_solution)

          new_clauses = substitute_variables(new_solution, first_solution_clause[0], deep_clone(clause))

          new_clauses.each.with_index do |line, idx|
            next if idx == 0

            new_solution.push([line, false])
          end

          solution_set.push(new_solution)
        end

        solution_set[first_solution_idx] = nil
        solution_set = solution_set.compact

        next
      end

      unless anything_expanded
        solution_set = solution_set - first_solution

        unless solution_set.any?
          raise 'Unexpected error 3'
        end
      end
    end

    []
  end

  def equal_bodies(arr1, arr2)
    return false if arr1.count != arr2.count

    arr1.each.with_index do |val, idx|
      return false unless arr2[idx].eql?(val)
    end

    true
  end

  def table_add_clause(head, body, warn_if_exists)
    exists = false

    table.each do |arr|
      table_head = arr[0]
      table_body = arr[1]

      if table_head.eql?(head) && equal_bodies(table_body, body)
        puts 'Clause already exists' if warn_if_exists
        return
      end
    end

    table.push([head, body])
  end

  def err(msg, detail = nil)
    if detail && detail.size > 0
      puts "#{msg}\n    #{detail}"
    else
      puts msg
    end

    if @interactive
      puts
    else
      exit(1)
    end
  end
end

interpreter = DakiLangInterpreter.new
enter_interactive = false

ARGV.each.with_index do |command|
  if command == '-h' || command == '--help'
    interpreter.print_help
    exit(0)
  end

  if command == '-v' || command == '--version'
    interpreter.print_version
    exit(0)
  end

  if command == '-i' || command == '--interactive'
    enter_interactive = true
  end
end

ARGV.each.with_index do |command, idx|
  if command == '-c' || command == '--command'
    interpreter.consult_file(ARGV[idx + 1])
  end
end

if enter_interactive
  interpreter.enter_interactive_mode
end
