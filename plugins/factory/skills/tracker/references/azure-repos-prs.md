# Azure Repos pull request adapter

Written from the Azure CLI docs. Not yet run against a live ADO project.

Read `ado.organization`, `ado.project`, and `ado.repository` from `.claude/factory.json`. `ORG` below means `https://dev.azure.com/<organization>`.

PR states map like this: `active` is `OPEN`, `completed` is `MERGED`, and `abandoned` is `CLOSED`.

## find-pr

```bash
az repos pr list --org ORG --project "<project>" --repository "<repository>" --source-branch <branch> --status all --top 1 --query "[0].[pullRequestId, status]" -o tsv
```

Prints nothing when the branch has no PR.

## open-pr

```bash
az repos pr create --org ORG --project "<project>" --repository "<repository>" --source-branch <branch> --target-branch <baseBranch> --title "<title>" --description @<file> --work-items <id> --transition-work-items true --query pullRequestId -o tsv
```

## pr-status

State, head, conflicts, and reviewer votes:

```bash
az repos pr show --id <pr> --org ORG --query "{status: status, mergeStatus: mergeStatus, head: lastMergeSourceCommit.commitId, votes: reviewers[].vote}" -o json
```

- `CONFLICTS` is `yes` when `mergeStatus` is `conflicts`, `no` when it's `succeeded`, and `unknown` otherwise.
- `REVIEW` is `CHANGES_REQUESTED` if any vote is `-10` (rejected) or `-5` (waiting for author). Otherwise it's `APPROVED` if any vote is `10` or `5`, `REVIEW_REQUIRED` if there are reviewers, and `none` if there aren't.

Checks are the PR's build and status policies. `rejected` or `broken` goes under `CHECKS_FAILED`, and `queued` or `running` under `CHECKS_PENDING`:

```bash
az repos pr policy list --id <pr> --org ORG --query "[?configuration.type.displayName=='Build' || configuration.type.displayName=='Status'].{type: configuration.type.displayName, name: configuration.settings.displayName, status: status}" -o json
```

`HANDLED` and `FEEDBACK` come from the PR's comment threads:

```bash
az devops invoke --org ORG --area git --resource pullRequestThreads --route-parameters project="<project>" repositoryId="<repository>" pullRequestId=<pr> --api-version 7.1 -o json
```

Each comment has `author.displayName`, `content`, `publishedDate`, and `commentType`. Inline threads have `threadContext.filePath` and `threadContext.rightFileStart.line`.

- `HANDLED` is the newest comment whose `content` contains `factory-handled`.
- `FEEDBACK` is every comment with `commentType` `text` that doesn't contain `factory-handled` and is newer than `HANDLED`'s time, or every such comment when there's no `HANDLED`. Commenting on an Azure Repos PR takes the project's Contribute to pull requests permission, so no author filter is needed.

## pr-comment

Write this JSON to a file, with the comment text as `content`. The thread is posted as closed, so it never holds up a policy that requires comments to be resolved.

```json
{"comments": [{"parentCommentId": 0, "content": "<text>", "commentType": 1}], "status": "closed"}
```

```bash
az devops invoke --org ORG --area git --resource pullRequestThreads --route-parameters project="<project>" repositoryId="<repository>" pullRequestId=<pr> --http-method POST --in-file <file> --api-version 7.1
```

## merge-pr

Respect branch policies. Never pass `--bypass-policy`.

```bash
az repos pr update --id <pr> --org ORG --auto-complete true --squash true --transition-work-items true
```
