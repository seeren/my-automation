#!/usr/bin/env bash

discord_stop_vars_dir() {
  if [[ -n ${DISCORD_STOP_VARS_DIR:-} ]]; then
    printf '%s\n' "$DISCORD_STOP_VARS_DIR"
    return
  fi

  local service_root
  service_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)
  printf '%s/vars\n' "$service_root"
}

discord_meeting_stop_command() {
  local command_id=$1
  local vars_dir status_file status elapsed timeout interval step

  vars_dir=$(discord_stop_vars_dir)
  status_file="$vars_dir/status/$command_id"
  timeout=${DISCORD_STOP_COMMAND_TIMEOUT:-20}
  interval=${DISCORD_STOP_COMMAND_INTERVAL:-1}
  step=$interval
  ((step > 0)) || step=1

  rm -f "$status_file"
  printf 'stop' >"$vars_dir/commands/$command_id"

  elapsed=0
  while ((elapsed < timeout)); do
    if [[ -f $status_file ]]; then
      status=$(<"$status_file")
      [[ $status == success ]] && return 0
      [[ $status == error ]] && return 40
    fi

    sleep "$interval"
    elapsed=$((elapsed + step))
  done

  return 40
}

discord_bot_process_pids() {
  local bot_entrypoint
  bot_entrypoint="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/bot.js"

  ps -ax -o pid=,command= |
    awk -v entrypoint="$bot_entrypoint" 'index($0, entrypoint) && $0 !~ /awk/ {print $1}' |
    paste -sd ' ' -
}

discord_bot_signal() {
  local signal=$1
  local pid=$2
  kill -s "$signal" "$pid" 2>/dev/null || true
}

discord_stop_cleanup() {
  local command_id=$1
  local vars_dir
  vars_dir=$(discord_stop_vars_dir)

  rm -f \
    "$vars_dir/pids/$command_id" \
    "$vars_dir/commands/$command_id" \
    "$vars_dir/status/$command_id" \
    "$vars_dir/sessions/$command_id" \
    "$vars_dir/active"
}

discord_stop_signal_pids() {
  local signal=$1
  local pids=$2
  local pid

  for pid in $pids; do
    discord_bot_signal "$signal" "$pid"
  done
}

discord_stop_bot() {
  local vars_dir active_file command_id initial_pids current_pids remaining_pids
  local command_failed=0 forced=0

  vars_dir=$(discord_stop_vars_dir)
  active_file="$vars_dir/active"
  command_id=''
  [[ -f $active_file ]] && command_id=$(<"$active_file")

  initial_pids=$(discord_bot_process_pids)
  if [[ -z $initial_pids ]]; then
    [[ -n $command_id ]] && discord_stop_cleanup "$command_id"
    printf 'offline\n'
    return 0
  fi

  if [[ -z $command_id ]] || ! discord_meeting_stop_command "$command_id"; then
    command_failed=1
  fi

  current_pids=$(discord_bot_process_pids)
  if [[ -n $current_pids ]]; then
    discord_stop_signal_pids TERM "$current_pids"
  fi

  sleep "${DISCORD_STOP_TERM_WAIT:-2}"
  remaining_pids=$(discord_bot_process_pids)

  if [[ -n $remaining_pids ]]; then
    forced=1
    discord_stop_signal_pids KILL "$remaining_pids"
    sleep "${DISCORD_STOP_KILL_WAIT:-1}"
    remaining_pids=$(discord_bot_process_pids)
  fi

  if [[ -n $remaining_pids ]]; then
    printf 'persistent_failure\n'
    return 41
  fi

  [[ -n $command_id ]] && discord_stop_cleanup "$command_id"

  if ((command_failed)); then
    printf 'degraded\n'
  elif ((forced)); then
    printf 'forced\n'
  else
    printf 'normal\n'
  fi
}
