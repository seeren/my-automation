#!/usr/bin/env bash

# shellcheck source=/dev/null
source "$(dirname "${BASH_SOURCE[0]}")/../services/discord/bot.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../services/discord/record.sh"

meeting_record_controller() {
  local command_id
  command_id="record-$(date +%s)-$$"

  discord_bot_start "$command_id"
  discord_record "$command_id"
}
