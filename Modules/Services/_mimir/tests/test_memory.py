from datetime import date, timedelta

from fsrs import Rating

from helpers import STUDY, TZ, course, event, learn, skill_uuid
from mimir import catalog
from mimir.db import Override
from mimir.memory import replay

D0 = date(2026, 11, 2)
SK = "math/precalc/logs/convert"


def load(tmp_path):
    return catalog.load(course(tmp_path, [{"id": SK}]))


def test_graduation_puts_a_skill_into_fsrs(tmp_path):
    cat = load(tmp_path)
    st = replay(cat, [learn(SK, D0)], {}, STUDY, TZ)[skill_uuid(SK)]
    assert st.graduated and st.last_rating == Rating.Good
    assert st.due_day(TZ, STUDY.day_start_hour) > D0


def test_unfinished_learn_day_is_not_a_review(tmp_path):
    cat = load(tmp_path)
    ev = event(SK, D0, "New", [1.0], variants_correct=1)
    st = replay(cat, [ev], {}, STUDY, TZ)[skill_uuid(SK)]
    assert not st.graduated and st.learn_fails == 0 and st.attempted


def test_failed_learn_days_count(tmp_path):
    cat = load(tmp_path)
    evs = [event(SK, D0, "New", [0.0, 0.0], 0), event(SK, D0 + timedelta(days=1), "New", [0.0, 1.0], 1)]
    st = replay(cat, evs, {}, STUDY, TZ)[skill_uuid(SK)]
    assert st.learn_fails == 2 and not st.graduated


def test_intervals_grow_with_good_and_shrink_after_again(tmp_path):
    cat = load(tmp_path)
    evs, d = [learn(SK, D0)], D0
    dues = []
    for _ in range(4):
        st = replay(cat, evs, {}, STUDY, TZ)[skill_uuid(SK)]
        d = st.due_day(TZ, STUDY.day_start_hour)
        dues.append(d)
        evs.append(event(SK, d, "Review", [1.0]))
    gaps = [(b - a).days for a, b in zip(dues, dues[1:])]
    assert all(g2 > g1 for g1, g2 in zip(gaps, gaps[1:])), gaps
    before = replay(cat, evs, {}, STUDY, TZ)[skill_uuid(SK)].card.stability
    nxt = replay(cat, evs, {}, STUDY, TZ)[skill_uuid(SK)].due_day(TZ, STUDY.day_start_hour)
    evs.append(event(SK, nxt, "Review", [0.0, 0.0]))
    after = replay(cat, evs, {}, STUDY, TZ)[skill_uuid(SK)].card.stability
    assert after < before


def test_replay_is_deterministic(tmp_path):
    cat = load(tmp_path)
    evs = [learn(SK, D0)]
    for k in (3, 9, 25, 60):
        evs.append(event(SK, D0 + timedelta(days=k), "Review", [1.0]))
    a = replay(cat, evs, {}, STUDY, TZ)[skill_uuid(SK)].card
    b = replay(cat, list(reversed(evs)), {}, STUDY, TZ)[skill_uuid(SK)].card
    assert (a.due, a.stability, a.difficulty) == (b.due, b.stability, b.difficulty)


def test_one_event_per_skill_and_day(tmp_path):
    cat = load(tmp_path)
    first, dup = learn(SK, D0), event(SK, D0, "New", [0.0, 0.0], 0)  # e.g. a second user's instance, later
    st = replay(cat, [first, dup], {}, STUDY, TZ)[skill_uuid(SK)]
    assert st.graduated and len(st.history) == 1


def test_overrides(tmp_path):
    cat = load(tmp_path)
    d1 = D0 + timedelta(days=3)
    evs = [learn(SK, D0), event(SK, d1, "Review", [0.0, 0.0])]
    plain = replay(cat, evs, {}, STUDY, TZ)[skill_uuid(SK)]
    assert plain.last_rating == Rating.Again
    good = replay(cat, evs, {(d1, skill_uuid(SK)): Override(d1, skill_uuid(SK), "good", None)}, STUDY, TZ)
    assert good[skill_uuid(SK)].last_rating == Rating.Good
    void = replay(cat, evs, {(d1, skill_uuid(SK)): Override(d1, skill_uuid(SK), "void", None)}, STUDY, TZ)
    v = void[skill_uuid(SK)]
    assert v.last_rating == Rating.Good and v.history[-1].note == "void"
