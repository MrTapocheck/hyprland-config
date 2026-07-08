#!/usr/bin/env bash

STATE="/run/user/$(id -u)/waybar-super.state"
TIMEOUT_MS=400
NOW=$(($(date +%s%N) / 1000000))

toggle_waybar() {
    if ! pgrep -x waybar >/dev/null; then
        waybar &
        return
    fi
    killall -SIGUSR1 waybar 2>/dev/null
}

if [[ -f "$STATE" ]]; then
    LAST=$(<"$STATE")
    if (( NOW - LAST < TIMEOUT_MS )); then
        rm -f "$STATE"
        toggle_waybar
        exit 0
    fi
fi

echo "$NOW" > "$STATE"

(
    sleep "$(awk "BEGIN { print $TIMEOUT_MS / 1000 }")"
    [[ -f "$STATE" ]] && rm -f "$STATE"
) &
