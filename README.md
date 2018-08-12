# Datalog interpreter

Datalog programming language interpeter


## Intro to Datalog

Finding information about Datalog is hard.

It is easy enough to find it is the subset of Prolog that is contained by Hoare logic,
but unfortunately most papers on the subject are either behind paywalls,
or focus on such boring stuff as "real world use cases".

In the absence of a formalized language definition, I'll instead very shortly
introduce Datalog as I hope to implement. There is beauty in terseness.

### Glossary

First, some terminology (these are similar but different from Prolog):

*term* - Either a variable or literal.

*variable* - Something to be attributed an atom when searching for a solution. Must start with an upper case character.

*literal* - A constant. Like a name, number. Must start with a lower case character or algarism.

*rule* - A declaration, that can be translated as "X such that Y". We want to resolve these by finding combinations of variables that satisfy them.

*fact* - A rule that is so full of itself it needs no Y.

*goal* - A fact with one or more (non-free) variables, to be resolved.

*free variable* - Indicates a variable that for the purposes of the rule it's value doesn't matter. Must be an underscore ("_") always.

Our goal is to state our rules and facts about a domain, and then indicate goals we wish to solve the constraint problem for. More than one solution may exist.

For the sake of the parser, a name with a list of terms is called a *functor*, like `parent(A, B)`. Our rules and goals are made of at least one *functor*, that names them.

### Some examples

No introduction is complete without the classical parent example.

```prolog
parent(john, alice).   % This is a comment, commenting on a fact
parent(john, bob).     % Bob is the parent of John (we can read this however we want)
parent(bob, margaret).

grandparent(A, B) :- parent(A, Z), parent(Z, B). % "," means "and", conjunction

offspring(A, B) :- parent(B, A).
grandoffspring(A, B) :- offspring(B, A).
related(A, B) :- parent(A, B); offspring(B, A); grandparent(A, B);
                 grandoffspring(A, B). % ";" means "or", disjunction
```

And some goals and their responses:

```prolog
? related(john, margaret).
true                        % Our goal succeeds
?
? related(john, X).
X=alice ;                   % We use ";" to ask for more solutions, and "." to stop
X=bob ;
X=margaret ;
false                       % Rejecting the previous solutions, our goal fails
```

The search for solutions is done with reification: a process by which we
recursively try to replace variables with literal values.


## How to use

First install Ruby, any Ruby will do.

Launch the interpreter with:

```sh
ruby interpreter.rb
```

This will immediately start in interactive mode.

You can also load files of clauses and of goals, as such:

```sh
ruby interpreter.rb --consult clauses1.pl --eval goals.pl --consult clauses2.pl
```

## Further details

Some quirks of the interpreter/parser/language:

1. Operators do not have a set precedence, so to specify it, use braces around clause parts.

2. You can declare multiple clauses with the same name (as seen above). When solving a goal, the clauses are tried in order of declaration.

3. Clauses are matched if they match the number of arguments. `a(B, C)` will match `a(josh, _)` but not `a(josh)` or `a(josh, _, B)`.

4. Like in Prolog, free variables do not need to match in the same clause, for instance `a(A, _, _)` can be satisfied both by `a(john, mark, paul)` and `a(john, mark, mark)`. In `b(A, A, _, _)` variable `A` must have the same value.

5. If a fact contains variables (has no conditions because it is a fact), the only difference between `a(A, A)` and `a(_, _)` is that the first option enforces that the variables must match in value. Variable `A` is almost free in that regard. You can right:

```prolog
are_equal(A, A).
```

6. Besides the format restrictions above, names of *terms* and *functors* have to be composed of algarisms, letters and underscores. `My_best_variable1` is a valid name.
