#!/usr/bin/env bash

OBS_CMD="${HOME}/.local/bin/obs-cmd"
WS_CONFIG="${HOME}/.config/obs-studio/plugin_config/obs-websocket/config.json"
RECORD_DIR="${HOME}/Videos/obs"

notify() {
    command -v mako >/dev/null 2>&1 && notify-send "$@"
}

obs_websocket_url() {
    local port pass
    port=$(jq -r '.server_port // 4455' "$WS_CONFIG")
    pass=$(jq -r '.server_password // empty' "$WS_CONFIG")
    printf 'obsws://127.0.0.1:%s/%s' "$port" "$pass"
}

obs_cmd() {
    "$OBS_CMD" -w "$(obs_websocket_url)" "$@"
}

recording_active() {
    obs_cmd recording status-active 2>/dev/null | grep -qi 'true'
}

ensure_obs() {
    pgrep -x obs >/dev/null && return 0

    obs --minimize-to-tray >/dev/null 2>&1 &
    for _ in $(seq 1 40); do
        obs_cmd info >/dev/null 2>&1 && return 0
        sleep 0.25
    done

    notify "OBS" "Не удалось подключиться к OBS"
    exit 1
}

mkdir -p "$RECORD_DIR"
ensure_obs
obs_cmd record-directory set "$RECORD_DIR" >/dev/null 2>&1 || true

if recording_active; then
    obs_cmd recording stop
    notify "OBS" "Запись сохранена в ~/Videos/obs" -u normal -i obs
else
    ws=$(hyprctl activeworkspace -j 2>/dev/null | jq -r '.id // "?"')
    obs_cmd recording start
    notify "OBS" "Запись workspace ${ws} начата" -u low -i obs
fi
