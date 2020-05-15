#!/bin/bash

# rm tests/*.output

for i in ./tests/*.input; do
  output_file=${i%.input}.output
  test_name=${i%.input}
  test_name=${test_name#./}
  echo "Test ${test_name}"

  # To create all .output files
  # ./dakilang -c $i > $output_file

  diff -y --suppress-common-lines <(./dakilang -c $i) $output_file || (echo "Test ${test_name} FAILED" && exit 1)
done
