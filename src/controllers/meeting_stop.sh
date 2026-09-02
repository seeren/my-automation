#!/usr/bin/env bash

# shellcheck source=/dev/null
source "$(dirname "${BASH_SOURCE[0]}")/../services/discord/stop.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../services/discord/transcribe.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../services/discord/summarize.sh"

meeting_stop_controller() {
  local stop_outcome='' session_id='' transcript_file='' track_count=0
  local transcription=skipped summary=skipped code=0

  discord_stop_bot
  code=$?
  stop_outcome=$DISCORD_STOP_OUTCOME
  session_id=$DISCORD_STOP_SESSION_ID
  if ((code != 0)); then
    jq -cjn --arg outcome "$stop_outcome" \
      '{runner_details:true, outcome:$outcome, transcription:"skipped", summary:"skipped"}'
    return "$code"
  fi

  if [[ -n $session_id && $stop_outcome != degraded ]]; then
    discord_transcribe_session "$session_id" transcript_file track_count
    code=$?
    if ((code != 0)); then
      jq -cjn --arg outcome "$stop_outcome" --arg session_id "$session_id" \
        '{runner_details:true, outcome:$outcome, session_id:$session_id, transcription:"failed", summary:"skipped"}'
      return "$code"
    fi
    transcription=completed
    summary=$(discord_summary_start "$session_id")
  elif [[ -n $session_id ]]; then
    transcription=skipped_stop_degraded
  else
    transcription=skipped_not_recording
  fi

  jq -cjn \
    --arg outcome "$stop_outcome" \
    --arg session_id "$session_id" \
    --arg transcription "$transcription" \
    --arg summary "$summary" \
    --arg transcript_file "$transcript_file" \
    --argjson tracks "$track_count" \
    '{runner_details:true, outcome:$outcome, transcription:$transcription, summary:$summary}
     + if $session_id == "" then {} else {session_id:$session_id} end
     + if $transcript_file == "" then {} else {transcript_file:$transcript_file, tracks:$tracks} end'
}
