#!/bin/bash

# shellcheck source=/dev/null
source ~/Workspace/automation/config/env.sh

ACTION="inbox_add"
TIMESTAMP=$(date -Iseconds)
LOG_FILE=~/Workspace/automation/logs/clickup.log
TASK_TITLE="$1"
PAYLOAD=$(printf '{"name":"%s"}' "$TASK_TITLE")

RESPONSE=$(curl -s -w "\n%{http_code}" \
  -X POST "https://api.clickup.com/api/v2/list/$CLICKUP_INBOX_ID/task" \
  -H "Authorization: $CLICKUP_TOKEN" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD")

BODY=$(echo "$RESPONSE" | sed '$d')
CODE=$(echo "$RESPONSE" | tail -n 1)

if [ "$CODE" -ge 200 ] && [ "$CODE" -lt 300 ]; then
  echo "{\"status\":\"SUCCESS\",\"action\":\"$ACTION\",\"message\":\"Inbox item added\"}"
  echo "$TIMESTAMP|INFO|$ACTION|$CODE|$TASK_TITLE|created" >> "$LOG_FILE"
else
  CLEAN_BODY=$(echo "$BODY" | sed 's/"/\\"/g')
  echo "{\"status\":\"ERROR\",\"action\":\"$ACTION\",\"message\":\"$CLEAN_BODY\"}"
  echo "$TIMESTAMP|ERROR|$ACTION|$CODE|$TASK_TITLE|$BODY" >> "$LOG_FILE"
  exit 10
fi
