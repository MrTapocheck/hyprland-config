#!/usr/bin/env bash
# NetworkManager после входа в Hyprland + autoconnect Wi‑Fi.
# Запуск: sudo ~/.config/hypr/boot-fix-network.sh
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
    echo "Запустите: sudo $0" >&2
    exit 1
fi

USER_NAME="${SUDO_USER:-$(logname 2>/dev/null || echo "$USER")}"
SUDOERS=/etc/sudoers.d/hypr-network

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[[ -f "$SCRIPT_DIR/network.local.sh" ]] && source "$SCRIPT_DIR/network.local.sh"
WIFI_CONNS=("${WIFI_CONNS[@]:-YOUR_WIFI_1 YOUR_WIFI_2}")

echo "==> NetworkManager только после входа (не на этапе Ly)..."
systemctl disable NetworkManager-wait-online.service 2>/dev/null || true
systemctl disable NetworkManager.service
systemctl reset-failed NetworkManager.service 2>/dev/null || true

echo "==> Разрешаем старт NM из Hyprland без пароля..."
cat >"$SUDOERS" <<EOF
# Hyprland: ~/.config/hypr/network-start.sh
${USER_NAME} ALL=(ALL) NOPASSWD: /usr/bin/systemctl start NetworkManager.service, /usr/bin/systemctl reset-failed NetworkManager.service
EOF
chmod 440 "$SUDOERS"
visudo -c -f "$SUDOERS"

echo "==> Автоподключение к сохранённым Wi‑Fi..."
for conn in "${WIFI_CONNS[@]}"; do
    if nmcli connection show "$conn" &>/dev/null; then
        nmcli connection modify "$conn" connection.autoconnect yes
        echo "    autoconnect yes: $conn"
    fi
done
if ((${#WIFI_CONNS[@]} > 0)); then
    nmcli connection modify "${WIFI_CONNS[0]}" connection.autoconnect-priority 100 2>/dev/null || true
fi
if ((${#WIFI_CONNS[@]} > 1)); then
    nmcli connection modify "${WIFI_CONNS[1]}" connection.autoconnect-priority 90 2>/dev/null || true
fi

echo "==> Лишние сервисы на загрузке остаются выключенными..."
systemctl disable postgresql.service 2>/dev/null || true
systemctl disable cups.service cups.socket 2>/dev/null || true
systemctl disable input-remapper.service 2>/dev/null || true

echo
echo "Готово. Перезагрузитесь."
echo "  • До Ly: NetworkManager не стартует (быстрая загрузка)"
echo "  • После входа: ~/.config/hypr/network-start.sh поднимет Wi‑Fi сам"
