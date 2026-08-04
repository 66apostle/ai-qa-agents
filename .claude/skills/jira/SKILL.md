---
name: jira
description: Search, view, create, update, and investigate Jira tickets (links, history, boards)
argument-hint: <ticket-id | search | create | update | sprint | boards | links ID | history ID [field]>
user_invocable: true
---

# Jira

You manage Jira tickets by running **single `python3 << 'PYEOF'` heredoc commands** that call the Jira REST API using stdlib only. No external tools or scripts — everything is self-contained in one Bash call per operation.

If any command fails with auth/netrc errors, tell the user to run the install script.

## Helper

Every operation uses this pattern. Copy-paste and adapt — do NOT split into separate curl + python steps:

```bash
python3 << 'PYEOF'
import json, netrc, base64, urllib.request, urllib.parse, sys

BASE = "https://xtremepush.atlassian.net"
nrc = netrc.netrc()
login, _, pw = nrc.authenticators("xtremepush.atlassian.net")
AUTH = "Basic " + base64.b64encode(f"{login}:{pw}".encode()).decode()

def api(method, path, body=None, query=None):
    url = BASE + path
    if query:
        url += ("&" if "?" in url else "?") + urllib.parse.urlencode(query)
    data = json.dumps(body).encode() if body else None
    req = urllib.request.Request(url, data=data, method=method)
    req.add_header("Authorization", AUTH)
    req.add_header("Content-Type", "application/json")
    req.add_header("Accept", "application/json")
    try:
        with urllib.request.urlopen(req) as r:
            raw = r.read().decode()
            return json.loads(raw) if raw else {"ok": True}
    except urllib.error.HTTPError as e:
        body = e.read().decode()
        try: body = json.loads(body)
        except: pass
        print(json.dumps({"error": True, "status": e.code, "body": body}, indent=2))
        sys.exit(1)

# --- operation-specific code goes here ---
PYEOF
```

**Important**: Always use a quoted heredoc (`<< 'PYEOF'`) to pass Python code. This prevents the shell from interpreting `!`, `$`, or other special characters inside the Python code. Do NOT use `python3 -c '...'` as zsh history expansion mangles `!` characters (e.g. `!=` in JQL).

**0 results is a valid outcome.** If a search returns no issues, tell the user — do NOT second-guess, retry with a different query, or run extra verification calls.

## Dispatch on `$ARGUMENTS`

| Input | Action |
|---|---|
| *(empty)* or `mine` | Use the **Search** operation below with JQL: `assignee = currentUser() AND statusCategory != Done ORDER BY priority DESC, updated DESC`. Present as a table. Group by status if many tickets. |
| Ticket ID (e.g. `XP-123`) | **View** — see below. |
| `search <query>` | If natural language, translate to JQL first. Use the **Search** operation below. |
| `create` | See Create below. |
| `update <ID> ...` | See Update below. |
| `sprint` | See Sprint below. |
| `links <ID>` | See Links below — parent, subtasks, issue links, remote links. |
| `history <ID>` | See History below — full changelog audit trail. |
| `history <ID> <field>` | History filtered to one field (e.g. `history XP-123 status`). |
| `boards` | See Boards below — list all boards. |
| `boards <name>` | Search boards by name (e.g. `boards Technical Services`). |

## Search

After the helper, add:

```python
jql = "YOUR JQL HERE"
issues = []
token = None
while True:
    q = {"jql": jql, "fields": "key,summary,status,priority,assignee,created,updated", "maxResults": "50"}
    if token:
        q["nextPageToken"] = token
    data = api("GET", "/rest/api/3/search/jql", query=q)
    issues.extend(data.get("issues", []))
    token = data.get("nextPageToken")
    if data.get("isLast", True) or not token:
        break

if not issues:
    print("No issues found.")
else:
    print(f"{'Key':<12} {'Status':<16} {'Priority':<10} Summary")
    print("-" * 80)
    for i in issues:
        f = i["fields"]
        print(f"{i['key']:<12} {(f.get('status') or {}).get('name',''):<16} {(f.get('priority') or {}).get('name',''):<10} {f.get('summary','')[:50]}")
    print(f"\n{len(issues)} issue(s)")
```

Present the output as a markdown table. Add browse links: `https://xtremepush.atlassian.net/browse/<KEY>`.

## View

```python
data = api("GET", "/rest/api/3/issue/XP-123", query={"expand": "renderedFields"})
print(json.dumps(data, indent=2))
```

Present: Key, Summary, Status, Priority, Type, Assignee, Reporter, Description (parse ADF — walk `content` recursively, concatenate `text` nodes), and recent comments.

## Create

Pre-fill fields from conversation context. Ask the user **once** for any missing required fields (project, type, summary at minimum).

```python
result = api("POST", "/rest/api/3/issue", body={
    "fields": {
        "project": {"key": "XP"},
        "issuetype": {"name": "Task"},
        "summary": "Fix login bug",
        "priority": {"name": "Medium"},
        "description": {"type": "doc", "version": 1, "content": [
            {"type": "paragraph", "content": [{"type": "text", "text": "Description"}]}
        ]}
    }
})
print(json.dumps(result, indent=2))
```

To assign, look up the user first:

```python
users = api("GET", "/rest/api/3/user/search", query={"query": "Name", "maxResults": "10"})
# pick the right accountId, then:
api("PUT", "/rest/api/3/issue/XP-123/assignee", body={"accountId": "<id>"})
```

Show the created ticket link: `https://xtremepush.atlassian.net/browse/<KEY>`

## Update

### Transition

```python
trans = api("GET", "/rest/api/3/issue/XP-123/transitions")
# Find matching transition by name, then:
api("POST", "/rest/api/3/issue/XP-123/transitions", body={"transition": {"id": "<id>"}})
```

If no match, print available transitions and ask the user.

### Comment

```python
comment_body = {
    "body": {"type": "doc", "version": 1, "content": [
        {"type": "paragraph", "content": [{"type": "text", "text": "Comment text"}]}
    ]}
}
# Optional: restrict visibility (internal/service-desk comments)
# comment_body["visibility"] = {"type": "role", "value": "Service Desk Team"}
api("POST", "/rest/api/3/issue/XP-123/comment", body=comment_body)
```

### Reassign

Look up user then assign (same as Create).

### Edit fields

```python
api("PUT", "/rest/api/3/issue/XP-123", body={
    "fields": {"priority": {"name": "High"}, "labels": ["bug"]}
})
```

## Sprint

```python
sprints = api("GET", "/rest/agile/1.0/board/7/sprint", query={"state": "active"})
sid = sprints["values"][0]["id"]
issues = []
start = 0
while True:
    data = api("GET", f"/rest/agile/1.0/board/7/sprint/{sid}/issue",
               query={"maxResults": "50", "startAt": str(start), "fields": "key,summary,status,priority,assignee"})
    issues.extend(data.get("issues", []))
    if start + 50 >= data.get("total", 0):
        break
    start += 50

for i in issues:
    f = i["fields"]
    print(f"{i['key']:<12} {(f.get('status') or {}).get('name',''):<16} {f.get('summary','')[:50]}")
print(f"\n{len(issues)} issue(s)")
```

Present as a board grouped by status columns.

## Links

Get all relationships for a ticket: parent, subtasks, issue links, and remote links (Confluence pages, external URLs).

```python
# Issue data (parent, subtasks, issue links)
data = api("GET", "/rest/api/3/issue/XP-123", query={"fields": "parent,subtasks,issuelinks"})
f = data["fields"]
print("Parent:", f.get("parent", {}).get("key", "None"))
print("Subtasks:", [s["key"] for s in f.get("subtasks", [])])
for link in f.get("issuelinks", []):
    if "outwardIssue" in link:
        print(f"  {link['type']['outward']} {link['outwardIssue']['key']}")
    elif "inwardIssue" in link:
        print(f"  {link['type']['inward']} {link['inwardIssue']['key']}")

# Remote links (Confluence pages, external URLs)
remotes = api("GET", "/rest/api/3/issue/XP-123/remotelink")
for rl in remotes:
    obj = rl.get("object", {})
    print(f"  {obj.get('title', '')} -> {obj.get('url', '')}")
```

Present parent, subtasks, issue links (with direction), and remote links. Add browse links.

## History

Get the change history (audit trail) for a ticket. Optionally filter to a specific field.

```python
import json

field_filter = ""  # e.g. "status", "assignee", "priority" — leave empty for all
entries = []
start = 0
while True:
    data = api("GET", "/rest/api/3/issue/XP-123/changelog", query={"startAt": str(start), "maxResults": "100"})
    for history in data.get("values", []):
        author = (history.get("author") or {}).get("displayName", "")
        created = history.get("created", "")
        for item in history.get("items", []):
            if field_filter and item.get("field", "").lower() != field_filter.lower():
                continue
            entries.append({"author": author, "created": created, "field": item["field"], "from": item.get("fromString", ""), "to": item.get("toString", "")})
    if start + 100 >= data.get("total", 0):
        break
    start += 100

for e in entries:
    print(f"{e['created'][:16]}  {e['author']:<20}  {e['field']}: {e['from'] or '(none)'} → {e['to'] or '(none)'}")
print(f"\n{len(entries)} change(s)")
```

Present as a timeline table. For `history <ID> <field>`, set `field_filter` to the given field name.

## Boards

Use the `jira_list_boards` MCP tool to list or search Jira boards.

```
jira_list_boards()                              # list all boards
jira_list_boards(name="Technical Services")     # search by name
jira_list_boards(project_key="TS")              # filter by project
jira_list_boards(type="scrum")                  # filter by type
```

Returns board ID, name, type, project key, and project name. Use the board ID with `sprint` commands.
