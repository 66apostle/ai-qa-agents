---
name: confluence
description: Search, view, create, update, and explore Confluence pages (ancestors, children, descendants, comments)
argument-hint: <page-id | search query | create | update | spaces | ancestors ID | children ID | descendants ID | comments ID>
user_invocable: true
---

# Confluence

You manage Confluence pages by running **single `python3 << 'PYEOF'` heredoc commands** that call the Confluence REST API using stdlib only. No external tools or scripts — everything is self-contained in one Bash call per operation.

If any command fails with auth/netrc errors, tell the user to run the install script.

## Helper

Every operation uses this pattern. Copy-paste and adapt — do NOT split into separate curl + python steps:

```bash
python3 << 'PYEOF'
import json, netrc, base64, urllib.request, urllib.parse, sys
from html.parser import HTMLParser

BASE = "https://xtremepush.atlassian.net"
nrc = netrc.netrc()
login, _, pw = nrc.authenticators("xtremepush.atlassian.net")
AUTH = "Basic " + base64.b64encode(f"{login}:{pw}".encode()).decode()

def api_v2(method, path, body=None, query=None):
    """Confluence v2 API — pages CRUD, spaces."""
    url = BASE + "/wiki/api/v2" + path
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

def api_v1(method, path, body=None, query=None):
    """Confluence v1 API — CQL search."""
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

class _HTMLStripper(HTMLParser):
    def __init__(self):
        super().__init__()
        self._parts = []
    def handle_data(self, data):
        self._parts.append(data)
    def get_text(self):
        return "".join(self._parts).strip()

def html_to_text(html):
    """Strip Confluence storage-format HTML to readable text."""
    s = _HTMLStripper()
    s.feed(html)
    return s.get_text()

def text_to_storage(text):
    """Wrap plain text paragraphs in <p> tags for Confluence storage format."""
    paragraphs = text.split("\n\n") if "\n\n" in text else [text]
    return "".join(f"<p>{p.strip()}</p>" for p in paragraphs if p.strip())

# --- operation-specific code goes here ---
PYEOF
```

**Important**: Always use a quoted heredoc (`<< 'PYEOF'`) to pass Python code. This prevents the shell from interpreting `!`, `$`, or other special characters inside the Python code. Do NOT use `python3 -c '...'` as zsh history expansion mangles `!` characters.

**0 results is a valid outcome.** If a search returns no pages, tell the user — do NOT second-guess, retry with a different query, or run extra verification calls.

## Dispatch on `$ARGUMENTS`

| Input | Action |
|---|---|
| *(empty)* | List recent pages (Search with CQL: `type=page ORDER BY lastModified DESC`) |
| A number (e.g. `12345`) | **View** page by ID |
| `search <query>` | CQL search: `type=page AND text ~ "query"` |
| `view <title>` | Resolve title to page ID via v2 API, then **View** |
| `create` | See Create below. |
| `update <ID>` | See Update below. |
| `spaces` | List all spaces |
| `ancestors <ID>` | See Ancestors below — parent chain from root to page. |
| `children <ID>` | See Children below — direct child pages. |
| `descendants <ID>` | See Descendants below — all nested pages recursively. |
| `comments <ID>` | See Comments below — inline and footer comments. |

## Search

After the helper, add:

```python
cql = 'type=page AND text ~ "QUERY HERE"'
results = []
start = 0
while True:
    data = api_v1("GET", "/content/search", query={"cql": cql, "limit": "25", "start": str(start)})
    results.extend(data.get("results", []))
    if data.get("size", 0) < 25 or len(results) >= 100:
        break
    start += 25

if not results:
    print("No pages found.")
else:
    print(f"{'ID':<12} {'Space':<10} {'Title'}")
    print("-" * 70)
    for r in results:
        page_id = r["id"]
        space_key = r.get("_expandable", {}).get("space", "").rsplit("/", 1)[-1] if "_expandable" in r else ""
        title = r.get("title", "")[:50]
        print(f"{page_id:<12} {space_key:<10} {title}")
    print(f"\n{len(results)} page(s)")
```

Present the output as a markdown table. Add browse links: `https://xtremepush.atlassian.net/wiki/spaces/{space_key}/pages/{page_id}`.

For listing recent pages (empty arguments), use CQL: `type=page ORDER BY lastModified DESC` with limit 25.

## View

```python
page = api_v2("GET", "/pages/PAGE_ID", query={"body-format": "storage"})
title = page.get("title", "")
page_id = page.get("id", "")
space_id = page.get("spaceId", "")
version = page.get("version", {}).get("number", "")
body_html = page.get("body", {}).get("storage", {}).get("value", "")
body_text = html_to_text(body_html)
print(f"Title: {title}")
print(f"ID: {page_id}")
print(f"Space ID: {space_id}")
print(f"Version: {version}")
print(f"\n{body_text}")
```

Present: Title, ID, Space ID, Version, and the page content as readable text. Add browse link.

To resolve a title to a page ID (for `view <title>`):

```python
data = api_v2("GET", "/pages", query={"title": "PAGE TITLE HERE", "limit": "5"})
pages = data.get("results", [])
if not pages:
    print("No page found with that title.")
    sys.exit(0)
page_id = pages[0]["id"]
# Then proceed with the View code above using this page_id
```

## Create

Ask the user **once** for any missing required fields (space key, title, content at minimum). Resolve the space key to a space ID first.

```python
# Resolve space key to space ID
spaces = api_v2("GET", "/spaces", query={"keys": "SPACE_KEY"})
space_list = spaces.get("results", [])
if not space_list:
    print("Space not found."); sys.exit(1)
space_id = space_list[0]["id"]

result = api_v2("POST", "/pages", body={
    "spaceId": space_id,
    "status": "current",
    "title": "PAGE TITLE HERE",
    "body": {
        "representation": "storage",
        "value": text_to_storage("PAGE CONTENT HERE")
    }
})
print(json.dumps({"id": result["id"], "title": result["title"]}, indent=2))
```

Show the created page link: `https://xtremepush.atlassian.net/wiki/spaces/{space_key}/pages/{page_id}`.

## Update

Get the current page to read its version number, then PUT with version + 1.

```python
# Get current page
page = api_v2("GET", "/pages/PAGE_ID", query={"body-format": "storage"})
current_version = page["version"]["number"]
current_title = page["title"]

result = api_v2("PUT", "/pages/PAGE_ID", body={
    "id": "PAGE_ID",
    "status": "current",
    "title": current_title,
    "body": {
        "representation": "storage",
        "value": text_to_storage("UPDATED CONTENT HERE")
    },
    "version": {
        "number": current_version + 1
    }
})
print(json.dumps({"id": result["id"], "title": result["title"], "version": result["version"]["number"]}, indent=2))
```

Show the updated page link. If the user only wants to append content, fetch the current body and concatenate before updating.

## Spaces

```python
spaces = []
cursor = None
while True:
    q = {"limit": "25"}
    if cursor:
        q["cursor"] = cursor
    data = api_v2("GET", "/spaces", query=q)
    spaces.extend(data.get("results", []))
    cursor = data.get("_links", {}).get("next")
    if not cursor:
        break
    # Extract cursor param from next link
    cursor = urllib.parse.parse_qs(urllib.parse.urlparse(cursor).query).get("cursor", [None])[0]
    if not cursor:
        break

if not spaces:
    print("No spaces found.")
else:
    print(f"{'Key':<12} {'Name':<40} {'Type'}")
    print("-" * 65)
    for s in spaces:
        print(f"{s.get('key', ''):<12} {s.get('name', '')[:38]:<40} {s.get('type', '')}")
    print(f"\n{len(spaces)} space(s)")
```

Present the output as a markdown table. Add browse links: `https://xtremepush.atlassian.net/wiki/spaces/{key}`.

## Ancestors

Get the full parent chain from the root page down to the immediate parent of a page.

```python
data = api_v2("GET", "/pages/PAGE_ID/ancestors")
ancestors = data.get("results", [])
if not ancestors:
    print("This page is a root page (no ancestors).")
else:
    print("Ancestor chain (root → parent):")
    for a in ancestors:
        print(f"  {a['id']}  {a.get('title', '')}")
```

Present as a breadcrumb trail. Add browse links: `https://xtremepush.atlassian.net/wiki/pages/{id}`.

## Children

Get direct child pages of a page.

```python
data = api_v2("GET", "/pages/PAGE_ID/children", query={"limit": "50"})
children = data.get("results", [])
if not children:
    print("No child pages.")
else:
    print(f"{'ID':<12} {'Title'}")
    print("-" * 50)
    for c in children:
        print(f"{c['id']:<12} {c.get('title', '')}")
    print(f"\n{len(children)} child page(s)")
```

Present as a markdown table with browse links.

## Descendants

Get all descendant pages recursively (entire subtree).

```python
data = api_v1("GET", f"/content/PAGE_ID/descendant/page", query={"limit": "100"})
descendants = data.get("results", [])
if not descendants:
    print("No descendant pages.")
else:
    print(f"{'ID':<12} {'Title'}")
    print("-" * 50)
    for d in descendants:
        print(f"{d['id']:<12} {d.get('title', '')}")
    print(f"\n{len(descendants)} descendant page(s)")
```

Present as a markdown table with browse links.

## Comments

Get inline (in-body) and footer (page-level) comments on a page.

```python
# Inline comments (with resolution status)
inline = api_v2("GET", "/pages/PAGE_ID/inline-comments", query={"body-format": "storage"})
print("Inline comments:")
for c in inline.get("results", []):
    body_html = c.get("body", {}).get("storage", {}).get("value", "")
    body_text = html_to_text(body_html)
    status = c.get("resolutionStatus", "open")
    print(f"  [{status}] {body_text[:80]}")

# Footer comments
footer = api_v2("GET", "/pages/PAGE_ID/footer-comments", query={"body-format": "storage"})
print("\nFooter comments:")
for c in footer.get("results", []):
    body_html = c.get("body", {}).get("storage", {}).get("value", "")
    body_text = html_to_text(body_html)
    print(f"  {body_text[:80]}")
```

Present inline comments with their resolution status (open/resolved). Present footer comments separately.
