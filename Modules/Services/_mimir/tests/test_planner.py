from dataclasses import replace
from datetime import date, timedelta

from helpers import STUDY, TZ, course, event, learn
from mimir import catalog
from mimir.memory import replay
from mimir.planner import choose_template, frontier, plan_day

MON = date(2026, 11, 2)  # a Monday
SAT = date(2026, 11, 7)
A, B, C, P = "m/p/a/one", "m/p/b/two", "m/p/c/three", "m/p/d/placeholder"


def ids(items):
    return [getattr(i, "skill", i).id for i in items]  # plan items or skills


def test_gating_and_placeholders(tmp_path):
    cat = catalog.load(course(tmp_path, [
        {"id": A}, {"id": P, "requires": [A]}, {"id": B, "requires": [P]}, {"id": C, "encompasses": {B: 1.0}},
    ], templates={A: ["t1"], B: ["t1"], C: ["t1"]}))
    assert not cat.errors, cat.errors
    st = replay(cat, [], {}, STUDY, TZ)
    assert ids(frontier(cat, st)) == [A]                 # B waits for A through the placeholder P
    st = replay(cat, [learn(A, MON)], {}, STUDY, TZ)
    assert ids(frontier(cat, st)) == [B]                 # C encompasses B, so it waits for B
    assert cat.effective_gates(B) == {A}


def test_failed_prerequisite_blocks_new_skills(tmp_path):
    cat = catalog.load(course(tmp_path, [{"id": A}, {"id": B, "requires": [A]}]))
    evs = [learn(A, MON), event(A, MON + timedelta(days=3), "Review", [0.0, 0.0])]
    assert ids(frontier(cat, replay(cat, evs, {}, STUDY, TZ))) == []


def test_reviews_first_then_new_within_budget(tmp_path):
    skills = [{"id": f"m/p/s/n{i}", "minutes": 5} for i in range(8)]
    cat = catalog.load(course(tmp_path, skills))
    evs = [learn(s["id"], MON) for s in skills[:5]]
    st = replay(cat, evs, {}, STUDY, TZ)
    far = MON + timedelta(days=60)                        # everything is due
    plan = plan_day(cat, st, STUDY, TZ, far)
    assert [i.zone for i in plan.items] == ["Review"] * 5 + ["New"] * 0  # 5 x 5 min, a new one costs 12.5
    small = replace(STUDY, budget_minutes=60)
    plan = plan_day(cat, st, small, TZ, far)
    assert [i.zone for i in plan.items].count("Review") == 5 and [i.zone for i in plan.items].count("New") == 2


def test_budget_skips_but_always_fits_one(tmp_path):
    skills = [{"id": f"m/p/s/n{i}", "minutes": 18} for i in range(3)]  # under the long threshold
    cat = catalog.load(course(tmp_path, skills))
    st = replay(cat, [learn(s["id"], MON) for s in skills], {}, STUDY, TZ)
    plan = plan_day(cat, st, STUDY, TZ, MON + timedelta(days=60))
    assert len(plan.items) == 1 and plan.skipped_due == 2


def test_long_items_only_on_the_long_day(tmp_path):
    cat = catalog.load(course(tmp_path, [{"id": A, "minutes": 40, "learn": 1}, {"id": B, "minutes": 3}]))
    st = replay(cat, [], {}, STUDY, TZ)
    assert [i.zone for i in plan_day(cat, st, STUDY, TZ, MON).items] == ["New"]
    sat = plan_day(cat, st, STUDY, TZ, SAT)
    assert sorted(i.zone for i in sat.items) == ["Long", "New"]
    on_request = plan_day(cat, st, STUDY, TZ, MON, mode="long")
    assert [i.zone for i in on_request.items] == ["Long"] and on_request.items[0].learning


def test_more_excludes_what_is_already_planned(tmp_path):
    cat = catalog.load(course(tmp_path, [{"id": A}, {"id": B}]))
    st = replay(cat, [], {}, STUDY, TZ)
    first = plan_day(cat, st, STUDY, TZ, MON)
    done = frozenset(i.skill.uuid for i in first.items)
    more = plan_day(cat, st, STUDY, TZ, MON, mode="more", exclude=done, new_done=len(first.items))
    assert not set(ids(more.items)) & set(ids(first.items))


def test_template_rotation(tmp_path):
    cat = catalog.load(course(tmp_path, [{"id": A}], templates={A: ["t1", "t2", "t3"]}))
    s = cat.skills[A]
    evs, used = [learn(A, MON)], []
    for k in range(1, 7):
        st = replay(cat, evs, {}, STUDY, TZ)[s.uuid]
        t = choose_template(cat, st, s, MON + timedelta(days=k))
        assert t.qid != st.last_template
        used.append(t.qid.rsplit("/", 1)[-1])
        evs.append(event(A, MON + timedelta(days=k), "Review", [1.0], template=used[-1]))
    assert set(used[:3]) == {"t1", "t2", "t3"} or set(used[1:4]) == {"t1", "t2", "t3"}, used
