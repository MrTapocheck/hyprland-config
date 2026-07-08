#!/usr/bin/env bash
# NetworkManager и Wi‑Fi autoconnect — только после входа в Hyprland.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[[ -f "$SCRIPT_DIR/network.local.sh" ]] && source "$SCRIPT_DIR/network.local.sh"
WIFI_CONNS=("${WIFI_CONNS[@]:-YOUR_WIFI_1 YOUR_WIFI_2}")

ensure_nm() {
    if systemctl is-active --quiet NetworkManager; then
        return 0
    fi
    sudo systemctl reset-failed NetworkManager.service 2>/dev/null || true
    sudo systemctl start NetworkManager.service
}

wait_nm() {
    for _ in $(seq 1 50); do
        nmcli general status &>/dev/null && return 0
        sleep 0.2
    done
    return 1
}

connect_wifi() {
    nmcli radio wifi on 2>/dev/null || true

    for _ in $(seq 1 20); do
        nmcli -t -f DEVICE,STATE device status 2>/dev/null | grep -q '^wlp2s0:connected$' && return 0
        sleep 0.3
    done

    for conn in "${WIFI_CONNS[@]}"; do
        if nmcli connection up "$conn" 2>/dev/null; then
            return 0
        fi
    done
}

ensure_nm || exit 1
wait_nm || exit 1
connect_wifi &

if ! pgrep -x nm-applet >/dev/null; then
    nm-applet --indicator &
fi
