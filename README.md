# AI-QA Agents — Test Preparation Pipeline

A multi-agent system that cuts the preparation phase of software testing — reading
requirements, chasing documentation, and drafting test documentation — from hours to
minutes. Give it a ticket ID; get back a structured requirements corpus, automation-ready
test cases, an effort estimate, and a list of requirement gaps to resolve **before**
development starts.

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

The human QA engineer stays in control: the pipeline stops at a review gate and never
writes to any external system on its own.

## Architecture

Three agents in a chain, coordinated by a slash command.

```
        QA / Product
   Jira · Confluence · Docs · fixtures
                │
                ▼
   ┌──────────────────────────────┐
   │  Agent 1: Coordinator         │  /prep-testing <TICKET-ID>
   │  • runs the pipeline          │
   │  • delegates & combines       │
   │  • stops at the review gate   │
   └───────────────┬──────────────┘
                   │
                   ▼
   ┌──────────────────────────────┐
   │  Agent 2: Requirements        │  → requirements corpus
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
   │  Agent 3: QA Test Design      │  → test cases + estimate
   │  Architect                    │    + out-of-scope list
   │  • positive/negative/error/   │
   │    boundary cases             │
   │  • AC-to-test mapping         │
   │  • scope control (no bloat)   │
   │  • automation-ready, STE      │
   └───────────────┬──────────────┘
                   │
                   ▼
   ┌──────────────────────────────┐
   │  Human review                 │  accept / cut / refine
   │  → optional push to Qase      │  (separate, confirmed step)
   └──────────────────────────────┘
```

### Design decisions worth noting

- **Separation of concerns.** The researcher *only extracts* and the architect *only
  designs*. Keeping gathering and interpretation apart preserves the source of truth and
  makes hallucinated requirements far less likely.
- **Scope control.** An LLM tends to test *everything adjacent* to a change, which inflates
  estimates. Agent 3 is instructed to test the change itself and push everything else into
  an explicit `[OUT OF SCOPE — engineer decides]` list.
- **Gaps as a first-class output.** Contradictions and missing docs are reported, not
  silently resolved — often the most valuable result, because they surface before code is
  written.
- **Human-in-the-loop.** The pipeline never writes to Jira/Confluence/Qase. A person
  reviews first.
- **Automation-ready output.** Cases use atomic steps, explicit test data, assertable
  results, and ASD-STE100 Simplified Technical English, so they convert cleanly into
  automated tests.

## Repository layout

```
ai-qa-agents/
├─ .claude/
│  ├─ agents/
│  │  ├─ requirements-researcher.md   # Agent 2
│  │  └─ qa-test-architect.md         # Agent 3
│  ├─ commands/
│  │  ├─ prep-testing.md              # Agent 1 (coordinator)
│  │  └─ push-to-qase.md              # reviewed cases → Qase (dry-run by default)
│  └─ skills/                         # self-contained data-access skills
│     ├─ jira/                        # Jira REST via ~/.netrc (fallback path)
│     ├─ confluence/                  # Confluence REST via ~/.netrc
│     └─ investigate/                 # one-pass ticket context pull
├─ fixtures/                          # demo mode: synthetic tickets
│  └─ DEMO-123/                       # sample ticket + Epic + PRODUCT idea + RFC
├─ config/
│  └─ sources.json                    # demo | real switch
├─ .mcp.json                          # Qase + Atlassian MCP servers
├─ .env.example                       # QASE_API_TOKEN template (copy to .env)
├─ output/                            # generated reports land here (gitignored)
├─ docs/
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

On first launch Claude Code asks you to approve the MCP servers — accept them.

## Usage

```bash
cd ai-qa-agents
claude
```

Then, inside Claude Code:

```
/prep-testing DEMO-123
```

The pipeline produces `output/DEMO-123-test-prep.md` and shows it for review. It stops
there — nothing is pushed anywhere.

**Fast mode** for small tickets (Happy Path only):

```
/prep-testing DEMO-123 --positive
```

### Real tickets and pushing to Qase

On a real ticket, the coordinator gathers context from Jira/Confluence (via Claude Code
skills) and the pipeline works the same way, stopping at the review gate:

```
/prep-testing TS-1234 --mode=real
```

After you review `output/TS-1234-test-prep.md` and cut anything you do not want, push the
accepted cases into Qase. This step is **dry-run by default** and writes only with
`--confirm`:

```
/push-to-qase TS-1234            # shows what would be created — writes nothing
/push-to-qase TS-1234 --confirm  # creates the cases in Qase after your review
```

`[OUT OF SCOPE]` items and unconfirmed `[ASSUMPTION]` cases are never pushed. The created
Qase cases can then be turned into automated tests, closing the loop
**Jira → test docs → Qase → automated tests**.

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

Working proof of concept. See `docs/` for notes. Roadmap: push-to-Qase step behind the
review gate; regression-coverage analysis; a thin SDK/CLI wrapper.
