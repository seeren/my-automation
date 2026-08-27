#!/usr/bin/env bash

discord_bot_start() {
  local command_id=$1
  local service_root
  local bot_entrypoint
  local pid_dir

  service_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)
  bot_entrypoint="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/bot.js"
  pid_dir="$service_root/vars/pids"

  nohup "$HOME/homebrew/bin/node" "$bot_entrypoint" "$command_id" >/dev/null 2>&1 &
  printf '%s\n' "$!" >"$pid_dir/$command_id"
}
