#!/usr/bin/env bash
set -euo pipefail

BACKLIGHT="${BACKLIGHT:-amdgpu_bl1}"
STEP="${STEP:-10}"

focused_monitor() {
    hyprctl monitors -j | jq -r '.[] | select(.focused == true).name'
}

case "${1:-}" in
    up|+)
        delta="+${STEP}"
        ;;
    down|-)
        delta="-${STEP}"
        ;;
    *)
        echo "Usage: $0 {up|down}" >&2
        exit 1
        ;;
esac

swayosd-client \
    --monitor "$(focused_monitor)" \
    --brightness "$delta" \
    --device "$BACKLIGHT"
