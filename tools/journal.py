"""Build the development journal, docs/roadmap/journal/index.html, from live sources.

Sources: docs/roadmap/journal.json (hand-kept by the lead: phase items, PR map, day notes, captures,
his highlighted words), docs/DECISIONS.md plus docs/archive/decisions_*.md (every ruling), the
director note tables in docs/roadmap/*.md, the PR list (`gh`, cached in docs/roadmap/journal-prs.json
so CI and offline runs need no network) and the captures named in journal.json (resized to webp in
docs/roadmap/journal/img/).

Run from the repo root after merges:  python tools/journal.py [--no-gh] [--check]
  --no-gh   use the cached PR list only
  --check   build nothing; fail if a merged PR is missing from journal.json (lead keeps the map)
Open docs/roadmap/journal/index.html in a browser; `artifact.html` beside it is the same page
without the document skeleton, for publishing as a claude.ai artifact.
"""

import datetime
import json
import os
import re
import subprocess
import sys

REPO = "gabebartolo-spec/Kaiju-Incremental"
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
JOURNAL = os.path.join(ROOT, "docs", "roadmap", "journal.json")
PR_CACHE = os.path.join(ROOT, "docs", "roadmap", "journal-prs.json")
OUT_DIR = os.path.join(ROOT, "docs", "roadmap", "journal")
FIRST_REAL_PR = 4  # 1-3 are the scaffold, kickoff handoff and look-options


def read(path):
    with open(path, encoding="utf-8") as f:
        return f.read()


def decisions():
    files = [os.path.join(ROOT, "docs", "DECISIONS.md")]
    archive = os.path.join(ROOT, "docs", "archive")
    if os.path.isdir(archive):
        files += sorted(os.path.join(archive, f) for f in os.listdir(archive) if f.startswith("decisions_"))
    out, seen = [], set()
    pat = re.compile(r"^## (\d{4}-\d\d-\d\d) · (D-[0-9a-z]+) · (\w+) · (.+?)\s*$", re.M)
    for path in files:
        text = read(path)
        for m in pat.finditer(text):
            if m.group(2) in seen:
                continue
            seen.add(m.group(2))
            body = text[m.end():]
            nxt = body.find("\n## ")
            body = body[: nxt if nxt >= 0 else None].strip()
            out.append({"date": m.group(1), "id": m.group(2), "who": m.group(3),
                        "title": m.group(4), "body": body[:600]})
    out.sort(key=lambda d: (d["date"], d["id"]))
    return out


def note_tables():
    """Every director note row: (file, number, his words, status)."""
    folder = os.path.join(ROOT, "docs", "roadmap")
    rows = []
    for name in sorted(os.listdir(folder)):
        if not name.endswith(".md") or not re.match(r"\d{4}-\d\d-\d\d-", name):
            continue
        date = name[:10]
        for line in read(os.path.join(folder, name)).splitlines():
            m = re.match(r"^\| (\d+) \| (.+?) \| (.+) \|\s*$", line)
            if not m:
                continue
            status = m.group(3).split(" | ")[-1].strip()
            rows.append({"file": name, "date": date, "n": int(m.group(1)),
                         "status": status})
    return rows


def status_bucket(status):
    s = status.lower()
    if s.startswith(("merged", "done", "decided", "recorded", "approved", "rule", "standing", "fixed")):
        return "done"
    if "in progress" in s or "in review" in s or s.startswith(("built", "queued", "tried")):
        return "in progress"
    return "open"


def pull_requests(use_gh):
    prs = None
    if use_gh:
        try:
            out = subprocess.run(["gh", "pr", "list", "--state", "all", "--limit", "500",
                                  "--json", "number,title,state,createdAt,mergedAt", "--repo", REPO],
                                 capture_output=True, text=True, encoding="utf-8", check=True).stdout
            prs = [{"n": p["number"], "t": p["title"], "s": p["state"], "c": p["createdAt"][:10],
                    "m": (p.get("mergedAt") or "")[:10]} for p in json.loads(out or "[]")]
            prs.sort(key=lambda p: p["n"])
            with open(PR_CACHE, "w", encoding="utf-8", newline="\n") as f:
                json.dump(prs, f, indent=0, ensure_ascii=False)
                f.write("\n")
        except (subprocess.CalledProcessError, FileNotFoundError) as e:
            print("gh unavailable (%s); using the cached PR list" % e, file=sys.stderr)
    if prs is None:
        prs = json.loads(read(PR_CACHE))
    return prs


def check(journal, prs):
    mapped = set(journal["prs"].get("closed", []))
    for ph in journal["phases"]:
        for it in ph["items"]:
            mapped.update(it["prs"])
    missing = [p["n"] for p in prs if p["s"] == "MERGED" and p["n"] >= FIRST_REAL_PR and p["n"] not in mapped]
    if missing:
        print("journal.json: merged PRs missing from a phase item: %s" % ", ".join("#%d" % n for n in missing))
        return 1
    print("journal.json: every merged PR is placed")
    return 0


def images(journal):
    try:
        from PIL import Image
    except ImportError:
        print("Pillow missing: images not rebuilt", file=sys.stderr)
        return
    img_dir = os.path.join(OUT_DIR, "img")
    os.makedirs(img_dir, exist_ok=True)
    for key, cap in journal["captures"].items():
        src = os.path.normpath(os.path.join(ROOT, "docs", "captures", cap["src"]))
        dst = os.path.join(img_dir, key + ".webp")
        if os.path.exists(dst) and os.path.getmtime(dst) >= os.path.getmtime(src):
            continue
        im = Image.open(src).convert("RGB")
        w = min(im.width, 1200)
        im = im.resize((w, round(im.height * w / im.width)), Image.LANCZOS)
        im.save(dst, "WEBP", quality=78)


def build(journal, prs, use_gh):
    decs = decisions()
    notes = note_tables()
    today = datetime.date.today()
    start = datetime.date.fromisoformat(journal["start"])
    data = {
        "generated": datetime.datetime.now().strftime("%Y-%m-%d %H:%M"),
        "start": journal["start"],
        "today": today.isoformat(),
        "day": (today - start).days + 1,
        "repo": REPO,
        "milestones": journal["milestones"],
        "builds": journal["builds"],
        "days": journal["days"],
        "phases": journal["phases"],
        "highlights": journal["highlights"],
        "captures": journal["captures"],
        "closedPrs": journal["prs"].get("closed", []),
        "decisions": decs,
        "notes": [{"date": n["date"], "file": n["file"], "n": n["n"], "bucket": status_bucket(n["status"])} for n in notes],
        "prs": prs,
    }
    blob = json.dumps(data, ensure_ascii=False).replace("</", "<\\/")
    inner = TEMPLATE.replace("__DATA__", blob)
    os.makedirs(OUT_DIR, exist_ok=True)
    with open(os.path.join(OUT_DIR, "artifact.html"), "w", encoding="utf-8", newline="\n") as f:
        f.write(inner)
    with open(os.path.join(OUT_DIR, "index.html"), "w", encoding="utf-8", newline="\n") as f:
        f.write('<!doctype html>\n<html lang="en">\n<head>\n<meta charset="utf-8">\n'
                '<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">\n'
                '</head>\n<body style="margin:0">\n' + inner + "\n</body>\n</html>\n")
    images(journal)
    print("wrote %s (day %d, %d decisions, %d PRs, %d director notes)" % (
        os.path.relpath(OUT_DIR, ROOT), data["day"], len(decs), len(prs), len(notes)))


TEMPLATE = r"""<title>Kaiju Incremental Journal</title>
<meta name="claude:viewport-fit-sides" content="cover">
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Barlow+Condensed:wght@600;800&family=Barlow:wght@400;500;600&family=JetBrains+Mono:wght@400;600&display=swap">
<style>
/* Layout: a broadcast control-room log. One column of dated bands under a hazard-striped masthead;
   the data (bars, chips, tables) in mono; the director's words in condensed display caps. */
:root{
  --bg:#0f0f10; --panel:#17181a; --panel2:#1f2023; --line:#2c2d31; --fg:#ededea; --mute:#9a9b96;
  --hazard:#f2c01a; --alert:#e3362b; --ok:#5ec26a; --warn:#f2a01a; --blue:#5aa9ff;
  --display:"Barlow Condensed","Arial Narrow",Impact,sans-serif; --body:"Barlow",system-ui,sans-serif;
  --mono:"JetBrains Mono",ui-monospace,Consolas,monospace;
  color-scheme:dark;
}
@media (prefers-color-scheme: light){ :root:not([data-theme="dark"]){
  --bg:#f3f1ea; --panel:#ffffff; --panel2:#ecebe4; --line:#d8d6cc; --fg:#161616; --mute:#5f6059;
  --hazard:#c99a00; --alert:#c32a20; --ok:#2e8f3a; --warn:#c77d0e; --blue:#1d6fd6; color-scheme:light; } }
:root[data-theme="light"]{
  --bg:#f3f1ea; --panel:#ffffff; --panel2:#ecebe4; --line:#d8d6cc; --fg:#161616; --mute:#5f6059;
  --hazard:#c99a00; --alert:#c32a20; --ok:#2e8f3a; --warn:#c77d0e; --blue:#1d6fd6; color-scheme:light; }
*{box-sizing:border-box}
body{background:var(--bg);color:var(--fg);font-family:var(--body);font-size:16px;line-height:1.5;margin:0}
.wrap{max-width:1100px;margin:0 auto;padding-block:0 64px;padding-left:max(16px,env(safe-area-inset-left,0px));padding-right:max(16px,env(safe-area-inset-right,0px))}
a{color:var(--blue);text-decoration:none}a:hover{text-decoration:underline}
h1,h2,h3{font-family:var(--display);text-transform:uppercase;letter-spacing:.02em;line-height:1;margin:0;text-wrap:balance}
h1{font-size:clamp(40px,8vw,84px);font-weight:800}
h2{font-size:28px;font-weight:800;margin-block:48px 16px;display:flex;align-items:baseline;gap:12px;flex-wrap:wrap}
h2 small{font:600 13px var(--mono);color:var(--mute);letter-spacing:.08em}
h3{font-size:22px;font-weight:700}
.eyebrow{font:600 12px var(--mono);letter-spacing:.14em;text-transform:uppercase;color:var(--hazard)}
.tape{height:14px;background:repeating-linear-gradient(135deg,var(--hazard) 0 22px,#111 22px 44px)}
header.mast{padding-block:28px 24px;border-bottom:1px solid var(--line)}
.mast .row{display:flex;justify-content:space-between;align-items:flex-end;gap:16px;flex-wrap:wrap}
.mast p{max-width:62ch;color:var(--mute);margin:10px 0 0}
nav.bar{position:sticky;top:env(safe-area-inset-top,0px);z-index:5;background:var(--bg);border-bottom:1px solid var(--line);display:flex;gap:4px;flex-wrap:wrap;align-items:center;padding-block:8px}
nav.bar a{color:var(--fg);font:600 13px var(--mono);letter-spacing:.06em;text-transform:uppercase;padding:6px 10px;border-radius:2px}
nav.bar a:hover{background:var(--panel2);text-decoration:none}
nav.bar input{margin-left:auto;background:var(--panel);border:1px solid var(--line);color:var(--fg);font:14px var(--mono);padding:6px 10px;min-width:200px;border-radius:2px}
nav.bar input:focus{outline:2px solid var(--hazard);outline-offset:1px}
.tiles{display:grid;grid-template-columns:repeat(auto-fit,minmax(140px,1fr));gap:1px;background:var(--line);border:1px solid var(--line);margin-top:24px}
.tile{background:var(--panel);padding:14px 16px}
.tile b{display:block;font:800 40px var(--display);line-height:1;font-variant-numeric:tabular-nums}
.tile span{font:600 11px var(--mono);letter-spacing:.1em;text-transform:uppercase;color:var(--mute)}
.pill{display:inline-block;font:600 11px var(--mono);letter-spacing:.08em;text-transform:uppercase;padding:2px 8px;border-radius:2px;border:1px solid currentColor;white-space:nowrap}
.pill.done{color:var(--ok)}.pill.inprog{color:var(--warn)}.pill.queued{color:var(--mute)}.pill.open{color:var(--alert)}
.mstrip{display:grid;grid-template-columns:repeat(auto-fit,minmax(220px,1fr));gap:12px;margin-top:16px}
.ms{background:var(--panel);border-left:4px solid var(--line);padding:12px 14px}
.ms.inprog{border-left-color:var(--warn)}.ms.done{border-left-color:var(--ok)}
.ms .id{font:800 20px var(--display)}
.ms p{margin:6px 0 0;color:var(--mute);font-size:14px}
.chart{background:var(--panel);border:1px solid var(--line);padding:16px;overflow-x:auto}
.chart svg{display:block;width:100%;height:auto;max-width:100%}
.legend{display:flex;gap:18px;flex-wrap:wrap;font:600 12px var(--mono);color:var(--mute);margin-top:8px}
.legend i{display:inline-block;width:12px;height:12px;vertical-align:-1px;margin-right:6px}
.filters{display:flex;gap:6px;flex-wrap:wrap;margin-bottom:12px}
.filters button{background:var(--panel);border:1px solid var(--line);color:var(--fg);font:600 12px var(--mono);letter-spacing:.06em;text-transform:uppercase;padding:6px 10px;cursor:pointer;border-radius:2px}
.filters button[aria-pressed="true"]{background:var(--hazard);color:#111;border-color:var(--hazard)}
.filters button:focus-visible{outline:2px solid var(--hazard);outline-offset:2px}
.phase{background:var(--panel);border:1px solid var(--line);margin-bottom:10px}
.phase summary{list-style:none;cursor:pointer;padding:14px 16px;display:grid;grid-template-columns:1fr auto;gap:8px 16px;align-items:center}
.phase summary::-webkit-details-marker{display:none}
.phase summary:focus-visible{outline:2px solid var(--hazard);outline-offset:-2px}
.phase .gate{font-size:13px;color:var(--mute);grid-column:1/-1}
.bar{grid-column:1/-1;height:8px;background:var(--panel2);position:relative}
.bar i{position:absolute;inset:0 auto 0 0;background:var(--ok)}
.bar em{position:absolute;inset:0 auto 0 0;background:var(--warn);opacity:.7}
.phase .body{padding:0 16px 16px;border-top:1px solid var(--line)}
.item{display:grid;grid-template-columns:96px 1fr;gap:12px;padding:10px 0;border-bottom:1px dashed var(--line);align-items:start}
.item:last-child{border-bottom:0}
.chips{display:flex;gap:4px;flex-wrap:wrap;margin-top:4px}
.chip{font:500 12px var(--mono);background:var(--panel2);padding:1px 6px;border-radius:2px;color:var(--fg)}
.chip.closed{text-decoration:line-through;color:var(--mute)}
.asks{margin-top:14px;border:1px solid var(--hazard);padding:10px 14px}
.asks b{font:600 11px var(--mono);letter-spacing:.1em;text-transform:uppercase;color:var(--hazard)}
.asks ul{margin:6px 0 0;padding-left:18px}
.day{display:grid;grid-template-columns:120px 1fr;gap:20px;padding:22px 0;border-top:1px solid var(--line)}
.day .when{font:600 13px var(--mono);color:var(--mute);line-height:1.6}
.day .when b{display:block;font:800 30px var(--display);color:var(--fg);line-height:1}
.day p{margin:6px 0 0;max-width:70ch}
.day .meta{display:flex;gap:10px;flex-wrap:wrap;margin-top:10px;font:600 12px var(--mono);color:var(--mute)}
.day .meta button{background:none;border:0;color:var(--blue);font:inherit;cursor:pointer;padding:0}
.thumbs{display:grid;grid-template-columns:repeat(auto-fill,minmax(150px,1fr));gap:8px;margin-top:12px}
.thumbs button{background:var(--panel2);border:1px solid var(--line);padding:0;cursor:pointer;aspect-ratio:16/9;overflow:hidden;max-width:100%}
.thumbs img{width:100%;height:100%;object-fit:cover;display:block}
.quotes{display:grid;grid-template-columns:repeat(auto-fit,minmax(300px,1fr));gap:10px}
.q{background:var(--panel);border-top:3px solid var(--alert);padding:14px 16px}
.q blockquote{margin:0;font:600 20px/1.2 var(--display);text-transform:uppercase}
.q .when{font:600 11px var(--mono);color:var(--mute);letter-spacing:.08em}
.q p{margin:8px 0 0;font-size:14px;color:var(--mute)}
table{width:100%;border-collapse:collapse;font-size:14px}
th{font:600 11px var(--mono);letter-spacing:.1em;text-transform:uppercase;color:var(--mute);text-align:left;padding:8px 8px;border-bottom:1px solid var(--line)}
td{padding:7px 8px;border-bottom:1px solid var(--line);vertical-align:top}
td.mono{font:500 13px var(--mono);white-space:nowrap}
.tscroll{overflow-x:auto;background:var(--panel);border:1px solid var(--line)}
details.dec summary{cursor:pointer;list-style:none}
details.dec summary::-webkit-details-marker{display:none}
details.dec p{margin:6px 0 0;font-size:13px;color:var(--mute);max-width:80ch}
.gallery{display:grid;grid-template-columns:repeat(auto-fill,minmax(240px,1fr));gap:10px}
.gallery figure{margin:0;background:var(--panel);border:1px solid var(--line)}
.gallery img{width:100%;display:block;aspect-ratio:16/9;object-fit:cover;cursor:zoom-in}
.gallery figcaption{padding:8px 10px;font-size:13px;color:var(--mute)}
.lightbox{position:fixed;inset:0;background:rgba(0,0,0,.92);z-index:20;display:flex;flex-direction:column;align-items:center;justify-content:center;padding:max(16px,env(safe-area-inset-top,0px)) max(16px,env(safe-area-inset-right,0px)) max(16px,env(safe-area-inset-bottom,0px)) max(16px,env(safe-area-inset-left,0px))}
.lightbox img{max-width:100%;max-height:85vh;object-fit:contain}
.lightbox p{color:#ddd;font:14px var(--body);margin:10px 0 0;text-align:center}
.lightbox button{position:absolute;top:max(12px,env(safe-area-inset-top,0px));right:max(12px,env(safe-area-inset-right,0px));background:var(--hazard);color:#111;border:0;font:800 16px var(--display);padding:8px 14px;cursor:pointer}
.empty{color:var(--mute);font-style:italic}
footer{margin-top:56px;padding-top:16px;border-top:1px solid var(--line);font:13px var(--mono);color:var(--mute)}
.hit{background:color-mix(in srgb,var(--hazard) 35%,transparent)}
@media (max-width:640px){.day,.item{grid-template-columns:1fr}.day .when b{display:inline;margin-right:8px}}
@media (prefers-reduced-motion:no-preference){.bar i,.bar em{transition:width .4s ease}}
</style>

<div class="tape"></div>
<div class="wrap">
<header class="mast">
  <div class="row">
    <div>
      <div class="eyebrow">Development journal · <span id="dayno"></span></div>
      <h1>Kaiju Incremental</h1>
      <p>From the kickoff on <span id="startd"></span> to today. Every ruling, every merge, every build he played, in the order the roadmap runs. Designed by a person, developed with AI.</p>
    </div>
    <div class="eyebrow" id="updated"></div>
  </div>
  <div class="tiles" id="tiles"></div>
</header>

<nav class="bar" aria-label="Sections">
  <a href="#milestones">Milestones</a><a href="#phases">Phases</a><a href="#days">Days</a><a href="#words">His words</a><a href="#decisions">Decisions</a><a href="#gallery">Gallery</a>
  <input id="search" type="search" placeholder="Search decisions, PRs, items" aria-label="Search">
</nav>

<h2 id="milestones">Playtest milestones <small>D-146 · he plays only at these</small></h2>
<div class="mstrip" id="mstrip"></div>
<h3 style="margin-top:20px">Builds he has played</h3>
<div class="tscroll" style="margin-top:8px"><table><thead><tr><th>Date</th><th>Build</th><th>Verdict</th></tr></thead><tbody id="builds"></tbody></table></div>

<h2>Pace <small>per day · merges, rulings, his notes</small></h2>
<div class="chart"><div id="pace"></div>
<div class="legend"><span><i style="background:var(--ok)"></i>PRs merged</span><span><i style="background:var(--hazard)"></i>Decisions</span><span><i style="background:var(--alert)"></i>Director notes recorded</span></div></div>
<div class="chart" style="margin-top:10px"><div id="notesbar"></div></div>

<h2 id="phases">Roadmap phases <small>the spine · click a phase to open it</small></h2>
<div class="filters" id="pfilters" role="group" aria-label="Filter phases">
  <button aria-pressed="true" data-f="all">All</button><button aria-pressed="false" data-f="done">Done</button><button aria-pressed="false" data-f="in progress">In progress</button><button aria-pressed="false" data-f="queued">Queued</button>
</div>
<div id="phaselist"></div>

<h2 id="days">Day by day <small>what happened, with the captures he saw</small></h2>
<div id="daylist"></div>

<h2 id="words">His words that changed the game <small>highlights only</small></h2>
<div class="quotes" id="quotes"></div>

<h2 id="decisions">Decisions <small id="deccount"></small></h2>
<div class="filters" id="dfilters" role="group" aria-label="Filter decisions by day"></div>
<div class="tscroll"><table><thead><tr><th>Date</th><th>Id</th><th>Who</th><th>Ruling</th></tr></thead><tbody id="dectable"></tbody></table></div>

<h2 id="gallery">Gallery <small>every capture in the journal</small></h2>
<div class="gallery" id="gallery"></div>

<footer>Generated <span id="gen"></span> by tools/journal.py from docs/roadmap/journal.json, docs/DECISIONS.md, the roadmap note tables and the PR list. Rebuild after merges: <code>python tools/journal.py</code>.</footer>
</div>

<script id="data" type="application/json">__DATA__</script>
<script>
(function(){
const D = JSON.parse(document.getElementById('data').textContent);
const $ = s => document.querySelector(s);
const esc = s => String(s).replace(/[&<>"]/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c]));
const prUrl = n => 'https://github.com/' + D.repo + '/pull/' + n;
const prBy = {}; D.prs.forEach(p => prBy[p.n] = p);
const cls = s => s === 'done' ? 'done' : s === 'in progress' ? 'inprog' : s === 'open' ? 'open' : 'queued';
const fmt = d => { const [y,m,dd] = d.split('-'); return ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][+m-1] + ' ' + (+dd); };

// masthead
$('#dayno').textContent = 'day ' + D.day + ' · ' + D.today;
$('#startd').textContent = D.start;
$('#updated').textContent = 'updated ' + D.generated;
$('#gen').textContent = D.generated;
const merged = D.prs.filter(p => p.s === 'MERGED');
const open = D.prs.filter(p => p.s === 'OPEN');
const byDir = D.decisions.filter(d => d.who === 'Director').length;
$('#tiles').innerHTML = [
  [D.day, 'days in'], [D.decisions.length, 'rulings (' + byDir + ' his)'], [merged.length, 'PRs merged'],
  [open.length, 'PRs open'], [D.notes.length, 'notes of his recorded'], [D.builds.length, 'builds played']
].map(([n, l]) => '<div class="tile"><b>' + n + '</b><span>' + l + '</span></div>').join('');

// milestones and builds
$('#mstrip').innerHTML = D.milestones.map(m => '<div class="ms ' + cls(m.status) + '"><span class="id">' + esc(m.id) + ' · ' + esc(m.name) + '</span> <span class="pill ' + cls(m.status) + '">' + esc(m.status) + '</span><p>' + esc(m.what) + '</p></div>').join('');
$('#builds').innerHTML = D.builds.map(b => '<tr><td class="mono">' + b.date + '</td><td>' + esc(b.name) + '</td><td>' + esc(b.verdict) + '</td></tr>').join('');

// pace chart (SVG, one scale)
const days = D.days.map(d => d.date);
const count = (arr, key) => days.map(day => arr.filter(x => x[key] === day).length);
const mergesPer = count(merged, 'm'), decsPer = count(D.decisions, 'date'), notesPer = count(D.notes, 'date');
const max = Math.max(1, ...mergesPer, ...decsPer, ...notesPer);
(function(){
  const W = 1000, H = 260, L = 40, B = 40, T = 16, gw = (W - L - 10) / days.length, bw = Math.min(26, gw / 4);
  const y = v => T + (H - T - B) * (1 - v / max);
  let s = '<svg viewBox="0 0 ' + W + ' ' + H + '" role="img" aria-label="Merges, decisions and director notes per day">';
  const ticks = [0, Math.round(max / 2), max];
  ticks.forEach(t => { s += '<line x1="' + L + '" x2="' + W + '" y1="' + y(t) + '" y2="' + y(t) + '" stroke="var(--line)"/><text x="' + (L - 8) + '" y="' + (y(t) + 4) + '" text-anchor="end" font-size="12" font-family="JetBrains Mono,monospace" fill="var(--mute)">' + t + '</text>'; });
  days.forEach((day, i) => {
    const x0 = L + i * gw + gw / 2 - bw * 1.5 - 4;
    const vals = [[mergesPer[i], 'var(--ok)', 'PRs merged'], [decsPer[i], 'var(--hazard)', 'decisions'], [notesPer[i], 'var(--alert)', 'notes']];
    s += '<a href="#d-' + day + '"><g>';
    vals.forEach(([v, c, l], k) => { const x = x0 + k * (bw + 4); s += '<rect x="' + x + '" y="' + y(v) + '" width="' + bw + '" height="' + (y(0) - y(v)) + '" fill="' + c + '"><title>' + fmt(day) + ': ' + v + ' ' + l + '</title></rect>'; if (v) s += '<text x="' + (x + bw / 2) + '" y="' + (y(v) - 4) + '" text-anchor="middle" font-size="11" font-family="JetBrains Mono,monospace" fill="var(--fg)">' + v + '</text>'; });
    s += '<text x="' + (L + i * gw + gw / 2) + '" y="' + (H - 14) + '" text-anchor="middle" font-size="13" font-family="JetBrains Mono,monospace" fill="var(--fg)">' + fmt(day) + '</text></g></a>';
  });
  s += '</svg>';
  $('#pace').innerHTML = s;
})();

// director notes: acted on
(function(){
  const b = { done: 0, 'in progress': 0, open: 0 }; D.notes.forEach(n => b[n.bucket]++);
  const tot = D.notes.length || 1;
  const seg = (k, c) => '<div style="width:' + (100 * b[k] / tot) + '%;background:' + c + '" title="' + k + ': ' + b[k] + '"></div>';
  $('#notesbar').innerHTML = '<div class="eyebrow" style="color:var(--mute);margin-bottom:8px">His ' + tot + ' playtest and comment notes, by state</div><div style="display:flex;height:18px;overflow:hidden">' + seg('done', 'var(--ok)') + seg('in progress', 'var(--warn)') + seg('open', 'var(--alert)') + '</div><div class="legend"><span><i style="background:var(--ok)"></i>acted on, merged or recorded ' + b.done + '</span><span><i style="background:var(--warn)"></i>in progress ' + b['in progress'] + '</span><span><i style="background:var(--alert)"></i>open ' + b.open + '</span></div>';
})();

// phases
const chip = n => { const p = prBy[n]; const closed = D.closedPrs.includes(n) || (p && p.s === 'CLOSED'); return '<a class="chip' + (closed ? ' closed' : '') + '" href="' + prUrl(n) + '" target="_blank" rel="noopener" title="' + esc(p ? p.t : '') + '">#' + n + '</a>'; };
function renderPhases(filter){
  $('#phaselist').innerHTML = D.phases.filter(p => filter === 'all' || p.status === filter).map(p => {
    const n = p.items.length, done = p.items.filter(i => i.status === 'done').length, prog = p.items.filter(i => i.status === 'in progress').length;
    const prs = p.items.reduce((a, i) => a + i.prs.filter(x => prBy[x] && prBy[x].s === 'MERGED').length, 0);
    return '<details class="phase" id="p-' + p.id + '"' + (p.status === 'in progress' ? ' open' : '') + '><summary>' +
      '<h3>' + esc(p.name) + '</h3><span><span class="pill ' + cls(p.status) + '">' + esc(p.status) + '</span> <span class="chip">' + done + '/' + n + ' items · ' + prs + ' PRs</span></span>' +
      '<div class="gate">Gate: ' + esc(p.gate) + '</div>' +
      '<div class="bar"><em style="width:' + (100 * (done + prog) / n) + '%"></em><i style="width:' + (100 * done / n) + '%"></i></div></summary>' +
      '<div class="body">' + p.items.map(i => '<div class="item" data-search="' + esc(i.text + ' ' + i.prs.map(x => '#' + x + ' ' + (prBy[x] ? prBy[x].t : '')).join(' ')) + '"><span class="pill ' + cls(i.status) + '">' + esc(i.status) + '</span><div>' + esc(i.text) + (i.prs.length ? '<div class="chips">' + i.prs.map(chip).join('') + '</div>' : '') + '</div></div>').join('') +
      (p.asks.length ? '<div class="asks"><b>Waiting on you at this phase</b><ul>' + p.asks.map(a => '<li>' + esc(a) + '</li>').join('') + '</ul></div>' : '') +
      '</div></details>';
  }).join('') || '<p class="empty">No phase in that state.</p>';
}
renderPhases('all');
$('#pfilters').addEventListener('click', e => { const b = e.target.closest('button'); if (!b) return; [...$('#pfilters').children].forEach(x => x.setAttribute('aria-pressed', x === b)); renderPhases(b.dataset.f); });

// days
$('#daylist').innerHTML = D.days.map((d, i) => {
  const decs = D.decisions.filter(x => x.date === d.date), m = mergesPer[i], notes = notesPer[i];
  const ids = decs.map(x => x.id.replace('D-', '')); const span = ids.length ? (ids.length > 1 ? 'D-' + ids[0] + ' to D-' + ids[ids.length - 1] : 'D-' + ids[0]) : '';
  return '<div class="day" id="d-' + d.date + '"><div class="when"><b>Day ' + (i + 1) + '</b>' + fmt(d.date) + '<br>' + d.date + '</div><div>' +
    '<h3>' + esc(d.title) + '</h3><p>' + esc(d.text) + '</p>' +
    '<div class="meta"><span>' + m + ' merged</span><span>' + decs.length + ' rulings' + (span ? ' · <button data-day="' + d.date + '">' + span + '</button>' : '') + '</span><span>' + notes + ' notes of his</span></div>' +
    (d.captures.length ? '<div class="thumbs">' + d.captures.map(k => '<button data-cap="' + k + '" aria-label="' + esc(D.captures[k].caption) + '"><img src="img/' + k + '.webp" alt="' + esc(D.captures[k].caption) + '" loading="lazy"></button>').join('') + '</div>' : '') +
    '</div></div>';
}).join('');

// quotes
$('#quotes').innerHTML = D.highlights.map(q => '<div class="q"><div class="when">' + q.date + '</div><blockquote>“' + esc(q.quote) + '”</blockquote><p>' + esc(q.effect) + '</p></div>').join('');

// decisions
const decDays = [...new Set(D.decisions.map(d => d.date))];
$('#dfilters').innerHTML = '<button aria-pressed="true" data-f="all">All</button>' + decDays.map(d => '<button aria-pressed="false" data-f="' + d + '">' + fmt(d) + '</button>').join('');
let decFilter = 'all';
function renderDecs(q){
  const rows = D.decisions.filter(d => (decFilter === 'all' || d.date === decFilter) && (!q || (d.id + ' ' + d.title + ' ' + d.body).toLowerCase().includes(q))).slice().reverse();
  $('#deccount').textContent = rows.length + ' of ' + D.decisions.length + ' · newest first · click one for its reasoning';
  $('#dectable').innerHTML = rows.map(d => '<tr><td class="mono">' + d.date + '</td><td class="mono">' + d.id + '</td><td>' + esc(d.who) + '</td><td><details class="dec"><summary>' + esc(d.title) + '</summary><p>' + esc(d.body) + '</p></details></td></tr>').join('') || '<tr><td colspan="4" class="empty">Nothing matches.</td></tr>';
}
renderDecs('');
$('#dfilters').addEventListener('click', e => { const b = e.target.closest('button'); if (!b) return; [...$('#dfilters').children].forEach(x => x.setAttribute('aria-pressed', x === b)); decFilter = b.dataset.f; renderDecs($('#search').value.trim().toLowerCase()); });
$('#daylist').addEventListener('click', e => { const b = e.target.closest('button[data-day]'); if (b) { decFilter = b.dataset.day; [...$('#dfilters').children].forEach(x => x.setAttribute('aria-pressed', x.dataset.f === decFilter)); renderDecs(''); location.hash = 'decisions'; } });

// search: decisions table + phase items
$('#search').addEventListener('input', e => {
  const q = e.target.value.trim().toLowerCase(); renderDecs(q);
  document.querySelectorAll('.item').forEach(el => { const hit = q && el.dataset.search.toLowerCase().includes(q); el.classList.toggle('hit', !!hit); el.hidden = !!q && !hit; });
  document.querySelectorAll('.phase').forEach(p => { if (q) p.open = [...p.querySelectorAll('.item')].some(i => !i.hidden); });
});

// gallery + lightbox
$('#gallery').innerHTML = Object.keys(D.captures).map(k => '<figure><img src="img/' + k + '.webp" alt="' + esc(D.captures[k].caption) + '" loading="lazy" data-cap="' + k + '"><figcaption>' + esc(D.captures[k].caption) + '</figcaption></figure>').join('');
function openCap(k){ const c = D.captures[k]; const box = document.createElement('div'); box.className = 'lightbox'; box.innerHTML = '<button type="button">Close</button><img src="img/' + k + '.webp" alt="' + esc(c.caption) + '"><p>' + esc(c.caption) + '</p>'; box.addEventListener('click', () => box.remove()); document.body.appendChild(box); box.querySelector('button').focus(); }
document.addEventListener('click', e => { const t = e.target.closest('[data-cap]'); if (t) openCap(t.dataset.cap); });
document.addEventListener('keydown', e => { if (e.key === 'Escape') document.querySelectorAll('.lightbox').forEach(b => b.remove()); });

// hash → open a phase
if (location.hash.startsWith('#p-')) { const p = document.getElementById(location.hash.slice(1)); if (p) p.open = true; }
})();
</script>
"""


def main(argv):
    use_gh = "--no-gh" not in argv
    journal = json.loads(read(JOURNAL))
    prs = pull_requests(use_gh)
    if "--check" in argv:
        return check(journal, prs)
    build(journal, prs, use_gh)
    return check(journal, prs)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
