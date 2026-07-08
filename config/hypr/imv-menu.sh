#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

active_class=$(hyprctl activewindow -j | jq -r '.class // empty')
[[ "$active_class" == "imv" ]] || exit 0

pid=$(pgrep -x imv-wayland | head -1)
[[ -n "$pid" ]] || exit 0

imv-msg "$pid" "exec ${SCRIPT_DIR}/imv-actions.sh menu"
