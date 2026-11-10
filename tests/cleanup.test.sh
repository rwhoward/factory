#!/usr/bin/env bash
# Exercises scripts/cleanup.sh against throwaway git worktrees.
# Run with: bash tests/cleanup.test.sh
set -u

script="$(cd "$(dirname "$0")/.." && pwd)/plugins/factory/scripts/cleanup.sh"
repo="$(mktemp -d)"
failures=0

pass() { echo "ok   - $1"; }
fail() { echo "FAIL - $1"; failures=$((failures + 1)); }

cd "$repo" || exit 1
git init -q -b main
git config user.email test@example.com
git config user.name test
echo one > file.txt
git add file.txt
git commit -qm one

# A finished worker: helper branch plus the factory branch it switched to.
git worktree add -q -b worktree-agent-a .claude/worktrees/agent-a
git -C .claude/worktrees/agent-a switch -q -c factory/1-a
# A finished checker: detached HEAD, with an untracked file left behind.
git worktree add -q -b worktree-agent-b .claude/worktrees/agent-b
git -C .claude/worktrees/agent-b checkout -q --detach
echo junk > .claude/worktrees/agent-b/junk.txt
# Another ticket that must survive.
git worktree add -q -b worktree-agent-c .claude/worktrees/agent-c
# A worktree outside the factory folder.
git worktree add -q -b outside ../"$(basename "$repo")-outside"

bash "$script" "$repo/.claude/worktrees/agent-a" "$repo/.claude/worktrees/agent-b" > /dev/null 2>&1

[ ! -e .claude/worktrees/agent-a ] && pass "worker worktree removed" || fail "worker worktree removed"
[ ! -e .claude/worktrees/agent-b ] && pass "worktree with leftovers removed" || fail "worktree with leftovers removed"
git show-ref --verify -q refs/heads/factory/1-a && fail "factory branch deleted" || pass "factory branch deleted"
git show-ref --verify -q refs/heads/worktree-agent-a && fail "helper branch deleted" || pass "helper branch deleted"
git show-ref --verify -q refs/heads/worktree-agent-b && fail "checker helper branch deleted" || pass "checker helper branch deleted"
[ -e .claude/worktrees/agent-c ] && pass "other worktree kept" || fail "other worktree kept"
git show-ref --verify -q refs/heads/worktree-agent-c && pass "other branch kept" || fail "other branch kept"

outside="$(cd "../$(basename "$repo")-outside" && pwd)"
output="$(bash "$script" "$outside" 2>&1)"
status=$?
[ -e "$outside" ] && pass "refuses a path outside .claude/worktrees" || fail "refuses a path outside .claude/worktrees"
[ "$status" -ne 0 ] && pass "refusal exits non-zero" || fail "refusal exits non-zero"
case "$output" in *refusing*) pass "refusal says why" ;; *) fail "refusal says why" ;; esac

cd / && rm -rf "$repo" "$repo-outside"

if [ "$failures" -eq 0 ]; then
  echo "all passed"
else
  echo "$failures failed"
  exit 1
fi
