"""`mimir graph`: the skill graph as Graphviz DOT (with memory state when known)."""

from .catalog import Catalog
from .memory import SkillState


def neighbourhood(cat: Catalog, center: str, depth: int) -> set[str]:
    keep, frontier = {center}, {center}
    for _ in range(depth):
        nxt = set()
        for s in frontier:
            nxt |= cat.skills[s].gates
            nxt |= {o.id for o in cat.skills.values() if s in o.gates}
        frontier = nxt - keep
        keep |= nxt
    return {k for k in keep if k in cat.skills}


def dot(cat: Catalog, states: dict[str, SkillState] | None = None, around: str | None = None,
        depth: int = 2) -> str:
    ids = neighbourhood(cat, around, depth) if around else set(cat.skills)
    out = ["digraph mimir {", "  rankdir=BT;", '  node [shape=box, style="rounded,filled", fontname="sans"];']
    for sid in sorted(ids):
        s = cat.skills[sid]
        st = (states or {}).get(s.uuid)
        if not cat.has_templates(sid):
            fill, note = "white", "no template yet"
        elif st is None or not st.graduated:
            fill, note = "lightyellow", "new"
        else:
            fill, note = "palegreen", f"S={st.card.stability:.0f}d" if st.card and st.card.stability else ""
        label = f"{s.title}\\n{sid}\\n{note}"
        out.append(f'  "{sid}" [label="{label}", fillcolor="{fill}"];')
    for sid in sorted(ids):
        s = cat.skills[sid]
        for r in sorted(s.requires):
            if r in ids:
                out.append(f'  "{r}" -> "{sid}" [color=gray];')
        for e, w in sorted(s.encompasses.items()):
            if e in ids:
                out.append(f'  "{e}" -> "{sid}" [label="{w:g}", penwidth={1 + 2 * w:.1f}];')
    out.append("}")
    return "\n".join(out)
