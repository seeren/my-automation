#!/bin/bash

ACTION="meeting_transcribe"
TIMESTAMP=$(date -Iseconds)
LOG_FILE=~/Workspace/shortcuts/vars/logs/discord.log
AUDIO_DIR=~/Workspace/shortcuts/vars/audios
TRANSCRIPTS_DIR=~/Workspace/shortcuts/vars/transcripts
WHISPER_BIN=~/homebrew/bin/whisper-cli
WHISPER_MODEL=~/Workspace/shortcuts/vars/ggml-large-v3.bin
WHISPER_LANGUAGE=fr
SRT_PARSER_AWK=~/Workspace/shortcuts/discord/lib/parse_srt.awk

SESSION_ID="${1:-}"
SESSION_START_NO_MS="${SESSION_ID%Z}"
SESSION_START_NO_MS="${SESSION_START_NO_MS%-*}"
SESSION_START_EPOCH=$(date -j -u -f "%Y-%m-%dT%H-%M-%S" "$SESSION_START_NO_MS" "+%s" 2>/dev/null || date -u "+%s")
SESSION_END_EPOCH="$SESSION_START_EPOCH"
ENTRIES_FILE="/tmp/meeting-transcribe-entries-${SESSION_ID}-$$.txt"

rm -f "$ENTRIES_FILE"
touch "$ENTRIES_FILE"

set -- "$AUDIO_DIR/${SESSION_ID}"__speaker-*.wav
if [ ! -e "$1" ]; then
  echo "$TIMESTAMP|ERROR|$ACTION|61|session|not_found|session=$SESSION_ID" >> "$LOG_FILE"
  echo "{\"status\":\"ERROR\",\"action\":\"$ACTION\",\"message\":\"No audio files found for session_id\"}"
  exit 61
fi

TRANSCRIBED_COUNT=0

for AUDIO_FILE in "$@"; do
  BASENAME=$(basename "$AUDIO_FILE")
  SPEAKER_RAW="${BASENAME#*__speaker-}"
  SPEAKER_RAW="${SPEAKER_RAW%.wav}"
  SPEAKER_ID="${SPEAKER_RAW%%__name-*}"
  SPEAKER_NAME="$SPEAKER_ID"
  ENCODED_NAME=""
  DECODED_NAME=""
  case "$SPEAKER_RAW" in
    *__name-*)
      ENCODED_NAME="${SPEAKER_RAW#*__name-}"
      ;;
  esac
  if [ -n "$ENCODED_NAME" ]; then
    BASE64_NAME=$(printf "%s" "$ENCODED_NAME" | tr '_-' '/+')
    BASE64_MOD=$(( ${#BASE64_NAME} % 4 ))
    if [ "$BASE64_MOD" -eq 2 ]; then
      BASE64_NAME="${BASE64_NAME}=="
    elif [ "$BASE64_MOD" -eq 3 ]; then
      BASE64_NAME="${BASE64_NAME}="
    fi
    DECODED_NAME=$(printf "%s" "$BASE64_NAME" | base64 -D 2>/dev/null || true)
    if [ -n "$DECODED_NAME" ]; then
      SPEAKER_NAME="$DECODED_NAME"
    fi
  fi
  OUTPUT_PREFIX="/tmp/meeting-transcribe-${SESSION_ID}-${SPEAKER_ID}-$$"
  OUTPUT_SRT_FILE="${OUTPUT_PREFIX}.srt"
  OUTPUT_SEGMENTS_FILE="${OUTPUT_PREFIX}.segments.tsv"

  rm -f "$OUTPUT_SRT_FILE"

  "$WHISPER_BIN" -m "$WHISPER_MODEL" -f "$AUDIO_FILE" -l "$WHISPER_LANGUAGE" -osrt -of "$OUTPUT_PREFIX" >/dev/null 2>&1
  WHISPER_EXIT_CODE=$?

  if [ "$WHISPER_EXIT_CODE" -ne 0 ] || [ ! -f "$OUTPUT_SRT_FILE" ]; then
    rm -f "$OUTPUT_SRT_FILE"
    echo "$TIMESTAMP|ERROR|$ACTION|62|transcription|failed|session=$SESSION_ID|speaker=$SPEAKER_ID" >> "$LOG_FILE"
    echo "{\"status\":\"ERROR\",\"action\":\"$ACTION\",\"message\":\"Failed to transcribe session audio\"}"
    exit 62
  fi

  awk -f "$SRT_PARSER_AWK" "$OUTPUT_SRT_FILE" > "$OUTPUT_SEGMENTS_FILE"

  while IFS=$'\t' read -r START_MS SEGMENT_TEXT; do
    SEGMENT_EPOCH=$((SESSION_START_EPOCH + (START_MS / 1000)))
    SEGMENT_LABEL=$(date -u -r "$SEGMENT_EPOCH" "+%H:%M:%S")
    printf "%s\t%s\t%s\t%s\n" "$SEGMENT_EPOCH" "$SEGMENT_LABEL" "$SPEAKER_NAME" "$SEGMENT_TEXT" >> "$ENTRIES_FILE"
    if [ "$SEGMENT_EPOCH" -gt "$SESSION_END_EPOCH" ]; then
      SESSION_END_EPOCH="$SEGMENT_EPOCH"
    fi
  done < "$OUTPUT_SEGMENTS_FILE"

  rm -f "$OUTPUT_SRT_FILE"
  rm -f "$OUTPUT_SEGMENTS_FILE"
  TRANSCRIBED_COUNT=$((TRANSCRIBED_COUNT + 1))
done

TRANSCRIPT_FILE="$TRANSCRIPTS_DIR/$SESSION_ID.md"
SORTED_ENTRIES_FILE="/tmp/meeting-transcribe-sorted-${SESSION_ID}-$$.txt"
PARTICIPANTS_FILE="/tmp/meeting-transcribe-participants-${SESSION_ID}-$$.txt"
sort -n "$ENTRIES_FILE" > "$SORTED_ENTRIES_FILE"
awk -F '\t' 'NF >= 3 {print $3}' "$SORTED_ENTRIES_FILE" | sort -u > "$PARTICIPANTS_FILE"

{
  printf "# Meeting Transcript\n\n"
  printf "## 👤 Participant\n"
  if [ -s "$PARTICIPANTS_FILE" ]; then
    while IFS= read -r PARTICIPANT_NAME; do
      printf -- "- %s\n" "$PARTICIPANT_NAME"
    done < "$PARTICIPANTS_FILE"
  else
    printf -- "- unknown\n"
  fi
  printf "\n"
  printf "## 🗣 Transcript\n\n"
} > "$TRANSCRIPT_FILE"

if [ -s "$ENTRIES_FILE" ]; then
  while IFS=$'\t' read -r _SEGMENT_EPOCH SEGMENT_LABEL SPEAKER_NAME SEGMENT_TEXT; do
    {
      printf "### [%s] %s\n" "$SEGMENT_LABEL" "$SPEAKER_NAME"
      printf "%s\n\n" "$SEGMENT_TEXT"
    } >> "$TRANSCRIPT_FILE"
  done < "$SORTED_ENTRIES_FILE"
fi

{
  printf "---\n"
} >> "$TRANSCRIPT_FILE"

rm -f "$ENTRIES_FILE"
rm -f "$SORTED_ENTRIES_FILE"
rm -f "$PARTICIPANTS_FILE"

echo "$TIMESTAMP|INFO|$ACTION|0|transcription|completed|session=$SESSION_ID|files=$TRANSCRIBED_COUNT|file=$TRANSCRIPT_FILE" >> "$LOG_FILE"
echo "{\"status\":\"SUCCESS\",\"action\":\"$ACTION\",\"message\":\"Meeting transcription completed\",\"session_id\":\"$SESSION_ID\",\"files\":$TRANSCRIBED_COUNT,\"transcript_file\":\"$TRANSCRIPT_FILE\"}"
