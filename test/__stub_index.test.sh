#! /usr/bin/env bash
source "test-helper.sh"

#
# __stub_index() tests.
#

# Echoes array index of given stub (the number to the right of the equals sign)
STUB_INDEX="uname=1
top=3
uname X=0"

assert '__stub_index "uname"' "1"
assert '__stub_index "top"' "3"
assert '__stub_index "uname X"' "0"
unset STUB_INDEX

# Echoes nothing if stub is not in the index.
STUB_INDEX=("uname=1")
assert '__stub_index "top"' ""
unset STUB_INDEX


# End of tests.
assert_end "__stub_index()"
