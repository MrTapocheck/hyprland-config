#!/usr/bin/env bash

SIZE=24
theme="$1"
[[ -n "$theme" ]] || exit 1

hyprctl setcursor "$theme" "$SIZE" >/dev/null 2>&1
gsettings set org.gnome.desktop.interface cursor-theme "$theme" >/dev/null 2>&1
gsettings set org.gnome.desktop.interface cursor-size "$SIZE" >/dev/null 2>&1

echo "Applied: $theme ($SIZE px)"
