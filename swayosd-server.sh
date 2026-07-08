#!/usr/bin/env bash
# Тихий запуск OSD: логи не сыпятся в терминал при ручном старте.
exec swayosd-server >/dev/null 2>&1
