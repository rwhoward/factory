#!/usr/bin/env bash
# Removes finished factory worktrees and their local branches.
#
#   cleanup.sh <worktree-path>...
#
# Removal is forced, so this only touches paths under .claude/worktrees/.
set -u
. "$(dirname "$0")/worktree-lib.sh"

status=0
for path in "$@"; do
  if ! factory_worktree_path "$path"; then
    status=1
    continue
  fi
  branch=$(git -C "$path" branch --show-current 2>/dev/null)
  if ! remove_worktree "$path"; then
    status=1
    continue
  fi
  case "$branch" in
    factory/*) git branch -D "$branch" > /dev/null 2>&1 ;;
  esac
  echo "removed $path"
done
git worktree prune
exit "$status"
