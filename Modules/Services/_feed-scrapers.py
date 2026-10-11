"""Atom feeds for sites that publish none, for Miniflux.

Each scraper reads a listing page and returns entries; the result is written
to <outdir>/<name>.xml and served at https://rss.ironshark.org/scraped/.
Miniflux's crawler fetches the full text, so the entries only need a title,
link, date and a line of summary. A scraper that fails keeps its last file.

    feed-scrapers <outdir>
"""
import datetime
import sys
import urllib.request
from pathlib import Path
from urllib.parse import urljoin
from xml.sax.saxutils import escape

from bs4 import BeautifulSoup

UA = "Mozilla/5.0 (X11; Linux x86_64) feed-scrapers (Akmon; personal RSS)"


def fetch(url):
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=60) as r:
        return BeautifulSoup(r.read(), "html.parser")


def nature_futures():
    """Nature's weekly science-fiction short-short column."""
    base = "https://www.nature.com/nature/articles?type=futures"
    entries = []
    for card in fetch(base).select("article.c-card"):
        a = card.select_one(".c-card__title a")
        time = card.select_one("time[datetime]")
        if not a or not time:
            continue
        summary = card.select_one('[itemprop="description"]')
        entries.append({
            "title":   a.get_text(strip=True),
            "link":    urljoin(base, a["href"]),
            "date":    time["datetime"],
            "authors": [s.get_text(strip=True) for s in card.select('[itemprop="creator"] [itemprop="name"]')],
            "summary": summary.get_text(" ", strip=True) if summary else "",
        })
    return {"title": "Nature Futures", "link": base, "entries": entries}


SCRAPERS = {"nature-futures": nature_futures}


def atom(feed):
    now = datetime.datetime.now(datetime.timezone.utc).isoformat(timespec="seconds")
    out = [
        '<?xml version="1.0" encoding="utf-8"?>',
        '<feed xmlns="http://www.w3.org/2005/Atom">',
        f"<title>{escape(feed['title'])}</title>",
        f'<link href="{escape(feed["link"])}"/>',
        f"<id>{escape(feed['link'])}</id>",
        f"<updated>{now}</updated>",
    ]
    for e in feed["entries"]:
        date = e["date"] if "T" in e["date"] else e["date"] + "T12:00:00Z"
        out += [
            "<entry>",
            f"<title>{escape(e['title'])}</title>",
            f'<link href="{escape(e["link"])}"/>',
            f"<id>{escape(e['link'])}</id>",
            f"<published>{date}</published>",
            f"<updated>{date}</updated>",
            *(f"<author><name>{escape(a)}</name></author>" for a in e["authors"]),
            f"<summary>{escape(e['summary'])}</summary>",
            "</entry>",
        ]
    out.append("</feed>")
    return "\n".join(out) + "\n"


def main():
    outdir = Path(sys.argv[1])
    failed = []
    for name, scrape in SCRAPERS.items():
        try:
            feed = scrape()
            if not feed["entries"]:
                raise RuntimeError("no entries (page layout changed?)")
            tmp = outdir / f".{name}.xml"
            tmp.write_text(atom(feed))
            tmp.rename(outdir / f"{name}.xml")
            print(f"{name}: {len(feed['entries'])} entries")
        except Exception as ex:
            print(f"{name}: FAILED: {ex}", file=sys.stderr)
            failed.append(name)
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
