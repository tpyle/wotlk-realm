#!/usr/bin/env bash
#
# Run a long job (a build, a database import) detached, in a way that survives
# an SSH drop *and* can be checked afterwards.
#
#   tools/bg.sh start <name> <command...>   run it
#   tools/bg.sh status [name]               running, or dead with its exit code
#   tools/bg.sh log <name> [lines]          the output so far
#   tools/bg.sh watch <name>                block until it finishes (for scripts)
#   tools/bg.sh clean <name>                forget a finished job
#
# It is a tmux session, which buys three things over "setsid nohup ... &":
#
#   * you can watch it happen - tmux attach -t acore-<name>
#   * the exit code survives the process, because the pane is kept after the
#     command exits (remain-on-exit) and tmux reports #{pane_dead_status}.
#     A plain background job has to remember to echo $? somewhere, and if it
#     is killed rather than failing, nothing is written at all.
#   * the output is both on screen and in logs/<name>.log (pipe-pane), so it
#     can be grepped later.
#
# What it does NOT do is tell anyone it has finished - nothing polls for you.
# Pair it with a watcher that blocks on "tools/bg.sh watch <name>".
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOGS="$ROOT/logs"

usage() { sed -n '3,20p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 2; }

cmd="${1:-}"; shift || usage
[ -n "$cmd" ] || usage

case "$cmd" in
  start)
    name="${1:-}"; shift || usage
    [ -n "$name" ] && [ $# -gt 0 ] || usage
    session="acore-$name"
    if tmux has-session -t "$session" 2>/dev/null; then
      echo "$session already exists - 'tools/bg.sh status $name', or clean it first" >&2
      exit 1
    fi
    mkdir -p "$LOGS"
    : > "$LOGS/$name.log"
    # The command is run through bash -c so that a pipeline or && chain works.
    tmux new-session -d -s "$session" -x 220 -y 50 \
      "bash -c $(printf '%q' "$*")" \; set-option -t "$session" remain-on-exit on
    tmux pipe-pane -o -t "$session" "cat >> $(printf '%q' "$LOGS/$name.log")"
    echo "started $session"
    echo "  watch it:  tmux attach -t $session   (detach with ctrl-b d)"
    echo "  log:       $LOGS/$name.log"
    ;;

  status)
    name="${1:-}"
    for session in $(tmux list-sessions -F '#{session_name}' 2>/dev/null | grep '^acore-'); do
      short="${session#acore-}"
      [ -n "$name" ] && [ "$short" != "$name" ] && continue
      read -r dead code < <(tmux list-panes -t "$session" -F '#{pane_dead} #{pane_dead_status}' 2>/dev/null | head -1)
      if [ "${dead:-0}" = "1" ]; then
        printf '%-20s finished, exit %s\n' "$short" "${code:-unknown}"
      else
        printf '%-20s running\n' "$short"
      fi
    done
    ;;

  log)
    name="${1:-}"; lines="${2:-40}"
    [ -n "$name" ] || usage
    tail -n "$lines" "$LOGS/$name.log"
    ;;

  watch)
    name="${1:-}"
    [ -n "$name" ] || usage
    session="acore-$name"
    while tmux has-session -t "$session" 2>/dev/null; do
      read -r dead code < <(tmux list-panes -t "$session" -F '#{pane_dead} #{pane_dead_status}' 2>/dev/null | head -1)
      if [ "${dead:-0}" = "1" ]; then
        echo "$name finished, exit ${code:-unknown}"
        exit "${code:-0}"
      fi
      sleep 15
    done
    echo "$name: no such session (already cleaned?)" >&2
    exit 1
    ;;

  clean)
    name="${1:-}"
    [ -n "$name" ] || usage
    tmux kill-session -t "acore-$name" 2>/dev/null && echo "cleaned acore-$name"
    ;;

  *) usage ;;
esac
