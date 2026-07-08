#!/usr/bin/env bash

while read -r kb; do
    hyprctl switchxkblayout "$kb" 0 >/dev/null
done < <(hyprctl devices -j | jq -r '.keyboards[] | .name')

exec hyprlock "$@"
