require 'ostruct'
require 'pry'

class DakiLangInterpreter
  def initialize
    @iteration_limit = 1000
    @debug = false
    @table = {}
    @table_nr = 0
  end

  def consult(filename)
    print_version

    file_read(filename).each do |line|
      consult_line(line)
    end
  end

  private

  def table
    @table[@table_nr] ||= []
  end

  def print_version
    puts 'dakilang 0.1'
    puts
  end

  def deep_clone(obj)
    if obj.is_a? Array
      obj.map { |o| deep_clone(o) }
    elsif obj.is_a? Hash
      ret = {}
      obj.each { |k, v| ret[k] = deep_clone(v) }
      ret
    elsif obj.is_a? OpenStruct
      ret = {}
      obj.to_h.each { |k, v| ret[k] = deep_clone(v) }
      OpenStruct.new(ret)
    else
      obj
    end
  end

  def file_read(name)
    ret = []

    remainder = ''

    File.foreach(name).with_index do |line, line_num|
      line = line.to_s.strip.split('%').first.to_s.strip

      next if line.size == 0

      if !line.end_with?('.') && !line.end_with?('?') && !line.end_with?('~') && line != 'listing'
        remainder += " #{line}"
        next
      end

      ret.push("#{remainder} #{line}".strip)
      remainder = ''
    end

    raise "Syntax error at #{remainder}" if remainder.size > 0

    ret
  end

  def parse_head(head)
    name, rest = head.split('(')
    variables, _ = rest.split(')')
    variables = variables.split(',')

    OpenStruct.new(name: name, variables: variables)
  end

  def parse_body(body)
    return [] if body.nil? || body.empty?

    and_parts = body.split('&') # logical and

    and_parts.map { |part| parse_head(part) }
  end

  def format_head(head)
    "#{head.name}(#{head.variables.join(', ')})"
  end

  def const?(str)
    chr = str[0]

    (chr >= '0' && chr < '9') || (chr >= 'a' && chr < 'z')
  end

  def clauses_match(h1, h2)
    return false unless h1.name == h2.name && h1.variables.count == h2.variables.count && h1.variables.uniq.count == h2.variables.uniq.count

    h1.variables.each.with_index do |var1, idx|
      var2 = h2.variables[idx]

      return false if const?(var1) && const?(var2) && var1 != var2
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
        next if const?(var_name1) || variables.include?(var_name1)

        @vari += 1
        new_var_name = "%#{@vari.to_s(16)}"
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

      if const?(var_name1) && !const?(var_name2)
        # Replace variable in solution
        solution.map { |l| l[0] }.each do |clause|
          replace_variable(var_name2, var_name1, clause)
        end
      elsif !const?(var_name1) && const?(var_name2)
        # Replace variable in new_clauses
        new_clauses.each do |clause|
          replace_variable(var_name1, var_name2, clause)
        end
      elsif !const?(var_name1) && !const?(var_name2)
        # Replace variable in new_clauses
        new_clauses.each do |clause|
          replace_variable(var_name1, var_name2, clause)
        end
      end
    end

    new_clauses
  end

  def search(head)
    @vari = 0
    iteration = 0

    solution_set = [unique_var_names([[deep_clone(head), false]], iteration)]

    while iteration < @iteration_limit
      iteration += 1
      puts "Iteration #{iteration}" if @debug
      solution_set.each.with_index do |solution, idx|
        puts "  Solution #{idx + 1}" if @debug
        solution.each do |head|
          puts "    #{head[1] ? '*' : ''}#{format_head(head[0])}." if @debug
        end
      end

      anything_expanded = false

      first_solution_idx = solution_set.find_index do |solution|
        solution.any? do |solution_clause|
          !solution_clause[1]
        end
      end

      if first_solution_idx.nil?
        successful_solutions = solution_set.select do |solution|
          !solution.any? do |solution_clause|
            solution_clause[0].variables.any? { |v| !const?(v) }
          end
        end

        return successful_solutions.map { |sol| sol[0][0] }
      end

      first_solution = solution_set[first_solution_idx]

      first_solution_clause_idx = first_solution.find_index do |solution_clause|
        !solution_clause[1]
      end
      first_solution_clause = first_solution[first_solution_clause_idx]

      unless first_solution_clause
        puts 'Error 1'
        break
      end

      head = first_solution_clause[0]

      matching_clauses = table.select do |table_clause|
        clauses_match(table_clause[0], head)
      end

      first_solution_clause[1] = true

      if matching_clauses.any?
        anything_expanded = true

        new_solutions = matching_clauses.map do |clause|
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
          puts 'Error 2'
          break
        end
      end
    end

    []
  end

  def consult_line(text)
    puts "> #{text}"

    if text == 'listing'
      table.each do |arr|
        puts "#{format_head(arr[0])}#{arr[1].any? ? " :- #{arr[1].map { |part| format_head(part) }.join(' & ')}" : ''}."
      end

      puts
    elsif text.chars.last == '.'
      text = text.tr(' ', '').chomp('.')

      parts = text.split(':-')
      raise "Syntax error at #{text}" if parts.count > 2

      head, body = parts.first(2)

      head = parse_head(head)
      body = parse_body(body)

      table.push([head, body])
    elsif text.chars.last == '?'
      text = text.tr(' ', '').chomp('?')

      parts = text.split(':-')
      raise "Syntax error at #{text}" if parts.count > 2

      head = parts.first

      head = parse_head(head)

      solutions = search(head)

      if solutions.any?
        solutions.each do |arr1|
          puts "#{format_head(arr1)}."
        end
      else
        puts 'No solution'
      end

      puts
    end
  end
end

interpreter = DakiLangInterpreter.new

interpreter.consult('db.dl')
