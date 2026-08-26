#!/usr/bin/env bash

# Internal compatibility helper: ensure only that the Discord bot is running.
# Meeting join is now an internal phase of the single record instruction.

# shellcheck source=/dev/null
source "$(dirname "${BASH_SOURCE[0]}")/../../src/services/discord/bot.sh"

discord_bot_ensure_running
exit_code=$?
if ((exit_code == 0)); then
  exit 0
fi

case $exit_code in
  32)
    printf '%s\n' '{"status":"ERROR","action":"meeting_ensure_started","message":"Multiple Discord detected: run stop first."}'
    ;;
  *)
    printf '%s\n' '{"status":"ERROR","action":"meeting_ensure_started","message":"Unable to start Discord bot"}'
    ;;
esac
exit "$exit_code"
