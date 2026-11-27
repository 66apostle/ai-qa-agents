---
name: find-endpoint
description: Finds an API endpoint definition in the Xtremepush application source (XP xp-web-application or MXA maxautomation-xp) and returns its method, URL, required/optional params and prerequisites. Use for "/find-endpoint campaigns/{id}/snapshot", "what params does this endpoint take", "where is this route defined".
argument-hint: endpoint-name-or-pattern
---

> **Cowork notes (apply before the steps below).** Read `../../shared/cowork-environment.md`
> §6 and §7. The application repos must be connected folders: request access to the one(s)
> needed (siblings of the `api-mocha` root in `targets.json`; ask for paths if not there) and
> search them with `grep -rn` in `device_bash`. `docs/stacks/api-mocha.md` means
> `../../shared/stacks/api-mocha.md`.


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
