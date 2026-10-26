"""Replay the review log through FSRS into one state per skill.

Deterministic: review times are normalized to the practice day's start, and
the interval fuzz is seeded per (skill, day). So the same log, thresholds and
graph always give the same schedule, and changing any of them recomputes all
history. One event counts per skill and day (the earliest graded one).

Phase 3 (FIRe) adds implicit updates after each explicit review; those never
feed a parameter fit.
"""

import random
from dataclasses import dataclass, field
from datetime import date, datetime, timedelta

from fsrs import Card, Rating, Scheduler, State

from .catalog import Catalog
from .config import Study, day_start
from .db import Event, Override
from .grades import RATINGS, learn_outcome, review_rating


@dataclass
class Entry:
    day: date
    zone: str
    template: str
    rating: Rating | None  # None: a learn day that didn't graduate
    note: str = ""


@dataclass
class SkillState:
    uuid: str
    skill_id: str
    card: Card | None = None  # None until the skill graduates (enters FSRS)
    history: list[Entry] = field(default_factory=list)
    learn_fails: int = 0

    @property
    def graduated(self) -> bool:
        return self.card is not None

    @property
    def last_rating(self) -> Rating | None:
        rated = [h.rating for h in self.history if h.rating is not None]
        return rated[-1] if rated else None

    @property
    def last_template(self) -> str | None:
        return self.history[-1].template if self.history else None

    @property
    def attempted(self) -> bool:
        return bool(self.history)

    def due_day(self, tz, hour) -> date | None:
        """The practice day the card falls due on (it is due from that day's start)."""
        if self.card is None:
            return None
        local = self.card.due.astimezone(tz) - timedelta(hours=hour)
        return local.date()


def scheduler(study: Study) -> Scheduler:
    return Scheduler(desired_retention=study.retention, learning_steps=(), relearning_steps=(),
                     maximum_interval=study.max_interval_days, enable_fuzzing=True)


def _review(sched: Scheduler, card: Card, rating: Rating, when: datetime, seed: str) -> Card:
    random.seed(seed)  # py-fsrs fuzzes with the module-level random()
    card, _ = sched.review_card(card, rating, review_datetime=when)
    return card


def _order(e: Event) -> tuple[float, int]:
    return (e.first_graded_at.timestamp() if e.first_graded_at else float("inf"), e.iq_id)


def pick_events(events: list[Event]) -> list[Event]:
    """One event per (skill, day): the earliest graded one."""
    best: dict[tuple[str, date], Event] = {}
    for e in events:
        k = (e.skill_uuid, e.day)
        if k not in best or _order(e) < _order(best[k]):
            best[k] = e
    return sorted(best.values(), key=lambda e: (e.day, *_order(e)))


def replay(cat: Catalog, events: list[Event], overrides: dict[tuple[date, str], Override],
           study: Study, tz) -> dict[str, SkillState]:
    sched = scheduler(study)
    by_uuid = cat.by_uuid()
    states: dict[str, SkillState] = {
        s.uuid: SkillState(s.uuid, s.id) for s in cat.skills.values()
    }
    for ev in pick_events(events):
        st = states.get(ev.skill_uuid)
        if st is None:  # a skill removed from the course: its history is kept in the log only
            continue
        skill = by_uuid[ev.skill_uuid]
        when = day_start(ev.day, tz, study.day_start_hour)
        seed = f"{ev.skill_uuid}:{ev.day.isoformat()}"
        ov = overrides.get((ev.day, ev.skill_uuid))
        if ov and ov.rating == "void":
            st.history.append(Entry(ev.day, ev.zone, ev.template_qid, None, "void"))
            continue
        if not st.graduated:
            out = learn_outcome(ev, skill.learn)
            if ov:  # an override on a learn day graduates it with that grade
                st.card = _review(sched, Card(card_id=0, due=when), RATINGS[ov.rating], when, seed)
                st.history.append(Entry(ev.day, ev.zone, ev.template_qid, RATINGS[ov.rating], "override"))
            elif out is None:
                continue
            elif out.graduated:
                st.card = _review(sched, Card(card_id=0, due=when), out.rating, when, seed)
                st.history.append(Entry(ev.day, ev.zone, ev.template_qid, out.rating, "graduated"))
            else:
                st.learn_fails += int(out.failed)
                st.history.append(Entry(ev.day, ev.zone, ev.template_qid, None,
                                        "learn: wrong first variant" if out.failed else "learn: not finished"))
            continue
        minutes = cat.minutes(cat.templates[ev.template_qid]) if ev.template_qid in cat.templates else skill.minutes
        rating = RATINGS[ov.rating] if ov else review_rating(ev, minutes, study)
        if rating is None:
            continue
        st.card = _review(sched, st.card, rating, when, seed)
        st.history.append(Entry(ev.day, ev.zone, ev.template_qid, rating, "override" if ov else ""))
    return states


def retrievability(st: SkillState, d: date, tz, hour: int, sched: Scheduler) -> float:
    if st.card is None:
        return 0.0
    return sched.get_card_retrievability(st.card, current_datetime=day_start(d, tz, hour))


def is_mature(st: SkillState) -> bool:
    return st.card is not None and st.card.state == State.Review and (st.card.stability or 0) >= 21
