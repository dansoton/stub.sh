#! /usr/bin/env bash
source "test-helper.sh"

#
# stub_called_with() tests.
#

# Returns 1 when stub doesn't exist.
assert_raises 'stub_called_with "top"' 1

# Returns 0 when stub has been called with given arguments.
stub "uname"
stub "uname X"

uname
uname -r
uname -r -a

uname X
uname X Y
uname X "love spaces"

assert_raises 'stub_called_with "uname"' 0
assert_raises 'stub_called_with "uname" -r' 0
assert_raises 'stub_called_with "uname" -r -a' 0

assert_raises 'stub_called_with "uname X"' 0
assert_raises 'stub_called_with "uname X" Y' 0
restore "uname"
restore "uname X"

# Returns 1 when stub has not been called with given arguments.
stub "uname"
stub "uname X"
uname -r
uname X Y
assert_raises 'stub_called_with "uname"' 1
assert_raises 'stub_called_with "uname" -a' 1
assert_raises 'stub_called_with "uname X"' 1
assert_raises 'stub_called_with "uname X" Z' 1
restore "uname"
restore "uname X"

# Only matches against exact argument lists.
stub "uname"
stub "uname X"
uname -r -a
uname X Y Z
assert_raises 'stub_called_with "uname" -r' 1
assert_raises 'stub_called_with "uname" -r -a' 0
assert_raises 'stub_called_with "uname X" Y' 1
assert_raises 'stub_called_with "uname X" Y Z' 0
restore "uname"
restore "uname X"

# Call history is only reset when restubbing a command, not when restoring.
stub "uname"
stub "uname X"
uname -r
uname X
assert_raises 'stub_called_with "uname" -r' 0
assert_raises 'stub_called_with "uname X"' 0
restore "uname"
restore "uname X"
assert_raises 'stub_called_with "uname" -r' 0
assert_raises 'stub_called_with "uname X"' 0
stub "uname"
assert_raises 'stub_called_with "uname" -r' 1
assert_raises 'stub_called_with "uname X"' 0
stub "uname X"
assert_raises 'stub_called_with "uname X"' 1
restore "uname"
restore "uname X"

# Handling of string arguments containing spaces.
stub "uname"
stub "uname X"
uname -r "foo bar"
uname X Y "baz blah" Z
assert_raises "stub_called_with 'uname' -r 'foo bar'" 0
assert_raises "stub_called_with 'uname' -r foo bar" 1
assert_raises "stub_called_with 'uname X' Y 'baz blah' Z" 0
assert_raises "stub_called_with 'uname X' Y baz blah Z" 1
restore "uname"
restore "uname X"

# End of tests.
assert_end "stub_called_with()"
