# ai-qa-agents (Cowork plugin)

Cowork version of https://github.com/66apostle/ai-qa-agents: a ticket goes in, and you get a
requirements corpus, regression-ready test cases, gap questions, then (after your review)
automated tests in your test repo.

## Install

1. In the Claude desktop app, start a Cowork task.
2. Drag `ai-qa-agents.plugin` (one folder up) into the chat and press **Install**.
3. After editing this source, run `../build.sh` and install the new file.

See the "Using it in Claude Cowork" section of the project README for full usage.

## Skills

| Skill | What it does |
|---|---|
| `/qa-flow <ID>` | Full pipeline. Stops at Gate 1 after the report; `--from=implement --target=…` writes + runs tests, then reviews them, and stops at Gate 2. |
| `/prep-testing <ID>` | Report only (Phases 1–2). |
| `/push-to-qase <ID>` | Reviewed cases → Qase. Dry run unless you confirm. |
| `/review-tests` | Reviews test code against the repo's own checklist. |
| `/find-selectors <url> <element>` | Real selectors from the live page, as page-object properties. |
| `/find-endpoint <pattern>` | Endpoint method/URL/params from the XP/MXA source. |

Try `/qa-flow DEMO-123` for a synthetic demo that needs no connectors.

## What it needs

- **Your ai-qa-agents folder** (`~/Документы/ai-qa-agents`) connected. Reports are saved to
  its `output/` folder; `config/sources.json` and `config/targets.json` are read from it.
- **Atlassian connector** for real tickets (read-only use).
- **Qase connector** for `/push-to-qase`.
- **Your test repo folders** connected when implementing or reviewing tests. Test runs happen
  in Cowork's Linux VM; if your macOS `node_modules` won't run there, the plugin gives you the
  command to run in your terminal instead.

## Guarantees

Nothing is written to Jira or Confluence. Qase is written only after you confirm. Code is
never committed or pushed: you get an unstaged diff.
