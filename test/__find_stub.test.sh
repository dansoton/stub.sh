#! /usr/bin/env bash
source "test-helper.sh"

#
# __find_stub() tests.
#

assert_variables() {
  local expected_stub_index="$1"
  local expected_cmd_and_args="$2"
  local expected_remaining_args=("$3")
  local expected_stub_behavior="$4"

  assert_raises "[ '$expected_stub_index' == '$stub_index' ]" 0
  assert_raises "[ '$expected_cmd_and_args' == '$cmd_and_args' ]" 0
  assert_raises "[ '${expected_remaining_args[@]}' == '${remaining_args[@]}' ]" 0
  assert_raises "[ '$expected_stub_behavior' == '$stub_behavior' ]" 0
}

# Adds call to stub call list.
STUB_INDEX="uname X=0
uname=1
uname Y=2
top=3
"

STUB_0_BEHAVIOR="behavior for uname X"
STUB_1_BEHAVIOR="behavior for uname"
STUB_2_BEHAVIOR="behavior for uname Y"
STUB_3_BEHAVIOR="behavior for top"

STUBS_ACTIVE="uname=1
uname Y=2
top=3
uname X=0"

# Test it finds all existing stubs
__find_stub "uname"
assert_variables "1" "uname" "" "behavior for uname"
__find_stub "uname X"
assert_variables "0" "uname X" "" "behavior for uname X"
__find_stub "top"
assert_variables "3" "top" "" "behavior for top"
__find_stub "uname Y"
assert_variables "2" "uname Y" "" "behavior for uname Y"

# Remove an element and check the remaining elements are still correctly found
cmd_to_remove="uname"
STUBS_ACTIVE=$(echo "$STUBS_ACTIVE" | $SED "/^${cmd_to_remove}=/d")
unset STUB_1_BEHAVIOR

__find_stub "uname X"
assert_variables "0" "uname X" "" "behavior for uname X"
__find_stub "uname Y"
assert_variables "2" "uname Y" "" "behavior for uname Y"
__find_stub "top"
assert_variables "3" "top" "" "behavior for top"

# Test it returns empty values in the variables when it cannot find a match
__find_stub "nonexistant"
assert_variables "" "" "" ""

unset STUBS_ACTIVE
unset STUB_BEHAVIORS_ACTIVE

# End of tests.
assert_end "__find_stub()"
