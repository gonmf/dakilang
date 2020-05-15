#!/bin/bash

# rm tests/*.out

for i in ./tests/*.dl; do
  output_file=${i%.dl}.out
  test_name=${i%.dl}
  test_name=${test_name#./}
  echo "Test ${test_name}"

  # To create all .out files
  # ./dakilang -c $i > $output_file

  diff -y --suppress-common-lines <(./dakilang -c $i) $output_file || (echo "Test ${test_name} FAILED" && exit 1)
done
