---
name: prep-testing
description: Prepares test documentation only (no code) for a ticket — requirements corpus, regression-ready test cases, effort estimate, and gap questions — and saves one report for human review. Use for "/prep-testing TS-1234", "write test cases for this ticket", "what's missing in this ticket's requirements".
argument-hint: TICKET-ID [--positive] [--mode=demo|real]
---

# Prep Testing — documentation only

Run Phases 1–2 of the QA pipeline and stop at Gate 1. This never writes code and never writes
to Jira, Confluence or Qase.

1. Read `../../shared/cowork-environment.md` (relative to this skill's base directory).
2. Read `../qa-flow/SKILL.md` and carry out **Phase 1**, **Phase 2** and **Gate 1** exactly as
   written there, with the same arguments (`<TICKET-ID>`, `--positive`, `--mode`).
3. Stop at Gate 1. Do not offer to start Phase 3 in the same turn; list it only as an option
   in the Gate 1 message.
