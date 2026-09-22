#!/usr/bin/env bash
#
# Start MySQL, the auth server and the world server.
#
# Each server runs inside its own tmux session so its console stays usable:
#
#   tmux attach -t acore-world     (detach again with Ctrl-B then D)
#
set -euo pipefail

BIN="/root/classic/run/bin"
LOGS="/root/classic/logs"

mkdir -p "$LOGS"

if ! mysqladmin --silent status >/dev/null 2>&1; then
    echo "starting MySQL..."
    service mysql start >/dev/null
    for _ in $(seq 1 60); do
        mysqladmin --silent status >/dev/null 2>&1 && break
        sleep 1
    done
fi

if ! mysqladmin --silent status >/dev/null 2>&1; then
    echo "MySQL did not come up - aborting" >&2
    exit 1
fi
echo "MySQL is up"

start_session() {
    local session="$1" command="$2"

    if tmux has-session -t "$session" 2>/dev/null; then
        echo "$session is already running"
        return
    fi

    tmux new-session -d -s "$session" -c "$BIN" "$command"
    echo "$session started (tmux attach -t $session)"
}

# The auth server is started first and waited for on purpose: both servers run
# the database updater, and on a freshly created (empty) database starting them
# at the same time makes them deadlock against each other.
start_session acore-auth "$BIN/authserver"

if ! tmux has-session -t acore-world 2>/dev/null; then
    echo -n "waiting for the auth server to finish its database work"
    for _ in $(seq 1 180); do
        if ss -ltn 2>/dev/null | grep -q ':3724 '; then
            echo " - ready"
            break
        fi
        if ! tmux has-session -t acore-auth 2>/dev/null; then
            echo
            echo "the auth server exited, see $LOGS/Auth.log" >&2
            exit 1
        fi
        echo -n "."
        sleep 1
    done
fi

start_session acore-world "$BIN/worldserver"

echo
echo "The world server needs a few minutes to load and to log in 500 bots."
echo "Watch it with:  tmux attach -t acore-world"
