alpha(hello, world).
beta(A) :- test(A).
charlie(exists).
delta(exists).
delta(blob).

test(B) :- delta(B).

test(A)?
test(literal)?
beta(B)?

alpha2(A, B) :- alpha(A, B).

alpha2(A, B)?
alpha2(goodbye, B)?
alpha2(X, world)?
alpha2(A, A)?

listing

parent(john, mary).
parent(victor, john).
grandparent(X, Y) :- parent(X, Z) & parent(Z, Y).

grandparent(A, B)?
grandparent(A, A)?
