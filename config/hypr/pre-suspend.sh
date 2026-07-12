#!/usr/bin/env bash
# Вызывается перед suspend (hypridle / system-sleep / suspend.sh)
set -euo pipefail

export PATH="${HOME}/.local/bin:/usr/bin:/bin"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"

HYPR="${HOME}/.config/hypr"

playerctl pause 2>/dev/null || true

if [[ -x "${HYPR}/music-lounge.sh" ]]; then
    "${HYPR}/music-lounge.sh" stop 2>/dev/null || true
fi

pkill -x mpvpaper 2>/dev/null || true
pkill -x cava 2>/dev/null || true

# VPN-страж сна иногда мешает amdgpu resume
systemctl --user stop AmneziaVPN.service 2>/dev/null || true

# dpms off перед suspend не делаем — amdgpu на этом ноутбуке ломает resume
