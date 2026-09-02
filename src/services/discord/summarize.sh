#!/usr/bin/env bash

discord_summary_run() {
  local session_id=$1 root transcript summary prompt response agent_id run_id status result
  local poll=0

  root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)
  source "$root/config.sh"
  transcript="$root/vars/transcripts/$session_id.md"
  summary="$root/vars/transcripts/$session_id.summary.md"

  prompt=$(cat "$root/prompts/meeting_summarize.prompt"; \
    printf '\n\nTranscript :\n\n'; cat "$transcript") || return 67
  rm -f "$summary"

  response=$(jq -cn --arg text "$prompt" '{prompt:{text:$text},model:{id:"default"}}' |
    curl -fsS \
      -H "Authorization: Bearer $API_CURSOR_TOKEN" \
      -H 'Content-Type: application/json' \
      -d @- https://api.cursor.com/v1/agents) || return 67
  agent_id=$(printf '%s' "$response" | jq -r '.agent.id // empty')
  run_id=$(printf '%s' "$response" | jq -r '.run.id // empty')
  [[ -n $agent_id && -n $run_id ]] || return 67

  while ((poll < 36)); do
    response=$(curl -fsS -H "Authorization: Bearer $API_CURSOR_TOKEN" \
      "https://api.cursor.com/v1/agents/$agent_id/runs/$run_id") || return 67
    status=$(printf '%s' "$response" | jq -r '.status // empty')

    if [[ $status == FINISHED ]]; then
      result=$(printf '%s' "$response" | jq -r '.result // empty')
      [[ -n $result ]] || return 67
      printf '%s\n' "$result" >"$summary"
      return 0
    fi

    case $status in ERROR|CANCELLED|EXPIRED|FAILED) return 67 ;; esac
    poll=$((poll + 1))
    sleep 5
  done

  return 67
}

discord_summary_start() {
  local session_id=$1 service
  service=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/summarize.sh
  nohup bash -c 'source "$1"; discord_summary_run "$2"' _ "$service" "$session_id" \
    >/dev/null 2>&1 &
}
