#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_SRC="${REPO_ROOT}/config"
SKIP_PACKAGES=0

usage() {
    cat <<'EOF'
Usage: ./install.sh [OPTIONS]

  --skip-packages   Do not run pacman -S from packages.txt

Links config/* into ~/.config/, installs desktop/mime fragments, and prepares local files.
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --skip-packages) SKIP_PACKAGES=1; shift ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
    esac
done

timestamp() { date +%Y%m%d%H%M%S; }

backup_path() {
    local p="$1"
    [[ -e "$p" || -L "$p" ]] || return 0
    local dest="${p}.bak.$(timestamp)"
    echo "  backup: $p -> $dest"
    mv "$p" "$dest"
}

link_config_dir() {
    local name="$1"
    local src="${CONFIG_SRC}/${name}"
    local dst="${HOME}/.config/${name}"
    [[ -d "$src" ]] || { echo "Missing ${src}" >&2; exit 1; }

    if [[ -L "$dst" && "$(readlink -f "$dst")" == "$(readlink -f "$src")" ]]; then
        echo "  ok (already linked): ${dst}"
        return 0
    fi

    if [[ -e "$dst" || -L "$dst" ]]; then
        backup_path "$dst"
    fi
    ln -sfn "$src" "$dst"
    echo "  linked: ${dst} -> ${src}"
}

install_packages() {
    local list="${REPO_ROOT}/packages.txt"
    [[ -f "$list" ]] || return 0
    mapfile -t pkgs < <(grep -v '^[[:space:]]*#' "$list" | grep -v '^[[:space:]]*$' || true)
    [[ ${#pkgs[@]} -gt 0 ]] || return 0
    echo "Installing packages (${#pkgs[@]})..."
    sudo pacman -S --needed --noconfirm "${pkgs[@]}"
}

install_desktop_entry() {
    local src="${REPO_ROOT}/extra/applications/imv-dir.desktop"
    local dst="${HOME}/.local/share/applications/imv-dir.desktop"
    mkdir -p "$(dirname "$dst")"
    sed "s|\$HOME|${HOME}|g" "$src" > "$dst"
    echo "  installed: ${dst}"
}

merge_mimeapps() {
    local frag="${REPO_ROOT}/extra/mimeapps.d/hyprland-config.mimeapps"
    local dest="${HOME}/.config/mimeapps.list"
    mkdir -p "${HOME}/.config"
    if [[ ! -f "$dest" ]]; then
        cp "$frag" "$dest"
        echo "  created: ${dest}"
        return 0
    fi
    python3 - <<'PY' "$frag" "$dest"
import configparser, sys
from pathlib import Path

frag, dest = sys.argv[1:3]
cfg = configparser.ConfigParser(interpolation=None, strict=False)
cfg.optionxform = str
if Path(dest).exists():
    cfg.read(dest, encoding="utf-8")
if not cfg.has_section("Default Applications"):
    cfg.add_section("Default Applications")
frag_cfg = configparser.ConfigParser(interpolation=None, strict=False)
frag_cfg.optionxform = str
frag_cfg.read(frag, encoding="utf-8")
for key, val in frag_cfg.items("Default Applications"):
    cfg.set("Default Applications", key, val)
with open(dest, "w", encoding="utf-8") as f:
    cfg.write(f, space_around_delimiters=True)
PY
    echo "  merged imv defaults into ${dest}"
}

install_wireplumber_snippets() {
    local src_dir="${CONFIG_SRC}/wireplumber/wireplumber.conf.d"
    local dst_dir="${HOME}/.config/wireplumber/wireplumber.conf.d"
    mkdir -p "$dst_dir"
    for f in "$src_dir"/*.conf; do
        [[ -f "$f" ]] || continue
        local base
        base="$(basename "$f")"
        if [[ -e "${dst_dir}/${base}" && ! -L "${dst_dir}/${base}" ]]; then
            backup_path "${dst_dir}/${base}"
        fi
        ln -sfn "$f" "${dst_dir}/${base}"
        echo "  linked: ${dst_dir}/${base}"
    done
}

ensure_network_local() {
    local example="${CONFIG_SRC}/hypr/network.local.sh.example"
    local target="${HOME}/.config/hypr/network.local.sh"
    if [[ ! -f "$target" ]]; then
        cp "$example" "$target"
        echo "  created ${target} from example"
    fi
}

chmod_hypr_scripts() {
    find "${CONFIG_SRC}/hypr" -maxdepth 1 -name '*.sh' -exec chmod +x {} +
}

mkdir -p "${HOME}/Pictures/wallpapers"

echo "==> Hyprland dotfiles install (${REPO_ROOT})"

if (( SKIP_PACKAGES == 0 )); then
    install_packages
else
    echo "Skipping pacman (--skip-packages)"
fi

echo "==> Linking configs"
for dir in hypr waybar mako swayosd cava rofi cliphist; do
    link_config_dir "$dir"
done
install_wireplumber_snippets

echo "==> Desktop & MIME"
install_desktop_entry
merge_mimeapps

ensure_network_local
chmod_hypr_scripts

cat <<EOF

Done.

Next steps:
  1. Edit ~/.config/hypr/network.local.sh (Wi‑Fi names from: nmcli connection show)
  2. Adjust monitors in ~/.config/hypr/hyprland.conf (HDMI/eDP names)
  3. Optional: ~/.config/hypr/audio-setup.sh — set LAPTOP_CARD / sink for your hardware
  4. Optional: copy wireplumber 51-auto-audio.conf.example → 51-auto-audio.conf and set PCI id
  5. Put wallpapers in ~/Pictures/wallpapers/ (wall1.jpeg … used by hyprpaper/hyprlock)
  6. Log out and back into Hyprland (or: hyprctl reload)

Repo: ${REPO_ROOT}
EOF
