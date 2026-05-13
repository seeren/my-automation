#!/bin/bash

# shellcheck source=/dev/null
source ~/Workspace/automation/config/env.sh

ACTION="meeting_start"
TIMESTAMP=$(date -Iseconds)
LOG_FILE=~/Workspace/automation/logs/discord.log

DISCORD_BOT_ENTRYPOINT=~/Workspace/automation/discord/bot.js
PID_FILE=~/Workspace/automation/pids/discord-bot.pid
BOT_STDOUT_LOG=~/Workspace/automation/logs/discord.log
NODE_BIN=~/homebrew/bin/node

BOT_RUNNING="false"

if [ -f "$PID_FILE" ]; then
  BOT_PID=$(cat "$PID_FILE" 2>/dev/null)
  if [ -n "$BOT_PID" ] && kill -0 "$BOT_PID" 2>/dev/null; then
    BOT_RUNNING="true"
  else
    rm -f "$PID_FILE"
  fi
fi

if [ "$BOT_RUNNING" = "true" ]; then
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

# if [ -x "$DISCORD_MEETING_START_SCRIPT" ] && sh "$DISCORD_MEETING_START_SCRIPT"; then
#   echo "{\"status\":\"SUCCESS\",\"action\":\"$ACTION\",\"message\":\"Meeting started\",\"bot_started\":\"$BOT_STARTED\"}"
#   echo "$TIMESTAMP|INFO|$ACTION|0|meeting|started" >> "$LOG_FILE"
# else
#   echo "$TIMESTAMP|ERROR|$ACTION|31|meeting|start_failed" >> "$LOG_FILE"
#   echo "{\"status\":\"ERROR\",\"action\":\"$ACTION\",\"message\":\"Unable to start Discord meeting capture\"}"
#   exit 31
# fi

