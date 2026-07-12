#!/usr/bin/env bash
# Полноценный GUI скриншотов (KDE Spectacle): режимы, сохранение в файл, буфер.
set -euo pipefail

mkdir -p "${HOME}/Pictures"

if ! command -v spectacle >/dev/null 2>&1; then
    notify-send "Скриншот" "Установите spectacle: sudo pacman -S spectacle" -u critical 2>/dev/null || true
    exit 1
fi

exec env QT_QPA_PLATFORM=wayland XDG_CURRENT_DESKTOP=Hyprland \
    spectacle --launchonly
