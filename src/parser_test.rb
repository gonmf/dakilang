# frozen_string_literal: true

require_relative 'interpreter'

interpreter = DakiLang::Interpreter.new

expected = File.read('tests/0_parser_output').split("\n").map(&:strip)

failed = false

File.foreach('tests/0_parser_input').with_index do |line, idx|
  line = line.strip
  next if line.empty?

  parsed = interpreter.debug_tokenizer(line)&.tr("\n\r", '')&.tr("\t", ' ')&.strip
  # puts parsed

  if parsed != expected[idx]
    failed = true
    puts "Mismatch on line #{idx + 1}\n  #{parsed}\n  #{expected[idx] || 'N/A'}"
    puts
  end
end

if failed
  puts 'Parser tests failed'
  exit(1)
else
  puts 'Parser tests passed'
end
