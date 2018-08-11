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

term - Either a variable or literal.

variable - Something to be attributed an atom when searching for a solution. Must start with an upper case character.

literal - A constant. Like a name, number. Must start with a lower case character or algarism.

rule - A declaration, that can be translates as "X such that Y". We want to resolve/satisfy these by finding combinations of variables that satisfy them.

fact - A rule that is so full of itself it needs no Y.

goal - A fact with one or more (non-free) variables, to be resolved.

free variable - Indicates a variable that for the purposes of the rule it's value doesn't matter. Must be a lower case only.

Our goal is to state our rules and facts about a domain, and then indicate goals we wish to solve the constraint problem for.

### Some examples

No introduction is complete without the classical parent example.

```prolog
parent(john, alice).   % This is a comment
parent(john, bob).     % Bob is the parent of John (we can read this however we want)
parent(bob, margaret).

grandparent(A, B) :- parent(A, Z), parent(Z, B). % "," means "and"

offspring(A, B) :- parent(B, A).
grandoffspring(A, B) :- offspring(B, A).
related(A, B) :- parent(A, B); offspring(B, A); grandparent(A, B);
                 grandoffspring(A, B). % ";" means "or"
```

And some goals and their responses:

```prolog
? related(john, margaret).
true                        % Our goal succeeds
?
? related(john, X).
X=alice ;                   % We use ";" to ask for more solutions, and "." to stop
X=bob ;
X=margaret;
false                       % Rejecting the previous solutions, our goal fails
```

The search for solutions is done with reification: a process by which we recursively
try to replace variables with literal values.


## How to use

First install Ruby, any Ruby will do.

Launch the interpreter with:

```sh
ruby interpreter.rb
```

This will immediately start in interactive mode.

You can also load files of clauses and of goals, as such:

```sh
ruby interpreter.rb --consult clauses1 --eval goals --consult cl2
```
