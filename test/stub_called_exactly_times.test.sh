#! /usr/bin/env bash
source "test-helper.sh"

#
# stub_called_exactly_times() tests.
#

# Setup.
stub "uname"
stub "uname X"
uname
uname -r
uname X


# Returns 0 when stub called exactly given number of times.
assert_raises 'stub_called_exactly_times "uname" 2' 0
assert_raises 'stub_called_exactly_times "uname X" 1' 0

# Returns 1 when stub has not been called the exact given number of times.
assert_raises 'stub_called_exactly_times "uname" 4' 1
assert_raises 'stub_called_exactly_times "uname" 3' 1
assert_raises 'stub_called_exactly_times "uname" 1' 1
assert_raises 'stub_called_exactly_times "uname" 0' 1

assert_raises 'stub_called_exactly_times "uname X" 0' 1
assert_raises 'stub_called_exactly_times "uname X" 2' 1

# Behaves as if stub has not been called when the stub doesn't exist.
assert_raises 'stub_called_exactly_times "top" 0' 0
assert_raises 'stub_called_exactly_times "top" 1' 1

# Teardown.
restore "uname"
restore "uname X"

# End of tests.
assert_end "stub_called_times()"
