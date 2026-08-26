#!/usr/bin/env bash

# shellcheck source=/dev/null
source "$(dirname "${BASH_SOURCE[0]}")/../services/discord/bot.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../services/discord/record.sh"

meeting_record_controller() {
  discord_bot_ensure_running || return $?
  discord_record
}
