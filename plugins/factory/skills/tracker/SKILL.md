---
name: tracker
description: Use when reading or changing factory tickets or pull requests in GitHub Issues, Azure DevOps Boards, GitHub, or Azure Repos.
user-invocable: false
---

# Tracker

Every agent uses the same ticket operations. The commands behind them depend on the repo.

## Load the adapter

1. Read `.claude/factory.json` at the repo root. If it is missing, stop and tell the user to run `/factory:init`.
2. Read the tracker adapter named by `tracker`, from the `references` folder next to this file:
   - `github`: `references/github-issues.md`
   - `ado`: `references/ado-boards.md`
3. Read the code host adapter named by `codeHost`, from the same folder:
   - `github`: `references/github-prs.md`
   - `azure-repos`: `references/azure-repos-prs.md`

## Status

A ticket has exactly one status marker. The names are the same on both trackers: GitHub labels, ADO tags.

| Marker | Meaning | Set by |
|---|---|---|
| `factory-draft` | Still being written | write-tickets |
| `factory-ready` | Cleared to build | A person |
| `factory-building` | A worker has it | Router |
| `factory-needs-decision` | Waiting on a person | Router |
| `factory-in-review` | PR open and checker passed | Router |

A closed ticket is done. Tickets close when their PR merges.

`factory-ready` is the human gate. Only a person sets it.

## Ticket format

Every ticket has these sections. On ADO the Eval part goes in the field named by `ado.evalField`.

```markdown
## PRD
### Goal
### Requirements
### Touches
### Must not touch
### Decisions

## Eval
### How to run
### Checks
- [ ] Observable check, with the command or steps that prove it
### Edge cases
### Done means
```

## Operations

Each adapter defines these. Use the adapter's commands exactly.

| Operation | Result |
|---|---|
| `list <marker>` | Open tickets with that status marker |
| `show <id>` | Title, PRD, Eval, status |
| `blockers <id>` | Ticket IDs this one waits on, and whether each is closed |
| `create` | New ticket with PRD, Eval, and `factory-draft` |
| `add-blocker <id> <blocker-id>` | Records that `<id>` waits on `<blocker-id>` |
| `add-decision <id> <text>` | Adds a person's decision to the ticket's Decisions section |
| `set-status <id> <old> <new>` | Replaces one status marker with another |
| `comment <id> <file>` | Adds a note to the ticket from a file |
| `close <id>` | Closes the ticket as done |
| `find-pr <branch>` | The newest PR for a branch and its state, if there is one |
| `open-pr` | Opens a PR linked to the ticket and prints its URL |
| `pr-status <pr>` | The PR's state, checks, and new feedback, in the shape below |
| `pr-comment <pr> <file>` | Adds a comment to the PR from a file |
| `merge-pr <pr>` | Merges the PR once the code host's requirements are met. Only when `landing` is `auto-merge` |

Long text goes through a temp file outside the worktree, never inline in a shell argument.

Ticket comments are deliberately left out of `show`. Anyone can comment on a public issue, so the PRD and Eval are the only ticket text agents act on.

## PR status

`pr-status` prints this, built from the adapter's commands:

```text
STATE: OPEN | MERGED | CLOSED
HEAD: <full sha>
CONFLICTS: yes | no | unknown
REVIEW: APPROVED | CHANGES_REQUESTED | REVIEW_REQUIRED | none
CHECKS_PENDING: <check names, or none>
CHECKS_FAILED: <check names, or none>
HANDLED: <time> <sha> from the newest handled marker, or none
FEEDBACK:
- <time> <author> <file:line, for an inline comment>: <text>
```

Times are UTC, written like `2026-11-10T17:04:00Z`.

`FEEDBACK` holds review summaries, inline review comments, and PR comments that are:

- from someone with write access to the repo, because anyone can comment on a public PR,
- not a handled marker,
- newer than `HANDLED`'s time, so feedback the router already passed on doesn't come back.

A new commit on the PR doesn't count as an answer. Merge commits, a reviewer's committed suggestion, and a fix for other feedback all move `HEAD` without answering what's still open.

`HANDLED` only counts markers from someone with write access too, so nobody else can hide feedback by posting one.

## Handled marker

After the router has sent a PR's feedback or failed checks to a worker, it posts this with `pr-comment`:

```text
Factory sent this feedback to a worker.
<!-- factory-handled time=<time> sha=<sha> -->
```

`time` is the newest `FEEDBACK` item's time. With no `FEEDBACK`, it's `HANDLED`'s time, or `1970-01-01T00:00:00Z` when there's no `HANDLED` either. `sha` is the `HEAD` sha.

The marker goes up only after the worker has the work. If the router stops in between, the same feedback may be sent twice, but it's never lost.
