[![Build Status](https://travis-ci.org/gonmf/dakilang.svg?branch=master)](https://travis-ci.org/gonmf/dakilang)

# Daki language Ruby interpreter

Daki is a small computer programming language influenced by Prolog and Datalog. [Read all about it.](https://macro.win/dakilang/).

For fast prototyping and iteration, this first interpreter is written in Ruby.

## Installation

You will only require a not-too-old Ruby binary.

## Instructions

The Daki interpreter can be used both in interactive and non-interactive mode. In non-interactive mode, the interpreter input, read from files, is also outputted so as to mimic what would appear on a terminal on interactive mode.

In non-interactive mode, the interpreter reads one or more text files in sequence, and interpretes each line fully before advancing. A line can change the global state, which consists of logical assertions.

To launch the interpreter in interactive mode, use the `-i` flag:

```sh
./dakilang -i
```

In non-interactive mode a syntax error will end the program, whereas nothing is stopped in interactive mode, so give it a go in interactive mode until you have a good grasp of the syntax.

To launch the interpreter in non-interactive mode, use `-c` with the file path to be executed:

```sh
./dakilang -c examples/example1.dl
```

You can mix the modes, you can start the interpreter by including - _consulting_ - one or more files, and afterwards switching to interactive mode:

```sh
./dakilang -i -c examples/example1.dl -c examples/example2.dl
```

Switching to interactive mode is always performed only after every consulted file is interpreted, in order.

### Options

The full list of command line options are:

Option | Description
------ | -----------
-h, --help | Print out the program manual and exit
-v, --version | Print out the program name and version, and exit
-c, --consult | Read file with path F and interpret each line
-i, --interactive | Activate interactive mode after finishing consulting all files
-d, --debug | Activate debug mode, which shows the output of the output of clause parsing and a trace of the query solver
-t, --time | Changes the default query timeout time; N is a floating point value in seconds
--disable-colors | Disable the use of colors in the interpreter's output

## Tests

The tests are still under heavy development.

Some tests, interpreter independent, are ran using:

```bash
./test_interpreter.sh
```

Other, parser specific tests for this interpreter, are ran with:

```bash
./test_parser.sh
```

## Future work

- Support parenthesizing clause tails, with mixed _and_ and _or_ relationships
