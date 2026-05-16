#!/bin/bash

set -euo pipefail

RUNTIME_DIR=~/Workspace/automation/vars/runtime
COMMAND_FILE="$RUNTIME_DIR/discord-command.json"
STATUS_FILE="$RUNTIME_DIR/discord-status.json"
TIMEOUT_SECONDS=20
SLEEP_SECONDS=1
CMD_ID="record-$(date +%s)-$$"

printf '{"id":"%s","action":"record_start"}' "$CMD_ID" > "$COMMAND_FILE"

elapsed=0
while [ "$elapsed" -lt "$TIMEOUT_SECONDS" ]; do
  if [ -f "$STATUS_FILE" ]; then
    STATUS_CONTENT=$(<"$STATUS_FILE")
    case "$STATUS_CONTENT" in
      *"\"id\":\"$CMD_ID\",\"action\":\"record_start\",\"status\":\"success\",\"state\":\"recording_started\""*)
        exit 0
        ;;
      *"\"id\":\"$CMD_ID\",\"action\":\"record_start\",\"status\":\"success\",\"state\":\"recording_already_started\""*)
        exit 0
        ;;
      *"\"id\":\"$CMD_ID\",\"action\":\"record_start\",\"status\":\"error\",\"state\":\"error\""*)
        exit 1
        ;;
    esac
  fi
  sleep "$SLEEP_SECONDS"
  elapsed=$((elapsed + SLEEP_SECONDS))
done

exit 1
