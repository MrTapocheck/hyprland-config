#!/usr/bin/env bash
# hypridle after_sleep_cmd — wiki: dpms on + наше восстановление amdgpu
set -euo pipefail

hyprctl dispatch 'hl.dsp.dpms({ action = "enable" })' 2>/dev/null \
    || hyprctl dispatch dpms on 2>/dev/null \
    || true

"${HOME}/.config/hypr/post-resume.sh" 2>/dev/null || true
