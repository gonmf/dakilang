Toy Prolog interpreter

Example

```sh
make clean && make && ./prolog --consult db.pl --eval db2.pl
```

```
Consulting "db.pl"...

Loaded 3 facts.

Evaluating "db2.pl"...

?- parent(A,B).

A = john
B = mary

yes

?- parent(A,A).

no
```
