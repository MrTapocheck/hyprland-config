#!/usr/bin/env bash
set -euo pipefail

notify() {
    command -v notify-send >/dev/null 2>&1 && notify-send "$@"
}

copy_file() {
    local file="$1"
    local real name
    real=$(realpath "$file")
    name=$(basename "$real")
    printf 'copy\nfile://%s\n' "$real" | wl-copy -t x-special/gnome-copied-files
    notify "Скопировано" "$name" -u low -i edit-copy
}

copy_path() {
    local file="$1"
    local real name
    real=$(realpath "$file")
    name=$(basename "$real")
    wl-copy -t text/plain "$real"
    notify "Путь скопирован" "$name" -u low
}

open_folder() {
    local file="$1"
    local dir
    dir=$(dirname "$(realpath "$file")")
    thunar "$dir" >/dev/null 2>&1 &
}

show_menu() {
    local file="$1"
    local choice name
    name=$(basename "$file")

    choice=$(printf '%s\n' \
        "Копировать" \
        "Копировать путь" \
        "Открыть папку в Thunar" \
        | rofi -dmenu -i -p "$name" -theme "$HOME/.config/rofi/config.rasi" 2>/dev/null \
        || printf '%s\n' \
            "Копировать" \
            "Копировать путь" \
            "Открыть папку в Thunar" \
            | rofi -dmenu -i -p "$name")

    [[ -n "$choice" ]] || return 0

    case "$choice" in
        "Копировать") copy_file "$file" ;;
        "Копировать путь") copy_path "$file" ;;
        "Открыть папку в Thunar") open_folder "$file" ;;
    esac
}

action="${1:-}"
file="${imv_current_file:-${2:-}}"

[[ -n "$file" && -f "$file" ]] || exit 0

case "$action" in
    copy) copy_file "$file" ;;
    path) copy_path "$file" ;;
    folder) open_folder "$file" ;;
    menu) show_menu "$file" ;;
    *)
        echo "Usage: $0 {copy|path|folder|menu} [file]" >&2
        exit 1
        ;;
esac
