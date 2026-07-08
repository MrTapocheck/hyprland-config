#!/usr/bin/env bash
set -euo pipefail

active_class=$(hyprctl activewindow -j | jq -r '.class // empty')
[[ "$active_class" == "imv" ]] || exit 0

pid=$(pgrep -x imv-wayland | head -1)
[[ -n "$pid" ]] || exit 0

imv-msg "$pid" "exec /home/matehuslims/.config/hypr/imv-actions.sh menu"
