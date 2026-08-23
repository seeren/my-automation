#!/usr/bin/env bash

clickup_priority_get_from_text() {
  local priority_text=$1
  local priority

  case $priority_text in
    *urgente*|*urgent*|*critique*)
      priority=1
      ;;
    *élevée*|*elevee*|*haute*|*important|*importante|*top*)
      priority=2
      ;;
    *normale*|*normal*|*moyenne|bof*)
      priority=3
      ;;
    *basse*|*faible*)
      priority=4
      ;;
    *)
      priority=3
      ;;
  esac

  printf '%s' "$priority"
}
