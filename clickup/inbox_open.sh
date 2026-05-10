#!/bin/bash

# shellcheck source=/dev/null
source ~/Workspace/automation/config/env.sh

ACTION="inbox_open"
TIMESTAMP=$(date -Iseconds)
LOG_FILE=~/Workspace/automation/logs/clickup.log
CLICKUP_INBOX_URL="$CLICKUP_BASE_URL/$CLICKUP_INBOX_PATH"

if open "$CLICKUP_INBOX_URL"; then
  echo "{\"status\":\"SUCCESS\",\"action\":\"$ACTION\",\"message\":\"ClickUp inbox opened\"}"
  echo "$TIMESTAMP|INFO|$ACTION|0|clickup_inbox|opened" >> "$LOG_FILE"
else
  echo "{\"status\":\"ERROR\",\"action\":\"$ACTION\",\"message\":\"Unable to open ClickUp inbox\"}"
  echo "$TIMESTAMP|ERROR|$ACTION|20|clickup_inbox|open_failed" >> "$LOG_FILE"
  exit 20
fi
