---
name: investigate
description: Investigate a bug ticket by gathering context from Jira, Confluence, Bitbucket, and Kubernetes
argument-hint: <TICKET-ID>
user_invocable: true
---

# Investigate

You run an automated investigation of a bug ticket by gathering context from every available system — Jira, Confluence, Bitbucket, and Kubernetes — and presenting a consolidated briefing. Each step is a separate Bash call so that one failure does not block the rest.

If `$ARGUMENTS` is empty, ask the user for a Jira ticket ID before proceeding.

## Investigation Workflow

Run these steps in order. After all steps complete, synthesise the findings into a briefing (see Output Format below).

---

### Step 1 — Jira: Ticket Context

Fetch the ticket, its relationships, and recent history. Run these as **three separate Bash calls** (they share the same helper):

**1a. Ticket details + links + remote links:**

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

# Fetch ticket
data = api("GET", "/rest/api/3/issue/TICKET_ID", query={"expand": "renderedFields"})
print("=== TICKET ===")
print(json.dumps(data, indent=2))

# Fetch issue links, parent, subtasks from the same response
f = data["fields"]
print("\n=== LINKS ===")
print("Parent:", json.dumps(f.get("parent"), indent=2))
print("Subtasks:", json.dumps(f.get("subtasks"), indent=2))
print("Issue links:", json.dumps(f.get("issuelinks"), indent=2))

# Fetch remote links (Confluence pages, Bitbucket PRs, external URLs)
remotes = api("GET", "/rest/api/3/issue/TICKET_ID/remotelink")
print("\n=== REMOTE LINKS ===")
print(json.dumps(remotes, indent=2))
PYEOF
```

**1b. Recent changelog (last 10 changes):**

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

data = api("GET", "/rest/api/3/issue/TICKET_ID/changelog", query={"startAt": "0", "maxResults": "10"})
print("=== CHANGELOG ===")
for history in data.get("values", []):
    author = (history.get("author") or {}).get("displayName", "")
    created = history.get("created", "")
    for item in history.get("items", []):
        print(f"{created[:16]}  {author:<20}  {item['field']}: {item.get('fromString', '') or '(none)'} -> {item.get('toString', '') or '(none)'}")
PYEOF
```

From the ticket response, extract and note for later steps:
- **Project key** (e.g. `TS`) — for related ticket searches
- **Labels and components** — for related ticket searches and service name extraction
- **Summary keywords** — for text searches
- **Service/app name** — look in labels, components, summary, and description (in that order). Common patterns: service names in kebab-case (e.g. `bonus-integrations-middleware`), or mentioned after "in", "from", "on" in the summary.

---

### Step 2 — Jira: Related Tickets

Search for tickets that may be related. Build JQL from the ticket's labels, components, and summary keywords. Run **one** search combining the criteria:

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

# Adapt this JQL using the ticket's project, labels, and summary keywords
jql = 'project = PROJECT_KEY AND text ~ "KEY TERMS FROM SUMMARY" AND key != TICKET_ID ORDER BY created DESC'
data = api("GET", "/rest/api/3/search/jql", query={"jql": jql, "fields": "key,summary,status,priority,assignee,created,resolution", "maxResults": "10"})
issues = data.get("issues", [])
if not issues:
    print("No related tickets found.")
else:
    print(f"{'Key':<12} {'Status':<16} {'Priority':<10} {'Resolution':<14} Summary")
    print("-" * 100)
    for i in issues:
        f = i["fields"]
        print(f"{i['key']:<12} {(f.get('status') or {}).get('name',''):<16} {(f.get('priority') or {}).get('name',''):<10} {(f.get('resolution') or {}).get('name','None'):<14} {f.get('summary','')[:50]}")
    print(f"\n{len(issues)} related issue(s)")
PYEOF
```

Include the `resolution` field — resolved related tickets often contain the fix that applies to this bug too.

---

### Step 3 — Confluence: Documentation

Check for linked Confluence pages (from Step 1 remote links) and search for relevant documentation.

**3a. Fetch any Confluence pages found in remote links** — extract page IDs from URLs matching `xtremepush.atlassian.net/wiki` and fetch their titles using the `/confluence` view pattern.

**3b. Search for documentation about the service:**

```bash
python3 << 'PYEOF'
import json, netrc, base64, urllib.request, urllib.parse, sys

BASE = "https://xtremepush.atlassian.net"
nrc = netrc.netrc()
login, _, pw = nrc.authenticators("xtremepush.atlassian.net")
AUTH = "Basic " + base64.b64encode(f"{login}:{pw}".encode()).decode()

def api_v1(method, path, body=None, query=None):
    url = BASE + "/wiki/rest/api" + path
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

cql = 'type=page AND text ~ "SERVICE_NAME_HERE"'
data = api_v1("GET", "/content/search", query={"cql": cql, "limit": "5"})
results = data.get("results", [])
if not results:
    print("No Confluence pages found.")
else:
    for r in results:
        page_id = r["id"]
        space_key = r.get("_expandable", {}).get("space", "").rsplit("/", 1)[-1] if "_expandable" in r else ""
        title = r.get("title", "")
        print(f"{page_id}  {space_key}  {title}")
    print(f"\n{len(results)} page(s)")
PYEOF
```

---

### Step 4 — Bitbucket: Recent Code Changes

Look for commits and PRs related to this ticket. Check two sources:

**4a. PRs from remote links** — if Step 1 found Bitbucket PR URLs in the remote links, fetch each PR's title, status, and diffstat using the `/bitbucket` view pattern.

**4b. Search for commits referencing the ticket ID** — use the Bitbucket commits pattern to search for the ticket ID in commit messages. Run this in the repo most likely to be related (infer from the service name or from linked PRs):

```bash
python3 << 'PYEOF'
import json, netrc, base64, urllib.request, urllib.parse, sys, subprocess, re

BASE = "https://api.bitbucket.org/2.0"
nrc = netrc.netrc()
login, _, pw = nrc.authenticators("api.bitbucket.org")
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

def get_repo():
    url = subprocess.check_output(["git", "remote", "get-url", "origin"], text=True).strip()
    if "bitbucket.org:" in url:
        path = url.split("bitbucket.org:")[1]
    elif "bitbucket.org/" in url:
        path = url.split("bitbucket.org/")[1]
    else:
        print("Not a Bitbucket repo — skipping commit search."); sys.exit(0)
    path = path.removesuffix(".git")
    parts = path.split("/")
    return parts[0], parts[1]

try:
    ws, repo = get_repo()
except Exception:
    print("Could not detect repo — skipping commit search.")
    sys.exit(0)

# Search recent commits on the default branch for the ticket ID
try:
    ref = subprocess.check_output(["git", "symbolic-ref", "refs/remotes/origin/HEAD"], text=True, stderr=subprocess.DEVNULL).strip()
    branch = ref.split("/")[-1]
except subprocess.CalledProcessError:
    branch = "master"

data = api("GET", f"/repositories/{ws}/{repo}/commits/{urllib.parse.quote(branch, safe='')}", query={"pagelen": "50"})
jira_re = re.compile(r"\bTICKET_ID\b")
found = []
for c in data.get("values", []):
    msg = c.get("message", "")
    if jira_re.search(msg):
        author = (c.get("author") or {}).get("user", {}).get("display_name", c.get("author", {}).get("raw", ""))
        found.append({"hash": c["hash"][:12], "author": author, "message": msg.strip().split("\n")[0][:80], "date": c.get("date", "")[:16]})

if not found:
    print(f"No commits referencing TICKET_ID found in {ws}/{repo}.")
else:
    for c in found:
        print(f"{c['date']}  {c['hash']}  {c['author']:<20}  {c['message']}")
    print(f"\n{len(found)} commit(s) referencing TICKET_ID")
PYEOF
```

If the current directory is not a Bitbucket repo, skip this step gracefully.

---

### Step 5 — Kubernetes: Runtime State

Extract the service/app name identified in Step 1. If no clear service name was found, skip this step with a note.

**Check if kubectl is available first:**

```bash
kubectl version --client --short 2>/dev/null || echo "KUBECTL_NOT_AVAILABLE"
```

If kubectl is not available, skip this step entirely and note it in the briefing.

**5a. Pod status and restarts:**

```bash
echo "=== Pod Status ==="
kubectl get pods -l app=APP_NAME -o wide 2>/dev/null || kubectl get pods --no-headers 2>/dev/null | grep APP_NAME

echo ""
echo "=== Restart Counts ==="
kubectl get pods -l app=APP_NAME -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{range .status.containerStatuses[*]}{.name}:{.restartCount}{" "}{end}{"\n"}{end}' 2>/dev/null
```

**5b. Recent events for the app:**

```bash
echo "=== Recent Events ==="
kubectl get events --sort-by=.lastTimestamp --field-selector involvedObject.kind=Pod --no-headers 2>/dev/null | grep APP_NAME | tail -20
```

**5c. Error log grep** (only if the ticket mentions error codes like 502, 500, timeout, OOM, crash, etc.):

```bash
POD=$(kubectl get pods -l app=APP_NAME --sort-by=.metadata.creationTimestamp -o jsonpath='{.items[-1].metadata.name}' 2>/dev/null)
if [ -n "$POD" ]; then
  echo "=== Recent Error Logs (from $POD) ==="
  kubectl logs "$POD" --tail=200 2>/dev/null | grep -iE "(error|exception|fatal|timeout|502|500|503|OOM|kill|crash)" | tail -30
fi
```

---

## Output Format

After gathering all data, present a structured briefing. Use this exact format:

```
## Investigation Briefing: TICKET_ID

### Ticket Summary
**Summary**: ...
**Status**: ... | **Priority**: ... | **Type**: ...
**Assignee**: ... | **Reporter**: ...
**Created**: ... | **Updated**: ...

> Description (first 500 characters)...

Browse: https://xtremepush.atlassian.net/browse/TICKET_ID

### Relationships
- **Parent**: ... (or None)
- **Subtasks**: ... (or None)
- **Blocks**: ...
- **Blocked by**: ...
- **Linked tickets**: ...
- **Linked PRs**: ...
- **Linked Confluence pages**: ...

### Timeline
| When | Who | Change |
|---|---|---|
| ... | ... | field: old -> new |

### Related Tickets
| Key | Status | Priority | Resolution | Summary |
|---|---|---|---|---|
| ... | ... | ... | ... | ... |

Browse links for each: https://xtremepush.atlassian.net/browse/<KEY>

### Documentation
- [Page Title](confluence-link) — Space: KEY
- ...

### Recent Code Changes
- `abc123def` by Author — "commit message" (date)
- PR #42: "PR title" — Status: MERGED (link)

### Kubernetes Status
**Pods**: X running, Y pending, Z restarts in last hour
**Events**: (any warnings)
**Error logs**: (relevant excerpts, if any)

(If kubectl was unavailable: "Skipped — kubectl not configured. Run `aws sso login` and check your kubeconfig.")

### Key Observations
- Bullet 1: Synthesise findings across systems
- Bullet 2: e.g. "3 restarts in the last hour correlate with PR #42 merged yesterday"
- Bullet 3: e.g. "Similar issue TS-890 was resolved by scaling up replicas"
```

The **Key Observations** section is the most important — connect the dots. Look for:
- Correlations between recent deploys and error onset
- Similar resolved tickets whose fixes may apply
- Restart patterns or resource exhaustion
- Missing documentation or configuration gaps
- Blocking relationships that explain stalled progress

**0 results is a valid outcome for any step.** Report it and move on — do NOT retry with different queries or second-guess the results.
