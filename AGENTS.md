# AGENTS.md

An AzerothCore 3.3.5a (WotLK) realm with playerbots and a set of custom
modules. `README.md` is the full record of what was built and why; read the
section for whatever you are touching before changing it. This file is the
short list of rules and traps.

## The tree is many repositories

- This repository (`tpyle/wotlk-realm`) holds `sql/`, `tools/`,
  `client-patch/`, the scripts and the README.
- `server/` is the core (a fork of the playerbots AzerothCore) and every
  directory under `server/modules/` is its own repository. Commit in the
  repository the change belongs to. `server/AGENTS.md` and
  `server/modules/mod-playerbots/AGENTS.md` are upstream's; they apply inside
  those trees.
- Every repository uses `trunk`; `origin` is the GitHub copy, and the forks
  (`server`, `mod-ah-bot`, `mod-playerbots`) also have `upstream`.
- `tools/bootstrap.sh --status` shows every repository's branch, head and
  dirty files. After committing in a module, run `tools/bootstrap.sh --lock`
  and commit `bootstrap.lock` here as `Lock <module> with <what changed>`.
- Gitignored and only on disk: `run/` (binaries, generated config, client
  data), `build/`, `logs/`, `backups/`, `notes/`, `ADMIN_CREDENTIALS.txt`,
  the client-patch `.MPQ` files.

## Running

- `./start.sh`, `./stop.sh` (`--now` when only bots are online),
  `./status.sh`. The servers run in tmux sessions `acore-world` and
  `acore-auth`.
- MySQL 8.4 on `127.0.0.1`, user `acore` / `acore`; databases `acore_auth`,
  `acore_characters`, `acore_world`, `acore_playerbots`.
- Stopping logs out and saves 500 bots; let it finish rather than killing it.

## Building

- **Stop the server before compiling and before `make install`.** A running
  server makes install skip the binary as "Up-to-date", and a killed build
  can leave a truncated `.gch` that makes GCC crash on unrelated files.
- GCC 14 (`gcc-14`/`g++-14`), not the system default. The exact cmake line
  is in README, "Rebuilding and re-applying".
- This machine has 56 cores and 750 GB of memory: `make -j56` is fine,
  including a full rebuild (about ten minutes) and the final link. The
  `-j1`/`-j2` advice in README is from the old 15 GB machine.
- Confirm an install with `nm -C run/bin/worldserver | grep <new symbol>`,
  never by comparing md5sums (install rewrites the RUNPATH).
- Use `tools/bg.sh start <name> '<command>'` for anything long, so it survives
  a dropped connection and keeps its exit code.

## Configuration and SQL

- `run/etc/` is generated. Change settings in `tools/apply_config.py` and
  run it; edits made directly to `run/etc/*.conf` are lost on the next run.
  Each config file must appear once in its `SETTINGS` dict (the script
  refuses duplicates).
- A new module setting goes in three places: the module's
  `conf/*.conf.dist`, its README, and `apply_config.py`.
- Every file in `sql/` is idempotent and safe to re-run. Where a change to
  stock data can be undone, a `*_revert.sql` sits beside it.

## Client side

- Anything the client reads from its own DBCs (classes per race, skills,
  item icons, spell text, LFG) needs a regenerated and repacked MPQ in
  `client-patch/`, and every player has to install it again. Say so when a
  change needs one.

## Tests

- mod-worldscale, mod-botlore, mod-talentgrant, mod-spellcooldowns and
  mod-bankreagents keep their logic in pure headers with googletest suites
  that build without the server:
  `cmake -S tests -B build-tests && cmake --build build-tests && ctest --test-dir build-tests --output-on-failure`.
  Keep new logic in those modules testable the same way.

## Content rules

- **mod-botlore: bots never state a level as a number.** No `%level` in
  `level_up` lines and no "level 32". A bot may notice it is getting
  stronger (steadier hands, harder to kill), but never name the number,
  because a number is a game statistic and breaks the fiction. Put this rule
  in the brief of any subagent that writes corpus lines; given a `%level`
  placeholder, a model will use it.

## Documentation

- Every feature has a README section explaining what it does, why, and what
  was learned the hard way. Update it in the same change.
