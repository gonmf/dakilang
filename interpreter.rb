require 'ostruct'
require 'pry'

table = []

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

  and_parts = body.split('&')

  and_parts.map { |part| parse_head(part) }
end

def format_head(head)
  "#{head.name}(#{head.variables.join(', ')})"
end

def const?(str)
  chr = str[0]

  (chr >= '0' && chr < '9') || (chr >= 'a' && chr < 'z')
end

def heads_match(h1, h2)
  return false unless h1.name == h2.name && h1.variables.count == h2.variables.count

  h1.variables.each.with_index do |var1, idx|
    var2 = h2.variables[idx]

    return false if const?(var1) && const?(var2) && var1 != var2
    return false if !const?(var1) && !const?(var2)
  end

  true
end

def head_search(table, head)
  solutions = []

  table.each do |arr|
    if heads_match(arr[0], head)
      solutions.push(arr[0])
    end
  end
end

def rules_can_match(lookup, head)
  return false unless lookup.name == head.name && lookup.variables.count == head.variables.count

  lookup.variables.each.with_index do |name, idx|
    other_name = head.variables[idx]
    return false if const?(name) && const?(other_name) && name != other_name
  end

  true
end

def replace_body_part(table, head, body, replacement)
  head = deep_clone(head)
  body = deep_clone(body)

  replacement.variables.each.with_index do |name, idx|
    next unless const?(name)

    body.each do |body_part|
      next unless body_part.name == replacement.name

      body_part.variables.each.with_index do |var_name, i1|
        if !const?(var_name) && i1 == idx
          # Replace all instances of variable

          head.variables.each.with_index do |other_name, i|
            head.variables[i] = name if other_name == var_name
          end

          body.each do |bp|
            bp.variables.each.with_index do |other_name, i|
              bp.variables[i] = name if other_name == var_name
            end
          end
        end
      end
    end
  end

  [head, body]
end

def expand_rule(table, lookup, head, body)
  # puts "#{format_head(lookup)} ~ #{format_head(head)} :- #{body.map { |b| format_head(b) }.join(' & ')}"
  solutions = []

  lookup.variables.each.with_index do |name, idx|
    other_name = head.variables[idx]

    next if const?(name) == const?(other_name)

    if const?(name)
      old_variable_name = head.variables[idx]
      new_variable_name = name
      head.variables[idx] = new_variable_name
    else
      old_variable_name = lookup.variables[idx]
      new_variable_name = head.variables[idx]
      lookup.variables[idx] = new_variable_name
    end

    body.each do |tuple|
      tuple.variables.each.with_index do |n, i|
        tuple.variables[i] = new_variable_name if n == old_variable_name
      end
    end
  end

  if body.any?
    partial_solutions = body.map { |bh| recursive_search(table, bh) }.flatten

    return partial_solutions.map { |ps| replace_body_part(table, head, body, ps).first }
  end

  if lookup.variables.any? { |name| !const?(name) }
    []
  else
    [lookup]
  end
end

def recursive_search(table, lookup)
  # puts "search #{format_head(lookup)}"
  solutions = []

  table.each do |arr|
    head = deep_clone(arr[0])
    body = deep_clone(arr[1])

    if rules_can_match(lookup, head)
      solutions += expand_rule(table, deep_clone(lookup), head, body)
    end
  end

  solutions
end

def consult_line(table, text)
  puts "> #{text}"

  if text == 'listing'
    table.each do |arr|
      puts "#{format_head(arr[0])}#{arr[1].any? ? " :- #{arr[1].map { |part| format_head(part) }.join(' & ')}" : ''}."
    end
  elsif text.chars.last == '.'
    text = text.tr(' ', '').chomp('.')

    parts = text.split(':-')
    raise "Syntax error at #{text}" if parts.count > 2

    head, body = parts.first(2)

    head = parse_head(head)
    body = parse_body(body)

    # head = parse_functor(head)
    # body = parse_functor_tree(body) if body

    table.push([head, body])
  elsif text.chars.last == '?'
    text = text.tr(' ', '').chomp('?')

    parts = text.split(':-')
    raise "Syntax error at #{text}" if parts.count > 2

    head = parts.first

    head = parse_head(head)

    solutions = recursive_search(table, head)

    if solutions.any?
      solutions.each do |arr1|
        puts "#{format_head(arr1)}."
      end
    else
      puts 'No solution'
    end
  end
end

file_read('db.pl').each do |line|
  consult_line(table, line)
end
