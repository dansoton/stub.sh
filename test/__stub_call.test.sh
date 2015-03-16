#! /usr/bin/env bash
source "test-helper.sh"

#
# __stub_call() tests.
#

# Adds call to stub call list.
STUB_INDEX="uname=0
uname X=1"

__stub_call "uname" 0
__stub_call "uname" 0 -r
__stub_call "uname" 0 -r -a

__stub_call "uname X" 1
__stub_call "uname X" 1 Y
__stub_call "uname X" 1 Y Z

# Invoking __stub_call_history_array sets the call_history array
__stub_call_history_array "uname"

assert 'echo ${call_history[@]}' "<none> -r -r -a"
assert 'echo ${call_history[0]}' "<none>"
assert 'echo ${call_history[1]}' "-r"
assert 'echo ${call_history[2]}' "-r -a"

__stub_call_history_array "uname X"

assert 'echo ${call_history[0]}' "<none>"
assert 'echo ${call_history[1]}' "Y"
assert 'echo ${call_history[2]}' "Y Z"

# End of tests.
assert_end "__stub_call()"
