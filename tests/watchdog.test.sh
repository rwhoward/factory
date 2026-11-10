#!/usr/bin/env bash
# Exercises scripts/watchdog.sh --once against throwaway git worktrees.
# Run with: bash tests/watchdog.test.sh
set -u

script="$(cd "$(dirname "$0")/.." && pwd)/plugins/factory/scripts/watchdog.sh"
repo="$(mktemp -d)"
failures=0

check() { # name, expected substring ("" means output must be empty), actual
  if [ -z "$2" ]; then
    if [ -z "$3" ]; then echo "ok   - $1"; return; fi
  else
    case "$3" in *"$2"*) echo "ok   - $1"; return ;; esac
  fi
  echo "FAIL - $1"
  echo "       expected: '${2:-<nothing>}'"
  echo "       actual:   '$3'"
  failures=$((failures + 1))
}

cd "$repo" || exit 1
git init -q -b main
git config user.email test@example.com
git config user.name test
echo one > file.txt
git add file.txt
git commit -qm one

run() { bash "$script" --once 20 2>&1; }

check "no worktrees means no report" "" "$(run)"

git worktree add -q -b factory/1-a .claude/worktrees/agent-a
git worktree add -q -b factory/2-b .claude/worktrees/agent-b
git worktree add -q -b unrelated ../"$(basename "$repo")-outside"
check "recent worktrees are not reported" "" "$(run)"

old="$(date -d '2 hours ago' '+%Y-%m-%d %H:%M:%S')"
find .claude/worktrees/agent-a -type f -exec touch -d "$old" {} +
touch -d "$old" ../"$(basename "$repo")-outside"/file.txt

first="$(run)"
check "quiet worktree is reported" "QUIET" "$first"
check "report names the branch" "branch=factory/1-a" "$first"
case "$first" in
  *agent-b*) check "active worktree stays out of the report" "" "$first" ;;
  *) echo "ok   - active worktree stays out of the report" ;;
esac
case "$first" in
  *outside*) check "worktrees outside .claude stay out of the report" "" "$first" ;;
  *) echo "ok   - worktrees outside .claude stay out of the report" ;;
esac

check "a quiet worktree is reported only once" "" "$(run)"

echo two > .claude/worktrees/agent-a/new.txt
touch -d "$old" .claude/worktrees/agent-a/new.txt
check "new work makes it reportable again" "branch=factory/1-a" "$(run)"

# The looping form must stop by itself, because background commands get killed.
exit_out="$(timeout 10 bash "$script" 0 20 0 2>&1)"
status=$?
check "looping form stops at its time limit" "NOTHING_QUIET" "$exit_out"
[ "$status" -eq 124 ] && check "looping form exits before being killed" "exited" "timed out"

cd / && rm -rf "$repo" "$repo-outside"

if [ "$failures" -eq 0 ]; then
  echo "all passed"
else
  echo "$failures failed"
  exit 1
fi
