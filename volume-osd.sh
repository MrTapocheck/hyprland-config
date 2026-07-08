#!/usr/bin/env bash
set -euo pipefail

STEP="${STEP:-5%}"
SINK="@DEFAULT_AUDIO_SINK@"

focused_monitor() {
    hyprctl monitors -j | jq -r '.[] | select(.focused == true).name'
}

sink_description() {
    wpctl inspect "$SINK" 2>/dev/null \
        | awk -F'"' '/node.description/ { print $2; exit }'
}

case "${1:-}" in
    up|+)
        wpctl set-volume "$SINK" "${STEP}+"
        ;;
    down|-)
        wpctl set-volume "$SINK" "${STEP}-"
        ;;
    mute)
        wpctl set-mute "$SINK" toggle
        ;;
    *)
        echo "Usage: $0 {up|down|mute}" >&2
        exit 1
        ;;
esac

vol_line=$(wpctl get-volume "$SINK")
vol_raw=$(awk '{ print $2 }' <<<"$vol_line")
pct=$(awk -v v="$vol_raw" 'BEGIN { printf "%d", v * 100 }')
muted=false
[[ "$vol_line" == *"[MUTED]"* ]] && muted=true

desc=$(sink_description)
[[ -z "$desc" ]] && desc="Аудио"

if ((${#desc} > 30)); then
    desc="${desc:0:27}..."
fi

if $muted; then
    icon="sink-volume-muted-symbolic"
    text="${desc} · ${pct}% · mute"
else
    case "$pct" in
        0) icon="sink-volume-muted-symbolic" ;;
        [1-9]|[1-2][0-9]|3[0-3]) icon="sink-volume-low-symbolic" ;;
        [3-6][4-9]|[4-5][0-9]|6[0-6]) icon="sink-volume-medium-symbolic" ;;
        *) icon="sink-volume-high-symbolic" ;;
    esac
    text="${desc} · ${pct}%"
fi

swayosd-client \
    --monitor "$(focused_monitor)" \
    --custom-icon "$icon" \
    --custom-progress "$vol_raw" \
    --custom-progress-text "$text"
