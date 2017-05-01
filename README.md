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


## Supported buil-in predicates

`assert/1`

`eq/`

`and/2`

`or/2`

`xor/2`

`not/1`

`listing/0`

`write/1`

`print/1`

`nl/0`

`halt/0`
