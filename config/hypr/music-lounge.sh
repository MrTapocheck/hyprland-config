#!/usr/bin/env bash
set -euo pipefail

STATE_DIR="${XDG_RUNTIME_DIR}/hypr"
PID_FILE="${STATE_DIR}/music-lounge.pids"
ACTIVE_FILE="${STATE_DIR}/music-lounge.active"
MPV_SOCKET="${STATE_DIR}/music-lounge.mpvpaper.sock"
ENV_FILE="${HOME}/.config/hypr/music-lounge.env"
CAVA_CONF="${HOME}/.config/cava/music-lounge.conf"
MPVPAPER_BIN="${MPVPAPER_BIN:-/usr/local/bin/mpvpaper}"

# shellcheck source=/dev/null
[[ -f "$ENV_FILE" ]] && source "$ENV_FILE"

mpvpaper_available() {
    [[ "${MUSIC_LOUNGE_USE_MPVPAPER:-1}" == "1" ]] && [[ -x "$MPVPAPER_BIN" || -n "$(command -v mpvpaper 2>/dev/null)" ]]
}

monitor_geometry() {
    local monitor="${1:-}"
    hyprctl monitors -j | jq -r --arg mon "$monitor" '
        .[] | select(.name == $mon) |
        "\(.width)|\(.height)|\(.x)|\(.y)"
    '
}

ws8_monitor() {
    hyprctl monitors -j | jq -r '.[] | select(.activeWorkspace.id == 8) | .name' | head -1
}

save_pid() {
    echo "$1" >> "$PID_FILE"
}

client_address() {
    local class="${1:-}"
    local title="${2:-}"
    hyprctl clients -j | jq -r --arg c "$class" --arg t "$title" '
        .[] | select(.class == $c and ($t == "" or .title == $t)) | .address' | head -1
}

close_class_on_ws8() {
    local class="$1"
    local addr
    while read -r addr; do
        [[ -n "$addr" && "$addr" != "null" ]] || continue
        hyprctl dispatch closewindow "address:${addr}" >/dev/null 2>&1 || true
    done < <(hyprctl clients -j | jq -r --arg c "$class" '
        .[] | select(.class == $c and .workspace.id == 8) | .address')
}

position_window() {
    local class="$1"
    local title="$2"
    local px="$3"
    local py="$4"
    local pw="$5"
    local ph="$6"
    local opacity="${7:-}"
    local addr

    for _ in {1..25}; do
        addr=$(client_address "$class" "$title")
        [[ -n "$addr" && "$addr" != "null" ]] && break
        sleep 0.08
    done
    [[ -n "$addr" && "$addr" != "null" ]] || return 0

    hyprctl dispatch resizewindowpixel "exact ${pw} ${ph},address:${addr}" >/dev/null 2>&1 || true
    hyprctl dispatch movewindowpixel "exact ${px} ${py},address:${addr}" >/dev/null 2>&1 || true
    if [[ -n "$opacity" ]]; then
        hyprctl dispatch opacity "${opacity} override,address:${addr}" >/dev/null 2>&1 || true
    fi
    hyprctl dispatch movetoworkspacesilent "8,address:${addr}" >/dev/null 2>&1 || true
}

raise_window() {
    local class="$1"
    local addr
    addr=$(client_address "$class" "")
    [[ -n "$addr" && "$addr" != "null" ]] || return 0
    hyprctl dispatch alterzorder top "address:${addr}" >/dev/null 2>&1 || true
}

lower_window() {
    local class="$1"
    local addr
    addr=$(client_address "$class" "")
    [[ -n "$addr" && "$addr" != "null" ]] || return 0
    hyprctl dispatch alterzorder bottom "address:${addr}" >/dev/null 2>&1 || true
}

clear_monitor_wallpaper() {
    local monitor="$1"
    if command -v awww >/dev/null 2>&1 && awww query >/dev/null 2>&1; then
        awww clear --outputs "$monitor" 11111bff >/dev/null 2>&1 || true
    fi
}

start_background() {
    local monitor="$1"
    local width height x y
    local paper_bin=""

    IFS='|' read -r width height x y <<< "$MONITOR_GEOM"

    if mpvpaper_available; then
        if [[ -x "$MPVPAPER_BIN" ]]; then
            paper_bin="$MPVPAPER_BIN"
        else
            paper_bin=$(command -v mpvpaper 2>/dev/null || true)
        fi
        [[ -n "$paper_bin" ]] || return 0

        clear_monitor_wallpaper "$monitor"
        "$paper_bin" -f -l background \
            -o "no-audio loop input-ipc-server=${MPV_SOCKET}" \
            "$monitor" "$MUSIC_LOUNGE_VIDEO" >/dev/null 2>&1 &
        save_pid "$!"
        return
    fi

    # Без mpvpaper: обычное окно по размеру монитора, НЕ fullscreen (fullscreen перекрывает waybar)
    mpv --force-window=immediate --no-audio --loop-file=inf \
        --geometry="${width}x${height}+${x}+${y}" \
        --no-osc --no-border --keepaspect=no --ontop=no \
        --wayland-app-id=mpv-music-bg \
        "$MUSIC_LOUNGE_VIDEO" >/dev/null 2>&1 &
    save_pid "$!"
}

start_visualizer() {
    local width height x y viz_h viz_w viz_x viz_y

    IFS='|' read -r width height x y <<< "$MONITOR_GEOM"
    viz_h="${MUSIC_LOUNGE_VIZ_HEIGHT:-140}"
    viz_w=$((width - 96))
    viz_x=$((x + 48))
    viz_y=$((y + height - viz_h - 28))

    if [[ -f "$CAVA_CONF" ]] && command -v cava >/dev/null 2>&1; then
        local runtime_conf="${STATE_DIR}/cava-music-lounge.conf"
        awk -v w="$viz_w" -v h="$viz_h" '
            /^sdl_width = / { print "sdl_width = " w; next }
            /^sdl_height = / { print "sdl_height = " h; next }
            { print }
        ' "$CAVA_CONF" > "$runtime_conf"
        cava -p "$runtime_conf" >/dev/null 2>&1 &
        save_pid "$!"
        position_window "cava" "cava" "$viz_x" "$viz_y" "$viz_w" "$viz_h" "0.96"
        raise_window "cava"
        return
    fi

    command -v notify-send >/dev/null 2>&1 && \
        notify-send "Music lounge" "Установи cava: sudo pacman -S cava" -u low
}

START_LOCK="${STATE_DIR}/music-lounge.start.lock"

start_lounge() {
    local monitor geom width height x y widget_size

    exec 8>"$START_LOCK"
    flock -n 8 || return 0

    monitor=$(ws8_monitor)
    [[ -n "$monitor" ]] || return 0

    if [[ -f "$ACTIVE_FILE" ]] && [[ "$(cat "$ACTIVE_FILE" 2>/dev/null)" == "$monitor" ]]; then
        local lounge_ok=true
        if mpvpaper_available; then
            pgrep -x mpvpaper >/dev/null 2>&1 || lounge_ok=false
        else
            [[ -n "$(client_address "mpv-music-bg" "")" ]] || lounge_ok=false
        fi
        pgrep -x cava >/dev/null 2>&1 || lounge_ok=false
        $lounge_ok && return 0
    fi

    stop_lounge

    [[ -f "$MUSIC_LOUNGE_VIDEO" ]] || {
        command -v notify-send >/dev/null 2>&1 && \
            notify-send "Music lounge" "Нет видео: $MUSIC_LOUNGE_VIDEO" -u normal
        return 1
    }

    geom=$(monitor_geometry "$monitor")
    [[ -n "$geom" ]] || return 0
    MONITOR_GEOM="$geom"
    IFS='|' read -r width height x y <<< "$geom"

    : > "$PID_FILE"
    echo "$monitor" > "$ACTIVE_FILE"

    widget_size="${MUSIC_LOUNGE_WIDGET_SIZE:-260}"
    if [[ -f "$MUSIC_LOUNGE_WIDGET_LEFT" ]]; then
        mpv --force-window=immediate --no-audio --loop-file=inf \
            --no-osc --no-border --ontop \
            --wayland-app-id=mpv-music-widget-l \
            "$MUSIC_LOUNGE_WIDGET_LEFT" >/dev/null 2>&1 &
        save_pid "$!"
    fi

    if [[ -f "$MUSIC_LOUNGE_WIDGET_RIGHT" ]]; then
        mpv --force-window=immediate --no-audio --loop-file=inf \
            --no-osc --no-border --ontop \
            --wayland-app-id=mpv-music-widget-r \
            "$MUSIC_LOUNGE_WIDGET_RIGHT" >/dev/null 2>&1 &
        save_pid "$!"
    fi

    start_visualizer
    start_background "$monitor"

    sleep 0.7
    position_window "mpv-music-widget-l" "" "$((x + 48))" "$((y + 96))" "$widget_size" "$widget_size" "0.88"
    position_window "mpv-music-widget-r" "" "$((x + width - widget_size - 48))" "$((y + height - widget_size - 180))" "$widget_size" "$widget_size" "0.88"
    raise_window "mpv-music-widget-l"
    raise_window "mpv-music-widget-r"
    raise_window "cava"

    if ! mpvpaper_available; then
        position_window "mpv-music-bg" "" "$x" "$y" "$width" "$height" "1.0"
        lower_window "mpv-music-bg"
    fi
}

stop_lounge() {
    if [[ -f "$PID_FILE" ]]; then
        while read -r pid; do
            [[ -n "$pid" ]] || continue
            kill "$pid" 2>/dev/null || true
        done < "$PID_FILE"
    fi

    pkill -x mpvpaper 2>/dev/null || true
    pkill -f "/usr/local/bin/mpvpaper" 2>/dev/null || true
    pkill -x cava 2>/dev/null || true
    close_class_on_ws8 "mpv-music-bg"
    close_class_on_ws8 "mpv-music-widget-l"
    close_class_on_ws8 "mpv-music-widget-r"
    close_class_on_ws8 "cava"

    rm -f "$PID_FILE" "$ACTIVE_FILE" "$MPV_SOCKET"
    "$HOME/.config/hypr/workspace-wallpapers.sh" &
}

sync_lounge() {
    if [[ -n "$(ws8_monitor)" ]]; then
        start_lounge
    else
        [[ -f "$ACTIVE_FILE" ]] && stop_lounge || true
    fi
}

case "${1:-daemon}" in
    start)  sync_lounge ;;
    stop)   stop_lounge ;;
    ensure-daemon)
        mkdir -p "$STATE_DIR"
        if pgrep -f "[m]usic-lounge.sh daemon" >/dev/null 2>&1; then
            exit 0
        fi
        nohup "$0" daemon >>"${STATE_DIR}/music-lounge.log" 2>&1 &
        ;;
    toggle)
        if [[ -n "$(ws8_monitor)" ]] && [[ -f "$ACTIVE_FILE" ]]; then
            stop_lounge
        else
            hyprctl dispatch workspace 8
            sleep 0.2
            start_lounge
        fi
        ;;
    daemon)
        mkdir -p "$STATE_DIR"
        DAEMON_LOCK="${STATE_DIR}/music-lounge.daemon.lock"
        exec 9>"$DAEMON_LOCK"
        flock -n 9 || exit 0
        sync_lounge
        while read -r line; do
            case "$line" in
                workspace*|moveworkspace*)
                    sleep 0.2
                    sync_lounge
                    ;;
            esac
        done < <(socat -U - "UNIX-CONNECT:${XDG_RUNTIME_DIR}/hypr/${HYPRLAND_INSTANCE_SIGNATURE}/.socket2.sock")
        ;;
    *)
        echo "Usage: $0 {daemon|ensure-daemon|start|stop|toggle}" >&2
        exit 1
        ;;
esac
