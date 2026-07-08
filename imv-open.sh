#!/usr/bin/env bash
set -euo pipefail

[[ $# -ge 1 ]] || { echo "Usage: $0 <image> [image...]" >&2; exit 1; }

pkill -x imv-wayland 2>/dev/null || true
pkill -x imv-x11 2>/dev/null || true
sleep 0.05

if [[ $# -ge 2 ]]; then
    exec imv -f "$@"
fi

file=$(realpath -e "$1")
dir=$(dirname "$file")
exec imv -f -n "$file" "$dir"
