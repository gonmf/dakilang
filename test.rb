require_relative 'dakilang'

def assert(a, b)
  if a != b
    puts "Test failed: Expected\n    #{b}\nbut got\n    #{a}"
    exit(1)
  end
end

interpreter = DakiLangInterpreter.new

assert(
  interpreter.debug_tokenizer('abc(A, B).'),
  'name | abc | vars_start | var | %A | var | %B | vars_end | clause_finish'
)

assert(
  interpreter.debug_tokenizer('abc(A, 123, 12.3, "123", \'123\', 0>vic, vic <> 0.3, vic > "my_str").'),
  'name | abc | vars_start | var | %A | integer_const | 123 | float_const | 12.3 | string_const | 123 | string_const | 123 | var | %vic%<%i%0 | var | %vic%<>%f%0.3 | var | %vic%>%s%my_str | vars_end | clause_finish'
)

assert(
  interpreter.debug_tokenizer('fib(Pos <= 2, Res) :- sub(Pos, 1, N1), sub(Pos, 2, N2), fib(N1, X1), fib(N2, X2), add(X1, X2, Res).'),
  'name | fib | vars_start | var | %Pos%<=%i%2 | var | %Res | vars_end | sep | name | sub | vars_start | var | %Pos | integer_const | 1 | var | %N1 | vars_end | and | name | sub | vars_start | var | %Pos | integer_const | 2 | var | %N2 | vars_end | and | name | fib | vars_start | var | %N1 | var | %X1 | vars_end | and | name | fib | vars_start | var | %N2 | var | %X2 | vars_end | and | name | add | vars_start | var | %X1 | var | %X2 | var | %Res | vars_end | clause_finish'
)

assert(
  interpreter.debug_tokenizer('parent("victor", \'john\').'),
  'name | parent | vars_start | string_const | victor | string_const | john | vars_end | clause_finish'
)

assert(
  interpreter.debug_tokenizer('grandparent(X, Y) :- parent(X, Z), parent(Z, Y).'),
  'name | grandparent | vars_start | var | %X | var | %Y | vars_end | sep | name | parent | vars_start | var | %X | var | %Z | vars_end | and | name | parent | vars_start | var | %Z | var | %Y | vars_end | clause_finish'
)

assert(
  interpreter.debug_tokenizer('not_found(\'true\')?'),
  'name | not_found | vars_start | string_const | true | vars_end | full_query_finish'
)

assert(
  interpreter.debug_tokenizer('natural_except_five(5)~'),
  'name | natural_except_five | vars_start | integer_const | 5 | vars_end | retract_finish'
)


puts 'Tests passed'
