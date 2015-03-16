#! /usr/bin/env bash
source "test-helper.sh"

#
# __stub_clean() tests.
#

# Removes unsets stub call list, removes stub from index
STUB_INDEX="uname=0
top=1
uname X=2"

__stub_call "uname" 0
__stub_call "uname" 0 -r
__stub_call "uname" 0 -r -a

__stub_call "top" 1 -h
__stub_call "uname X" 2 Y

__stub_clean "uname"
assert 'echo "$STUB_INDEX"' "top=1\nuname X=2"

# The call history should have been deleted when a stub was cleaned
__stub_call_history_array "uname"
assert 'echo "${#call_history[@]}"' "0"

__stub_call_history_array "uname X"
assert 'echo "${call_history[@]}"' "Y"
__stub_call_history_array "top"
assert 'echo "${call_history[@]}"' "-h"

__stub_clean "uname X"
assert 'echo "$STUB_INDEX"' "top=1"
__stub_call_history_array "top"
assert 'echo "${call_history[@]}"' "-h"
__stub_call_history_array "uname X"
assert 'echo "${#call_history[@]}"' "0"

# End of tests.
assert_end "__stub_clean()"
