#!/usr/bin/env bash
set -euo pipefail

LAPTOP_CARD="alsa_card.pci-0000_03_00.6"
LAPTOP_PROFILE="output:analog-stereo+input:analog-stereo"
LAPTOP_SINK="alsa_output.pci-0000_03_00.6.analog-stereo"
DAC_PREFIX="alsa_output.usb-TempoTec"
PREF_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/hypr/audio-output.pref"

read_pref() {
    if [[ -f "$PREF_FILE" ]]; then
        tr -d '[:space:]' <"$PREF_FILE"
    else
        echo "auto"
    fi
}

card_profile() {
    local card="$1"
    pactl list cards 2>/dev/null | awk -v card="$card" '
        $0 ~ "^[[:space:]]*Name: " card "$" { found=1; next }
        found && /^[[:space:]]*Active Profile:/ { print $3; exit }
    '
}

default_sink_name() {
    pactl get-default-sink 2>/dev/null || true
}

sink_available() {
    local sink="$1"
    pactl list sinks short 2>/dev/null | awk -v s="$sink" '$2 == s { found=1 } END { exit !found }'
}

find_dac_sink() {
    pactl list sinks short 2>/dev/null | awk -v p="$DAC_PREFIX" '
        $2 ~ "^" p && $2 !~ /\.monitor$/ { print $2; exit }
    '
}

sink_description() {
    local name="${1:-@DEFAULT_AUDIO_SINK@}"
    wpctl inspect "$name" 2>/dev/null \
        | awk -F'"' '/node.description/ { print $2; exit }'
}

resolve_target_sink() {
    local pref dac_sink
    pref=$(read_pref)
    dac_sink=$(find_dac_sink)

    case "$pref" in
        laptop)
            echo "$LAPTOP_SINK"
            ;;
        dac)
            if [[ -n "$dac_sink" ]]; then
                echo "$dac_sink"
            else
                echo "$LAPTOP_SINK"
            fi
            ;;
        auto|*)
            if [[ -n "$dac_sink" ]]; then
                echo "$dac_sink"
            else
                echo "$LAPTOP_SINK"
            fi
            ;;
    esac
}

ensure_audio() {
    if [[ "$(card_profile "$LAPTOP_CARD")" == "off" ]]; then
        pactl set-card-profile "$LAPTOP_CARD" "$LAPTOP_PROFILE" 2>/dev/null || true
    fi

    local target current
    target=$(resolve_target_sink)
    current=$(default_sink_name)

    if [[ -z "$target" ]]; then
        return
    fi

    if ! sink_available "$target"; then
        target="$LAPTOP_SINK"
    fi

    if [[ -z "$current" || "$current" == "auto_null" || "$current" != "$target" ]]; then
        pactl set-default-sink "$target" 2>/dev/null || true
    fi
}

notify_sink_change() {
    local desc="${1:-}"
    [[ -z "$desc" ]] && desc=$(sink_description @DEFAULT_AUDIO_SINK@)
    [[ -z "$desc" ]] && return

    if ((${#desc} > 36)); then
        desc="${desc:0:33}..."
    fi

    command -v notify-send >/dev/null 2>&1 \
        && notify-send "Звук" "$desc" -u low -i audio-card-analog \
        || true
}

LAST_SINK=""

report_if_changed() {
    local current desc
    current=$(default_sink_name)
    [[ -z "$current" || "$current" == "$LAST_SINK" ]] && return
    LAST_SINK="$current"
    desc=$(sink_description "$current")
    notify_sink_change "$desc"
}

ensure_audio
report_if_changed

(
    pactl subscribe 2>/dev/null | while read -r event; do
        case "$event" in
            *"new sink"*|*"remove sink"*|*"change"*"fallback"*|*"Server"*"New"*)
                sleep 0.4
                ensure_audio
                report_if_changed
                ;;
        esac
    done
) &
