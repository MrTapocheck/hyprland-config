#!/usr/bin/env bash

mode=$("$HOME/.config/hypr/power-mode.sh" label)
gov=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null)
max_khz=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq 2>/dev/null)
max_mhz=$((max_khz / 1000))

if [[ "$mode" == "on" ]]; then
    text=$'\U000f0521'
    class="on"
    tooltip="Экономный режим · ${gov} · max ${max_mhz} MHz"
else
    text=$'\U000f0522'
    class="off"
    tooltip="Обычный режим · ${gov} · max ${max_mhz} MHz"
fi

jq -cn --arg text "$text" --arg class "$class" --arg tooltip "$tooltip" \
    '{text: $text, class: $class, tooltip: $tooltip}'
