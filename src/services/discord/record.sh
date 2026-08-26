#!/usr/bin/env bash

discord_record() {
  local service_root
  local command_file
  local status_file
  local log_file
  local command_id
  local elapsed=0

  service_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)
  command_file="$service_root/vars/runtime/discord-command.json"
  status_file="$service_root/vars/runtime/discord-status.json"
  log_file="$service_root/vars/logs/discord.log"
  command_id="record-$(date +%s)-$$"

  printf '{"id":"%s","action":"record"}' "$command_id" >"$command_file"

  while ((elapsed < 25)); do
    if [[ -f $status_file ]]; then
      case $(<"$status_file") in
        *"\"id\":\"$command_id\",\"action\":\"record\",\"status\":\"success\",\"state\":\"recording_started\""*)
          return 0
          ;;
        *"\"id\":\"$command_id\",\"action\":\"record\",\"status\":\"error\",\"state\":\"meeting_error\""*)
          return 31
          ;;
        *"\"id\":\"$command_id\",\"action\":\"record\",\"status\":\"error\",\"state\":\"recording_error\""*)
          return 1
          ;;
      esac
    fi

    sleep 1
    elapsed=$((elapsed + 1))
  done

  printf '%s|ERROR|meeting_record|1|recording|timeout\n' \
    "$(date -Iseconds)" >>"$log_file"
  return 1
}
