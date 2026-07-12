#!/usr/bin/env bash
# hypridle before_sleep_cmd — по образцу Hyprland wiki + наши GPU-фиксы
set -euo pipefail

loginctl lock-session 2>/dev/null || true
"${HOME}/.config/hypr/pre-suspend.sh" 2>/dev/null || true
