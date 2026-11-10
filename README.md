# Factory

A Claude Code plugin for the router + workers pattern. You talk to one router session. It takes tickets from GitHub Issues or Azure DevOps Boards, hands each one to a worker in its own git worktree, and comes back with pull requests for you to review.

## How it works

```text
You
 │  one conversation
 ▼
Router ◄──► Tracker (GitHub Issues or ADO Boards)
 │  picks ready tickets, judges results, asks you only for decisions
 ├──► Worker (own worktree) ──► Tester
 ├──► Worker (own worktree) ──► Tester
 ├──► Merger (updates the branch, pushes, opens the PR)
 ├──► Checker (verifies the pushed branch from a clean checkout)
 └──► Watchdog script (flags worktrees that go quiet, and wakes the router to check open PRs)
```

Tickets carry a status marker: a label on GitHub, a tag on ADO.

| Marker | Meaning |
|---|---|
| `factory-draft` | Still being written |
| `factory-ready` | Cleared to build. Only a person sets this |
| `factory-building` | A worker has it |
| `factory-needs-decision` | Waiting on a person |
| `factory-in-review` | PR open and checker passed |

A ticket is done when it closes, which happens when its PR merges.

While a PR is in review, the router checks it each time the watchdog exits, about every nine minutes:

- **Review comments and failed CI** go back to the ticket's worker. The fix lands through the merger and checker again.
- **Merge conflicts** go to the merger.
- **A merged PR** closes the ticket if the code host didn't, and its worktree is removed.
- **A PR closed without merging** becomes a decision for you.

Only comments from people with access to the repo count as feedback. The router posts a short "Factory sent this feedback to a worker" comment on the PR, so the same feedback isn't sent twice.

## Stopping and restarting

You can stop the router and start it again later. On start it picks up tickets marked `factory-building`, `factory-needs-decision`, or `factory-in-review` whose `factory/<id>-...` branch exists on this machine. An interrupted worker's leftover changes are committed to its branch, and a new worker continues from there. Tickets with those markers but no branch here are listed and left alone, since another machine may be working on them.

## Install

Add this repo as a plugin marketplace, using its GitHub `owner/repo` or the path to a local clone:

```bash
claude plugin marketplace add <owner>/factory
```

```bash
claude plugin install factory@factory-marketplace
```

## Set up a repo

In Claude Code, inside the repo:

```text
/factory:init
```

It detects what it can, writes `.claude/factory.json`, checks that `gh` or `az` is ready, and creates the GitHub labels. Commit `.claude/factory.json` so everyone on the repo shares it.

## Use it

1. Write tickets. It reads the code, asks about every open decision, and creates tickets as `factory-draft`:

   ```text
   /factory:write-tickets <what to build, or a path to a PRD>
   ```

2. Review the tickets and set `factory-ready` on the ones you want built.

3. Start the router:

   ```bash
   claude --agent factory:router --permission-mode auto
   ```

4. Tell it what to do, such as "run whatever's ready" or "build 12 and 14". It comes back when it needs a decision or a PR is ready.

You can answer its decision questions and add tickets while work is running.

## Settings

`.claude/factory.json` in each repo:

| Setting | Values |
|---|---|
| `tracker` | `github` or `ado` |
| `codeHost` | `github` or `azure-repos` |
| `baseBranch` | The branch work starts from and PRs target |
| `landing` | `pr` leaves merging to a person. `auto-merge` merges after the checker and the PR's CI checks pass, using the code host's auto-merge so branch protection still applies |
| `maxWorkers` | How many workers run at once |
| `commands` | `setup`, `build`, `test`, and `e2e` commands for the repo. Leave any blank |
| `ado` | Organization, project, repository, work item type, and which field holds the Eval |

## How each tracker stores a ticket

| | GitHub Issues | Azure DevOps Boards |
|---|---|---|
| PRD | Issue body | Description |
| Eval | Issue body | Acceptance Criteria, or Description on the Basic process |
| Status | Labels | Tags |
| Dependencies | `Blocked by: #12` line in the body | Predecessor links |
| Closes on | PR merge, through `Closes #12` | PR completion, through the linked work item |

ADO boards with code on GitHub also work: set `tracker` to `ado` and `codeHost` to `github`. That needs the Azure Boards app connected to the GitHub repo.

## Changing it

- **Models and effort:** the frontmatter in `plugins/factory/agents/`. Everything starts on Sonnet.
- **How agents behave:** the body of each agent file.
- **Another tracker:** add an adapter to `plugins/factory/skills/tracker/references/` with the operations listed in that skill, and add it to the skill's list.

After changing the plugin, validate it and run the tests:

```bash
claude plugin validate plugins/factory
```

```bash
bash tests/watchdog.test.sh
```

```bash
bash tests/cleanup.test.sh
```

```bash
bash tests/release.test.sh
```

## Safety

- **`factory-ready` directs the agents.** Anyone who can set it can tell them what to build, so keep that permission to people you trust.
- **Agents act on the PRD and Eval only.** Ticket comments are left out because anyone can comment on a public issue.
- **`landing: pr` keeps a person in the loop.** Branch protection on your base branch is still worth having.
- **The router's limits are partly instructions.** It has no Write or Edit tools, but it does have Bash for tracker commands.
- **Auto mode isn't a guarantee.** It reviews each action with a classifier, and your organization's admins can turn it off.

## What's been tested

Tested on Claude Code 2.1.317 on Windows, in throwaway repos with a stub `gh` and a local bare `origin`, using `claude -p`.

| Area | Status |
|---|---|
| Router to worker to merger to checker, ending in `factory-in-review` | Tested |
| Worktree isolation, tester started by a worker | Tested |
| Worker stops for a decision, then a resume in the same worktree | Tested |
| Router catching an open decision before starting a worker | Tested |
| Watchdog, cleanup, and release scripts | Tested, with `tests/` |
| `/factory:init`, `/factory:write-tickets`, plugin install | Tested |
| `gh` read commands, including every `pr-status` command | Run for real against a public repo |
| `gh` write commands | Not run for real yet |
| Restart pickup, the PR review loop, and the round limit | Not run yet |
| Interactive sessions, including AskUserQuestion | Not run yet |
| Two or more workers at once, merge conflicts, a blocker unblocking a ticket | Not run yet |
| `auto-merge` landing | Not run yet |
| ADO Boards and Azure Repos adapters | Not run yet. Written from the Azure CLI docs |

## Limits

- It runs on your machine, so work stops when the session ends or the machine sleeps. Starting the router again picks it back up.
- While a PR is in review, the router wakes about every nine minutes to check it, which costs tokens even when nothing changed. If reviews will take days, stop the router and start it again later.
- A worker gets three rounds of fixes for gaps, checker failures, and failed CI before the ticket is marked blocked. The count starts over when the router restarts.
- The watchdog watches for file activity. A long test run that changes no files can get flagged, and the router then just asks that worker for its status.
- On ADO, only tags change. The work item's State doesn't move, so board columns don't follow the ticket until its PR completes.
- Run one router per repo at a time. Nothing enforces this, so two routers can pick up the same `factory-ready` ticket.
- Gitignored files such as `.env` aren't copied into worktrees unless they're listed in `.worktreeinclude`.
- Agent teams aren't used. Workers don't talk to each other, and everything goes through the router.

## License

MIT. See [LICENSE](LICENSE).
