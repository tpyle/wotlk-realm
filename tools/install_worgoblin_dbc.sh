#!/usr/bin/env bash
#
# Server-side data for mod-worgoblin (Worgen and Goblin as playable races),
# and the client patch that goes with it. Run once after the module is built,
# with the world server stopped; re-run any time the module's DBCs change.
#
# What it does, in order:
#   1. copies the module's 30 DBCs over run/data/dbc (the server discovers
#      playable races from ChrRaces.dbc at startup - RaceMgr::LoadRaces - so
#      this is what makes race 9 and 12 creatable server side);
#   2. refreshes the *.orig baselines our own generators start from, because
#      the module's CharBaseInfo/CharStartOutfit/SkillLineAbility/
#      SkillRaceClassInfo are now the base to patch, not the stock ones;
#   3. re-runs gen_all_classes_dbc.py and gen_all_weapons_dbc.py so "all
#      classes on all races" and "every weapon for every class" now cover
#      Worgen and Goblin too;
#   4. packs our two client DBCs as patch-Z.MPQ. It used to be patch-4.MPQ;
#      the client loads patch-?.MPQ matches in name order with later ones
#      overriding, digits before letters, so patch-4 would lose to the
#      module's patch-A.MPQ - and both carry CharBaseInfo.dbc. Z wins.
#
# A backup of the DBC directory as it was before the module went in is at
# run/data/dbc-before-worgoblin.tgz.
set -euo pipefail

ROOT=/root/classic
SRC=$ROOT/server/modules/mod-worgoblin/data/patch/DBFilesClient
DBC=$ROOT/run/data/dbc

# --client-only: skip the server DBC step (nothing changed there) and only
# rebuild patch-Z from the staging directory and the HD merge.
CLIENT_ONLY=0
[ "${1:-}" = "--client-only" ] && CLIENT_ONLY=1

if [ "$CLIENT_ONLY" = 0 ]; then
if pgrep -x worldserver >/dev/null; then
    echo "stop the world server first (./stop.sh)" >&2
    exit 1
fi

n=0
for f in "$SRC"/*.dbc; do
    b=$(basename "$f")
    [ -f "$DBC/$b" ] || echo "note: $b is new to the server set"
    cp "$f" "$DBC/$b"
    [ -f "$DBC/$b.orig" ] && cp "$f" "$DBC/$b.orig"
    n=$((n + 1))
done
echo "installed $n module DBCs into $DBC"

python3 "$ROOT/tools/gen_all_classes_dbc.py"
python3 "$ROOT/tools/gen_all_weapons_dbc.py"
# Layered on top of the weapons pass, not restored from .orig like the two
# above: it edits the same two files, so starting from .orig would undo them.
python3 "$ROOT/tools/gen_lockpicking_dbc.py"
fi

# --- the HD patches -------------------------------------------------------
# The client's Data folder also carries Leeviathan's HD patches (Patch-F/G:
# mounts and creatures, Patch-H: WoD character models with its own goblin
# textures). Each ships DBCs the race module also ships, and they load after
# patch-A, so the module's rows vanished: no CreatureDisplayInfo row for the
# Worgen display ids (a null dereference when the race button is clicked)
# and two competing sets of goblin CharSections (scrambled faces). The eight
# contested DBCs are merged - the HD copy as base, the module's changes on
# top - and shipped in patch-Z together with the module's goblin model
# folder, which loads last. client-patch/hd-dbc holds the HD patches' copies
# (probed out of the archives by name, Patch-H has no listfile) and
# client-patch/stock-dbc the untouched originals the merge diffs against.
HD=$ROOT/client-patch/hd-dbc
STOCK=$ROOT/client-patch/stock-dbc
MERGE="python3 $ROOT/tools/merge_dbc.py"
OUT=$ROOT/client-patch/staging/DBFilesClient
if [ -d "$HD" ]; then
    for f in CreatureDisplayInfo CreatureModelData; do
        # Patch-G loads after Patch-F, so G's changes go on top of F first.
        $MERGE --base "$HD/F-$f.dbc" --overlay "$HD/G-$f.dbc" --stock "$STOCK/$f.dbc" --out "$OUT/$f.dbc"
        $MERGE --base "$OUT/$f.dbc" --overlay "$SRC/$f.dbc" --stock "$STOCK/$f.dbc" --out "$OUT/$f.dbc"
    done
    for f in CreatureDisplayInfoExtra EmotesTextSound HelmetGeosetVisData; do
        $MERGE --base "$HD/H-$f.dbc" --overlay "$SRC/$f.dbc" --stock "$STOCK/$f.dbc" --out "$OUT/$f.dbc"
    done
    # Character appearance: Patch-H's own goblin rows (race 9) are dropped in
    # favour of the module's, since the module's goblin files override H's.
    for f in CharSections CharHairGeosets; do
        $MERGE --base-drop 1=9,12 --base "$HD/H-$f.dbc" --overlay "$SRC/$f.dbc" --stock "$STOCK/$f.dbc" --out "$OUT/$f.dbc"
    done
    $MERGE --key 0,1,2 --base-drop 0=9,12 --base "$HD/H-CharacterFacialHairStyles.dbc" \
        --overlay "$SRC/CharacterFacialHairStyles.dbc" --stock "$STOCK/CharacterFacialHairStyles.dbc" \
        --out "$OUT/CharacterFacialHairStyles.dbc"
    rm -rf "$ROOT/client-patch/staging/Character"
    mkdir -p "$ROOT/client-patch/staging/Character"
    cp -r "$ROOT/server/modules/mod-worgoblin/data/patch/Character/Goblin" "$ROOT/client-patch/staging/Character/"
fi

rm -f "$ROOT/client-patch/patch-4.MPQ"
"$ROOT/tools/mpq_pack" "$ROOT/client-patch/patch-Z.MPQ" "$ROOT/client-patch/staging" | tail -1
echo "client patch: $ROOT/client-patch/patch-Z.MPQ (ours) + patch-A.MPQ (the module's)"
