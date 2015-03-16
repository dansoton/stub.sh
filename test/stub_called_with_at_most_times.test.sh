#! /usr/bin/env bash
source "test-helper.sh"

#
# stub_called_with_at_most_times() tests.
#

# Setup.
stub "uname"
stub "uname X"

uname
uname -r
uname -r
uname -r
uname -r -a

uname X
uname X Y
uname X Y
uname X Y Z

# Returns 0 when stub called no more than given number of times.
assert_raises 'stub_called_with_at_most_times "uname" 5 -r' 0
assert_raises 'stub_called_with_at_most_times "uname" 4 -r' 0
assert_raises 'stub_called_with_at_most_times "uname" 3 -r' 0

assert_raises 'stub_called_with_at_most_times "uname X" 2' 0
assert_raises 'stub_called_with_at_most_times "uname X" 1' 0
assert_raises 'stub_called_with_at_most_times "uname X" 2 Y' 0
assert_raises 'stub_called_with_at_most_times "uname X" 1 Y Z' 0

# Returns 1 when stub has been called more than given number of times.
assert_raises 'stub_called_with_at_most_times "uname" 2 -r' 1
assert_raises 'stub_called_with_at_most_times "uname" 1 -r' 1
assert_raises 'stub_called_with_at_most_times "uname" 0 -r' 1

assert_raises 'stub_called_with_at_most_times "uname X" 0' 1
assert_raises 'stub_called_with_at_most_times "uname X" 1 Y' 1

# Behaves as if stub has not been called when the stub doesn't exist.
assert_raises 'stub_called_with_at_most_times "top" 0' 0
assert_raises 'stub_called_with_at_most_times "top" 1' 0

# Teardown.
restore "uname"
restore "uname X"

# End of tests.
assert_end "stub_called_with_at_most_times()"
