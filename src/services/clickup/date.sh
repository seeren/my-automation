#!/usr/bin/env bash

# shellcheck disable=SC2034 # Results are assigned through caller-owned namerefs.
clickup_date_get_from_now() {
  local -n start_date_ms_ref=$1
  local -n due_date_ms_ref=$2
  local epoch_seconds=${3:-$(date +%s)}

  start_date_ms_ref=$((epoch_seconds * 1000))
  due_date_ms_ref=$((start_date_ms_ref + 86400000))
}
