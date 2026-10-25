from datetime import date

from fsrs import Rating

from helpers import STUDY, event
from mimir.grades import learn_outcome, review_rating

D = date(2026, 11, 2)


def grade(tries, duration: float | None = 60, minutes=4):
    return review_rating(event("a/b/c/d", D, "Review", tries, duration_s=duration), minutes, STUDY)


def test_grade_table():
    assert grade([1.0]) == Rating.Good
    assert grade([1.0], duration=4 * 60 * 2.5) == Rating.Hard          # right but slow
    assert grade([0.0, 1.0]) == Rating.Hard                             # a fixed slip
    assert grade([0.6]) == Rating.Hard                                  # partial >= 0.5
    assert grade([0.3, 0.5]) == Rating.Hard                             # best partial >= 0.5
    assert grade([0.0, 0.0]) == Rating.Again
    assert grade([0.4]) == Rating.Again
    assert grade([]) is None


def test_slow_needs_a_duration():
    assert grade([1.0], duration=None) == Rating.Good


def test_learn_outcomes():
    ok = learn_outcome(event("a/b/c/d", D, "New", [1.0], variants_correct=2, variants=2), learn=2)
    assert ok.graduated and ok.rating == Rating.Good
    slip = learn_outcome(event("a/b/c/d", D, "New", [0.0, 1.0], variants_correct=2, variants=3), learn=2)
    assert slip.graduated and slip.rating == Rating.Hard
    short = learn_outcome(event("a/b/c/d", D, "New", [1.0], variants_correct=1), learn=2)
    assert not short.graduated and not short.failed
    fail = learn_outcome(event("a/b/c/d", D, "New", [0.0, 0.0], variants_correct=0), learn=2)
    assert not fail.graduated and fail.failed


def self_graded(tries, duration: float | None = 60, minutes=4):
    ev = event("a/b/c/d", D, "Review", tries, duration_s=duration, grader="self")
    return review_rating(ev, minutes, STUDY)


def test_self_graded_is_pass_fail():
    assert self_graded([1.0]) == Rating.Good
    assert self_graded([1.0], duration=4 * 60 * 10) == Rating.Good    # no time rule: a pass is a pass
    assert self_graded([0.0]) == Rating.Again
    assert self_graded([0.0, 1.0]) == Rating.Again                    # the first variant decides
    assert self_graded([]) is None


def test_self_graded_learning():
    ok = learn_outcome(event("a/b/c/d", D, "New", [1.0], variants_correct=2, variants=2, grader="self"), learn=2)
    assert ok.graduated and ok.rating == Rating.Good
    slip = learn_outcome(event("a/b/c/d", D, "New", [0.0], variants_correct=2, variants=3, grader="self"), learn=2)
    assert slip.graduated and slip.rating == Rating.Again              # pass/fail has no Hard


def test_grading_mode_from_practice_toml(tmp_path):
    import pytest

    from mimir.config import load_study

    assert load_study(tmp_path).grading == "self"
    (tmp_path / "practice.toml").write_text('[grades]\nmode = "auto"\n')
    assert load_study(tmp_path).grading == "auto"
    (tmp_path / "practice.toml").write_text('[grades]\nmode = "sometimes"\n')
    with pytest.raises(ValueError):
        load_study(tmp_path)


def test_ingest_tags_self_graded_reviews():
    from mimir.ingest import _event

    q = {"instance_question_id": 7, "zone_title": "Review", "question_name": "a/b/c/d/t1", "duration_seconds": 30}
    sub = {"graded_at": "2026-11-02T19:00:00+00:00", "score": 1.0, "date": "2026-11-02T19:00:00+00:00",
           "submission_id": "1", "variant_number": 1, "submitted_answer": {"selfgrade": "pass"}}
    ev = _event("2026-11-02-daily1", D, q, [sub], ("u", "a/b/c/d"), False)
    assert ev.grader == "self" and ev.tries == [1.0]
    typed = dict(sub, submitted_answer={"ans": "x"})
    assert _event("2026-11-02-daily1", D, q, [typed], ("u", "a/b/c/d"), False).grader == "internal"
