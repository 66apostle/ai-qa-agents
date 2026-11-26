# Stack profile — UI, Playwright (TypeScript)

Target repo: `xp-test-ui` · config key `ui-playwright` in `config/targets.json`.

**This profile is a map, not a rulebook.** It tells you where things live and which of the
target repo's own documents to read. The conventions themselves live in that repo, are
maintained by the team that owns it, and are the single source of truth. Earlier versions of
this profile copied those conventions here, and the copy went stale within one refactor — do
not reintroduce that. If a convention needs changing, it changes in the target repo.

## Read these first, in the target repo

Read them in this order before writing anything. They are short.

| Document | What it settles |
|---|---|
| `CLAUDE.md` | Repo overview, commands, directory structure, selector basics |
| `docs/ui-architecture.md` | How a spec flows through fixtures → page objects → DOM; iframe handling; API helpers for setup/teardown; spec structure |
| `docs/naming.md` | Files, classes, locator properties, `describe`/`test` titles, variables |
| `docs/assertions.md` | Matcher conventions, error-message policy, toast policy, skip patterns |
| `docs/test-data.md` | What belongs in `data/`, fixture reuse, randomisation |
| `docs/review-checklist.md` | **The acceptance bar.** Your code is reviewed against this — read it before writing, not after |

Where this profile and those documents disagree, **the target repo wins**. Report the
disagreement so this profile gets fixed.

## Where things go

Verified against the repo layout. If a path here does not exist, trust the repo and flag it.

| Layer | Path | Always needed? |
|---|---|---|
| Page object | `pages/<feature>.page.ts` | Yes |
| Spec | `tests/<feature>.spec.ts` (or `tests/<area>/<feature>.spec.ts`) | Yes |
| Shared UI component | `pages/components/*.ts` | Reuse, rarely add |
| Test data | `data/<feature>.data.ts` | Only for fixed valid values |
| Fixture registration | `fixtures.ts` (repo root) | Yes — register the page object |
| API helper | `utils/helpers/<feature>.ts` | Only for setup/teardown |
| Helper barrel | `utils/helpers/index.ts` | When adding a helper file |
| API module | `api/rest/<resource>.ts` | Only if the endpoint wrapper is missing |

The repo is **TypeScript-native throughout** — specs, page objects, data, helpers, and the
api/utils layer are all `.ts`. Import local modules without an extension (`#utils/get-token`,
not `#utils/get-token.js`).

Path aliases from `package.json` → `imports`, use them instead of relative paths:

```
#pages/*      ./pages/*
#components/* ./pages/components/*
#data/*       ./data/*
#api/*        ./api/*
#utils/*      ./utils/*
#fixtures     ./fixtures.ts
```

Never put a selector in a spec. Never write a pure API test here — that belongs in
`xp-test-api`.

## Reuse before you create

The repo already solves most of what a new spec needs. Check in this order:

1. **Shared components** — `pages/components/`:
   - `dashboard-iframe.ts` → `DASHBOARD_IFRAME`, the iframe selector constant. Use it;
     do not hardcode an iframe selector.
   - `iframe-table.component.ts` / `table.component.ts` → table rows, column headers, row
     action menus, options menus.
   - `iframe-toast.ts` → `getSuccessToast(frame)`.
   - `label.component.ts`, `notification-bell.ts`.
2. **An existing page object** for the page you need — extend it rather than adding a second
   class for the same page. One page object can serve several specs.
3. **An existing API helper** — read `utils/helpers/index.ts` first; most resources are
   already covered. `utils/shortcuts.ts` has composed multi-step setups.
4. **An existing data fixture** in `data/` — override fields rather than hand-writing a new
   object.

State in your report what you reused.

## Read two neighbours

Before writing, read the closest existing example of each file you are about to create. A
good triple to start from: `tests/gateways.spec.ts`, `pages/gateways.page.ts`,
`data/gateways.data.ts`. Match their shape — not every convention is written down; some of it
only exists as precedent in sibling files.

Shape at a glance (details are in the repo's docs):

```typescript
// tests/<feature>.spec.ts
import { test, expect } from "#fixtures";
import * as helpers from "#utils/helpers/index";

// Data
import { gateways } from "#data/gateways.data";

test.describe("Settings > Gateways", () => { /* ... */ });
```

```typescript
// pages/<feature>.page.ts
import { type Page, type FrameLocator, type Locator } from "@playwright/test";
import { DASHBOARD_IFRAME } from "#components/dashboard-iframe";
import { IframeTableComponent } from "#components/iframe-table.component";
import { getSuccessToast } from "#components/iframe-toast";

export class GatewaysPage {
	private frame: FrameLocator;
	readonly table: IframeTableComponent;
	readonly saveBtn: Locator;

	constructor(private page: Page) {
		this.frame = page.frameLocator(DASHBOARD_IFRAME);
		this.table = new IframeTableComponent(this.frame);
		this.saveBtn = this.frame.locator("[data-qa='save-button']");
	}
}
```

Two things the docs assume you already know:

- **Clickable locators end in `Btn`, never `Button`** (the checklist rejects `...Button`).
- **Element Plus dropdown option lists** (`.el-select-dropdown__item`) render as portals
  inside the iframe document — scope them to `this.frame`, and filter shared-portal items
  with `.filter({ visible: true })`.

## Fixtures and auth

Register each page object in `fixtures.ts`, alphabetically, in both the type block and the
implementation block. If a page must be open and settled before the test body, do that in the
fixture (`open()` plus a `waitFor()` on a landmark element).

Authentication is already solved: the `setup` project runs `tests/auth.setup.ts`, and the
`chromium` project loads `storageState` from `./.auth/user.json`. **Never write a login step
into a feature spec.**

`fullyParallel` is `false` — tests within a file run in order. Still keep each test
independent enough to run alone.

## Selectors

Priority order and the full rationale are in the repo's `CLAUDE.md` and in its
`/find-ui-selectors` command. The short version:

1. `[data-qa='...']` — always prefer
2. `[name='...']` / `[id='...']` — form fields without data-qa
3. A unique, stable CSS class (never generated/hashed)
4. One parent class + one element class, when a single class is not unique
5. `[aria-label='...']` — icon buttons, unlabelled controls
6. `[placeholder='...']` — text inputs with nothing better

**Never select static UI chrome by its visible text** — `getByRole('button', { name })`,
`getByText(...)`. That text is translated in other locales and the selector silently stops
matching. Text may locate an element while you inspect it, but must not survive into the
selector.

The one exception: filtering a collection down to an item identified by data the test itself
created, or by a known fixed value — `tableRows.filter({ hasText: name })`. Prefer that over
a long chain of descendant combinators.

To get real values rather than guesses: read them from an existing page object, or run
`/find-selectors <url> <element>` from this repo. If no stable selector exists for a required
static element, **do not invent one** — flag it and recommend requesting a `data-qa` attribute
from dev.

## Definition of done

1. `npx playwright test tests/<feature>.spec.ts` passes locally.
2. `npm run lint:fix`, `npm run format:fix`, and `npm run type:check` all run clean.
   **`type:check` is not optional here** — the PR pipeline runs `tsc --noEmit`.
3. Tabs, tab width 4 (Prettier config in repo).
4. No `.only`. No skipped test without a reason string and the
   `// eslint-disable-next-line playwright/no-skipped-test` comment immediately above.
5. No secrets, no hardcoded environment URLs — `baseURL` comes from `playwright.config.ts`.
6. No comment referencing the current ticket number ("see XP-1234") — that belongs in the PR
   description, since it rots once the ticket closes.
7. Your diff survives a read of `docs/review-checklist.md`, item by item.
