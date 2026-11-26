---
name: find-endpoint
description: Find an API endpoint definition in the Xtremepush application source (XP or MXA) and return its method, URL, and required/optional params, plus what state must exist before calling it.
argument-hint: <endpoint-name-or-pattern>
user_invocable: true
---

# Find Endpoint

Search for an API endpoint definition across the `xp-web-application` (XP) and
`maxautomation-xp` (MXA) repos. Both are **PHP-based** — look for PHP routing patterns.

This is the endpoint-discovery helper for Phase 3 with the `api-mocha` target. Use it to
confirm a route and its parameters against the real source instead of inferring them from a
ticket.

## Locating the repos

Read `config/targets.json` → `targets["api-mocha"].root` for the API test repo. The two
application repos are siblings of that repo (one level up from it, under the same parent).
If they are not there, ask the user for their paths and stop.

## Instructions

1. **Ask which part of the system the endpoint belongs to** before searching:
   - **XP** — search `xp-web-application` only
   - **MXA** — search `maxautomation-xp` only
   - **Don't know** — search both in parallel

2. **Search** for route definitions matching the pattern. Common PHP routing patterns:
   - Laravel-style: `Route::get(`, `Route::post(`, `Route::patch(`, `Route::put(`,
     `Route::delete(`, `Route::any(`
   - Slim/other framework route registration
   - Controller method annotations
   - Any route registration whose URL string contains the search term

   Use the most specific segment of the given path (for
   `campaigns/{campaignId}/snapshot`, grep `campaigns/` and `snapshot` together, not
   `snapshot` alone). Then **discard results whose URL structure does not closely match the
   input** — drop hits where the surrounding path segments differ significantly.

3. **For each match**, read the surrounding handler/controller to extract:
   - the full endpoint URL (reconstructed with any route-group prefix)
   - HTTP method
   - required body properties / query params
   - optional body properties / query params

4. **Return a markdown table:**

   | Repo | Method | Endpoint URL | Required Params | Optional Params |

   One param per line within a cell:

   ```
   | xp-web-application | POST | /projects/{id}/campaigns | `name`<br>`type`<br>`status` | `description`<br>`tags` |
   ```

5. **Add a Testing Notes section** describing what must exist before the endpoint can be
   called successfully:
   - prerequisite resources (a campaign must exist before fetching its snapshot)
   - feature flags that must be enabled
   - required resource states (campaign must be `active`)
   - auth requirements beyond the standard bearer token

6. **If nothing is found**, advise the user to confirm the application repo is on `main` and
   has pulled the latest changes, then retry.

## Then

Map the result onto the `api-mocha` layout in `docs/stacks/api-mocha.md`: the area decides
`api/<area>/<resource>.js`, `tests/<area>/…`, and the npm script. Check whether the endpoint
wrapper already exists before writing a new one.
