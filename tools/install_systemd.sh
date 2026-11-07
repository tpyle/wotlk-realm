#!/usr/bin/env bash
#
# Install the acore-auth and acore-world units and enable them at boot. Safe to
# re-run after changing tools/systemd/*.service.in. Starts nothing, and a running
# server keeps its old unit settings until it is next restarted.
#
# The units are rendered with this checkout's location and owner, so they stay
# right wherever the tree lives.
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
USER_NAME="$(stat -c %U "$ROOT/run/bin/worldserver")"
GROUP_NAME="$(stat -c %G "$ROOT/run/bin/worldserver")"

for unit in acore-auth acore-world; do
    sed -e "s|@ROOT@|$ROOT|g" -e "s|@USER@|$USER_NAME|g" -e "s|@GROUP@|$GROUP_NAME|g" \
        "$ROOT/tools/systemd/$unit.service.in" |
        sudo tee "/etc/systemd/system/$unit.service" >/dev/null
    echo "installed $unit.service"
done

sudo systemctl daemon-reload
sudo systemctl enable acore-auth.service acore-world.service
systemd-analyze verify /etc/systemd/system/acore-auth.service /etc/systemd/system/acore-world.service
