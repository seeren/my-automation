#!/usr/bin/env bash

discord_summary_log() {
  local level=$1 code=$2 event=$3 session_id=$4
  local root log_file
  root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)
  log_file=${DISCORD_LOG_FILE:-$root/vars/logs/discord.log}
  printf '%s|%s|meeting_summarize|%s|summary|%s|session=%s\n' \
    "$(date -Iseconds)" "$level" "$code" "$event" "$session_id" >>"$log_file"
}

discord_summary_run() {
  local session_id=$1 root transcript_dir transcript_file summary_file prompt_file
  local api_base model poll_max poll_interval temp_dir prompt request create_response
  local agent_id run_id run_response run_status result poll_count=0

  root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)
  [[ -f $root/config.sh ]] && source "$root/config.sh"
  transcript_dir=${DISCORD_TRANSCRIPTS_DIR:-$root/vars/transcripts}
  transcript_file="$transcript_dir/$session_id.md"
  summary_file="$transcript_dir/$session_id.summary.md"
  prompt_file=${DISCORD_SUMMARY_PROMPT_FILE:-$root/discord/lib/meeting_summarize.prompt}
  api_base=${CURSOR_API_BASE:-https://api.cursor.com}
  model=${CURSOR_MODEL:-default}
  poll_max=${CURSOR_POLL_MAX:-36}
  poll_interval=${CURSOR_POLL_INTERVAL:-5}

  [[ -s $transcript_file && -s $prompt_file && -n ${API_CURSOR_TOKEN:-} ]] || return 67
  temp_dir=$(mktemp -d "${TMPDIR:-/tmp}/meeting-summary.XXXXXX") || return 67
  trap 'rm -rf "$temp_dir"; trap - RETURN' RETURN
  rm -f "$summary_file"

  prompt="$temp_dir/prompt.txt"
  request="$temp_dir/request.json"
  {
    printf 'Tu es un assistant de synthèse de réunion.\n\nTranscript :\n\n'
    cat "$transcript_file"
    printf '\n\nRéponds UNIQUEMENT avec le markdown du mail (aucun commentaire avant ou après, pas de méta-texte).\n\n'
    cat "$prompt_file"
  } >"$prompt" || return 67
  jq -n --rawfile text "$prompt" --arg model "$model" \
    '{prompt:{text:$text},model:{id:$model}}' >"$request" || return 67

  discord_summary_log INFO 0 running "$session_id"
  create_response=$(curl -fsS \
    -H "Authorization: Bearer $API_CURSOR_TOKEN" \
    -H 'Content-Type: application/json' \
    -d @"$request" "$api_base/v1/agents") || return 67
  agent_id=$(printf '%s' "$create_response" | jq -r '.agent.id // empty')
  run_id=$(printf '%s' "$create_response" | jq -r '.run.id // empty')
  [[ -n $agent_id && -n $run_id ]] || return 67

  while ((poll_count < poll_max)); do
    run_response=$(curl -fsS -H "Authorization: Bearer $API_CURSOR_TOKEN" \
      "$api_base/v1/agents/$agent_id/runs/$run_id") || return 67
    run_status=$(printf '%s' "$run_response" | jq -r '.status // empty')
    case $run_status in
      FINISHED)
        result=$(printf '%s' "$run_response" | jq -r '.result // empty')
        [[ -n $result ]] || return 67
        printf '%s\n' "$result" >"$temp_dir/summary.md" || return 67
        mv "$temp_dir/summary.md" "$summary_file"
        discord_summary_log INFO 0 completed "$session_id"
        return 0
        ;;
      ERROR|CANCELLED|EXPIRED|FAILED)
        rm -f "$summary_file"
        discord_summary_log ERROR 67 failed "$session_id"
        return 67
        ;;
    esac
    poll_count=$((poll_count + 1))
    sleep "$poll_interval"
  done

  rm -f "$summary_file"
  discord_summary_log ERROR 67 timeout "$session_id"
  return 67
}

discord_summary_start() {
  local session_id=$1 service_file
  service_file=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/summarize.sh
  nohup bash -c 'source "$1"; discord_summary_run "$2"' _ \
    "$service_file" "$session_id" >/dev/null 2>&1 &
  printf 'pending\n'
}
