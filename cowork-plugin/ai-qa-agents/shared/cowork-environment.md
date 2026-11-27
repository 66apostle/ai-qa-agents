# Running the pipeline in Cowork

The playbooks in `shared/agents/` were written for Claude Code inside the ai-qa-agents repo.
In Cowork, apply this mapping before following them. Where a playbook and this file disagree
about *where* or *with which tool*, this file wins. The playbooks still decide *what* to do.

Locate files by path from the plugin root: two levels up from the base directory of the
skill that is running (`<skill base>/../..`).

## 1. The workspace folder

The pipeline's home is the user's ai-qa-agents folder on their Mac:

`/Users/66apostle/Документы/ai-qa-agents`

1. Check the connected folders (`get_device_info` → `connectedFolders`). If that folder is not
   connected, call `device_request_folder_access` for it once, with the reason
   "Read pipeline config and save test-prep reports".
2. In `device_bash` it is mounted at `$HOME/mnt/ai-qa-agents` (confirm with `ls $HOME/mnt/`).
3. Path mapping for every playbook:

| Playbook path | In Cowork |
|---|---|
| `output/<ID>-test-prep.md` | `<workspace>/output/<ID>-test-prep.md` |
| `config/sources.json` | `<workspace>/config/sources.json`; if missing, `shared/config/sources.json` |
| `config/targets.json` | `<workspace>/config/targets.json`; if missing, `shared/config/targets.example.json` (then ask for real paths) |
| `docs/stacks/<target>.md` | `shared/stacks/<target>.md` |
| `fixtures/<ID>/` | `shared/demo/<ID>/` |

4. Write reports with `device_bash` (a heredoc or a short python write) into
   `<workspace>/output/`. Never overwrite an existing report without saying so; if one exists,
   write `<ID>-test-prep.v2.md` (v3, …) unless the user asked to replace it.
5. If the workspace folder cannot be reached (computer offline, access declined), deliver the
   report as a chat file with SendUserFile and tell the user that later steps will need it
   re-attached.

## 2. Mode

- Ticket ID starting with `DEMO-` → demo mode: read `shared/demo/<ID>/` only. Touch no
  connectors.
- Any other ticket ID → real mode, unless the user passes `--mode=demo`.

## 3. Jira and Confluence (real mode)

Use the **Atlassian connector**. Its tools may be deferred: load them with ToolSearch
(query "atlassian jira confluence", or `select:` the names below) in one call.

| Need | Tool |
|---|---|
| Cloud ID | `getAccessibleAtlassianResources` (pick xtremepush.atlassian.net) |
| Ticket, Epic, PRODUCT idea | `getJiraIssue` (description, all AC, comments, issue links, parent) |
| Related tickets | `searchJiraIssuesUsingJql` |
| RFC / linked pages | `searchConfluence`, then `getConfluenceContent` |

The RFC space and PRODUCT project come from `sources.json` → `real`. Follow every link the
ticket gives (parent, "relates to", Confluence URLs in the description and comments). A link
you cannot read is a **GAP**, never a guess.

If no Atlassian tools exist in the session, use `SearchMcpRegistry` + `SuggestConnectors` for
Atlassian and stop until it is connected.

The Atlassian connector is **read-only for this pipeline.** Never comment on, transition or
edit a ticket, and never create a Confluence page.

## 4. Qase

Use the **Qase Test Management** connector (`qase_project_context`, `qase_case_upsert`,
`qase_get`). Load via ToolSearch ("qase"). Writes happen only through the push-to-qase skill
with explicit confirmation.

## 5. Delegation

The playbooks say "delegate to agent X". In Cowork, do not spawn subagents for this. Read the
playbook from `shared/agents/<name>.md` and carry out that phase yourself, keeping the phases
separate: finish the corpus before reading the architect playbook, and do not let the
architect phase fetch new sources. Only spawn a subagent if the user explicitly asks.

## 6. Target test repos (Phase 3 and 3.5)

1. Read `targets.json`. Each target's `root` is a path on the user's Mac.
2. If the root is not a connected folder, call `device_request_folder_access` for it.
   If `root` is still the example placeholder, ask the user which folder holds that repo.
   Identify the stack from the contents: `playwright.config.ts` → `ui-playwright`;
   `.mocharc*` / mocha in `package.json` → `api-mocha`.
3. Work inside the repo with `device_bash` at `$HOME/mnt/<folder-name>`. Edit files there in
   place; never stage repo files into the cloud workspace to edit them.
4. Running tests: `device_bash` runs in a Linux VM on the user's Mac, not in macOS itself.
   `node_modules` installed on macOS can contain macOS-only binaries (esbuild, Playwright
   browsers), so a run can fail for environment reasons that have nothing to do with the test.
   - Try the target's `runSpec` once.
   - If it fails with a platform/binary/browser-missing error, do **not** reinstall
     dependencies inside the user's repo. Report it as an environment gap, give the exact
     command for the user to run in their Mac terminal, and ask them to paste the result.
     Then continue the failure loop from their output.
   - Lint/format/type-check follow the same rule.
5. Never `git add`, commit, push, stash, checkout or reset. `git status --short` and
   `git diff --stat` are fine.
6. Delete is off by default in connected folders. The pipeline should never need it.

## 7. Selectors and endpoints

- `/find-selectors`: use the Playwright plugin's browser tools (`browser_navigate`,
  `browser_snapshot`, `browser_evaluate`) if present, else the built-in browser. The stored
  auth file (`.auth/user.json` in the UI repo) can be applied by reading it with `device_bash`
  and adding its cookies via `browser_run_code_unsafe` (`context.addCookies`). If that is not
  possible, ask the user to sign in in the browser. Never type their credentials from `.env`
  without asking.
- `/find-endpoint`: the app repos (`xp-web-application`, `maxautomation-xp`) are siblings of
  the API test repo root. Request folder access to the one(s) needed, then grep with
  `device_bash`.

## 8. Confidentiality

Real-mode reports contain internal ticket data. Keep them in `<workspace>/output/` (gitignored
in the user's repo). Do not publish them as artifacts or post them anywhere unless the user
asks.
