---
name: find-selectors
description: Find reliable Playwright selectors for UI elements on a live page and return them as page object properties. Drives a real browser via the Playwright MCP server, reusing the target repo's stored auth state.
argument-hint: <url-or-page-name> [element description]
user_invocable: true
---

# Find Selectors

Find reliable selectors for UI elements and return them formatted as Playwright page object
properties matching the conventions of the target repo.

This is the selector-discovery helper for Phase 3 of the pipeline. Use it whenever the
test-implementer needs a selector that no existing page object provides — never guess one.

## Setup

Read `config/targets.json` → `targets["ui-playwright"]` for:
- `root` — the target repo path,
- `authState` — the stored auth state file,
- `layout.pageObject` — where page objects live.

Read `docs/stacks/ui-playwright.md` for the selector priority order and naming conventions.
Everything below assumes paths relative to the target repo `root`.

## Step 1 — Launch and navigate

1. Launch a Chrome session with the Playwright MCP browser tool.
2. Navigate to the target URL. If given a page name rather than a URL, derive it from the
   `open()` methods of the existing page objects in `<root>/playwright/pages/` and the
   `baseURL` in `<root>/playwright.config.ts`.
3. The app requires authentication. Use `<root>/playwright/.auth/user.json` as the stored
   auth state. Only fall back to logging in with `EMAIL` / `PASSWORD` from `<root>/.env` if
   that file is missing or the session has expired.
4. Many pages render inside an iFrame (`iframe.h-full.w-full`). After load, check for the
   iframe and switch into it if present.

## Step 2 — Inspect

Take a screenshot first for visual reference.

**Specific element:** use the accessibility snapshot to locate it by label, role, or visible
text; cross-reference the screenshot; then inspect its attributes to pick the best selector.

**All elements:** run the accessibility snapshot, query `[data-qa]`, then query
`input, button, select, textarea, [role='button'], [role='tab'], [role='combobox']` for
anything missed.

## Step 3 — Build selectors

Always inspect the element's real attributes (`data-qa`, `class`, `id`, `aria-label`,
`name`) before choosing. Visible text may be used to *locate* an element while inspecting,
but must never appear in the final selector.

Priority order:

1. `[data-qa='...']` — always prefer when present
2. `[name='...']` or `[id='...']` — form fields without data-qa
3. CSS class — only when unique and stable (never generated/hashed)
4. `[aria-label='...']` — icon buttons and unlabelled controls
5. `[placeholder='...']` — text inputs with nothing better

If the only option is visible text content, **do not provide a selector.** Flag the element
as lacking a reliable one and recommend requesting a `data-qa` attribute from dev.

Prefer short selectors. If no short selector is unique, do not chain combinators to force
uniqueness — return a broader locator plus a filtering helper method, the pattern used
throughout the repo:

```typescript
// In constructor:
this.tableRows = this.frame.locator(".el-table__row");

// Helper method:
async getRowByName(name: string): Promise<Locator> {
	return this.tableRows.filter({ hasText: name });
}
```

## Step 4 — Name the properties

- camelCase
- suffixed with the element type: `Button`, `Input`, `Dropdown`, `Checkbox`, `Table`, `Tab`,
  `Modal`
- plural for collections (`tableRows`)
- examples: `campaignNameInput`, `deleteButton`, `channelIosPushCheckbox`

## Step 5 — Output

Return `readonly` class-level declarations plus constructor assignments, grouped logically
(navigation/tabs, then form fields, then actions, then table elements). State for each
whether it is scoped to `this.frame` or `this.page`.

```typescript
// Class-level declarations
readonly nameInput: Locator;
readonly saveButton: Locator;
readonly tableRows: Locator;

// Constructor assignments
// Form fields (frame-scoped)
this.nameInput = this.frame.locator("[data-qa='name-input']");

// Actions (frame-scoped)
this.saveButton = this.frame.locator("[data-qa='save-button']");

// Table (frame-scoped)
this.tableRows = this.frame.locator(".el-table__row");
```

Then ask:

1. **"Add this to a page file?"** If yes, list the files in `<root>/playwright/pages/` to
   choose from, or take a new filename. Insert declarations into the class body and
   assignments into the constructor, in the right logical group. Change nothing else.
2. **"Find more elements, or close the browser?"** If more, stay on the page or navigate as
   directed without relaunching.

## Notes

- Skip decorative/layout elements with no interaction role.
- If the page has several distinct sections or tabs, say so and ask which one.
- If an element has no reliable unique selector, flag it — never guess.
- Element Plus dropdown option lists (`.el-select-dropdown__item`) render as portals inside
  the iframe's own document — scope them to `this.frame`, not `this.page`.
