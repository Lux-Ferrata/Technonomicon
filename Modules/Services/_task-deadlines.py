# Vikunja due dates -> Radicale calendars (task-deadlines.nix).
#
# Reads $DB, the copy of Kvasir's Vikunja database that its backup timer
# sends here through Syncthing (_sync.nix "Vikunja"), read-only. Every open
# task with a due date becomes a 30-minute event at that time (Vikunja keeps
# times in UTC). $CONFIG (JSON) names the calendars: a listed project sends
# its tasks there, and so do all its sub-projects (the nearest listed one
# wins); everything else goes to the default one. Archived projects and
# deleted tasks are left out. Titles read "[Project] task" unless the
# project is Inbox or the calendar is named after it. Names match ignoring
# case. Each calendar is replaced by one PUT on its collection, only when it
# differs from the last one (kept in $STATE_DIRECTORY). Any surprise exits
# non-zero, so the unit fails and alerts.

import base64
import hashlib
import json
import os
import re
import sqlite3
import sys
import urllib.request
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import NoReturn

DB = Path(os.environ["DB"])
# {"url": ".../xin/", "user", "default": {"collection", "name"},
#  "calendars": {collection: {"name", "projects": [title, ...]}}}
CONFIG = json.loads(Path(os.environ["CONFIG"]).read_text())
PASSWORD = (Path(os.environ["CREDENTIALS_DIRECTORY"]) / "radicale").read_text().strip()
STATE = Path(os.environ["STATE_DIRECTORY"])


def die(msg) -> NoReturn:
    print(f"task-deadlines: {msg}", file=sys.stderr)
    sys.exit(1)


def load():
    if not DB.exists():
        print(f"task-deadlines: no {DB} yet (Kvasir hasn't sent one); nothing to do")
        sys.exit(0)
    # immutable: never write a journal into the Syncthing folder
    try:
        con = sqlite3.connect(f"file:{DB}?mode=ro&immutable=1", uri=True)
        con.row_factory = sqlite3.Row
        projects = {r["id"]: dict(r) for r in con.execute(
            "SELECT id, title, parent_project_id, is_archived FROM projects")}
        tasks = [dict(r) for r in con.execute(
            "SELECT id, title, project_id, due_date, created FROM tasks "
            "WHERE NOT done AND deleted_at IS NULL "
            "AND due_date IS NOT NULL AND due_date > '1970-01-02'")]
    except sqlite3.Error as e:
        die(f"{DB}: {e}")
    return tasks, projects


def esc(s):
    return (s.replace("\\", "\\\\").replace(";", "\\;").replace(",", "\\,")
             .replace("\r\n", "\\n").replace("\n", "\\n"))


def fold(line):
    # RFC 5545: lines over 75 octets continue with a leading space
    out, b = [], line.encode()
    while len(b) > 75:
        cut = 75
        while (b[cut] & 0xC0) == 0x80:   # don't split a UTF-8 sequence
            cut -= 1
        out.append(b[:cut].decode())
        b = b" " + b[cut:]
    out.append(b.decode())
    return "\r\n".join(out)


def when(s):
    # "2026-10-11 06:55:00" (UTC; sometimes with fractions or an offset)
    try:
        d = datetime.fromisoformat(str(s).replace(" ", "T"))
    except ValueError:
        die(f"unreadable date {s!r}")
    return d if d.tzinfo else d.replace(tzinfo=timezone.utc)


def utc(d):
    return d.astimezone(timezone.utc).strftime("%Y%m%dT%H%M%SZ")


def event(t, prefix):
    due = when(t["due_date"])
    return ["BEGIN:VEVENT", f"UID:vikunja-deadline-{t['id']}@ironshark.org",
            # fixed, so unchanged tasks give byte-identical events
            f"DTSTAMP:{utc(when(t['created']))}",
            f"SUMMARY:{esc(prefix + (t['title'] or '(untitled)'))}",
            "TRANSP:TRANSPARENT",
            f"DTSTART:{utc(due)}", f"DTEND:{utc(due + timedelta(minutes=30))}",
            "END:VEVENT"]


def put(collection, name, events):
    lines = ["BEGIN:VCALENDAR", "VERSION:2.0",
             "PRODID:-//Technonomicon//task-deadlines//EN",
             f"X-WR-CALNAME:{esc(name)}"]
    for ev in events:
        lines += ev
    lines.append("END:VCALENDAR")
    ics = "\r\n".join(fold(line) for line in lines) + "\r\n"

    last = STATE / f"{collection}.sha256"
    digest = hashlib.sha256(ics.encode()).hexdigest()
    if last.exists() and last.read_text() == digest:
        return
    auth = base64.b64encode(f"{CONFIG['user']}:{PASSWORD}".encode()).decode()
    headers = {"Content-Type": "text/calendar; charset=utf-8",
               "Authorization": f"Basic {auth}"}
    req = urllib.request.Request(f"{CONFIG['url']}{collection}/",
                                 data=ics.encode(), method="PUT", headers=headers)
    with urllib.request.urlopen(req) as r:
        if r.status not in (200, 201, 204):
            die(f"Radicale PUT {collection} returned {r.status}")
    last.write_text(digest)
    print(f"task-deadlines: {collection}: {len(events)} deadline(s) written")


def main():
    tasks, projects = load()
    target = {}                         # project title -> collection
    for coll, cal in CONFIG["calendars"].items():
        for title in cal["projects"]:
            target[title.casefold()] = coll
    titles = {(p["title"] or "").casefold() for p in projects.values()}
    for title in sorted(set(target) - titles):
        print(f"task-deadlines: no project named {title!r} (tn.taskDeadlines.calendars); "
              f"projects: {sorted(titles)}", file=sys.stderr)

    default = CONFIG["default"]["collection"]
    names = {default: CONFIG["default"]["name"],
             **{c: cal["name"] for c, cal in CONFIG["calendars"].items()}}

    def route(pid):
        # (collection, archived?) from the project and its parents
        seen, archived = set(), False
        while pid in projects and pid not in seen:
            seen.add(pid)
            p = projects[pid]
            archived = archived or bool(p["is_archived"])
            coll = target.get((p["title"] or "").casefold())
            if coll:
                return coll, archived
            pid = p["parent_project_id"]
        return default, archived

    out = {coll: [] for coll in names}
    for t in sorted(tasks, key=lambda t: t["id"]):
        coll, archived = route(t["project_id"])
        if archived:
            continue
        project = (projects.get(t["project_id"]) or {}).get("title") or ""
        # the calendar's name without a leading emoji ("🔒 Academics")
        bare = re.sub(r"^\W+", "", names[coll]).casefold()
        named = project.casefold() in ("", "inbox", bare)
        out[coll].append(event(t, "" if named else f"[{project}] "))

    for coll, name in names.items():
        put(coll, name, out[coll])


main()
