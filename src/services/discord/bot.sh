#!/usr/bin/env bash

discord_bot_ensure_running() {
  local service_root
  local bot_entrypoint
  local pid_file
  local log_file
  local bot_pids
  local bot_count
  local bot_pid

  service_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)
  bot_entrypoint="$service_root/discord/lib/bot.js"
  pid_file="$service_root/vars/pids/discord-bot.pid"
  log_file="$service_root/vars/logs/discord.log"

  bot_pids=$(ps -ax -o pid=,command= | awk -v entrypoint="$bot_entrypoint" 'index($0, entrypoint) && $0 !~ /awk/ {print $1}')
  bot_count=$(printf '%s\n' "$bot_pids" | awk 'NF {c++} END {print c+0}')

  if ((bot_count > 1)); then
    printf '%s|ERROR|meeting_record|32|discord_bot|duplicate_processes_detected\n' \
      "$(date -Iseconds)" >>"$log_file"
    return 32
  fi

  if ((bot_count == 1)); then
    bot_pid=$(printf '%s\n' "$bot_pids" | awk 'NR==1 {print; exit}')
    printf '%s\n' "$bot_pid" >"$pid_file"
    return 0
  fi

  nohup "$HOME/homebrew/bin/node" "$bot_entrypoint" >>"$log_file" 2>&1 &
  bot_pid=$!
  printf '%s\n' "$bot_pid" >"$pid_file"

  sleep 1
  if kill -0 "$bot_pid" 2>/dev/null; then
    return 0
  fi

  printf '%s|ERROR|meeting_record|30|discord_bot|start_failed\n' \
    "$(date -Iseconds)" >>"$log_file"
  return 30
}
