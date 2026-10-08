# Super Productivity deadlines -> Radicale calendars (task-deadlines.nix).
#
# Reads the newest sync-data.json under $SP_DIR (the app's WebDAV sync file:
# "pf_" + optional C (gzip, base64) / E (encrypted) flags + model version +
# "__" + JSON {version: 2, state: {task: {entities}}, ...}; the state is the
# full snapshot, rewritten on every upload). Every open task with a deadline
# becomes an event: all-day for deadlineDay, a 30-minute slot for
# deadlineWithTime. $CONFIG (JSON) names the calendars: projects listed under
# a calendar go there, and so do the projects in its listed sidebar folders
# (sub-folders included; a named project beats its folder); everything else
# goes to the default one. Titles read "[Project] task" unless the calendar
# is named after the project. Names match ignoring case. Each calendar is replaced by one PUT on its collection,
# only when it differs from the last one (kept in $STATE_DIRECTORY). Any
# format surprise exits non-zero, so the unit fails and alerts.

import base64
import gzip
import hashlib
import json
import os
import re
import sys
import urllib.request
from datetime import date, datetime, timedelta, timezone
from pathlib import Path
from typing import NoReturn

SP_DIR = Path(os.environ["SP_DIR"])
# {"url": ".../xin/", "user", "default": {"collection", "name"},
#  "calendars": {collection: {"name", "projects": [title, ...], "folders": [name, ...]}}}
CONFIG = json.loads(Path(os.environ["CONFIG"]).read_text())
PASSWORD = (Path(os.environ["CREDENTIALS_DIRECTORY"]) / "radicale").read_text().strip()
STATE = Path(os.environ["STATE_DIRECTORY"])


def die(msg) -> NoReturn:
    print(f"task-deadlines: {msg}", file=sys.stderr)
    sys.exit(1)


def load_sync_file():
    files = sorted(SP_DIR.rglob("sync-data.json"), key=lambda p: p.stat().st_mtime)
    if not files:
        print("task-deadlines: no sync-data.json yet (sync not set up); nothing to do")
        sys.exit(0)
    raw = files[-1].read_text()
    m = re.match(r"pf_([CE]*)(\d+(?:\.\d+)?)__", raw)
    if not m:
        die(f"{files[-1]}: unknown prefix {raw[:20]!r}")
    flags, body = m.group(1), raw[m.end():]
    if "E" in flags:
        die("sync file is encrypted; turn off encryption in Super Productivity's sync settings")
    if "C" in flags:
        body = gzip.decompress(base64.b64decode(body)).decode()
    data = json.loads(body)
    if data.get("version") == 3 or data.get("format") == "split":
        die("sync uses the split-file format; turn off split/surgical sync files")
    if data.get("version") != 2:
        die(f"unsupported sync file version {data.get('version')!r}")
    try:
        return (data["state"]["task"]["entities"],
                data["state"]["project"]["entities"],
                # sidebar folders; optional, only folder routing needs it
                (data["state"].get("menuTree") or {}).get("projectTree") or [])
    except (KeyError, TypeError):
        die("no state.task/project.entities in the sync file")


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


def utc(ms):
    return datetime.fromtimestamp(ms / 1000, timezone.utc).strftime("%Y%m%dT%H%M%SZ")


def event(t, prefix):
    uid = f"sp-deadline-{t['id']}@ironshark.org"
    lines = ["BEGIN:VEVENT", f"UID:{uid}",
             # fixed, so unchanged tasks give byte-identical events
             f"DTSTAMP:{utc(t.get('created') or 0)}",
             f"SUMMARY:{esc(prefix + (t.get('title') or '(untitled)'))}",
             "TRANSP:TRANSPARENT"]
    if t.get("deadlineWithTime"):
        ms = t["deadlineWithTime"]
        lines += [f"DTSTART:{utc(ms)}", f"DTEND:{utc(ms + 30 * 60 * 1000)}"]
    else:
        d = date.fromisoformat(t["deadlineDay"])
        lines += [f"DTSTART;VALUE=DATE:{d:%Y%m%d}",
                  f"DTEND;VALUE=DATE:{d + timedelta(days=1):%Y%m%d}"]
    lines.append("END:VEVENT")
    return lines


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
    tasks, projects, tree = load_sync_file()
    title_of = {pid: p.get("title") or "" for pid, p in projects.items()
                if isinstance(p, dict)}
    target = {}                         # project title -> collection
    folder_target = {}                  # folder name -> collection
    for coll, cal in CONFIG["calendars"].items():
        for title in cal["projects"]:
            target[title.casefold()] = coll
        for name in cal.get("folders", []):
            folder_target[name.casefold()] = coll

    # project id -> collection, from the folders it sits in (innermost wins)
    by_folder, seen_folders = {}, set()

    def walk(nodes, coll):
        for n in nodes if isinstance(nodes, list) else []:
            if not isinstance(n, dict):
                continue
            if n.get("k") == "f":
                name = (n.get("name") or "").casefold()
                seen_folders.add(name)
                walk(n.get("children"), folder_target.get(name, coll))
            elif n.get("k") == "p" and coll:
                by_folder[n.get("id")] = coll
    walk(tree, None)

    for title in sorted(set(target) - {t.casefold() for t in title_of.values()}):
        print(f"task-deadlines: no project named {title!r} (tn.taskDeadlines.calendars)",
              file=sys.stderr)
    for name in sorted(set(folder_target) - seen_folders):
        print(f"task-deadlines: no folder named {name!r} (tn.taskDeadlines.calendars); "
              f"folders: {sorted(seen_folders)}", file=sys.stderr)

    default = CONFIG["default"]["collection"]
    out = {coll: [] for coll in [default, *CONFIG["calendars"]]}
    due = [t for t in tasks.values()
           if isinstance(t, dict) and not t.get("isDone")
           and (t.get("deadlineWithTime") or t.get("deadlineDay"))]

    names = {default: CONFIG["default"]["name"],
             **{c: cal["name"] for c, cal in CONFIG["calendars"].items()}}

    def place(item):
        pid = item.get("projectId") or ""
        project = title_of.get(pid, "")
        coll = target.get(project.casefold()) or by_folder.get(pid) or default
        # the calendar's name without a leading emoji ("🔒 Academics")
        bare = re.sub(r"^\W+", "", names[coll]).casefold()
        named = project.casefold() in ("", "inbox", bare)
        return coll, ("" if named else f"[{project}] ")

    for t in sorted(due, key=lambda t: t["id"]):
        coll, prefix = place(t)
        out[coll].append(event(t, prefix))

    put(default, CONFIG["default"]["name"], out[default])
    for coll, cal in CONFIG["calendars"].items():
        put(coll, cal["name"], out[coll])


main()
