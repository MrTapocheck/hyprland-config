#!/usr/bin/env bash

# Ждём полной инициализации Hyprland
sleep 1.5

hyprctl dispatch exec "[workspace 1 silent] chromium"
sleep 0.4

hyprctl dispatch exec "[workspace 2 silent] yakuake"
sleep 0.4

hyprctl dispatch workspace 3
hyprctl dispatch exec webcord
sleep 0.8
hyprctl dispatch exec Telegram
sleep 0.4

hyprctl dispatch exec "[workspace 4 silent] thunar"
