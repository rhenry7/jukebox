"""Usage: python3 scripts/token_audit.py . docs/ui_audit/token_mapping.md

Scan lib/ for hard-coded spacing, radius and color values and map each to
the tokens in lib/ui/theme/tokens.dart. Writes markdown to argv[2]."""
import os
import re
import sys
from collections import Counter, defaultdict

ROOT = sys.argv[1]
OUT = sys.argv[2]
LIB = os.path.join(ROOT, "lib")

SPACING = [(0, "none"), (2, "xxs"), (4, "xs"), (8, "sm"), (12, "md"),
           (16, "lg"), (24, "xl"), (32, "xxl"), (48, "xxxl"), (64, "huge")]
RADIUS = [(0, "none"), (4, "xs"), (8, "sm"), (12, "md"), (16, "lg"),
          (24, "xl"), (25, "input"), (999, "pill")]


def snap(v, scale):
    """Nearest token; ties round up (Breathing Room rule)."""
    best = None
    for tv, name in scale:
        d = abs(tv - v)
        if best is None or d < best[0] or (d == best[0] and tv > best[1]):
            best = (d, tv, name)
    return best[1], best[2]


def spacing_token(v):
    if v > 64:
        return None, f"{v:g} (keep — layout-specific)", "keep"
    tv, name = snap(v, SPACING)
    return tv, f"AppSpacing.{name}", "exact" if tv == v else f"{v:g}→{tv:g}"


def radius_token(v):
    if v >= 30:
        return 999, "AppRadius.pill", "exact" if v in (999, 9999) else f"{v:g}→pill"
    if v < 4 and v > 0:
        return None, f"{v:g} (keep — hairline/handle)", "keep"
    tv, name = snap(v, RADIUS)
    return tv, f"AppRadius.{name}", "exact" if tv == v else f"{v:g}→{tv:g}"


NUM = r"(\d+(?:\.\d+)?)"
EDGE_RE = re.compile(r"EdgeInsets\.(all|symmetric|only|fromLTRB)\(([^()]*)\)")
SIZED_RE = re.compile(r"SizedBox\(\s*(height|width):\s*" + NUM + r"\s*[,)]")
GAP_RE = re.compile(r"\bGap\(\s*" + NUM + r"\s*\)")
RADIUS_RE = re.compile(r"(?:BorderRadius\.circular|Radius\.circular)\(\s*([^()]*?)\s*\)")

# Colors -> token. Keys are normalized source text.
COLOR_MAP = {
    "Color(0xFFEE2309)": "primary", "Color(0xFFCC1111)": "primary",
    "Colors.red": "primary", "Colors.red[600]": "primary", "Colors.red[700]": "primaryDim",
    "Colors.red[400]": "primaryLight", "Colors.redAccent": "primary",
    "Color.fromARGB(255, 220, 53, 69)": "error", "Color.fromARGB(255, 255, 9, 9)": "primary",
    "Color.fromARGB(255, 227, 44, 27)": "primary", "Color.fromARGB(255, 220, 40, 23)": "primary",
    "Color.fromARGB(255, 214, 30, 30)": "primary", "Color.fromRGBO(214, 40, 40, 80)": "primary",
    "Color(0xFFFF3B30)": "error", "Color(0xFFEF4444)": "error",
    "Color(0xFF3FFF8B)": "secondary", "Color(0xFF39FF6A)": "secondary",
    "Color(0xFF22C55E)": "success", "Color(0xFF2DBD3A)": "success",
    "Colors.green": "success", "Colors.greenAccent": "secondary", "Colors.greenAccent[700]": "success",
    "Colors.black": "surfaceContainerLowest",
    "Color(0xFF0E0E0E)": "background", "Color(0xFF0D0D0D)": "background",
    "Color(0xFF0A0A0A)": "background", "Color(0xFF121212)": "background",
    "Color(0xFF131313)": "surfaceContainerLow",
    "Color(0xFF1A1919)": "surfaceContainer", "Color(0xFF1A1A1A)": "surfaceContainer",
    "Color(0xFF1C1C1C)": "surfaceContainer",
    "Color(0xFF201F1F)": "surfaceContainerHigh", "Colors.grey[900]": "surfaceContainerHigh",
    "Colors.grey[850]": "surfaceContainerHighest", "Colors.grey[800]": "surfaceContainerHighest",
    "Color(0xFF494847)": "outlineVariant", "Color(0xFF5A5A5A)": "outlineVariant",
    "Color.fromARGB(56, 158, 158, 158)": "ghostBorder (22%→15%)",
    "Color(0xFFADAAAA)": "onSurfaceVariant", "Colors.grey": "onSurfaceVariant",
    "Colors.grey[400]": "onSurfaceVariant", "Colors.grey[500]": "onSurfaceVariant",
    "Colors.grey[600]": "onSurfaceVariant", "Colors.grey[700]": "outlineVariant",
    "Color(0xFF6B7280)": "onSurfaceVariant",
    "Colors.white": "onSurface (onSurfaceVariant for metadata)",
    "Colors.orange": "warning", "Color(0xFFF59E0B)": "warning",
    "Colors.amber": "rating (new token — star color)",
    "Colors.transparent": "(keep Colors.transparent)",
    "Color(0x08FFFFFF)": "onSurface @3%", "Color(0x1AFFFFFF)": "onSurface @10%",
    "Color(0x4DFFFFFF)": "onSurface @30%", "Color(0x66FFFFFF)": "onSurface @40%",
    "Color(0x99CC0000)": "primary @60%", "Color(0x88CC0000)": "primary @53%",
    "Color(0x44CC0000)": "primary @27%", "Color(0x55FF2200)": "primary @33%",
    "Color.fromARGB(61, 172, 49, 49)": "primary @24%",
    "Color.fromARGB(4, 131, 131, 131)": "onSurfaceVariant @2% (likely invisible — check)",
    "Color.fromARGB(255, 239, 239, 239)": "onSurface",
    "Color.fromARGB(255, 138, 138, 138)": "onSurfaceVariant",
    "Colors.grey[300]": "onSurfaceVariant", "Colors.grey[200]": "onSurface",
    "Colors.red[300]": "primaryLight", "Colors.green[400]": "success",
    "Colors.green[600]": "success", "Colors.orange[400]": "warning",
    "Colors.orangeAccent": "warning", "Colors.deepOrangeAccent": "primaryLight",
    "Colors.yellow": "rating", "Colors.blue": "review — off-palette",
}
DATA_PALETTE_HINT = "data palette (genre/chart/heatmap) — move to a dedicated const list, don't tokenize"
COLOR_RE = re.compile(
    r"(Color\(0x[0-9A-Fa-f]{8}\)|Color\.from(?:RGBO|ARGB)\([^)]*\)|"
    r"Colors\.[a-zA-Z]+(?:\[\d+\])?)"
    r"(\.with(?:Opacity\([0-9.]+\)|Values\(alpha:\s*[0-9.]+\)))?")


def parse_args(kind, args):
    """Return list of (label, numeric_or_None, raw)."""
    out = []
    if kind == "all":
        out.append(("all", args.strip()))
    elif kind == "fromLTRB":
        for lab, a in zip("LTRB", args.split(",")):
            out.append((lab, a.strip()))
    else:
        for part in args.split(","):
            if ":" in part:
                k, v = part.split(":", 1)
                out.append((k.strip(), v.strip()))
    res = []
    for lab, raw in out:
        m = re.fullmatch(NUM, raw)
        res.append((lab, float(m.group(1)) if m else None, raw))
    return res


spacing_rows, radius_rows = [], []
color_uses = defaultdict(Counter)  # base -> file counter
color_alpha = defaultdict(Counter)
manual = []

for dirpath, _, files in os.walk(LIB):
    for fn in sorted(files):
        if not fn.endswith(".dart") or fn == "tokens.dart":
            continue
        path = os.path.join(dirpath, fn)
        rel = os.path.relpath(path, ROOT)
        with open(path, encoding="utf-8") as f:
            for ln, line in enumerate(f, 1):
                for m in EDGE_RE.finditer(line):
                    parts = parse_args(m.group(1), m.group(2))
                    if not parts:
                        continue
                    proposed, changes = [], []
                    for lab, v, raw in parts:
                        if v is None:
                            if raw.startswith("AppSpacing."):
                                proposed.append(raw if lab in ("all", "L", "T", "R", "B") else f"{lab}: {raw}")
                                changes.append("exact")
                                continue
                            manual.append((rel, ln, m.group(0)))
                            proposed.append(f"{lab}: {raw}")
                            changes.append("manual")
                            continue
                        _, tok, ch = spacing_token(v)
                        proposed.append(tok if lab in ("all", "L", "T", "R", "B") else f"{lab}: {tok}")
                        changes.append(ch)
                    spacing_rows.append((rel, ln, m.group(0),
                                         f"EdgeInsets.{m.group(1)}({', '.join(proposed)})",
                                         ", ".join(c for c in changes if c != "exact") or "exact"))
                for m in SIZED_RE.finditer(line):
                    v = float(m.group(2))
                    _, tok, ch = spacing_token(v)
                    spacing_rows.append((rel, ln, m.group(0).rstrip(",)") + ")",
                                         f"SizedBox({m.group(1)}: {tok})", ch))
                for m in GAP_RE.finditer(line):
                    v = float(m.group(1))
                    _, tok, ch = spacing_token(v)
                    spacing_rows.append((rel, ln, m.group(0), f"Gap({tok})", ch))
                for m in RADIUS_RE.finditer(line):
                    raw = m.group(1)
                    nm = re.fullmatch(NUM, raw)
                    if not nm:
                        if not raw.startswith("AppRadius."):
                            manual.append((rel, ln, m.group(0)))
                        continue
                    _, tok, ch = radius_token(float(nm.group(1)))
                    radius_rows.append((rel, ln, m.group(0), tok, ch))
                for m in COLOR_RE.finditer(line):
                    base = re.sub(r"\s+", " ", m.group(1))
                    base = re.sub(r"0x([0-9a-f]{8})", lambda x: "0x" + x.group(1).upper(), base)
                    color_uses[base][rel] += 1
                    if m.group(2):
                        a = re.search(r"([0-9.]+)\)$", m.group(2)).group(1)
                        color_alpha[base][a] += 1

# Only show color groups that are actual colors (skip e.g. Colors.primaries)
def esc(s):
    return s.replace("|", "\\|")


def summarize(rows):
    total = len(rows)
    exact = sum(1 for r in rows if r[4] == "exact")
    keep = sum(1 for r in rows if "keep" in r[4])
    return total, exact, keep, total - exact - keep


with open(OUT, "w", encoding="utf-8") as o:
    o.write("# Token mapping — generated\n\n")
    o.write("Generated by a scan of `lib/` against `lib/ui/theme/tokens.dart`. "
            "Snapping rule: nearest token, ties round **up** (Breathing Room rule).\n\n")
    st, se, sk, sc = summarize(spacing_rows)
    rt, re_, rk, rc = summarize(radius_rows)
    o.write("| Category | Occurrences | Already on scale | Keep as-is | Will change value |\n|---|---|---|---|---|\n")
    o.write(f"| Spacing (EdgeInsets / SizedBox / Gap) | {st} | {se} | {sk} | {sc} |\n")
    o.write(f"| Radius | {rt} | {re_} | {rk} | {rc} |\n")
    o.write(f"| Colors | {sum(sum(c.values()) for c in color_uses.values())} uses of {len(color_uses)} distinct values | | | |\n")
    o.write(f"| Non-literal (needs manual review) | {len(manual)} | | | |\n\n")

    o.write("## Value changes at a glance\n\n")
    for title, rows in (("Spacing", spacing_rows), ("Radius", radius_rows)):
        c = Counter()
        for r in rows:
            for part in r[4].split(", "):
                if "→" in part:
                    c[part] += 1
        o.write(f"**{title}:** " + ", ".join(f"`{k}` ×{v}" for k, v in
                                               sorted(c.items(), key=lambda kv: -kv[1])) + "\n\n")

    o.write("## Colors (grouped by value)\n\n| Value | Uses | Proposed token | Opacities seen | Files |\n|---|---|---|---|---|\n")
    for base, files in sorted(color_uses.items(), key=lambda kv: -sum(kv[1].values())):
        tok = COLOR_MAP.get(base)
        if tok is None:
            if base.startswith("Colors.") and not re.match(r"Colors\.(white|black|grey|red|green|blue|amber|orange|purple|pink|yellow|teal|cyan|indigo|lime|brown|deepPurple|deepOrange|lightBlue|lightGreen|blueGrey|redAccent|greenAccent|blueAccent|purpleAccent|orangeAccent|pinkAccent|white\d+|black\d+)", base):
                continue
            tok = DATA_PALETTE_HINT if base.startswith("Color(") else "review"
        alphas = ", ".join(f"{a}×{n}" for a, n in color_alpha[base].most_common(6))
        fl = ", ".join(f"`{os.path.basename(f)}`×{n}" for f, n in files.most_common(4))
        if len(files) > 4:
            fl += f", +{len(files) - 4} more"
        o.write(f"| `{esc(base)}` | {sum(files.values())} | {tok} | {alphas} | {fl} |\n")

    o.write("\n## Radius — every occurrence\n\n| Location | Current | Proposed | Change |\n|---|---|---|---|\n")
    for rel, ln, cur, tok, ch in sorted(radius_rows):
        o.write(f"| `{rel}:{ln}` | `{esc(cur)}` | `{tok}` | {ch} |\n")

    o.write("\n## Spacing — every occurrence\n\n| Location | Current | Proposed | Change |\n|---|---|---|---|\n")
    for rel, ln, cur, prop, ch in sorted(spacing_rows):
        o.write(f"| `{rel}:{ln}` | `{esc(cur)}` | `{esc(prop)}` | {ch} |\n")

    o.write("\n## Needs manual review (computed values)\n\n")
    for rel, ln, cur in sorted(set(manual)):
        o.write(f"- `{rel}:{ln}` — `{esc(cur)}`\n")

print(f"spacing={summarize(spacing_rows)} radius={summarize(radius_rows)} "
      f"colors={len(color_uses)} manual={len(set(manual))}")
