#!/usr/bin/env bash
# Suspend по кнопке waybar / XF86Sleep / Super+Shift+Z
# pre/post: hypridle + /usr/lib/systemd/system-sleep/99-hyprland-sleep.sh
set -euo pipefail

playerctl pause 2>/dev/null || true
systemctl suspend
