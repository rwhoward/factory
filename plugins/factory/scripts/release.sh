#!/usr/bin/env bash
# Frees an interrupted worker's branch so a new worker can continue it.
#
#   release.sh <worktree-path>...
#
# Commits anything left in the worktree as work in progress, removes the
# worktree, and keeps its factory/ branch. A new worker then switches to that
# branch from its own worktree. A merge, cherry-pick, or revert left half done
# is aborted first, and unresolved conflicts or a rebase in progress are
# refused, so conflict markers never get committed. Only touches paths under
# .claude/worktrees/ that are on a factory/ branch.
set -u
. "$(dirname "$0")/worktree-lib.sh"

status=0
refuse() { # path, reason
  echo "refusing $1: $2" >&2
  status=1
}

for path in "$@"; do
  if ! factory_worktree_path "$path"; then
    status=1
    continue
  fi
  # Checked before the branch, because a rebase detaches HEAD.
  git_dir=$(git -C "$path" rev-parse --absolute-git-dir 2>/dev/null)
  if [ -n "$git_dir" ] && { [ -d "$git_dir/rebase-merge" ] || [ -d "$git_dir/rebase-apply" ]; }; then
    refuse "$path" "a rebase is in progress"
    continue
  fi
  branch=$(git -C "$path" branch --show-current 2>/dev/null)
  case "$branch" in
    factory/*) ;;
    *)
      refuse "$path" "not on a factory/ branch"
      continue
      ;;
  esac
  aborted=yes
  for op in MERGE_HEAD:merge CHERRY_PICK_HEAD:cherry-pick REVERT_HEAD:revert; do
    if git -C "$path" rev-parse -q --verify "${op%%:*}" > /dev/null; then
      if ! git -C "$path" "${op#*:}" --abort; then
        refuse "$path" "could not abort its ${op#*:}"
        aborted=no
        break
      fi
    fi
  done
  [ "$aborted" = yes ] || continue
  if [ -n "$(git -C "$path" diff --name-only --diff-filter=U)" ]; then
    refuse "$path" "it has unresolved conflicts"
    continue
  fi
  if [ -n "$(git -C "$path" status --porcelain)" ]; then
    if ! { git -C "$path" add -A && git -C "$path" commit -q -m "factory: work in progress from an interrupted worker"; }; then
      refuse "$path" "could not commit its changes"
      continue
    fi
  fi
  sha=$(git -C "$path" rev-parse HEAD)
  if ! remove_worktree "$path"; then
    status=1
    continue
  fi
  echo "released $path branch=$branch commit=$sha"
done
git worktree prune
exit "$status"
