# !/usr/bin/env bash
#
# stub.sh 1.0.2 - stubbing helpers for simplifying bash script tests.
# https://github.com/jimeh/stub.sh
#
# (The MIT License)
#
# Copyright (c) 2014 Jim Myhrberg.
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

# Important we need to export all declarations below so that the stubs are
# accessible from programs under test. Otherwise although the stubs will work
# in the file that directly sources this file, they won't work when invoked
# from inside any commands invoked.
set -a

# Associative arrays are not available in Bash 3
# so we simulate using several arrays that are added to/removed in exactly
# the same order so elements at the same index are associated with each other

__add_stubbed_command() {
  local cmd="$1"

  trace "__add_stubbed_command(): Adding stubbed command: $cmd"

  if [ -n "$(command -v "$cmd")" ]; then
    if [[ "$(type "$cmd" | head -1)" == *"is a function" ]]; then
      debug "Stubbing function: $cmd"
      local stubbing_a_function=0
      local source="$(type "$cmd" | tail -n +2)"
      source="${source/$cmd/non_stubbed_${cmd}}"
      eval "$source"
    else
      # command is not a function so find the fully-qualified path
      # and wrap it in 'non_stubbed' function for use below
      debug "Stubbing command: $cmd"
      local stubbing_a_function=1
      local fully_qualified_cmd=$(which $cmd 2> /dev/null)

      eval 'function non_stubbed_'${cmd}'() {
        '$fully_qualified_cmd' "$@"
      }'
    fi
  else
    # We're stubbing a non-existing cmd/function so set variable to false
    debug "Stubbing unresolvable cmd/function: $cmd"
    local stubbing_a_function=1
  fi

  # Create the stub.
  eval 'function '${cmd}'() {
    __find_stub "'$cmd'" "$@"
    local stub_found=$?

    # If no stub is found then we have not stubbed this particular set of args
    # so call the real command instead
    if [ "$stub_found" == 1 ]; then
      non_stubbed_'$cmd' "$@"
    else
      # Stub found, the following fields are set accordingly:
      # stub_index, cmd_and_args, remaining_args, stub_behavior

      __stub_call "$cmd_and_args" "$stub_index" "${remaining_args[@]}"
      set -- "${remaining_args[@]}"
      eval "$stub_behavior"
    fi
  }'

  __register_stubbed_command "$cmd" "$stubbing_a_function"
}

__register_stubbed_command() {
  local cmd="$1"
  local is_function="$2"

  if [ -z "$STUBBED_COMMAND_NEXT_INDEX" ]; then STUBBED_COMMAND_NEXT_INDEX=0; fi

  # We hold the stub functions in a multi-line string rather than an array
  # as it needs to be environment exportable so that programs that invoke
  # the stub function declared in stub_and_eval can access this variable.
  # Arrays aren't exportable, but strings are.
  local index="$STUBBED_COMMAND_NEXT_INDEX"

  STUBBED_COMMANDS="$(__add_line "$STUBBED_COMMANDS" "$cmd=$index")"

  trace "__register_stubbed_command(): Index $index assigned for stubbed command: $cmd. Stubbed commands now: $STUBBED_COMMANDS"

  __set_variable "STUBBED_COMMAND_${index}" "$cmd"
  __set_variable "STUBBED_COMMAND_${index}_COUNTER" '1'
  __set_variable "STUBBED_COMMAND_${index}_IS_FUNCTION" "$is_function"

  # Increment stubbed command count.
  ((STUBBED_COMMAND_NEXT_INDEX++))
}

__remove_stubbed_command() {
  local cmd="$1"
  local existing_cmd_index="$2"

  # If stub was for a function, restore the original function.
  if __is_stubbed_command_a_function "$existing_cmd_index"; then
    debug "Restoring original function: $cmd"
    local source="$(type "non_stubbed_$cmd" | tail -n +2)"
    source="${source/non_stubbed_${cmd}/$cmd}"
    eval "$source"
  else
    # Otherwise just remove the stub function
    debug "Removing stub function: $cmd"
    unset -f "$cmd"
  fi

  # Remove the non-stubbed function.
  unset -f "non_stubbed_${cmd}"

  # Finally remove stub from list of active stubs.
  __deregister_stubbed_command "$cmd"
}

__deregister_stubbed_command() {
  local cmd="$1"

  STUBBED_COMMANDS="$(__remove_index_line "$STUBBED_COMMANDS" "$cmd")"

  trace "__deregister_stubbed_command(): Removing stubbed command: $cmd. Stubbed commands now: $STUBBED_COMMANDS"

  unset "STUBBED_COMMAND_${existing_cmd_index}"
  unset "STUBBED_COMMAND_${existing_cmd_index}_COUNTER"
  unset "STUBBED_COMMAND_${existing_cmd_index}_IS_FUNCTION"
}

__stubbed_command_index() {
  local cmd="$1"
  local index_matched=$(echo "$STUBBED_COMMANDS" | $SED -rn 's/^'"${cmd}"'=(.)/\1/p')

  if [ -n "$index_matched" ]; then
    trace "__stubbed_command_index(): Index matched for stubbed command '$cmd': $index_matched"
    echo "$index_matched"
  else
    trace "__stubbed_command_index(): No index matched for stubbed command '$cmd'"
    return 1
  fi
}

__increment_stubbed_command_counter() {
  __update_stubbed_command_counter "$@" "1"
}

__decrement_stubbed_command_counter() {
  __update_stubbed_command_counter "$@" "-1"
}

__update_stubbed_command_counter() {
  local cmd="$1"
  if [ $# == 3 ]; then
    local existing_cmd_index="$2"
    shift
  fi

  local increment="$2"

  local current_count=$(__stubbed_command_counter "$cmd" "$existing_cmd_index")
  local new_count=$(($current_count + $increment))

  debug "__update_stubbed_command_counter(): Updating counter for cmd '$cmd'" \
        "(index '$existing_cmd_index') by adding $increment." \
        "Current count: $current_count; new count: $new_count"

  __set_variable "STUBBED_COMMAND_${existing_cmd_index}_COUNTER" "$new_count"
}

__stubbed_command_counter() {
  local cmd="$1"
  local existing_cmd_index="$2"

  if [ -z "$existing_cmd_index" ]; then existing_cmd_index=$(__stubbed_command_index "$cmd"); fi

  eval "echo \"\$STUBBED_COMMAND_${existing_cmd_index}_COUNTER\""
}

__is_stubbed_command_a_function() {
  local existing_cmd_index="$1"
  return $(eval "echo \"\$STUBBED_COMMAND_${existing_cmd_index}_IS_FUNCTION\"")
}

__add_line() {
  local existing_contents="$1"
  local line="$2"

  if [ -n "$existing_contents" ]; then
    echo "$existing_contents"$'\n'"$line"
  else
    echo "$line"
  fi
}

__remove_index_line() {
  local existing_contents="$1"
  local cmd_to_remove="$2"

  echo "$existing_contents" | $SED "/^${cmd_to_remove}=/d"
}


# Public: Stub given command.
#
# Arguments:
#   - $1: Name of command to stub.
#   - $2: (optional) When set to "STDOUT", echo a default message to STDOUT.
#         When set to "STDERR", echo default message to STDERR.
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
#   - $3: (optional) When set to "STDERR", echo to STDERR instead of STDOUT.
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

# Public: Stub given command, and tracks if it is called.
# Then error_stub_called can be subsequently called to check if any stubs
# created using this function have been called as the purpose of using this
# stubbing function it to ensure they haven't been.
#
# Arguments:
#   - $1: Name of command to stub.
#   - $2: (optional) When set to "STDOUT", echo a default message to STDOUT.
#         When set to "STDERR", echo default message to STDERR.
#
# Echoes nothing.
# Returns nothing.
stub_and_error() {
  local msg="$1 stubbed to be an 'error-stub' and exit with return code of 1"
  local output=
  if [ "$2" == "stdout" ] || [ "$2" == "STDOUT" ]; then output="echo '$msg';"; fi
  if [ "$2" == "stderr" ] || [ "$2" == "STDERR" ]; then output="echo '$msg' >&2;"; fi

  stub_and_eval "$1" "$output return 1" "true"
}



stub_and_raise() {
  local cmd="$1"
  local rc="${2:-1}"

  local msg="$cmd stubbed to exit with return code of $rc"
  local output=
  if [ "$2" == "stdout" ] || [ "$2" == "STDOUT" ]; then output="echo '$msg';"; fi
  if [ "$2" == "stderr" ] || [ "$2" == "STDERR" ]; then output="echo '$msg' >&2;"; fi

  stub_and_eval "$1" "$output return $rc"
}


# Public: Stub given command, and execute given string with eval.
#
# Arguments:
#   - $1: Name of command to stub.
#   - $2: String to eval when stub is called.
#   - $3: (optional) boolean flag to whether this stub is an 'error stub' and
#         so should not be called.
#         Error stubs call history is tracked by error_stubs_called function.
#
# Echoes nothing.
# Returns nothing.
stub_and_eval() {
  # Parse the command into the following values:
  # cmd, cmd_args, cmd_and_args
  __parse_cmd "$1"

  debug "stub_and_eval: Stubbing: '$1' to invoke: $2"

  # First remove any existing stub so we can add it again correctly below
  restore "$cmd_and_args"

  # Keep track of what is currently stubbed to ensure restore only acts on
  # actual stubs.
  local existing_cmd_index=$(__stubbed_command_index "$cmd")
  if [ -n "$existing_cmd_index" ]; then
    # Increment cmd counter as adding a new stub for this command
    __increment_stubbed_command_counter "$cmd" "$existing_cmd_index" > /dev/null
  else
    # If stubbing a function, store non-stubbed copy of it required for restore.
    __add_stubbed_command "$cmd"
  fi

  # Prepare stub index and call list for this stub.
  __stub_register "$1" "$2" "$3"
}


error_stubs_not_called() {
  local error_stubs=()
  while read index_line; do
    local cmd_and_args=${index_line%%=*}
    local stub_index=${index_line#*=}

    error_stubs+=("$cmd_and_args")
  done <<< "$ERROR_STUB_INDEX"

  local error_stubs_called=()
  for error_stub in "${error_stubs[@]}"; do
    if stub_called "$error_stub"; then
      error_stubs_called+=("$error_stub");
    fi
  done

  debug "Checking if any error stubs called: ${#error_stubs_called[@]} called"\
        "out of ${#error_stubs[@]} error stubs. Stubs called:" \
        $(__as_csv "${error_stubs_called[@]}")

  if [ "${#error_stubs_called[@]}" != 0 ]; then
    echo "${error_stubs_called[@]}"
    return 1
  fi
}

# Public: Find out if stub has been called. Returns 0 if yes, 1 if no.
#
# Arguments:
#   - $1: Name of stubbed command.
#
# Echoes nothing.
# Returns 0 (success) is stub has been called, 1 (error) otherwise.
stub_called() {
  if [ "$(stub_called_times "$1")" -lt 1 ]; then
    return 1
  fi
}


# Public: Find out if stub has been called with specific arguments.
#
# Arguments:
#   - $1: Name of stubbed command.
#   - $@: Any/all additional arguments are used to specify what stub was
#         called with.
#
# Examples:
#   stub uname
#   uname
#   uname -r -a
#   stub_called_with uname       # Returns 0 (success).
#   stub_called_with uname -r    # Returns 1 (error).
#   stub_called_with uname -r -a # Returns 0 (success).
#
# Echoes nothing.
# Returns 0 (success) if specified stub has been called with given arguments,
# otherwise returns 1 (error).
stub_called_with() {
  __parse_cmd "$1"
  shift 1

  if [ "$(stub_called_with_times "$cmd_and_args" "$@")" -lt 1 ]; then
    return 1
  fi
}


# Public: Find out how many times a stub has been called.
#
# Arguments:
#   - $1: Name of stubbed command.
#
# Echoes number of times stub has been called if $2 is not given, otherwise
# echoes nothing.
# Returns 0 (success) if $2 is not given, or if it is given and it matches the
# number of times the stub has been called. Otherwise 1 (error) is returned if
# it doesn't match..
stub_called_times() {
  __parse_cmd "$1"

  # Loads the call history into the 'call_history' array variable
  __stub_call_history_array "$cmd_and_args"

  echo "${#call_history[@]}"
}


# Public: Find out if stub has been called exactly the given number of times
# with specified arguments.
#
# Arguments:
#   - $1: Name of stubbed command.
#   - $2: Exact number of times stub has been called.
#
# Echoes nothing.
# Returns 0 (success) if stub has been called at least the given number of
# times with specified arguments, otherwise 1 (error) is returned.
stub_called_exactly_times() {
  if [ "$(stub_called_times "$1")" != "$2" ]; then
    return 1
  fi
}


# Public: Find out if stub has been called at least the given number of times.
#
# Arguments:
#   - $1: Name of stubbed command.
#   - $2: Minimum required number of times stub has been called.
#
# Echoes nothing.
# Returns 0 (success) if stub has been called at least the given number of
# times, otherwise 1 (error) is returned.
stub_called_at_least_times() {
  if [ "$(stub_called_times "$1")" -lt "$2" ]; then
    return 1
  fi
}


# Public: Find out if stub has been called no more than the given number of
# times.
#
# Arguments:
#   - $1: Name of stubbed command.
#   - $2: Maximum allowed number of times stub has been called.
#
# Echoes nothing.
# Returns 0 (success) if stub has been called no more than the given number of
# times, otherwise 1 (error) is returned.
stub_called_at_most_times() {
  if [ "$(stub_called_times "$1")" -gt "$2" ]; then
    return 1
  fi
}


# Public: Find out how many times a stub has been called with specific
# arguments.
#
# Arguments:
#   - $1: Name of stubbed command.
#   - $@: Any/all additional arguments are used to specify what stub was
#         called with.
#
# Echoes number of times stub has been called with given arguments.
# Return 0 (success).
stub_called_with_times() {
  __parse_cmd "$1"
  shift 1

  local args=("$@")
  if [ "$args" == "" ]; then args=("<none>"); fi

  local count=0

  __quote_args "${args[@]}"

  # Loads the call history into the 'call_history' array variable
  __stub_call_history_array "$cmd_and_args"

  for call in "${call_history[@]}"; do
    if [ "$call" == "${quoted_args[*]}" ]; then ((count++)); fi
  done

  echo $count
}


# Public: Find out if stub has been called exactly the given number of times
# with specified arguments.
#
# Arguments:
#   - $1: Name of stubbed command.
#   - $2: Exact number of times stub has been called.
#   - $@: Any/all additional arguments are used to specify what stub was
#         called with.
#
# Echoes nothing.
# Returns 0 (success) if stub has been called at least the given number of
# times with specified arguments, otherwise 1 (error) is returned.
stub_called_with_exactly_times() {
  __parse_cmd "$1"
  local count="$2"
  shift 2

  if [ "$(stub_called_with_times "$cmd_and_args" $@)" != "$count" ]; then
    return 1
  fi
}


# Public: Find out if stub has been called at least the given number of times
# with specified arguments.
#
# Arguments:
#   - $1: Name of stubbed command.
#   - $2: Minimum required number of times stub has been called.
#   - $@: Any/all additional arguments are used to specify what stub was
#         called with.
#
# Echoes nothing.
# Returns 0 (success) if stub has been called at least the given number of
# times with specified arguments, otherwise 1 (error) is returned.
stub_called_with_at_least_times() {
  __parse_cmd "$1"
  local count="$2"
  shift 2

  if [ "$(stub_called_with_times "$cmd_and_args" $@)" -lt "$count" ]; then
    return 1
  fi
}


# Public: Find out if stub has been called no more than the given number of
# times.
#
# Arguments:
#   - $1: Name of stubbed command.
#   - $2: Maximum allowed number of times stub has been called.
#   - $@: Any/all additional arguments are used to specify what stub was
#         called with.
#
# Echoes nothing.
# Returns 0 (success) if stub has been called no more than the given number of
# times with specified arguments, otherwise 1 (error) is returned.
stub_called_with_at_most_times() {
  __parse_cmd "$1"
  local count="$2"
  shift 2

  if [ "$(stub_called_with_times "$cmd_and_args" $@)" -gt "$count" ]; then
    return 1
  fi
}


# Public: Returns the call history of a particular stub if given,
# or all stubs registered if not
#
# Arguments:
#   - $1: Optional: Name of stubbed command.
#
# Echoes the call history of a particular stub if given,
# or all stubs registered if not
# Return 0 (success).
stub_call_history() {
  local cmd_and_args="$1"

  if [ -n "$cmd_and_args" ]; then
    local call_history=$(__stub_call_history "$cmd_and_args")
  else
    local call_history=$(__all_call_history)
  fi

  if [ -n "$call_history" ]; then
    echo "$call_history"
  fi
}


__all_call_history() {
  debug "Outputting call history for all stubs currently registered (including inactive ones)"

  local number_of_stubs_invoked=0
  while read index_line; do
    local cmd_and_args=${index_line%%=*}
    local stub_index=${index_line#*=}

    local stub_history=$(__stub_call_history "$cmd_and_args" "$stub_index" "  ")

    if [ -n "$stub_history" ]; then
      if [ "$number_of_stubs_invoked" == 0 ]; then
        echo "["
      else
        echo ","
      fi
      echo "$stub_history"
      ((number_of_stubs_invoked++))
    fi
  done <<< "$STUB_INDEX"

  if [ "$number_of_stubs_invoked" != 0 ]; then
    echo "]"
  fi

  debug "Number of different stubs invoked: $number_of_stubs_invoked"
}


__stub_call_history() {
  local cmd_and_args="$1"
  local stub_index="$2"
  local indent="$3"

  if [ -z "$stub_index" ]; then stub_index=$(__stub_index "$cmd_and_args"); fi

  # Get the call history, which sets the 'call_history' array variable
  __stub_call_history_array "$cmd_and_args" "$stub_index"

  if [ "${#call_history[@]}" != 0 ]; then
    debug "Outputting call history for '$cmd_and_args', ${#call_history[@]} calls found."

    echo "$indent{"
    echo "$indent  \"stub\": \"$cmd_and_args\","
    echo "$indent  \"history\": ["

    local calls_processed=0
    for call_index in "${!call_history[@]}"; do
      if [ "$call_index" != 0 ]; then echo ","; fi
      echo -n "$indent    \"${call_history[$call_index]}\""
    done

    echo
    echo "$indent  ]"
    echo -n "$indent}"
  else
    debug "Outputting call history for '$cmd_and_args', no calls found."
  fi
}


__stub_call_history_array() {
  local cmd_and_args="$1"
  local stub_index="$2"

  if [ -z "$stub_index" ]; then stub_index=$(__stub_index "$cmd_and_args"); fi

  local call_history_file=$(__call_history_file "$cmd_and_args" "$stub_index")

  # public call_history variable not local for access after function call.
  call_history=()

  while read line; do
    if [[ -n "$line" && "$line" != \#* ]]; then
      call_history+=("$line")
    fi
  done < "$call_history_file"
}


__array_contents() {
  local array_name="$1"

  # Indirection to iterate through call history array
  # See: http://stackoverflow.com/a/25880676/1161972
  local array_reference="\${$array_name[@]}"
  local contents="${!array_reference}"

  eval "local array=(\"$array_reference\")"

  if [ -n "$contents" ]; then
    echo "${array[@]}"
  fi
}

# Public: Restore the original command/functions that were stubbed.
#
# Arguments:
#   - $@: Name of the commands to restore.
#
# Echoes nothing.
# Returns nothing.
restore() {
  while [ $# != 0 ]; do
    # If an asterisk is specified at the end of the arg then restore all stubs
    # which share the same base command but may have different arguments
    if [[ "$1" =~ (.*)[[:space:]]+\* ]] ; then
      local cmd="${BASH_REMATCH[1]}"

      debug "restore(): Attempting to restore all stubs for the base command '$cmd'"

      local stubs_matched_str=$(echo "$STUBS_ACTIVE" | $SED -rn 's/^('"${cmd}"'([[:space:]]+.+)?)=[[:digit:]]+$/\1/p')
      if [ -n "$stubs_matched_str" ]; then
        local stubs_matched=()
        while read cmd_and_args; do
          __restore "$cmd_and_args"
        done <<< "$stubs_matched_str"
      fi
    else
      __restore "$1"
    fi
    shift
  done
}


# Private: Restores a single original command/function that was stubbed.
#
# Arguments:
#   - $1: Name of the command to restore.
#
# Echoes nothing.
# Returns nothing.
__restore() {
  # Parse the command into the following values:
  # cmd, cmd_args, cmd_and_args
  __parse_cmd "$1"

  # Don't do anything if the command isn't currently stubbed.
  local existing_cmd_index=$(__stubbed_command_index "$cmd")
  if [ -z "$existing_cmd_index" ]; then
    return 0
  fi

  # Again return early if the command and args combination isn't stubbed
  local existing_cmd_and_args_index=$(__active_stub_index "$cmd_and_args")
  if [ -z "$existing_cmd_and_args_index" ]; then
    return 0
  fi

  debug "restore(): Called on stub: '$cmd_and_args'"

  # Now Remove the command and args combination
  STUBS_ACTIVE=$(__remove_index_line "$STUBS_ACTIVE" "$cmd_and_args")

  # Decrement the counter for the cmd stub, and if 0 remove the stub completely
  __decrement_stubbed_command_counter "$cmd" "$existing_cmd_index"

  local stub_cmd_counter=$(__stubbed_command_counter "$cmd" "$existing_cmd_index")
  if [ "$stub_cmd_counter" == 0 ]; then
    debug "restore(): Usage counter for stub function for '$cmd' is now zero,"\
          "so removing stub function."

    __remove_stubbed_command "$cmd" "$existing_cmd_index"
  else
    debug "restore(): Stub function for '$cmd' still in use by" \
          "$stub_cmd_counter other stubs."
  fi
}


#
# Internal functions
#

# Private: Used to keep track of which stubs have been called and how many
# times.
__stub_call() {
  local cmd_and_args="$1"
  local stub_index="$2"
  shift 2

  local args=("$@")
  if [ "$args" == "" ]; then args=("<none>"); fi

  # Create a string of all the args for this call
  # wrapping args with spaces in with quotes first so that the history
  # shows single arguments with spaces in correctly
  __quote_args "${args[@]}"

  local call_history_file=$(__call_history_file "$cmd_and_args" "$stub_index")
  echo "${quoted_args[@]}" >> "$call_history_file"

  trace "__stub_call(): Stub: $cmd_and_args; index: $stub_index; args: ${quoted_args[@]};" \
          "Call history file: $call_history_file"
}


__quote_args() {
  local args=("$@")

  # quoted_args is a public var designed to be read after function completes
  quoted_args=()
  for arg in "${args[@]}"; do
    if [[ "$arg" =~ [[:space:]] ]]; then
      quoted_args+=("'$arg'")
    else
      quoted_args+=("$arg")
    fi
  done
}


# Private: Return the stub index of a particular active command
__active_stub_index() {
  __parse_cmd "$1"

  trace "Looking for active stub index for '$cmd_and_args' from the active stubs:"
  trace "$STUBS_ACTIVE"

  local active_index=$(echo "$STUBS_ACTIVE" | $SED -rn 's/^'"${cmd_and_args}"'=([[:digit:]]+)$$/\1/p')
  if [ -n "$active_index" ]; then
    trace "Stub '$cmd_and_args' is active, index: $active_index"
    echo "$active_index"
  else
    trace "Stub '$cmd_and_args' is not active, so no index to return"
    return 1
  fi
}


# Private: Return the stub index of a particular command
__stub_index() {
  __parse_cmd "$1"

  trace "Looking for stub index for '$cmd_and_args' in index:"$'\n'"$STUB_INDEX"

  local index_matched=
  if [ -n "$STUB_INDEX" ]; then
    index_matched=$(echo "$STUB_INDEX" | $SED -rn 's/^'"${cmd_and_args}"'=([[:digit:]]+)$/\1/p')
  fi

  if [ -n "$index_matched" ]; then
    trace "__stub_index(): Index matched for stub '$cmd_and_args': $index_matched"
    echo "$index_matched"
  else
    trace "__stub_index(): No index matched for stub '$cmd_and_args'"
    return 1
  fi
}


# Private: Prepare for the creation of a new stub. Adds stub to index and
# sets up an empty call list.
__stub_register() {
  __parse_cmd "$1"
  local stub_behavior="$2"
  local error_stub="${3-false}"

  if [ -z "$STUB_NEXT_INDEX" ]; then STUB_NEXT_INDEX=0; fi

  # Clean up after any previous stub for the same command.
  __stub_clean "$cmd_and_args"

  local new_index="${STUB_NEXT_INDEX}"

  # Add stub to index.
  local stub_line="${cmd_and_args}=${new_index}"
  STUB_INDEX="$(__add_line "$STUB_INDEX" "$stub_line")"

  # If an error stub then add to error stub index
  if [ "$error_stub" == "true" ]; then
    ERROR_STUB_INDEX="$(__add_line "$ERROR_STUB_INDEX" "$stub_line")"
  fi

  __set_variable "STUB_${new_index}" "$cmd_and_args"
  __set_variable "STUB_${new_index}_BEHAVIOR" "$stub_behavior"

  is_tracing && trace "__stub_register(): Added: '$stub_line'; (error stub: $error_stub); behavior: $stub_behavior"

  # Add this particular command and args stub to arrays
  STUBS_ACTIVE=$(__add_line "$STUBS_ACTIVE" "$cmd_and_args=$new_index")

  # Increment stub count.
  ((STUB_NEXT_INDEX++))
}


# Private: Cleans out and removes a stub's call list, and removes stub from
# index.
__stub_clean() {
  __parse_cmd "$1"

  local index="$(__stub_index "$cmd_and_args")"

  # Remove all relevant details from any previously existing stub for the same
  # command.
  if [ -n "$index" ]; then
    # Remove the matching element from STUB_INDEX and ERROR_STUB_INDEX
    STUB_INDEX="$(__remove_index_line "$STUB_INDEX" "$cmd_and_args")"
    ERROR_STUB_INDEX="$(__remove_index_line "$ERROR_STUB_INDEX" "$cmd_and_args")"

    eval "unset STUB_${index}"
    eval "unset STUB_${index}_BEHAVIOR"
    rm -f "$(__call_history_file "$cmd_and_args" "$index")"
  fi
}


# Private: Parses the command to stub/restore ($1) into the base command
# and any args that are part of the particular stub
__parse_cmd() {
  cmd_and_args="$1"
  cmd="$cmd_and_args"
  cmd_args=

  # If stubbing a cmd with only specific arguments then we need to split
  # those arguments from the command
  if [[ "$cmd" =~ (([^ ]*) +(.*)) ]]; then
    cmd="${BASH_REMATCH[2]}"
    cmd_args="${BASH_REMATCH[3]}"
  fi
}


# Private: Returns stub information for an existing stub
__find_stub() {
  local cmd="$1"
  shift
  local cmd_args=("$@")
  local remaining_args_in_reverse=()

  ### The variables below are the ones that are designed to be accessible
  #   by the caller after this function completes
  stub_index=
  cmd_and_args=
  remaining_args=()
  stub_behavior=
  ### end of public variables

  is_tracing && trace "__find_stub(): Looking for stub matching '$cmd'" \
                        "and args: '${cmd_args[@]}'."

  while : ; do
    # Create the stub string from the cmd and current args
    local current_cmd_and_args="$cmd"
    if [ "${#cmd_args[@]}" -gt 0 ]; then
      current_cmd_and_args="$cmd ${cmd_args[@]}"
    fi

    trace "__find_stub(): Searching for: '$current_cmd_and_args'"
    stub_index=$(__active_stub_index "$current_cmd_and_args")

    # If no match found and we still have arguments
    # then remove the last argument and look for a stub with those arguments
    if [[ -z "$stub_index" && "${#cmd_args[@]}" -gt 0 ]]; then
      remaining_args_in_reverse+=("${cmd_args[@]:(-1)}")
      unset cmd_args[${#cmd_args[@]}-1]
    else
      # Otherwise break out of the loop
      break
    fi
  done

  # If we've found a matching stub we'll return the necessary information
  if [ -n "$stub_index" ]; then
    # Reverse the remaining args so they are in the right order
    if [ "${#remaining_args_in_reverse[@]}" != 0 ]; then
      local i
      for ((i=${#remaining_args_in_reverse[@]}-1; i>=0; i--)); do
        remaining_args+=("${remaining_args_in_reverse[$i]}")
      done
    fi

    debug "__find_stub(): Found stub: '$current_cmd_and_args'" \
          "(index: $stub_index). Passing these ${#remaining_args[@]} args" \
          "to stub: ${remaining_args[@]}"

    cmd_and_args="$current_cmd_and_args"
    local stub_behavior_variable="STUB_${stub_index}_BEHAVIOR"
    stub_behavior="${!stub_behavior_variable}"
    return 0
  else
    debug "__find_stub(): No stub found for: '$current_cmd_and_args'"
    return 1
  fi
}

CALL_HISTORY_DIRECTORY=".stub-history"
mkdir -p "$CALL_HISTORY_DIRECTORY"
rm -f "$CALL_HISTORY_DIRECTORY/"*

__clean_call_history_on_exit() {
  if [ -z "$STUB_KEEP_CALL_HISTORY" ]; then
    reset_stub_history
    rmdir "$CALL_HISTORY_DIRECTORY"
  fi
}


reset_stub_history() {
  # Safety check before deleting that the CALL_HISTORY_DIRECTORY var is set
  if [ -n "$CALL_HISTORY_DIRECTORY" ]; then
    rm -f "$CALL_HISTORY_DIRECTORY/"*.history
  fi
}


__call_history_file() {
  local cmd_and_args="$1"
  local index="$2"

  local file="$CALL_HISTORY_DIRECTORY/stub_${index}.history"

  # Initialize the file if not already created
  if [ ! -e "$file" ]; then
    echo "# Stub history for: ${cmd_and_args}" > "$file"
    echo -e "# Created on: $(date)\n" >> "$file"
  fi

  echo "$file"
}

# Private: Echos the array index of the element if present; otherwise nothing
__array_index() {
  # Iterate through array (all args from arg 2) looking for arg 1
  local array=("${@:2}")

  local i
  for i in "${!array[@]}"; do
    if [ "$1" == "${array[$i]}" ]; then
      echo "$i";
      return 0
    fi
  done

  return 1
}


# Private: Remove an element from an array by index.
# This safely handles arrays with spaces in their element values
__remove_array_index() {
  local array_name="$1"
  local array_index="$2"

  # Only attempt if an index was actually provided as may be no match
  if [ -n "$array_index" ]; then
    local array_length=$(eval "echo \${#$array_name[@]}")
    if [[ "$array_index" -ge 0 && "$array_index" -lt "$array_length" ]]; then
      eval "unset $array_name[$array_index] && \
            $array_name=(\"\${$array_name[@]}\")"
      return $?
    else
      debug "Invalid array index specified ($array_index). Array name:" \
            "$array_name; array length: $array_length"
      return 1
    fi
  fi
}


# Private: Returns a comma-separated String from the array passed in
__as_csv() {
  local array=("$@")
  local csv=$(printf "%s, " "${array[@]}")
  csv="${csv:0:${#csv}-2}"
  echo "$csv"
}


__set_variable() {
  export $1="$2"
}

# Private: Function to return whether debug information is enabled or not.
is_debugging() {
  [[ "$DEBUG" || "$STUB_TRACE" ]]; return $?
}


# Private: Function to return whether debug information is enabled or not.
is_tracing() {
  [ "$STUB_TRACE" ]; return $?
}


# Private: Function to print debug information to STDERR if debugging is enabled
debug() {
  if is_debugging; then echo "  stub.sh: $@" >&2; else return 1; fi
}


# Private: Function to print trace information to STDERR if tracing is enabled
trace() {
  if is_tracing; then echo "  stub.sh: $@" >&2; else return 1; fi
}

# Returns the resolved command, preferring any gnu-versions of the cmd (prefixed with 'g') on
# non-Linux systems such as Mac OS, and falling back to the standard version if not.
_cmd() {
  local cmd="$1"

  local gnu_cmd="g$cmd"
  local gnu_cmd_found=$(which "$gnu_cmd" 2> /dev/null)
  if [ "$gnu_cmd_found" ]; then
    echo "$gnu_cmd_found"
  else
    if [ "$(uname)" == 'Darwin' ]; then
      echo "Warning: Cannot find gnu version of command '$cmd' ($gnu_cmd) on path." \
           "Falling back to standard command" >&2
    fi
    echo "cmd"
  fi
}

SED=$(_cmd sed)

trap "__clean_call_history_on_exit" EXIT