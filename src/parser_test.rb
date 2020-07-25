# frozen_string_literal: true

require_relative 'interpreter'

interpreter = DakiLang::Interpreter.new

failed = false
expected = File.read('tests/0_parser_output').split("\n").map(&:strip)

File.foreach('tests/0_parser_input').with_index do |line, idx|
  line = line.strip
  next if line.empty?

  parsed = interpreter.debug_parser(line)&.tr("\n\r", '')&.tr("\t", ' ')&.strip
  # puts parsed

  if parsed != expected[idx]
    failed = true
    puts "  Mismatch on line #{idx + 1}\n    Input: #{line}\n      Got:      #{parsed}\n      Expected: #{expected[idx] || 'N/A'}"
  end
end

if failed
  puts 'Failed'
  exit(1)
else
  puts 'Passed'
end
