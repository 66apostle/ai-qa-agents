# Architecture notes

## Pipeline stages

| Stage | Component | Input | Output | Guarantee |
|---|---|---|---|---|
| 1 | `prep-testing` command (Coordinator) | ticket ID, mode | orchestration + final report | Never writes to external systems |
| 2 | `requirements-researcher` agent | ticket ID, mode | requirements corpus | Extracts only; marks GAP/CONFLICT; never invents |
| 3 | `qa-test-architect` agent | requirements corpus | test cases, AC map, estimate, out-of-scope | Automation-ready, STE, scope-controlled |
| — | Human review | full report | accepted cases | Gate before any Qase push |

## Why three agents instead of one prompt

A single mega-prompt mixes gathering, interpretation, and design, which makes it easy for
the model to blur the source of truth and invent requirements. Splitting the roles:

- **isolates extraction from design** — the researcher cannot "helpfully" rewrite a
  requirement it is only supposed to quote;
- **makes each stage independently reviewable** — the corpus can be checked before any test
  case is written;
- **mirrors how a QA analyst actually works** — first understand, then design.

## Provenance of Agent 3

The `qa-test-architect` prompt is adapted from a mature in-house playbook for generating
test cases from Jira tickets. Adaptations for this environment:

1. Role moved into agent frontmatter; removed the Atlassian-Rovo-specific framing.
2. Context is no longer assumed "in view" — it arrives as a corpus from Agent 2.
3. Hardcoded org-specific project/space paths replaced with `config/sources.json` values.
4. Added an explicit `[OUT OF SCOPE — engineer decides]` block to control estimate bloat.

## Real mode & security

- Real mode reads Jira/Confluence through Claude Code skills using local credentials.
- Least privilege: only sources reachable from the ticket are read; nothing is written.
- Credentials and any exported real data are gitignored and must never be committed.
- The demo mode is fully synthetic and is the only mode intended for public presentation.

## Roadmap

- Push accepted cases to Qase behind the review gate (separate confirmed command).
- Regression-coverage analysis for changed areas.
- Bug-report drafting from failed runs.
- Optional thin SDK/CLI wrapper once the prompt logic stabilizes.
