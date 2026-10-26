"""Settings: study settings from the course's practice.toml, deployment from the environment."""

import os
import tomllib
from dataclasses import dataclass
from datetime import date, datetime, time, timedelta, timezone
from pathlib import Path
from zoneinfo import ZoneInfo

WEEKDAYS = ("Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun")


@dataclass(frozen=True)
class Study:
    """practice.toml: read on every run, so changes need no deploy."""

    budget_minutes: float = 30
    new_per_day: int = 3
    retention: float = 0.85
    max_interval_days: int = 365
    grading: str = "self"  # "self": Pass/Fail after showing the solution (Anki style); "auto": PL grades typed answers
    slow_factor: float = 2.0
    partial_hard: float = 0.5
    long_threshold: float = 20
    long_days: tuple[str, ...] = ("Sat",)
    long_max: int = 2
    day_start_hour: int = 4


def load_study(course: Path) -> Study:
    path = course / "practice.toml"
    if not path.exists():
        return Study()
    t = tomllib.loads(path.read_text())
    b, m, g, lg, d = (t.get(k, {}) for k in ("budget", "memory", "grades", "long", "day"))
    s = Study()
    days = tuple(lg.get("days", s.long_days))
    bad = [x for x in days if x not in WEEKDAYS]
    if bad:
        raise ValueError(f"practice.toml: long.days has {bad}; use {', '.join(WEEKDAYS)}")
    grading = str(g.get("mode", s.grading))
    if grading not in ("self", "auto"):
        raise ValueError(f'practice.toml: grades.mode is "{grading}"; use "self" or "auto"')
    return Study(
        budget_minutes=float(b.get("minutes", s.budget_minutes)),
        new_per_day=int(b.get("new_per_day", s.new_per_day)),
        retention=float(m.get("retention", s.retention)),
        max_interval_days=int(m.get("max_interval_days", s.max_interval_days)),
        grading=grading,
        slow_factor=float(g.get("slow_factor", s.slow_factor)),
        partial_hard=float(g.get("partial_hard", s.partial_hard)),
        long_threshold=float(lg.get("threshold_minutes", s.long_threshold)),
        long_days=days,
        long_max=int(lg.get("max", s.long_max)),
        day_start_hour=int(d.get("start_hour", s.day_start_hour)),
    )


@dataclass(frozen=True)
class Env:
    """Where things are. The Tn-mimir module sets these; defaults suit a checkout."""

    course: Path
    generated: Path
    state: Path
    pl_url: str
    token_file: Path | None
    tz: ZoneInfo
    pl_image: str
    remote: str | None
    learn_url: str
    author_url: str

    @property
    def db_path(self) -> Path:
        return self.state / "mimir.db"

    def token(self) -> str:
        if self.token_file is None:
            raise SystemExit("MIMIR_PL_TOKEN_FILE is not set")
        return self.token_file.read_text().strip()


def load_env() -> Env:
    e = os.environ.get
    home = Path.home()
    tok = e("MIMIR_PL_TOKEN_FILE")
    return Env(
        course=Path(e("MIMIR_COURSE", str(home / "Projects" / "Mimir"))),
        generated=Path(e("MIMIR_GENERATED", "/srv/mimir/generated")),
        state=Path(e("MIMIR_STATE", "/srv/mimir/state")),
        pl_url=e("MIMIR_PL_URL", "http://127.0.0.1:3060").rstrip("/"),
        token_file=Path(tok) if tok else None,
        tz=ZoneInfo(e("MIMIR_TZ", "America/Phoenix")),
        pl_image=e("MIMIR_PL_IMAGE", ""),
        remote=e("MIMIR_REMOTE") or None,
        learn_url=e("MIMIR_LEARN_URL", "https://learn.ironshark.org").rstrip("/"),
        author_url=e("MIMIR_AUTHOR_URL", "https://pl.ironshark.org").rstrip("/"),
    )


# ── the practice day: 04:00 to 04:00 local ──────────────────────────────
def day_start(d: date, tz: ZoneInfo, hour: int) -> datetime:
    """The UTC instant a practice day begins."""
    return datetime.combine(d, time(hour), tzinfo=tz).astimezone(timezone.utc)


def practice_day(t: datetime, tz: ZoneInfo, hour: int) -> date:
    local = t.astimezone(tz)
    return (local - timedelta(hours=hour)).date()


def today(tz: ZoneInfo, hour: int) -> date:
    return practice_day(datetime.now(timezone.utc), tz, hour)


def local_stamp(d: date, hour: int) -> str:
    """PL's local datetime format for accessControl dates."""
    return f"{d.isoformat()}T{hour:02d}:00:00"
