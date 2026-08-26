#!/usr/bin/env bash

SHORTCUTS_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

exec "$SHORTCUTS_ROOT/bin/shortcuts" meeting_record "$@"
