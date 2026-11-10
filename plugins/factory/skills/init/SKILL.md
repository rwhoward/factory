---
name: init
description: Use when setting up a repo for the factory or when .claude/factory.json is missing.
disable-model-invocation: true
---

# Init

Set up this repo for the factory. Fill in everything you can detect, and ask only about the rest.

## Steps

1. Confirm this is a git repo with an `origin` remote. Stop if it isn't.
2. Read `git remote get-url origin`:
   - `github.com`: `codeHost` is `github`
   - `dev.azure.com` or `visualstudio.com`: `codeHost` is `azure-repos`, and the URL gives `ado.organization`, `ado.project`, and `ado.repository`
3. Ask which tracker the repo uses, `github` or `ado`, suggesting the one that matches the code host.
4. If the tracker is `ado`:
   - Get `ado.organization` and `ado.project` if the remote didn't give them.
   - Ask for the work item type: `User Story` (Agile), `Product Backlog Item` (Scrum), `Requirement` (CMMI), or `Issue` (Basic).
   - For Basic, set `ado.evalField` to `System.Description`.
5. Set `baseBranch` from `git symbolic-ref --short refs/remotes/origin/HEAD`, without the `origin/` prefix.
6. Fill in `commands` from what the repo uses, such as `package.json` scripts or a `.sln` file. Leave a command empty if you can't tell, and say so.
7. Ask for `landing`: `pr` leaves every PR for a person to merge, and `auto-merge` merges after the checker and the PR's CI checks pass, through the code host's own auto-merge so branch protection still applies. Suggest `pr`.
8. Write the result to `.claude/factory.json`, starting from `${CLAUDE_PLUGIN_ROOT}/templates/factory.json`. If the file already exists, show what would change and ask first.
9. Add `.claude/worktrees/` to `.gitignore` if it's missing.
10. Check the tools the config needs, and for anything missing give the user the exact fix rather than installing it:
    - GitHub: `gh auth status`
    - ADO: `az extension show --name azure-devops` and `az account show`
11. If the tracker is `github`, create the labels:
    ```bash
    gh label create factory-draft --color BFD4F2 --description "Ticket still being written" --force
    gh label create factory-ready --color 0E8A16 --description "Cleared for the router to build" --force
    gh label create factory-building --color FBCA04 --description "A worker has this ticket" --force
    gh label create factory-needs-decision --color D93F0B --description "Waiting on a person" --force
    gh label create factory-in-review --color 5319E7 --description "PR open and checker passed" --force
    ```
    ADO tags are created the first time they're used.
12. Report what you set and what's missing. Mention that gitignored files such as `.env` aren't copied into worktrees unless they're listed in `.worktreeinclude`. Finish with the next steps: `/factory:write-tickets`, then `claude --agent factory:router --permission-mode auto`.
