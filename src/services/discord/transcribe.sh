#!/usr/bin/env bash

discord_transcribe_decode_name() {
  local encoded=$1 decoded base64_name padding
  base64_name=$(printf '%s' "$encoded" | tr '_-' '/+')
  padding=$((${#base64_name} % 4))
  [[ $padding -eq 2 ]] && base64_name+='=='
  [[ $padding -eq 3 ]] && base64_name+='='
  decoded=$(printf '%s' "$base64_name" | base64 -D 2>/dev/null || true)
  printf '%s' "$decoded"
}

discord_transcribe_session_epoch() {
  local session_id=$1 timestamp
  timestamp=${session_id%Z}
  timestamp=${timestamp%-*}
  date -j -u -f '%Y-%m-%dT%H-%M-%S' "$timestamp" '+%s' 2>/dev/null || date -u '+%s'
}

discord_transcribe_session() {
  local session_id=$1 transcript_var=${2-} count_var=${3-}
  local root audio_dir transcript_dir whisper_bin whisper_model language parser temp_dir
  local session_epoch transcript_file entries sorted participants audio_file basename speaker_raw
  local speaker_id speaker_name encoded output_prefix srt segments start_ms text segment_epoch label count=0
  local -a audio_files

  root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)
  audio_dir=${DISCORD_AUDIO_DIR:-$root/vars/audios}
  transcript_dir=${DISCORD_TRANSCRIPTS_DIR:-$root/vars/transcripts}
  whisper_bin=${DISCORD_WHISPER_BIN:-$HOME/homebrew/bin/whisper-cli}
  whisper_model=${DISCORD_WHISPER_MODEL:-$root/vars/ggml-large-v3.bin}
  language=${DISCORD_WHISPER_LANGUAGE:-fr}
  parser=${DISCORD_SRT_PARSER:-$root/discord/lib/parse_srt.awk}
  temp_dir=$(mktemp -d "${TMPDIR:-/tmp}/meeting-transcribe.XXXXXX") || return 62
  entries="$temp_dir/entries.tsv"
  sorted="$temp_dir/sorted.tsv"
  participants="$temp_dir/participants.txt"
  trap 'rm -rf "$temp_dir"' RETURN

  shopt -s nullglob
  audio_files=("$audio_dir/${session_id}"__speaker-*.wav)
  shopt -u nullglob
  ((${#audio_files[@]})) || return 61

  : >"$entries"
  session_epoch=$(discord_transcribe_session_epoch "$session_id")

  for audio_file in "${audio_files[@]}"; do
    basename=${audio_file##*/}
    speaker_raw=${basename#*__speaker-}
    speaker_raw=${speaker_raw%.wav}
    speaker_id=${speaker_raw%%__name-*}
    speaker_name=$speaker_id
    if [[ $speaker_raw == *__name-* ]]; then
      encoded=${speaker_raw#*__name-}
      speaker_name=$(discord_transcribe_decode_name "$encoded")
      [[ -n $speaker_name ]] || speaker_name=$speaker_id
    fi

    output_prefix="$temp_dir/$speaker_id"
    srt="$output_prefix.srt"
    segments="$output_prefix.segments.tsv"
    "$whisper_bin" -m "$whisper_model" -f "$audio_file" -l "$language" -osrt -of "$output_prefix" >/dev/null 2>&1 || return 62
    [[ -f $srt ]] || return 62
    awk -f "$parser" "$srt" >"$segments" || return 62

    while IFS=$'\t' read -r start_ms text; do
      segment_epoch=$((session_epoch + start_ms / 1000))
      label=$(date -u -r "$segment_epoch" '+%H:%M:%S')
      printf '%s\t%s\t%s\t%s\n' "$segment_epoch" "$label" "$speaker_name" "$text" >>"$entries"
    done <"$segments"
    count=$((count + 1))
  done

  mkdir -p "$transcript_dir"
  transcript_file="$transcript_dir/$session_id.md"
  sort -n "$entries" >"$sorted"
  awk -F '\t' 'NF >= 3 {print $3}' "$sorted" | sort -u >"$participants"
  {
    printf '# Meeting Transcript\n\n## 👤 Participant\n'
    if [[ -s $participants ]]; then
      while IFS= read -r speaker_name; do printf -- '- %s\n' "$speaker_name"; done <"$participants"
    else
      printf -- '- unknown\n'
    fi
    printf '\n## 🗣 Transcript\n\n'
    while IFS=$'\t' read -r _ label speaker_name text; do
      printf '### [%s] %s\n%s\n\n' "$label" "$speaker_name" "$text"
    done <"$sorted"
    printf '%s\n' '---'
  } >"$transcript_file" || return 62

  if [[ -n $transcript_var ]]; then
    printf -v "$transcript_var" '%s' "$transcript_file"
    [[ -n $count_var ]] && printf -v "$count_var" '%s' "$count"
  else
    printf '%s\n' "$transcript_file"
  fi
}
