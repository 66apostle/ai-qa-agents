# AI-QA Agents — Ticket to Automated Tests

A multi-agent system that takes a ticket ID and walks it all the way to working automated
tests: it reads the requirements, chases the documentation, designs the test cases, and then
implements them in the target test repository — following that repo's own conventions.

Give it a ticket ID; get back a structured requirements corpus, automation-ready test cases,
an effort estimate, a list of requirement gaps to resolve **before** development starts, and
— after you review — real test code that runs.

> Inspired by the approach described in ["How we cut test preparation by 70% with AI
> agents"](https://habr.com/ru/companies/svoi_ru/articles/1024608/). This is an
> independent implementation built on Claude Code, with a demo mode that uses fully
> synthetic data — no confidential information is included.

## Why this exists

Most people think QA is running tests and finding bugs. In practice a large share of the
time goes to *preparation*: reading a Jira ticket, hunting acceptance criteria across
Confluence, reconciling an RFC with a product idea, and only then writing the first test
case. This pipeline automates the mechanical part of that work and — just as valuably —
surfaces missing scenarios, incomplete rules, and contradictions early.

The human QA engineer stays in control: the pipeline stops at two review gates and never
writes to an external system, or commits code, on its own.

## Architecture

Three specialist agents in a chain, coordinated by a slash command, with a human gate after
test design and another after implementation.

```
        QA / Product
   Jira · Confluence · Docs · fixtures
                │
                ▼
   ┌──────────────────────────────┐
   │  Coordinator                  │  /qa-flow <TICKET-ID>
   │  • runs the pipeline          │
   │  • delegates & combines       │
   │  • stops at both gates        │
   └───────────────┬──────────────┘
                   │
                   ▼
   ┌──────────────────────────────┐
   │  Phase 1: Requirements        │  → requirements corpus
   │  Researcher                   │
   │  • gathers ticket, AC, Epic,  │
   │    PRODUCT idea, RFC, links   │
   │  • extracts only — never      │
   │    interprets or invents      │
   │  • marks GAPs & CONFLICTs     │
   └───────────────┬──────────────┘
                   │
                   ▼
   ┌──────────────────────────────┐
   │  Phase 2: QA Test Design      │  → test cases + estimate
   │  Architect                    │    + out-of-scope list
   │  • one happy path per flow +  │
   │    the key rejections         │
   │  • AC-to-test mapping         │
   │  • two scope gates (ticket,   │
   │    then regression-suite fit) │
   │  • automation-ready, STE      │
   └───────────────┬──────────────┘
                   │
                   ▼
   ╔══════════════════════════════╗
   ║  GATE 1 — human review        ║  accept / cut / refine
   ║  → optional /push-to-qase     ║  (separate, confirmed step)
   ╚═══════════════┬══════════════╝
                   │
                   ▼
   ┌──────────────────────────────┐
   │  Phase 3: Test Implementer    │  → page objects, specs,
   │  • reads the target repo's     │    helpers, test data
   │    own docs & existing code   │
   │  • writes the tests           │
   │  • runs them, fixes failures  │
   │  • never weakens assertions   │
   └───────────────┬──────────────┘
                   │
                   ▼
   ┌──────────────────────────────┐
   │  Phase 3.5: Test Reviewer     │  → findings: blocking /
   │  • the target repo's own       │    worth fixing / questions
   │    review checklist, walked   │
   │    item by item               │
   │  • coverage vs the approved   │
   │    cases                      │
   │  • reports, does not fix      │
   └───────────────┬──────────────┘
                   │
                   ▼
   ╔══════════════════════════════╗
   ║  GATE 2 — human review        ║  read the diff + findings,
   ║  unstaged diff in target repo ║  then commit (never the agent)
   ╚══════════════════════════════╝
```

### Targets and stack profiles

Phase 3 writes into a **target repository**, not into this one. Each target is described by
an entry in `config/targets.json` plus a **stack profile** in `docs/stacks/`.

The profile is a **map, not a rulebook**: where files go, which commands run the result, and
which of the target repo's own documents define its conventions (`conventionDocs` and
`reviewChecklist` in the target entry). Those documents are the source of truth — they are
maintained by the team that owns the repo, and a copy kept here goes stale within one
refactor. When the profile and the repo disagree, the repo wins and the drift is reported as
a finding.

| Target | Stack | Role |
|---|---|---|
| `ui-playwright` | Playwright + TypeScript, POM, fixtures | active UI target |
| `api-mocha` | Mocha + Chai + superagent (ESM) | active API target |
| `ui-wdio` | WebdriverIO | legacy, read-only — being ported to Playwright |

Adding a stack means adding a config entry and a profile document; the implementer agent
itself stays unchanged.

### Design decisions worth noting

- **Separation of concerns.** The researcher *only extracts* and the architect *only
  designs*. Keeping gathering and interpretation apart preserves the source of truth and
  makes hallucinated requirements far less likely.
- **Scope control, twice.** An LLM tends to test *everything adjacent* to a change, which
  inflates estimates. Agent 3 first keeps to the ticket, then checks each case against what a
  regression suite actually accepts — one happy path per flow plus the key rejections.
  Boundary ladders and per-channel permutations go into an explicit
  `[OUT OF SCOPE — engineer decides]` list with a reason.
- **Gaps as a first-class output.** Contradictions and missing docs are reported, not
  silently resolved — often the most valuable result, because they surface before code is
  written.
- **Human-in-the-loop.** The pipeline never writes to Jira/Confluence/Qase and never commits
  code. A person reviews at both gates first.
- **Automation-ready output.** Cases use atomic steps, explicit test data, assertable
  results, and ASD-STE100 Simplified Technical English, so they convert cleanly into
  automated tests.
- **Stack profiles instead of a mega-prompt.** The implementer agent holds no framework
  opinions of its own; it loads a profile that maps the target repo's layout and points at
  that repo's own convention docs. Conventions stay where their owners maintain them, and a
  new stack is a config change rather than a prompt rewrite.
- **Generated code gets reviewed before you see it.** Phase 3.5 walks the target repo's own
  review checklist against the diff, item by item, and checks the tests back against the
  approved cases — including whether an assertion was quietly bent to match the app's
  behaviour, which would have destroyed a finding meant for you.
- **A failing test is a finding, not an obstacle.** The implementer diagnoses failures and
  fixes causes, but never weakens an assertion or deletes coverage to get green. Where the
  app contradicts a reviewed case, it reports the discrepancy for a human to judge.

## Repository layout

```
ai-qa-agents/
├─ .claude/
│  ├─ agents/
│  │  ├─ requirements-researcher.md   # Phase 1
│  │  ├─ qa-test-architect.md         # Phase 2
│  │  ├─ test-implementer.md          # Phase 3
│  │  └─ test-reviewer.md             # Phase 3.5
│  ├─ commands/
│  │  ├─ qa-flow.md                   # full pipeline coordinator (all phases)
│  │  ├─ prep-testing.md              # Phases 1–2 only (docs, no code)
│  │  ├─ push-to-qase.md              # reviewed cases → Qase (dry-run by default)
│  │  ├─ review-tests.md              # Phase 3.5, or standalone on any branch
│  │  ├─ find-selectors.md            # live-browser selector discovery
│  │  └─ find-endpoint.md             # endpoint lookup in the application source
│  └─ skills/                         # self-contained data-access skills
│     ├─ jira/                        # Jira REST via ~/.netrc (fallback path)
│     ├─ confluence/                  # Confluence REST via ~/.netrc
│     └─ investigate/                 # one-pass ticket context pull
├─ fixtures/                          # demo mode: synthetic tickets
│  └─ DEMO-123/                       # sample ticket + Epic + PRODUCT idea + RFC
├─ config/
│  ├─ sources.json                    # demo | real switch
│  ├─ targets.example.json            # template — copy to targets.json
│  └─ targets.json                    # target repos for Phase 3 (gitignored: local paths)
├─ docs/
│  ├─ ARCHITECTURE.md
│  └─ stacks/                         # stack profiles: layout maps, not rulebooks
│     ├─ ui-playwright.md
│     └─ api-mocha.md
├─ .mcp.json                          # Qase + Atlassian + Playwright MCP servers
├─ .env.example                       # QASE_API_TOKEN template (copy to .env)
├─ output/                            # generated reports land here (gitignored)
├─ cowork-plugin/                     # the same pipeline packaged for Claude Cowork
│  ├─ ai-qa-agents/                   # plugin source (skills + shared playbooks)
│  ├─ ai-qa-agents.plugin             # installable build
│  └─ build.sh                        # rebuilds the .plugin from source
└─ README.md
```

Everything the pipeline needs lives in this one folder — agents, commands, data-access
skills, and MCP server config. Clone it and it works.

## Setup

Requires [Claude Code](https://claude.com/claude-code).

**Demo mode needs no setup** — it reads local fixtures only.

For **real mode** (live Jira/Confluence/Qase):

1. Copy the env template and add your Qase token:
   ```bash
   cp .env.example .env      # then edit .env, set QASE_API_TOKEN
   ```
2. Data access uses MCP first, with a skills fallback:
   - **Qase** — MCP server (`.mcp.json`), token from `.env`.
   - **Jira / Confluence** — Atlassian MCP (`.mcp.json`, OAuth on first use). If MCP is
     unavailable, the bundled skills in `.claude/skills/` are used instead; they
     authenticate via `~/.netrc` (`machine your-org.atlassian.net`).
3. Set your real project keys in `config/sources.json` → `real`.

For **Phase 3** (implementing tests):

4. Point the targets config at your test repositories:
   ```bash
   cp config/targets.example.json config/targets.json   # then set each target's "root"
   ```
   `config/targets.json` is gitignored — it holds absolute local paths. Each target entry also
   names the documents in that repo which define its conventions (`conventionDocs`,
   `reviewChecklist`); the profiles in `docs/stacks/` only map the layout and point at them.
   If your repos differ, edit the target entry and the profile, not the agent.
5. The target repo must be runnable on its own first: dependencies installed and its `.env`
   configured (the UI target also needs its stored auth state, at the path in the target's
   `authState`, e.g. `.auth/user.json`). Phase 3 runs the suite there, it does not bootstrap
   it.

On first launch Claude Code asks you to approve the MCP servers — accept them. The
`playwright` server is only needed for live selector discovery (`/find-selectors`).

## Usage

```bash
cd ai-qa-agents
claude
```

Then, inside Claude Code:

```
/qa-flow DEMO-123
```

Phases 1–2 run and the pipeline produces `output/DEMO-123-test-prep.md`, then stops at
**Gate 1**. Nothing is pushed anywhere.

**Fast mode** for small tickets (Happy Path only):

```
/qa-flow DEMO-123 --positive
```

Only want the documentation, never the code? `/prep-testing <TICKET-ID>` runs Phases 1–2 and
nothing else.

### Real tickets

On a real ticket the coordinator gathers live context from Jira/Confluence (Atlassian MCP,
with the bundled skills as fallback) and works the same way, stopping at Gate 1:

```
/qa-flow TS-1234 --mode=real
```

### After Gate 1 — Qase, and the tests

Review `output/TS-1234-test-prep.md` and cut anything you do not want. Then, independently:

**Push the accepted cases to Qase** — dry-run by default, writes only with `--confirm`:

```
/push-to-qase TS-1234            # shows what would be created — writes nothing
/push-to-qase TS-1234 --confirm  # creates the cases in Qase after your review
```

`[OUT OF SCOPE]` items and unconfirmed `[ASSUMPTION]` cases are never pushed.

**Implement the automated tests** — Phase 3, straight from the reviewed report:

```
/qa-flow TS-1234 --from=implement --target=ui-playwright
/qa-flow TS-1234 --from=implement --target=api-mocha --cases=1,3
```

The implementer reads the target repo's conventions, studies the neighbouring code, writes
the page objects / specs / helpers / data, runs the suite, and fixes what it broke. Phase 3.5
then reviews the diff against that repo's own review checklist. It stops at **Gate 2** with an
unstaged diff and a report: files touched, what it reused, case→test mapping, run results,
cases it could not automate, any place the app contradicts a reviewed case, and the review
findings split into blocking / worth fixing / questions. Committing is your call.

To review code that did not come out of this pipeline — something you wrote by hand, or a
colleague's branch — run the reviewer on its own:

```
/review-tests --target=ui-playwright                 # the current working tree
/review-tests --target=api-mocha --base=develop      # a branch diff
/review-tests TS-1234 --target=ui-playwright         # also checks coverage vs the cases
```

That closes the loop **Jira → test docs → Qase → automated tests**.

## Using it in Claude Cowork (desktop app)

The same pipeline is packaged as a **Cowork plugin** in `cowork-plugin/`, so you can run it
from the Claude desktop app without Claude Code, a terminal, `.env` or `~/.netrc`. It uses the
connectors you already have in Cowork (Atlassian, Qase) and the same agent prompts, gates and
rules as the Claude Code version.

### Install

1. Open the Claude desktop app and start a Cowork task.
2. Drag `cowork-plugin/ai-qa-agents.plugin` into the chat (or attach it).
3. Press **Install** on the plugin card. The skills appear under `/` in every new Cowork task.

To update after editing the source, rebuild and install again:

```bash
./cowork-plugin/build.sh      # writes cowork-plugin/ai-qa-agents.plugin
```

Bump `version` in `cowork-plugin/ai-qa-agents/.claude-plugin/plugin.json` when you do.

### What it needs

| Need | Why | How |
|---|---|---|
| This folder connected | Reports go to `output/`; `config/sources.json` and `config/targets.json` are read from here | Approve the folder prompt on first run (it shows on your Mac) |
| Atlassian connector | Reads the ticket, Epic, PRODUCT idea, RFC (read-only) | Cowork → Connectors → Atlassian |
| Qase connector | `/push-to-qase` only | Cowork → Connectors → Qase |
| Test repo folders | Phase 3 / review — writes and runs tests there | Approve the folder prompt when asked |

The folder path is set in `cowork-plugin/ai-qa-agents/shared/cowork-environment.md`
(`/Users/66apostle/Документы/ai-qa-agents`). Teammates should change it to their own path
and rebuild.

### Use

Type `/` in a Cowork task and pick a skill, or ask in plain words ("write test cases for
TS-1234").

| Skill | What it does |
|---|---|
| `/qa-flow TS-1234` | Phases 1–2: report saved to `output/TS-1234-test-prep.md`, stops at **Gate 1** |
| `/qa-flow TS-1234 --positive` | Same, Happy Path only (small tickets) |
| `/prep-testing TS-1234` | Report only, never code |
| `/push-to-qase TS-1234` | Dry run; reply "confirm" to create the cases in Qase |
| `/qa-flow TS-1234 --from=implement --target=ui-playwright` | Phase 3 + 3.5: writes, runs and reviews the tests, stops at **Gate 2** with an unstaged diff |
| `/qa-flow TS-1234 --from=implement --target=api-mocha --cases=1,3` | Only the listed cases, API repo |
| `/review-tests --target=ui-playwright` | Review any working tree or branch against the repo's checklist |
| `/find-selectors <page> <element>` | Real selectors from the live dashboard |
| `/find-endpoint campaigns/{id}/snapshot` | Route, method and params from the XP / MXA source |
| `/qa-flow DEMO-123` | Demo with the synthetic ticket — no connectors needed |

Typical flow: `/qa-flow TS-1234` → review and edit the report → optional `/push-to-qase` →
`/qa-flow TS-1234 --from=implement --target=…` → read the diff and findings → commit yourself.

### Differences from the Claude Code version

- Phases run in one conversation (the agent prompts in `cowork-plugin/ai-qa-agents/shared/agents/`
  are followed in turn) instead of as separate subagents.
- Tests run in Cowork's Linux VM on your Mac. If macOS-installed `node_modules` (Playwright
  browsers, esbuild) do not run there, the plugin does not reinstall anything in your repo — it
  gives you the command to run in your terminal and continues from the pasted output.
- The plugin keeps its own copy of the agent prompts. After changing `.claude/agents/*.md`,
  copy them into `cowork-plugin/ai-qa-agents/shared/agents/` and rebuild.

## Modes

Controlled by `config/sources.json`:

- **`demo`** (default) — reads everything from `fixtures/<TICKET-ID>/`. No network, no
  credentials, safe to run and present anywhere.
- **`real`** — pulls live context from Jira/Confluence via Claude Code skills. **Never
  commit real credentials or exported real data to this repo** (see `.gitignore`).

## The demo ticket

`fixtures/DEMO-123` is a realistic "export a segment to CSV" story spread across a Jira
ticket, a parent Epic, a PRODUCT idea, and an RFC. It intentionally contains:

- a **CONFLICT** — the acceptance criteria cap the segment at 10,000 contacts, the RFC caps
  it at 5,000;
- a **GAP** — both reference an "Export Throttling Policy" document that does not exist in
  the fixtures.

A good run flags both in the gaps section rather than silently picking one — that is the
behavior the pipeline is designed to demonstrate.

## Status

Working proof of concept, exercised end to end on both a synthetic ticket and a real one.
See `docs/ARCHITECTURE.md` for design notes and `docs/stacks/` for the target profiles.

Roadmap: regression-coverage analysis for changed areas; bug-report drafting from failed
runs; a thin SDK/CLI wrapper once the prompt logic stabilises.
