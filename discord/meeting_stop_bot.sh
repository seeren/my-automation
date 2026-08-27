#!/bin/bash

set -euo pipefail

VARS_DIR=~/Workspace/shortcuts/vars
COMMAND_DIR="$VARS_DIR/commands"
STATUS_DIR="$VARS_DIR/status"
ACTIVE_FILE="$VARS_DIR/active"
TIMEOUT_SECONDS=20
SLEEP_SECONDS=1

[[ -f $ACTIVE_FILE ]] || exit 1

CMD_ID=$(<"$ACTIVE_FILE")

rm -f "$STATUS_DIR/$CMD_ID"
printf 'stop' > "$COMMAND_DIR/$CMD_ID"

elapsed=0
while [ "$elapsed" -lt "$TIMEOUT_SECONDS" ]; do
  if [ -f "$STATUS_DIR/$CMD_ID" ]; then
    case $(<"$STATUS_DIR/$CMD_ID") in
      success)
        exit 0
        ;;
      error)
        exit 1
        ;;
    esac
  fi
  sleep "$SLEEP_SECONDS"
  elapsed=$((elapsed + SLEEP_SECONDS))
done

exit 1
