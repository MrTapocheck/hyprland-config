#!/usr/bin/env bash
# Переустановить Ventoy на 32 ГБ и скопировать Win7 + Win10 + Win11 с 64 ГБ флешки.
# Запуск: sudo ~/.config/hypr/ventoy-win-only.sh
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
    echo "Запустите: sudo $0" >&2
    exit 1
fi

ISO_WIN7="en_windows_7_ultimate_with_sp1_x64_dvd_u_677332.iso"
ISO_WIN10="Windows 10 Pro 22H2 RU EN 19045.7058 by Revision.iso"
ISO_WIN11="Win11_25H2_English_x64_v2.iso"
WORK=/tmp/ventoy
MNT=/mnt/ventoy32
VENTOY_VER="1.1.05"
USER_NAME="${SUDO_USER:-matehuslims}"

usb_disk_by_size() {
    local min="$1" max="$2"
    lsblk -dnpo NAME,SIZE,TRAN | awk -v min="$min" -v max="$max" '
        $3 == "usb" {
            gsub(",", ".", $2)
            gsub(/[^0-9.]/, "", $2)
            if ($2 + 0 >= min && $2 + 0 <= max) print $1
        }'
}

USB_DEV=$(usb_disk_by_size 20 40 | head -1)
SRC_DEV=$(usb_disk_by_size 40 999 | head -1)

[[ -n "$USB_DEV" ]] || { echo "Не найдена 32 ГБ USB-флешка." >&2; exit 1; }
[[ -n "$SRC_DEV" ]] || { echo "Не найдена 64 ГБ USB-флешка." >&2; exit 1; }

mount_src() {
    local m
    m=$(findmnt -nro TARGET "${SRC_DEV}1" 2>/dev/null || true)
    if [[ -z "$m" ]]; then
        udisksctl mount -b "${SRC_DEV}1" >/dev/null
        m=$(findmnt -nro TARGET "${SRC_DEV}1")
    fi
    echo "$m"
}

SRC=$(mount_src)

for iso in "$ISO_WIN7" "$ISO_WIN10" "$ISO_WIN11"; do
    [[ -f "$SRC/$iso" ]] || { echo "Нет на большой флешке: $SRC/$iso" >&2; exit 1; }
done

USB_MODEL=$(lsblk -dnpo MODEL "$USB_DEV" | xargs)
echo "Источник (64 ГБ): $SRC"
echo "Цель (32 ГБ):     $USB_DEV ($USB_MODEL)"
echo
read -r -p "Стереть $USB_DEV и поставить Ventoy ${VENTOY_VER} заново? [y/N] " ans
[[ "$ans" =~ ^[yY]$ ]] || exit 0

echo "==> Размонтируем $USB_DEV..."
umount -R "${USB_DEV}"* 2>/dev/null || true
sleep 1

echo "==> Скачиваем Ventoy ${VENTOY_VER}..."
mkdir -p "$WORK"
if [[ ! -x "$WORK/ventoy-${VENTOY_VER}/Ventoy2Disk.sh" ]]; then
    curl -fsSL -o "$WORK/ventoy.tar.gz" \
        "https://github.com/ventoy/Ventoy/releases/download/v${VENTOY_VER}/ventoy-${VENTOY_VER}-linux.tar.gz"
    tar -xzf "$WORK/ventoy.tar.gz" -C "$WORK"
fi

echo "==> Ставим Ventoy на $USB_DEV..."
"$WORK/ventoy-${VENTOY_VER}/Ventoy2Disk.sh" -I "$USB_DEV"

echo "==> Копируем Windows 7, 10 и 11 (~14.6 ГБ)..."
mkdir -p "$MNT"
mount "${USB_DEV}1" "$MNT"
cp -v "$SRC/$ISO_WIN7" "$SRC/$ISO_WIN10" "$SRC/$ISO_WIN11" "$MNT/"
sync
ls -lh "$MNT"/*.iso
umount "$MNT"

echo
echo "Готово. Безопасно извлеките 32 ГБ флешку и пробуйте загрузку."
