Toy Prolog interpreter

Example

```prolog
loves(romeo, juliet).

loves(juliet, romeo) :- loves(romeo, juliet) .

?- loves(juliet, X).

X = romeo

yes
```
