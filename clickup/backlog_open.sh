#!/bin/bash

# shellcheck source=/dev/null
source ~/Workspace/automation/config/env.sh

ACTION="backlog_open"
TIMESTAMP=$(date -Iseconds)
LOG_FILE=~/Workspace/automation/logs/clickup.log

PRODUCT="$1"
PATH_VAR="CLICKUP_BACKLOG_${PRODUCT}_PATH"
PATH_SUFFIX="${!PATH_VAR}"

CLICKUP_URL="$CLICKUP_BASE_URL/$PATH_SUFFIX"

if open "$CLICKUP_URL"; then
  echo "{\"status\":\"SUCCESS\",\"action\":\"$ACTION\",\"message\":\"ClickUp backlog opened\",\"product\":\"$PRODUCT\"}"
  echo "$TIMESTAMP|INFO|$ACTION|0|$PRODUCT|opened" >> "$LOG_FILE"
else
  echo "{\"status\":\"ERROR\",\"action\":\"$ACTION\",\"message\":\"Unable to open ClickUp backlog\"}"
  echo "$TIMESTAMP|ERROR|$ACTION|20|$PRODUCT|open_failed" >> "$LOG_FILE"
  exit 20
fi
