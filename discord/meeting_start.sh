#!/bin/bash

# shellcheck source=/dev/null
source ~/Workspace/automation/config/env.sh

ACTION="meeting_start"
TIMESTAMP=$(date -Iseconds)
LOG_FILE=~/Workspace/automation/vars/logs/discord.log

DISCORD_BOT_ENTRYPOINT=~/Workspace/automation/discord/bot.js
DISCORD_MEETING_START_SCRIPT=~/Workspace/automation/discord/bot_meeting_start.sh
PID_FILE=~/Workspace/automation/vars/pids/discord-bot.pid
BOT_STDOUT_LOG=~/Workspace/automation/vars/logs/discord.log
NODE_BIN=~/homebrew/bin/node

BOT_PIDS=$(ps -ax -o pid=,command= | awk -v entrypoint="$DISCORD_BOT_ENTRYPOINT" 'index($0, entrypoint) && $0 !~ /awk/ {print $1}')
BOT_COUNT=$(printf "%s\n" "$BOT_PIDS" | awk 'NF {c++} END {print c+0}')

if [ "$BOT_COUNT" -gt 1 ]; then
  echo "$TIMESTAMP|ERROR|$ACTION|32|discord_bot|duplicate_processes_detected" >> "$LOG_FILE"
  echo "{\"status\":\"ERROR\",\"action\":\"$ACTION\",\"message\":\"Multiple Discord bot processes detected. Run stop first.\"}"
  exit 32
fi

if [ "$BOT_COUNT" -eq 1 ]; then
  BOT_PID=$(printf "%s\n" "$BOT_PIDS" | awk 'NR==1 {print; exit}')
  echo "$BOT_PID" > "$PID_FILE"
  echo "$TIMESTAMP|INFO|$ACTION|0|discord_bot|already_running" >> "$LOG_FILE"
else
  nohup "$NODE_BIN" "$DISCORD_BOT_ENTRYPOINT" >> "$BOT_STDOUT_LOG" 2>&1 &
  BOT_PID=$!
  echo "$BOT_PID" > "$PID_FILE"

  sleep 1
  if kill -0 "$BOT_PID" 2>/dev/null; then
    echo "$TIMESTAMP|INFO|$ACTION|0|discord_bot|started" >> "$LOG_FILE"
    sleep 2
  else
    echo "$TIMESTAMP|ERROR|$ACTION|30|discord_bot|start_failed" >> "$LOG_FILE"
    echo "{\"status\":\"ERROR\",\"action\":\"$ACTION\",\"message\":\"Unable to start Discord bot\"}"
    exit 30
  fi
fi

if [ -x "$DISCORD_MEETING_START_SCRIPT" ] && sh "$DISCORD_MEETING_START_SCRIPT"; then
  echo "{\"status\":\"SUCCESS\",\"action\":\"$ACTION\",\"message\":\"Meeting started\"}"
  echo "$TIMESTAMP|INFO|$ACTION|0|meeting|started" >> "$LOG_FILE"
else
  echo "$TIMESTAMP|ERROR|$ACTION|31|meeting|start_failed" >> "$LOG_FILE"
  echo "{\"status\":\"ERROR\",\"action\":\"$ACTION\",\"message\":\"Unable to start Discord meeting capture\"}"
  exit 31
fi

