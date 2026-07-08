#!/usr/bin/env bash
# Однократная установка mpvpaper (настоящие видео-обои под окнами).
set -euo pipefail

if command -v mpvpaper >/dev/null 2>&1; then
    echo "mpvpaper уже установлен: $(command -v mpvpaper)"
    exit 0
fi

echo "Нужны права sudo для wlroots0.19 и сборки mpvpaper."
sudo pacman -S --needed --noconfirm wlroots0.19 meson ninja git base-devel

build_dir="${XDG_CACHE_HOME:-$HOME/.cache}/mpvpaper-build"
rm -rf "$build_dir"
git clone --depth 1 https://github.com/GhostNaN/mpvpaper "$build_dir"
meson setup "$build_dir/build" "$build_dir" --prefix=/usr/local
ninja -C "$build_dir/build"
sudo ninja -C "$build_dir/build" install

echo "Готово. Перезайди на Super+8 или: ~/.config/hypr/music-lounge.sh stop && Super+8"
