#!/bin/bash

ACTION="meeting_stop"
TIMESTAMP=$(date -Iseconds)
LOG_FILE=~/Workspace/shortcuts/vars/logs/discord.log

DISCORD_MEETING_STOP_SCRIPT=~/Workspace/shortcuts/discord/meeting_stop_bot.sh
DISCORD_MEETING_TRANSCRIBE_SCRIPT=~/Workspace/shortcuts/discord/meeting_transcribe.sh
DISCORD_MEETING_SUMMARIZE_SCRIPT=~/Workspace/shortcuts/discord/meeting_summarize.sh
DISCORD_BOT_ENTRYPOINT=~/Workspace/shortcuts/src/services/discord/bot.js
VARS_DIR=~/Workspace/shortcuts/vars
PID_DIR="$VARS_DIR/pids"
COMMAND_DIR="$VARS_DIR/commands"
STATUS_DIR="$VARS_DIR/status"
ACTIVE_FILE="$VARS_DIR/active"
SESSION_DIR="$VARS_DIR/sessions"
ACTIVE_ID=""
MEETING_STOP_RESULT="ok"
KILL9_USED="no"
TRANSCRIPTION_STATUS="skipped"
SUMMARY_STATUS="skipped"
TRANSCRIPTION_SESSION_ID=""

if [ -f "$ACTIVE_FILE" ]; then
  ACTIVE_ID=$(<"$ACTIVE_FILE")
fi

meeting_cleanup() {
  local command_id=$1

  rm -f "$PID_DIR/$command_id"
  rm -f "$COMMAND_DIR/$command_id"
  rm -f "$STATUS_DIR/$command_id"
  rm -f "$SESSION_DIR/$command_id"
  rm -f "$ACTIVE_FILE"
}

BOT_PIDS=$(ps -ax -o pid=,command= | awk -v entrypoint="$DISCORD_BOT_ENTRYPOINT" 'index($0, entrypoint) && $0 !~ /awk/ {print $1}')
BOT_COUNT=$(printf "%s\n" "$BOT_PIDS" | awk 'NF {c++} END {print c+0}')
STOP_PID_LIST=$(printf "%s" "$BOT_PIDS" | tr '\n' ',' | sed 's/,$//')

if [ "$BOT_COUNT" -eq 0 ]; then
  if [ -n "$ACTIVE_ID" ]; then
    meeting_cleanup "$ACTIVE_ID"
  fi
  echo "{\"status\":\"SUCCESS\",\"action\":\"$ACTION\",\"message\":\"Bot already offline\"}"
  exit 0
fi

if sh "$DISCORD_MEETING_STOP_SCRIPT"; then
  :
else
  echo "$TIMESTAMP|ERROR|$ACTION|40|meeting|stop_failed" >> "$LOG_FILE"
  MEETING_STOP_RESULT="failed"
fi

CURRENT_BOT_PIDS=$(ps -ax -o pid=,command= | awk -v entrypoint="$DISCORD_BOT_ENTRYPOINT" 'index($0, entrypoint) && $0 !~ /awk/ {print $1}')
CURRENT_COUNT=$(printf "%s\n" "$CURRENT_BOT_PIDS" | awk 'NF {c++} END {print c+0}')

if [ "$CURRENT_COUNT" -gt 0 ]; then
  for PID in $CURRENT_BOT_PIDS; do
    kill "$PID" 2>/dev/null || true
  done
fi

sleep 2

REMAINING_BOT_PIDS=$(ps -ax -o pid=,command= | awk -v entrypoint="$DISCORD_BOT_ENTRYPOINT" 'index($0, entrypoint) && $0 !~ /awk/ {print $1}')
REMAINING_COUNT=$(printf "%s\n" "$REMAINING_BOT_PIDS" | awk 'NF {c++} END {print c+0}')

if [ "$REMAINING_COUNT" -gt 0 ]; then
  KILL9_USED="yes"
  for PID in $REMAINING_BOT_PIDS; do
    kill -9 "$PID" 2>/dev/null || true
  done
  sleep 1
  REMAINING_BOT_PIDS=$(ps -ax -o pid=,command= | awk -v entrypoint="$DISCORD_BOT_ENTRYPOINT" 'index($0, entrypoint) && $0 !~ /awk/ {print $1}')
  REMAINING_COUNT=$(printf "%s\n" "$REMAINING_BOT_PIDS" | awk 'NF {c++} END {print c+0}')
fi

if [ "$REMAINING_COUNT" -gt 0 ]; then
  echo "$TIMESTAMP|ERROR|$ACTION|41|discord_bot|stop_failed" >> "$LOG_FILE"
  echo "{\"status\":\"ERROR\",\"action\":\"$ACTION\",\"message\":\"Unable to stop Discord bot\"}"
  exit 41
fi

if [ "$MEETING_STOP_RESULT" = "ok" ] && [ -n "$ACTIVE_ID" ] && [ -f "$SESSION_DIR/$ACTIVE_ID" ]; then
  TRANSCRIPTION_SESSION_ID=$(<"$SESSION_DIR/$ACTIVE_ID")
  if "$DISCORD_MEETING_TRANSCRIBE_SCRIPT" "$TRANSCRIPTION_SESSION_ID" >/dev/null 2>&1; then
    TRANSCRIPTION_STATUS="completed"
    echo "$TIMESTAMP|INFO|$ACTION|0|transcription|completed|session=$TRANSCRIPTION_SESSION_ID" >> "$LOG_FILE"
    nohup "$DISCORD_MEETING_SUMMARIZE_SCRIPT" "$TRANSCRIPTION_SESSION_ID" >> "$LOG_FILE" 2>&1 &
    SUMMARY_STATUS="pending"
    echo "$TIMESTAMP|INFO|$ACTION|0|summary|started|session=$TRANSCRIPTION_SESSION_ID" >> "$LOG_FILE"
  else
    TRANSCRIPTION_STATUS="failed"
    SUMMARY_STATUS="skipped"
    echo "$TIMESTAMP|INFO|$ACTION|0|transcription|failed|session=$TRANSCRIPTION_SESSION_ID" >> "$LOG_FILE"
  fi
elif [ "$MEETING_STOP_RESULT" = "ok" ] && [ -n "$ACTIVE_ID" ]; then
  TRANSCRIPTION_STATUS="skipped_not_recording"
fi

if [ -n "$ACTIVE_ID" ]; then
  meeting_cleanup "$ACTIVE_ID"
fi

if [ "$MEETING_STOP_RESULT" = "failed" ]; then
  echo "$TIMESTAMP|INFO|$ACTION|0|meeting|stopped_with_meeting_stop_failed|pids=$STOP_PID_LIST" >> "$LOG_FILE"
  echo "{\"status\":\"SUCCESS\",\"action\":\"$ACTION\",\"message\":\"Bot stopped, but meeting stop failed\",\"transcription\":\"$TRANSCRIPTION_STATUS\",\"summary\":\"$SUMMARY_STATUS\"}"
elif [ "$KILL9_USED" = "yes" ]; then
  echo "$TIMESTAMP|INFO|$ACTION|0|meeting|stopped_forced|pids=$STOP_PID_LIST" >> "$LOG_FILE"
  echo "{\"status\":\"SUCCESS\",\"action\":\"$ACTION\",\"message\":\"Meeting stopped (forced bot shutdown)\",\"transcription\":\"$TRANSCRIPTION_STATUS\",\"summary\":\"$SUMMARY_STATUS\"}"
else
  echo "$TIMESTAMP|INFO|$ACTION|0|meeting|stopped|pids=$STOP_PID_LIST" >> "$LOG_FILE"
  echo "{\"status\":\"SUCCESS\",\"action\":\"$ACTION\",\"message\":\"Meeting stopped\",\"transcription\":\"$TRANSCRIPTION_STATUS\",\"summary\":\"$SUMMARY_STATUS\"}"
fi
