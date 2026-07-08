#!/usr/bin/env bash
set -euo pipefail

BACKLIGHT="${BACKLIGHT:-amdgpu_bl1}"
STEP="${STEP:-10}"

focused_monitor() {
    hyprctl monitors -j | jq -r '.[] | select(.focused == true).name'
}

case "${1:-}" in
    up|+)
        delta="+${STEP}%"
        ;;
    down|-)
        delta="${STEP}%-"
        ;;
    *)
        echo "Usage: $0 {up|down}" >&2
        exit 1
        ;;
esac

if ! brightnessctl --device="$BACKLIGHT" set "$delta" 2>/dev/null; then
    brightnessctl set "$delta"
fi

current=$(brightnessctl --device="$BACKLIGHT" get 2>/dev/null || brightnessctl get)
max=$(brightnessctl --device="$BACKLIGHT" max 2>/dev/null || brightnessctl max)
pct=$(( current * 100 / max ))
progress=$(awk -v c="$current" -v m="$max" 'BEGIN { printf "%.3f", c / m }')

swayosd-client \
    --monitor "$(focused_monitor)" \
    --custom-icon "display-brightness-symbolic" \
    --custom-progress "$progress" \
    --custom-progress-text "${pct}%"
