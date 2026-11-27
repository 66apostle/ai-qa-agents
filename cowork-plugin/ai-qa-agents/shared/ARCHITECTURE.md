# Architecture notes

## Pipeline stages

| Stage | Component | Input | Output | Guarantee |
|---|---|---|---|---|
| — | `qa-flow` command (Coordinator) | ticket ID, mode, target | orchestration + gates | Never writes to external systems; never commits |
| 1 | `requirements-researcher` agent | ticket ID, mode | requirements corpus | Extracts only; marks GAP/CONFLICT; never invents |
| 2 | `qa-test-architect` agent | requirements corpus | test cases, AC map, estimate, out-of-scope | Automation-ready, STE, sized for a regression suite |
| — | **Gate 1** — human review | full report | accepted cases | Hard stop before Qase push or any code |
| 3 | `test-implementer` agent | accepted cases + target key | test code in the target repo, run results | Follows the target repo's conventions; never weakens an assertion |
| 3.5 | `test-reviewer` agent | the Phase 3 diff + accepted cases | findings: blocking / worth fixing / questions | Reports against the target repo's own checklist; never fixes unasked |
| — | **Gate 2** — human review | unstaged diff + findings | committed tests | Hard stop; the human commits |

`prep-testing` remains as a narrower entry point covering stages 1–2 only, for when the
deliverable is documentation rather than code.

## Why separate agents instead of one prompt

A single mega-prompt mixes gathering, interpretation, design, and implementation, which makes
it easy for the model to blur the source of truth and invent requirements. Splitting the
roles:

- **isolates extraction from design** — the researcher cannot "helpfully" rewrite a
  requirement it is only supposed to quote;
- **isolates design from implementation** — the implementer receives cases as fixed scope, so
  it cannot quietly substitute tests that are easier to automate for the ones that were
  approved;
- **makes each stage independently reviewable** — the corpus can be checked before any test
  case is written, and the cases before any code;
- **mirrors how a QA engineer actually works** — first understand, then design, then automate.

## Why stack profiles

Phase 3 could have been a prompt describing a framework. It is not, for two reasons.

**Framework knowledge is not repo knowledge.** Generic Playwright advice produces code that
passes review nowhere: it misses that pages here live behind an iframe, that page objects
expose `readonly` locators assigned in the constructor, that fixtures pre-open the page, that
setup goes through API helpers re-exported from an index file. A profile in `docs/stacks/`
carries that local knowledge.

**But a profile must not own the conventions.** The first version of each profile copied the
target repo's naming, assertion and layout rules in full, and instructed the implementer to
trust the copy over the repo's own `CLAUDE.md` — which was correct at the time, because those
files lagged behind a migration in progress. Both halves then rotted: the repos documented
their conventions properly in `docs/`, and the UI repo moved its tests, went
TypeScript-native and renamed its locator suffix, while the profile still described the old
layout. An agent following it would have written code that no longer compiles against the
repo.

So the profile is now a **map**: where files go, how to run them, and which of the target
repo's documents (`conventionDocs`, `reviewChecklist` in `config/targets.json`) define the
rules. Precedence is inverted — the repo's docs and its actual code win, and profile drift is
a finding the implementer has to report. Conventions live with the team that maintains them;
this repo keeps only the navigation.

**A hardcoded stack rots.** The first draft of this phase assumed "Playwright for UI,
WebdriverIO for API." Neither half was true: WDIO was the *UI* framework being ported away
from, and the API repo runs Mocha + Chai + superagent. Moving the stack description into data
(`config/targets.json`) plus documents means correcting a wrong assumption is an edit to a
profile, and adding a stack is a new file — neither touches the agent.

Targets carry a `status`. A `legacy-read-only` target (`ui-wdio`) is readable for reference
but refuses generation, so the pipeline cannot add tests to a suite that is being deleted.

## Why a separate review phase

Phase 3 already self-checks before reporting, so Phase 3.5 looks redundant until you ask what
each one can see.

The implementer checks **its own intent**: did I do what I set out to do, did I weaken
anything, did I run the suite after my last edit. That catches shortcuts, and it is why those
checks stay. What it cannot do is judge its own output against a standard it just spent an
hour internalising — the same context that produced the code is the worst place to evaluate it.
A test that is self-consistent, passes, and follows every rule the agent remembers can still
be the wrong test.

So the reviewer starts from the other end: from the target repo's `docs/review-checklist.md`
and the approved cases, not from the code. Three things only it can catch:

- **An assertion bent to match the application.** When the app and an approved case disagree,
  that is a bug or a defective case, and a human decides which. An implementer that adjusts
  the expectation produces a green suite and destroys the finding. The reviewer compares code
  back to cases, so the adjustment shows up as a discrepancy rather than a success.
- **A test not worth having.** Duplicated coverage, a success assertion on state that was
  already true before the action ran, expected values derived by re-implementing the logic
  under test. Each passes, each proves nothing.
- **Scope creep.** Extra tests invented during implementation are not in the approved set and
  need a human decision even when they are good.

It also pays for itself outside the pipeline: `/review-tests` runs standalone on a hand-written
branch or a colleague's PR, because the checklist it applies belongs to the repo, not to this
project.

Two guarantees keep it honest. It **reports and does not fix** unless asked, so a judgement
call reaches the human instead of being quietly resolved. And the coordinator may hand
mechanical findings back to the implementer **once** — a second round of findings means the
human should be looking, not the loop.

## Provenance of Phase 3

`test-implementer` descends from an earlier standalone prompt (`sdet_playwright_wdio_agent`,
kept as a note for the record). Two of its cognitive methods carried over, two did not.

**Kept — Reflexion (Step 6).** The failure loop is Observe → Analyze → Reflect → Adapt. The
*Reflect* move is the one that earns its place: from the second attempt onwards the agent must
name what its previous hypothesis assumed and what the new evidence disproves. Without it, a
model retries variations of the same guess and then reports "flaky". Two attempts in the same
category with no new evidence is defined as a wrong category, not a reason for a third try.

**Kept — Chain of Verification (Step 7).** A thirteen-question self-check, each question paired
with a command or a file read that produces evidence, run before the report. It exists because
the failure mode of an implementation agent is not writing bad code — it is *claiming* the
suite passes when the last edit came after the last run, or quietly relaxing a matcher. The
checks that specifically hunt the agent's own shortcuts (grep the diff for widened matchers,
raised timeouts, `.skip`, invented selectors) matter more than the ones that confirm success.

**Dropped — explicit `<thinking>` blocks (CoT).** Chain of thought survives as *procedure*
rather than markup: read two neighbouring files before writing, build the case→test table
before coding, diagnose before editing. Claude Code reasons without being told to emit
reasoning tags, and the tags would only pollute a subagent's return value, which is consumed
as data by the coordinator.

**Dropped — the OpenHands framing.** Observation/Action/State-loop described that runtime's
event architecture. Here the harness already provides the loop; restating it in the prompt
added words, not behaviour.

The dropped "Senior SDET" role framing is a separate, deliberate choice: the prompt sets a
quality bar without making a seniority claim (same note as on `qa-test-architect`).

The original prompt also asserted a stack that did not exist — "Playwright for UI,
WebdriverIO for API" — when the API repo runs Mocha and WDIO was the UI framework being
retired. That error is why Phase 3 keeps stack knowledge in profiles derived from real code
rather than in the agent's prompt.

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
| Live UI (selectors) | `playwright` MCP (`/find-selectors`) | read existing page objects | target repo's stored auth state |
| Application source (routes) | filesystem grep (`/find-endpoint`) | — | local clones, read-only |

MCP is preferred for uniformity with the Qase write step. The bundled skills make the repo
work even where the Atlassian MCP server is not approved/authenticated (e.g. headless runs)
— they call the REST API directly with stdlib and `~/.netrc`.

## Security

- Least privilege: only sources reachable from the ticket are read; Phases 1–2 write
  nothing; `/push-to-qase` writes only with `--confirm`.
- **No secrets in git.** The real Qase token is injected via `${QASE_API_TOKEN}` from
  `.env` (gitignored). `.mcp.json` contains only the variable reference, never the value.
- `~/.netrc` and any exported real data (`output/`) are gitignored.
- Demo mode is fully synthetic and is the only mode intended for public presentation.

### Phase 3 blast radius

Phase 3 is the only stage that writes code, and it writes it **outside this repo** — into a
work repository. Constraints:

- **No VCS operations.** The implementer never stages, commits, pushes, or opens a pull
  request; it never touches CI config or unrelated tests. Gate 2 shows an unstaged diff and
  the human commits.
- **Feature-scoped writes only.** Files come from the target's `layout` in
  `config/targets.json`; anything else needs a reason stated in the report.
- **No secrets written into tests.** Credentials come from the target repo's existing
  mechanisms (token getters, `.env`, stored auth state); test data uses obvious dummies.
- **Confidentiality.** Real-mode reports in `output/` may quote internal tickets and stay
  gitignored. Generated tests live in the work repo and are never copied back here — the
  public artefact is the pipeline and the demo fixture, never real data.
- **Phase 3.5 is read-only** (`Read`, `Grep`, `Glob`, `Bash` for git inspection). It cannot
  edit the code it reviews, so a review can never silently become a rewrite. `--fix` on
  `/review-tests` is handled by the coordinator, for mechanical findings only.

## Roadmap

- Regression-coverage analysis for changed areas.
- A profile-drift check that compares `docs/stacks/` against each target repo on demand,
  rather than only when an agent trips over it.
- Bug-report drafting from failed runs.
- Additional target profiles as stacks appear.
- Optional thin SDK/CLI wrapper once the prompt logic stabilizes.
