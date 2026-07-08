#!/usr/bin/env bash
# Однократная настройка: ускорить загрузку до Ly, сеть — после входа в Hyprland.
# Запуск: sudo ~/.config/hypr/boot-optimize.sh
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
    echo "Запустите: sudo $0" >&2
    exit 1
fi

exec "$(dirname "$0")/boot-fix-network.sh"
