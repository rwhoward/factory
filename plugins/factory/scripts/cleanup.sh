#!/usr/bin/env bash
# Removes finished factory worktrees and their local branches.
#
#   cleanup.sh <worktree-path>...
#
# Removal is forced, so this only touches paths under .claude/worktrees/.
set -u

status=0
for path in "$@"; do
  case "$path" in
    */.claude/worktrees/*) ;;
    *)
      echo "refusing $path: not under .claude/worktrees/" >&2
      status=1
      continue
      ;;
  esac
  branch=$(git -C "$path" branch --show-current 2>/dev/null)
  if ! git worktree remove --force "$path"; then
    status=1
    continue
  fi
  git branch -D "worktree-$(basename "$path")" > /dev/null 2>&1
  case "$branch" in
    factory/*) git branch -D "$branch" > /dev/null 2>&1 ;;
  esac
  echo "removed $path"
done
git worktree prune
exit "$status"
