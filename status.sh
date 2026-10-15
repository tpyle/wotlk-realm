#!/usr/bin/env bash
#
# Show what is running and how many bots are online.
#
set -uo pipefail

printf 'mysql        : %s\n' "$(mysqladmin --silent status >/dev/null 2>&1 && echo up || echo down)"

for session in acore-auth acore-world; do
    if tmux has-session -t "$session" 2>/dev/null; then
        printf '%-13s: up\n' "${session#acore-}server"
    else
        printf '%-13s: down\n' "${session#acore-}server"
    fi
done

# The bot account prefix is config, not a constant - read it rather than
# write it in here, so renaming it there cannot turn 500 bots into people.
PREFIX=$(sed -n 's/^AiPlayerbot.RandomBotAccountPrefix[[:space:]]*=[[:space:]]*"\?\([^"]*\)"\?.*/\1/p' \
    /root/classic/run/etc/modules/playerbots.conf 2>/dev/null | tail -1)
PREFIX="${PREFIX:-rndbot}"

# mod-lorecompanions' characters are bots too, on an account of their own. Its
# online flag stays set after a companion logs out (headless sessions never
# clear it), so it would otherwise read as a person at character select.
COMPANIONS=$(sed -n 's/^LoreCompanions.AccountName[[:space:]]*=[[:space:]]*"\?\([^"]*\)"\?.*/\1/p' \
    /root/classic/run/etc/modules/mod_lorecompanions.conf 2>/dev/null | tail -1)
COMPANIONS="${COMPANIONS:-LORECOMPANIONS}"

online=$(mysql -uacore -pacore -h127.0.0.1 -N -B -e \
    "SELECT COUNT(*) FROM acore_characters.characters WHERE online = 1;" 2>/dev/null)
bots=$(mysql -uacore -pacore -h127.0.0.1 -N -B -e \
    "SELECT COUNT(*) FROM acore_characters.characters c
     JOIN acore_auth.account a ON a.id = c.account
     WHERE c.online = 1 AND (a.username LIKE '${PREFIX}%' OR a.username = '${COMPANIONS}');" 2>/dev/null)
companions=$(mysql -uacore -pacore -h127.0.0.1 -N -B -e \
    "SELECT GROUP_CONCAT(c.name SEPARATOR ', ') FROM acore_characters.characters c
     JOIN acore_auth.account a ON a.id = c.account
     WHERE c.online = 1 AND a.username = '${COMPANIONS}';" 2>/dev/null)

printf 'characters online: %s (of which bots: %s)\n' "${online:-?}" "${bots:-?}"
[ -n "$companions" ] && [ "$companions" != "NULL" ] && printf 'companions out: %s\n' "$companions"

# People, listed rather than counted, because the useful question before a
# restart is not "how many" but "who, and are they really there".
#
# account.online is a FLAG the server sets on login and clears on logout, not
# a live socket. A client that hangs or is killed can leave it set with nobody
# behind it, and a person sitting at character select has it set with no
# character to show - so both appear here, and the character column is what
# tells them apart. "account onlinelist" on the world console is the
# authoritative list when it matters.
mysql -uacore -pacore -h127.0.0.1 -N -B -e \
    "SELECT CONCAT('  ', a.username, '  ', a.last_ip, '  ',
            IFNULL(GROUP_CONCAT(c.name SEPARATOR ', '), '(no character - at login, or a stale session)'))
     FROM acore_auth.account a
     LEFT JOIN acore_characters.characters c ON c.account = a.id AND c.online = 1
     WHERE a.online = 1 AND a.username NOT LIKE '${PREFIX}%' AND a.username <> '${COMPANIONS}'
     GROUP BY a.username, a.last_ip;" 2>/dev/null | {
    found=""
    while IFS= read -r line; do
        [ -z "$found" ] && printf 'people online:\n' && found=1
        printf '%s\n' "$line"
    done
    [ -z "$found" ] && printf 'people online: none\n'
}
