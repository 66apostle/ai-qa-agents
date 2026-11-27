---
name: qa-flow
description: Runs the end-to-end QA pipeline for one ticket — gathers requirements from Jira/Confluence, designs regression-ready test cases, stops for human review, then implements and reviews automated tests in the Playwright or Mocha repo. Use for "/qa-flow TS-1234", "prep tests for ticket X", "implement tests for TS-1234", "run the QA pipeline".
argument-hint: TICKET-ID [--target=ui-playwright|api-mocha] [--mode=demo|real] [--positive] [--from=prep|implement|review] [--cases=1,3]
---

# QA Flow — full pipeline coordinator

Walk one ticket from requirements to working automated tests, with two hard human gates.

**First, read `../../shared/cowork-environment.md`** (relative to this skill's base
directory). It maps every path, tool and "delegate" instruction below onto Cowork.

```
Phase 1   requirements-researcher  → requirements corpus
Phase 2   qa-test-architect        → test cases + estimate + out-of-scope
══ GATE 1 — human reviews the report ══   (optional: push-to-qase)
Phase 3   test-implementer         → tests in the target repo, run them
Phase 3.5 test-reviewer            → findings vs the repo's own checklist
══ GATE 2 — human reviews the diff, then commits ══
```

Never commit, push, or open a pull request. Never write to Jira, Confluence, or Qase here.

## Arguments

- `<TICKET-ID>` — required. If missing, ask.
- `--target=<key>` — a key from `targets.json`. If omitted, infer before Phase 3: UI pages /
  components → `ui-playwright`; endpoints / payloads → `api-mocha`; both → the one most AC are
  written against (say the rest is out of scope this run); unclear → ask. Never pick a
  `legacy-read-only` target.
- `--mode=demo|real` — default from the ticket prefix (see environment file §2).
- `--positive` — fast mode: Happy Path case only.
- `--from=prep|implement|review` — `prep` (default) runs Phases 1–2 and stops at Gate 1.
  `implement` runs Phase 3 + 3.5 from the saved report. `review` runs Phase 3.5 only.
- `--cases=1,3` — implement only these case numbers.

Plain-language requests map onto these ("implement case 1 and 3 for TS-1234 in the UI repo"
= `--from=implement --target=ui-playwright --cases=1,3`).

## Phase 1 — Gather requirements  (skip if `--from=implement|review`)

1. Make sure the workspace folder is available (environment §1).
2. **Demo:** read every file in `shared/demo/<ID>/`.
   **Real:** collect the raw context with the Atlassian connector (environment §3): the
   ticket with every AC, comments and links; its parent Epic; the linked PRODUCT idea; the
   RFC and every linked Confluence page.
3. Read `../../shared/agents/requirements-researcher.md` and produce the **requirements
   corpus** exactly as it specifies, from only what you gathered. Mark every unreadable
   source as GAP and every disagreement as CONFLICT.

## Phase 2 — Design test cases  (skip if `--from=implement|review`)

1. Read `../../shared/agents/qa-test-architect.md` and follow it on the corpus. With
   `--positive`, produce only the Happy Path case.
2. Consolidate GAP / CONFLICT / UNCLEAR markers into concrete questions to resolve before
   development. Invent nothing; every item traces to the corpus or a real coverage gap.
3. Assemble the report in the format of `../../shared/report-format.md`, save it to
   `<workspace>/output/<ID>-test-prep.md`, and tell the user where it is.

## Gate 1 — STOP

Show a short summary (case count, top conflicts/gaps) and then exactly this:

```
Gate 1 — review output/<ID>-test-prep.md in your ai-qa-agents folder

Then choose:
  /push-to-qase <ID>                      dry-run the Qase push
  /push-to-qase <ID> --confirm            write the cases to Qase
  /qa-flow <ID> --from=implement --target=<key>   implement the tests
```

Do not continue until the user comes back. The user may edit the report first; always
re-read it from disk in later phases.

## Phase 3 — Implement  (`--from=implement`, or the user explicitly says continue)

1. Read `<workspace>/output/<ID>-test-prep.md`. Missing → tell the user to run
   `/qa-flow <ID>` first, and stop. If several versions exist, use the highest `.vN` and say so.
2. Extract the **Test Cases** section only. Ignore the corpus, gaps, and `[OUT OF SCOPE]`.
3. If any case carries an unresolved `[ASSUMPTION]`, list those cases and ask whether to
   include them.
4. Resolve the target and connect its repo folder (environment §6).
5. Read `../../shared/agents/test-implementer.md` and follow it fully: target contract,
   neighbours, mapping table, real selectors, code, run + failure loop, verification table,
   report. Apply environment §6.4 for test runs.

## Phase 3.5 — Review  (always after Phase 3; alone with `--from=review`)

Do not skip it because the run was green. Switch roles cleanly: read
`../../shared/agents/test-reviewer.md` and review the files Phase 3 touched, with the Test
Cases section verbatim for the coverage check. A blocking finding stays blocking. An assertion
bent to match app behaviour is the most important line in the report.

You may fix findings the review marked mechanical and unambiguous once, then re-review once.
Anything requiring judgement goes to the human. Never loop more than once.

## Gate 2 — STOP

If anything is blocking, say so at the top. Then show: files with one line each; the run
command and pass/fail result (or the environment gap and the command for the user to run);
failing tests with diagnosis; cases not automated and why; app-vs-case discrepancies; review
findings as blocking / worth fixing / questions; stack-profile drift. Finish with
`git status --short` and `git diff --stat` from the target repo, and state that the diff is
unstaged in that folder and committing is the user's call.

## Rules

- Two hard gates. No external writes without an explicit, confirmed command.
- Never weaken an assertion to turn a test green. A discrepancy is a finding.
- Zero results from any phase is valid — report it, do not retry blindly.
- In target repos, touch only files for this feature. Never CI config, never unrelated tests.
