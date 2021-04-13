# frozen_string_literal: true

begin
  require 'readline'

  # Just for development
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
    include Parser
    include OperatorClauses

    OPERATOR_CLAUSES = [
      # Arithmetic
      ['add',        3,     -1], # Variable arity
      ['sub',        3],
      ['mul',        3,     -1], # Variable arity
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
      ['eval',       3,     -1], # Variable arity
      # Equality and comparison
      ['eql',        3],
      ['neq',        3],
      ['max',        2,     -1], # Variable arity
      ['min',        2,     -1], # Variable arity
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
      ['concat',     3,     -1], # Variable arity
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
      ['print',      2,      3],
      ['time',       1,      2]
    ].freeze

    TYPE_COND_COMPAT = {
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
    }.freeze

    attr_accessor :search_time_limit, :color_output, :debug

    def initialize
      @search_time_limit = 3.0 # Seconds
      @color_output = true

      @table = {}
      @memo_tree = {}
      @to_memo = {}

      init_oper_clauses

      select_table('0', false)
    end

    def enter_interactive_mode
      @interactive = true

      loop do
        Readline
        line = Readline.readline('> ')&.strip
        exit(0) if line.nil?

        Readline::HISTORY.push(line) if line.size > 0

        run_commands([line], [])
      end
    end

    def consult_file(filename, consult_chain = [])
      if !filename || filename.size == 0
        puts red('File name is missing or invalid')
        puts
      elsif consult_chain.include?(filename)
        puts red('Circular file consult invocation detected')
        puts
      else
        contents = file_read(filename)

        if contents
          run_commands(contents, consult_chain + [filename])
        else
          puts red('File not found or cannot be read')
          puts
        end
      end
    end

    def debug_parser(text)
      instruction_type, clause_set = parser(text)

      clause_set && clause_to_s([instruction_type, clause_set])
    rescue ParserError => e
      e.to_s
    end

    def print_version
      puts "dakilang interpreter v#{VERSION}"
      puts
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
        elsif down_line == 'select_table' || down_line.start_with?('select_table ')
          select_table(line.split(' ')[1], true)
          next
        elsif down_line.start_with?('add_memo ')
          add_memo(line.split(' ')[1])
          next
        elsif down_line.start_with?('rem_memo ')
          rem_memo(line.split(' ')[1])
          next
        elsif down_line == 'list_memo'
          list_memo
          next
        elsif down_line == 'clear_memo'
          clear_memo
          next
        elsif down_line == 'listing'
          table_listing
          next
        elsif down_line.start_with?('consult ')
          consult_file(line.split(' ')[1], consult_chain)
          next
        elsif down_line.start_with?('retract ')
          retract_rule_by_index(line.split(' ')[1])
          next
        end

        begin
          instruction_type, clause_set = parser(line)
          next unless clause_set

          puts clause_to_s([instruction_type, clause_set]) if @debug

          case instruction_type
          when 'clause'
            add_rule(clause_set)
          when 'short_query'
            execute_query(clause_set.first, true)
          when 'full_query'
            execute_query(clause_set.first, false)
          when 'retract'
            retract_rule_by_declaration(clause_set)
          end
        rescue ParserError => e
          puts e

          if @interactive
            puts
          else
            exit(1)
          end
        end
      end
    end

    def add_rule(clause_set)
      head = clause_set[0][0]

      if head && oper_clause_matches?(head.name, head.arity)
        puts red('Built-in operator clause already exists')
        puts
        return
      end

      clause_set.each do |clause|
        table_add_clause(clause)
      end
    end

    def retract_rule_by_declaration(clause_set)
      head = clause_set[0][0]

      if head && oper_clause_matches?(head.name, head.arity)
        puts red('Built-in operator clause cannot be removed')
        puts
        return
      end

      clause_set.each do |clause|
        table_remove_clause(clause)
      end
    end

    def retract_rule_by_index(idx_str)
      idx = idx_str.to_i
      if idx.to_s != idx_str || idx < 0 || idx >= @table[@table_name].count
        puts red('Invalid clause index')
        puts
        return
      end

      @table[@table_name][idx] = nil
      @table[@table_name] = @table[@table_name].compact
    end

    def execute_query(facts, stop_early)
      head = facts.first

      solutions = search(head, stop_early)

      if solutions.nil?
        puts red('Search timeout')
      elsif solutions.any?
        printed_any = false

        solutions.uniq.each do |solution|
          printed = Set.new

          head.arg_list.each.with_index do |arg, idx|
            next if arg.const? || arg.name[0] == '_'

            printed_any = true
            value = solution.arg_list[idx]
            text = "#{arg.name} = #{value}"

            if !printed.include?(text)
              printed.add(text)
              puts green(text)
            end
          end

          puts if printed_any
        end

        unless printed_any
          puts green('Yes')
          puts
        end
      else
        puts red('No')
        puts
      end
    end

    def green(str)
      color_output ? "\e[32m#{str}\e[0m" : str
    end

    def red(str)
      color_output ? "\e[31m#{str}\e[0m" : str
    end

    def add_memo(name)
      name = name.to_s

      n, arity, more = name.split('/')

      if name.size == 0 || !arity || more || arity != arity.to_i.to_s || arity.to_i < 1
        puts red('Clause name is invalid')
      elsif @to_memo[@table_name].include?(name)
        puts red('Clause is already being memoized')
      elsif oper_clause_matches?(n, arity)
        puts red('Cannot memoize built-in operator clause')
      else
        @to_memo[@table_name].add(name)
        puts green('OK')
      end

      puts
    end

    def rem_memo(name)
      if !name && name.size == 0
        puts red('Clause name is invalid')
      elsif @to_memo[@table_name].include?(name)
        @to_memo[@table_name].delete(name)
        @memo_tree[@table_name][name] = nil
        @memo_tree[@table_name] = @memo_tree[@table_name].compact
        puts green('OK')
      else
        puts red('Clause was not being memoized')
      end

      puts
    end

    def list_memo
      @to_memo[@table_name].sort.each do |name|
        puts green(name)
      end

      puts
    end

    def clear_memo
      @memo_tree[@table_name] = {}
    end

    def all_chars?(str, chars)
      str.chars.all? { |c| chars.include?(c) }
    end

    def init_oper_clauses
      @operator_clauses = {}

      OPERATOR_CLAUSES.each do |clause|
        name, min_arity, max_arity = clause

        max_arity = if max_arity == -1
                      2_147_483_647
                    elsif max_arity
                      max_arity
                    else
                      min_arity
                    end

        @operator_clauses[name] = { min_arity: min_arity, max_arity: max_arity }
      end
    end

    def oper_clause_matches?(name, arity)
      clause = @operator_clauses[name]
      return false if clause.nil?

      clause[:min_arity] <= arity && arity <= clause[:max_arity]
    end

    def select_table(name, output)
      if name && name.size > 0
        @table_name = name

        @table[@table_name] ||= []
        @memo_tree[@table_name] ||= {}
        @to_memo[@table_name] ||= Set.new

        puts green("Table changed to #{@table_name}") if output
      else
        puts green("Current table is #{@table_name}") if output
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
        puts green("#{idx.to_s.rjust(indent)}: #{arr[0]}#{arr[1].any? ? " :- #{arr[1].join(', ')}" : ''}.#{arr[2] > 1 ? " (#{arr[2]})" : ''}")
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
              if !TYPE_COND_COMPAT[const.type][var3.condition_type] || !const.value.send(var3.condition, var3.condition_value)
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
              if !TYPE_COND_COMPAT[const.type][var3.condition_type] || !const.value.send(var3.condition, var3.condition_value)
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

    def replace_variable(var_name, replacement, head)
      head.arg_list.each.with_index do |var1, idx|
        if !var1.const? && var1.name == var_name
          head.arg_list[idx] = replacement
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
              replace_variable(var2.name, Literal.new(var1.value), arr[0])
            end
          end
        elsif var2.const?
          # Replace variable in new_clauses
          new_clauses.each do |clause|
            replace_variable(var1.name, Literal.new(var2.value), clause)
          end
        else
          # Replace variable in new_clauses
          new_clauses.each do |clause|
            replace_variable(var1.name, Variable.new(var2.name), clause)
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
            m = memoed_fact(memo[var], arguments)

            [var, m] if m
          else
            [var]
          end
        else
          nil
        end
      else
        arguments = arguments.slice(1, arguments.count)

        memo.each do |value, sol|
          se = memoed_fact(sol, arguments)

          return [value, se] if se
        end

        nil
      end
    end

    def search(head, stop_early)
      @vari = 0
      iteration = 0
      solution_set_hashes = Set.new
      time_limit = Time.now + @search_time_limit
      missing_declarations = Set.new

      dummy_head = Fact.new('0', deep_clone(head.arg_list))
      dummy_vars = (0...head.arg_list.size).map { |i| Variable.new(('A'.ord + i).chr) }
      dummy_clause = [Fact.new(dummy_head.name, dummy_vars), [Fact.new(head.name, dummy_vars)], 1]

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
              puts "    #{head1[1] ? '*' : ''}#{head1[0].to_s(true)}"
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

          if oper_clause_matches?(solution_clause[0].name, solution_clause[0].arity)
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
        if first_solution_clause_idx.nil?
          solution_set[first_solution_idx] = nil
          solution_set = solution_set.compact
          next
        end

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
          pruned_clauses = []

          matching_clauses.each.with_index do |clause, matching_clause_idx|
            new_solution = deep_clone(first_solution)
            clause = [clause[0], clause[1]].compact

            new_clauses = substitute_variables(new_solution, first_solution_clause[0], deep_clone(clause))

            impossible_solution = false
            prev_count = new_solution.count
            new_clauses.each.with_index do |line, idx|
              next if idx == 0

              if oper_clause_matches?(line.name, line.arity) || @table[@table_name].any? { |table_entry| table_entry[0].arity_name == line.arity_name }
                new_solution.push([line, false])
              else
                impossible_solution = true

                if !missing_declarations.include?(line.arity_name) && !@table[@table_name].map { |entry| entry[0].arity_name }.include?(line.arity_name)
                  missing_declarations.add(line.arity_name)
                  puts red("Declaration missing: #{line.arity_name}")
                end

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

            # Truncate solution to first clause and clauses still to be resolved
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

              if @debug && !kept
                pruned_clauses.push(rule[0].to_s)
              end

              kept
            end

            new_solution = unique_var_names(new_solution)

            # TODO: can performance be improved?
            new_solution_hash = new_solution.map { |l| l[0] }.hash

            unless solution_set_hashes.include?(new_solution_hash)
              solution_set_hashes.add(new_solution_hash)

              solution_set.push(new_solution)
            end
          end

          if @debug && pruned_clauses.any?
            puts '*** pruned'
            pruned_clauses.sort.uniq.each do |pruned_clause|
              puts "    #{pruned_clause}"
            end
          end
        end
      end

      nil # Timeout
    ensure
      @table[@table_name] = @table[@table_name].slice(1, @table[@table_name].size)
    end

    def table_add_clause(clause)
      @table[@table_name].each do |arr|
        table_head = arr[0]
        table_body = arr[1]

        if clauses_are_equal([table_head] + table_body, clause)
          arr[2] = arr[2] + 1
          return
        end
      end

      head, *body = clause
      @table[@table_name].push([head, body, 1])
    end

    def table_remove_clause(clause)
      @table[@table_name].each.with_index do |arr, arr_idx|
        table_head = arr[0]
        table_body = arr[1]

        if clauses_are_equal([table_head] + table_body, clause)
          arr[2] = arr[2] - 1

          if arr[2] == 0
            @table[@table_name][arr_idx] = nil
            @table[@table_name] = @table[@table_name].compact
          end

          return
        end
      end
    end

    def clauses_are_equal(clause1, clause2)
      return false if clause1.count != clause2.count

      clause1.each.with_index do |fact, idx|
        fact2 = clause2[idx]
        return false if fact.name != fact2.name || fact.arg_list.count != fact2.arg_list.count
      end

      # Check argument order and constants
      argument_id = 0
      arg_names = {}

      args1 = clause1.map { |fact| fact.arg_list }.flatten
      args1 = args1.map.with_index do |arg, idx|
        next "#{arg.type}:#{arg.hash}" if arg.const?

        if !arg_names[arg]
          arg_names[arg] = argument_id
          argument_id += 1
        end

        args1[idx] = arg_names[arg]
      end

      argument_id = 0
      arg_names = {}

      args2 = clause2.map { |fact| fact.arg_list }.flatten
      args2 = args2.map.with_index do |arg, idx|
        next "#{arg.type}:#{arg.hash}" if arg.const?

        if !arg_names[arg]
          arg_names[arg] = argument_id
          argument_id += 1
        end

        args2[idx] = arg_names[arg]
      end

      args1 == args2
    end
  end
end
