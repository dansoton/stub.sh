# !/usr/bin/env bash
# stub.sh 0.2.0 - stubbing helpers for simplifying bash script tests.
# Copyright (c) 2014 Jim Myhrberg.
#
# https://github.com/jimeh/stub.sh
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to
# deal in the Software without restriction, including without limitation the
# rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
# sell copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
# IN THE SOFTWARE.
#


# Public: Stub given command, echoing a default stub message.
#
# Arguments:
#   - $1: Name of command to stub.
#   - $2: When set to "STDERR", echo to STDERR instead of STDOUT.
#         When set to "null", all output is redirected to /dev/null.
#
# Echoes nothing.
# Returns nothing.
stub() {
  local redirect="null"
  if [ "$2" == "stdout" ] || [ "$2" == "STDOUT" ]; then redirect=""; fi
  if [ "$2" == "stderr" ] || [ "$2" == "STDERR" ]; then redirect="stderr"; fi

  stub_and_echo "$1" "$1 stub: \$@" "$redirect"
}


# Public: Stub given command, and echo given string.
#
# Arguments:
#   - $1: Name of command to stub.
#   - $2: String to echo when stub is called.
#   - $3: When set to "STDERR", echo to STDERR instead of STDOUT.
#         When set to "null", all output is redirected to /dev/null.
#
# Echoes nothing.
# Returns nothing.
stub_and_echo() {
  local redirect=""
  if [ "$3" == "stderr" ] || [ "$3" == "STDERR" ]; then redirect=" 1>&2"; fi
  if [ "$3" == "null" ]; then redirect=" &>/dev/null"; fi

  stub_and_eval "$1" "echo \"$2\"$redirect"
}


# Public: Stub given command, and execute given string with eval.
#
# Arguments:
#   - $1: Name of command to stub.
#   - $2: String to eval when stub is called.
#
# Echoes nothing.
# Returns nothing.
stub_and_eval() {
  local cmd="$1"

  # Setup empty list of active stubs.
  if [ -z "$STUB_ACTIVE_STUBS" ]; then STUB_ACTIVE_STUBS=(); fi

  # If stubbing a function, store non-stubbed copy of it required for restore.
  if [ -n "$(command -v "$cmd")" ]; then
    if [ -z "$(command -v "non_stubbed_${cmd}")" ]; then
      if [[ "$(type "$cmd" | head -1)" == *"is a function" ]]; then
        local source="$(type "$cmd" | tail -n +2)"
        source="${source/$cmd/non_stubbed_${cmd}}"
        eval "$source"
      fi
    fi
  fi

  # Keep track of what is currently stubbed to ensure restore only acts on
  # actual stubs.
  if [[ " ${STUB_ACTIVE_STUBS[@]} " != *" $1 "* ]]; then
    STUB_ACTIVE_STUBS+=("$cmd")
  fi

  # Create the stub.
  eval "$(echo -e "${cmd}() {\n  $2\n}")"
}


# Public: Restore the original command/function that was stubbed.
#
# Arguments:
#   - $1: Name of command to restore.
#
# Echoes nothing.
# Returns nothing.
restore() {
  local cmd="$1"

  # Don't do anything if the command isn't currently stubbed.
  if [[ " ${STUB_ACTIVE_STUBS[@]} " != *" $1 "* ]]; then
    return 0
  fi

  # Remove stub functions.
  unset -f "$cmd"

  # Remove stub from list of active stubs.
  STUB_ACTIVE_STUBS=(${STUB_ACTIVE_STUBS[@]/$cmd/})

  # If stub was for a function, restore the original function.
  if type "non_stubbed_${cmd}" &>/dev/null; then
    if [[ "$(type "non_stubbed_${cmd}" | head -1)" == *"is a function" ]]; then
      local source="$(type "non_stubbed_$cmd" | tail -n +2)"
      source="${source/non_stubbed_${cmd}/$cmd}"
      eval "$source"
      unset -f "non_stubbed_${cmd}"
    fi
  fi
}
