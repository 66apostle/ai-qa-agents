---
name: push-to-qase
description: Pushes human-reviewed test cases from a saved test-prep report into Qase. Dry-run by default; writes only when the user confirms. Use for "/push-to-qase TS-1234", "push these cases to Qase", "create the test cases in Qase".
argument-hint: TICKET-ID [--confirm] [--suite=id] [--code=PROJECT]
---

# Push to Qase

Create the **already-reviewed** cases from a test-prep report in Qase. This is the only write
step after Gate 1. Read `../../shared/cowork-environment.md` first (§1 workspace, §4 Qase).

## Safety rules

- **Dry-run by default.** Without `--confirm` (or the user plainly saying "yes, create them"
  after seeing a dry run), show what would be created and write nothing.
- Push only what is in the report. Missing or empty report → stop and say so.
- `[OUT OF SCOPE]` items are never pushed.
- Cases with `[ASSUMPTION]` steps: list them separately and ask before including them.
- No deletes. Create new cases only, or update a case whose report line already carries a
  Qase case id.
- Demo tickets (`DEMO-*`): dry run only, unless the user explicitly insists on writing.

## Steps

1. **Load the report** `<workspace>/output/<ID>-test-prep.md` (highest `.vN` if several; say
   which). If it is not there, check for a chat attachment; otherwise tell the user to run
   `/prep-testing <ID>` and stop. Parse the **Test Cases** section only: title, type,
   objective, preconditions, postconditions, steps (action + expected result).
2. **Confirm the target.** Project code from `--code`, else `sources.json` → `real.qase.projectCode`
   (default `XP`). Call `qase_project_context` to confirm the project and see the suite tree.
   Verify `--suite` if given. If no suite was given, show the suite tree and ask which suite to
   use (or confirm root). Unresolvable → stop, create nothing.
3. **Map each case** to `qase_case_upsert`:

| Report field | Param |
|---|---|
| title | `title` |
| project code | `code` |
| suite | `suite_id` |
| type | `type` (functional unless a better match exists) |
| objective | prepend to `description`, then "Source: <ID>" |
| preconditions / postconditions | `preconditions` / `postconditions` |
| steps | `steps`, `steps_type: "classic"`, each `{action, expected_result}` |
| — | `automation`: "is-not-automated" |
| ticket ID, "prep-testing" | `tags` |

   Set `priority` only if the report states one.
4. **Dry run:** table of title, type, step count, target suite, plus the exact payload of the
   first case. End with: "Dry run. Say *confirm* to create these N cases in Qase project
   `<CODE>`."
   **Confirmed:** create cases one at a time; record each returned id. On any failure, stop,
   report what was already created (with ids), and do not retry blindly.
5. **Report:** title → Qase id → link (`https://app.qase.io/case/<CODE>-<id>`); counts of
   created / skipped / failed; reminder that out-of-scope and unconfirmed assumption cases were
   not pushed. Optionally, with the user's OK, append the Qase ids to the report file next to
   each case title so later updates do not duplicate them.
