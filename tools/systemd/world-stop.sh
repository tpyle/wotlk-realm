#!/usr/bin/env bash
#
# ExecStop for the world server, so that every way of stopping it (stop.sh,
# systemctl, rebooting the machine) goes through the same graceful shutdown.
#
# Real players are warned and then kicked *before* the shutdown starts. This
# matters because World's shutdown calls WorldSessionMgr::KickAll(), which logs
# out and saves all 500 bots - and until that finishes the server answers
# nobody. A client left connected through it can still walk around on its own
# prediction but gets no reply to anything, including its own logout request,
# which looks exactly like a hang. Kicking first returns it to the login screen
# straight away.
#
# The warning lasts as many seconds as /run/acore-world/stop-grace says (stop.sh
# writes it), or 15. There is no other way to pass systemctl stop an argument.
#
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RUNDIR=/run/acore-world

# systemd also runs this after the server has exited by itself ("server shutdown"
# on the console), and then with no MAINPID. Failing here would make that clean
# exit count as a failure, and Restart=on-failure would bring the server back.
[ -n "${MAINPID:-}" ] && kill -0 "$MAINPID" 2>/dev/null || exit 0

GRACE=$(cat "$RUNDIR/stop-grace" 2>/dev/null)
GRACE="${GRACE:-15}"

# Read-write, so this cannot block even if the server has just died.
world() { printf '%s\n' "$1" 1<>"$RUNDIR/console"; }

conf() {
    sed -n "s/^$2[[:space:]]*=[[:space:]]*\"\?\([^\"]*\)\"\?.*/\1/p" "$ROOT/run/etc/modules/$1" 2>/dev/null | tail -1
}

# Who is actually a person? Bot accounts are read from config rather than
# written in here, so renaming them there cannot quietly turn every bot into
# somebody worth waiting for. mod-lorecompanions' account counts as bots too:
# its online flag stays set after a companion logs out.
PREFIX=$(conf playerbots.conf AiPlayerbot.RandomBotAccountPrefix)
PREFIX="${PREFIX:-rndbot}"
COMPANIONS=$(conf mod_lorecompanions.conf LoreCompanions.AccountName)
COMPANIONS="${COMPANIONS:-LORECOMPANIONS}"
NOT_BOT="a.username NOT LIKE '${PREFIX}%' AND a.username <> '${COMPANIONS}'"

# Sessions, not characters. A person sitting at character select or on the
# realm list has an account online and no character online at all, and
# counting characters would shut the server down under them.
humans=$(mysql -uacore -pacore -h127.0.0.1 -N -B -e "
    SELECT COUNT(*) FROM acore_auth.account a WHERE a.online = 1 AND ${NOT_BOT};" 2>/dev/null)

# The ones who can actually be kicked by name, which is a subset: whoever is on
# a character right now.
mapfile -t players < <(mysql -uacore -pacore -h127.0.0.1 -N -B -e "
    SELECT c.name FROM acore_characters.characters c
    JOIN acore_auth.account a ON a.id = c.account
    WHERE c.online = 1 AND ${NOT_BOT};" 2>/dev/null)

if [ "${humans:-0}" -gt 0 ]; then
    echo "online players: ${players[*]:-(nobody on a character; at login or character select)}"

    if [ "$GRACE" -gt 0 ]; then
        world "announce Server is shutting down in ${GRACE} seconds."
        sleep "$GRACE"
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

# 500 bots have to be logged out and saved, which is not quick. Past this,
# systemd falls back to SIGTERM and then SIGKILL (bot state may be stale).
for _ in $(seq 1 180); do
    kill -0 "$MAINPID" 2>/dev/null || exit 0
    sleep 1
done
echo "world server did not exit in 180s" >&2
