#!/usr/bin/env bash
#
# Start MySQL, the auth server and the world server, through their systemd units
# (see README, "Running under systemd"). Each pulls in what it depends on, and
# the world server is ordered after the auth server has finished its database
# work.
#
set -euo pipefail

if ! systemctl cat acore-world.service >/dev/null 2>&1; then
    echo "the units are not installed, run tools/install_systemd.sh" >&2
    exit 1
fi

# Asking for a start by hand overrides a crash loop systemd has given up on.
sudo systemctl reset-failed acore-auth.service acore-world.service 2>/dev/null || true

sudo systemctl start acore-auth.service
echo "auth server is up"

# Not waited for: the unit reads "activating" until the world accepts players.
sudo systemctl start --no-block acore-world.service
echo "world server starting"

echo
echo "The world server needs a few minutes to load and to log in 500 bots."
echo "Watch it with:  ./console.sh   (or ./status.sh)"
