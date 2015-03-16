#! /usr/bin/env bash
source "test-helper.sh"

#
# stub() tests.
#


# Stubbing a bash function.
my-name-is() { echo "My name is $@."; }
assert "my-name-is Edward Elric" "My name is Edward Elric."
stub "my-name-is"
assert "my-name-is" ""
restore my-name-is


# Stubbing a executable file.
stub "uname"
assert "uname" ""
restore uname


# Redirect stub of bash function output to STDOUT.
my-name-is() { echo "My name is $@."; }
stub "my-name-is" STDOUT
assert "my-name-is" "my-name-is stub: "
assert "my-name-is Edward" "my-name-is stub: Edward"
assert "my-name-is Edward Elric" "my-name-is stub: Edward Elric"
restore my-name-is


# Redirect stub of executable file output to STDOUT.
stub "uname" STDOUT
assert "uname" "uname stub: "
assert "uname -r" "uname stub: -r"
restore uname


# Redirect stub of bash function output to STDERR.
my-name-is() { echo "My name is $@."; }
stub "my-name-is" STDERR
assert "my-name-is Edward" ""
assert "my-name-is Edward 2>&1" "my-name-is stub: Edward"
restore my-name-is


# Redirect stub of executable output to STDERR.
stub "uname" STDERR
assert "uname -r" ""
assert "uname 2>&1" "uname stub: "
assert "uname -r 2>&1" "uname stub: -r"
restore uname


# Redirect stub of bash function output to /dev/null.
my-name-is() { echo "My name is $@."; }
stub "my-name-is" null
assert "my-name-is Edward" ""
assert "my-name-is Edward 2>&1" ""
restore my-name-is


# Stubbing something that doesn't exist.
assert_raises "cowabunga-dude" 127
stub "cowabunga-dude" stdout
assert_raises "cowabunga-dude" 0
assert "cowabunga-dude yeah dude" "cowabunga-dude stub: yeah dude"
restore cowabunga-dude


# Stubbing a sub-command (command + argument combinations)
assert "seq 3" "1\n2\n3"
stub "seq 4"
assert "seq 3" "1\n2\n3"
assert "seq 4" ""
restore "seq 4"
assert "seq 4" "1\n2\n3\n4"


# Stubbing 2 sub-commands with 1 having output to STDOUT
assert "seq 3" "1\n2\n3"
stub "seq 4" STDOUT
stub "seq 2"
assert "seq 3" "1\n2\n3"
assert "seq 4" "seq 4 stub: "
assert "seq 4 ok" "seq 4 stub: ok"
assert "seq 2" ""
restore "seq 2"
restore "seq 4"
assert "seq 2" "1\n2"
assert "seq 4" "1\n2\n3\n4"


# Stubbing sub-command ensuring it splits stubs on whole arguments only
assert "seq 3" "1\n2\n3"
stub "seq 1"
assert "seq 1" ""
assert "seq 10" "1\n2\n3\n4\n5\n6\n7\n8\n9\n10"
restore "seq 1"


# Stubbing sub-command and base command
assert "seq 3" "1\n2\n3"
stub "seq 4" STDOUT
stub "seq" STDERR
assert "seq 3" ""
assert "seq 3 2>&1" "seq stub: 3"
assert "seq 4" "seq 4 stub: "
restore "seq 4"
restore "seq"
assert "seq 3" "1\n2\n3"
assert "seq 4" "1\n2\n3\n4"


# Check stubbing sub-commands keeps track of the number and removes the
# stub function when all stubs of that command have been restored
# First check seq is not a function, but the real cmd
assert_raises "type seq | grep 'seq is a function' &> /dev/null" 1
stub "seq 4"
# After stubbing 'seq 4' 'seq' itself should be a stubbing function
# (it would delegate to the real 'seq' for anything not starting 'seq 4')
assert_raises "type seq | grep 'seq is a function' &> /dev/null" 0
stub "seq 2"
restore "seq 4"
# After another stub and a restore, we still have one stub combination
assert_raises "type seq | grep 'seq is a function' &> /dev/null" 0
stub "seq"
stub "seq 1"
restore "seq"
restore "seq 2"
# After another 2 stubs and restores, we still have one stub combination
assert_raises "type seq | grep 'seq is a function' &> /dev/null" 0
restore "seq 1"
# Finally after the last restore, seq should go back to be the real cmd
assert_raises "type seq | grep 'seq is a function' &> /dev/null" 1

# End of tests.
assert_end "stub()"
