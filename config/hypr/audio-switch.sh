#!/usr/bin/env bash
set -euo pipefail

ROFI_THEME="${ROFI_THEME:-$HOME/.config/rofi/config.rasi}"
PREF_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/hypr/audio-output.pref"

LAPTOP_SINK="alsa_output.pci-0000_03_00.6.analog-stereo"
DAC_PREFIX="alsa_output.usb-TempoTec"

save_pref() {
    local pref="$1"
    mkdir -p "$(dirname "$PREF_FILE")"
    printf '%s\n' "$pref" >"$PREF_FILE"
}

current_default() {
    pactl get-default-sink 2>/dev/null || true
}

find_dac_sink() {
    pactl list sinks short 2>/dev/null | awk -v p="$DAC_PREFIX" '
        $2 ~ "^" p && $2 !~ /\.monitor$/ { print $2; exit }
    '
}

sink_label() {
    local sink="$1"

    if [[ "$sink" == "$LAPTOP_SINK" ]]; then
        echo "Ноутбук"
        return
    fi

    if [[ "$sink" == "$DAC_PREFIX"* ]]; then
        echo "M3 Pro"
        return
    fi

    pactl list sinks 2>/dev/null | awk -v sink="$sink" '
        /^[[:space:]]*Name: / { cur=$2; next }
        cur == sink && /^[[:space:]]*Description:/ {
            $1 = $2 = ""
            sub(/^[[:space:]]+/, "")
            print
            exit
        }
    '
}

notify_switch() {
    local text="$1"
    command -v notify-send >/dev/null 2>&1 \
        && notify-send "Звук" "$text" -u low -i audio-card-analog \
        || true
}

apply_output() {
    local sink="$1"
    local pref="$2"

    pactl set-default-sink "$sink" 2>/dev/null || return 1
    save_pref "$pref"

    local label
    label=$(sink_label "$sink")
    [[ -z "$label" ]] && label="Аудио"

    notify_switch "$label"
}

build_menu() {
    local current="${1:-}"
    local dac_sink
    local -a lines=()

    dac_sink=$(find_dac_sink)

    local marker="  "
    [[ "$current" == "$LAPTOP_SINK" ]] && marker="● "
    lines+=("${marker}Ноутбук"$'\t'"${LAPTOP_SINK}"$'\t'"laptop")

    if [[ -n "$dac_sink" ]]; then
        marker="  "
        [[ "$current" == "$dac_sink" ]] && marker="● "
        lines+=("${marker}M3 Pro"$'\t'"${dac_sink}"$'\t'"dac")
    fi

    printf '%s\n' "${lines[@]}"
}

show_menu() {
    local current
    current=$(current_default)

    local -a lines=()
    mapfile -t lines < <(build_menu "$current")

    local -a labels=()
    local line label
    for line in "${lines[@]}"; do
        label=${line%%$'\t'*}
        labels+=("$label")
    done

    local choice
    choice=$(
        printf '%s\n' "${labels[@]}" \
            | rofi -dmenu -i -p "Вывод звука" -theme "$ROFI_THEME" 2>/dev/null \
            || printf '%s\n' "${labels[@]}" \
                | rofi -dmenu -i -p "Вывод звука"
    ) || return 0

    [[ -n "$choice" ]] || return 0

    local sink="" pref=""
    for line in "${lines[@]}"; do
        label=${line%%$'\t'*}
        if [[ "$label" == "$choice" ]]; then
            IFS=$'\t' read -r _ sink pref <<<"$line"
            break
        fi
    done

    [[ -n "$sink" && -n "$pref" ]] || return 0
    apply_output "$sink" "$pref"
}

show_menu
