#!/usr/bin/env bash

STATE="$HOME/.config/hypr/power-mode.state"
RESTORE="$HOME/.config/hypr/power-mode.restore"
BACKLIGHT="${BACKLIGHT_DEVICE:-amdgpu_bl1}"
CPUPOWER="/usr/bin/cpupower"

get_mode() {
    [[ -f "$STATE" ]] && cat "$STATE" || echo "max"
}

read_governor() {
    cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo "schedutil"
}

read_freq() {
    local which=$1
    cat "/sys/devices/system/cpu/cpu0/cpufreq/scaling_${which}_freq" 2>/dev/null
}

read_brightness() {
    brightnessctl g -d "$BACKLIGHT" 2>/dev/null || brightnessctl g 2>/dev/null || echo "130"
}

bluetooth_on() {
    bluetoothctl show 2>/dev/null | grep -q "Powered: yes"
}

save_restore() {
    local gov max_freq min_freq brightness bt

    gov=$(read_governor)
    max_freq=$(read_freq max)
    min_freq=$(read_freq min)
    brightness=$(read_brightness)
    bt=false
    bluetooth_on && bt=true

    jq -n \
        --arg governor "$gov" \
        --arg max_freq "$max_freq" \
        --arg min_freq "$min_freq" \
        --argjson brightness "$brightness" \
        --argjson bluetooth "$bt" \
        '{
            governor: $governor,
            max_freq: $max_freq,
            min_freq: $min_freq,
            brightness: $brightness,
            bluetooth: $bluetooth
        }' > "$RESTORE"
}

apply_cpupower() {
    local governor=$1 max_freq=$2 min_freq=$3
    sudo -n "$CPUPOWER" frequency-set -g "$governor" -u "$max_freq" -d "$min_freq" >/dev/null 2>&1
}

apply_max() {
    local governor max_freq min_freq brightness bt

    powerprofilesctl set balanced >/dev/null 2>&1

    if [[ -f "$RESTORE" ]]; then
        governor=$(jq -r '.governor // "schedutil"' "$RESTORE")
        max_freq=$(jq -r '.max_freq // "2300000"' "$RESTORE")
        min_freq=$(jq -r '.min_freq // "1400000"' "$RESTORE")
        brightness=$(jq -r '.brightness // empty' "$RESTORE")
        bt=$(jq -r '.bluetooth // false' "$RESTORE")
    else
        governor="schedutil"
        max_freq="2300000"
        min_freq="1400000"
        brightness=""
        bt=false
    fi

    apply_cpupower "$governor" "$max_freq" "$min_freq"

    if [[ -n "$brightness" ]]; then
        brightnessctl set "$brightness" -d "$BACKLIGHT" >/dev/null 2>&1 \
            || brightnessctl set "$brightness" >/dev/null 2>&1
    else
        brightnessctl set 50% -d "$BACKLIGHT" >/dev/null 2>&1 \
            || brightnessctl set 50% >/dev/null 2>&1
    fi

    if [[ "$bt" == "true" ]]; then
        bluetoothctl power on >/dev/null 2>&1
    fi

    echo "max" > "$STATE"
}

apply_min() {
    if [[ "$(get_mode)" != "min" ]]; then
        save_restore
    fi

    powerprofilesctl set power-saver >/dev/null 2>&1
    apply_cpupower powersave 1400000 1400000

    brightnessctl set 1 -d "$BACKLIGHT" >/dev/null 2>&1 \
        || brightnessctl set 1 >/dev/null 2>&1

    bluetoothctl power off >/dev/null 2>&1

    echo "min" > "$STATE"
}

toggle_mode() {
    if [[ "$(get_mode)" == "min" ]]; then
        apply_max
    else
        apply_min
    fi
}

case "${1:-}" in
    get)
        get_mode
        ;;
    toggle)
        toggle_mode
        ;;
    set)
        case "${2:-}" in
            min) apply_min ;;
            max) apply_max ;;
            *) echo "use min or max" >&2; exit 1 ;;
        esac
        ;;
    label)
        if [[ "$(get_mode)" == "min" ]]; then
            echo "on"
        else
            echo "off"
        fi
        ;;
    *)
        echo "Usage: $0 {get|toggle|set min|max|label}" >&2
        exit 1
        ;;
esac
