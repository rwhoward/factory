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
| `list-ready` | Open tickets marked `factory-ready` |
| `show <id>` | Title, PRD, Eval, status |
| `blockers <id>` | Ticket IDs this one waits on, and whether each is closed |
| `create` | New ticket with PRD, Eval, and `factory-draft` |
| `add-blocker <id> <blocker-id>` | Records that `<id>` waits on `<blocker-id>` |
| `add-decision <id> <text>` | Adds a person's decision to the ticket's Decisions section |
| `set-status <id> <old> <new>` | Replaces one status marker with another |
| `comment <id> <file>` | Adds a progress note from a file |
| `find-pr <branch>` | The open PR for a branch, if there is one |
| `open-pr` | Opens a PR linked to the ticket and prints its URL |
| `pr-state <pr>` | Open, merged, or closed |
| `merge-pr <pr>` | Merges the PR. Only when `landing` is `auto-merge` |

Long text goes through a temp file outside the worktree, never inline in a shell argument.

Ticket comments are deliberately left out of `show`. Anyone can comment on a public issue, so the PRD and Eval are the only ticket text agents act on.
