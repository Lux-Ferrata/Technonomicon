"""The course as Mimir sees it: skills (skills/**/*.toml) and templates (questions/**/info.json).

A skill is a graph node and one FSRS card; a template is a PL question that
exercises one skill (info.json: "comment": {"srs": {"skill": "<id>"}}).
Loading never raises on content problems: they go to Catalog.errors (the
planner skips what's broken; `mimir lint` reports it).
"""

import json
import tomllib
from dataclasses import dataclass, field
from pathlib import Path

from .config import Study

LEVELS = ("precalc", "lower", "upper", "grad")


@dataclass
class Skill:
    id: str
    uuid: str
    title: str
    requires: list[str]
    encompasses: dict[str, float]
    level: str
    minutes: float
    learn: int
    tags: list[str]
    suspended: bool
    file: str

    @property
    def gates(self) -> set[str]:
        """Direct prerequisites: requires plus everything encompassed."""
        return set(self.requires) | set(self.encompasses)


@dataclass
class Template:
    qid: str
    uuid: str
    title: str
    skill_id: str
    minutes: float | None
    encompasses: dict[str, float]
    declares_learn: bool


@dataclass
class Catalog:
    skills: dict[str, Skill] = field(default_factory=dict)
    templates: dict[str, Template] = field(default_factory=dict)
    errors: list[str] = field(default_factory=list)
    warnings: list[str] = field(default_factory=list)

    def templates_of(self, skill_id: str) -> list[Template]:
        return sorted((t for t in self.templates.values() if t.skill_id == skill_id), key=lambda t: t.qid)

    def by_uuid(self) -> dict[str, Skill]:
        return {s.uuid: s for s in self.skills.values()}

    def minutes(self, t: Template) -> float:
        return t.minutes if t.minutes is not None else self.skills[t.skill_id].minutes

    def has_templates(self, skill_id: str) -> bool:
        return any(t.skill_id == skill_id for t in self.templates.values())

    def effective_gates(self, skill_id: str) -> set[str]:
        """Prerequisites with placeholder skills (no templates) passed through to theirs."""
        out, seen, todo = set(), set(), list(self.skills[skill_id].gates)
        while todo:
            g = todo.pop()
            if g in seen or g not in self.skills:
                continue
            seen.add(g)
            if self.has_templates(g):
                out.add(g)
            else:
                todo.extend(self.skills[g].gates)
        return out

    def dependents(self) -> dict[str, set[str]]:
        """skill id -> every skill that (transitively) gates on it."""
        direct: dict[str, set[str]] = {s: set() for s in self.skills}
        for s in self.skills.values():
            for g in s.gates:
                if g in direct:
                    direct[g].add(s.id)
        out = {}
        for s in self.skills:
            seen, todo = set(), list(direct[s])
            while todo:
                d = todo.pop()
                if d not in seen:
                    seen.add(d)
                    todo.extend(direct.get(d, ()))
            out[s] = seen
        return out


def _skill(raw: dict, file: str, study: Study, errors: list[str]) -> Skill | None:
    where = f"{file}: skill {raw.get('id', '?')!r}"
    for k in ("id", "uuid", "title"):
        if not isinstance(raw.get(k), str) or not raw[k]:
            errors.append(f"{where}: missing {k}")
            return None
    enc = raw.get("encompasses", {}) or {}
    if not isinstance(enc, dict) or not all(isinstance(v, (int, float)) and 0 < v <= 1 for v in enc.values()):
        errors.append(f"{where}: encompasses must map skill ids to weights in (0, 1]")
        enc = {}
    level = raw.get("level", "precalc")
    if level not in LEVELS:
        errors.append(f"{where}: level must be one of {', '.join(LEVELS)}")
    return Skill(
        id=raw["id"], uuid=raw["uuid"], title=raw["title"],
        requires=list(raw.get("requires", []) or []), encompasses={k: float(v) for k, v in enc.items()},
        level=level, minutes=float(raw.get("minutes", 5)), learn=int(raw.get("learn", 2)),
        tags=list(raw.get("tags", []) or []), suspended=bool(raw.get("suspended", False)), file=file,
    )


def load(course: Path, study: Study) -> Catalog:
    cat = Catalog()
    seen_uuid: dict[str, str] = {}
    for path in sorted((course / "skills").rglob("*.toml")):
        rel = path.relative_to(course).as_posix()
        try:
            doc = tomllib.loads(path.read_text())
        except (tomllib.TOMLDecodeError, OSError) as e:
            cat.errors.append(f"{rel}: {e}")
            continue
        for raw in doc.get("skill", []):
            s = _skill(raw, rel, study, cat.errors)
            if s is None:
                continue
            if s.id in cat.skills:
                cat.errors.append(f"{rel}: duplicate skill id {s.id} (also in {cat.skills[s.id].file})")
                continue
            if s.uuid in seen_uuid:
                cat.errors.append(f"{rel}: skill {s.id} reuses the uuid of {seen_uuid[s.uuid]}")
                continue
            expected = "skills/" + "/".join(s.id.split("/")[:3]) + ".toml"
            if rel != expected:
                cat.warnings.append(f"{rel}: skill {s.id} belongs in {expected}")
            seen_uuid[s.uuid] = s.id
            cat.skills[s.id] = s

    qroot = course / "questions"
    for info in sorted(qroot.rglob("info.json")):
        qid = info.parent.relative_to(qroot).as_posix()
        try:
            d = json.loads(info.read_text())
        except (json.JSONDecodeError, OSError) as e:
            cat.errors.append(f"questions/{qid}/info.json: {e}")
            continue
        srs = (d.get("comment") or {}).get("srs") if isinstance(d.get("comment"), dict) else None
        if not srs or not srs.get("skill"):
            cat.warnings.append(f"{qid}: no comment.srs.skill, so it is never scheduled")
            continue
        if srs["skill"] not in cat.skills:
            cat.errors.append(f"{qid}: skill {srs['skill']} does not exist")
            continue
        if not qid.startswith(srs["skill"] + "/"):
            cat.warnings.append(f"{qid}: templates live under their skill's path, questions/{srs['skill']}/<slug>")
        enc = srs.get("encompasses", {}) or {}
        cat.templates[qid] = Template(
            qid=qid, uuid=d.get("uuid", ""), title=d.get("title", qid), skill_id=srs["skill"],
            minutes=float(srs["minutes"]) if srs.get("minutes") is not None else None,
            encompasses={k: float(v) for k, v in enc.items()},
            declares_learn="learn" in (d.get("preferences") or {}),
        )

    _check_graph(cat)
    return cat


def _check_graph(cat: Catalog) -> None:
    for s in cat.skills.values():
        for g in s.gates:
            if g not in cat.skills:
                cat.errors.append(f"{s.file}: {s.id} refers to unknown skill {g}")
            if g == s.id:
                cat.errors.append(f"{s.file}: {s.id} refers to itself")
    for t in cat.templates.values():
        for g in t.encompasses:
            if g not in cat.skills:
                cat.errors.append(f"{t.qid}: encompasses unknown skill {g}")
    # cycles in the gate graph (requires + encompasses)
    state: dict[str, int] = {}

    def visit(n: str, path: list[str]) -> None:
        state[n] = 1
        for g in sorted(cat.skills[n].gates):
            if g not in cat.skills:
                continue
            if state.get(g) == 1:
                cyc = path[path.index(g):] + [g] if g in path else [n, g]
                cat.errors.append("prerequisite cycle: " + " -> ".join(cyc))
            elif state.get(g) is None:
                visit(g, path + [g])
        state[n] = 2

    for sid in sorted(cat.skills):
        if sid not in state:
            visit(sid, [sid])
