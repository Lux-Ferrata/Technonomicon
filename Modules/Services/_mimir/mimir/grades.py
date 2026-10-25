"""From what happened in PL to an FSRS grade (judged on the first variant).

| Outcome                                                          | Grade |
| fully right on try 1, within slow_factor x minutes               | Good  |
| right but slow; right only on try 2; best partial >= partial_hard | Hard  |
| anything worse                                                   | Again |

Later variants the same day are relearning: they don't change the grade.
Easy is never automatic. New skills enter FSRS on the day they reach their
`learn` count of correct variants: Good if that day's first variant was right
on try 1, otherwise Hard.
"""

from dataclasses import dataclass

from fsrs import Rating

from .config import Study
from .db import Event

FULL = 0.9999  # a score counts as fully right at or above this


def review_rating(ev: Event, minutes: float, study: Study) -> Rating | None:
    if not ev.tries:
        return None
    first, best = ev.tries[0], max(ev.tries[:2])
    if first >= FULL:
        slow = ev.duration_s is not None and minutes > 0 and ev.duration_s > study.slow_factor * minutes * 60
        return Rating.Hard if slow else Rating.Good
    if len(ev.tries) > 1 and ev.tries[1] >= FULL:
        return Rating.Hard
    if best >= study.partial_hard:
        return Rating.Hard
    return Rating.Again


@dataclass
class LearnOutcome:
    graduated: bool
    rating: Rating | None  # the first FSRS grade when graduated
    failed: bool           # a wrong first variant and no graduation (counts toward remediation)


def learn_outcome(ev: Event, learn: int) -> LearnOutcome | None:
    if not ev.tries:
        return None
    if ev.variants_correct >= learn:
        return LearnOutcome(True, Rating.Good if ev.tries[0] >= FULL else Rating.Hard, False)
    return LearnOutcome(False, None, ev.tries[0] < FULL)


RATINGS = {"again": Rating.Again, "hard": Rating.Hard, "good": Rating.Good, "easy": Rating.Easy}
