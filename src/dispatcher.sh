#!/usr/bin/env bash

dispatch() (
  local action=$1
  shift

  local action_name
  local log_file
  local _action_output
  local code
  local level
  local status
  local message
  local response
  local details

  action_name=${action%_controller}
  log_file="$(dirname "${BASH_SOURCE[0]}")/../vars/logs/$action_name.log"

  if _action_output=$("$action" "$@"); then
    code=0
    level=INFO
    status=SUCCESS
    message='Action completed'
  else
    code=$?
    level=ERROR
    status=ERROR
    message='Action failed'
  fi

  response=$(jq -cjn \
    --arg status "$status" \
    --arg action "$action_name" \
    --arg message "$message" \
    '{status: $status, action: $action, message: $message}')

  if details=$(printf '%s' "$_action_output" | jq -ce \
    'select(type == "object" and .runner_details == true) | del(.runner_details)' 2>/dev/null); then
    response=$(jq -cn --argjson response "$response" --argjson details "$details" \
      '$response + $details')
  fi

  printf '%s|%s|%s|%s|dispatch\n' \
    "$(date -Iseconds)" "$level" "$action_name" "$code" >>"$log_file"

  printf '%s\n' "$response"
  return "$code"
)
