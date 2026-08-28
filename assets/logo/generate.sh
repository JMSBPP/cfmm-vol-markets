#!/usr/bin/env bash
# Derive every raster and vector deliverable from the SVG masters in svg/.
# Idempotent: safe to re-run. Never hand-edit anything this script writes.
#
# Master -> raster mapping is BINDING (docs/superpowers/specs/2026-08-28-logo-design.md
# §7.1). Each raster is generated from the master for the TIER WHOSE RANGE CONTAINS ITS
# RENDERED SIZE — not from one master rasterised at every size:
#
#   16px                       -> icon-micro-*   (tier D, 16-23px)
#   32px, 48px                 -> icon-mid-*     (tier C, 24-63px)
#   64px, 128px, 256px, 512px  -> icon-*         (tier B, >=64px)
#   mark-full-* (all sizes)    -> mark-full-*    (tier A)
#
# Lockups are NOT square: rasterise by WIDTH ONLY (-w), never -h, so height follows
# the master's own aspect ratio instead of being distorted to a forced square.
set -euo pipefail
cd "$(dirname "$0")"

# Pin cairo's (via rsvg-convert) embedded PDF timestamp so pdf/mark-full.pdf is
# byte-reproducible across runs. Without this, cairo 1.18.4 stamps a per-run
# CreationDate/ModDate inside a FlateDecode-compressed object stream — invisible to a
# plain `grep`/`strings` pass, but it makes two back-to-back, otherwise-identical runs
# produce different sha256 hashes even within the same second. rsvg-convert honours
# SOURCE_DATE_EPOCH (https://reproducible-builds.org/specs/source-date-epoch/); cairo
# reads it directly. REMOVING THIS EXPORT SILENTLY BREAKS PDF REPRODUCIBILITY — the
# script will still exit 0 and produce a valid PDF, just a non-deterministic one.
# Value: 1787875200 = 2026-08-28T00:00:00Z, the date this visual identity was designed
# (docs/superpowers/specs/2026-08-28-logo-design.md). Arbitrary in the sense that any
# fixed constant works, but chosen to be meaningful rather than "whatever `date` gave
# the first run".
export SOURCE_DATE_EPOCH=1787875200

command -v rsvg-convert >/dev/null 2>&1 || {
  echo "FATAL: rsvg-convert not found. Install librsvg (Debian/Ubuntu: apt install librsvg2-bin; Arch: pacman -S librsvg)." >&2
  exit 1
}
python3 -c 'import PIL' >/dev/null 2>&1 || {
  echo "FATAL: Pillow not importable. Install it (pip install Pillow) — needed to verify rasters (transparency, dimensions, favicon.ico in a later task)." >&2
  exit 1
}

mkdir -p png pdf

# render_square <src.svg> <size> <out.png>
# Mark and icon masters are square (512x512 viewBox): pass both -w and -h.
render_square() {
  rsvg-convert -w "$2" -h "$2" -f png -o "$3" "$1"
}

# render_by_width <src.svg> <width> <out.png>
# Lockups are NOT square: pass -w only and let height follow the aspect ratio.
render_by_width() {
  rsvg-convert -w "$2" -f png -o "$3" "$1"
}

echo "== full mark (tier A) =="
for theme in light dark; do
  for size in 512 1024 2048; do
    render_square "svg/mark-full-${theme}.svg" "$size" "png/mark-full-${theme}-${size}.png"
  done
done

echo "== icon family (tiers B/C/D — each size from its own tier's master, per §7.1) =="
for theme in light dark; do
  # Tier D floor (16-23px): only the 16px raster.
  render_square "svg/icon-micro-${theme}.svg" 16 "png/icon-${theme}-16.png"
  # Tier C (24-63px): the 32 and 48px rasters.
  for size in 32 48; do
    render_square "svg/icon-mid-${theme}.svg" "$size" "png/icon-${theme}-${size}.png"
  done
  # Tier B (>=64px): 64 through 512.
  for size in 64 128 256 512; do
    render_square "svg/icon-${theme}.svg" "$size" "png/icon-${theme}-${size}.png"
  done
done

echo "== horizontal lockup (tier-A mark embedded) =="
for theme in light dark; do
  for width in 512 1024 2048; do
    render_by_width "svg/lockup-horizontal-${theme}.svg" "$width" "png/lockup-horizontal-${theme}-${width}.png"
  done
done

echo "== horizontal lockup, b variant (tier-B icon embedded) =="
for theme in light dark; do
  for width in 512 1024 2048; do
    render_by_width "svg/lockup-horizontal-b-${theme}.svg" "$width" "png/lockup-horizontal-b-${theme}-${width}.png"
  done
done

echo "== stacked lockup (tier-A mark embedded) =="
for theme in light dark; do
  for width in 512 1024 2048; do
    render_by_width "svg/lockup-stacked-${theme}.svg" "$width" "png/lockup-stacked-${theme}-${width}.png"
  done
done

echo "== vector PDF (for \\includegraphics in the LaTeX/Lean spec repo) =="
rsvg-convert -f pdf -o pdf/mark-full.pdf svg/mark-full-light.svg

echo "== favicon family =="
mkdir -p favicon

# Per §7.1: 16px is tier D (icon-micro), 32/48px are tier C (icon-mid). Task 6's
# png/icon-light-{16,32,48}.png already carry the correct tier's art (see the
# "icon family" loop above) — reuse them rather than re-rendering.
cp png/icon-light-16.png favicon/favicon-16x16.png
cp png/icon-light-32.png favicon/favicon-32x32.png

# 64px and above are tier B (icon-*), per §7.1 — apple-touch-icon (180) and the
# android-chrome sizes (192, 512) all qualify.
render_square "svg/icon-light.svg" 180 favicon/apple-touch-icon.png
render_square "svg/icon-light.svg" 192 favicon/android-chrome-192x192.png
render_square "svg/icon-light.svg" 512 favicon/android-chrome-512x512.png

# Multi-resolution .ico: each entry embeds its own tier's PNG verbatim (tools/mkico.py),
# rather than Pillow's ICO writer, which downsamples one source to every requested size
# and would push tier-B art down into the 16px slot. Per §7.1: 16 -> icon-micro (tier D),
# 32/48 -> icon-mid (tier C).
python3 tools/mkico.py favicon/favicon.ico \
  png/icon-light-16.png png/icon-light-32.png png/icon-light-48.png
python3 tools/check_ico.py favicon/favicon.ico

cat > favicon/site.webmanifest <<'MANIFEST'
{
  "name": "cfmm-vol-markets",
  "short_name": "cfmm-vol",
  "icons": [
    { "src": "android-chrome-192x192.png", "sizes": "192x192", "type": "image/png" },
    { "src": "android-chrome-512x512.png", "sizes": "512x512", "type": "image/png" }
  ],
  "theme_color": "#0D1117",
  "background_color": "#0D1117",
  "display": "standalone"
}
MANIFEST

# safari-pinned-tab.svg: Safari's mask-icon recolours the shape via the <link>'s
# `color` attribute, and expects a single-colour SVG with NO stroke attributes (it
# masks by alpha, and the historical guidance is fill-only geometry). Safari renders
# the pinned-tab mask at ~16px in the tab bar — tier D's range, per §7.1 — so this is
# derived from icon-micro-light.svg (tier D: blocks + arc, no notch, no label), NOT
# icon-light.svg (tier B): the tier-B sigma^2 label is unreadable noise at 16px, the
# exact defect §7.1 exists to prevent. icon-micro-light.svg's arc ("morphism-arc") is
# drawn as an 80-wide ROUND-CAPPED STROKE, not a fill — a naive fill-substitution
# (leaving the stroke attribute in place, or just recolouring it) would either keep a
# literal `stroke=` attribute or, if stroke-width were dropped too, collapse the arc
# from 80px wide to a hairline. Instead this converts the stroke to an equivalent
# FILLED OUTLINE: it samples the cubic Bezier, offsets left/right by half the stroke
# width along the curve normal, and closes the polygon with sampled round caps at both
# ends — reproducing the original stroked silhouette (verified by rasterising both and
# diffing alpha channels; see task-7-report.md for the measured delta) while using
# fill only.
#
# The arc's control points and stroke width are PARSED from icon-micro-light.svg at
# generation time (not hardcoded) so that if the master is ever edited, this derivation
# tracks it automatically instead of silently going stale. If the master's morphism-arc
# element ever stops matching the expected `d="M.. C.. .. .."` / `stroke-width="N"`
# single-segment shape, parsing fails loudly (raises) rather than silently reusing old
# geometry.
python3 - <<'PY'
import math
import pathlib
import re

logo = pathlib.Path(".")
src = (logo / "svg/icon-micro-light.svg").read_text()

arc_match = re.search(
    r'<path id="morphism-arc" d="([^"]+)" stroke="[^"]*" stroke-width="([0-9.]+)"',
    src,
)
if not arc_match:
    raise SystemExit(
        "safari-pinned-tab generation: could not find morphism-arc's d/stroke-width "
        "attributes in svg/icon-micro-light.svg in the expected d,stroke,stroke-width "
        "order -- the tier-D master changed shape; update the parser (or the "
        "hardcoded fallback it replaced) before regenerating the pinned tab."
    )
d_attr, stroke_width_str = arc_match.group(1), arc_match.group(2)

# d is a single "M x0 y0 C x1 y1 x2 y2 x3 y3" cubic segment -- exactly 8 numbers.
nums = [float(n) for n in re.findall(r'-?[0-9]*\.?[0-9]+', d_attr)]
if len(nums) != 8:
    raise SystemExit(
        f"safari-pinned-tab generation: expected a single M+C cubic (8 numbers) in "
        f"morphism-arc's d, got {len(nums)} from d={d_attr!r} -- the curve shape "
        f"changed; update the parser before regenerating the pinned tab."
    )
P0, P1, P2, P3 = (nums[0], nums[1]), (nums[2], nums[3]), (nums[4], nums[5]), (nums[6], nums[7])
R = float(stroke_width_str) / 2.0  # half the parsed stroke-width
N_CURVE, N_CAP = 48, 24


def bezier(t):
    mt = 1 - t
    x = mt**3*P0[0] + 3*mt**2*t*P1[0] + 3*mt*t**2*P2[0] + t**3*P3[0]
    y = mt**3*P0[1] + 3*mt**2*t*P1[1] + 3*mt*t**2*P2[1] + t**3*P3[1]
    return x, y


def bezier_deriv(t):
    mt = 1 - t
    dx = 3*mt**2*(P1[0]-P0[0]) + 6*mt*t*(P2[0]-P1[0]) + 3*t**2*(P3[0]-P2[0])
    dy = 3*mt**2*(P1[1]-P0[1]) + 6*mt*t*(P2[1]-P1[1]) + 3*t**2*(P3[1]-P2[1])
    return dx, dy


def unit(v):
    x, y = v
    m = math.hypot(x, y)
    return (x/m, y/m)


def normal_of(t):
    tx, ty = unit(bezier_deriv(t))
    return (-ty, tx), (tx, ty)  # (left-normal, forward-tangent)


def build_outline():
    ts = [i/(N_CURVE-1) for i in range(N_CURVE)]
    left_pts, right_pts = [], []
    for t in ts:
        cx, cy = bezier(t)
        (nx, ny), _ = normal_of(t)
        left_pts.append((cx+R*nx, cy+R*ny))
        right_pts.append((cx-R*nx, cy-R*ny))

    (n1x, n1y), (t1x, t1y) = normal_of(1.0)
    dth = math.pi/N_CAP
    end_cap = []
    for k in range(1, N_CAP):
        a = k*dth
        end_cap.append((P3[0]+R*(-n1x*math.cos(a)+t1x*math.sin(a)),
                         P3[1]+R*(-n1y*math.cos(a)+t1y*math.sin(a))))

    (n0x, n0y), (t0x, t0y) = normal_of(0.0)
    start_cap = []
    for k in range(1, N_CAP):
        a = k*dth
        start_cap.append((P0[0]+R*(n0x*math.cos(a)-t0x*math.sin(a)),
                           P0[1]+R*(n0y*math.cos(a)-t0y*math.sin(a))))

    poly = []
    poly.extend(left_pts)
    poly.extend(reversed(end_cap))
    poly.extend(right_pts[::-1])
    poly.extend(reversed(start_cap))
    return poly


def polygon_to_path_d(poly):
    parts = [f"M {poly[0][0]:.3f},{poly[0][1]:.3f}"]
    for x, y in poly[1:]:
        parts.append(f"L {x:.3f},{y:.3f}")
    parts.append("Z")
    return " ".join(parts)


d = polygon_to_path_d(build_outline())

# Recolour every explicit fill to solid black (leave fill="none" alone).
out = re.sub(r'fill="(?!none)[^"]*"', 'fill="#000000"', src)

# Replace the stroked morphism-arc path with the filled outline polygon above —
# no stroke/stroke-width attribute survives anywhere in the output.
stroke_pattern = re.compile(r'<path id="morphism-arc"[^>]*stroke="[^"]*"[^>]*/>')
assert stroke_pattern.search(out), "morphism-arc stroke path not found in icon-micro-light.svg"
out = stroke_pattern.sub(f'<path id="morphism-arc" d="{d}" fill="#000000"/>', out)

assert "stroke" not in out, "stroke attribute survived conversion"
(logo / "favicon/safari-pinned-tab.svg").write_text(out)
print("wrote favicon/safari-pinned-tab.svg; colour tokens remaining:",
      sorted(set(re.findall(r'fill="([^"]*)"', out))))
PY

echo "done."
