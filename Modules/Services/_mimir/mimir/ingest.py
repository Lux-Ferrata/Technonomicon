"""PL submissions in the generated assessments -> review-log events.

Every user's instance counts (a lost learner session must not drop reviews);
the replay keeps one event per skill and day. An assessment's events become
final once it has closed (the next day's 04:00).
"""

import re
from collections import defaultdict
from datetime import date, datetime, timedelta

from .catalog import Catalog
from .config import Env, Study, day_start
from .db import Event, Log
from .grades import FULL
from .pl import PL

TID = re.compile(r"^(\d{4}-\d{2}-\d{2})(?:-(more|long)\d+)?$")
SET_NAME = "Practice"


def tid_day(tid: str) -> date | None:
    m = TID.match(tid)
    return date.fromisoformat(m.group(1)) if m else None


def _event(tid: str, d: date, q: dict, subs: list[dict], skill: tuple[str, str], closed: bool) -> Event | None:
    graded = [s for s in subs if s.get("graded_at") and s.get("score") is not None]
    if not graded:
        return None
    graded.sort(key=lambda s: (s["date"], int(s["submission_id"])))
    by_variant: dict[int, list[dict]] = defaultdict(list)
    for s in graded:
        by_variant[int(s["variant_number"])].append(s)
    first = by_variant[min(by_variant)]
    # a Pass/Fail review (the <tn-selfgrade> element) is graded by the learner, not by PL
    selfgraded = any("selfgrade" in (s.get("submitted_answer") or {}) for s in graded)
    return Event(
        iq_id=int(q["instance_question_id"]),
        assessment_tid=tid,
        day=d,
        zone=q["zone_title"],
        skill_uuid=skill[0],
        skill_id=skill[1],
        template_qid=q["question_name"],
        tries=[float(s["score"]) for s in first],
        variants_correct=sum(1 for vs in by_variant.values() if max(float(s["score"]) for s in vs) >= FULL),
        variants=len(by_variant),
        duration_s=q.get("duration_seconds"),
        first_graded_at=datetime.fromisoformat(graded[0]["graded_at"]),
        grader="self" if selfgraded else "internal",
        final=closed,
    )


def ingest(pl: PL, ci: int, cat: Catalog, log: Log, env: Env, study: Study, now: datetime) -> dict:
    stats = {"assessments": 0, "events": 0, "changed": 0, "unknown": []}
    final = log.final_tids()
    closing = set()
    for a in pl.assessments(ci):
        tid = a["assessment_name"]
        d = tid_day(tid)
        if d is None or a.get("assessment_set_name") != SET_NAME or tid in final:
            continue
        stats["assessments"] += 1
        closed = now >= day_start(d + timedelta(days=1), env.tz, study.day_start_hour)
        for inst in pl.assessment_instances(ci, a["assessment_id"]):
            aiid = inst["assessment_instance_id"]
            subs_by_iq: dict[str, list[dict]] = defaultdict(list)
            for s in pl.submissions(ci, aiid):
                subs_by_iq[str(s["instance_question_id"])].append(s)
            for q in pl.instance_questions(ci, aiid):
                qid = q["question_name"]
                plan = log.plan_lookup(tid, qid)
                if plan:
                    sid = next((s.id for s in cat.skills.values() if s.uuid == plan.skill_uuid), plan.skill_uuid)
                    skill = (plan.skill_uuid, sid)
                elif qid in cat.templates:
                    s = cat.skills[cat.templates[qid].skill_id]
                    skill = (s.uuid, s.id)
                else:
                    stats["unknown"].append(f"{tid}:{qid}")
                    continue
                ev = _event(tid, d, q, subs_by_iq.get(str(q["instance_question_id"]), []), skill, closed)
                if ev is None:
                    continue
                stats["events"] += 1
                stats["changed"] += int(log.upsert_event(ev))
        if closed:
            closing.add(tid)
    if closing:
        log.mark_final(closing)
    return stats
