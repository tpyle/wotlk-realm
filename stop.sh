#!/usr/bin/env bash
#
# Stop the world server (gracefully, so characters and bots are saved) and the
# auth server. The graceful part lives in tools/systemd/world-stop.sh, so that
# systemctl and a machine reboot get it as well.
#
#   ./stop.sh            warn players for $STOP_GRACE seconds (15), then stop
#   ./stop.sh --now      skip the warning (nothing but bots online)
#
set -uo pipefail

GRACE="${STOP_GRACE:-15}"
[ "${1:-}" = "--now" ] && GRACE=0

if systemctl is-active --quiet acore-world.service; then
    echo "$GRACE" > /run/acore-world/stop-grace
fi

# Blocks until 500 bots are logged out and saved, which is not quick.
echo "stopping the world server..."
sudo systemctl stop acore-world.service
echo "stopping the auth server..."
sudo systemctl stop acore-auth.service
echo "stopped"
