"""Plan one practice day.

1. Due short reviews (retrievability below target), lowest retrievability
   first, within the minute budget (at least one always fits).
2. New skills off the frontier, while budget and new_per_day allow.
3. On a long day (or `--long`), long skills: due ones first, then new ones.
Templates rotate: the skill's least recently used, never the last one again.
"""

import hashlib
from dataclasses import dataclass, field
from datetime import date

from fsrs import Rating

from .catalog import LEVELS, Catalog, Skill, Template
from .config import WEEKDAYS, Study
from .memory import SkillState, retrievability, scheduler

PAUSE_AFTER_FAILS = 2  # learn days ending wrong before a new skill is paused


@dataclass
class Item:
    skill: Skill
    template: Template
    zone: str  # Review | New | Long
    minutes: float
    reason: str


@dataclass
class Plan:
    day: date
    mode: str  # daily | more | long
    items: list[Item] = field(default_factory=list)
    skipped_due: int = 0  # due short reviews that didn't fit the budget

    def zone(self, z: str) -> list[Item]:
        return [i for i in self.items if i.zone == z]

    @property
    def minutes(self) -> float:
        return sum(i.minutes for i in self.items)


def is_long(cat: Catalog, s: Skill, study: Study) -> bool:
    """Long when every template of the skill targets at least the threshold."""
    ts = cat.templates_of(s.id)
    return bool(ts) and min(cat.minutes(t) for t in ts) >= study.long_threshold


def _tiebreak(*parts) -> str:
    return hashlib.sha256(":".join(map(str, parts)).encode()).hexdigest()


def choose_template(cat: Catalog, st: SkillState, s: Skill, day: date) -> Template:
    ts = cat.templates_of(s.id)
    if len(ts) == 1:
        return ts[0]
    last_used = {}
    for h in st.history:
        last_used[h.template] = h.day
    ordered = sorted(ts, key=lambda t: (last_used.get(t.qid, date.min), _tiebreak(day, s.uuid, t.qid)))
    if ordered[0].qid == st.last_template:
        return ordered[1]
    return ordered[0]


def gates_open(cat: Catalog, states: dict[str, SkillState], s: Skill) -> bool:
    for g in cat.effective_gates(s.id):
        gs = states[cat.skills[g].uuid]
        if not gs.graduated or gs.last_rating == Rating.Again:
            return False
    return True


def frontier(cat: Catalog, states: dict[str, SkillState]) -> list[Skill]:
    """New skills that may be learned now: in-learning ones first, then lower level, then most unlocks."""
    deps = cat.dependents()
    level = {lv: i for i, lv in enumerate(LEVELS)}
    out = [s for s in cat.skills.values()
           if not s.suspended and cat.has_templates(s.id) and not states[s.uuid].graduated
           and states[s.uuid].learn_fails < PAUSE_AFTER_FAILS and gates_open(cat, states, s)]
    out.sort(key=lambda s: (not states[s.uuid].attempted, level.get(s.level, 0), -len(deps[s.id]), s.id))
    return out


def paused(cat: Catalog, states: dict[str, SkillState]) -> list[Skill]:
    return [s for s in cat.skills.values()
            if not states[s.uuid].graduated and states[s.uuid].learn_fails >= PAUSE_AFTER_FAILS]


def plan_day(cat: Catalog, states: dict[str, SkillState], study: Study, tz, day: date,
             mode: str = "daily", exclude: frozenset[str] = frozenset(), new_done: int = 0) -> Plan:
    sched = scheduler(study)
    hour = study.day_start_hour
    plan = Plan(day, mode)
    usable = [s for s in cat.skills.values()
              if not s.suspended and cat.has_templates(s.id) and s.uuid not in exclude]

    due = []
    for s in usable:
        st = states[s.uuid]
        dd = st.due_day(tz, hour)
        if dd is not None and dd <= day:
            due.append((retrievability(st, day, tz, hour, sched), s))
    due.sort(key=lambda x: (x[0], x[1].id))

    if mode != "long":
        used = 0.0
        for r, s in due:
            if is_long(cat, s, study):
                continue
            t = choose_template(cat, states[s.uuid], s, day)
            m = cat.minutes(t)
            if plan.items and used + m > study.budget_minutes:
                plan.skipped_due += 1
                continue
            plan.items.append(Item(s, t, "Review", m, f"due (recall chance {r:.0%})"))
            used += m
        added = new_done
        for s in frontier(cat, states):
            if added >= study.new_per_day:
                break
            if s.uuid in exclude or is_long(cat, s, study):
                continue
            t = choose_template(cat, states[s.uuid], s, day)
            m = cat.minutes(t) * (s.learn + 0.5)
            if used + m > study.budget_minutes and plan.items:
                continue
            reason = "learning (again)" if states[s.uuid].attempted else "new"
            plan.items.append(Item(s, t, "New", m, reason))
            used += m
            added += 1

    if mode == "long" or (mode == "daily" and WEEKDAYS[day.weekday()] in study.long_days):
        want = 1 if mode == "long" else study.long_max
        longs = [(s, f"due (recall chance {r:.0%})") for r, s in due if is_long(cat, s, study)]
        longs += [(s, "new") for s in frontier(cat, states) if is_long(cat, s, study) and s.uuid not in exclude]
        for s, why in longs[:want]:
            t = choose_template(cat, states[s.uuid], s, day)
            zone = "Long"
            plan.items.append(Item(s, t, zone, cat.minutes(t), why))
    return plan
