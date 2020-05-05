[![Build Status](https://travis-ci.org/gonmf/dakilang.svg?branch=master)](https://travis-ci.org/gonmf/dakilang)

# Daki Language Interpreter

Daki is a small computer programming language influenced by Prolog and Datalog. This is it's first version definition, with accompanying language interpreter. The language features are still subject to fast change.

![Dakilang mascot](/img/mascot.jpeg)

_Image courtesy of Maria Teresa C._

Daki is a declarative, logic, typed language based on Horn clauses, aimed at solving problems via deduction. This project implements a stable, iterative and space bound algorithm of unification of free variables, in depth-first search.

**For now the reference interpreter will be implemented in Ruby for fast prototyping and iteration.**

Regardless of your familiarity with Prolog or Datalog, Daki language has significant differences from both. It is also a work in progress. For this reason I have compiled the following short language definition, with examples.

## Contents

- [Language definition](#language-definition)
  - [Introduction](#introduction)
  - [Comments](#comments)
  - [Declarations](#declarations)
  - [Queries](#queries)
  - [Retractions](#retractions)
  - [Environment commands](#environment-commands)
  - [Operator clauses](#operator-clauses)
    - [Arithmetic operator clauses](#arithmetic-operator-clauses)
    - [Bitwise operator clauses](#bitwise-operator-clauses)
    - [Equality/order operator clauses](#equalityorder-operator-clauses)
    - [Type casting operator clauses](#type-casting-operator-clauses)
    - [String operator clauses](#string-operator-clauses)
    - [Other operator clauses](#other-operator-clauses)
  - [Clause conditions](#clause-conditions)
    - [Operators](#operators)
  - [Memoization](#memoization)
- [Interpreter](#interpreter-manual)
  - [Options](#options)
- [Future work](#future-work)

## Language definition

### Introduction

Daki can be used both in interactive and non-interactive mode. In non-interactive mode, the interpreter input, read from files, is also outputted so as to mimic what would appear on a terminal on interactive mode.

In non-interactive mode, the interpreter reads one or more text files in sequence, and interpretes each line fully before advancing. A line can change the global state, which consists of logical assertions.

A Daki language text file can contain five types of instructions:

1. Comments
2. New declarations
3. Queries
4. Declarations to be removed
5. Built-in commands

Each instruction must be in it's own line or lines - they cannot be mixed - except for inline comments at the end of another instruction.

### Comments

Comments start with the `%` character, and everything after this character is ignored by the interpreter.

```java
> % I am a comment
>
> fact('john', 'mary', 1). % I am a comment too
```

### Declarations

New declarations add what is called a _clause_ to the _global table of clauses_ (sometimes called database or knowledge base in other logic languages). A clause is composed of a head declaration and an optional tail, separated by the characters `:-`.

```java
> parent('john', 'emily').
> grandparent(A, B) :- parent(A, C) & parent(C, B).
```

Clauses are always terminated by a dot `.`. If they are declared with a tail, the tail must be evaluated true for the head to match. Clauses with a tail are called _rules_, while clauses without it are called _facts_.

In Daki, the tail dependencies order is not important. The `&` character is used to denote logical AND, and the `|` character logical OR. Notice how these are equivalent though:

```java
> rule(x) :- reason1(x) | reason2(x).
> % is the same as
> rule(x) :- reason1(x).
> rule(x) :- reason2(x).
```

In fact the second form is exactly how they are saved in the global table. If some of the broken down OR clauses already exist they are ignored without raising a warning. Keep this in mind when removing declarations.

The elements of clauses always have open brackets and are declared with one or more strings. Those strings can be
constants - with a specific data type - or variables.

The Daki data types are **string** (`'daki'`), **integer** (`42`) and **float**, for IEEE 754 floating point numbers (`3.14`). This document also uses the term _numeric_ to mean both integer and floating point values. Constant types are not automatically coerced or matched, for example:

```java
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

Integer literals can be specified in decimal, octal, hexadecimal or binary notation:

```java
> value(122).       % decimal
> value(0172).      % octal
> value(0x7a).      % hexadecimal
> value(0b1111010). % binary
```

String literals can be enclosed both by the characters `'` and `"`, and both of these can be escaped with `\`. `\` itself is escaped with `\\`. You can write `"'"` and `'"'`, but need to escape it if the character is used for delimiting the string: `"\""` and `'\''`. The character `\` is also used to denote line continuation - when placed at the end of a line, it is discarded and the line is join with the line bellow.

Variable names and clause names must start with a letter and be composed of letters, algarisms and underscores.

All whitespace outside of string constants is ignored.

### Queries

A query has a similar format to a tailless clause, but ends with a `?` character instead of `.`. Upon being input, it starts a search for all its solutions using the global table of clauses.

The search will try to find all solutions for which the original query has no outstanding variables, showing the constants that have filled it. When all variables of a clause are replaced, we say it has unified.

The interpreter will print out every solution found or return `No solution`.

```java
> grandparent("john", someone)?
grandparent('john', 'mary').

> grandparent("mary", someone)?
No solution
```

These queries that return all the solutions are called _full queries_. If the clause is ended with a `!` instead of `?`, a _short query_ is performed. A short query terminates as soon as the first solution is found. They only return one answer, or `No solution`:

```java
> month('January').
> month('February').
> month('March').
> month(name)!
month('January').
```

Queries have a time limit to be completed. If a query times out the interpreter prints the message `Search timeout`. A full query can timeout even after finding at least part of the solution.

Previously we said the order of tail clauses is not important, which is true for full queries. With short queries, the first solution found may be different depending on the order of the tail clauses. The interpreter algorithm, however, is stable: given the same definitions the result will be constant (aside from built-in clauses with side effects and interpreter/system differences).

### Retractions

You can remove a declaraction from the global table of clauses by declaring it again, with a final `~` instead of `.`. The clause must have the same name, constant values and tail of the original clause declaration. The variables can have different names.

Declaring two clauses with the same name, constants and tail is impossible, and will raise a warning; similarly trying to remove from the global table a clause that does not exist will also raise a warning.

```java
> grandparent("john", Var) :- other(Var, Var).
> grandparent("john", Var) :- other(Var, Var).
Clause already exists
> grandparent("john", X) :- other(X, X)~
Clause removed
> grandparent("john", X) :- other(X, X)~
Clause not found
```
### Environment commands

Finally, some built-in commands allow for operations related to the interpreter and global table themselves. These are:

Command | Description
------ | -----------
quit, exit | Stop execution and exit the interpreter if in interactive mode; only stops processing the current file is in non-interactive mode
select_table | Changes the global table currently in use; by default, table 0 is active; passing no argument prints the current table number
listing | Prints all clauses kept in the current global table
consult | Read and interpret a Daki language file; receives file path as an argument
version | Print version information
help | Print help information
add_memo | Add a clause name to the list of clauses to memoize (ex: `func/3`)
rem_memo | Remove a clause name to the list of clauses to memoize; clears the memory pertaining to that clause
list_memo | List all clause names of the memoization list
clear_memo | Clear all memory spent on clause memoization (does not clear the list of clauses to memoize)

These commands are executed without any trailing `.`, `?` or `!`, and are case-insensitive. The _memo_ commands are made clear in the [memoization](#memoization) section.

The language features up to here are the minimum required for a pure, logic-based, query-only language. For many real problems, however, this is not enough.

### Operator clauses

The Daki language also has __built-in clauses__, that unify with user-specified clauses and perform some form of calculation. To see why these are important, let's look at a practical example. In a language like Prolog, for instance, calculating a number of the Fibonacci sequence may look like:

```prolog
> fib(1, 1).
> fib(2, 1).
> fib(N, X) :- f1 = fib(N - 1, X1), f2 = fib(N - 2, X2), X is X1 + X2.
>
> fib(4, X)?
```

In Prolog we find arithmetic and conditional logic mixed with the clause itself. In the Daki language, however, we prefer to keep the clause format consistent even for these operations. We use instead what we call **operator clauses**:

Operator clauses are always unifiable only when the input variables are present, if any, and for performance they are always unified before user-defined clauses where possible.

In these tables, clause `add/3` means a clause named `add` with three arguments. The last variable is always the output, and the remaining the input variables. The descriptions sometimes use the term _InputN_ to name a specific variable N, counting from 1. The result of the operation is unified in the last argument.

#### Arithmetic operator clauses

_The inputs must be numeric to unify._

Clause | Description
------ | -----------
add/3 | Unifies with the result of the addition of the two inputs
sub/3 | Unifies with the result of the subtraction of Input1 with Input2
mul/3 | Unifies with the result of the multiplication of the two inputs
div/3 | Unifies with the result of the division of the two inputs; integer division is used if both inputs are integer
mod/3 | Unifies with the rest of the integer division of the two inputs
pow/3 | Unifies with the result ofInput1 to the power of Input2
sqrt/2 | Unifies with the result of the square root of Input
log/3 | Unifies with the logarithmic base Input2 of Input1
round/3 | Unifies with the rounded value of Input1 to Input2 decimal cases
trunc/2 | Unifies with the value of Input without decimal part
floor/2 | Unifies with the largest integer value that is less or equal to the input
ceil/2 | Unifies with the smallest integer value that is greater or equal to the input
abs/2 | Unifies with the absolute value of the input

#### Bitwise operator clauses

_The inputs must be of type Integer to unify._

Clause | Description
------ | -----------
bit_and/3 | Unifies with the bitwise AND of the two inputs
bit_or/3 | Unifies with the bitwise OR of the two inputs
bit_xor/3 | Unifies with the bitwise XOR of the two inputs
bit_neg/2 | Unifies with the bitwise inversion of the bits of the input
bit_shift_left/3 | Unifies with the left shifted value of Input1 by Input2
bit_shift_right/3 | Unifies with the right shifted value of Input1 by Input2

#### Equality/order operator clauses

_The inputs must be both numeric or both strings to unify._

Clause | Description
------ | -----------
eql/3 | Unifies if the values are equal; with the string literal `'yes'`
neq/3 | Unifies if the values are not equal; with the string literal `'yes'`
max/3 | Unifies with the maximum value between Input1 and Input2; if any of the inputs is a string, string comparison is used instead of numeric
min/3 | Unifies with the minimum value between Input1 and Input2; if any of the inputs is a string, string comparison is used instead of numeric
gt/3 | Unifies if Input1 is greater than Input2; if any of the inputs is a string, string comparison is used instead of numeric; unifies with the string literal `'yes'`
lt/3 | Unifies if Input1 is lower than Input2; if any of the inputs is a string, string comparison is used instead of numeric; unifies with the string literal `'yes'`
gte/3 | Unifies if Input1 is greater or equal to Input2; if any of the inputs is a string, string comparison is used instead of numeric; unifies with the string literal `'yes'`
lte/3 | Unifies if Input1 is lower or equal to Input2; if any of the inputs is a string, string comparison is used instead of numeric; unifies with the string literal `'yes'`

#### Type casting operator clauses

_The inputs must be of the correct data type to unify._

Clause | Description
------ | -----------
as_string/2 | Unifies with the text representation of the input (of any type)
as_string/3 | Unifies with the text representation of the first integer input, with the base specified by the second integer input
as_integer/2 | Unifies with the integer value of the input (of any type); will truncate floating point values
as_integer/3 | Unifies with the integer value of the first string input, with the base specified by the second integer input
as_float/2 | Unifies with the floating point value of the input (of any type)

#### String operator clauses

_The inputs must be of the correct data type to unify._

Clause | Description
------ | -----------
len/2 | Unifies with the number of characters of a string input
concat/3 | Unifies with the concatenation of two string inputs
slice/4 | Unifies with the remainder of a string Input1 starting at integer Input2 and ending at integer Input3
index/4 | Unifies with the integer position of string Input2 if found in string Input1, or `-1`; searching from the integer offset Input3
ord/2 | Unifies with the numeric ASCII value of the first character in the string input
char/2 | Unifies with a string with the ASCII character found for the integer input

#### Other operator clauses

_These always unify._

Clause | Description
------ | -----------
rand/1 | Unifies with a random floating point value between 0 and 1
type/2 | Unifies with the string literal of the name of the data type of Input: `'string'`, `'integer'` or `'float'`
print/2 | Print the Input to the console; unifies with the string literal `'yes'`
time/1 | Unifies with the integer number of milliseconds since the UNIX epoch
time/2 | Unifies with the integer number of milliseconds since the UNIX epoch; the input is just used as a requirement to enforce order of execution

Operator clauses cannot be overwritten or retracted with clauses with the same name and arity. They also only unify with some data types - for instance an arithmetic clause will not unify with string arguments. Illegal arguments, like trying to divide by 0, also do not unify.

Let's now go back to how to implement a program that returns the value of the Fibonacci sequence at position N. At first glance the solution would be:

```java
> fib(1, 1).
> fib(2, 1).
> fib(N, Res) :- gt(N, 2, gt) & sub(N, 1, N1) & sub(N, 2, N2) & fib(N1, X1) & fib(N2, X2) & \
                 add(X1, X2, Res).
```

Since this solution is recursive: a dependency on `fib` will try all solutions by expanding all clauses named `fib`, including itself; this may seem wrong at first. The Daki language interpreter, however, knows that the operator clauses can be evaluated before everything else in the clause tail. Therefore if the operator clause `gt` fails to unify when it's variables are set, we can abort that whole search subtree.

### Clause conditions

Depending on the interpreter to abort the whole search subtree because one of the clauses is falsifiable still requires the whole clause tail to be expanded, and sometimes multiple iterations depending on how long it takes for the operator clause to have it's variables set. The best solution would be to avoid expanding the clause tail in the first place.

This is best achieved by using what we call _clause conditions_. Clause conditions are boolean tests evaluated before a clause is expanded, providing earlier search termination. With clause conditions our Fibonacci program becomes:

```java
> fib(1, 1).
> fib(2, 1).
> fib(N > 2, Res) :- sub(N, 1, N1) & sub(N, 2, N2) & fib(N1, X1) & fib(N2, X2) & add(X1, X2, Res).
```

The clause condition `fib(N > 2, Res)` restricts matching N to values greater than 2. The full list of operators is as follows.

#### Operators

Symbol | Description
------ | ----
<  | Tests if the variable is lower than the constant
<= | Tests if the variable is lower or _equal_ to the constant
\>  | Tests if the variable is greater than the constant
\>= | Tests if the variable is greater or _equal_ to the constant
<\> | Tests if the variable is not _equal_ to the constant
:  | Tests if the data type of the variable is the constant value (from `'integer'`, `'float'` or `'string'`)

Clause conditions are exclusively between a variable and a constant values (`func(X < B, ...` is invalid) and numeric types never unify with string data types. Notice that in the usual unification rules, an integer literal in a clause will not match a floating point literal. In clause conditions and many operation clauses, however, these numeric types unify. The comparison operators use alphabetical order for strings.

Also note that you can mix multiple conditions. A variable must match all conditions for the clause to be expanded:

```java
> positive_except_five1(0 < N, N <> 5.0).
> positive_except_five(N) :- positive_except_five1(N, N).
>
> positive_except_five(3)?
positive_except_five(3).

> positive_except_five(4.50)?
positive_except_five(4.5).

> positive_except_five(5)?
No solution

> positive_except_five(-3)?
No solution

> positive_except_five('1')?
No solution

> is_string(X: 'string').
> is_string(1)?
No solution

> is_string(1.0)?
No solution

> is_string("1")?
is_string('1').

> is_float(X: 'float').
> is_float(1)?
No solution

> is_float(1.0)?
is_float(1.0).

> is_float("1")?
No solution

> is_integer(X: 'integer').
> is_integer(1)?
is_integer(1).

> is_integer(1.0)?
No solution

> is_integer("1")?
No solution

> is_numeric(X) :- is_float(X) | is_integer(X).
> is_numeric(1)?
is_numeric(1).

> is_numeric(1.0)?
is_numeric(1.0).

> is_numeric("1")?
No solution
```

As a last example, we can also benchmark how fast our two Fibonacci functions are, by making use of the `time` operator clause:

```java
> % Using only operator clauses
> fib1(1, 1).
> fib1(2, 1).
> fib1(N, Res) :- gt(N, 2, gt) & sub(N, 1, N1) & sub(N, 2, N2) & fib1(N1, X1) & fib1(N2, X2) & \
                  add(X1, X2, Res).
> time_fib1(N, Val, Elapsed) :- time(StartTime) & fib1(N, Val) & time(Val, EndTime) & \
                                sub(EndTime, StartTime, Elapsed).
>
> time_fib1(10, Val, Elapsed)?
time_fib1(12, 144, 161).

> % Using a clause condition
> fib2(1, 1).
> fib2(2, 1).
> fib2(N > 2, Res) :- sub(N, 1, N1) & sub(N, 2, N2) & fib2(N1, X1) & fib2(N2, X2) & \
                      add(X1, X2, Res).
> time_fib2(N, Val, Elapsed) :- time(StartTime) & fib2(N, Val) & time(Val, EndTime) & \
                                sub(EndTime, StartTime, Elapsed).
>
> time_fib2(10, Val, Elapsed)?
time_fib2(12, 144, 99).
```

As you can see, using only operator clauses where a clause condition could've been used can result in a large performance penalty. Operator clauses are obviously still useful for intermediate calculations, but should be avoided for logic control.

### Memoization

In the last example, when calculating the value of position N of the Fibonacci sequence, we are recalculating a lot. In some contexts, this is required, because a clause can be expanded in many ways; in mathematical formulas however this doesn't happen, and we can apply _memoization_ to the known unifiable forms of the clause.

In the Daki language this is done by telling the interpreter what functions can be memoized:

```java
> % Having fib1, fib2, time_fib1 and time_fib2 defined before
>
> add_memo fib1/2
OK

> add_memo fib2/2
OK

>
> time_fib1(12, Val, Elapsed)?
time_fib1(12, 144, 11).

> time_fib2(12, Val, Elapsed)?
time_fib2(12, 144, 8).

>
> % Values have already been completely memoized:
>
> time_fib1(12, Val, Elapsed)?
time_fib1(12, 144, 0).

> time_fib2(12, Val, Elapsed)?
time_fib2(12, 144, 0).
```

In this example we are implicitly memoizing the unification of the clause by the first argument. We must be consistent in how we expand our requirements on a memoized clause. If we later tried to find out all positions in the Fibonacci sequence for which the value is 1, it would fail to give all the solutions:

```java
> fib2(X, 1)?
fib2(2, 1).
```

Memoization is always relative to a global clauses table. Changing to another table will use another memoization tree.

## Interpreter Manual

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

### Options

The full list of command line options are:

Option | Description
------ | -----------
-h, --help | Print out the program manual and exit
-v, --version | Print out the program name and version, and exit
-c, --consult | Read file with path F and interpret each line
-i, --interactive | Activate interactive mode after finishing consulting all files
-d, --debug | Activate debug mode, which shows extra output and disables some performance improvements
-t, --time | Changes the default query timeout time; N is a floating point value in seconds

## Future work

- Test suite - cover the solver
- Help built-in
- Version number 1.0
- List data type, operators and unification of list elements (head|tail)
