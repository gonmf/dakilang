Toy Prolog interpreter

Example

```sh
$ make clean && make && ./prolog db.pl
```

```
Read 233 bytes.

parent(john, mary).
f:parent(c:john,c:mary) :- c:1

parent(victor, john).
f:parent(c:victor,c:john) :- c:1

grandparent(X, Y) :- parent(X, Z), parent(Z, Y).
f:grandparent(v:X,v:Y) :- f:$and(f:parent(v:X,v:Z),f:parent(v:Z,v:Y))


Loaded 3 facts.
```
