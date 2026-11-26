# Stack profile — API, Mocha + Chai + superagent (JavaScript, ESM)

Target repo: `xp-test-api` · config key `api-mocha` in `config/targets.json`.

There is **no WebdriverIO in this repo**. API tests are Mocha specs asserting with Chai on
responses returned by the shared client in `utils/api-client.js` (superagent underneath).

## Five API areas

`external` · `mobile` · `rest` · `mxa` · `gamification`

The area decides every path: `api/<area>/…`, `tests/<area>/…`,
`utils/helpers/<area>/…`, and the npm script (`npm run test:rest`). Determine the area from
the ticket before writing anything. If the ticket does not say, use `/find-endpoint` in the
target repo to locate the route in `xp-web-application` (XP) or `maxautomation-xp` (MXA).

## Files to touch for one feature

| Layer | Path | Always needed? |
|---|---|---|
| Spec | `tests/<area>/<resource>.spec.js` | Yes |
| Spec (large resource) | `tests/<area>/<resource>/<action>.spec.js` | When one file per action is clearer |
| API module | `api/<area>/<resource>.js` | Only if the endpoint wrapper is missing |
| Helper | `utils/helpers/<area>/<resource>.js` | Only for setup/teardown reuse |
| Test data | `tests/data/<resource>.data.js` | Only for valid, reusable data |

## API module (endpoint wrapper)

One exported function per endpoint. Every call goes through `API.sendRequest`. Signature is
a single destructured object defaulting to `{}`.

```javascript
import * as urls from "#utils/urls.js";
import API from "#utils/api-client.js";

export async function createSegment({ headers, requestBody } = {}) {
	return await API.sendRequest({
		baseURL: urls.getRestUrl(),
		method: "POST",
		endpoint: `/projects/${process.env.PROJECTID}/segments`,
		headers,
		data: requestBody
	});
}
```

Rules:
- Base URL always from `#utils/urls.js` (`getRestUrl()`, and the equivalents per area) —
  never a literal URL.
- Query params and bodies both go in `data`.
- The module returns the raw response object. It does not assert and does not throw on a
  non-2xx status — negative tests need those responses.

## Spec

```javascript
import { expect } from "chai";
import { getRestAccessToken } from "#utils/get-token.js";
import * as bookmarks from "#api/rest/bookmarks.js";
import * as restHelpers from "#utils/helpers/rest/index.js";
import { getRandomNumber } from "#utils/random-utils.js";

// Global variables
let response;
let bookmarkId;

const headers = { Authorization: `Bearer ${await getRestAccessToken()}` };

const bookmarkName = "QA Automation Bookmark";
const contentId = getRandomNumber();

describe("Bookmarks Endpoints", function () {
	describe("POST /bookmarks", function () {
		describe("successfully creates a bookmark", function () {
			before(async function () {
				response = await bookmarks.createBookmark({ headers, requestBody: { name: bookmarkName, position: 1 } });
				bookmarkId = response.body.id;
			});
			after(async function () {
				await restHelpers.bookmarks.deleteBookmark({ bookmarkId });
			});
			it("returns the expected 'statusCode' of 201", function () {
				expect(response).to.have.property("statusCode", 201);
			});
			it("returns a valid 'name' property", function () {
				expect(response.body).to.have.property("name", bookmarkName);
			});
		});
	});
});
```

Structure, exactly as above:
- Three `describe` levels: resource (`"Bookmarks Endpoints"`) → endpoint
  (`"POST /bookmarks"`) → scenario (`"successfully creates a bookmark"`,
  `"missing 'name' property"`).
- `function () {}` for `describe`/`it` (not arrow functions — Mocha context).
- **The request happens once in `before`**, the response is stored in a module-level `let`,
  and each `it` asserts on one property of that stored response. Do not send a request from
  inside an `it`.
- One assertion subject per `it`. Title format:
  `returns the expected 'statusCode' of 201`, `returns a valid '<field>' property`.
- Cleanup in `after` via a helper.
- Do not put the project or project ID in a `describe` title; do not repeat the full URL.
- Auth: top-level `await getRestAccessToken()` into a `headers` const. Other areas use
  their own token getter (`externalHeaders` / `mxaHeaders` come from
  `utils/root-hooks.js`).
- Security-relevant tests carry `@security` in the test name so `npm run test:security`
  picks them up.

## Helper

`utils/helpers/<area>/<resource>.js`, re-exported from that area's `index.js`. Same
contract as the UI repo: validate params, call the api module, throw on an unexpected
status, return the useful part. Helpers are for setup/teardown and cross-spec reuse — the
assertions stay in the spec.

## Test data

`tests/data/` holds only **valid** reusable data. Invalid/negative payloads are passed
inline at the call site — that is an explicit repo convention.

Prefer per-run-unique values (`getRandomNumber()` from `#utils/random-utils.js`) so
parallel runs do not collide.

## Definition of done

1. `npm run test -- ./tests/<area>/<resource>.spec.js` passes locally (90s default timeout).
2. `npm run lint:fix && npm run format:fix` run clean.
3. Tabs, tab width 4, print width 100. **Inside a `describe`, no blank lines between
   `before` / `after` / `it` blocks** — this repo's style is dense. Blank lines are used only
   to separate the file preamble (imports · global `let`s · consts · the root `describe`).
4. No secrets. Tokens come from the token getters, never literals.
5. If the run needs isolation, `USE_SYNTHETIC_PROJECT=true` spins up and tears down a
   throwaway project (see `utils/synthetic-project-manager.js`).
