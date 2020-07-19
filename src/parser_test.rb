# frozen_string_literal: true

require_relative 'interpreter'

interpreter = DakiLang::Interpreter.new

puts 'Tokenizer tests'

failed1 = false
expected = File.read('tests/0_tokenizer_output').split("\n").map(&:strip)

File.foreach('tests/0_parser_input').with_index do |line, idx|
  line = line.strip
  next if line.empty?

  parsed = interpreter.debug_tokenizer(line)&.tr("\n\r", '')&.tr("\t", ' ')&.strip
  # puts parsed

  if parsed != expected[idx]
    failed1 = true
    puts "  Mismatch on line #{idx + 1}\n    #{parsed}\n    #{expected[idx] || 'N/A'}"
  end
end

if failed1
  puts 'Failed'
else
  puts 'Passed'
end

###################################################################################################

puts 'Parser tests'

failed2 = false
expected = File.read('tests/0_parser_output').split("\n").map(&:strip)

File.foreach('tests/0_parser_input').with_index do |line, idx|
  line = line.strip
  next if line.empty?

  parsed = interpreter.debug_parser(line)&.tr("\n\r", '')&.tr("\t", ' ')&.strip
  # puts parsed

  if parsed != expected[idx]
    failed2 = true
    puts "  Mismatch on line #{idx + 1}\n    #{parsed}\n    #{expected[idx] || 'N/A'}"
  end
end

if failed2
  puts 'Failed'
else
  puts 'Passed'
end

if failed1 || failed2
  exit(1)
end
