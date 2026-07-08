#!/usr/bin/env bash

THUMB_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/cliphist/thumbs"

format_entry() {
    local id=$1
    local data=$2
    local icon=""
    local label="$data"

    case "$data" in
        *'[[ binary data '*png' '[0-9]*x[0-9]*' ]]'|\
        *'[[ binary data '*jpeg' '[0-9]*x[0-9]*' ]]'|\
        *'[[ binary data '*jpg' '[0-9]*x[0-9]*' ]]'|\
        *'[[ binary data '*webp' '[0-9]*x[0-9]*' ]]'|\
        *'[[ binary data '*bmp' '[0-9]*x[0-9]*' ]]')
            icon="$THUMB_DIR/${id}.png"
            mkdir -p "$THUMB_DIR"
            if [[ ! -f "$icon" ]]; then
                cliphist decode "$id" > "$icon" 2>/dev/null || icon=""
            fi
            if [[ "$data" =~ ([0-9]+x[0-9]+) ]]; then
                label="[изображение ${BASH_REMATCH[1]}]"
            else
                label="[изображение]"
            fi
            ;;
        *'[[ binary data '*)
            icon="$THUMB_DIR/${id}.png"
            mkdir -p "$THUMB_DIR"
            if [[ ! -f "$icon" ]]; then
                cliphist decode "$id" > "$icon" 2>/dev/null || icon=""
            fi
            label="[изображение]"
            ;;
    esac

    label=${label//$'\n'/ }
    label=${label//$'\r'/ }
    if ((${#label} > 100)); then
        label="${label:0:97}..."
    fi
    [[ -z "$label" ]] && label="[пусто]"

    printf '%s\0icon\x1f%s\x1finfo\x1f%s\n' "$label" "$icon" "$id"
}

get_clips() {
    if ! command -v cliphist >/dev/null 2>&1; then
        printf '%s\0info\x1f0\n' "cliphist не найден"
        return
    fi

    if ! cliphist list 2>/dev/null | grep -q .; then
        printf '%s\0info\x1f0\n' "(буфер пуст — скопируй что-нибудь)"
        return
    fi

    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        format_entry "${line%%$'\t'*}" "${line#*$'\t'}"
    done < <(cliphist list 2>/dev/null)
}

case ${ROFI_RETV:-0} in
    0)
        get_clips
        ;;
    1)
        [[ -n "${ROFI_INFO}" && "${ROFI_INFO}" != "0" ]] || exit 0
        cliphist decode "${ROFI_INFO}" | wl-copy
        (
            sleep 0.1
            hyprctl dispatch sendshortcut CTRL,V,activewindow >/dev/null 2>&1
        ) &
        exit 0
        ;;
esac
