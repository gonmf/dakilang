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

  def parse_functor_tree(text)
    or_parts = text.split('|').map(&:strip)

    if or_parts.count > 1
      return OpenStruct.new(
        operator: '|',
        functors: or_parts.map { |part| parse_functor_tree(part) }
      )
    end

    and_parts = text.split('&').map(&:strip)

    if and_parts.count > 1
      return OpenStruct.new(
        operator: '&',
        functors: and_parts.map { |part| parse_functor_tree(part) }
      )
    end

    OpenStruct.new(
      operator: nil,
      functors: [parse_functor(text)]
    )
  end

  def consult_line(text)
    text = text.chomp('.')

    parts = text.split(' :- ')
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
