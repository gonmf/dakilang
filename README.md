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
> fact('john', 'mary', 1). % I am a comment too
```

**New declarations** add what is called a _clause_ to a global table of clauses. A clause is composed of a head declaration and an optional tail, separated by the characters `:-`.

```
> parent('john', 'emily').
> grandparent(A, B) :- parent(A, C), parent(C, B).
```

Clauses are always terminated by a dot `.`. If they are declared with a tail, the tail must be evaluated true for the head to match. Clauses with a tail are called _rules_, while clauses without it are called _facts_.

In accordance with other logic languages, the `,` character is used to denote logical AND. You can also use the character `;` to denote logical OR, but notice these are equivalent:

```
> rule(x) :- reason1(x); reason2(x).
> % is the same as
> rule(x) :- reason1(x).
> rule(x) :- reason2(x).
```

In fact the second form is exactly how they are saved in the global table. If some of the broken down OR clauses already exist they are ignored without raising a warning. Keep this in mind when removing declarations.

The elements of clauses always have open brackets and are declared with one or more strings. Those strings can be
constants - with a specific data type - or variables.

The Daki data types are **string** (`'daki'`), **integer** (`42`) and **float**, for IEEE 754 floating point numbers (`3.14`). Constant types are not automatically coerced or matched, for example:

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

The following characters are reserved and should only appear outside of string constants for their specific uses: `'`, `"`, `%`, `,`, `(`, `)`, `;`, `.`, `?`, `~`, `\`, `>` and `<`. The specific sequence `:-` is also reserved. All others can be used in names of clause terms, variables and constants. All whitespace outside of string constants is ignored.

A **query** has a similar format to a tailless clause, but is ended with a `?` character instead of `.`. Upon being input, it starts a search for all its solutions using the global table of clauses.

The search will try to find all solutions for which the original query has no outstanding variables, showing the constants that have filled it.

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
- _listing_ - Prints all clauses kept in the current global table.
- _consult_ - Read and interpret a Daki language file.
- _version_ - Print version information.
- _help_ - Print help information.

Built-in commands are executed without any trailing `.`, `?` or `!`.

There are also **built-in clauses**, that unify with user-specified clauses and perform some form of calculation. To see why these are important, let's look at a practical example. In a language like Prolog, for instance, calculating a number of the Fibonacci sequence may look like:

```prolog
> fib(1, 1).
> fib(2, 1).
> fib(N, X) :- f1 = fib(N - 1, X1), f2 = fib(N - 2, X2), X is X1 + X2.
>
> fib(4, X)?
```

In Prolog we find arithmetic and conditional logic mixed with the clause itself. In the Daki language, however, we prefer to keep the clause format consistent even for these operations. We use instead what we call **operator clauses**:

Operator clauses are always unifiable only when the input variables are present and the Answer missing, and for performance they are always unified before user-defined clauses where possible.

**Arithmetic operator clauses**

_The inputs must be numeric to unify._

- `add(Numeric1, Numeric2, Answer)` - Unifies with the result of the addition of the two inputs
- `sub(Numeric1, Numeric2, Answer)` - Unifies with the result of the subtraction of Numeric1 with Numeric2
- `mul(Numeric1, Numeric2, Answer)` - Unifies with the result of the multiplication of the two inputs
- `div(Numeric1, Numeric2, Answer)` - Unifies with the result of the division of the two inputs; integer division is used if both inputs are integer
- `mod(Numeric1, Numeric2, Answer)` - Unifies with the rest of the integer division of the two inputs
- `pow(Numeric1, Numeric2, Answer)` - Unifies with the result of Numeric1 to the power of Numeric2
- `sqrt(Numeric, Answer)` - Unifies with the result of the square root of Numeric
- `log(Numeric1, Numeric2, Answer)` - Unifies with the logarithmic base Numeric2 of Numeric1
- `round(Numeric1, Numeric2, Answer)` - Unifies with the rounded value of Numeric1 to Numeric2 decimal cases
- `trunc(Numeric, Answer)` - Unifies with the value of Numeric without decimal part
- `floor(Numeric, Answer)` - Unifies with the largest integer value that is less or equal to the input
- `ceil(Numeric, Answer)` - Unifies with the smallest integer value that is greater or equal to the input
- `abs(Numeric, Answer)` - Unifies with the absolute value of the input

**Bitwise operator clauses**

_The inputs must be of type Integer to unify._

- `bit_and(Integer1, Integer2, Answer)` - Unifies with the bitwise AND of the two inputs
- `bit_or(Integer1, Integer2, Answer)` - Unifies with the bitwise OR of the two inputs
- `bit_xor(Integer1, Integer2, Answer)` - Unifies with the bitwise XOR of the two inputs
- `bit_neg(Integer, Answer)` - Unifies with the bitwise inversion of the bits of the input
- `bit_shift_left(Integer1, Integer2, Answer)` - Unifies with the left shifted value of Integer1 by Integer2
- `bit_shift_right(Integer1, Integer2, Answer)` - Unifies with the right shifted value of Integer1 by Integer2

**Equality/order operator clauses**

_The inputs must be of the same data type to unify._

- `eql(Input1, Input2, Answer)` - Unifies if the values are equal; with the string literal `'yes'`
- `neq(Input1, Input2, Answer)` - Unifies if the values are not equal; with the string literal `'yes'`
- `max(Input1, Input2, Answer)` - Unifies with the maximum value between Input1 and Input2; if any of the inputs is a string, string comparison is used instead of numeric
- `min(Input1, Input2, Answer)` - Unifies with the minimum value between Input1 and Input2; if any of the inputs is a string, string comparison is used instead of numeric
- `gt(Input1, Input2, Answer)` - Unifies if Input1 is greater than Input2; if any of the inputs is a string, string comparison is used instead of numeric; ; unifies with the string literal `'yes'`
- `lt(Input1, Input2, Answer)` - Unifies if Input1 is lower than Input2; if any of the inputs is a string, string comparison is used instead of numeric; ; unifies with the string literal `'yes'`

**Type casting operator clauses**

_These always unify._

- `str(Input, Answer)` - Unifies with the text representation of Input
- `int(Input, Answer)` - Unifies with the integer value of Input; will truncate floating point inputs
- `float(Input, Answer)` - Unifies with the floating point value of Input

**String operator clauses**

_The inputs must be of the correct data type to unify._

- `len(String, Answer)` - Unifies with the number of characters in String
- `concat(String1, String2, Answer)` - Unifies with the concatenation of the two inputs
- `slice(String, Numeric1, Numeric2, Answer)` - Unifies with the remainder of String starting at Numeric1 and ending at Numeric2
- `index(String, Numeric1, Numeric2, Answer)` - Unifies with the first position of Numeric1 in String, starting the search from Numeric2
- `ord(String, Answer)` - Unifies with the numeric ASCII value of the first character in the String string
- `char(Integer, Answer)` - Unifies with the ASCII character found for the numeric value of Integer

**Other operator clauses**

_These always unify._

- `rand(Answer)` - Unifies with a random floating point value between 0 and 1
- `type(Input, Answer)` - Unifies with the string literal of the name of the data type of Input: `'string'`, `'integer'` or `'float'`
- `print(Input, Answer)` - Print the Input to the console; unifies with the string literal `'yes'`
- `time(Answer)` - Unifies with the number of milliseconds since the UNIX epoch
- `time(Input, Answer)` - Unifies with the number of milliseconds since the UNIX epoch; the input is just used as a requirement to enforce order of execution

Operator clauses cannot be overwritten or retracted with clauses with the same name and arity. They also only unify with some data types - for instance an arithmetic clause will not unify with string arguments. Illegal arguments, like trying to divide by 0, also do not unify.

Let's now go back to how to implement a program that returns the value of the Fibonnaci sequence at position N. At first glance the solution would be:

```
fib(1, 1).
fib(2, 1).
fib(N, Res) :- gt(N, 2, gt), sub(N, 1, N1), sub(N, 2, N2), fib(N1, X1), fib(N2, X2), add(X1, X2, Res).
```

Since this solution is recursive: a dependency on `fib` will try all solutions by expanding all clauses named `fib`, including itself; this may seem wrong at first. The Daki language interpreter, however, knows that the operator clauses can be evaluated before everything else in the clause tail. Therefore if the operator clause `gt` fails to unify when it's variables are set, we can abort the whole search subtree.

Depending on the interpreter to abort the whole search subtree because one of the clauses is falsifiable however still requires the whole clause tail to be expanded. In another example we may also not be able to fail to unify immediately. The best solution would be to avoid expanding the clause tail in the first place.

This is best achieved by using what we call **clause conditions**. Clause conditions are boolean tests evaluated before a clause is expanded, providing earlier search termination. With clause conditions our Fibonnaci program becomes:

```
fib(1, 1).
fib(2, 1).
fib(N > 2, Res) :- sub(N, 1, N1), sub(N, 2, N2), fib(N1, X1), fib(N2, X2), add(X1, X2, Res).
```

The clause condition `fib(N > 2, Res)` restricts matching N to values greater than 2. The only other operators are `<` (lower than), `<=` (lower or equal to), `>=` (greater or equal to) and `<>` (different than). _Equal to_ semantics are already the default matching strategy used. The lower and greater than operators use alphabetical order for strings.

Clause conditions are exclusively between a variable and a constant values (`func(X < B, ...` is invalid) and numeric types never unify with string data types.

Also note that you can mix multiple conditions. A variable must match all conditions for the clause to be expanded:

```
> positive_except_five1(0 < N, N <> 5).
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
```

As a last example, we can also benchmark how fast our two Fibonnaci functions are, by making use of the `time` operator clause:

```
> % Using only operator clauses
> fib1(1, 1).
> fib1(2, 1).
> fib1(N, Res) :- gt(N, 2, gt), sub(N, 1, N1), sub(N, 2, N2), fib1(N1, X1), fib1(N2, X2), add(X1, X2, Res).
> time_fib1(N, Val, Elapsed) :- time(StartTime), fib1(N, Val), time(Val, EndTime), sub(EndTime, StartTime, Elapsed).
>
> time_fib1(10, Val, Elapsed)?
time_fib1(12, 144, 161). % 161 milliseconds

> % Using clause conditions
> fib2(1, 1).
> fib2(2, 1).
> fib2(N > 2, Res) :- sub(N, 1, N1), sub(N, 2, N2), fib2(N1, X1), fib2(N2, X2), add(X1, X2, Res).
> time_fib2(N, Val, Elapsed) :- time(StartTime), fib2(N, Val), time(Val, EndTime), sub(EndTime, StartTime, Elapsed).
>
> time_fib2(10, Val, Elapsed)?
time_fib2(12, 144, 106). % 106 milliseconds
```

As you can see, using only operator clauses where a clause condition could've been used can result in a large performance penalty. Operator clauses are obviously still useful for intermediate calculations, but should be avoided for logic control.

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

The commands `-h`, `-v` and `-d` are also available to show instructions, the program version, and activate debug mode. All commands have their long form counterparts: `--consult`, `--interactive`, `--help`, `--version` and `--debug`. Debug mode shows extra debug messages and disables some performance improvements.

## TODO - Planned features or improvements

- Add condition for testing variable type, like "="
- Test suite - cover the parser
- Improve parser
- Support other formats for numeric values, like hex
- Test suite - cover the solver
- Help built-in
- List data type, operators and unification of list elements (head|tail)
