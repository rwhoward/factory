# GitHub Issues adapter

`gh` infers the repository from the `origin` remote. Run commands from inside the repo.

A ticket ID is the issue number. Dependencies live on the issue's last line:

```text
Blocked by: #12, #14
```

## list-ready

```bash
gh issue list --state open --label factory-ready --limit 100 --json number,title --jq '.[] | "\(.number)\t\(.title)"'
```

## show

```bash
gh issue view <id> --json number,title,body,labels,state
```

## blockers

```bash
gh issue view <id> --json body --jq .body | grep -iE '^Blocked by:' | grep -oE '#[0-9]+' | tr -d '#'
```

For each number printed:

```bash
gh issue view <blocker-id> --json state --jq .state
```

The ticket is unblocked when every blocker prints `CLOSED`.

## create

Write the title to a variable and the full body to a file, then:

```bash
gh issue create --title "<title>" --body-file <file> --label factory-draft
```

## add-blocker

Read the body into a file, append or extend the `Blocked by:` line, then write it back. If the body comes back empty, stop and report it, because writing it back would erase the ticket.


```bash
gh issue edit <id> --body-file <file>
```

## add-decision

Read the body into a file, add the decision under `### Decisions`, then write it back. If the body comes back empty, stop and report it, because writing it back would erase the ticket.


```bash
gh issue edit <id> --body-file <file>
```

## set-status

```bash
gh issue edit <id> --remove-label <old> --add-label <new>
```

## comment

```bash
gh issue comment <id> --body-file <file>
```
