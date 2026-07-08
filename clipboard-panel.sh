#!/usr/bin/env bash

THEME="$HOME/.config/rofi/clipboard.rasi"
SCRIPT="$HOME/.config/hypr/cliphist-rofi.sh"

rofi -no-config \
    -show clipboard \
    -modi "clipboard:${SCRIPT}" \
    -show-icons \
    -hover-select \
    -me-select-entry '' \
    -me-accept-entry MousePrimary \
    -theme "$THEME"
