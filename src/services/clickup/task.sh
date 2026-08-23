#!/usr/bin/env bash

clickup_task_payload_build() {
  local title=$1
  local priority=$2
  local start_date_ms=$3
  local due_date_ms=$4

  jq -cjn \
    --arg name "$title" \
    --argjson priority "$priority" \
    --arg start_date "$start_date_ms" \
    --arg due_date "$due_date_ms" \
    '{
      name: $name,
      priority: $priority,
      start_date: $start_date,
      start_date_time: true,
      due_date: $due_date,
      due_date_time: true
    }'
}
