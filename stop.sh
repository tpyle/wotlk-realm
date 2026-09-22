#!/usr/bin/env bash
#
# Stop the world server (gracefully, so characters and bots are saved) and the
# auth server.
#
# Real players are warned and then kicked *before* the shutdown starts. This
# matters because World's shutdown calls WorldSessionMgr::KickAll(), which logs
# out and saves all 500 bots - and until that finishes the server answers
# nobody. A client left connected through it can still walk around on its own
# prediction but gets no reply to anything, including its own logout request,
# which looks exactly like a hang. Kicking first returns it to the login screen
# straight away.
#
#   ./stop.sh            warn for $BOTLORE_GRACE seconds, then stop
#   ./stop.sh --now      skip the warning (nothing but bots online)
#
set -uo pipefail

GRACE="${STOP_GRACE:-15}"
[ "${1:-}" = "--now" ] && GRACE=0

world() { tmux send-keys -t acore-world "$1" Enter 2>/dev/null; }

if tmux has-session -t acore-world 2>/dev/null; then
    # Who is actually a person? Bot accounts all carry the random bot prefix.
    mapfile -t players < <(mysql -uacore -pacore -h127.0.0.1 -N -B -e "
        SELECT c.name FROM acore_characters.characters c
        JOIN acore_auth.account a ON a.id = c.account
        WHERE c.online = 1 AND a.username NOT LIKE 'RNDBOT%';" 2>/dev/null)

    if [ "${#players[@]}" -gt 0 ] && [ -n "${players[0]}" ]; then
        echo "online players: ${players[*]}"

        if [ "$GRACE" -gt 0 ]; then
            world "announce Server is shutting down in ${GRACE} seconds."
            echo -n "warning players"
            for _ in $(seq 1 "$GRACE"); do
                echo -n "."
                sleep 1
            done
            echo
        fi

        # Out before the bot saves begin, so the client is not left waiting on a
        # server that has stopped answering.
        for name in "${players[@]}"; do
            [ -n "$name" ] && world "kick $name Server is shutting down"
        done
        sleep 2
    fi

    echo "asking the world server to shut down..."
    world "server shutdown 1"

    # 500 bots have to be logged out and saved, which is not quick.
    for _ in $(seq 1 180); do
        tmux has-session -t acore-world 2>/dev/null || break
        sleep 1
    done

    if tmux has-session -t acore-world 2>/dev/null; then
        echo "world server did not exit in 180s, killing the session (bot state may be stale)"
        tmux kill-session -t acore-world
    fi
    echo "world server stopped"
else
    echo "world server is not running"
fi

if tmux has-session -t acore-auth 2>/dev/null; then
    tmux kill-session -t acore-auth
    echo "auth server stopped"
else
    echo "auth server is not running"
fi
