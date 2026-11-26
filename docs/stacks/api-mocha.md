# Stack profile — API, Mocha + Chai + superagent (JavaScript, ESM)

Target repo: `xp-test-api` · config key `api-mocha` in `config/targets.json`.

**This profile is a map, not a rulebook.** It tells you where things live and which of the
target repo's own documents to read. The conventions themselves live in that repo and are the
single source of truth. Do not copy them back in here — a copy goes stale within one
refactor.

There is **no WebdriverIO in this repo.** API tests are Mocha specs asserting with Chai on
responses returned by the shared client in `utils/api-client.js` (superagent underneath).

## Read these first, in the target repo

| Document | What it settles |
|---|---|
| `CLAUDE.md` | Repo overview, the five API areas, env vars, auth flows, npm scripts |
| `docs/test-design.md` | How a spec is structured top to bottom: imports, `before`/`after`, skip conditions, shortcuts |
| `docs/api-client-architecture.md` | How a request flows spec → `api/` → `utils/helpers/` → `api-client.js`, and the five token flows |
| `docs/naming.md` | Files, `describe`/`it` titles, function and variable names |
| `docs/assertions.md` | `expect()` conventions, status codes per API type, error-message policy, skip patterns |
| `docs/test-data.md` | What belongs in `tests/data/`, fixture reuse, randomisation |
| `docs/review-checklist.md` | **The acceptance bar.** Your code is reviewed against this — read it before writing, not after |

Where this profile and those documents disagree, **the target repo wins**. Report the
disagreement so this profile gets fixed.

## Pick the API area first

`external` · `mobile` · `rest` · `mxa` · `gamification`

The area decides every path (`api/<area>/`, `tests/<area>/`, `utils/helpers/<area>/`) and the
npm script (`npm run test:rest`). Determine it from the ticket before writing anything. If
the ticket does not say, use `/find-endpoint` to locate the route in `xp-web-application` (XP)
or `maxautomation-xp` (MXA).

Each area also has its own auth: REST uses a bearer token from `getRestAccessToken()`,
External uses the OAuth flow via `externalHeaders`, MXA uses `mxaHeaders` — both set up in
`utils/root-hooks.js`. `docs/api-client-architecture.md` has the full picture; never mint a
token by hand in a spec.

## Where things go

| Layer | Path | Always needed? |
|---|---|---|
| Spec | `tests/<area>/<resource>.spec.js` | Yes |
| Spec (large resource) | `tests/<area>/<resource>/<action>.spec.js` | When one file per action is clearer |
| API module | `api/<area>/<resource>.js` | Only if the endpoint wrapper is missing |
| Helper | `utils/helpers/<area>/<resource>.js` | Only for setup/teardown reuse |
| Helper barrel | `utils/helpers/<area>/index.js` | When adding a helper file |
| Test data | `tests/data/<resource>.data.js` | Only for valid, reusable data |

Path aliases from `package.json` → `imports`: `#utils/*` → `./utils/*`, `#api/*` → `./api/*`,
`#data/*` → `./tests/data/*`.

Nothing calls `API.sendRequest` directly from a spec — a new endpoint gets its own function in
`api/<area>/`. A spec calls `api/` only for the endpoint actually under test; setup and
teardown go through a helper.

## Reuse before you create

1. **The endpoint wrapper** — check `api/<area>/` before adding one.
2. **The helper** — check that area's `index.js`; most resources are covered.
   `utils/shortcuts.js` has cross-helper setups (`createAndActivateApplication`,
   `checkSkipConditions`).
3. **An existing data-driven loop** — before adding a new spec or variant, check whether an
   existing loop covers it by adding one data entry.
4. **Utilities** — `utils/dates.js`, `utils/random-utils.js`, `utils/response-parser.js`,
   `utils/parameter-validator.js`.

State in your report what you reused.

## Read two neighbours

Read the closest existing spec in the same area before writing, plus its helper and api
module. Match their shape — some conventions exist only as precedent in sibling files,
notably how a nested sub-resource endpoint is filed.

Three things the structure hangs on (the rest is in `docs/test-design.md`):

- **Three `describe` levels:** resource → endpoint (`"POST /bookmarks"`) → scenario
  (`"successfully creates a bookmark"`, `"missing 'name' property"`). No project or project ID
  in a title, no full URL.
- **The request happens once in `before`**, the response is stored, and each `it` asserts on
  one property of it. Never send a request from inside an `it`. Never assert inside `before`.
- `function () {}` for `describe`/`it`, not arrow functions — Mocha context.

Security-relevant tests carry `@security` in the test name so `npm run test:security` picks
them up.

## Definition of done

1. `npm run test -- ./tests/<area>/<resource>.spec.js` passes locally (270s default timeout).
2. `npm run lint:fix && npm run format:fix` run clean.
3. Tabs, tab width 4. **Inside a `describe`, no blank lines between `before` / `after` / `it`
   blocks** — this repo's style is dense. Blank lines only separate the file preamble
   (imports · global `let`s · consts · the root `describe`).
4. Every resource created in `before` is cleaned up in `after`, guarded by an
   `if (resourceId) { ... }` check, through the helper layer rather than a raw `api/` call.
5. No secrets. Tokens come from the token getters, never literals.
6. No feature flag toggled inside a spec — flags are enabled in `utils/feature-flag-setup.js`
   and the spec skips if the flag is off.
7. If the run needs isolation, `USE_SYNTHETIC_PROJECT=true` spins up and tears down a
   throwaway project (`utils/synthetic-project-manager.js`).
8. Your diff survives a read of `docs/review-checklist.md`, item by item.
