#! /usr/bin/env bash
source "test-helper.sh"

#
# stub_and_eval() tests.
#


# Stubbing a bash function.
my-name-is() { echo "My name is $@."; }
assert "my-name-is Edward Elric" "My name is Edward Elric."

stub_and_eval "my-name-is" "date +%Y"
assert "my-name-is" "$(date +%Y)"
assert "my-name-is Edward" "$(date +%Y)"
assert "my-name-is Edward Elric" "$(date +%Y)"
restore my-name-is


# Stubbing a executable file.
stub_and_eval "uname" "date +%Y"
assert "uname" "$(date +%Y)"
assert "uname -h" "$(date +%Y)"
restore uname


# Stubbing something that doesn't exist.
stub_and_eval "cowabunga-dude" "date +%Y"
assert "cowabunga-dude" "$(date +%Y)"
assert "cowabunga-dude yeah dude" "$(date +%Y)"
restore cowabunga-dude


# Stubbing a sub-command (command + argument combinations)
assert "seq 3" "1\n2\n3"
stub_and_eval "seq 4" "date +%Y"
assert "seq 3" "1\n2\n3"
assert "seq 4" "$(date +%Y)"
restore "seq 4"
assert "seq 4" "1\n2\n3\n4"


# Stubbing sub-command ensuring it splits stubs on whole arguments only
assert "seq 3" "1\n2\n3"
stub_and_eval "seq 1" "date +%Y"
assert "seq 1" "$(date +%Y)"
assert "seq 10" "1\n2\n3\n4\n5\n6\n7\n8\n9\n10"
restore "seq 1"


# Stubbing sub-command and base command
assert "seq 3" "1\n2\n3"
stub_and_eval "seq 4" "date +%Y"
stub_and_eval "seq" "date +%m"
assert "seq 3" "$(date +%m)"
assert "seq 4" "$(date +%Y)"
restore "seq 4"
restore "seq"
assert "seq 3" "1\n2\n3"
assert "seq 4" "1\n2\n3\n4"


# Check stubbing sub-commands keeps track of the number and removes the
# stub function when all stubs of that command have been restored
# First check seq is not a function, but the real cmd
assert_raises "type seq | grep 'seq is a function' &> /dev/null" 1
stub_and_eval "seq 4" "date +%Y"
# After stubbing 'seq 4' 'seq' itself should be a stubbing function
# (it would delegate to the real 'seq' for anything not starting 'seq 4')
assert_raises "type seq | grep 'seq is a function' &> /dev/null" 0
stub_and_eval "seq 2" "date +%Y"
restore "seq 4"
# After another stub and a restore, we still have one stub combination
assert_raises "type seq | grep 'seq is a function' &> /dev/null" 0
stub_and_eval "seq" "date +%Y"
stub_and_eval "seq 1" "date +%Y"
restore "seq"
restore "seq 2"
# After another 2 stubs and restores, we still have one stub combination
assert_raises "type seq | grep 'seq is a function' &> /dev/null" 0
restore "seq 1"
# Finally after the last restore, seq should go back to be the real cmd
assert_raises "type seq | grep 'seq is a function' &> /dev/null" 1

# End of tests.
assert_end "stub_and_eval()"
