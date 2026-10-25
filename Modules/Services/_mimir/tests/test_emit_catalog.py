import json
from datetime import date, timedelta

import jsonschema

from helpers import STUDY, TZ, course, learn
from mimir import catalog, emit
from mimir.memory import replay
from mimir.planner import plan_day

MON = date(2026, 11, 2)
A, B = "m/p/a/one", "m/p/b/two"


def test_catalog_errors(tmp_path):
    cat = catalog.load(course(tmp_path, [
        {"id": A, "requires": ["m/p/x/missing"]},
        {"id": B, "requires": [A], "encompasses": {"m/p/b/three": 0.5}},
        {"id": "m/p/b/three", "requires": [B]},
    ]))
    text = "\n".join(cat.errors)
    assert "unknown skill m/p/x/missing" in text
    assert "prerequisite cycle" in text


def test_template_must_point_at_a_skill(tmp_path):
    root = course(tmp_path, [{"id": A}], templates={A: ["t1"], "m/p/z/ghost": ["t1"]})
    cat = catalog.load(root)
    assert any("ghost" in e for e in cat.errors)
    assert list(cat.templates) == [f"{A}/t1"]


def test_emitted_files_validate_and_set_learn_only_when_learning(tmp_path):
    cat = catalog.load(course(tmp_path, [{"id": A}, {"id": B}]))
    st = replay(cat, [learn(A, MON)], {}, STUDY, TZ)
    day = st[cat.skills[A].uuid].due_day(TZ, STUDY.day_start_hour)
    plan = plan_day(cat, st, STUDY, TZ, day)
    assert sorted(i.zone for i in plan.items) == ["New", "Review"]
    gen = tmp_path / "generated"
    emit.ensure_course_instance(gen, "America/Phoenix")
    tid = emit.tid_for(day, "daily", set())
    path = emit.write_assessment(gen, cat, plan, tid, STUDY)
    a = json.loads(path.read_text())
    jsonschema.validate(a, emit.schema("infoAssessment"))
    jsonschema.validate(json.loads((gen / "Practice" / "infoCourseInstance.json").read_text()),
                        emit.schema("infoCourseInstance"))
    zones = {z["title"]: z["questions"] for z in a["zones"]}
    assert zones["Review"][0] == {"id": f"{A}/t1", "autoPoints": 1, "triesPerVariant": 2, "maxAutoPoints": 1}
    assert zones["New"][0]["preferences"] == {"learn": True} and zones["New"][0]["maxAutoPoints"] == 2
    ac = a["accessControl"][0]["dateControl"]
    assert ac["release"]["date"] == f"{day.isoformat()}T04:00:00"
    assert ac["due"]["date"] == f"{(day + timedelta(days=1)).isoformat()}T04:00:00"


def test_tids_and_stable_uuids():
    assert emit.tid_for(MON, "daily", set()) == "2026-11-02"
    assert emit.tid_for(MON, "more", {"2026-11-02", "2026-11-02-more1"}) == "2026-11-02-more2"
    assert emit.course_instance("America/Phoenix")["uuid"] == emit.course_instance("UTC")["uuid"]


def test_prune_keeps_recent_and_unfinished(tmp_path):
    root = tmp_path / "Practice" / "assessments"
    for tid in ("2026-10-01", "2026-10-02", "2026-11-01"):
        (root / tid).mkdir(parents=True)
    removed = emit.prune(tmp_path, MON, final_tids={"2026-10-01", "2026-11-01"})
    assert removed == ["2026-10-01"]
    assert sorted(p.name for p in root.iterdir()) == ["2026-10-02", "2026-11-01"]
