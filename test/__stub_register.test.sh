#! /usr/bin/env bash
source "test-helper.sh"

#
# __stub_register() tests.
#

# Sets up stub index, stub call list, and adds stub to index.
__stub_register "uname"
__stub_register "top"
__stub_register "uname X"

assert 'echo "$STUB_INDEX"' "uname=0\ntop=1\nuname X=2"
assert 'echo "$STUB_NEXT_INDEX"' "3"

# Note: There seems to be no possible way to validate if a empty array
# variable has been set, as it appears to be empty/null/undefined whatever I
# try.


# End of tests.
assert_end "__stub_register()"
