# Daki Language Interpreter

![Dakilang mascot](/drawing.jpeg)

Daki is a small computer programming language similar to Prolog and Datalog. This is it's first concept implementation, and therefore features an interpreter instead of a compiler.

**For now this project will be implemented in Ruby for fast prototyping and reiteration.**

Daki is a declarative and logic language based on Horn clauses, aimed at solving problems via deduction.

This project implements a stable, iterative and space bound algorithm of unification of free variables, in depth-first search. At this point, the implementation details and algorithm are subject to change.

Regardless of your familarity with Prolog or Datalog, Daki language has significant differences and omissions from both, also being a work in progress, so I have compiled the following language definition, structured by example.

## Tutorial

Daki can be used both in interactive and non-interactive mode. Currently only non-interactive is supported.

In non-interactive mode, the interpreter reads one or more .dl files in sequence, and interpretes each line as if input in interactive mode.

A .dl file can contain five types of instructions:

1. Comments
2. New declarations
3. Queries
4. Declarations to be removed
5. Built-in commands

**Comments** start with the "%" character, and everything after this character is ignored

```
% I am a comment

> func(john, mary). % I am a comment too
```

**New declarations** add what is called a _clause_ to a global table of clauses. A clause is composed of a head declaration and an optional tail, separated by the characters ":-".

```
> parent(john, emily).
> grandparent(A, B) :- parent(A, C) & parent(C, B).
```

Clauses are always terminated by a dot ".". If they are declared with a tail, the tail must be evaluated true for the head to also match.

In contrast with other logic languages, the "&" character is used to denote logical AND.

The elements of clauses always have open brackets and are declared with one or more strings. Those strings are variables if the first character is a capital letter, or constant values otherwise. Numbers and other special characters not used for other purposes can therefore also be the first characters of valid constants.

A **query** has a similar format to a tailess clause, but is ended with a "?" character instead of ".". Upon being inputed, it starts a search for all its solutions using the global table of clauses.

The search will try to find solutions for which the original query has no outstanding variables, showing the contants that have filled it.

The interpreter will print out every solution found or return "No solution".

```
> grandparent(john, B)?
grandparent(john, mary).
```

**Declarations to be removed** to be removed are declared with the same name, constant values and tail of the original clause declarations. The variables can have different names.

Declaring two clauses with the same name, constants and tail is impossible, and will raise a warning; similarly trying to remove from the global table a clause that does not exist will also raise a warning.

To remove a clause end your command with the "~" character.

```
> grandparent(john, Var) :- other(Var, Var).
> grandparent(john, Var) :- other(Var, Var).
Clause already exists
> grandparent(john, X) :- other(X, X)~
Clause removed
> grandparent(john, X) :- other(X, X)~
Clause not found
```

Finally, **built-in commands** allow for some specific operations related to the interpreter and global table themselves. These are:

- _quit_ / _exit_ - Stop execution and exit the interpreter if in interactive mode
- _database_set N_ - Changes the global table currently in use. By default, number 0 is active. Passing no argument prints the current table number.
- _listing_ - Prints all rules kept in the current global table.

Built-in commands are executed without any trailing "." or "?".



