---
name: write-tickets
description: Use when turning a feature idea, PRD, or bug list into factory tickets that a worker can build without asking questions.
argument-hint: <what to build, or a path to a PRD>
---

# Write Tickets

Workers can't ask questions, so a ticket has to answer them in advance. Every ticket must pass this test: someone who has never spoken to the user could build it and prove it's done.

Request: $ARGUMENTS

## Steps

1. Read `${CLAUDE_PLUGIN_ROOT}/skills/tracker/SKILL.md` and load the adapters it names.
2. Read the request and the code it affects, so you ask only what the code can't answer.
3. Split the work into tickets. Each one is a single reviewable PR that is useful on its own.
4. Ask the user about every open decision, one question at a time, until none remain. Offer concrete options and your recommendation.
5. Show the user the ticket titles and what each waits on, and adjust until they agree.
6. Run `create` for each ticket, in dependency order, then `add-blocker` for each dependency.
7. List the tickets with links. Tell the user they're in `factory-draft`, and that setting `factory-ready` on a ticket is what lets the router build it. Leave that step to them.

## What each section holds

| Section | Contents |
|---|---|
| Goal | What changes for the user, in a sentence or two |
| Requirements | Every behavior, specific enough to check |
| Touches | Files, modules, or areas expected to change |
| Must not touch | Areas the worker has to leave alone |
| Decisions | Each choice the user made, and why |
| How to run | Commands to start and test this change |
| Checks | One observable check per requirement |
| Edge cases | What could go wrong, and the expected behavior |
| Done means | The final state, in a sentence |

## Writing checks

A check states an action and a result that anyone can verify.

```markdown
- [ ] `curl -s localhost:3000/health` returns status 200 with body `{"ok":true}`
- [ ] Submitting the form with an empty email shows "Email is required" and sends no request
```

If you can't write the check, the requirement isn't clear yet. Go back to step 4.
