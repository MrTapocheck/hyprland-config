# Hyprland config

Публичный конфиг Hyprland для Manjaro / Arch: рабочие столы, waybar, music lounge, imv, аудио, OSD и утилиты.

**Автор:** [@MrTapocheck](https://github.com/MrTapocheck)

## Быстрая установка

```bash
git clone git@github.com:MrTapocheck/hyprland-config.git ~/.config/hypr
chmod +x ~/.config/hypr/*.sh
cp ~/.config/hypr/network.local.sh.example ~/.config/hypr/network.local.sh
# отредактируйте network.local.sh — имена Wi‑Fi из `nmcli connection show`
```

Перезайдите в Hyprland или выполните `hyprctl reload`.

## Связанные конфиги (не в этом репо)

Часть функций опирается на соседние каталоги в `~/.config/`:

| Каталог | Назначение |
|---------|------------|
| `waybar/` | Панель (двойной Super — показать/скрыть) |
| `mako/` | Уведомления |
| `swayosd/` | OSD громкости и яркости |
| `cava/music-lounge.conf` | Визуализатор music lounge |
| `rofi/clipboard.rasi` | Панель буфера обмена (Super+V) |
| `hypridle.conf` | Блокировка / idle (рядом с hypr) |

## Рабочие столы

| Клавиша | Workspace | Содержимое |
|---------|-----------|------------|
| Super+1…7 | 1–7 | Приложения (Chromium, Yakuake, Telegram, Thunar…) |
| Super+8 | 8 | Music lounge (фон, cava, GIF-виджеты) |
| Super+9 | 9 | imv — просмотр фото |
| Super+0 | 10 | Пустой запасной |

## Полезные скрипты

| Скрипт | Описание |
|--------|----------|
| `music-lounge.sh` | Демон music lounge на ws 8 |
| `imv-open.sh` | Открыть папку с фото в imv |
| `audio-setup.sh` | Автовыбор аудиоустройства (PipeWire) |
| `network-start.sh` | NetworkManager + Wi‑Fi после входа |
| `clipboard-panel.sh` | История буфера (Super+V) |
| `volume-osd.sh` / `brightness-osd.sh` | OSD через SwayOSD |

## Локальные настройки

Файл `network.local.sh` **не коммитится** — там Wi‑Fi и другие личные параметры. Шаблон: `network.local.sh.example`.

Одноразовая настройка сети (опционально):

```bash
sudo ~/.config/hypr/boot-fix-network.sh
```

## Зависимости (Arch)

```bash
sudo pacman -S --needed hyprland hypridle hyprlock waybar mako rofi-wayland \
  wireplumber pipewire-pulse grim slurp wl-clipboard cliphist jq \
  brightnessctl network-manager-applet obs-studio python python-pip
```

Дополнительно: `swayosd`, `cava`, `imv`, `mpvpaper`, `awww-daemon` — по желанию, см. скрипты в репо.

## Лицензия

MIT — используйте свободно, на свой страх и риск.
