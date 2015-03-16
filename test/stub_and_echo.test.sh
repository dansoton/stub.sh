#! /usr/bin/env bash
source "test-helper.sh"

#
# stub_and_echo() tests.
#

function _number_of_lines() {
    # Trim whitespace from wc for compatibility with BSD's wc cmd (Mac OS)
    echo "$1" | wc -l | tr -d '[[:space:]]'
}

# Stubbing a bash function.
my-name-is() { echo "My name is $@."; }
assert "my-name-is Edward Elric" "My name is Edward Elric."

stub_and_echo "my-name-is" "Hohenheim"
assert "my-name-is" "Hohenheim"
assert "my-name-is Edward" "Hohenheim"
assert "my-name-is Edward Elric" "Hohenheim"
restore my-name-is


# Stubbing a executable file.
stub_and_echo "uname" "State Alchemist"
assert "uname" "State Alchemist"
assert "uname -h" "State Alchemist"
restore uname


# Redirect stub output to STDERR.
my-name-is() { echo "My name is $@."; }
stub_and_echo "my-name-is" "Hohenheim" STDERR
assert "my-name-is Edward" ""
assert "my-name-is Edward 2>&1" "Hohenheim"
restore my-name-is


# Stubbing something that doesn't exist.
stub_and_echo "cowabunga-dude" "Surf's up dude :D"
assert "cowabunga-dude" "Surf's up dude :D"
assert "cowabunga-dude yeah dude" "Surf's up dude :D"
restore cowabunga-dude


# Stubbing a multi-line echo
multiline_string="{
    'testing': 'multi-line values are echoed correctly when stubbed'
}"
stub_and_echo "print-sample-json" "$multiline_string"
assert "print-sample-json" "$multiline_string"
assert '_number_of_lines "$(print-sample-json)"' "3"
restore print-sample-json
unset multiline_string
unset string_echoed


# Stubbing a sub-command (command + argument combinations)
assert "seq 3" "1\n2\n3"
stub_and_echo "seq 4" "1 4 9 16"
assert "seq 3" "1\n2\n3"
assert "seq 4" "1 4 9 16"
restore "seq 4"
assert "seq 4" "1\n2\n3\n4"


# Stubbing 2 sub-commands with 1 having output to STDERR
assert "seq 3" "1\n2\n3"
stub_and_echo "seq 4" "1 4 9 16" STDERR
stub_and_echo "seq 2" "1 8"
assert "seq 3" "1\n2\n3"
assert "seq 4" ""
assert "seq 4 2>&1" "1 4 9 16"
assert "seq 2" "1 8"
assert "seq 2 ok" "1 8"
restore "seq 2"
restore "seq 4"
assert "seq 2" "1\n2"
assert "seq 4" "1\n2\n3\n4"


# Stubbing sub-command ensuring it splits stubs on whole arguments only
assert "seq 3" "1\n2\n3"
stub_and_echo "seq 1" "100"
assert "seq 1" "100"
assert "seq 10" "1\n2\n3\n4\n5\n6\n7\n8\n9\n10"
restore "seq 1"


# Stubbing sub-command and base command
assert "seq 3" "1\n2\n3"
stub_and_echo "seq 4" "1 4 9 16"
stub_and_echo "seq" 'Args: $@'
assert "seq 3" "Args: 3"
assert "seq 4" "1 4 9 16"
restore "seq 4"
restore "seq"
assert "seq 3" "1\n2\n3"
assert "seq 4" "1\n2\n3\n4"


# Check stubbing sub-commands keeps track of the number and removes the
# stub function when all stubs of that command have been restored
# First check seq is not a function, but the real cmd
assert_raises "type seq | grep 'seq is a function' &> /dev/null" 1
stub_and_echo "seq 4" "1 4 9 16"
# After stubbing 'seq 4' 'seq' itself should be a stubbing function
# (it would delegate to the real 'seq' for anything not starting 'seq 4')
assert_raises "type seq | grep 'seq is a function' &> /dev/null" 0
stub_and_echo "seq 2" "1 4"
restore "seq 4"
# After another stub and a restore, we still have one stub combination
assert_raises "type seq | grep 'seq is a function' &> /dev/null" 0
stub_and_echo "seq" "seq base stub"
stub_and_echo "seq 1" "100"
restore "seq"
restore "seq 2"
# After another 2 stubs and restores, we still have one stub combination
assert_raises "type seq | grep 'seq is a function' &> /dev/null" 0
restore "seq 1"
# Finally after the last restore, seq should go back to be the real cmd
assert_raises "type seq | grep 'seq is a function' &> /dev/null" 1

# End of tests.
assert_end "stub_and_echo()"
