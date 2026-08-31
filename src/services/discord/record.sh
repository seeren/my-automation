#!/usr/bin/env bash

discord_record() {
  local command_id=$1
  local service_root
  local command_dir
  local status_dir
  local active_file
  local status
  local elapsed=0
  local timeout=8

  service_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)
  command_dir="$service_root/vars/commands"
  status_dir="$service_root/vars/status"
  active_file="$service_root/vars/active"

  printf 'record' >"$command_dir/$command_id"

  while ((elapsed < timeout)); do
    if [[ -f $status_dir/$command_id ]]; then
      status=$(<"$status_dir/$command_id")
      if [[ $status == success ]]; then
        printf '%s' "$command_id" >"$active_file"
        return 0
      fi
      if [[ $status == error ]]; then
        return 1
      fi
    fi

    sleep 1
    elapsed=$((elapsed + 1))
  done

  return 1
}
