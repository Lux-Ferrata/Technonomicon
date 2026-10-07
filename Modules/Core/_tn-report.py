"""tn-report: Akmon's daily and weekly report emails (Tn-server-reports).

    tn-report daily  [--text FILE] [--review FILE] [--open-issues N] [--subject S]
    tn-report weekly [--text FILE] [--subject S]          (+ the report as a PDF)
    common:          [--to ADDR] [--dry-run DIR]

--text is the body that leads the mail (the alert digest, or the weekly CI
summary); --review is Claude's read of the day. Charts are Grafana panels
from the "Akmon report" dashboard rendered to PNG and embedded inline;
tables come straight from VictoriaMetrics. --dry-run writes mail.eml,
report.html (and report.pdf) into DIR instead of sending.
"""

import argparse
import datetime
import html
import json
import os
import re
import subprocess
import sys
import urllib.parse
import urllib.request
from email.message import EmailMessage
from email.utils import make_msgid

VM = os.environ.get("TN_REPORT_VM", "http://127.0.0.1:8428")
GRAFANA = os.environ.get("TN_REPORT_GRAFANA", "http://127.0.0.1:3001")
PUBLIC = os.environ.get("TN_REPORT_PUBLIC", "https://metrics.ironshark.org")
HOST = os.uname().nodename
FROM = f"{HOST} <homelab@ironshark.org>"
TO = "xin@ironshark.org"
DASH = "akmon-report"

# light chart surface + inks + status (dataviz reference palette)
INK, INK2, MUTED, HAIR = "#0b0b0b", "#52514e", "#898781", "#e1e0d9"
SURFACE, PAGE = "#fcfcfb", "#f9f9f7"
STATUS = {"good": ("#0ca30c", "✔", "All good"),
          "warning": ("#fab219", "▲", "Needs a look"),
          "critical": ("#d03b3b", "✖", "Problem")}
GIB = 1024 ** 3


# ---------------------------------------------------------------- queries
def query(expr):
    """Instant query -> [(labels, value)]; [] when VictoriaMetrics is away."""
    url = VM + "/api/v1/query?" + urllib.parse.urlencode({"query": expr})
    try:
        with urllib.request.urlopen(url, timeout=30) as r:
            data = json.load(r)["data"]["result"]
    except Exception as e:  # noqa: BLE001 - a report with gaps beats no report
        print(f"query failed: {expr}: {e}", file=sys.stderr)
        return []
    return [(d["metric"], float(d["value"][1])) for d in data]


def scalar(expr, default=None):
    r = query(expr)
    return r[0][1] if r else default


def render(panel, period, width=1000, height=300):
    params = {"orgId": 1, "panelId": panel, "from": f"now-{period}", "to": "now",
              "width": width, "height": height, "theme": "light",
              "tz": "America/Phoenix"}
    url = f"{GRAFANA}/render/d-solo/{DASH}/x?" + urllib.parse.urlencode(params)
    try:
        with urllib.request.urlopen(url, timeout=120) as r:
            if r.headers.get_content_type() == "image/png":
                return r.read()
    except Exception as e:  # noqa: BLE001
        print(f"render failed: panel {panel}: {e}", file=sys.stderr)
    return None


# ---------------------------------------------------------------- formatting
def gib(b):
    return f"{b / GIB:.1f} GiB"


def pct(x):
    return f"{x:.1f}%" if x is not None else "n/a"


def ago(seconds):
    if seconds < 3600:
        return f"{seconds / 60:.0f} min"
    if seconds < 2 * 86400:
        return f"{seconds / 3600:.0f} h"
    return f"{seconds / 86400:.0f} d"


def esc(s):
    return html.escape(str(s))


class Report:
    """Collects sections as HTML and as plain text side by side."""

    def __init__(self):
        self.html, self.text, self.images = [], [], []

    def heading(self, title):
        self.html.append(f'<h2 style="font-size:16px;margin:28px 0 8px;color:{INK}">{esc(title)}</h2>')
        self.text.append(f"\n== {title}")

    def para(self, s, muted=False):
        colour = MUTED if muted else INK2
        self.html.append(f'<p style="margin:4px 0;color:{colour}">{esc(s)}</p>')
        self.text.append(s)

    def prose(self, s):
        self.html.append(f'<div style="white-space:pre-wrap;color:{INK};line-height:1.5">{esc(s)}</div>')
        self.text.append(s)

    def pre(self, s):
        self.html.append(f'<pre style="font-family:ui-monospace,Menlo,Consolas,monospace;font-size:12px;'
                         f'line-height:1.35;white-space:pre-wrap;background:{PAGE};border:1px solid {HAIR};'
                         f'border-radius:6px;padding:10px 12px;color:{INK}">{esc(s)}</pre>')
        self.text.append(s)

    def table(self, header, rows, right=()):
        th = "".join(f'<th style="text-align:{"right" if i in right else "left"};font-weight:600;'
                     f'color:{INK2};padding:4px 10px 4px 0;border-bottom:1px solid {HAIR}">{esc(h)}</th>'
                     for i, h in enumerate(header))
        body = ""
        for row in rows:
            body += "<tr>" + "".join(
                f'<td style="text-align:{"right" if i in right else "left"};padding:3px 10px 3px 0;'
                f'border-bottom:1px solid {HAIR};color:{INK};font-variant-numeric:tabular-nums">{c}</td>'
                for i, c in enumerate(row)) + "</tr>"
        self.html.append(f'<table style="border-collapse:collapse;font-size:13px;width:100%">'
                         f'<tr>{th}</tr>{body}</table>')
        widths = [max(len(_plain(c)) for c in col) for col in zip(header, *rows)]
        for row in [header] + rows:
            self.text.append("  " + "  ".join(_plain(c).ljust(w) for c, w in zip(row, widths)))

    def chart(self, title, png):
        if png is None:
            self.para(f"({title}: chart unavailable)", muted=True)
            return
        cid = make_msgid(domain=HOST)
        self.images.append((cid, png))
        self.html.append(f'<img src="cid:{cid[1:-1]}" alt="{esc(title)}" width="100%" '
                         f'style="max-width:1000px;display:block;margin:6px 0 2px;border:1px solid {HAIR};'
                         f'border-radius:6px">')
        self.text.append(f"[chart: {title}]")


def _plain(cell):
    """Table cell (maybe holding a status chip) -> its text."""
    return html.unescape(re.sub(r"<[^>]+>", "", str(cell)))


def chip(level, label=None):
    colour, icon, default = STATUS[level]
    return (f'<span style="color:{colour};font-weight:600">{icon}</span> '
            f'<span style="color:{INK}">{esc(label or default)}</span>')


# ---------------------------------------------------------------- sections
def status(rep, open_issues):
    failed = scalar('count(systemd_unit_state{state="failed"} == 1)', 0)
    urgent = scalar('count(ALERTS{alertstate="firing",severity="urgent"})', 0)
    digest = scalar('count(ALERTS{alertstate="firing",severity!="urgent"})', 0)
    if failed or urgent:
        level = "critical"
    elif digest or open_issues:
        level = "warning"
    else:
        level = "good"
    colour, icon, label = STATUS[level]
    parts = [f"{int(failed)} failed units", f"{int(urgent)} urgent / {int(digest)} other alerts firing"]
    if open_issues is not None:
        parts.append(f"{open_issues} open issues")
    detail = ", ".join(parts)
    rep.html.append(f'<div style="border-left:4px solid {colour};padding:8px 12px;background:{PAGE};'
                    f'margin:8px 0 4px;color:{INK}"><span style="color:{colour};font-size:18px">{icon}</span> '
                    f'<b>{label}</b> &mdash; {esc(detail)}</div>')
    rep.text.append(f"{label.upper()}: {detail}")
    return level


def load_table(rep, period):
    cpu = '100 * (1 - avg(rate(node_cpu_seconds_total{mode="idle"}[5m])))'
    ram = "node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes - node_zfs_arc_size"
    rows_def = [
        ("CPU busy", cpu, pct),
        ("RAM (apps)", ram, gib),
        ("ZFS cache (ARC)", "node_zfs_arc_size", gib),
        ("GPU busy", "100 * avg(nvidia_smi_utilization_gpu_ratio)", pct),
        ("GPU memory", "sum(nvidia_smi_memory_used_bytes)", gib),
        ("GPU power", "sum(nvidia_smi_power_draw_watts)", lambda w: f"{w:.0f} W"),
        ("CPU temperature", 'max(node_hwmon_temp_celsius{chip=~".*coretemp.*"})', lambda c: f"{c:.0f} °C"),
    ]
    rows = []
    for name, expr, fmt in rows_def:
        window = f"({expr})[{period}:5m]"
        vals = [scalar(f"avg_over_time({window})"),
                scalar(f"quantile_over_time(0.95, {window})"),
                scalar(f"max_over_time({window})")]
        if all(v is None for v in vals):
            continue
        rows.append([esc(name)] + [esc(fmt(v)) if v is not None else "n/a" for v in vals])
    if rows:
        rep.heading(f"Load, last {period}")
        rep.table(["", "mean", "p95", "max"], rows, right=(1, 2, 3))


def availability(rep, period, only_problems):
    res = query(f'avg_over_time(probe_success[{period}])')
    if not res:
        return
    rows = []
    for labels, v in sorted(res, key=lambda r: r[1]):
        name = labels.get("instance", "?").replace("https://", "").rstrip("/")
        if only_problems and v >= 0.9999:
            continue
        level = "good" if v >= 0.999 else "warning" if v >= 0.99 else "critical"
        rows.append([esc(name), chip(level, f"{100 * v:.2f}%")])
    rep.heading(f"Availability, last {period}")
    if rows:
        rep.table(["service", "answered probes"], rows, right=(1,))
    else:
        rep.para(f"All {len(res)} services answered every probe.")


def pools(rep, period):
    size = {lab["pool"]: v for lab, v in query("tn_zpool_size_bytes")}
    alloc = {lab["pool"]: v for lab, v in query("tn_zpool_alloc_bytes")}
    growth = {lab["pool"]: v for lab, v in query(f"tn_zpool_alloc_bytes - tn_zpool_alloc_bytes offset {period}")}
    if not size:
        return
    days = 7 if period == "7d" else 1
    rows = []
    for p in sorted(size):
        used = alloc.get(p, 0) / size[p]
        g = growth.get(p)
        if g is None:
            full = "n/a"
        elif g <= 0:
            full = "not growing"
        else:
            full = ago((size[p] - alloc.get(p, 0)) / (g / days) * 86400)
        level = "good" if used < 0.8 else "warning" if used < 0.9 else "critical"
        rows.append([esc(p), chip(level, f"{100 * used:.0f}%"), esc(gib(alloc.get(p, 0))),
                     esc(("+" if (g or 0) >= 0 else "") + gib(g or 0)), esc(full)])
    rep.heading("Storage pools")
    rep.table(["pool", "used", "allocated", f"change ({period})", "full in"], rows, right=(1, 2, 3, 4))


def jobs(rep, only_problems):
    last = {lab["unit"]: v for lab, v in query("tn_job_last_success_timestamp_seconds")}
    limit = {lab["unit"]: v for lab, v in query("tn_job_max_age_seconds")}
    now = datetime.datetime.now().timestamp()
    rows = []
    for unit in sorted(limit):
        age = now - last[unit] if unit in last else None
        ok = age is not None and age <= limit[unit]
        if only_problems and ok:
            continue
        rows.append([esc(unit.removesuffix(".service")),
                     chip("good" if ok else "critical", ago(age) + " ago" if age is not None else "never"),
                     esc("every " + ago(limit[unit]))])
    rep.heading("Scheduled jobs (last success)")
    if rows:
        rep.table(["job", "last success", "expected"], rows, right=())
    else:
        rep.para(f"All {len(limit)} tracked jobs succeeded on schedule.")


def top_services(rep, period, n):
    mem = query(f"topk({n}, avg_over_time(tn_unit_memory_bytes[{period}]))")
    cpu = {lab["unit"]: v for lab, v in query(f"rate(tn_unit_cpu_seconds_total[{period}])")}
    if not mem:
        return
    rows = [[esc(lab["unit"].removesuffix(".service")), esc(gib(v)), esc(f"{100 * cpu.get(lab['unit'], 0):.1f}%")]
            for lab, v in sorted(mem, key=lambda r: -r[1])]
    rep.heading(f"Biggest services, last {period} (average)")
    rep.table(["service", "memory", "CPU (of one core)"], rows, right=(1, 2))


def charts(rep, period, extra):
    panels = [(1, "CPU and GPU busy"), (2, "Memory (RAM)"), (3, "Service availability")]
    if (scalar(f'sum(increase(nginx_http_response_count_total{{status=~"5.."}}[{period}]))', 0) or 0) >= 1:
        panels.append((6, "Web errors"))
    panels += extra
    rep.heading(f"Charts, last {period}")
    for pid, title in panels:
        rep.chart(title, render(pid, period, height=420 if pid == 3 else 300))
    rep.para(f"Live: {PUBLIC}/d/{DASH}", muted=True)


# ---------------------------------------------------------------- assembly
def build(args):
    rep = Report()
    weekly = args.kind == "weekly"
    period = "7d" if weekly else "24h"
    title = f"{HOST} {'weekly' if weekly else 'daily'} report, {datetime.date.today():%a %d %b %Y}"

    level = status(rep, args.open_issues)
    if args.review and os.path.exists(args.review) and os.path.getsize(args.review):
        rep.heading("Claude's read")
        rep.prose(open(args.review).read().strip())
    if args.text and os.path.exists(args.text):
        body = open(args.text).read().rstrip()
        if weekly:
            rep.heading("This week")
            rep.prose(body)
        else:
            rep.heading("Alert digest")
            rep.pre(body)

    if weekly:
        load_table(rep, period)
    charts(rep, period, [(4, "Temperatures"), (5, "Pool usage"), (7, "GPU memory")] if weekly else [])
    availability(rep, period, only_problems=not weekly)
    pools(rep, period)
    jobs(rep, only_problems=not weekly)
    top_services(rep, period, 10 if weekly else 5)

    page = (f'<!doctype html><html><head><meta charset="utf-8"><title>{esc(title)}</title></head>'
            f'<body style="margin:0;background:{SURFACE}">'
            f'<div style="max-width:1000px;margin:0 auto;padding:16px;font-family:-apple-system,Segoe UI,'
            f'Roboto,Helvetica,Arial,sans-serif;font-size:14px;color:{INK}">'
            f'<h1 style="font-size:20px;margin:0 0 4px">{esc(title)}</h1>'
            + "".join(rep.html) + "</div></body></html>")
    return rep, page, title, level


def to_pdf(page, images):
    """The same page, images inlined as data: URIs (weasyprint can't see cid:)."""
    import base64
    from weasyprint import HTML
    for cid, png in images:
        page = page.replace(f"cid:{cid[1:-1]}", "data:image/png;base64," + base64.b64encode(png).decode())
    return HTML(string=page).write_pdf()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("kind", choices=["daily", "weekly"])
    ap.add_argument("--text")
    ap.add_argument("--review")
    ap.add_argument("--open-issues", type=int)
    ap.add_argument("--subject")
    ap.add_argument("--to", default=TO)
    ap.add_argument("--dry-run", metavar="DIR")
    args = ap.parse_args()

    rep, page, title, level = build(args)

    msg = EmailMessage()
    msg["To"] = args.to
    msg["From"] = FROM
    msg["Subject"] = args.subject or f"[{HOST}] {title.split(', ')[0]}: {STATUS[level][2]}"
    msg.set_content("\n".join(rep.text) + f"\n\nLive dashboard: {PUBLIC}/d/{DASH}\n")
    msg.add_alternative(page, subtype="html")
    html_part = msg.get_body(preferencelist=("html",))
    for cid, png in rep.images:
        html_part.add_related(png, maintype="image", subtype="png", cid=cid)
    pdf = None
    if args.kind == "weekly":
        try:
            pdf = to_pdf(page, rep.images)
            msg.add_attachment(pdf, maintype="application", subtype="pdf",
                               filename=f"{HOST}-weekly-{datetime.date.today():%Y-%m-%d}.pdf")
        except Exception as e:  # noqa: BLE001 - the mail matters more than the PDF
            print(f"PDF failed: {e}", file=sys.stderr)

    if args.dry_run:
        os.makedirs(args.dry_run, exist_ok=True)
        with open(os.path.join(args.dry_run, "mail.eml"), "wb") as f:
            f.write(bytes(msg))
        with open(os.path.join(args.dry_run, "report.html"), "w") as f:
            f.write(page)
        if pdf:
            with open(os.path.join(args.dry_run, "report.pdf"), "wb") as f:
                f.write(pdf)
        print(f"wrote {args.dry_run}/mail.eml ({len(bytes(msg)) // 1024} KiB, {len(rep.images)} charts)")
        return
    subprocess.run(["/run/wrappers/bin/sendmail", "-t"], input=bytes(msg), check=True)


if __name__ == "__main__":
    main()
