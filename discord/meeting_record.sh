#!/bin/bash

# shellcheck source=/dev/null
source ~/Workspace/shortcuts/config.sh

ACTION="meeting_record"
TIMESTAMP=$(date -Iseconds)
LOG_FILE=~/Workspace/shortcuts/vars/logs/discord.log
ENSURE_MEETING_STARTED_SCRIPT=~/Workspace/shortcuts/discord/lib/ensure_meeting_started.sh
MEETING_RECORD_BOT_SCRIPT=~/Workspace/shortcuts/discord/meeting_record_bot.sh

START_OUTPUT=$("$ENSURE_MEETING_STARTED_SCRIPT" 2>&1)
START_EXIT_CODE=$?

if [ "$START_EXIT_CODE" -ne 0 ]; then
  echo "$START_OUTPUT"
  exit "$START_EXIT_CODE"
fi

if sh "$MEETING_RECORD_BOT_SCRIPT"; then
  echo "$TIMESTAMP|INFO|$ACTION|0|recording|enabled" >> "$LOG_FILE"
  echo "{\"status\":\"SUCCESS\",\"action\":\"$ACTION\",\"message\":\"Recording started\"}"
else
  EXIT_CODE=$?
  echo "$TIMESTAMP|ERROR|$ACTION|$EXIT_CODE|recording|problem" >> "$LOG_FILE"
  echo "{\"status\":\"ERROR\",\"action\":\"$ACTION\",\"message\":\"Problem while starting meeting recording\"}"
  exit "$EXIT_CODE"
fi
