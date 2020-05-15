#!/bin/bash

for i in ./tests/*.input; do
  test_name=${i%.input}
  test_name=${test_name#./}
  echo "Test ${test_name}"

  diff -y --suppress-common-lines <(./dakilang -c $i) ${i%.input}.output || (echo "Test ${test_name} FAILED" && exit 1)
done
