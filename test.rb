#!/usr/bin/env ruby

require_relative 'dakilang'

def assert(query, expected)
  parsed = DakiLangInterpreter.new.debug_tokenizer(query)
  return if parsed == expected || (parsed.start_with?('Syntax error') && expected == :error)

  puts "Test failed: #{query}\nExpected: #{expected}\nReceived: #{parsed}"
  exit(1)
end

assert(
  'abc(A, B0).',
  'name(abc) | args_start | var(%A) | var(%B0) | args_end | clause_finish'
)

assert(
  'abc(_a).',
  :error
)

assert(
  'abc(a_).',
  'name(abc) | args_start | var(%a_) | args_end | clause_finish'
)

assert(
  'abc(3a).',
  :error
)

assert(
  'abc(A, 123, 12.3, "123", \'123\', 0>vic, vic <> 0.3, vic > "my_str").',
  'name(abc) | args_start | var(%A) | integer_const(123) | float_const(12.3) | string_const(123) | string_const(123) | var(%vic%<%i%0) | var(%vic%<>%f%0.3) | var(%vic%>%s%my_str) | args_end | clause_finish'
)

assert(
  'fib(Pos <= 2, Res) :- sub(Pos, 1, N1), sub(Pos, 2, N2) , fib(N1, X1), fib(N2, X2), add(X1, X2, Res).',
  'name(fib) | args_start | var(%Pos%<=%i%2) | var(%Res) | args_end | sep | name(sub) | args_start | var(%Pos) | integer_const(1) | var(%N1) | args_end | and | name(sub) | args_start | var(%Pos) | integer_const(2) | var(%N2) | args_end | and | name(fib) | args_start | var(%N1) | var(%X1) | args_end | and | name(fib) | args_start | var(%N2) | var(%X2) | args_end | and | name(add) | args_start | var(%X1) | var(%X2) | var(%Res) | args_end | clause_finish'
)

assert(
  'parent("victor", \'john\').',
  'name(parent) | args_start | string_const(victor) | string_const(john) | args_end | clause_finish'
)

assert(
  'parent("victor",\'john\').',
  'name(parent) | args_start | string_const(victor) | string_const(john) | args_end | clause_finish'
)

assert(
  'grandparent(X, Y) :- parent(X, Z), parent(Z, Y).',
  'name(grandparent) | args_start | var(%X) | var(%Y) | args_end | sep | name(parent) | args_start | var(%X) | var(%Z) | args_end | and | name(parent) | args_start | var(%Z) | var(%Y) | args_end | clause_finish'
)

assert(
  'grandparent(X, Y) :- parent(X, Z); parent(Z, Y).',
  'name(grandparent) | args_start | var(%X) | var(%Y) | args_end | sep | name(parent) | args_start | var(%X) | var(%Z) | args_end | or | name(parent) | args_start | var(%Z) | var(%Y) | args_end | clause_finish'
)

assert(
  'not_found(\'true\')?',
  'name(not_found) | args_start | string_const(true) | args_end | full_query_finish'
)

assert(
  'not_found(\'\')?',
  'name(not_found) | args_start | string_const() | args_end | full_query_finish'
)

assert(
  'natural_except_five(5)~',
  'name(natural_except_five) | args_start | integer_const(5) | args_end | retract_finish'
)

assert(
  'natural_except_five().',
  :error
)

assert(
  'natural_except_five()~',
  :error
)

assert(
  'natural_except_five()?',
  :error
)

assert(
  'natural_except_five()',
  :error
)

assert(
  'natural_except_five() :- amep(); bla(X).',
  :error
)

assert(
  'natural_except_five() :- amep(); bla(X)~',
  :error
)

assert(
  'natural_except_five() :- amep(); bla(X)?',
  :error
)

assert(
  'natural_except_five() :- amep(); bla(X)',
  :error
)

assert(
  'is_string(X: \'string\').',
  'name(is_string) | args_start | var(%X%:%s%string) | args_end | clause_finish'
)

assert(
  'is_string("1")?',
  'name(is_string) | args_start | string_const(1) | args_end | full_query_finish'
)

assert(
  'div(43, 0.32, a_b)?',
  'name(div) | args_start | integer_const(43) | float_const(0.32) | var(%a_b) | args_end | full_query_finish'
)

assert(
  'div(00_43, 0.32, a_b)?',
  :error
)

assert(
  'div(43, ., a_b)?',
  :error
)

assert(
  'div(43, a_b,)?',
  :error
)

assert(
  'div(43, a_b, )?',
  :error
)

assert(
  'div(, 43, a_b)?',
  :error
)

assert(
  'div(, 43, a_b, )?',
  :error
)

assert(
  'xpto(N <> 2, N <> 3) :- eql(N, N, X).',
  'name(xpto) | args_start | var(%N%<>%i%2) | var(%N%<>%i%3) | args_end | sep | name(eql) | args_start | var(%N) | var(%N) | var(%X) | args_end | clause_finish'
)

assert(
  'xpto(N << 2, N <> 3) :- eql(N, N, X).',
  :error
)

assert(
  'xpto(N < 2, N <> 3) :- eql.',
  :error
)

assert(
  'xpto :- eql(N, N, X).',
  :error
)

assert(
  'xpto(N <> 2, N <> 3) :- eql(N, N, X)?',
  :error
)

assert(
  'number(121).',
  'name(number) | args_start | integer_const(121) | args_end | clause_finish'
)

assert(
  'number(0172).',
  'name(number) | args_start | integer_const(122) | args_end | clause_finish'
)

assert(
  'number(019).',
  :error
)

assert(
  'number(0b1111011).',
  'name(number) | args_start | integer_const(123) | args_end | clause_finish'
)

assert(
  'number(0b1111x011).',
  :error
)

assert(
  'number(0b1112011).',
  :error
)

assert(
  'number(0x7c).',
  'name(number) | args_start | integer_const(124) | args_end | clause_finish'
)

assert(
  'number(0x7xc).',
  :error
)

assert(
  'number(0x7g).',
  :error
)

puts 'Tests passed'
