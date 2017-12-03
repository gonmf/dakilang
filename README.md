![](https://www.heartlandflags.com/images/yellow-warning.gif) This program is very incomplete and does not meet the most basic of Prolog specifications yet.

# Toy Prolog interpreter

Example

```sh
make clean && make && ./prolog --consult db.pl
```

```
% Consulting "db.pl"...

% Loaded 4 facts.

?- parent(Father, Child).

Father = john
Child = mary

yes

?- assert(other(A,_)).

% Definition "assert/2" not found.
no

?- assert(other(A)).

A = (any)

yes

?- listing.

f:parent/2(c:john,c:mary) :- c:1

f:parent/2(c:victor,c:john) :- c:1

f:grandparent/2(v:X,v:Y) :- f:and/2(f:parent/2(v:X,v:Z),f:parent/2(v:Z,v:Y))

f:a/1(v:A) :- c:1

f:other/1(v:A) :- c:1

yes

?- halt.
```


## Supported buil-in predicates

`assert/1`

`eq/2`

`and/2`

`or/2`

`xor/2`

`not/1`

`listing/0`

`write/1`

`print/1`

`nl/0`

`halt/0`
