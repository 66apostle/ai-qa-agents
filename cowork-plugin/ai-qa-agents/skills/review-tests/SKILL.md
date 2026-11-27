---
name: review-tests
description: Reviews test code in the Playwright or Mocha test repo against that repo's own review checklist and conventions, like a senior reviewer on the team. Reports findings; fixes only mechanical ones when asked. Use for "/review-tests", "review my test branch", "review these specs", "check this PR's tests".
argument-hint: [--target=ui-playwright|api-mocha] [TICKET-ID] [--base=main] [--files=a,b] [--fix]
---

# Review Tests

Phase 3.5 of the pipeline, also usable alone on any branch or file set. Read
`../../shared/cowork-environment.md` first (§1 workspace, §6 target repos).

## Arguments

- `--target=<key>` — from `targets.json`. If omitted: a ticket ID resolves through its report;
  otherwise use whichever connected target repo has uncommitted changes; if both or neither,
  ask.
- `TICKET-ID` — loads the Test Cases section of `<workspace>/output/<ID>-test-prep.md` for the
  coverage-vs-intent check.
- `--base=<branch>` — default `main`. Ignored when the working tree has uncommitted changes.
- `--files=a,b` — review exactly these files.
- `--fix` — apply only mechanical, unambiguous fixes. Without it, edit nothing.

## Steps

1. Resolve the target and connect its repo folder.
2. Scope: uncommitted changes if any, else `git diff <base>...HEAD`. Empty scope → say so and
   stop.
3. Read `../../shared/agents/test-reviewer.md` and follow it on that scope (and the Test Cases,
   if a ticket was given).
4. Present the report grouped by the checklist's sections. Do not soften it.
5. With `--fix`: apply only the mechanical fixes, then run the target's lint/format/type-check
   and `runSpec` (environment §6.4 for run failures). Report what changed and what was left.

## Rules

Never weaken a test to resolve a finding. Never commit or push. Touch only files in the scope.
An empty finding list is a good result — say so plainly.
