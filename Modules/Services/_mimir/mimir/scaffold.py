"""`mimir new skill|template`: the mechanical part of authoring (uuids, file layout, skeletons)."""

import json
import uuid
from datetime import date
from pathlib import Path

ELEMENTS = {
    "numeric": '<pl-number-input answers-name="ans" comparison="relabs" rtol="0.002" label="Answer:"></pl-number-input>',
    "integer": '<pl-integer-input answers-name="ans" label="Answer:"></pl-integer-input>',
    "symbolic": '<pl-symbolic-input answers-name="ans" variables="x" label="Answer:" display="block"></pl-symbolic-input>',
    "set": ('<pl-symbolic-input answers-name="ans" allow-sets="true" label="Solution set:" display="block">'
            '</pl-symbolic-input>'),
    "mc": ('<pl-multiple-choice answers-name="ans">\n'
           '  {{#params.choices}}<pl-answer correct="{{correct}}">{{{text}}}</pl-answer>{{/params.choices}}\n'
           '</pl-multiple-choice>'),
}
KINDS = tuple(ELEMENTS)
# what Pass/Fail (self-grade) mode shows instead of each answer element: the prompt, nothing to type
ASKS = {
    "numeric": '<span class="tn-ask">Answer: <span class="tn-gap"></span></span>',
    "integer": '<span class="tn-ask">Answer: <span class="tn-gap"></span></span>',
    "symbolic": '<div class="tn-ask">Answer: <span class="tn-gap"></span></div>',
    "set": '<div class="tn-ask">Solution set: <span class="tn-gap"></span></div>',
    "mc": '<ul class="tn-options">{{#params.choices}}<li>{{{text}}}</li>{{/params.choices}}</ul>',
}

QUESTION_HTML = """{{{{#preferences.learn}}}}
<pl-card header="Worked example">
  {{{{{{params.example.statement}}}}}}
  {{{{{{params.example.steps}}}}}}
</pl-card>
{{{{/preferences.learn}}}}

<pl-question-panel>
  {{{{{{params.statement}}}}}}
</pl-question-panel>

{{{{^preferences.selfgrade}}}}{element}{{{{/preferences.selfgrade}}}}{{{{#preferences.selfgrade}}}}{ask}{{{{/preferences.selfgrade}}}}

{{{{#preferences.selfgrade}}}}
<tn-selfgrade></tn-selfgrade>
{{{{/preferences.selfgrade}}}}
{{{{^preferences.selfgrade}}}}
<pl-answer-panel>
  {{{{{{params.steps}}}}}}
</pl-answer-panel>
{{{{/preferences.selfgrade}}}}
"""

SERVER_PY = '''"""{title}.

TODO: the forms this template varies between, and what each tests.
"""

import random

import prairielearn as pl
import sympy as sp
from tnlearn import checks, fill, fmt, form, nice

X = sp.Symbol("x")


def make():
    """One problem. Vary the structure, not only the numbers. "_" keys stay private."""
    a = nice.nonzero(-9, 9)
    answer = sp.Integer(a)  # TODO: compute the answer with code, never by hand
    return {{
        "statement": f"<p>TODO</p>{{fmt.display(fmt.tex(a))}}",
        "_answer": answer,
        "_steps": [rf"TODO: the worked steps for ${{fmt.tex(a)}}$."],
    }}


def solve(m):
    return m["_steps"]


def answers(m):
    return {{"ans": {answer_expr}}}


def self_check(m):
    """An INDEPENDENT check of the answer: substitute it back, solve numerically,
    compare with a brute force. Never re-run the code that made it."""
    raise NotImplementedError("write the independent check")


def parse(data):
    form.relax_typed(data)  # isqrt(2), √2, xsqrt(3): shorthands PL's parser refuses


def generate(data):
    fill(data, make, solve, answers)
'''

SOURCE_MD = """# Source

- Kind: {kind}
- From: {cite}
- Added {today}.
"""


def skill_file(course: Path, skill_id: str) -> Path:
    parts = skill_id.split("/")
    if len(parts) < 4:
        raise SystemExit("a skill id has at least four parts: subject/level/area/name (e.g. math/precalc/logs/convert)")
    return course / "skills" / Path(*parts[:2]) / f"{parts[2]}.toml"


def _q(s: str) -> str:
    return json.dumps(s)


def new_skill(course: Path, skill_id: str, title: str, requires: list[str], encompasses: dict[str, float],
              minutes: float, level: str, learn: int, tags: list[str]) -> Path:
    path = skill_file(course, skill_id)
    text = path.read_text() if path.exists() else "# One [[skill]] per graph node and FSRS card; see the course CLAUDE.md.\n"
    if f"id       = {_q(skill_id)}" in text or f'id = {_q(skill_id)}' in text:
        raise SystemExit(f"{skill_id} already exists in {path.relative_to(course)}")
    lines = ["", "[[skill]]", f"id       = {_q(skill_id)}", f"uuid     = {_q(str(uuid.uuid4()))}",
             f"title    = {_q(title)}", f"level    = {_q(level)}", f"minutes  = {minutes:g}", f"learn    = {learn}",
             "requires = [" + ", ".join(_q(r) for r in requires) + "]"]
    if encompasses:
        lines.append("encompasses = { " + ", ".join(f"{_q(k)} = {v:g}" for k, v in encompasses.items()) + " }")
    lines.append("tags     = [" + ", ".join(_q(t) for t in tags) + "]")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text.rstrip("\n") + "\n" + "\n".join(lines) + "\n")
    return path


def new_template(course: Path, skill_id: str, slug: str, kind: str, title: str, topic: str,
                 source_kind: str, cite: str) -> Path:
    if kind not in ELEMENTS:
        raise SystemExit(f"--kind must be one of {', '.join(KINDS)}")
    d = course / "questions" / skill_id / slug
    if d.exists():
        raise SystemExit(f"{d.relative_to(course)} already exists")
    (d / "source").mkdir(parents=True)
    info = {"uuid": str(uuid.uuid4()), "title": title, "topic": topic, "type": "v3",
            "comment": {"srs": {"skill": skill_id}},
            "preferences": {"learn": {"type": "boolean", "default": False},
                            "selfgrade": {"type": "boolean", "default": True}}}
    (d / "info.json").write_text(json.dumps(info, indent=2) + "\n")
    (d / "question.html").write_text(QUESTION_HTML.format(element=ELEMENTS[kind], ask=ASKS[kind]))
    answer_expr = {"numeric": 'float(m["_answer"])', "integer": 'int(m["_answer"])',
                   "mc": 'None  # pl-multiple-choice uses params.choices',
                   }.get(kind, 'pl.to_json(m["_answer"])')
    (d / "server.py").write_text(SERVER_PY.format(title=title, answer_expr=answer_expr))
    (d / "source" / "source.md").write_text(SOURCE_MD.format(kind=source_kind, cite=cite, today=date.today()))
    return d
