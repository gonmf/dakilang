# Daki Language Interpreter

Daki is a small computer programming language similar to Prolog and Datalog. This is it's first version definition, with accompanying language interpreter. The language features are still subject to fast change.

![Dakilang mascot](/img/mascot.jpeg)

_Image courtesy of Maria Teresa C._

Daki is a declarative and logic language based on Horn clauses, aimed at solving problems via deduction. This project implements a stable, iterative and space bound algorithm of unification of free variables, in depth-first search.

**For now the reference interpreter will be implemented in Ruby for fast prototyping and iteration.**

Regardless of your familiarity with Prolog or Datalog, Daki language has significant differences from both. It is also a work in progress. For this reason I have compiled the following short language definition, in the form of a tutorial with examples.

## Tutorial

Daki can be used both in interactive and non-interactive mode. In non-interactive mode, the interpreter input, read from files, is also outputted so as to mimic what would appear on a terminal on interactive mode.

In non-interactive mode, the interpreter reads one or more text files in sequence, and interpretes each line fully before advancing. A line can change the global state, which consists of logical assertions.

A Daki language text file can contain five types of instructions:

1. Comments
2. New declarations
3. Queries
4. Declarations to be removed
5. Built-in commands

**Comments** start with the `%` character, and everything after this character is ignored.

```
> % I am a comment
>
> func('john', 'mary', 1). % I am a comment too
```

**New declarations** add what is called a _clause_ to a global table of clauses. A clause is composed of a head declaration and an optional tail, separated by the characters `:-`.

```
> parent('john', 'emily').
> grandparent(A, B) :- parent(A, C), parent(C, B).
```

Clauses are always terminated by a dot `.`. If they are declared with a tail, the tail must be evaluated true for the head to also match.

In accordance with other logic languages, the `,` character is used to denote logical AND. You can also use the character `;` to denote logical OR, but notice these are equivalent:

```
> fact(x) :- reason1(x); reason2(x).
> % is the same as
> fact(x) :- reason1(x).
> fact(x) :- reason2(x).
```

In fact the second form is exactly how they are saved in the global table. If some of the broken down OR clauses already exist they are ignored without raising a warning. Keep this in mind when removing declarations.

The elements of clauses always have open brackets and are declared with one or more strings. Those strings can be
constants - with a specific data type - or variables.

The Daki data types are strings ('daki'), integers (42) and floating point numbers (3.14). Constant types are not automatically coerced, for example:

```
> value('1').
> value(1).
> value(1.0).
>
> value('1')?
value('1').
> value(1)?
value(1).
> value(1.000)?
value(1.0).
```

Besides these limitations, variables names and string literals can contain any character not reserved by the language, like hyphens and underscores. String literals can be enclosed both by the characters `'` and `"`, and both of these can be escaped with `\`. `\` itself is escaped with `\\`. You can write `"'"` and `'"'`, but need to escape it if the character is used for delimiting the string: `"\""` and `'\''`.

A **query** has a similar format to a tailless clause, but is ended with a `?` character instead of `.`. Upon being input, it starts a search for all its solutions using the global table of clauses.

The search will try to find solutions for which the original query has no outstanding variables, showing the constants that have filled it.

The interpreter will print out every solution found or return `No solution`.

```
> grandparent("john", someone)?
grandparent('john', 'mary').
```

These queries that return all the solutions are called _full queries_. If the clause is ended with a `!` instead of `?`, a _short query_ is performed. A short query terminates as soon as the first solution is found. They only return one answer, or `No solution`:

```
> month('January').
> month('February').
> month('March').
> month(name)!
month('January').
```

**Declarations to be removed** are declared with the same name, constant values and tail of the original clause declarations. The variables can have different names.

Declaring two clauses with the same name, constants and tail is impossible, and will raise a warning; similarly trying to remove from the global table a clause that does not exist will also raise a warning.

To remove a clause end your command with the `~` character.

```
> grandparent("john", Var) :- other(Var, Var).
> grandparent("john", Var) :- other(Var, Var).
Clause already exists
> grandparent("john", X) :- other(X, X)~
Clause removed
> grandparent("john", X) :- other(X, X)~
Clause not found
```

Finally, **built-in commands** allow for some specific operations related to the interpreter and global table themselves. These are:

- _quit_ / _exit_ - Stop execution and exit the interpreter if in interactive mode. Only stops processing the current file is in non-interactive mode.
- _select_table N_ - Changes the global table currently in use. By default, table 0 is active. Passing no argument prints the current table number.
- _listing_ - Prints all rules kept in the current global table.
- _consult_ - Read and interpret a Daki language file.
- _version_ - Print version information.
- _help_ - Print help information.

Built-in commands are executed without any trailing `.` or `?`.

The following characters are reserved and should only appear outside of string constants for their specific uses: `'`, `"`, `%`, `,`, `(`, `)`, `;`, `.`, `?`, `~` and `\`. The specific sequence `:-` is also reserved. All others can be used in names of clause terms, variables and constants. All whitespace is ignored.

## Manual

You will need to have a Ruby executable installed.

To launch the interpreter in non-interactive mode, execute:

```sh
./dakilang -c example1.txt
```

To launch the interpreter in interactive mode, add the -i flag:

```sh
./dakilang -i
```

You can mix the modes, you can start the interpreter by including - _consulting_ - one or more files, and afterwards switching to interactive mode:

```sh
./dakilang -i -c example1.txt -c example2.txt
```

Switching to interactive mode is always performed only after every consulted file is interpreted, in order.

The commands -h and -v are also available to show the help and version information. All commands have their long form counterparts: --consult, --interactive, --help and --version.

## FIXME - Known Bugs

- Issue with query clause without variables, only constants

## TODO - Core features missing implementation

- Built-in operators for string and numeric types
- Test suite
- Help built-in
- List data type, operators and unification of list elements (head|tail)
