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

# -- Task 7 (favicon family) and Task 8 (OG social card) append their sections here. --

echo "done."
