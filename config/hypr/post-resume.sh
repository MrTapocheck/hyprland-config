#!/usr/bin/env bash
# После пробуждения из suspend — восстановить DRM/Wayland
set -euo pipefail

export PATH="${HOME}/.local/bin:/usr/bin:/bin"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-1}"

HYPR="${HOME}/.config/hypr"

hypr_ok() {
    command -v hyprctl >/dev/null 2>&1 && hyprctl monitors -j >/dev/null 2>&1
}

# Ждём, пока Hyprland снова ответит после thaw
for _ in 1 2 3 4 5 6 7 8 9 10; do
    hypr_ok && break
    sleep 0.5
done

hypr_ok || exit 0

# Перескан DRM-коннекторов (amdgpu после s2idle)
for status in /sys/class/drm/card*-*/status; do
    [[ -w "$status" ]] && echo detect >"$status" 2>/dev/null || true
done

sleep 0.3

hyprctl dispatch dpms on 2>/dev/null || true
hyprctl reload 2>/dev/null || true

# hyprlock мог остаться на чёрном кадре — перерисовать или снять
if pidof hyprlock >/dev/null 2>&1; then
    pkill -USR1 hyprlock 2>/dev/null || true
    sleep 0.4
    if ! hyprctl monitors -j 2>/dev/null | grep -q '"dpmsStatus": true'; then
        pkill -x hyprlock 2>/dev/null || true
        loginctl unlock-session 2>/dev/null || true
        hyprctl dispatch dpms on 2>/dev/null || true
    fi
fi

sleep 0.2
[[ -x "${HYPR}/workspace-wallpapers.sh" ]] && "${HYPR}/workspace-wallpapers.sh" 2>/dev/null || true

if hypr_ok && ! pgrep -x waybar >/dev/null; then
    nohup waybar >/dev/null 2>&1 &
fi

# Amnezia поднимется сама, если была включена до сна
systemctl --user start AmneziaVPN.service 2>/dev/null || true
