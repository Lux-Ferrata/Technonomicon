from datetime import date

from fsrs import Rating

from helpers import STUDY, event
from mimir.grades import learn_outcome, review_rating

D = date(2026, 11, 2)


def grade(tries, duration=60, minutes=4):
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
