require 'ostruct'
require 'pry'


class Interpreter
  attr_accessor :clause_database

  def initialize
    self.clause_database = {}
  end

  def parse_functor(text)
    parts = text.split('(').map(&:strip)
    raise "Syntax error at #{text}" if parts.count != 2

    name = parts[0]
    parts = parts[1].split(')').map(&:strip)
    raise "Syntax error at #{text}" if parts.count != 1

    args = parts[0].split(',').map(&:strip)

    OpenStruct.new(
      name: "#{name}/#{args.count}",
      vars: args
    )
  end

  def select_text_until_brace(text, i)
    initial_i = i

    while i < text.size
      return [text[initial_i, i + 1 - initial_i], i + 1] if text[i] == ')'

      i += 1
    end

    nil
  end

  def parse_functor_tree(text)
    tree, _ = parse_functor_tree_recursive(text, 0, false)

    tree
  end

  def parse_functor_tree_recursive(text, i, needs_end_brace)
    # ... :- ((a(A), b(C, D)); c(X)).
    relation = nil
    relations = 0
    functors = []

    while i < text.size
      if text[i] == '('
        subfunctor, new_i = parse_functor_tree_recursive(text, i + 1, true)
        functors.push(subfunctor)
        i = new_i
        next
      end

      if text[i] == ')'
        if !needs_end_brace
          raise "Syntax error parsing #{text}: unexpected character #{text[i]}"
        end

        raise "Syntax error parsing #{text}: empty braces" if functors.none?

        needs_end_brace = false
        break
      end

      if text[i] >= 'a' && text[i] <= 'z'
        subtext, new_i = select_text_until_brace(text, i)
        raise "Syntax error parsing #{text}" if subtext.nil?

        functor = parse_functor(subtext)
        functors.push(functor)
        i = new_i
        next
      end

      if text[i] == '&' || text[i] == '|'
        if relation.nil?
          relation = text[i]
        elsif relation != text[i]
          raise "Syntax error parsing #{text}: mixing operators without braces"
        end

        relations += 1
        i += 1
        next
      end

      if text[i] == ' ' || text[i] == "\n" || text[i] == "\t" || text[i] == "\r"
        i += 1
        next
      end

      raise "Syntax error parsing #{text}: unexpected character '#{text[i]}'"
    end

    if needs_end_brace
      raise "Syntax error parsing #{text}: braces not closed"
    end

    if relations + 1 != functors.count
      raise "Syntax error parsing #{text}: unfinished clause"
    end

    [OpenStruct.new(operator: relation, functors: functors), i + 1]
  end

  def consult_line(text)
    text = text.chomp('.')

    parts = text.split(':-')
    raise "Syntax error at #{text}" if parts.count > 2

    head, body = parts.first(2)

    head = parse_functor(head)
    body = parse_functor_tree(body) if body

    clause = OpenStruct.new(
      head: head,
      body: body
    )

    self.clause_database[head.name] ||= []
    self.clause_database[head.name].push(clause)
     clause
  end

  def interactive_mode
    raise 'Not implemented error'
  end

  def read_file(name)
    ret = []

    remainder = ''

    File.foreach(name).with_index do |line, line_num|
      line = line.to_s.strip.split('%').first.to_s.strip

      next if line.size == 0

      if !line.end_with?('.')
        remainder += " #{line}"
        next
      end

      ret.push("#{remainder} #{line}".strip)
      remainder = ''
    end

    raise "Syntax error at #{remainder}" if remainder.size > 0

    ret
  end

  def consult_file(name)
    read_file(name).each do |line|
      consult_line(line)
    end
  end

  def eval_file(name)
    raise 'Not implemented error'
  end

  def start
    ARGV.each_slice(2) do |option, filename|
      raise "Program argument error near #{option}" unless filename

      if option == '--consult'
        consult_file(filename)
      elsif option == '--eval'
        eval_file(filename)
      else
        raise "Program argument error near #{option}"
      end
    end

    puts self.clause_database

    # interactive_mode
  end
end

Interpreter.new.start
