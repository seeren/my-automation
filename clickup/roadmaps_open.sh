#!/bin/bash

# shellcheck source=/dev/null
source ~/Workspace/automation/config/env.sh

ACTION="roadmaps_open"
TIMESTAMP=$(date -Iseconds)
LOG_FILE=~/Workspace/automation/vars/logs/clickup.log

URL_PORTFOLIO="$CLICKUP_BASE_URL/$CLICKUP_PORTFOLIO_ROADMAP_PATH"
URL_PI_ROADMAP="$CLICKUP_BASE_URL/$CLICKUP_PROGRAM_INCREMENT_ROADMAP_PATH"
URL_PI_PLAN="$CLICKUP_BASE_URL/$CLICKUP_PROGRAM_INCREMENT_PLAN_PATH"

EXIT=0
open "$URL_PORTFOLIO" || EXIT=20
open "$URL_PI_ROADMAP" || EXIT=20
open "$URL_PI_PLAN" || EXIT=20

if [ "$EXIT" -eq 0 ]; then
  echo "{\"status\":\"SUCCESS\",\"action\":\"$ACTION\",\"message\":\"ClickUp roadmaps and PI plan opened in browser tabs\"}"
  echo "$TIMESTAMP|INFO|$ACTION|0|roadmaps_three|opened" >> "$LOG_FILE"
else
  echo "{\"status\":\"ERROR\",\"action\":\"$ACTION\",\"message\":\"Unable to open one or more ClickUp roadmap URLs\"}"
  echo "$TIMESTAMP|ERROR|$ACTION|20|roadmaps_three|open_failed" >> "$LOG_FILE"
  exit 20
fi
