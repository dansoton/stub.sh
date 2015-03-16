#! /usr/bin/env bash
source "test-helper.sh"

#
# __remove_array_index() tests.
#

# Adds call to stub call list.
ARRAY=("element 1" "element 2" "element 3")

# Remove from middle of the list, check elements are moved left
__remove_array_index "ARRAY" "1"
assert 'echo ${#ARRAY[@]}' "2"
assert 'echo ${ARRAY[0]}' "element 1"
assert 'echo ${ARRAY[1]}' "element 3"

# Remove with no index specified, check no error and nothing happens
assert_raises '__remove_array_index "ARRAY" ""' 0
assert 'echo ${#ARRAY[@]}' "2"
assert 'echo ${ARRAY[0]}' "element 1"
assert 'echo ${ARRAY[1]}' "element 3"

# Remove a non-valid index returns a non-zero value
assert_raises '__remove_array_index "ARRAY" "10"' 1

# Check that it works removing the remaining elements
__remove_array_index "ARRAY" "0"
assert 'echo ${#ARRAY[@]}' "1"
assert 'echo ${ARRAY[0]}' "element 3"

__remove_array_index "ARRAY" "0"
assert 'echo ${#ARRAY[@]}' "0"

unset ARRAY

# End of tests.
assert_end "__remove_array_index()"
