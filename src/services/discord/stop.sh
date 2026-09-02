#!/usr/bin/env bash

discord_bot_pids() {
  local bot
  bot="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/bot.js"
  ps -ax -o pid=,command= |
    awk -v bot="$bot" 'index($0, bot) && $0 !~ /awk/ {print $1}'
}

discord_meeting_stop() {
  local command_id=$1 vars=$2 status elapsed=0

  rm -f "$vars/status/$command_id"
  printf stop >"$vars/commands/$command_id"

  while ((elapsed < 20)); do
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

discord_stop_bot() {
  local root vars command_id='' pids pid command_failed=0 forced=0

  root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)
  vars="$root/vars"
  DISCORD_STOP_OUTCOME=''
  DISCORD_STOP_SESSION_ID=''

  [[ -f $vars/active ]] && command_id=$(<"$vars/active")
  if [[ -n $command_id && -f $vars/sessions/$command_id ]]; then
    DISCORD_STOP_SESSION_ID=$(<"$vars/sessions/$command_id")
  fi

  pids=$(discord_bot_pids)
  if [[ -z $pids ]]; then
    [[ -n $command_id ]] && rm -f "$vars"/{pids,commands,status,sessions}/"$command_id" "$vars/active"
    DISCORD_STOP_OUTCOME=offline
    return 0
  fi

  [[ -n $command_id ]] && discord_meeting_stop "$command_id" "$vars" || command_failed=1

  for pid in $(discord_bot_pids); do kill "$pid" 2>/dev/null || true; done
  sleep 2

  pids=$(discord_bot_pids)
  if [[ -n $pids ]]; then
    forced=1
    for pid in $pids; do kill -9 "$pid" 2>/dev/null || true; done
    sleep 1
  fi

  if [[ -n $(discord_bot_pids) ]]; then
    DISCORD_STOP_OUTCOME=persistent_failure
    return 41
  fi

  [[ -n $command_id ]] && rm -f "$vars"/{pids,commands,status,sessions}/"$command_id" "$vars/active"

  if ((command_failed)); then
    DISCORD_STOP_OUTCOME=degraded
  elif ((forced)); then
    DISCORD_STOP_OUTCOME=forced
  else
    DISCORD_STOP_OUTCOME=normal
  fi
}
