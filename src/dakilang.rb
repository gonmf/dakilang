# frozen_string_literal: true

require_relative 'interpreter'

interpreter = DakiLang::Interpreter.new
enter_interactive = false
argv = ARGV.dup

if argv.empty?
  puts 'Nothing to do. Use --help to learn how to use this program.'
  puts
  exit(1)
end

argv.each.with_index do |command, idx|
  if command == '-h' || command == '--help'
    puts 'USE'
    puts '    ./dakilang [OPTIONS]'
    puts
    puts 'OPTIONS'
    puts '    -h, --help                 # Print out the program manual and exit'
    puts '    -v, --version              # Print out the program name and version, and exit'
    puts '    -c file, --consult file    # Read file with path "file" and interpret each line'
    puts '    -i, --interactive          # Activate interactive mode after finishing consulting all files'
    puts '    -d, --debug                # Activate debug mode, which shows the output of the output of clause parsing and a trace of the query solver'
    puts '    -t seconds, --time seconds # Changes the default query timeout time; "seconds" is a floating point value in seconds'
    puts '    --disable-colors           # Disable use of terminal colors in program output'
    puts
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

  if command == '--disable-colors'
    interpreter.color_output = false
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
