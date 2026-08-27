#!/bin/bash

# shellcheck source=/dev/null
source ~/Workspace/shortcuts/config.sh

ACTION="meeting_summarize"
TIMESTAMP=$(date -Iseconds)
LOG_FILE=~/Workspace/shortcuts/vars/logs/discord.log
TRANSCRIPTS_DIR=~/Workspace/shortcuts/vars/transcripts
SUMMARIZE_PROMPT_FILE=~/Workspace/shortcuts/discord/lib/meeting_summarize.prompt
CURSOR_API_BASE=https://api.cursor.com
CURSOR_MODEL=default

SESSION_ID="${1:-}"
TRANSCRIPT_FILE="$TRANSCRIPTS_DIR/$SESSION_ID.md"
SUMMARY_FILE="$TRANSCRIPTS_DIR/$SESSION_ID.summary.md"
PROMPT_TMP="/tmp/meeting-summarize-prompt-${SESSION_ID}-$$.txt"
REQUEST_TMP="/tmp/meeting-summarize-request-${SESSION_ID}-$$.json"
POLL_COUNT=0
POLL_MAX=36
AGENT_ID=""
RUN_ID=""
RUN_STATUS=""

TRANSCRIPT_CONTENT=$(cat "$TRANSCRIPT_FILE")
AGENT_PROMPT=$(cat <<EOF
Tu es un assistant de synthèse de réunion.

Transcript :

$TRANSCRIPT_CONTENT

Réponds UNIQUEMENT avec le markdown du mail (aucun commentaire avant ou après, pas de méta-texte).

$(cat "$SUMMARIZE_PROMPT_FILE")
EOF
)

rm -f "$PROMPT_TMP" "$REQUEST_TMP" "$SUMMARY_FILE"

printf '%s' "$AGENT_PROMPT" > "$PROMPT_TMP"
jq -n --rawfile text "$PROMPT_TMP" --arg model "$CURSOR_MODEL" '{prompt:{text:$text},model:{id:$model}}' > "$REQUEST_TMP"

echo "$TIMESTAMP|INFO|$ACTION|0|summary|running|session=$SESSION_ID|backend=cursor_api" >> "$LOG_FILE"

CREATE_RESPONSE=$(curl -s -H "Authorization: Bearer $API_CURSOR_TOKEN" -H "Content-Type: application/json" -d @"$REQUEST_TMP" "$CURSOR_API_BASE/v1/agents")
AGENT_ID=$(printf '%s' "$CREATE_RESPONSE" | jq -r '.agent.id // empty')
RUN_ID=$(printf '%s' "$CREATE_RESPONSE" | jq -r '.run.id // empty')

if [ -z "$AGENT_ID" ] || [ -z "$RUN_ID" ]; then
  API_ERR=$(printf '%s' "$CREATE_RESPONSE" | head -c 200 | tr '\n' ' ')
  rm -f "$PROMPT_TMP" "$REQUEST_TMP"
  echo "$TIMESTAMP|ERROR|$ACTION|67|summary|failed|session=$SESSION_ID|step=create|api_err=$API_ERR" >> "$LOG_FILE"
  echo "{\"status\":\"ERROR\",\"action\":\"$ACTION\",\"message\":\"Failed to generate meeting summary\"}"
  exit 67
fi

while [ "$POLL_COUNT" -lt "$POLL_MAX" ]; do
  RUN_RESPONSE=$(curl -s -H "Authorization: Bearer $API_CURSOR_TOKEN" "$CURSOR_API_BASE/v1/agents/$AGENT_ID/runs/$RUN_ID")
  RUN_STATUS=$(printf '%s' "$RUN_RESPONSE" | jq -r '.status // empty')
  case "$RUN_STATUS" in
    FINISHED)
      printf '%s' "$RUN_RESPONSE" | jq -r '.result // empty' > "$SUMMARY_FILE"
      break
      ;;
    ERROR|CANCELLED|EXPIRED|FAILED)
      API_ERR=$(printf '%s' "$RUN_RESPONSE" | head -c 200 | tr '\n' ' ')
      rm -f "$SUMMARY_FILE" "$PROMPT_TMP" "$REQUEST_TMP"
      echo "$TIMESTAMP|ERROR|$ACTION|67|summary|failed|session=$SESSION_ID|step=poll|status=$RUN_STATUS|api_err=$API_ERR" >> "$LOG_FILE"
      echo "{\"status\":\"ERROR\",\"action\":\"$ACTION\",\"message\":\"Failed to generate meeting summary\"}"
      exit 67
      ;;
  esac
  POLL_COUNT=$((POLL_COUNT + 1))
  sleep 5
done

rm -f "$PROMPT_TMP" "$REQUEST_TMP"

if [ ! -s "$SUMMARY_FILE" ]; then
  rm -f "$SUMMARY_FILE"
  echo "$TIMESTAMP|ERROR|$ACTION|67|summary|failed|session=$SESSION_ID|step=timeout|status=$RUN_STATUS" >> "$LOG_FILE"
  echo "{\"status\":\"ERROR\",\"action\":\"$ACTION\",\"message\":\"Failed to generate meeting summary\"}"
  exit 67
fi

echo "$TIMESTAMP|INFO|$ACTION|0|summary|completed|session=$SESSION_ID|file=$SUMMARY_FILE" >> "$LOG_FILE"
echo "{\"status\":\"SUCCESS\",\"action\":\"$ACTION\",\"message\":\"Meeting summary generated\",\"session_id\":\"$SESSION_ID\",\"summary_file\":\"$SUMMARY_FILE\"}"
