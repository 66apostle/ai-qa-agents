# Stack profile — UI, Playwright (TypeScript)

Target repo: `xp-test-ui` · config key `ui-playwright` in `config/targets.json`.

This profile is derived from the code that is actually in the repo. Follow it over any
general Playwright advice, and over the repo's own `CLAUDE.md` where they disagree — that
file still describes the older WDIO layout (`utils/api/helpers/`, `wdio/tests/data/`) and
predates the Playwright migration.

## Files to touch for one feature

| Layer | Path | Always needed? |
|---|---|---|
| Page object | `playwright/pages/<feature>.page.ts` | Yes |
| Spec | `playwright/tests/<feature>.spec.ts` | Yes |
| Test data | `data/<feature>.data.ts` | Only if the spec needs fixed values |
| Fixture entry | `playwright/fixtures.ts` | Yes — register the page object |
| API helper | `utils/helpers/<feature>.js` | Only for setup/teardown |
| API module | `api/rest/<resource>.js` | Only if the endpoint wrapper is missing |

Never put a selector in a spec file. Never write a pure API test here — that belongs in
`xp-test-api`.

## Page object

Class per page. Locators are declared `readonly` at class level and assigned in the
constructor. The page instance is `private page` on the constructor. Most pages render
inside an iframe, so the page holds a `FrameLocator` and scopes locators to it.

```typescript
import { type Page, type FrameLocator, type Locator } from "@playwright/test";
import { type GatewayCredentials } from "#data/gateways.data";

export class GatewaysPage {
	private frame: FrameLocator;
	readonly successToast: Locator;
	readonly saveButton: Locator;
	readonly tableRows: Locator;

	constructor(private page: Page) {
		this.frame = page.frameLocator("iframe.h-full.w-full");
		this.successToast = this.frame.locator(".el-message--success");
		this.saveButton = this.frame.locator(".save-button");
		this.tableRows = this.frame.locator(".el-table__row");
	}

	async selectGateway(name: string) {
		await this.selectGatewayDropdown.click();
		await this.frame.locator(".el-select-dropdown__item").filter({ hasText: name }).click();
	}

	async open() {
		await this.page.goto(`/projects/${process.env.PROJECTID}/embed#/channel/config/index`);
	}
}
```

Rules:
- Every page object gets an `async open()` that `page.goto()`s its own URL. Embedded pages
  use the `/projects/${process.env.PROJECTID}/embed#/<route>` shape.
- Multi-step interactions become methods on the page object (`deleteGateway()`,
  `fillCredentials()`), so the spec reads as intent, not clicks.
- To reach one row/item, expose the collection locator and filter by text in a method —
  do not build a long descendant chain.
- The app is Vue + Element Plus. Dropdown option lists (`.el-select-dropdown__item`) render
  as portals **inside the iframe document** — scope them to `this.frame`, not `this.page`.

## Selector priority

1. `[data-qa='...']` — always prefer
2. `[name='...']` / `[id='...']` — form fields without data-qa
3. CSS class — only if unique and stable (never generated/hashed classes)
4. `[aria-label='...']` — icon buttons, unlabelled controls
5. `[placeholder='...']` — text inputs with nothing better

Visible text may locate an element while you inspect it, but must not end up in the final
selector. If nothing stable exists, do not invent a selector: flag the element and
recommend asking dev for a `data-qa` attribute.

To get real selectors instead of guessing, run `/find-selectors <url> <element description>`
from this repo. It drives a live browser through the Playwright MCP server and reuses the
target repo's `playwright/.auth/user.json`. (The target repo has its own equivalent,
`/find-ui-selectors-playwright`, if you are working inside it directly — same conventions.)

Naming: camelCase, suffixed with the element type — `campaignNameInput`, `deleteButton`,
`channelIosPushCheckbox`, plural for collections (`tableRows`).

## Fixtures

Register each page object in `playwright/fixtures.ts`, alphabetically. If a page must be
open and settled before the test body, do it in the fixture — `open()` plus a `waitFor()`
on a landmark element.

```typescript
retentionPage: async ({ page }, use) => {
	const p = new RetentionPage(page);
	await p.open();
	await p.policiesTab.waitFor();
	await use(p);
},
```

Specs import from the local fixtures module, never from `@playwright/test` directly:

```typescript
import { test, expect } from "../fixtures";
```

Authentication is already solved: the `setup` project runs `auth.setup.ts` and the
`chromium` project loads `storageState` from `playwright/.auth/user.json`. Do not write a
login step into a feature spec.

## Spec

```typescript
import { test, expect } from "../fixtures";
import * as helpers from "#utils/helpers/index";
import { gateways } from "#data/gateways.data";

test.describe("Settings > Gateways", () => {
	test.beforeAll(async () => { /* API setup */ });
	test.afterAll(async () => { /* API teardown */ });

	test("creates the gateway", async ({ gatewaysPage }) => {
		await gatewaysPage.addChannelConfigButton.click();
		await gatewaysPage.saveButton.click();
		await expect(gatewaysPage.successToast).toBeVisible();
	});
});
```

Rules:
- `describe` title mirrors the UI path (`"Settings > Gateways"`). Test titles are lowercase
  verb phrases (`"creates the gateway"`) and should map recognisably onto the Qase case.
- Web-first assertions only: `await expect(locator).toBeVisible()`, `.toHaveText()`,
  `.toHaveCount()`. Never `waitForTimeout`. Never assert on a value you read into a
  variable first when a locator assertion would do.
- Set up and tear down through API helpers, not through the UI.
- Data-driven cases use a `for (const x of data)` loop around `test.describe`.
- `fullyParallel` is `false` in this repo — tests within a file run in order. Still keep
  each test independent enough to run alone.

## API helpers (setup/teardown)

Helpers live in `utils/helpers/<feature>.js` (plain JS, ESM), are re-exported from
`utils/helpers/index.js` as `export * as camelCaseName from "./file.js";`, and are consumed
as `helpers.channelConfigs.getChannelConfig(...)`.

A helper takes a single destructured object, validates params, calls the `api/` wrapper,
throws on an unexpected status code, and returns the useful part of the body:

```javascript
import { getRestAccessToken } from "#utils/get-token.js";
import { validateParams } from "#utils/parameter-validator.js";
import * as channelConfigs from "#api/rest/channel-configs.js";

const headers = { Authorization: `Bearer ${await getRestAccessToken()}` };

export async function getChannelConfig({ channelConfig }) {
	validateParams({ channelConfig });
	const response = await channelConfigs.getChannelConfigs({ headers, queryParams: { channel: channelConfig } });
	if (response.statusCode !== 200) {
		throw new Error(`Error getting channel, status code: '${response.statusCode}'`);
	}
	return response.body.find((channel) => channel.channel === channelConfig) || null;
}
```

Create a helper only if setup/teardown genuinely needs it. Check `utils/helpers/index.js`
first — most resources are already covered.

## Test data

`data/<feature>.data.ts`. Export an `interface` for the shape plus named consts, and an
array when the spec iterates. Keep only valid data here; pass invalid data inline in the
negative test. Never commit real credentials — use obvious dummies
(`"dummy_password"`).

## Definition of done

1. `npx playwright test playwright/tests/<feature>.spec.ts` passes locally.
2. `npm run lint:fix && npm run format:fix` run clean.
3. Tabs for indentation, tab width 4 (Prettier config in repo).
4. No `.only`, no skipped test without a documented reason and an eslint-disable comment.
5. No secrets, no hardcoded environment URLs — `baseURL` comes from `playwright.config.ts`.
