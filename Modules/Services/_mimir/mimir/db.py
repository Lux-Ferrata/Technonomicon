"""The review log: Mimir's system of record (SQLite).

events     one row per practiced instance question (idempotent by PL's
           instance_question_id), with the raw tries; grades are derived on
           every replay, so changing thresholds recomputes history
overrides  manual corrections (mimir override): a grade, or void
plans      what each generated assessment contained (template rotation, `why`)
meta       small facts (PL course-instance id, finalized assessments)
"""

import json
import sqlite3
from contextlib import closing
from dataclasses import dataclass
from datetime import date, datetime, timezone
from pathlib import Path

SCHEMA = """
CREATE TABLE IF NOT EXISTS events (
  iq_id            INTEGER PRIMARY KEY,   -- PL instance_question_id
  assessment_tid   TEXT NOT NULL,
  day              TEXT NOT NULL,         -- practice day, YYYY-MM-DD
  zone             TEXT NOT NULL,         -- Review | New | Long
  skill_uuid       TEXT NOT NULL,
  skill_id         TEXT NOT NULL,
  template_qid     TEXT NOT NULL,
  tries            TEXT NOT NULL,         -- JSON: graded scores on the first variant, in order
  variants_correct INTEGER NOT NULL,
  variants         INTEGER NOT NULL,
  duration_s       REAL,
  first_graded_at  TEXT,
  grader           TEXT NOT NULL DEFAULT 'internal',
  final            INTEGER NOT NULL DEFAULT 0,
  updated_at       TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS overrides (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  day        TEXT NOT NULL,
  skill_uuid TEXT NOT NULL,
  rating     TEXT NOT NULL CHECK (rating IN ('again', 'hard', 'good', 'easy', 'void')),
  note       TEXT,
  created_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS plans (
  assessment_tid TEXT NOT NULL,
  day            TEXT NOT NULL,
  skill_uuid     TEXT NOT NULL,
  template_qid   TEXT NOT NULL,
  zone           TEXT NOT NULL,
  reason         TEXT,
  PRIMARY KEY (assessment_tid, skill_uuid)
);
CREATE TABLE IF NOT EXISTS meta (key TEXT PRIMARY KEY, value TEXT NOT NULL);
"""


@dataclass
class Event:
    iq_id: int
    assessment_tid: str
    day: date
    zone: str
    skill_uuid: str
    skill_id: str
    template_qid: str
    tries: list[float]
    variants_correct: int
    variants: int
    duration_s: float | None
    first_graded_at: datetime | None
    grader: str = "internal"
    final: bool = False


@dataclass
class Override:
    day: date
    skill_uuid: str
    rating: str
    note: str | None


@dataclass
class PlanRow:
    assessment_tid: str
    day: date
    skill_uuid: str
    template_qid: str
    zone: str
    reason: str | None


def now() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


class Log:
    def __init__(self, path: Path):
        path.parent.mkdir(parents=True, exist_ok=True)
        self.con = sqlite3.connect(path)
        self.con.execute("PRAGMA journal_mode=WAL")
        self.con.executescript(SCHEMA)

    def close(self):
        self.con.close()

    # ── events ──────────────────────────────────────────────────────────
    def upsert_event(self, e: Event) -> bool:
        """Insert or refresh an event; returns True if anything changed. Final rows stay final."""
        old = self.con.execute("SELECT tries, variants_correct, variants, final FROM events WHERE iq_id = ?",
                               (e.iq_id,)).fetchone()
        row = (e.iq_id, e.assessment_tid, e.day.isoformat(), e.zone, e.skill_uuid, e.skill_id, e.template_qid,
               json.dumps(e.tries), e.variants_correct, e.variants, e.duration_s,
               e.first_graded_at.isoformat() if e.first_graded_at else None, e.grader, int(e.final), now())
        if old and old[3] and (json.loads(old[0]), old[1], old[2]) == (e.tries, e.variants_correct, e.variants):
            return False
        with self.con:
            self.con.execute(
                "INSERT INTO events VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?) ON CONFLICT(iq_id) DO UPDATE SET "
                "tries=excluded.tries, variants_correct=excluded.variants_correct, variants=excluded.variants, "
                "duration_s=excluded.duration_s, first_graded_at=excluded.first_graded_at, "
                "final=MAX(events.final, excluded.final), updated_at=excluded.updated_at", row)
        return old is None or (json.loads(old[0]), old[1], old[2]) != (e.tries, e.variants_correct, e.variants)

    def events(self) -> list[Event]:
        rows = self.con.execute(
            "SELECT iq_id, assessment_tid, day, zone, skill_uuid, skill_id, template_qid, tries, "
            "variants_correct, variants, duration_s, first_graded_at, grader, final FROM events "
            "ORDER BY day, first_graded_at, iq_id").fetchall()
        return [Event(r[0], r[1], date.fromisoformat(r[2]), r[3], r[4], r[5], r[6], json.loads(r[7]), r[8], r[9],
                      r[10], datetime.fromisoformat(r[11]) if r[11] else None, r[12], bool(r[13])) for r in rows]

    def final_tids(self) -> set[str]:
        row = self.get_meta("final_tids")
        return set(json.loads(row)) if row else set()

    def mark_final(self, tids: set[str]) -> None:
        self.set_meta("final_tids", json.dumps(sorted(self.final_tids() | tids)))
        with self.con:
            self.con.executemany("UPDATE events SET final = 1 WHERE assessment_tid = ?", [(t,) for t in tids])

    # ── overrides ───────────────────────────────────────────────────────
    def add_override(self, day: date, skill_uuid: str, rating: str, note: str | None) -> None:
        with self.con:
            self.con.execute("INSERT INTO overrides (day, skill_uuid, rating, note, created_at) VALUES (?,?,?,?,?)",
                             (day.isoformat(), skill_uuid, rating, note, now()))

    def overrides(self) -> dict[tuple[date, str], Override]:
        """Latest override per (day, skill)."""
        out = {}
        for d, u, r, n in self.con.execute("SELECT day, skill_uuid, rating, note FROM overrides ORDER BY id"):
            out[(date.fromisoformat(d), u)] = Override(date.fromisoformat(d), u, r, n)
        return out

    # ── plans ───────────────────────────────────────────────────────────
    def record_plan(self, rows: list[PlanRow]) -> None:
        with self.con:
            self.con.executemany(
                "INSERT OR REPLACE INTO plans VALUES (?,?,?,?,?,?)",
                [(r.assessment_tid, r.day.isoformat(), r.skill_uuid, r.template_qid, r.zone, r.reason) for r in rows])

    def plans(self) -> list[PlanRow]:
        return [PlanRow(t, date.fromisoformat(d), u, q, z, r) for t, d, u, q, z, r in self.con.execute(
            "SELECT assessment_tid, day, skill_uuid, template_qid, zone, reason FROM plans ORDER BY day, assessment_tid")]

    def plan_lookup(self, tid: str, qid: str) -> PlanRow | None:
        r = self.con.execute("SELECT assessment_tid, day, skill_uuid, template_qid, zone, reason FROM plans "
                             "WHERE assessment_tid = ? AND template_qid = ?", (tid, qid)).fetchone()
        return PlanRow(r[0], date.fromisoformat(r[1]), r[2], r[3], r[4], r[5]) if r else None

    def tids(self) -> set[str]:
        return {r[0] for r in self.con.execute("SELECT DISTINCT assessment_tid FROM plans")}

    # ── meta ────────────────────────────────────────────────────────────
    def get_meta(self, key: str) -> str | None:
        r = self.con.execute("SELECT value FROM meta WHERE key = ?", (key,)).fetchone()
        return r[0] if r else None

    def set_meta(self, key: str, value: str) -> None:
        with self.con:
            self.con.execute("INSERT OR REPLACE INTO meta VALUES (?, ?)", (key, value))


def open_log(path: Path) -> closing:
    return closing(Log(path))
