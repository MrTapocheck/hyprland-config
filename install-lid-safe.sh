#!/usr/bin/env bash
# Крышка и waybar: один путь — systemctl suspend (deep/S3) + hypridle wiki.
# Запуск: sudo ./install-lid-safe.sh
# После установки — перезагрузка (не logind restart в сессии!).
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
    echo "Запустите: sudo $0" >&2
    exit 1
fi

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

install -d /etc/systemd/logind.conf.d
rm -f /etc/systemd/logind.conf.d/10-lid-ignore.conf
install -m 644 "${REPO_ROOT}/etc/systemd/logind.conf.d/10-lid-suspend.conf" \
    /etc/systemd/logind.conf.d/10-lid-suspend.conf

install -d /etc/systemd/sleep.conf.d
rm -f /etc/systemd/sleep.conf.d/10-s2idle-only.conf
install -m 644 "${REPO_ROOT}/etc/systemd/sleep.conf.d/10-deep-preferred.conf" \
    /etc/systemd/sleep.conf.d/10-deep-preferred.conf

install -m 755 "${REPO_ROOT}/etc/systemd/system-sleep/99-hyprland-sleep.sh" \
    /usr/lib/systemd/system-sleep/99-hyprland-sleep.sh

chmod +x "${REPO_ROOT}/config/hypr/"{before-sleep,after-sleep,pre-suspend,post-resume,idle-screen-off,lid-close,suspend}.sh

# LACT лезет в amdgpu прямо в момент suspend — частая причина зависаний.
systemctl disable --now lactd.service 2>/dev/null || true

cat <<'EOF'

Готово.

ВАЖНО: перезагрузитесь — НЕ делайте systemctl restart systemd-logind в сессии.

  sudo reboot

Крышка = кнопка сна waybar (оба → systemctl suspend → deep/S3).

EOF
