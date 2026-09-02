#!/usr/bin/env bash

discord_bot_alive() {
  local pid=$1
  [[ -n $pid ]] && kill -0 "$pid" 2>/dev/null
}

discord_meeting_stop() {
  local command_id=$1 vars=$2 status elapsed=0

  rm -f "$vars/status/$command_id"
  printf stop >"$vars/commands/$command_id"

  while ((elapsed < 8)); do
    if [[ -f $vars/status/$command_id ]]; then
      status=$(<"$vars/status/$command_id")
      [[ $status == success ]] && return 0
      [[ $status == error ]] && return 40
    fi
    sleep 1
    elapsed=$((elapsed + 1))
  done

  return 40
}

# shellcheck disable=SC2034 # session_id is assigned through a caller-owned nameref.
discord_stop_bot() {
  local -n session_id_ref=$1
  local root vars command_id='' pid=''

  root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)
  vars="$root/vars"
  session_id_ref=''

  [[ -f $vars/active ]] && command_id=$(<"$vars/active")
  if [[ -n $command_id && -f $vars/sessions/$command_id ]]; then
    session_id_ref=$(<"$vars/sessions/$command_id")
  fi
  [[ -n $command_id && -f $vars/pids/$command_id ]] && pid=$(<"$vars/pids/$command_id")

  if discord_bot_alive "$pid"; then
    discord_meeting_stop "$command_id" "$vars" || true
    kill -9 "$pid" 2>/dev/null || true
    sleep 1
    discord_bot_alive "$pid" && return 41
  fi

  [[ -n $command_id ]] && rm -f "$vars"/{pids,commands,status,sessions}/"$command_id" "$vars/active"
}
