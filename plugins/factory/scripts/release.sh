#!/usr/bin/env bash
# Frees an interrupted worker's branch so a new worker can continue it.
#
#   release.sh <worktree-path>...
#
# Commits anything left in the worktree as work in progress, removes the
# worktree, and keeps its factory/ branch. A new worker then switches to that
# branch from its own worktree. A merge left half done is aborted first, so
# conflict markers never get committed. Only touches paths under
# .claude/worktrees/ that are on a factory/ branch.
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
  case "$branch" in
    factory/*) ;;
    *)
      echo "refusing $path: not on a factory/ branch" >&2
      status=1
      continue
      ;;
  esac
  git_dir=$(git -C "$path" rev-parse --absolute-git-dir)
  if [ -d "$git_dir/rebase-merge" ] || [ -d "$git_dir/rebase-apply" ]; then
    echo "refusing $path: a rebase is in progress" >&2
    status=1
    continue
  fi
  if git -C "$path" rev-parse -q --verify MERGE_HEAD > /dev/null; then
    if ! git -C "$path" merge --abort; then
      echo "refusing $path: could not abort its merge" >&2
      status=1
      continue
    fi
  fi
  if [ -n "$(git -C "$path" status --porcelain)" ]; then
    if ! { git -C "$path" add -A && git -C "$path" commit -q -m "factory: work in progress from an interrupted worker"; }; then
      echo "refusing $path: could not commit its changes" >&2
      status=1
      continue
    fi
  fi
  sha=$(git -C "$path" rev-parse HEAD)
  if ! git worktree remove --force "$path"; then
    status=1
    continue
  fi
  git branch -D "worktree-$(basename "$path")" > /dev/null 2>&1
  echo "released $path branch=$branch commit=$sha"
done
git worktree prune
exit "$status"
