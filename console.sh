#!/usr/bin/env bash
#
# The world server's console: commands go in through the FIFO that is its stdin,
# and what it prints comes back out of the journal.
#
#   ./console.sh                 interactive; leave with Ctrl-D
#   ./console.sh 'server info'   run one command and print what follows it
#
set -uo pipefail

FIFO=/run/acore-world/console

[ -p "$FIFO" ] || { echo "the world server is not running" >&2; exit 1; }

send() { printf '%s\n' "$1" 1<>"$FIFO"; }

if [ $# -gt 0 ]; then
    sudo timeout 3 journalctl -fu acore-world.service -n 0 -o cat &
    sleep 0.5
    send "$*"
    wait
    exit 0
fi

sudo journalctl -fu acore-world.service -n 20 -o cat &
follower=$!
trap 'sudo kill "$follower" 2>/dev/null' EXIT

while IFS= read -e -r line; do
    [ -n "$line" ] && send "$line" && history -s "$line"
done
