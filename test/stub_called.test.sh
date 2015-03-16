#! /usr/bin/env bash
source "test-helper.sh"

#
# stub_called() tests.
#

# Returns 1 when stub doesn't exist.
assert_raises 'stub_called "uname"' 1

# Returns 1 when stub hasn't been called.
stub "uname"
assert_raises 'stub_called "uname"' 1
restore "uname"

# Returns 0 when stub has been called.
stub "uname"
uname
assert_raises 'stub_called "uname"' 0
restore "uname"

# Stub called state is reset by creating a new stub, not by restore.
stub "uname"
uname
restore "uname"
assert_raises 'stub_called "uname"' 0
stub "uname"
assert_raises 'stub_called "uname"' 1
restore "uname"

# Recreating a stub only resets called state of recreated stub.
stub "uname"
stub "top"
uname
top
stub "uname"
assert_raises 'stub_called "uname"' 1
assert_raises 'stub_called "top"' 0
restore "uname"
restore "top"

# Check stub_called works with individual sub-command combinations
stub "uname"
stub "uname X"
assert_raises 'stub_called "uname"' 1
assert_raises 'stub_called "uname X"' 1
uname X
assert_raises 'stub_called "uname"' 1
assert_raises 'stub_called "uname X"' 0
uname
assert_raises 'stub_called "uname"' 0
assert_raises 'stub_called "uname X"' 0
stub "uname Y"
assert_raises 'stub_called "uname"' 0
assert_raises 'stub_called "uname X"' 0
assert_raises 'stub_called "uname Y"' 1
restore "uname"
restore "uname X"
restore "uname Y"

# End of tests.
assert_end "stub_called()"
