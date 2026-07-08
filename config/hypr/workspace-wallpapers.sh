#!/usr/bin/env bash

WALLPAPER_DIR="$HOME/Pictures/wallpapers"
LOCK_FILE="${XDG_RUNTIME_DIR}/hypr/workspace-wallpapers.lock"
DEBOUNCE_PID=""

exec 9>"$LOCK_FILE"
flock -n 9 || exit 0

get_wallpaper() {
    local ws="$1"
    local file

    for ext in jpeg jpg png webp; do
        file="${WALLPAPER_DIR}/wall${ws}.${ext}"
        if [[ -f "$file" ]]; then
            echo "$file"
            return
        fi
    done

    echo "${WALLPAPER_DIR}/wall1.jpeg"
}

set_wallpaper() {
    local monitor=$1 wp=$2

    if command -v awww >/dev/null 2>&1 && awww query >/dev/null 2>&1; then
        awww img "$wp" \
            --outputs "$monitor" \
            --resize crop \
            --transition-type fade \
            --transition-duration 0.35 \
            --transition-fps 60 >/dev/null 2>&1
    else
        hyprctl hyprpaper wallpaper "${monitor},${wp},cover" >/dev/null 2>&1
    fi
}

update_wallpapers() {
    while IFS='|' read -r monitor workspace; do
        [[ -n "$monitor" && -n "$workspace" ]] || continue
        set_wallpaper "$monitor" "$(get_wallpaper "$workspace")"
    done < <(hyprctl monitors -j | jq -r '.[] | "\(.name)|\(.activeWorkspace.id)"')
}

schedule_update() {
    if [[ -n "$DEBOUNCE_PID" ]]; then
        kill "$DEBOUNCE_PID" 2>/dev/null || true
    fi
    ( sleep 0.08; update_wallpapers ) &
    DEBOUNCE_PID=$!
}

update_wallpapers

while read -r line; do
    case "$line" in
        "workspace>>"*|"workspacev2>>"*|moveworkspace*)
            schedule_update
            ;;
    esac
done < <(socat -U - "UNIX-CONNECT:${XDG_RUNTIME_DIR}/hypr/${HYPRLAND_INSTANCE_SIGNATURE}/.socket2.sock")
