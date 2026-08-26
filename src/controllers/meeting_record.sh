#!/usr/bin/env bash

# shellcheck source=/dev/null
source "$(dirname "${BASH_SOURCE[0]}")/../services/discord/bot.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../services/discord/record.sh"

meeting_record_controller() {
  if discord_bot_is_running; then
    return 32
  fi

  discord_bot_start || return $?
  discord_record
}
