#!/usr/bin/env bash
# Exercises scripts/release.sh against throwaway git worktrees.
# Run with: bash tests/release.test.sh
set -u

script="$(cd "$(dirname "$0")/.." && pwd)/plugins/factory/scripts/release.sh"
repo="$(mktemp -d)"
failures=0

pass() { echo "ok   - $1"; }
fail() { echo "FAIL - $1"; failures=$((failures + 1)); }

cd "$repo" || exit 1
git init -q -b main
git config user.email test@example.com
git config user.name test
echo one > file.txt
printf 'node_modules/\n' > .gitignore
git add file.txt .gitignore
git commit -qm one

# An interrupted worker with uncommitted edits, a new file, and an ignored folder.
git worktree add -q -b worktree-agent-a .claude/worktrees/agent-a
git -C .claude/worktrees/agent-a switch -q -c factory/1-a
echo edited > .claude/worktrees/agent-a/file.txt
echo new > .claude/worktrees/agent-a/new.txt
mkdir .claude/worktrees/agent-a/node_modules
echo dep > .claude/worktrees/agent-a/node_modules/dep.js
before_a="$(git rev-parse factory/1-a)"

# A merger interrupted in the middle of a conflicted merge.
git worktree add -q -b worktree-agent-b .claude/worktrees/agent-b
git -C .claude/worktrees/agent-b switch -q -c factory/2-b
echo ticket > .claude/worktrees/agent-b/file.txt
git -C .claude/worktrees/agent-b commit -qam ticket
before_b="$(git rev-parse factory/2-b)"
echo base > file.txt
git commit -qam base
git -C .claude/worktrees/agent-b merge -q main > /dev/null 2>&1
git -C .claude/worktrees/agent-b rev-parse -q --verify MERGE_HEAD > /dev/null && pass "setup: merge left half done" || fail "setup: merge left half done"

# A worker that had committed everything.
git worktree add -q -b worktree-agent-c .claude/worktrees/agent-c
git -C .claude/worktrees/agent-c switch -q -c factory/3-c
echo done > .claude/worktrees/agent-c/done.txt
git -C .claude/worktrees/agent-c add done.txt
git -C .claude/worktrees/agent-c commit -qm done
before_c="$(git rev-parse factory/3-c)"

# A checker on a detached HEAD, and a worktree outside the factory folder.
git worktree add -q --detach .claude/worktrees/agent-d
git worktree add -q -b outside ../"$(basename "$repo")-outside"

output="$(bash "$script" "$repo/.claude/worktrees/agent-a" "$repo/.claude/worktrees/agent-b" "$repo/.claude/worktrees/agent-c" 2>&1)"
status=$?

[ "$status" -eq 0 ] && pass "release exits zero" || fail "release exits zero: $output"
[ ! -e .claude/worktrees/agent-a ] && pass "worker worktree removed" || fail "worker worktree removed"
git show-ref --verify -q refs/heads/factory/1-a && pass "factory branch kept" || fail "factory branch kept"
git show-ref --verify -q refs/heads/worktree-agent-a && fail "helper branch deleted" || pass "helper branch deleted"
[ "$(git rev-parse factory/1-a~1)" = "$before_a" ] && pass "leftovers committed on top" || fail "leftovers committed on top"
[ "$(git show factory/1-a:file.txt)" = "edited" ] && pass "edited file kept" || fail "edited file kept"
git cat-file -e factory/1-a:new.txt 2>/dev/null && pass "new file kept" || fail "new file kept"
git cat-file -e factory/1-a:node_modules/dep.js 2>/dev/null && fail "ignored files left out" || pass "ignored files left out"
case "$output" in *"released $repo/.claude/worktrees/agent-a branch=factory/1-a commit="*) pass "report names branch and commit" ;; *) fail "report names branch and commit: $output" ;; esac

[ ! -e .claude/worktrees/agent-b ] && pass "merger worktree removed" || fail "merger worktree removed"
[ "$(git rev-parse factory/2-b)" = "$before_b" ] && pass "half-done merge aborted, not committed" || fail "half-done merge aborted, not committed"

[ "$(git rev-parse factory/3-c)" = "$before_c" ] && pass "clean worktree gets no extra commit" || fail "clean worktree gets no extra commit"

git worktree add -q -b worktree-agent-e .claude/worktrees/agent-e
git -C .claude/worktrees/agent-e switch -q factory/1-a 2>/dev/null && pass "a new worker can switch to the released branch" || fail "a new worker can switch to the released branch"

output="$(bash "$script" "$repo/.claude/worktrees/agent-d" 2>&1)"
status=$?
[ -e .claude/worktrees/agent-d ] && pass "refuses a worktree not on a factory branch" || fail "refuses a worktree not on a factory branch"
[ "$status" -ne 0 ] && pass "refusal exits non-zero" || fail "refusal exits non-zero"
case "$output" in *refusing*) pass "refusal says why" ;; *) fail "refusal says why" ;; esac

outside="$(cd "../$(basename "$repo")-outside" && pwd)"
bash "$script" "$outside" > /dev/null 2>&1
[ -e "$outside" ] && pass "refuses a path outside .claude/worktrees" || fail "refuses a path outside .claude/worktrees"

cd / && rm -rf "$repo" "$repo-outside"

if [ "$failures" -eq 0 ]; then
  echo "all passed"
else
  echo "$failures failed"
  exit 1
fi
