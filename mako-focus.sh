#!/usr/bin/env bash

ID="${id:-}"
[[ -z "$ID" ]] && exit 0

fetch_app() {
    makoctl list -j | jq -r --argjson id "$ID" '.[] | select(.id == $id) | .app_name' | head -1
}

APP=$(fetch_app)
if [[ -z "$APP" || "$APP" == "null" ]]; then
    APP=$(makoctl history -j | jq -r --argjson id "$ID" '.[] | select(.id == $id) | .app_name' | head -1)
fi
[[ -z "$APP" || "$APP" == "null" ]] && exit 0

map_app() {
    local app="${1,,}"
    case "$app" in
        org.telegram.desktop|*telegram*) printf '%s\n' "org.telegram.desktop" "telegram" ;;
        org.chromium.*|chromium*|google-chrome*) printf '%s\n' "chromium" "chrome" ;;
        org.kde.yakuake|*yakuake*) printf '%s\n' "yakuake" "org.kde.yakuake" ;;
        *webcord*) printf '%s\n' "webcord" "WebCord" ;;
        *thunar*) printf '%s\n' "thunar" "Thunar" ;;
        *firefox*) printf '%s\n' "firefox" "Firefox" ;;
        *)
            printf '%s\n' "$1"
            if [[ "$app" == *.* ]]; then
                printf '%s\n' "${app##*.}"
            fi
            ;;
    esac
}

find_client() {
    local needle="${1,,}"
    [[ -z "$needle" ]] && return 1
    hyprctl clients -j | jq -r --arg n "$needle" '
        .[] | select(
            (.class | ascii_downcase | contains($n))
            or (.initialClass | ascii_downcase | contains($n))
        ) | "\(.workspace.id)\t\(.address)"' | head -1
}

CLIENT=""
while IFS= read -r needle; do
    CLIENT=$(find_client "$needle")
    [[ -n "$CLIENT" ]] && break
done < <(map_app "$APP")

if [[ -z "$CLIENT" ]]; then
    makoctl invoke -n "$ID" default >/dev/null 2>&1 || true
    exit 0
fi

WS=${CLIENT%%$'\t'*}
ADDR=${CLIENT#*$'\t'}

hyprctl dispatch workspace "$WS" >/dev/null 2>&1
hyprctl dispatch focuswindow "address:${ADDR}" >/dev/null 2>&1
makoctl dismiss -n "$ID" >/dev/null 2>&1 || true
