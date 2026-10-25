"""`mimir lint`: static checks of the catalog, then every template run inside the pinned PL image."""

import json
import shutil
import subprocess
from importlib import resources
from pathlib import Path

from .catalog import Catalog

PL_PY = "/PrairieLearn/.venv/bin/python3.13"
PL_PATH = "/PrairieLearn/apps/prairielearn/python"


def engine() -> str:
    for e in ("docker", "podman"):
        if shutil.which(e) and subprocess.run([e, "info"], capture_output=True).returncode == 0:
            return e
    raise SystemExit("mimir lint needs docker or podman")


def changed_qids(course: Path, cat: Catalog) -> list[str]:
    """Templates with uncommitted changes (or untracked), plus all of them if a helper changed."""
    out = subprocess.run(["git", "-C", str(course), "status", "--porcelain", "--untracked-files=all"],
                         capture_output=True, text=True).stdout
    paths = [line[3:].strip().strip('"') for line in out.splitlines() if line.strip()]
    if any(p.startswith("serverFilesCourse/") for p in paths):
        return sorted(cat.templates)
    hit = set()
    for p in paths:
        for q in cat.templates:
            if p.startswith(f"questions/{q}/"):
                hit.add(q)
    return sorted(hit)


def run_in_image(image: str, course: Path, qids: list[str], seeds: int) -> dict:
    if not image:
        raise SystemExit("MIMIR_PL_IMAGE is not set")
    check = resources.files("mimir").joinpath("incheck.py")
    with resources.as_file(check) as check_path:
        cmd = [engine(), "run", "--rm", "--network=none",
               "-v", f"{course.resolve()}:/course:ro", "-v", f"{check_path}:/mimir/incheck.py:ro",
               "-e", f"PYTHONPATH={PL_PATH}", image, PL_PY, "/mimir/incheck.py", "--seeds", str(seeds), *qids]
        r = subprocess.run(cmd, capture_output=True, text=True)
    if r.returncode != 0:
        raise SystemExit(f"the in-image check failed:\n{r.stderr[-2000:]}")
    return json.loads(r.stdout)


def report(cat: Catalog, results: dict | None, seeds: int) -> tuple[str, bool]:
    lines, ok = [], not cat.errors
    for e in cat.errors:
        lines.append(f"error   {e}")
    for w in cat.warnings:
        lines.append(f"warning {w}")
    for qid, r in sorted((results or {}).items()):
        good = r["ok"] == seeds and not r["failures"]
        ok &= good
        lines.append(f"{'ok  ' if good else 'FAIL'}    {r['ok']:>4}/{seeds}  {r['max_ms']:>7.1f} ms  {qid}")
        for f in r["failures"][:3]:
            err = " | ".join(f["error"][-3:]) if f["error"] else ""
            lines.append(f"          seed {f['seed']}: {f['what']}  {err}")
    return "\n".join(lines), ok
