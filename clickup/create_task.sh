#!/bin/bash

source ~/Workspace/automation/config/env.sh

TASK_TITLE="$1"

PAYLOAD=$(printf '{"name":"%s"}' "$TASK_TITLE")

RESPONSE=$(curl -s -w "\n%{http_code}" \
  -X POST "https://api.clickup.com/api/v2/list/$CLICKUP_LIST_ID/task" \
  -H "Authorization: $CLICKUP_TOKEN" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD")

BODY=$(echo "$RESPONSE" | sed '$d')
CODE=$(echo "$RESPONSE" | tail -n 1)
TIMESTAMP=$(date -Iseconds)


if [ "$CODE" -ge 200 ] && [ "$CODE" -lt 300 ]; then
  echo '{"status":"SUCCESS","message":"Task created"}'
  echo "$TIMESTAMP|ERROR|create_clickup_task|$CODE|$TASK_TITLE|$BODY" >> ~/Workspace/automation/logs/clickup.log
else
  CLEAN_BODY=$(echo "$BODY" | sed 's/"/\\"/g')
  echo "{\"status\":\"ERROR\",\"message\":\"$CLEAN_BODY\"}"
  echo "$TIMESTAMP|ERROR|create_clickup_task|$CODE|$TASK_TITLE|$BODY" >> ~/Workspace/automation/logs/clickup.log
fi

