#!/usr/bin/env bash

clickup_inbox_task_create() {
  local payload=$1

  curl --fail --silent --show-error \
    --request POST \
    "$API_CLICKUP_BASE_URL/api/v2/list/$CLICKUP_INBOX_ID/task" \
    --header "Authorization: $API_CLICKUP_TOKEN" \
    --header 'Content-Type: application/json' \
    --data "$payload" \
    --output /dev/null
}
