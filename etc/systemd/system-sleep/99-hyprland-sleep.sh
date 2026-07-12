#!/usr/bin/env bash
# systemd-sleep hook: pre/post suspend (lid, power button, systemctl suspend)
set -euo pipefail

run_as_session_user() {
    local script="$1"
    local uid user home session

    uid=$(loginctl list-sessions --no-legend 2>/dev/null | awk '$5 == "user" { print $2; exit }')
    [[ -n "$uid" ]] || return 0
    user=$(id -un "$uid" 2>/dev/null) || return 0
    home=$(getent passwd "$uid" | cut -d: -f6)
    [[ -x "${home}/.config/hypr/${script}" ]] || return 0

    session=$(loginctl list-sessions --no-legend 2>/dev/null | awk '$5 == "user" { print $1; exit }')
    wayland=$(loginctl show-session "$session" -p Display --value 2>/dev/null || true)
    [[ -n "$wayland" ]] || wayland=wayland-1

    runuser -u "$user" -- env \
        XDG_RUNTIME_DIR="/run/user/${uid}" \
        DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/${uid}/bus" \
        WAYLAND_DISPLAY="${wayland}" \
        "${home}/.config/hypr/${script}"
}

case "${1}/${2}" in
    pre/*)
        run_as_session_user pre-suspend.sh
        systemctl stop lactd.service 2>/dev/null || true
        ;;
    post/*)
        if systemctl is-enabled lactd.service >/dev/null 2>&1; then
            systemctl start lactd.service 2>/dev/null || true
        fi
        run_as_session_user post-resume.sh
        ;;
esac

exit 0
