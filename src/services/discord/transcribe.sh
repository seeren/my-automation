#!/usr/bin/env bash

discord_transcribe_session() {
  local session_id=$1 root audio_dir transcript_file temp_dir entries audio_file
  local name speaker_id encoded padding prefix start_ms text epoch label

  root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)
  audio_dir="$root/vars/audios"
  transcript_file="$root/vars/transcripts/$session_id.md"
  temp_dir="/tmp/meeting-transcribe-$session_id-$$"
  entries="$temp_dir/entries.tsv"
  mkdir -p "$temp_dir"

  set -- "$audio_dir/${session_id}"__speaker-*.wav
  if [[ ! -e $1 ]]; then
    rm -rf "$temp_dir"
    return 61
  fi

  epoch=${session_id%Z}
  epoch=${epoch%-*}
  epoch=$(date -j -u -f '%Y-%m-%dT%H-%M-%S' "$epoch" '+%s' 2>/dev/null || date -u '+%s')

  for audio_file in "$@"; do
    name=${audio_file##*__speaker-}
    name=${name%.wav}
    speaker_id=${name%%__name-*}

    if [[ $name == *__name-* ]]; then
      encoded=${name#*__name-}
      encoded=$(printf '%s' "$encoded" | tr '_-' '/+')
      padding=$((${#encoded} % 4))
      [[ $padding -eq 2 ]] && encoded+='=='
      [[ $padding -eq 3 ]] && encoded+='='
      name=$(printf '%s' "$encoded" | base64 -D 2>/dev/null || true)
    else
      name=$speaker_id
    fi
    [[ -n $name ]] || name=$speaker_id

    prefix="$temp_dir/$speaker_id"
    "$HOME/homebrew/bin/whisper-cli" \
      -m "$root/vars/ggml-large-v3.bin" -f "$audio_file" -l fr -osrt -of "$prefix" \
      >/dev/null 2>&1 || { rm -rf "$temp_dir"; return 62; }
    awk -f "$root/src/services/discord/parse_srt.awk" "$prefix.srt" >"$prefix.tsv" || {
      rm -rf "$temp_dir"
      return 62
    }

    while IFS=$'\t' read -r start_ms text; do
      label=$(date -u -r "$((epoch + start_ms / 1000))" '+%H:%M:%S')
      printf '%s\t%s\t%s\t%s\n' "$start_ms" "$label" "$name" "$text" >>"$entries"
    done <"$prefix.tsv"
  done

  sort -n "$entries" >"$temp_dir/sorted.tsv"
  awk -F '\t' '{print $3}' "$temp_dir/sorted.tsv" | sort -u >"$temp_dir/participants.txt"
  {
    printf '# Meeting Transcript\n\n## 👤 Participant\n'
    while IFS= read -r name; do printf -- '- %s\n' "$name"; done <"$temp_dir/participants.txt"
    printf '\n## 🗣 Transcript\n\n'
    while IFS=$'\t' read -r _ label name text; do
      printf '### [%s] %s\n%s\n\n' "$label" "$name" "$text"
    done <"$temp_dir/sorted.tsv"
    printf '%s\n' '---'
  } >"$transcript_file"

  rm -rf "$temp_dir"
}
