"""Build small synthetic courses and events for the tests."""

import json
import uuid
from datetime import date, datetime, time, timezone
from pathlib import Path
from zoneinfo import ZoneInfo

from mimir.config import Study
from mimir.db import Event

TZ = ZoneInfo("America/Phoenix")
STUDY = Study()


def course(tmp: Path, skills: list[dict], templates: dict[str, list[str]] | None = None,
           minutes: dict[str, float] | None = None) -> Path:
    """skills: dicts with id (+ requires/encompasses/minutes/learn/level/suspended);
    templates: skill id -> template slugs (default: one "t1" per skill)."""
    by_file: dict[str, list[str]] = {}
    for s in skills:
        parts = s["id"].split("/")
        f = "skills/" + "/".join(parts[:2]) + f"/{parts[2]}.toml"
        lines = ["[[skill]]", f'id = "{s["id"]}"', f'uuid = "{uuid.uuid5(uuid.NAMESPACE_URL, s["id"])}"',
                 f'title = "{s.get("title", s["id"])}"', f'level = "{s.get("level", "precalc")}"',
                 f'minutes = {s.get("minutes", 5)}', f'learn = {s.get("learn", 2)}',
                 "requires = [" + ", ".join(f'"{r}"' for r in s.get("requires", [])) + "]"]
        if s.get("encompasses"):
            lines.append("encompasses = { " + ", ".join(f'"{k}" = {v}' for k, v in s["encompasses"].items()) + " }")
        if s.get("suspended"):
            lines.append("suspended = true")
        by_file.setdefault(f, []).append("\n".join(lines))
    for f, blocks in by_file.items():
        p = tmp / f
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text("\n\n".join(blocks) + "\n")
    templates = templates if templates is not None else {s["id"]: ["t1"] for s in skills}
    for sid, slugs in templates.items():
        for slug in slugs:
            d = tmp / "questions" / sid / slug
            d.mkdir(parents=True, exist_ok=True)
            srs: dict = {"skill": sid}
            if minutes and f"{sid}/{slug}" in minutes:
                srs["minutes"] = minutes[f"{sid}/{slug}"]
            (d / "info.json").write_text(json.dumps({
                "uuid": str(uuid.uuid5(uuid.NAMESPACE_URL, f"{sid}/{slug}")), "title": slug, "topic": "T",
                "type": "v3", "comment": {"srs": srs},
                "preferences": {"learn": {"type": "boolean", "default": False},
                                "selfgrade": {"type": "boolean", "default": True}}}))
    return tmp


def skill_uuid(sid: str) -> str:
    return str(uuid.uuid5(uuid.NAMESPACE_URL, sid))


_iq = [0]


def event(sid: str, d: date, zone: str, tries: list[float], variants_correct: int | None = None,
          variants: int = 1, duration_s: float | None = 60, template: str = "t1", grader: str = "internal") -> Event:
    _iq[0] += 1
    if variants_correct is None:
        variants_correct = int(bool(tries) and max(tries) >= 1)
    when = datetime.combine(d, time(12), tzinfo=TZ).astimezone(timezone.utc)
    return Event(iq_id=_iq[0], assessment_tid=d.isoformat(), day=d, zone=zone, skill_uuid=skill_uuid(sid),
                 skill_id=sid, template_qid=f"{sid}/{template}", tries=tries, variants_correct=variants_correct,
                 variants=variants, duration_s=duration_s, first_graded_at=when, grader=grader)


def learn(sid: str, d: date, first_ok: bool = True) -> Event:
    """A learn day that graduates (2 correct variants)."""
    return event(sid, d, "New", [1.0] if first_ok else [0.0, 1.0], variants_correct=2, variants=2 if first_ok else 3)
