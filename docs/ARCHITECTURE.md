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

## Data access — MCP first, skills fallback

The project is self-contained: agents, commands, data-access skills, and MCP config all
live in the repo. Access to each system:

| System | Primary | Fallback | Auth |
|---|---|---|---|
| Qase | `qase` MCP server (`.mcp.json`) | — | `QASE_API_TOKEN` from `.env` |
| Jira | `atlassian` MCP (`mcp__atlassian__*`) | `.claude/skills/jira`, `investigate` | MCP: OAuth · skills: `~/.netrc` |
| Confluence | `atlassian` MCP | `.claude/skills/confluence` | same as Jira |

MCP is preferred for uniformity with the Qase write step. The bundled skills make the repo
work even where the Atlassian MCP server is not approved/authenticated (e.g. headless runs)
— they call the REST API directly with stdlib and `~/.netrc`.

## Security

- Least privilege: only sources reachable from the ticket are read; `/prep-testing` writes
  nothing; `/push-to-qase` writes only with `--confirm`.
- **No secrets in git.** The real Qase token is injected via `${QASE_API_TOKEN}` from
  `.env` (gitignored). `.mcp.json` contains only the variable reference, never the value.
- `~/.netrc` and any exported real data (`output/`) are gitignored.
- Demo mode is fully synthetic and is the only mode intended for public presentation.

## Roadmap

- Push accepted cases to Qase behind the review gate (separate confirmed command).
- Regression-coverage analysis for changed areas.
- Bug-report drafting from failed runs.
- Optional thin SDK/CLI wrapper once the prompt logic stabilizes.
