#!/bin/bash

# shellcheck source=/dev/null
source ~/Workspace/automation/config/env.sh

ACTION="meeting_record"
TIMESTAMP=$(date -Iseconds)
LOG_FILE=~/Workspace/automation/vars/logs/discord.log
MEETING_START_SCRIPT=~/Workspace/automation/discord/meeting_start.sh
MEETING_RECORD_BOT_SCRIPT=~/Workspace/automation/discord/meeting_record_bot.sh

START_OUTPUT=$("$MEETING_START_SCRIPT" 2>&1)
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
