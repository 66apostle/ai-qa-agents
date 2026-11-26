---
name: review-tests
description: Review test code in a target repo against that repo's own review checklist and convention docs. Runs as Phase 3.5 after implementation, or standalone on any branch or set of files.
argument-hint: [--target=ui-playwright|api-mocha] [TICKET-ID] [--base=main] [--files=a,b] [--fix]
user_invocable: true
---

# Review Tests

Reviews test code inside a target repository against **that repository's own** review
checklist, the way a senior engineer on that team would review a pull request.

Two ways this gets used:

- **As Phase 3.5**, straight after `/qa-flow ... --from=implement`, on the uncommitted diff the
  implementer just produced. This is the default and the main one.
- **Standalone**, on any branch or file set — including code you wrote by hand, or a colleague's
  PR branch.

The review reports findings. It does not change code unless you pass `--fix`.

## Arguments

Parse `$ARGUMENTS`:

- **`--target=<key>`** — a key from `config/targets.json`. If omitted, infer it: a ticket ID
  resolves through `output/<TICKET-ID>-test-prep.md`; otherwise detect which target repo has
  uncommitted changes, and if both do, ask.
- **`TICKET-ID`** (optional) — loads the reviewed cases from
  `output/<TICKET-ID>-test-prep.md` so the review can check coverage against intent, not just
  code quality. Pass it whenever the code came out of this pipeline.
- **`--base=<branch>`** — base for the diff. Default `main`. Ignored when the working tree has
  uncommitted changes, which are reviewed directly.
- **`--files=<a,b>`** — review exactly these files instead of a diff.
- **`--fix`** — apply the fixes for findings that are mechanical and unambiguous (a locator
  named `...Button`, a missing teardown guard, an import out of order). Everything requiring
  judgement is still only reported. Without this flag, nothing is edited.

## What to do

1. Resolve the target and confirm the entry exists in `config/targets.json`.
2. Determine the scope: uncommitted changes in the target repo if there are any, otherwise
   `git diff <base>...HEAD`. If the scope is empty, say so and stop — do not go looking for
   something to review.
3. Delegate to the **test-reviewer** agent with: the target key, the scope (explicit file
   list), and — when a ticket ID was given — the **Test Cases** section from
   `output/<TICKET-ID>-test-prep.md` verbatim.
4. Receive the report and present it as it came back, grouped by the checklist's sections. Do
   not re-summarise it into something softer; a blocking finding stays blocking.
5. If `--fix` was passed, apply only the mechanical fixes the agent marked as such, then re-run
   the target's `lintFix`, `formatFix`, `typeCheck` (where it exists) and `runSpec` to confirm
   the fixes changed nothing behavioural. Report what you changed and what you deliberately
   left alone.

## Rules

- **Report, do not fix**, unless `--fix` was passed. Even then, judgement calls stay reported.
- **Never weaken a test to resolve a finding.** If a finding is "this assertion would pass even
  when the behaviour is broken", the fix is a stronger assertion, never a deleted one.
- Never commit, never push, never open a pull request. This command sits *before* the human
  gate, not after it.
- Only touch files already in the diff under review. No CI config, no unrelated tests.
- An empty finding list is a good outcome. Say so plainly rather than padding the report.
