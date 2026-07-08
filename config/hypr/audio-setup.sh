#!/usr/bin/env bash
set -euo pipefail

LAPTOP_CARD="alsa_card.pci-0000_03_00.6"
LAPTOP_PROFILE="output:analog-stereo+input:analog-stereo"
LAPTOP_SINK="alsa_output.pci-0000_03_00.6.analog-stereo"
DAC_PREFIX="alsa_output.usb-TempoTec"

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

sink_description() {
    local name="${1:-@DEFAULT_AUDIO_SINK@}"
    wpctl inspect "$name" 2>/dev/null \
        | awk -F'"' '/node.description/ { print $2; exit }'
}

pick_best_sink() {
    local line name
    while read -r line; do
        name=${line#*$'\t'}
        name=${name#*$'\t'}
        [[ "$name" == *".monitor" ]] && continue
        [[ "$name" == "$DAC_PREFIX"* ]] && { echo "$name"; return; }
    done < <(pactl list sinks short 2>/dev/null || true)

    if pactl list sinks short 2>/dev/null | awk -v s="$LAPTOP_SINK" '$2 == s { found=1 } END { exit !found }'; then
        echo "$LAPTOP_SINK"
    fi
}

ensure_audio() {
    if [[ "$(card_profile "$LAPTOP_CARD")" == "off" ]]; then
        pactl set-card-profile "$LAPTOP_CARD" "$LAPTOP_PROFILE" 2>/dev/null || true
    fi

    local current best
    current=$(default_sink_name)
    best=$(pick_best_sink)

    if [[ -z "$best" ]]; then
        return
    fi

    if [[ -z "$current" || "$current" == "auto_null" || "$current" != "$best" ]]; then
        if [[ "$best" == "$DAC_PREFIX"* ]] || [[ "$current" == "auto_null" || -z "$current" ]]; then
            pactl set-default-sink "$best" 2>/dev/null || true
        elif [[ "$current" != "$LAPTOP_SINK" && "$best" == "$LAPTOP_SINK" ]]; then
            pactl set-default-sink "$best" 2>/dev/null || true
        fi
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
