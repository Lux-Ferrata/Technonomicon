"""mimir: plan, inspect and author the Mimir practice course.

State commands (plan, status, why, override, reload) need the review log and
PL on Akmon; on Kvasir (MIMIR_REMOTE=akmon) they run there over ssh, the way
`aku` does. Authoring commands (new, lint, preview, graph, backlog) work on
the local checkout.
"""

import argparse
import os
import shlex
import socket
import subprocess
import sys
import tomllib
from datetime import date, datetime, timedelta, timezone

from . import catalog as catalog_mod
from . import emit, graph, lint, report, scaffold
from .config import Env, load_env, load_study, today
from .db import PlanRow, open_log
from .ingest import ingest
from .memory import replay, retrievability, scheduler
from .pl import PL
from .planner import paused, plan_day

STATE_COMMANDS = {"plan", "status", "why", "override", "reload"}


def forward_if_remote(env: Env, argv: list[str]) -> None:
    if not argv or argv[0] not in STATE_COMMANDS or not env.remote:
        return
    if socket.gethostname().lower() == env.remote.lower():
        return
    os.execvp("ssh", ["ssh", "-t", env.remote, "mimir " + shlex.join(argv)])


def load_all(env: Env):
    study = load_study(env.course)
    cat = catalog_mod.load(env.course)
    return study, cat


def connect(env: Env, log) -> tuple[PL, int]:
    pl = PL(env.pl_url, env.token())
    if not pl.ping():
        raise SystemExit(f"PrairieLearn is not answering at {env.pl_url}")
    try:
        ci = pl.course_instance(log.get_meta("course_instance_id"))
    except RuntimeError:
        # first run: the Practice instance exists only once we've written it and PL has reloaded
        emit.ensure_course_instance(env.generated, env.tz.key)
        pl.reload()
        for _ in range(60):
            try:
                ci = pl.course_instance(None)
                break
            except RuntimeError:
                import time
                time.sleep(2)
        else:
            raise SystemExit("PL did not pick up the Practice course instance after a reload")
    log.set_meta("course_instance_id", str(ci))
    return pl, ci


def show_plan(plan) -> str:
    if not plan.items:
        return f"{plan.day}: nothing to practice."
    lines = [f"{emit.title(plan)}"]
    for i in plan.items:
        lines.append(f"  {i.zone:<6} {i.minutes:>4.0f} min  {i.skill.id}  [{i.template.qid.rsplit('/', 1)[-1]}]  {i.reason}")
    if plan.skipped_due:
        lines.append(f"  ({plan.skipped_due} more due reviews didn't fit the {plan.minutes:.0f}-minute budget)")
    return "\n".join(lines)


# ── commands ────────────────────────────────────────────────────────────
def cmd_plan(a, env: Env) -> int:
    study, cat = load_all(env)
    if cat.errors:
        print(f"{len(cat.errors)} catalog error(s); broken skills/templates are skipped (see `mimir lint`)",
              file=sys.stderr)
    day = date.fromisoformat(a.as_of) if a.as_of else today(env.tz, study.day_start_hour)
    mode = "more" if a.more else "long" if a.long else "daily"
    with open_log(env.db_path) as log:
        pl, ci = connect(env, log)
        stats = ingest(pl, ci, cat, log, env, study, datetime.now(timezone.utc))
        if stats["unknown"]:
            print("unknown questions in assessments (renamed or removed?):", ", ".join(stats["unknown"]),
                  file=sys.stderr)
        states = replay(cat, log.events(), log.overrides(), study, env.tz)
        planned_today = [p for p in log.plans() if p.day == day]
        tids_today = {p.assessment_tid for p in planned_today}
        if mode == "daily" and day.isoformat() in tids_today and not a.dry_run:
            print(f"Today's set {day.isoformat()} already exists; `mimir plan --more` adds an extra one.")
            return 0
        exclude = frozenset(p.skill_uuid for p in planned_today)
        new_done = sum(1 for p in planned_today if p.zone == "New")
        plan = plan_day(cat, states, study, env.tz, day, mode, exclude, new_done)
        print(show_plan(plan))
        tid = None
        if not a.dry_run and plan.items:
            tid = emit.tid_for(day, mode, log.tids())
            emit.ensure_course_instance(env.generated, env.tz.key)
            emit.write_assessment(env.generated, cat, plan, tid, study)
            log.record_plan([PlanRow(tid, day, i.skill.uuid, i.template.qid, i.zone, i.reason) for i in plan.items])
            removed = emit.prune(env.generated, day, log.final_tids())
            job = pl.reload()
            if not pl.wait_for(ci, tid):
                raise SystemExit(f"PL did not list {tid} after reloading (job {job}); check `mimir reload`")
            print(f"Written {tid}; open {env.learn_url}/pl/course_instance/{ci}/assessments")
            if removed:
                print("pruned:", ", ".join(removed))
        if not a.dry_run and mode == "daily":
            report.write_summary(env.state, report.summary(cat, states, plan, log.events(), study, env.tz, day, tid))
    return 0


def cmd_status(a, env: Env) -> int:
    study, cat = load_all(env)
    day = today(env.tz, study.day_start_hour)
    with open_log(env.db_path) as log:
        states = replay(cat, log.events(), log.overrides(), study, env.tz)
        planned = [p for p in log.plans() if p.day == day]
        events = log.events()
    done = {(e.skill_uuid) for e in events if e.day == day}
    by_uuid = cat.by_uuid()
    print(f"Practice day {day} ({env.learn_url})")
    if planned:
        for p in planned:
            s = by_uuid.get(p.skill_uuid)
            mark = "x" if p.skill_uuid in done else " "
            print(f"  [{mark}] {p.zone:<6} {s.id if s else p.skill_uuid}  ({p.assessment_tid})")
    else:
        print("  nothing planned yet (the timer runs at 04:00; `mimir plan` to plan now)")
    fc = report.forecast(cat, states, study, env.tz, day)
    print("Due per day: " + "  ".join(f"{d.strftime('%a')} {n}" for d, n in fc))
    weak = report.weakest(cat, states, study, env.tz, day)
    if weak:
        print("Weakest: " + ", ".join(f"{sid} ({r:.0%})" for r, sid in weak))
    grads = sum(1 for s in states.values() if s.graduated)
    total = sum(1 for s in cat.skills.values() if cat.has_templates(s.id))
    print(f"{grads} of {total} skills in FSRS; {sum(1 for s in cat.skills.values() if not cat.has_templates(s.id))} "
          f"placeholder skills (see `mimir backlog`)")
    for s in paused(cat, states):
        print(f"Paused (failed two learn days): {s.id}; its prerequisites need work")
    if cat.errors:
        print(f"{len(cat.errors)} catalog error(s): run `mimir lint`")
    return 0


def find_skill(cat, ident: str):
    if ident in cat.skills:
        return cat.skills[ident]
    if ident in cat.templates:
        return cat.skills[cat.templates[ident].skill_id]
    hits = [s for s in cat.skills.values() if ident in s.id]
    if len(hits) == 1:
        return hits[0]
    raise SystemExit(f"no single skill matches {ident!r}" + (f": {', '.join(s.id for s in hits)}" if hits else ""))


def cmd_why(a, env: Env) -> int:
    study, cat = load_all(env)
    s = find_skill(cat, a.id)
    day = today(env.tz, study.day_start_hour)
    with open_log(env.db_path) as log:
        states = replay(cat, log.events(), log.overrides(), study, env.tz)
    st = states[s.uuid]
    print(f"{s.title}\n  {s.id}  (uuid {s.uuid}, level {s.level}, {s.minutes:g} min, learn {s.learn})")
    gates = cat.effective_gates(s.id)
    if gates:
        print("  prerequisites: " + ", ".join(sorted(gates)))
    if s.encompasses:
        print("  encompasses: " + ", ".join(f"{k} ({v:g})" for k, v in sorted(s.encompasses.items())))
    print("  templates: " + ", ".join(t.qid.rsplit("/", 1)[-1] for t in cat.templates_of(s.id)) or "  (no templates)")
    if st.card:
        r = retrievability(st, day, env.tz, study.day_start_hour, scheduler(study))
        print(f"  FSRS: stability {st.card.stability:.1f} d, difficulty {st.card.difficulty:.2f}, "
              f"recall chance today {r:.0%}, due {st.due_day(env.tz, study.day_start_hour)}")
    else:
        print(f"  not in FSRS yet (learn fails: {st.learn_fails})")
    for h in st.history:
        g = h.rating.name if h.rating is not None else "-"
        print(f"    {h.day}  {h.zone:<6} {g:<5} {h.template.rsplit('/', 1)[-1]}  {h.note}")
    return 0


def cmd_override(a, env: Env) -> int:
    study, cat = load_all(env)
    s = find_skill(cat, a.id)
    d = date.fromisoformat(a.date)
    with open_log(env.db_path) as log:
        log.add_override(d, s.uuid, a.rating, a.note)
        states = replay(cat, log.events(), log.overrides(), study, env.tz)
    st = states[s.uuid]
    print(f"{s.id} on {d}: {a.rating}. Now due {st.due_day(env.tz, study.day_start_hour) or '(not in FSRS)'}")
    return 0


def cmd_reload(a, env: Env) -> int:
    pl = PL(env.pl_url, env.token())
    job = pl.reload()
    print(f"Reloading from disk: {env.author_url}{job.replace(env.pl_url, '')}")
    return 0


def cmd_backlog(a, env: Env) -> int:
    _, cat = load_all(env)
    deps = cat.dependents()
    rows = sorted(((len(deps[s.id]), s.id, s.title) for s in cat.skills.values() if not cat.has_templates(s.id)),
                  reverse=True)
    if not rows:
        print("Every skill has a template.")
    for n, sid, title in rows:
        print(f"  unlocks {n:>3}  {sid}  {title}")
    return 0


def cmd_graph(a, env: Env) -> int:
    _, cat = load_all(env)
    print(graph.dot(cat, None, a.around, a.depth))
    return 0


def cmd_lint(a, env: Env) -> int:
    _, cat = load_all(env)
    qids = a.ids or (sorted(cat.templates) if a.all else lint.changed_qids(env.course, cat))
    qids = [q for q in qids if q in cat.templates] + [q for q in qids if q not in cat.templates and q in
                                                      [t for s in cat.skills for t in []]]
    results = lint.run_in_image(env.pl_image, env.course, qids, a.seeds) if qids else {}
    text, ok = lint.report(cat, results, a.seeds)
    print(text or "nothing to check (no changed templates; --all checks every one)")
    return 0 if ok else 1


def cmd_new(a, env: Env) -> int:
    if a.what == "skill":
        enc = {}
        for e in a.encompasses or []:
            k, _, w = e.partition("=")
            enc[k] = float(w or 1)
        path = scaffold.new_skill(env.course, a.id, a.title, a.requires or [], enc, a.minutes, a.level, a.learn,
                                  a.tags or [])
        print(f"added {a.id} to {path.relative_to(env.course)}")
    else:
        _, cat = load_all(env)
        if a.skill not in cat.skills:
            raise SystemExit(f"unknown skill {a.skill}: add it first with `mimir new skill`")
        topic = a.topic or next((t.split(":", 1)[1] for t in cat.skills[a.skill].tags if t.startswith("topic:")), "")
        d = scaffold.new_template(env.course, a.skill, a.slug, a.kind, a.title or cat.skills[a.skill].title,
                                  topic, a.source_kind, a.cite or "TODO")
        print(f"created {d.relative_to(env.course)}/ (info.json, question.html, server.py, source/)")
    return 0


def cmd_preview(a, env: Env) -> int:
    eng = lint.engine()
    print(f"PrairieLearn on http://localhost:{a.port}/pl (Ctrl-C stops; nothing is kept)")
    cmd = [eng, "run", "--rm", "-it", "-p", f"127.0.0.1:{a.port}:3000",
           "-v", f"{env.course.resolve()}:/course:ro", env.pl_image]
    return subprocess.call(cmd)


def build_parser() -> argparse.ArgumentParser:
    ap = argparse.ArgumentParser(prog="mimir", description=__doc__.split("\n")[0])
    sub = ap.add_subparsers(dest="cmd", required=True)
    p = sub.add_parser("plan", help="ingest, replay, plan the day, write it to PL")
    p.add_argument("--dry-run", action="store_true", help="show the plan; write nothing")
    p.add_argument("--as-of", help="plan for this day (YYYY-MM-DD) instead of today")
    g = p.add_mutually_exclusive_group()
    g.add_argument("--more", action="store_true", help="an extra set of short items once today's is done")
    g.add_argument("--long", action="store_true", help="add one long item now")
    p.set_defaults(fn=cmd_plan)
    sub.add_parser("status", help="today's set, due forecast, weakest skills").set_defaults(fn=cmd_status)
    p = sub.add_parser("why", help="one skill's history and memory state")
    p.add_argument("id", help="skill id, template qid, or a unique part of an id")
    p.set_defaults(fn=cmd_why)
    p = sub.add_parser("override", help="correct a grade (void: a broken template)")
    p.add_argument("date", help="the practice day, YYYY-MM-DD")
    p.add_argument("id")
    p.add_argument("rating", choices=["again", "hard", "good", "easy", "void"])
    p.add_argument("--note")
    p.set_defaults(fn=cmd_override)
    sub.add_parser("reload", help="make PL re-read the course from disk").set_defaults(fn=cmd_reload)
    sub.add_parser("backlog", help="skills without templates, by what they unlock").set_defaults(fn=cmd_backlog)
    p = sub.add_parser("graph", help="the skill graph as Graphviz DOT")
    p.add_argument("--around", help="only this skill's neighbourhood")
    p.add_argument("--depth", type=int, default=2)
    p.set_defaults(fn=cmd_graph)
    p = sub.add_parser("lint", help="check the catalog, then run templates in the pinned PL image")
    p.add_argument("ids", nargs="*", help="template qids (default: templates with uncommitted changes)")
    p.add_argument("--all", action="store_true")
    p.add_argument("--seeds", type=int, default=200)
    p.set_defaults(fn=cmd_lint)
    p = sub.add_parser("new", help="scaffold a skill or a template")
    nsub = p.add_subparsers(dest="what", required=True)
    s = nsub.add_parser("skill")
    s.add_argument("id")
    s.add_argument("--title", required=True)
    s.add_argument("--requires", nargs="*")
    s.add_argument("--encompasses", nargs="*", help="skill=weight ...")
    s.add_argument("--minutes", type=float, default=5)
    s.add_argument("--level", default="precalc", choices=catalog_mod.LEVELS)
    s.add_argument("--learn", type=int, default=2)
    s.add_argument("--tags", nargs="*")
    s.set_defaults(fn=cmd_new)
    t = nsub.add_parser("template")
    t.add_argument("skill")
    t.add_argument("slug")
    t.add_argument("--kind", default="symbolic", choices=scaffold.KINDS)
    t.add_argument("--title")
    t.add_argument("--topic")
    t.add_argument("--source-kind", default="description", help="screenshot | pdf | description | url")
    t.add_argument("--cite")
    t.set_defaults(fn=cmd_new)
    p = sub.add_parser("preview", help="a throwaway local PL for offline authoring")
    p.add_argument("--port", type=int, default=3070)
    p.set_defaults(fn=cmd_preview)
    return ap


def main(argv: list[str] | None = None) -> int:
    argv = sys.argv[1:] if argv is None else argv
    env = load_env()
    forward_if_remote(env, argv)
    a = build_parser().parse_args(argv)
    return a.fn(a, env)


if __name__ == "__main__":
    sys.exit(main())
