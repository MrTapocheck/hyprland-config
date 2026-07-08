#!/usr/bin/env bash

playerctl pause 2>/dev/null || true
loginctl lock-session 2>/dev/null || true
sleep 0.5
systemctl suspend
