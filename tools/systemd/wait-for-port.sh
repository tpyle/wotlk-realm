#!/usr/bin/env bash
#
# ExecStartPost for both servers: return once the server is listening on the
# port its config names, so that the unit only reads "active" when it is really
# up. Fails as soon as the server dies rather than waiting out TimeoutStartSec.
#
#   wait-for-port.sh <config file in run/etc> <config key>
#
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

port=$(sed -n "s/^$2[[:space:]]*=[[:space:]]*\([0-9]*\).*/\1/p" "$ROOT/run/etc/$1" | tail -1)
[ -n "$port" ] || { echo "no $2 in run/etc/$1" >&2; exit 1; }

while ! ss -ltnH "sport = :$port" | grep -q .; do
    kill -0 "$MAINPID" 2>/dev/null || { echo "exited before listening on $port" >&2; exit 1; }
    sleep 1
done
