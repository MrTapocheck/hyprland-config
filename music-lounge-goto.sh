#!/usr/bin/env bash
set -euo pipefail

SCRIPT="${HOME}/.config/hypr/music-lounge.sh"
current=$(hyprctl activeworkspace -j | jq -r '.id')

"$SCRIPT" ensure-daemon

if [[ "$current" == "8" ]]; then
    "$SCRIPT" start
else
    hyprctl dispatch workspace 8
fi
