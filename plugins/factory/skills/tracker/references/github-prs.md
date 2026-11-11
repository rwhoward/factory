# GitHub pull request adapter

The PR body must link the ticket so that merging closes it:

- Tracker `github`: a line reading `Closes #<id>`
- Tracker `ado`: a line reading `AB#<id>`. This needs the Azure Boards app connected to the GitHub repo, and the work item does not close on merge unless the commit or PR text says `Fixes AB#<id>`, so use that form.

`gh api` fills in `{owner}` and `{repo}` from the repo you run it in, so type them as they are.

## find-pr

```bash
gh pr list --head <branch> --state all --limit 1 --json url,state --jq '.[] | "\(.url)\t\(.state)"'
```

Prints the URL and `OPEN`, `MERGED`, or `CLOSED`, or nothing when the branch has no PR.

## open-pr

```bash
gh pr create --base <baseBranch> --head <branch> --title "<title>" --body-file <file>
```

## pr-status

State, head, conflicts, and review:

```bash
gh pr view <pr> --json state,mergeable,reviewDecision,headRefOid --jq '"STATE: \(.state)\nHEAD: \(.headRefOid)\nCONFLICTS: \(if .mergeable == "CONFLICTING" then "yes" elif .mergeable == "MERGEABLE" then "no" else "unknown" end)\nREVIEW: \(if (.reviewDecision // "") == "" then "none" else .reviewDecision end)"'
```

Checks. `fail` lines go under `CHECKS_FAILED` and `pending` lines under `CHECKS_PENDING`. This command exits non-zero when checks are failing or pending, or when the PR has none. That describes the checks and isn't an error.

```bash
gh pr checks <pr> --json name,bucket --jq '.[] | select(.bucket == "fail" or .bucket == "pending") | "\(.bucket)\t\(.name)"'
```

`HANDLED`, from the handled markers. It prints one line per marker, oldest first: the author, a tab, then `<time> <sha>`. `HANDLED` is the last line whose author has write access, or `none`:

```bash
gh api "repos/{owner}/{repo}/issues/<pr>/comments" --paginate --jq '.[] | select(.body | contains("factory-handled")) | .user.login as $who | .body | capture("factory-handled time=(?<time>[^ ]+) sha=(?<sha>[0-9a-f]+)") | "\($who)\t\(.time) \(.sha)"'
```

`FEEDBACK`, from review summaries, inline comments, and PR comments. Replace `<since>` with `HANDLED`'s time, or `1970-01-01T00:00:00Z` when it's `none`. Keep only the items whose author has write access. Approvals are left out, since an approval asks for nothing.

```bash
gh api "repos/{owner}/{repo}/pulls/<pr>/reviews" --paginate --jq '.[] | select(.submitted_at > "<since>") | select(.state == "CHANGES_REQUESTED" or (.state == "COMMENTED" and (.body // "") != "")) | {time: .submitted_at, author: .user.login, state, body}'
```

```bash
gh api "repos/{owner}/{repo}/pulls/<pr>/comments" --paginate --jq '.[] | select(.created_at > "<since>") | {time: .created_at, author: .user.login, where: "\(.path):\(.line // .original_line)", body}'
```

```bash
gh api "repos/{owner}/{repo}/issues/<pr>/comments" --paginate --jq '.[] | select(.created_at > "<since>") | select(.body | contains("factory-handled") | not) | {time: .created_at, author: .user.login, body}'
```

### Write access

Anyone can comment on a public PR, so check each author once per `pr-status`. `author_association` isn't used, because GitHub reports org members whose membership is private as `CONTRIBUTOR` or `NONE`.

```bash
gh api "repos/{owner}/{repo}/collaborators/<login>/permission" --jq .permission
```

The author has write access when this prints `admin` or `write`. Maintainers show as `write` here. Anything else, or an error, means no. Bots fail this check, so their comments are left out.

## pr-comment

```bash
gh pr comment <pr> --body-file <file>
```

## merge-pr

`--auto` lets branch protection still apply: GitHub merges once the required checks and reviews pass. If the repo doesn't allow auto-merge and the PR can't merge yet, this fails, and the router leaves the merge to a person.

```bash
gh pr merge <pr> --squash --auto
```
