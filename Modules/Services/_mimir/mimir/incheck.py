"""Exercise Mimir templates across seeds. Runs INSIDE the pinned PrairieLearn image.

`mimir lint` mounts the course at /course and this file at /mimir/incheck.py,
then runs it with PL's own interpreter and Python library:

    PYTHONPATH=/PrairieLearn/apps/prairielearn/python \
        /PrairieLearn/.venv/bin/python3.13 /mimir/incheck.py --seeds 200 QID...

For every template and seed it mirrors the question server: seed `random` and
`numpy.random`, call generate() (half the seeds in learn mode when the
template declares it), then prepare(). It checks that params and correct
answers are JSON-safe, that every answers-name in question.html (rendered with
the variant's data, as PL's Mustache does) has a correct answer, and that
generate() is fast. Each dynamic figure in question.html is
fetched through file() and must come back as a non-empty image. Then, freshly
seeded, make() + self_check(): the template's independent check of its own
answer. A seed that runs past HANG_S (an endless loop) fails the template and
stops its check, so one bad template can't stall the rest.

Standard library, numpy and chevron only (it can't import the mimir package). Prints one
JSON object: {qid: {"ok": n, "failures": [...], "max_ms": t}}.
"""

import argparse
import importlib.util
import json
import random
import re
import signal
import sys
import time
import traceback
from pathlib import Path

import chevron
import numpy as np

SLOW_MS = 2000  # PL's question timeout is a few seconds; stay well under it
HANG_S = 10  # per seed and phase; past this it's an endless loop, not slowness
ANSWERS_NAME = re.compile(r'answers-name\s*=\s*"([^"]+)"')
DYNAMIC_FILE = re.compile(r"<pl-(?:figure|file-download)\b[^>]*>")
NO_CORRECT_NEEDED = ("pl-file-editor", "pl-file-upload", "pl-rich-text-editor", "pl-image-capture",
                     "pl-excalidraw", "pl-workspace",
                     # the correct answer is in the markup
                     "pl-checkbox", "pl-multiple-choice", "pl-dropdown", "pl-matching", "pl-order-blocks")


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


def answer_type_errors(html: str, correct: dict) -> list:
    """Correct answers of the wrong type crash the element at grading time
    (e.g. a bare int for pl-symbolic-input, which wants a string or sympy JSON)."""
    wants = {"pl-symbolic-input": (lambda v: isinstance(v, (str, dict)), "a string or sympy JSON (pl.to_json of a sympy object)"),
             "pl-number-input": (lambda v: isinstance(v, (int, float, dict)) and not isinstance(v, bool), "an int or float"),
             "pl-integer-input": (lambda v: isinstance(v, (int, str)) and not isinstance(v, bool), "an int")}
    errors = []
    for m in ANSWERS_NAME.finditer(html):
        start = html.rfind("<", 0, m.start())
        tag = html[start + 1:m.start()].split()[0] if start >= 0 else ""
        name = m.group(1)
        if tag in wants and name in correct and not wants[tag][0](correct[name]):
            errors.append(f"{tag} {name!r}: correct answer is {type(correct[name]).__name__}, needs {wants[tag][1]}")
    return errors


def dynamic_files(html: str) -> list:
    """file-name values of the dynamic figures and downloads, served by file()."""
    names = []
    for tag in DYNAMIC_FILE.findall(html):
        name = re.search(r'file-name\s*=\s*"([^"]+)"', tag)
        if name and re.search(r'type\s*=\s*"dynamic"', tag):
            names.append(name.group(1))
    return names


class Hang(BaseException):
    """Raised by the alarm; a BaseException so a template's own except can't swallow it."""


def on_alarm(signum, frame):
    raise Hang


def limited(fn, *args):
    signal.setitimer(signal.ITIMER_REAL, HANG_S)
    try:
        return fn(*args)
    finally:
        signal.setitimer(signal.ITIMER_REAL, 0)


def file_bytes(val) -> bytes:
    """file()'s return value as PL's zygote reads it."""
    if val is None:
        return b""
    if hasattr(val, "read"):
        val.seek(0)
        val = val.read()
    return val.encode() if isinstance(val, str) else bytes(val)


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
    has_file = hasattr(mod, "file")
    if dynamic_files(html) and not has_file:
        fail(None, f"dynamic files {dynamic_files(html)} but no file() in server.py")
    has_self_check = hasattr(mod, "make") and hasattr(mod, "self_check")
    if not has_self_check:
        fail(None, "no make()/self_check(): every template needs an independent check")

    for seed in range(1, seeds + 1):
        prefs = dict(declared)
        if "learn" in prefs:
            prefs["learn"] = seed % 2 == 0
        phase = "generate"
        try:
            random.seed(seed)
            np.random.seed(seed)
            data = blank(seed, prefs)
            t0 = time.perf_counter()
            limited(mod.generate, data)
            if hasattr(mod, "prepare"):
                phase = "prepare"
                limited(mod.prepare, data)
            ms = (time.perf_counter() - t0) * 1000
            out["max_ms"] = max(out["max_ms"], round(ms, 1))
            phase = "JSON-safe params and answers"
            json.dumps(data["params"])
            json.dumps(data["correct_answers"])
            phase = "render question.html"
            rendered = chevron.render(html, data)
            missing = needed_answers(rendered) - set(data["correct_answers"])
            if missing:
                fail(seed, f"no correct answer for {sorted(missing)}")
                continue
            wrong_type = answer_type_errors(rendered, data["correct_answers"])
            if wrong_type:
                fail(seed, "; ".join(wrong_type))
                continue
            figures = dynamic_files(rendered) if has_file else []  # names may come from Mustache
            if ms > SLOW_MS:
                fail(seed, f"generate()+prepare() took {ms:.0f} ms")
                continue
            for name in figures:
                phase = f"file({name})"
                random.seed(seed)
                np.random.seed(seed)
                fdata = {**data, "filename": name}
                t0 = time.perf_counter()
                body = file_bytes(limited(mod.file, fdata))
                fms = (time.perf_counter() - t0) * 1000
                if not body or (name.endswith(".png") and not body.startswith(b"\x89PNG")):
                    fail(seed, f"file() returned no image for {name} ({len(body)} bytes)")
                    break
                if fms > SLOW_MS:
                    fail(seed, f"file() took {fms:.0f} ms for {name}")
                    break
            else:
                phase = "self_check"
                if has_self_check:
                    random.seed(seed)
                    np.random.seed(seed)
                    limited(lambda: mod.self_check(mod.make()))
                out["ok"] += 1
        except Hang:
            fail(seed, f"{phase} ran past {HANG_S} s (an endless loop?); stopped checking this template")
            break
        except Exception:
            fail(seed, phase, traceback.format_exc())
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--course", default="/course")
    ap.add_argument("--seeds", type=int, default=200)
    ap.add_argument("qids", nargs="+")
    a = ap.parse_args()
    course = Path(a.course)
    signal.signal(signal.SIGALRM, on_alarm)
    report = {qid: check_template(course, qid, a.seeds) for qid in a.qids}
    print(json.dumps(report))


if __name__ == "__main__":
    main()
