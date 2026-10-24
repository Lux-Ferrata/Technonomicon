"""Exercise Mimir templates across seeds. Runs INSIDE the pinned PrairieLearn image.

`mimir lint` mounts the course at /course and this file at /mimir/incheck.py,
then runs it with PL's own interpreter and Python library:

    PYTHONPATH=/PrairieLearn/apps/prairielearn/python \
        /PrairieLearn/.venv/bin/python3.13 /mimir/incheck.py --seeds 200 QID...

For every template and seed it mirrors the question server: seed `random` and
`numpy.random`, call generate() (half the seeds in learn mode when the
template declares it), then prepare(). It checks that params and correct
answers are JSON-safe, that every answers-name in question.html has a correct
answer, and that generate() is fast. Then, freshly seeded, make() +
self_check(): the template's independent check of its own answer.

Standard library + numpy only (it can't import the mimir package). Prints one
JSON object: {qid: {"ok": n, "failures": [...], "max_ms": t}}.
"""

import argparse
import importlib.util
import json
import random
import re
import sys
import time
import traceback
from pathlib import Path

import numpy as np

SLOW_MS = 2000  # PL's question timeout is a few seconds; stay well under it
ANSWERS_NAME = re.compile(r'answers-name\s*=\s*"([^"]+)"')
NO_CORRECT_NEEDED = ("pl-file-editor", "pl-file-upload", "pl-rich-text-editor", "pl-image-capture",
                     "pl-excalidraw", "pl-workspace")


def load_module(qdir: Path, course: Path):
    """Import server.py the way PL's zygote does: question dir, then serverFilesCourse."""
    added = [str(qdir), str(course / "serverFilesCourse")]
    sys.path[:0] = added
    try:
        name = "mimir_q_" + re.sub(r"\W", "_", qdir.as_posix())
        spec = importlib.util.spec_from_file_location(name, qdir / "server.py")
        mod = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(mod)
        return mod
    finally:
        for p in added:
            sys.path.remove(p)


def needed_answers(html: str) -> set:
    """answers-name values whose element needs data["correct_answers"]."""
    names = set()
    for m in ANSWERS_NAME.finditer(html):
        start = html.rfind("<", 0, m.start())
        tag = html[start + 1:m.start()].split()[0] if start >= 0 else ""
        if not tag.startswith(NO_CORRECT_NEEDED):
            names.add(m.group(1))
    return names


def blank(seed: int, prefs: dict) -> dict:
    return {"params": {}, "correct_answers": {}, "submitted_answers": {}, "format_errors": {},
            "partial_scores": {}, "score": 0, "feedback": {}, "variant_seed": seed,
            "options": {}, "answers_names": {}, "preferences": prefs}


def check_template(course: Path, qid: str, seeds: int) -> dict:
    qdir = course / "questions" / qid
    out = {"ok": 0, "failures": [], "max_ms": 0.0}

    def fail(seed, what, err=None):
        if len(out["failures"]) < 5:
            out["failures"].append({"seed": seed, "what": what,
                                    "error": (err or "").strip().splitlines()[-6:]})

    try:
        info = json.loads((qdir / "info.json").read_text())
        html = (qdir / "question.html").read_text()
        mod = load_module(qdir, course)
    except Exception:
        fail(None, "load", traceback.format_exc())
        return out

    declared = {k: v.get("default") for k, v in (info.get("preferences") or {}).items()}
    needed = needed_answers(html)
    has_self_check = hasattr(mod, "make") and hasattr(mod, "self_check")
    if not has_self_check:
        fail(None, "no make()/self_check(): every template needs an independent check")

    for seed in range(1, seeds + 1):
        prefs = dict(declared)
        if "learn" in prefs:
            prefs["learn"] = seed % 2 == 0
        try:
            random.seed(seed)
            np.random.seed(seed)
            data = blank(seed, prefs)
            t0 = time.perf_counter()
            mod.generate(data)
            if hasattr(mod, "prepare"):
                mod.prepare(data)
            ms = (time.perf_counter() - t0) * 1000
            out["max_ms"] = max(out["max_ms"], round(ms, 1))
            json.dumps(data["params"])
            json.dumps(data["correct_answers"])
            missing = needed - set(data["correct_answers"])
            if missing:
                fail(seed, f"no correct answer for {sorted(missing)}")
                continue
            if ms > SLOW_MS:
                fail(seed, f"generate()+prepare() took {ms:.0f} ms")
                continue
        except Exception:
            fail(seed, "generate", traceback.format_exc())
            continue
        if has_self_check:
            try:
                random.seed(seed)
                np.random.seed(seed)
                mod.self_check(mod.make())
            except Exception:
                fail(seed, "self_check", traceback.format_exc())
                continue
        out["ok"] += 1
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--course", default="/course")
    ap.add_argument("--seeds", type=int, default=200)
    ap.add_argument("qids", nargs="+")
    a = ap.parse_args()
    course = Path(a.course)
    report = {qid: check_template(course, qid, a.seeds) for qid in a.qids}
    print(json.dumps(report))


if __name__ == "__main__":
    main()
