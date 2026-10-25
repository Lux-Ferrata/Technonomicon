"""summary.json for the 06:00 mail, and the text of `mimir status`."""

import json
from collections import Counter
from datetime import date, datetime, timedelta, timezone
from pathlib import Path

from fsrs import Rating

from .catalog import Catalog
from .config import Study
from .db import Event
from .memory import SkillState, is_mature, pick_events, retrievability, scheduler
from .planner import Plan, paused


def summary(cat: Catalog, states: dict[str, SkillState], plan: Plan | None, events: list[Event],
            study: Study, tz, day: date, tid: str | None) -> dict:
    yday = day - timedelta(days=1)
    done = [e for e in pick_events(events) if e.day == yday]
    passed = 0
    for e in done:
        h = next((h for h in states.get(e.skill_uuid, SkillState("", "")).history if h.day == yday), None)
        passed += int(h is not None and h.rating is not None and h.rating != Rating.Again)
    graduated = [s for s in states.values() if s.graduated]
    return {
        "day": day.isoformat(),
        "assessment": tid,
        "reviews": len(plan.zone("Review")) if plan else 0,
        "new": len(plan.zone("New")) if plan else 0,
        "long": [i.skill.title for i in plan.zone("Long")] if plan else [],
        "minutes": round(plan.minutes) if plan else 0,
        "skipped_due": plan.skipped_due if plan else 0,
        "yesterday": {"done": len(done), "passed": passed},
        "mature": sum(1 for s in graduated if is_mature(s)),
        "graduated": len(graduated),
        "skills": sum(1 for s in cat.skills.values() if cat.has_templates(s.id)),
        "backlog": sum(1 for s in cat.skills.values() if not cat.has_templates(s.id)),
        "paused": [s.id for s in paused(cat, states)],
        "errors": len(cat.errors),
        "generated_at": datetime.now(timezone.utc).isoformat(timespec="seconds"),
    }


def write_summary(state_dir: Path, s: dict) -> None:
    state_dir.mkdir(parents=True, exist_ok=True)
    tmp = state_dir / "summary.json.tmp"
    tmp.write_text(json.dumps(s, indent=2) + "\n")
    tmp.chmod(0o644)
    tmp.replace(state_dir / "summary.json")


def one_line(s: dict) -> str:
    parts = [f"{s['reviews']} reviews + {s['new']} new, ~{s['minutes']} min"]
    if s["long"]:
        parts.append("+ long: " + ", ".join(s["long"]))
    y = s["yesterday"]
    parts.append(f"yesterday {y['passed']}/{y['done']}")
    parts.append(f"{s['mature']} of {s['skills']} mature")
    return " · ".join(parts)


def forecast(cat: Catalog, states: dict[str, SkillState], study: Study, tz, day: date, days: int = 7) -> list:
    c = Counter()
    for st in states.values():
        dd = st.due_day(tz, study.day_start_hour)
        if dd is not None:
            c[max(dd, day)] += 1
    return [(day + timedelta(days=i), c.get(day + timedelta(days=i), 0)) for i in range(days)]


def weakest(cat: Catalog, states: dict[str, SkillState], study: Study, tz, day: date, n: int = 5) -> list:
    sched = scheduler(study)
    by_uuid = cat.by_uuid()
    rows = [(retrievability(st, day, tz, study.day_start_hour, sched), by_uuid[u].id)
            for u, st in states.items() if st.graduated and u in by_uuid]
    return sorted(rows)[:n]
