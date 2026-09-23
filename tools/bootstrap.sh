#!/usr/bin/env bash
#
# Clone the realm's source tree.
#
# The tree is eighteen git repositories, not one: this project, the core, and
# seventeen modules. They are deliberately not submodules - AzerothCore's own
# .gitignore keeps modules/ free for the user, so making them submodules would
# mean carrying a modified .gitignore and a .gitmodules in the core fork, which
# is the one repository where drift against upstream costs the most.
#
# This script does what submodules would have done for cloning, and nothing
# else:
#
#   tools/bootstrap.sh            clone whatever is missing, at each repo's branch
#   tools/bootstrap.sh --pinned   ... then check out the commits in bootstrap.lock
#   tools/bootstrap.sh --lock     write bootstrap.lock from the working tree
#   tools/bootstrap.sh --status   report branch, head and dirtiness for every repo
#
# Repositories that already exist are left alone: nothing here ever fetches,
# resets, or touches a working tree that is already on disk.
#
# Three of the repositories are forks. Their "origin" is the fork, so a plain
# push goes to the fork; the project they were forked from is "upstream", which
# is where "git fetch upstream && git merge upstream/<branch>" pulls from.
#
# After this, the build still has to be configured and run, the DBCs installed
# and the SQL applied - see the README ("Rebuilding and re-applying", "Worgen
# and Goblin", "Databases").

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOCK="$ROOT/bootstrap.lock"
GH="ssh://git@github.com/tpyle"

# path | origin | branch | upstream (optional)
REPOS=(
  "server|$GH/azerothcore-wotlk|trunk|https://github.com/liyunfan1223/azerothcore-wotlk.git"

  # Forked modules: our changes on trunk, upstream kept as a remote.
  "server/modules/mod-ah-bot|$GH/mod-ah-bot|trunk|https://github.com/azerothcore/mod-ah-bot"
  "server/modules/mod-playerbots|$GH/mod-playerbots|trunk|https://github.com/liyunfan1223/mod-playerbots.git"

  # Written here.
  "server/modules/mod-worldscale|$GH/mod-worldscale|trunk|"
  "server/modules/mod-factionchoice|$GH/mod-factionchoice|trunk|"
  "server/modules/mod-botlore|$GH/mod-botlore|trunk|"
  "server/modules/mod-talentgrant|$GH/mod-talentgrant|trunk|"
  "server/modules/mod-extraglyphs|$GH/mod-extraglyphs|trunk|"
  "server/modules/mod-bankreagents|$GH/mod-bankreagents|trunk|"
  "server/modules/mod-languages|$GH/mod-languages|trunk|"
  "server/modules/mod-spellcooldowns|$GH/mod-spellcooldowns|trunk|"
  "server/modules/mod-aurastack|$GH/mod-aurastack|trunk|"
  "server/modules/mod-bigbags|$GH/mod-bigbags|trunk|"
  "server/modules/mod-transmog-collect|$GH/mod-transmog-collect|trunk|"

  # Used unmodified, straight from their own projects. Pinned by
  # bootstrap.lock rather than by a branch, because these are the ones most
  # likely to move under us.
  "server/modules/mod-transmog|https://github.com/azerothcore/mod-transmog.git|master|"
  "server/modules/mod-aoe-loot|https://github.com/azerothcore/mod-aoe-loot.git|master|"
  "server/modules/mod-worgoblin|https://github.com/heyitsbench/mod-worgoblin.git|master|"
  "server/modules/mod-autobalance|https://github.com/azerothcore/mod-autobalance.git|master|"
)

mode="clone"
case "${1:-}" in
  --pinned) mode="pinned" ;;
  --lock)   mode="lock" ;;
  --status) mode="status" ;;
  "")       ;;
  *) echo "usage: $0 [--pinned|--lock|--status]" >&2; exit 2 ;;
esac

locked_sha() {
  [ -f "$LOCK" ] || return 1
  awk -v p="$1" '$1 == p { print $2; found = 1 } END { exit !found }' "$LOCK"
}

if [ "$mode" = "lock" ]; then
  : > "$LOCK"
  {
    echo "# path <tab> commit - written by tools/bootstrap.sh --lock on $(date -u '+%F %T UTC')"
    for entry in "${REPOS[@]}"; do
      IFS='|' read -r path origin branch upstream <<< "$entry"
      if [ -d "$ROOT/$path/.git" ]; then
        printf '%s\t%s\n' "$path" "$(git -C "$ROOT/$path" rev-parse HEAD)"
      else
        echo "# missing: $path" >&2
      fi
    done
  } >> "$LOCK"
  echo "wrote $LOCK"
  exit 0
fi

if [ "$mode" = "status" ]; then
  printf '%-38s %-8s %-10s %-7s %s\n' REPOSITORY BRANCH HEAD DIRTY "AGAINST LOCK"
  for entry in "${REPOS[@]}"; do
    IFS='|' read -r path origin branch upstream <<< "$entry"
    if [ ! -d "$ROOT/$path/.git" ]; then
      printf '%-38s %s\n' "$path" "MISSING"
      continue
    fi
    head=$(git -C "$ROOT/$path" rev-parse HEAD)
    want=$(locked_sha "$path" || echo "")
    case "$want" in
      "")      lockstate="-" ;;
      "$head") lockstate="ok" ;;
      *)       lockstate="differs" ;;
    esac
    printf '%-38s %-8s %-10s %-7s %s\n' \
      "$path" \
      "$(git -C "$ROOT/$path" rev-parse --abbrev-ref HEAD)" \
      "${head:0:9}" \
      "$(git -C "$ROOT/$path" status --porcelain | wc -l)" \
      "$lockstate"
  done
  exit 0
fi

failed=0
for entry in "${REPOS[@]}"; do
  IFS='|' read -r path origin branch upstream <<< "$entry"
  dest="$ROOT/$path"

  if [ -d "$dest/.git" ]; then
    echo "== $path: already present, left alone"
  else
    echo "== $path: cloning $origin ($branch)"
    if ! git clone --branch "$branch" "$origin" "$dest"; then
      echo "   FAILED to clone $origin" >&2
      failed=$((failed + 1))
      continue
    fi
    if [ -n "$upstream" ]; then
      git -C "$dest" remote add upstream "$upstream"
      echo "   upstream -> $upstream"
    fi
  fi

  if [ "$mode" = "pinned" ]; then
    if want=$(locked_sha "$path"); then
      if [ -n "$(git -C "$dest" status --porcelain)" ]; then
        echo "   not pinning: working tree has local changes" >&2
      elif [ "$(git -C "$dest" rev-parse HEAD)" = "$want" ]; then
        echo "   already at the pinned commit"
      elif git -C "$dest" checkout -q "$want" 2>/dev/null; then
        echo "   checked out pinned ${want:0:9} (detached)"
      else
        git -C "$dest" fetch -q origin && git -C "$dest" checkout -q "$want" 2>/dev/null \
          && echo "   fetched and checked out pinned ${want:0:9} (detached)" \
          || { echo "   FAILED to check out pinned $want" >&2; failed=$((failed + 1)); }
      fi
    else
      echo "   no entry in bootstrap.lock"
    fi
  fi
done

echo
if [ "$failed" -gt 0 ]; then
  echo "$failed repository/repositories failed." >&2
  exit 1
fi
echo "Source tree complete. Still to do, all documented in the README:"
echo "  * configure and build        (Rebuilding and re-applying)"
echo "  * install the DBCs and pack the client patch  (tools/install_worgoblin_dbc.sh)"
echo "  * import the databases and apply sql/         (Databases)"
echo "  * write the configuration    (tools/apply_config.py)"
