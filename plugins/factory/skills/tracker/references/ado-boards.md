# Azure DevOps Boards adapter

Written from the Azure CLI docs. Not yet run against a live ADO project.

Requires the `azure-devops` CLI extension and a signed-in account. Azure DevOps Server is not supported by these commands.

Read `ado.organization`, `ado.project`, `ado.workItemType`, and `ado.evalField` from `.claude/factory.json`. `ORG` below means `https://dev.azure.com/<organization>`.

A ticket ID is the work item ID. Status markers are tags, because state names differ between process templates. Dependencies are Predecessor links.

`--description`, `--discussion`, and `--fields "Name=value"` accept `@<path>` to read a value from a file. Use that for all long text. Both Description and the Eval field take HTML, so convert Markdown headings and lists to simple HTML before writing the file.

Set `evalField` to `System.Description` for the Basic process, which has no Acceptance Criteria field, and put Eval after PRD in the same HTML.

## list-ready

```bash
az boards query --org ORG --project "<project>" --wiql "SELECT [System.Id], [System.Title] FROM workitems WHERE [System.TeamProject] = @project AND [System.Tags] CONTAINS 'factory-ready' AND [System.State] NOT IN ('Closed', 'Done', 'Removed') ORDER BY [System.Id]" --query "[].{id:id, title:fields.\"System.Title\"}" -o tsv
```

## show

```bash
az boards work-item show --id <id> --org ORG -o json
```

The useful fields are `System.Title`, `System.Description`, `System.State`, `System.Tags`, and the Eval field.

## blockers

```bash
az boards work-item relation show --id <id> --org ORG --query "relations[?attributes.name=='Predecessor'].url" -o tsv
```

The blocker ID is the last path segment of each URL. For each one:

```bash
az boards work-item show --id <blocker-id> --org ORG --query "fields.\"System.State\"" -o tsv
```

The ticket is unblocked when every blocker is `Closed` or `Done`.

## create

Write the PRD HTML and Eval HTML to separate files, then:

```bash
az boards work-item create --org ORG --project "<project>" --type "<workItemType>" --title "<title>" --description @<prd-file> --fields "<evalField>=@<eval-file>" "System.Tags=factory-draft" --query id -o tsv
```

## add-blocker

```bash
az boards work-item relation add --id <id> --relation-type Predecessor --target-id <blocker-id> --org ORG
```

## add-decision

Read `System.Description` into a file, add the decision under the Decisions heading, then write it back. If it comes back empty, stop and report it, because writing it back would erase the ticket.


```bash
az boards work-item update --id <id> --org ORG --description @<file>
```

## set-status

`System.Tags` is replaced as a whole. Read it, swap one marker, and write back every other tag unchanged. If the read fails, stop and report it, because writing would erase the other tags.

```bash
az boards work-item show --id <id> --org ORG --query "fields.\"System.Tags\"" -o tsv
az boards work-item update --id <id> --org ORG --fields "System.Tags=<all tags, separated by '; '>"
```

## comment

```bash
az boards work-item update --id <id> --org ORG --discussion @<file>
```
