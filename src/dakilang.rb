# frozen_string_literal: true

require_relative 'interpreter'

interpreter = DakiLang::Interpreter.new
enter_interactive = false
argv = ARGV.dup

if argv.empty?
  interpreter.print_help
  exit(0)
end

argv.each.with_index do |command, idx|
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
    argv[idx] = nil
  end

  if command == '-i' || command == '--interactive'
    enter_interactive = true
    argv[idx] = nil
  end
end

argv = argv.compact

argv.each.with_index do |command, idx|
  next if command.nil?

  if command == '-t' || command == '--time'
    new_time = argv[idx + 1].to_f

    if argv[idx + 1] && new_time > 0
      interpreter.search_time_limit = new_time
      argv[idx] = nil
      argv[idx + 1] = nil
    else
      puts "Illegal time limit argument #{argv[idx + 1]}"
      exit(1)
    end
  end
end

argv = argv.compact
to_consult = []

argv.each.with_index do |command, idx|
  next if command.nil?

  if command == '-c' || command == '--command'
    to_consult.push(argv[idx + 1])
    argv[idx] = nil
    argv[idx + 1] = nil
  end
end

if argv.compact.any?
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
