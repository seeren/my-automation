#!/usr/bin/env bash

# shellcheck source=/dev/null
source "$(dirname "${BASH_SOURCE[0]}")/../services/clickup/priority.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../services/clickup/date.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../services/clickup/task.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../services/clickup/inbox.sh"

inbox_add_controller() {
  local title=${1-}
  local priority_text=${2-}
  local priority
  local start_date_ms
  local due_date_ms
  local payload
  local _response_body
  local _http_code

  clickup_date_get_from_now start_date_ms due_date_ms

  priority=$(clickup_priority_get_from_text "$priority_text")
  payload=$(clickup_task_payload_build "$title" "$priority" "$start_date_ms" "$due_date_ms")

  clickup_inbox_task_create "$payload" _response_body _http_code
}
