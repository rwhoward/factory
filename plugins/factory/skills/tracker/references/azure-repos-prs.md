# Azure Repos pull request adapter

Written from the Azure CLI docs. Not yet run against a live ADO project.

Read `ado.organization`, `ado.project`, and `ado.repository` from `.claude/factory.json`. `ORG` below means `https://dev.azure.com/<organization>`.

## find-pr

```bash
az repos pr list --org ORG --project "<project>" --repository "<repository>" --source-branch <branch> --status active --query "[0].pullRequestId" -o tsv
```

Prints nothing when there's no open PR.

## open-pr

```bash
az repos pr create --org ORG --project "<project>" --repository "<repository>" --source-branch <branch> --target-branch <baseBranch> --title "<title>" --description @<file> --work-items <id> --transition-work-items true --query pullRequestId -o tsv
```

## pr-state

```bash
az repos pr show --id <pr> --org ORG --query status -o tsv
```

`active`, `completed`, or `abandoned`.

## merge-pr

Respect branch policies. Never pass `--bypass-policy`.

```bash
az repos pr update --id <pr> --org ORG --auto-complete true --squash true --transition-work-items true
```
