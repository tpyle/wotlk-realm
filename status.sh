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

online=$(mysql -uacore -pacore -h127.0.0.1 -N -B -e \
    "SELECT COUNT(*) FROM acore_characters.characters WHERE online = 1;" 2>/dev/null)
bots=$(mysql -uacore -pacore -h127.0.0.1 -N -B -e \
    "SELECT COUNT(*) FROM acore_characters.characters c
     JOIN acore_auth.account a ON a.id = c.account
     WHERE c.online = 1 AND a.username LIKE 'RNDBOT%';" 2>/dev/null)

printf 'characters online: %s (of which bots: %s)\n' "${online:-?}" "${bots:-?}"
