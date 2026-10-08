# Super Productivity deadlines -> one Radicale calendar (task-deadlines.nix).
#
# Reads the newest sync-data.json under $SP_DIR (the app's WebDAV sync file:
# "pf_" + optional C (gzip, base64) / E (encrypted) flags + model version +
# "__" + JSON {version: 2, state: {task: {entities}}, ...}; the state is the
# full snapshot, rewritten on every upload). Every open task with a deadline
# becomes an event: all-day for deadlineDay, a 30-minute slot for
# deadlineWithTime. The calendar is replaced by one PUT on the collection,
# only when the result differs from the last one (kept in $STATE_DIRECTORY).
# Any format surprise exits non-zero, so the unit fails and alerts.

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

SP_DIR = Path(os.environ["SP_DIR"])
URL = os.environ["RADICALE_URL"]          # .../xin/task-deadlines/
USER = os.environ["RADICALE_USER"]
PASSWORD = (Path(os.environ["CREDENTIALS_DIRECTORY"]) / "radicale").read_text().strip()
STATE = Path(os.environ["STATE_DIRECTORY"]) / "last.sha256"
NAME = "Task Deadlines"


def die(msg):
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
        return data["state"]["task"]["entities"]
    except (KeyError, TypeError):
        die("no state.task.entities in the sync file")


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


def event(t):
    uid = f"sp-deadline-{t['id']}@ironshark.org"
    lines = ["BEGIN:VEVENT", f"UID:{uid}",
             # fixed, so unchanged tasks give byte-identical events
             f"DTSTAMP:{utc(t.get('created') or 0)}",
             f"SUMMARY:{esc(t.get('title') or '(untitled)')}",
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


def main():
    tasks = load_sync_file()
    due = [t for t in tasks.values()
           if isinstance(t, dict) and not t.get("isDone")
           and (t.get("deadlineWithTime") or t.get("deadlineDay"))]
    due.sort(key=lambda t: t["id"])
    lines = ["BEGIN:VCALENDAR", "VERSION:2.0",
             "PRODID:-//Technonomicon//task-deadlines//EN",
             f"X-WR-CALNAME:{NAME}"]
    for t in due:
        lines += event(t)
    lines.append("END:VCALENDAR")
    ics = "\r\n".join(fold(line) for line in lines) + "\r\n"

    digest = hashlib.sha256(ics.encode()).hexdigest()
    if STATE.exists() and STATE.read_text() == digest:
        return
    auth = base64.b64encode(f"{USER}:{PASSWORD}".encode()).decode()
    req = urllib.request.Request(URL, data=ics.encode(), method="PUT", headers={
        "Content-Type": "text/calendar; charset=utf-8",
        "Authorization": f"Basic {auth}",
    })
    with urllib.request.urlopen(req) as r:
        if r.status not in (200, 201, 204):
            die(f"Radicale PUT returned {r.status}")
    STATE.write_text(digest)
    print(f"task-deadlines: {len(due)} deadline(s) written")


main()
