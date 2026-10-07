"""tasks-offline: a read-only copy of Vikunja for when Akmon is out of reach.

Every 15 minutes (a user timer, Tn-web-apps) this logs in to Vikunja's API,
reads every open task and writes one self-contained page:
    ~/.local/share/tasks-offline/index.html   (launcher: "Tasks (offline copy)")
It never writes to Vikunja. When Akmon can't be reached it keeps the last
copy, whose header says how old it is.
"""

import datetime
import html
import json
import os
import sys
import urllib.request

API = "https://tasks.ironshark.org/api/v1"
WEB = "https://tasks.ironshark.org"
OUT = os.path.expanduser("~/.local/share/tasks-offline")
PASSWORD_FILE = os.environ.get("VIKUNJA_PASSWORD_FILE", "/run/secrets/vikunja-password")
NO_DATE = "0001-01-01T00:00:00Z"


def call(path, token=None, body=None):
    req = urllib.request.Request(API + path, method="POST" if body is not None else "GET")
    req.add_header("Content-Type", "application/json")
    if token:
        req.add_header("Authorization", f"Bearer {token}")
    data = json.dumps(body).encode() if body is not None else None
    with urllib.request.urlopen(req, data=data, timeout=20) as r:
        return json.load(r), r.headers


def fetch():
    with open(PASSWORD_FILE) as f:
        password = f.read().strip()
    token = call("/login", body={"username": "xin", "password": password})[0]["token"]
    projects, _ = call("/projects?per_page=250", token)
    tasks, page = [], 1
    while True:
        batch, headers = call(f"/tasks?per_page=250&page={page}", token)
        tasks += batch or []
        if page >= int(headers.get("x-pagination-total-pages") or 1):
            break
        page += 1
    return projects, [t for t in tasks if not t.get("done")]


def when(s):
    if not s or s == NO_DATE:
        return None
    return datetime.datetime.fromisoformat(s.replace("Z", "+00:00")).astimezone()


def render(projects, tasks):
    now = datetime.datetime.now().astimezone()
    names = {p["id"]: p["title"] for p in projects if not p.get("is_archived")}
    by_project = {}
    for t in tasks:
        by_project.setdefault(t["project_id"], []).append(t)

    def order(t):
        due = when(t.get("due_date"))
        return (due is None, due or now, -(t.get("priority") or 0), t.get("position") or 0)

    body = []
    for pid in sorted(by_project, key=lambda i: names.get(i, "~").lower()):
        rows = []
        for t in sorted(by_project[pid], key=order):
            due = when(t.get("due_date"))
            due_html = ""
            if due:
                cls = "overdue" if due < now else "due"
                due_html = f'<span class="{cls}">{due:%a %d %b %H:%M}</span>'
            prio = "!" * min(t.get("priority") or 0, 5)
            labels = "".join(f'<span class="label">{html.escape(lb["title"])}</span>'
                             for lb in (t.get("labels") or []))
            desc = t.get("description") or ""
            # Vikunja stores descriptions as HTML; it's xin's own text, shown as is
            desc_html = f"<details><summary>notes</summary><div class=desc>{desc}</div></details>" if desc.strip() else ""
            rows.append(f'<li><a href="{WEB}/tasks/{t["id"]}">{html.escape(t["title"])}</a>'
                        f'<span class="prio">{prio}</span>{labels}{due_html}{desc_html}</li>')
        title = html.escape(names.get(pid, f"project {pid}"))
        body.append(f"<h2>{title} <small>{len(rows)}</small></h2><ul>{''.join(rows)}</ul>")

    return f"""<!doctype html><html><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1"><title>Tasks (offline copy)</title>
<style>
:root {{ --bg:#fcfcfb; --ink:#0b0b0b; --ink2:#52514e; --hair:#e1e0d9; --accent:#2a78d6; --bad:#d03b3b; --chip:#f0efec; }}
@media (prefers-color-scheme: dark) {{ :root {{ --bg:#1a1a19; --ink:#fff; --ink2:#c3c2b7; --hair:#2c2c2a; --accent:#3987e5; --bad:#e66767; --chip:#2c2c2a; }} }}
body {{ background:var(--bg); color:var(--ink); font:15px/1.45 system-ui,sans-serif; max-width:760px; margin:0 auto; padding:16px; }}
header {{ color:var(--ink2); border-bottom:1px solid var(--hair); padding-bottom:8px; }}
h2 {{ font-size:17px; margin:22px 0 6px; }} h2 small {{ color:var(--ink2); font-weight:400; }}
ul {{ list-style:none; padding:0; margin:0; }}
li {{ padding:6px 0; border-bottom:1px solid var(--hair); }}
a {{ color:var(--ink); text-decoration:none; }} a:hover {{ color:var(--accent); }}
.due, .overdue {{ float:right; color:var(--ink2); font-variant-numeric:tabular-nums; }}
.overdue {{ color:var(--bad); font-weight:600; }}
.prio {{ color:var(--bad); font-weight:700; margin-left:6px; }}
.label {{ background:var(--chip); border-radius:4px; padding:0 6px; margin-left:6px; font-size:12px; color:var(--ink2); }}
details {{ color:var(--ink2); font-size:13px; }} .desc {{ padding:4px 0 2px 12px; }}
</style></head><body>
<header><b>Tasks (offline copy)</b>: read-only, saved {now:%a %d %b %H:%M}.
{len(tasks)} open tasks. Edit in Vikunja when you're online.</header>
{''.join(body) or '<p>No open tasks.</p>'}
</body></html>"""


def main():
    try:
        projects, tasks = fetch()
    except Exception as e:  # noqa: BLE001 - offline is the normal reason; keep the last copy
        print(f"Vikunja not reachable, keeping the last copy: {e}", file=sys.stderr)
        return
    os.makedirs(OUT, exist_ok=True)
    tmp = os.path.join(OUT, ".index.html.tmp")
    with open(tmp, "w") as f:
        f.write(render(projects, tasks))
    os.replace(tmp, os.path.join(OUT, "index.html"))
    print(f"saved {len(tasks)} open tasks")


if __name__ == "__main__":
    main()
