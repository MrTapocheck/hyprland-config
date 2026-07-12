#!/usr/bin/env bash
# Только idle (hypridle): lock + экран off, без kernel suspend
set -euo pipefail

HYPR="${HOME}/.config/hypr"

command -v hyprctl >/dev/null 2>&1 \
    && hyprctl dispatch 'hl.dsp.dpms({ action = "disable" })' 2>/dev/null \
    || true

if ! pidof hyprlock >/dev/null 2>&1; then
    "${HYPR}/hyprlock.sh" >/dev/null 2>&1 &
fi
