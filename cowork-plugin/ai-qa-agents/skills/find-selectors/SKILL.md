---
name: find-selectors
description: Finds reliable Playwright selectors for UI elements on a live Xtremepush dashboard page and returns them as page-object properties in the UI test repo's naming style. Use for "/find-selectors with a URL and element", "find a selector for the save button", "get data-qa selectors for this page".
argument-hint: url-or-page-name [element description]
---

> **Cowork notes (apply before the steps below).** Read `../../shared/cowork-environment.md`
> §6 and §7. The UI repo (`ui-playwright` root in `targets.json`) must be a connected folder;
> read and grep it with `device_bash`. In Step 1, drive the browser with the Playwright
> plugin's browser tools if present, otherwise the built-in browser — the target repo's
> `playwright-cli` skill is not available here. Never type credentials without asking.
> Adding properties to a page file happens with `device_bash` in place, only after the user
> says yes.


# Find Selectors

Find reliable selectors for UI elements and return them formatted as page object properties
matching the conventions of the target repo.

This is the selector-discovery helper for Phase 3. Use it whenever the test-implementer needs
a selector that no existing page object provides — **never guess one, and never derive one
from visible text.**

## Setup

Read `config/targets.json` → `targets["ui-playwright"]` for `root`, `authState`, and
`layout.pageObject` / `layout.sharedComponents`. Read the target's own selector guidance (its
`CLAUDE.md`, and its `/find-ui-selectors` command if present) — that repo owns these
conventions. All paths below are relative to the target repo `root`.

## Step 0 — Check it is not already solved

Two checks before touching a browser. Both save the whole exercise.

1. **An existing page object.** Grep `pages/` for the element or its page. If a locator for it
   already exists, return that and stop.
2. **A shared component** in `pages/components/`. The repo factors recurring widgets out, and
   re-declaring a duplicate locator for one is a review finding:
   - `dashboard-iframe.ts` → `DASHBOARD_IFRAME`, the iframe selector constant.
   - `iframe-table.component.ts` / `table.component.ts` → table rows, column headers, row
     action menus, options menus. A row action menu or options menu is driven through the
     component, not through a hand-rolled trigger click.
   - `iframe-toast.ts` → `getSuccessToast(frame)`.
   - `label.component.ts`, `notification-bell.ts`.

Only continue when the element is genuinely new.

## Step 1 — Launch and navigate

**Preferred driver: the `playwright-cli` skill** in the target repo. It runs headless and is
far cheaper on context than MCP tool schemas, which matters because selector hunting is
snapshot-heavy. Fall back to the Playwright MCP server when you need its structured output or
`playwright-cli` is unavailable.

1. Open a session and navigate to the target URL. Given a page name rather than a URL, derive
   it from the `open()` methods of existing page objects in `pages/` and `baseURL` in
   `playwright.config.ts`.
2. Authentication is already solved: load the stored state from `.auth/user.json`. Only fall
   back to `EMAIL` / `PASSWORD` from `.env` if that file is missing or expired.
3. Most of the dashboard renders inside an iframe. Use the `DASHBOARD_IFRAME` constant from
   `#components/dashboard-iframe` rather than hardcoding an iframe selector, and remember that
   Element Plus portals (dropdown option lists, shared action menus) render **inside the
   iframe document**.

## Step 2 — Inspect

Take a snapshot first (a screenshot only when you need the visual).

**Specific element:** locate it by label, role, or visible text in the accessibility snapshot,
then **inspect its real attributes** to choose the selector. Locating by text is fine; shipping
text in the selector is not.

**All elements:** accessibility snapshot, then query `[data-qa]`, then
`input, button, select, textarea, [role='button'], [role='tab'], [role='combobox']` for
anything missed.

## Step 3 — Build the selector

Priority order:

1. `[data-qa='...']` — always prefer when present
2. `[name='...']` or `[id='...']` — form fields without data-qa
3. A unique, stable CSS class — never generated/hashed
4. **One parent class + one element class**, when a single class is not unique.
   `.el-button--primary` matches every primary button on the page; `.controls .el-button` may
   be unique. Keep it to one parent plus one element — if that is still not unique, use the
   filter pattern below rather than a longer chain.
5. `[aria-label='...']` — icon buttons and unlabelled controls
6. `[placeholder='...']` — text inputs with nothing better

**Why text is banned for static UI.** `getByRole('button', { name: 'Save' })`,
`getByText(...)` and friends break the moment the app runs in another locale: the text is
translated, the selector matches nothing, and the failure looks like a timeout rather than a
naming problem. That is why this rule is absolute for buttons, tabs, labels and menu items,
and why the fix for a textless element is a `data-qa` request to dev, not a text fallback.

**The one exception:** filtering a collection down to an item identified by data the test
itself created, or by a known fixed value. There the text identifies *which* item, not the
control. Use `.filter({ hasText })` on a broader locator instead of chaining combinators:

```typescript
// In constructor:
this.tableRows = this.frame.locator(".el-table__row");

// Helper method:
getRowByName(name: string): Locator {
	return this.tableRows.filter({ hasText: name });
}
```

For a shared-portal action list, also filter by visibility — several copies exist in the DOM:
`.filter({ visible: true })`.

If the only thing that identifies a static element is its visible text, **do not provide a
selector.** Flag it and recommend requesting a `data-qa` attribute from dev.

## Step 4 — Name the properties

Follow the target repo's `docs/naming.md`. The essentials:

- camelCase.
- Clickable actions end in **`Btn`** — never `Button`, which the review checklist rejects.
- Other elements end in the type: `Input`, `Dropdown`, `Checkbox`, `Table`, `Tab`, `Modal`,
  `Toast`, `Title`.
- Plural for collections: `tableRows`.
- Examples: `campaignNameInput`, `deleteBtn`, `channelIosPushCheckbox`, `tableRows`.

## Step 5 — Output

Return `readonly` class-level declarations plus constructor assignments, grouped logically
(navigation/tabs, then form fields, then actions, then table elements), and state for each
whether it is scoped to `this.frame` or `page`.

```typescript
// Class-level declarations
readonly nameInput: Locator;
readonly saveBtn: Locator;
readonly tableRows: Locator;

// Constructor assignments
// Form fields (frame-scoped)
this.nameInput = this.frame.locator("[data-qa='name-input']");

// Actions (frame-scoped)
this.saveBtn = this.frame.locator("[data-qa='save-button']");

// Table (frame-scoped)
this.tableRows = this.frame.locator(".el-table__row");
```

Then ask:

1. **"Add this to a page file?"** If yes, list the files in `pages/` to choose from, or take a
   new filename. Insert the declarations into the class body and the assignments into the
   constructor, in the right logical group. Change nothing else.
2. **"Find more elements, or close the browser?"** If more, stay on the page or navigate as
   directed without relaunching.

## Notes

- Skip decorative/layout elements with no interaction role.
- If the page has several distinct sections or tabs, say so and ask which one.
- An element with no reliable unique selector is a finding, not a guess. Report it, and list it
  as a `data-qa` follow-up for dev.
- Close the session when done.
