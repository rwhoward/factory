# GitHub pull request adapter

The PR body must link the ticket so that merging closes it:

- Tracker `github`: a line reading `Closes #<id>`
- Tracker `ado`: a line reading `AB#<id>`. This needs the Azure Boards app connected to the GitHub repo, and the work item does not close on merge unless the commit or PR text says `Fixes AB#<id>`, so use that form.

## find-pr

```bash
gh pr list --head <branch> --state open --json url --jq '.[0].url'
```

Prints nothing when there's no open PR.

## open-pr

```bash
gh pr create --base <baseBranch> --head <branch> --title "<title>" --body-file <file>
```

## pr-state

```bash
gh pr view <pr> --json state --jq .state
```

`OPEN`, `MERGED`, or `CLOSED`.

## merge-pr

```bash
gh pr merge <pr> --squash
```
