#!/bin/bash

# shellcheck source=/dev/null
source ~/Workspace/automation/config/env.sh

ACTION="inbox_add"
TIMESTAMP=$(date -Iseconds)
LOG_FILE=~/Workspace/automation/vars/logs/clickup.log
TASK_TITLE="$1"
PRIORITY_TEXT="$2"

if [ -z "$TASK_TITLE" ] && [ -n "$PRIORITY_TEXT" ]; then
  TASK_TITLE="$PRIORITY_TEXT"
  PRIORITY_TEXT=""
fi

CLICKUP_PRIORITY=3
START_DATE_MS=$(( $(date +%s) * 1000 ))
DUE_DATE_MS=$(( START_DATE_MS + 86400000 ))

case "$PRIORITY_TEXT" in
  *urgente*|*urgent*|*critique*)
    CLICKUP_PRIORITY=1
    ;;
  *élevée*|*elevee*|*haute*|*important|*importante|*top*)
    CLICKUP_PRIORITY=2
    ;;
  *normale*|*normal*|*moyenne|bof*)
    CLICKUP_PRIORITY=3
    ;;
  *basse*|*faible*)
    CLICKUP_PRIORITY=4
    ;;
esac

PAYLOAD=$(printf '{"name":"%s","priority":%s,"start_date":"%s","start_date_time":true,"due_date":"%s","due_date_time":true}' "$TASK_TITLE" "$CLICKUP_PRIORITY" "$START_DATE_MS" "$DUE_DATE_MS")

RESPONSE=$(curl -s -w "\n%{http_code}" \
  -X POST "https://api.clickup.com/api/v2/list/$CLICKUP_INBOX_ID/task" \
  -H "Authorization: $CLICKUP_TOKEN" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD")

BODY=$(echo "$RESPONSE" | sed '$d')
CODE=$(echo "$RESPONSE" | tail -n 1)

if [ "$CODE" -ge 200 ] && [ "$CODE" -lt 300 ]; then
  echo "{\"status\":\"SUCCESS\",\"action\":\"$ACTION\",\"message\":\"Inbox item added\"}"
  echo "$TIMESTAMP|INFO|$ACTION|$CODE|$TASK_TITLE|created|priority=$CLICKUP_PRIORITY" >> "$LOG_FILE"
else
  CLEAN_BODY=$(echo "$BODY" | sed 's/"/\\"/g')
  echo "{\"status\":\"ERROR\",\"action\":\"$ACTION\",\"message\":\"$CLEAN_BODY\"}"
  echo "$TIMESTAMP|ERROR|$ACTION|$CODE|$TASK_TITLE|$BODY" >> "$LOG_FILE"
  exit 10
fi
