#!/usr/bin/env bash

# shellcheck source=/dev/null
source "$(dirname "${BASH_SOURCE[0]}")/../services/discord/stop.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../services/discord/transcribe.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../services/discord/summarize.sh"

meeting_stop_controller() {
  local session_id=''

  discord_stop_bot session_id || return
  [[ -n $session_id ]] || return
  discord_transcribe_session "$session_id" || return
  discord_summary_start "$session_id"
}
