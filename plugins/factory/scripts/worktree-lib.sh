#!/usr/bin/env bash
# Shared by cleanup.sh and release.sh. Source it rather than running it.

# Succeeds for a path under .claude/worktrees/, and says why on stderr otherwise.
# Removal is forced, so nothing outside that folder may be touched.
factory_worktree_path() {
  case "$1" in
    */.claude/worktrees/*) return 0 ;;
  esac
  echo "refusing $1: not under .claude/worktrees/" >&2
  return 1
}

# Force-removes a worktree and the worktree-<name> branch its agent started on.
remove_worktree() {
  git worktree remove --force "$1" || return 1
  git branch -D "worktree-$(basename "$1")" > /dev/null 2>&1
  return 0
}
