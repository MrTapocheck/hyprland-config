#!/usr/bin/env bash

STATE="${XDG_RUNTIME_DIR}/hypr/wallpaper-peek.state"
SPECIAL="special:peek"

restore_windows() {
    [[ -f "$STATE" ]] || return 0

    while IFS='|' read -r addr ws; do
        [[ -n "$addr" && -n "$ws" ]] || continue
        hyprctl dispatch movetoworkspacesilent "${ws},address:${addr}" >/dev/null 2>&1
    done < "$STATE"

    rm -f "$STATE"
}

hide_windows() {
    mapfile -t clients < <(
        hyprctl clients -j | jq -r '
            .[]
            | select(.mapped == true)
            | select(.workspace.name | startswith("special:") | not)
            | "\(.address)|\(.workspace.id)"
        '
    )

    [[ ${#clients[@]} -gt 0 ]] || return 0

    : > "$STATE"
    for entry in "${clients[@]}"; do
        IFS='|' read -r addr ws <<< "$entry"
        [[ -n "$addr" && -n "$ws" ]] || continue
        printf '%s|%s\n' "$addr" "$ws" >> "$STATE"
        hyprctl dispatch movetoworkspacesilent "${SPECIAL},address:${addr}" >/dev/null 2>&1
    done
}

if [[ -f "$STATE" ]]; then
    restore_windows
else
    hide_windows
fi
