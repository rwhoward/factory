#!/usr/bin/env bash
# Reports factory worktrees that have gone quiet, then exits so the router wakes up.
#
#   watchdog.sh [check-every-minutes] [quiet-after-minutes] [stop-after-minutes]
#   watchdog.sh --once [quiet-after-minutes]
#
# The looping form stops by itself, printing NOTHING_QUIET, because long-running
# background commands get killed. The router restarts it while work is running.
#
# Each quiet state is reported once. New commits or changed files make a
# worktree reportable again, so the router isn't woken twice for the same thing.
set -u

seen_file="$(git rev-parse --git-common-dir)/factory-watchdog-seen"

has_recent_files() { # path, minutes
  [ -n "$(find "$1" \( -name .git -o -name node_modules \) -prune -o -type f -mmin "-$2" -print -quit 2>/dev/null)" ]
}

check() { # quiet-after-minutes; returns 0 if anything was reported
  local quiet_after=$1 reported=1 line path key
  while IFS= read -r line; do
    case "$line" in
      "worktree "*/.claude/worktrees/*) path=${line#worktree } ;;
      *) continue ;;
    esac
    has_recent_files "$path" "$quiet_after" && continue
    key="$path $(git -C "$path" rev-parse HEAD) $(git -C "$path" status --porcelain | cksum)"
    grep -qxF "$key" "$seen_file" 2>/dev/null && continue
    echo "$key" >> "$seen_file"
    echo "QUIET path=$path branch=$(git -C "$path" branch --show-current) quiet_for_at_least=${quiet_after}m"
    reported=0
  done < <(git worktree list --porcelain)
  return $reported
}

if [ "${1:-}" = "--once" ]; then
  check "${2:-20}"
  exit 0
fi

check_every=${1:-2}
quiet_after=${2:-20}
stop_after=${3:-9}
deadline=$(( $(date +%s) + stop_after * 60 ))

while :; do
  remaining=$(( deadline - $(date +%s) ))
  [ "$remaining" -le 0 ] && break
  pause=$(( check_every * 60 ))
  [ "$pause" -gt "$remaining" ] && pause=$remaining
  sleep "$pause"
  check "$quiet_after" && exit 0
done
echo "NOTHING_QUIET checked_for=${stop_after}m"
