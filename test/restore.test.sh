#! /usr/bin/env bash
source "test-helper.sh"

#
# restore() tests.
#


# Stubbing and restoring a bash function.
my-name-is() { echo "My name is $@."; }
assert "my-name-is Edward Elric" "My name is Edward Elric."
assert "my-name-is John Doe" "My name is John Doe."

stub "my-name-is" stdout
stub "my-name-is John Doe" stdout

assert "my-name-is Edward Elric" "my-name-is stub: Edward Elric"
assert "my-name-is John Doe" "my-name-is John Doe stub: "

restore "my-name-is"
assert "my-name-is Edward Elric" "My name is Edward Elric."
assert "my-name-is John Doe" "my-name-is John Doe stub: "

restore "my-name-is John Doe"
assert "my-name-is John Doe" "My name is John Doe."


# Stubbing and restoring a executable file.
actual_uname="$(uname)"
actual_uname_m="$(uname -m)"

stub "uname" stdout
stub "uname -m" stdout

assert "uname" "uname stub: "
assert "uname -a" "uname stub: -a"
assert "uname -m" "uname -m stub: "

restore "uname"
assert "uname" "$actual_uname"
assert "uname -m" "uname -m stub: "

restore "uname -m"
assert "uname -m" "$actual_uname_m"

# Stubbing and restoring something that doesn't exist.
assert_raises "cowabunga-dude" 127
stub "cowabunga-dude"
assert_raises "cowabunga-dude" 0
restore "cowabunga-dude"
assert_raises "cowabunga-dude" 127


# Attempting to restore a function that wasn't stubbed.
my-name-is() { echo "My name is $@."; }
assert "my-name-is Edward Elric" "My name is Edward Elric."

restore "my-name-is"
assert "my-name-is Edward Elric" "My name is Edward Elric."


# Stubbing the same function multiple times and then restoring it.
my-name-is() { echo "My name is $@."; }
stub "my-name-is"
assert "my-name-is Edward Elric" ""
stub "my-name-is" stdout
assert "my-name-is Edward Elric" "my-name-is stub: Edward Elric"

restore "my-name-is"
assert "my-name-is Edward Elric" "My name is Edward Elric."


# Ensure restore supports restoring multiple stubs at once
stub "foo"
stub "bar"
stub "baz"

restore "bar" "foo"
assert_raises "type foo | grep 'foo is a function' &> /dev/null" 1
assert_raises "type bar | grep 'bar is a function' &> /dev/null" 1
assert_raises "type baz | grep 'baz is a function' &> /dev/null" 0
restore "baz"
assert_raises "type baz | grep 'baz is a function' &> /dev/null" 1


# Stubbing a function and not restoring it should not prevent
# another stub from being restored. A bug caused this to happen.
stub "foo"
stub "seq"
assert_raises "type seq | grep 'seq is a function' &> /dev/null" 0
restore "seq"
assert_raises "type seq | grep 'seq is a function' &> /dev/null" 1
assert_raises "type foo | grep 'foo is a function' &> /dev/null" 0


# End of tests.
assert_end "restore()"
