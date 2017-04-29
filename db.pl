% consult('db.pl')
% listing.


teste(a, b).
teste(b, a).

loves(romeo, juliet).
loves(romeo, juliet).

loves(juliet, romeo) :- loves(romeo, juliet).
loves(juliet, romeo) :- loves(romeo, juliet).
