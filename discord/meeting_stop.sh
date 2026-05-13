#!/bin/bash

# shellcheck source=/dev/null
source ~/Workspace/automation/config/env.sh

ACTION="meeting_stop"
TIMESTAMP=$(date -Iseconds)
LOG_FILE=~/Workspace/automation/vars/logs/discord.log

DISCORD_MEETING_STOP_SCRIPT=~/Workspace/automation/discord/bot_meeting_stop.sh
DISCORD_BOT_ENTRYPOINT=~/Workspace/automation/discord/bot.js
PID_FILE=~/Workspace/automation/vars/pids/discord-bot.pid
BOT_PIDS=$(ps -ax -o pid=,command= | awk -v entrypoint="$DISCORD_BOT_ENTRYPOINT" 'index($0, entrypoint) && $0 !~ /awk/ {print $1}')
BOT_COUNT=$(printf "%s\n" "$BOT_PIDS" | awk 'NF {c++} END {print c+0}')
MEETING_STOP_RESULT="ok"

if [ "$BOT_COUNT" -eq 0 ]; then
  rm -f "$PID_FILE"
  echo "$TIMESTAMP|INFO|$ACTION|0|discord_bot|already_stopped" >> "$LOG_FILE"
  echo "{\"status\":\"SUCCESS\",\"action\":\"$ACTION\",\"message\":\"Bot already offline\"}"
  exit 0
fi

if [ -x "$DISCORD_MEETING_STOP_SCRIPT" ] && sh "$DISCORD_MEETING_STOP_SCRIPT"; then
  echo "$TIMESTAMP|INFO|$ACTION|0|meeting|stopped" >> "$LOG_FILE"
else
  echo "$TIMESTAMP|ERROR|$ACTION|40|meeting|stop_failed" >> "$LOG_FILE"
  MEETING_STOP_RESULT="failed"
fi

for PID in $BOT_PIDS; do
  kill "$PID" 2>/dev/null || true
done

sleep 1

for PID in $BOT_PIDS; do
  if kill -0 "$PID" 2>/dev/null; then
    kill -9 "$PID" 2>/dev/null || true
  fi
done

sleep 1

REMAINING_BOT_PIDS=$(ps -ax -o pid=,command= | awk -v entrypoint="$DISCORD_BOT_ENTRYPOINT" 'index($0, entrypoint) && $0 !~ /awk/ {print $1}')
REMAINING_COUNT=$(printf "%s\n" "$REMAINING_BOT_PIDS" | awk 'NF {c++} END {print c+0}')

if [ "$REMAINING_COUNT" -eq 0 ]; then
  rm -f "$PID_FILE"
fi

if [ "$REMAINING_COUNT" -gt 0 ]; then
  echo "$TIMESTAMP|ERROR|$ACTION|41|discord_bot|stop_failed" >> "$LOG_FILE"
  echo "{\"status\":\"ERROR\",\"action\":\"$ACTION\",\"message\":\"Unable to stop Discord bot process\"}"
  exit 41
fi

echo "$TIMESTAMP|INFO|$ACTION|0|discord_bot|stopped" >> "$LOG_FILE"

if [ "$MEETING_STOP_RESULT" = "failed" ]; then
  echo "{\"status\":\"SUCCESS\",\"action\":\"$ACTION\",\"message\":\"Bot stopped, but meeting stop acknowledgment failed\"}"
else
  echo "{\"status\":\"SUCCESS\",\"action\":\"$ACTION\",\"message\":\"Meeting stopped\"}"
fi

