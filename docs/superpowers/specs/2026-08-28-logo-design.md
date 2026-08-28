# Logo design — `cfmm-vol-markets`

**Date:** 2026-08-28
**Scope:** `assets/logo/` in this repo only.
**Status:** design approved; implementation plan pending.

## 1. Purpose and scope

`cfmm-vol-markets` has no visual identity — there is no `assets/` directory. This
document specifies a mark, a tier system, a colour strategy, and a complete deliverable
matrix for it.

The mark identifies **this repository**: the on-chain protocol core for typed volatility
markets. It is deliberately NOT an org mark for `d2p-finance` and NOT a product brand for
a deployed protocol. Sibling repos (`cfmm-refs`, `gams-evm-transport`, `cfmm-numopt`,
`cfmm-vol-markets-spec`) are out of scope; if a family system is wanted later, this mark
becomes one member of it rather than its parent.

**Non-goals:** an org identity system; a token logo or chain-registry submission; a docs
site theme; typography rules beyond the wordmark lockups; animation.

## 2. Concept

**The claim: one curve, two readings.**

A constant-product bonding curve and a volatility skew are the same convex decreasing
shape. Only the coordinate system differs. The logo is a commutative diagram asserting
exactly that, which is the thesis of the repository — connecting constant-function market
makers with volatility trading.

The mark is a category-theoretic diagram: two objects (coordinate planes), one morphism
(an arrow), with the arrow pierced by the sigma that names what the morphism transports.

### 2.1 Composition

Diagonal, approximately 1:1, reading lower-left to upper-right. The diagonal is what
de-horizontalises a diagram that would otherwise be unusably wide, while preserving both
objects — a requirement, not a preference.

```
                                    σ²
                                    ┌────────────────┐
                                    │╲               │
                                    │ ╲___     σ²    │
                                    │     ‾‾──_ ──   │
                                    │          K     │
                                    └────────────────┘
                          ╱▸                  K
                    σ²  ╱
                  ═══╪
                   ╱
   ┌────────────────┐
 Y │╲  ╲            │
   │ ╲__╲     Y     │
   │    ‾╲──_ ─     │
   │         X      │
   └────────────────┘
            X
```

Each object is drawn as a **closed rectangular frame**, not an open L of axes. A closed
frame reads as an *object* in a categorical diagram, which is what the composition needs;
an L reads as a plot. Axis letters sit outside the frame on their respective edges, and
the ratio glyph sits inside it.

### 2.2 Source object (lower-left)

- Axes `X` (horizontal) and `Y` (vertical) — the CFMM state space. Single letters, not
  the words `asset`/`numéraire`: this roughly halves the stroke count and is what makes
  the planes shrink to icon size without going illegible.
- The hyperbola `x · y = k`.
- A **price tangent** line touching the curve. The tangent's slope is the marginal price;
  this shows the CFMM's pricing mechanism rather than only its invariant.
- A stacked ratio glyph `Y/X` set in the dead space the hyperbola leaves in the upper
  right of the frame.

`Y/X` is not a loose quotient. In a constant-product AMM the spot price **is** `Y/X`, and
the tangent's slope is `−Y/X`. The glyph and the tangent name the same quantity twice,
which is the intended reinforcement.

### 2.3 Morphism (the arrow)

- An arc rising diagonally from the source plane to the target plane, arrowhead at the
  target end.
- Pierced at its midpoint by **σ²** — the glyph sits ON the shaft, interrupted by it, not
  floating above it as a conventional label.
- **Curvature is not freehand:** the arc reuses the hyperbola's own path data, scaled. The
  connector is made of the thing it connects.

**Why σ² and not σ:** the protocol's canonical axis is realized *variance*, not volatility.
`notes/UNITS_AND_SCALES.md` pins σ² as the stored quantity throughout — strikes are packed
as `σ²_K` in `TickVolatility.vol`, the Algebra accumulator is in tick²·s, and the lens
compares σ² directly. Writing `σ` on the arrow would reintroduce the volStrike ambiguity
that document spent a review round eliminating.

### 2.4 Target object (upper-right)

- Axes `K` (horizontal, strike) and `σ²` (vertical).
- The **identical curve path**, translated and scaled.
- A stacked ratio glyph `σ²/K`.
- **No tangent.** The target stays lighter so the eye reads source-then-target rather than
  scanning two equally weighted frames.

**Skew, not smile.** The target curve is monotone decreasing and convex — a skew/smirk,
identical in shape to the source curve. A U-shaped smile was considered and rejected: two
visibly different shapes would make the arrow assert a *transformation*, a weaker and more
decorative claim. Identical shapes make it assert an *identity*, which is the point. A
monotone-decreasing convex skew is also the empirically dominant equity/crypto shape, so
this costs no accuracy.

`σ²/K` is a visual rhyme with `Y/X` rather than a standard financial quantity. This is a
deliberate, recorded choice: the symmetry is worth more to the mark than the notational
purity, and no reader is misled about a real object.

### 2.5 Construction rule (binding)

**The two curves MUST be the same path data in the SVG**, differing only by an affine
transform — not two hand-matched approximations. The arc's curvature MUST be derived from
that same path. The identity claim is then literally true in the file, and any future edit
that breaks it is a defect, not a style change.

## 3. Tier system

The full diagram cannot survive 16px. Degradation is specified rather than left to
downscaling.

| Tier | Size range | Contents |
|---|---|---|
| **A — full mark** | ≥ 128px | Both planes framed, both curves, price tangent, both ratio glyphs, σ² arc with label |
| **B — icon** | 24–127px | Planes as solid notched blocks; σ² arc with label. No curves, no ratio glyphs, no axis letters |
| **C — micro** | 16px | Solid blocks + arc only. σ² label drops |

Tier B abstracts each plane to a filled quadrant block because mass is the only thing that
reads reliably at small sizes. The two-object structure survives as form even when nothing
inside the frames can be drawn — this was the governing constraint on the reduction.

At tier B the blocks may carry a notched corner hinting at the axes; below 32px the notch
drops.

## 4. Lockups

Two, both setting `cfmm-vol-markets` in **JetBrains Mono**:

- **Horizontal** — mark left, name right. README headers, docs banners.
- **Stacked** — mark above, name below. Square contexts, slides, social.

Monospace is native to a kebab-case repository name and ties the mark to the Plank/Foundry
toolchain register.

**Glyph outlines MUST be vendored into the SVG** (converted to paths). No `font-family`
reference may survive in a delivered file — a lockup that depends on an installed font is
a lockup that renders wrong on someone else's machine. JetBrains Mono is OFL-licensed, so
embedding outlines is permitted; the licence notice belongs in `assets/logo/BRAND.md`.

## 5. Colour

| Role | Light | Dark |
|---|---|---|
| Ink (frames, curves, tangent, glyphs, wordmark) | `#0E1116` | `#E8EAED` |
| Accent (σ² arc only) | fixed, both themes | fixed, both themes |

The accent marks exactly one element — the σ² arc — so colour highlights the single
semantic claim the logo makes and nothing else. Everything else is ink. This yields the
austere, journal-plate register the diagram already implies, prints correctly, and needs
two variants rather than four.

**Accent selection is deferred to execution**, against a hard gate:

- **≥ 3:1 contrast against `#FFFFFF`** (GitHub light canvas), AND
- **≥ 3:1 contrast against `#0D1117`** (GitHub dark canvas).

A candidate failing either bound is rejected regardless of preference.

**Finding (2026-08-28), measured by `assets/logo/tools/check_accent.py`:** the two candidates
originally named here — `#2FBF71` and `#E0A526` — BOTH FAIL the light-canvas bound. A single
fixed accent serving both canvases must be mid-luminance; solving the two inequalities gives the
required window

> **L ∈ [0.1164, 0.3000]**

which is non-empty and comfortable.

| Candidate | L | vs `#FFFFFF` | vs `#0D1117` | Verdict |
|---|---|---|---|---|
| `#2FBF71` | 0.3906 | 2.38 | 7.94 | FAIL |
| `#E0A526` | 0.4290 | 2.19 | 8.63 | FAIL |
| `#1B9E5A` | 0.2542 | 3.45 | 5.48 | **PASS — selected** |
| `#B07A12` | 0.2319 | 3.72 | 5.08 | PASS |

These are tool-measured, superseding the hand estimates this note first carried. The selected
accent and its two ratios are recorded in `assets/logo/palette.json`; that file and the tool,
not this table, are authoritative.

### 5.1 Theme delivery

- Inline-use SVGs emit ink as `currentColor`, so one file serves both themes wherever the
  SVG is inlined and inherits colour.
- Baked `-light` / `-dark` files exist for `<img>` contexts, driven from the README by
  `<picture>` with `media="(prefers-color-scheme: dark)"`.
- The accent is hard-coded in all variants — it does not flip.

## 6. Geometry

- Master grid **512 × 512**, safe margin **32u** on all sides.
- Stroke weights snapped to the grid.
- **Minimum effective stroke 2px at tier-C rendered size.** A tier-C candidate whose
  strokes fall below this is redrawn, not shipped.
- Clear space around the mark: **one plane-block width** on all sides. Documented in
  `BRAND.md`.

## 7. Deliverables

All under `assets/logo/`. No ignore rule in `.gitignore` affects this path (verified).

```
assets/logo/
├── BRAND.md                    clear space, min sizes, misuse rules, hex, font licence
├── README.md                   file index + regeneration command
├── generate.sh                 derives every raster + .ico + .pdf from svg/ masters
├── svg/
│   ├── mark-full-{light,dark,currentcolor}.svg
│   ├── icon-{light,dark,currentcolor}.svg
│   ├── icon-micro-{light,dark}.svg
│   └── lockup-{horizontal,stacked}-{light,dark}.svg
├── png/
│   ├── mark-full-{light,dark}-{512,1024,2048}.png
│   ├── icon-{light,dark}-{16,32,48,64,128,256,512}.png
│   └── lockup-horizontal-{light,dark}-{512,1024,2048}.png
├── favicon/
│   ├── favicon.ico             multi-resolution 16/32/48
│   ├── favicon-{16x16,32x32}.png
│   ├── apple-touch-icon.png    180×180
│   ├── android-chrome-{192x192,512x512}.png
│   ├── safari-pinned-tab.svg   single monochrome path
│   └── site.webmanifest
├── social/
│   └── og-card-1280x640.{svg,png}
└── pdf/
    └── mark-full.pdf
```

### 7.1 Master → raster mapping (binding)

Tiers in §3 describe rendered *display* size, but the icon family deliberately uses tier-B
art at every pixel size so that an app icon is the same identity at 32px and at 512px. Only
16px steps down to tier C.

| Raster | Source master |
|---|---|
| `png/icon-*-16.png`, `favicon/favicon-16x16.png`, 16px entry of `favicon.ico` | `icon-micro-*` (tier C) |
| all other icon-family rasters — `png/icon-*-{32,48,64,128,256,512}.png`, `favicon-32x32.png`, `apple-touch-icon.png`, `android-chrome-*`, the 32/48 entries of `favicon.ico` | `icon-*` (tier B) |
| `png/mark-full-*`, `pdf/mark-full.pdf` | `mark-full-*` (tier A) |
| `png/lockup-horizontal-*`, `social/og-card-1280x640.png` | `lockup-horizontal-*` |

`generate.sh` encodes this mapping. A raster generated from the wrong tier master is a
defect, not a cosmetic difference.

**Why PDF:** `spec/` is a Lean/LaTeX repository. A raster logo in a typeset paper is
visible as a raster logo; the vector PDF is what `\includegraphics` should receive.

**Why `safari-pinned-tab.svg` is separate:** it must be a single-colour, single-path SVG
with no strokes — a distinct artefact, not a copy of an existing master.

## 8. Production pipeline

**Figma is the master.** Built via the Figma MCP server as components with variants over
`theme` × `tier`, with ink and accent as Figma variables so a palette change propagates
rather than being repainted by hand. The Figma file URL is recorded in
`assets/logo/README.md`.

**SVG masters are exported from Figma**, then hand-audited against §2.5 (shared path data)
and §4 (outlines vendored, no `font-family`).

**Every raster is derived, never hand-exported.** `assets/logo/generate.sh` regenerates the
whole matrix from `svg/`, so the deliverables are reproducible and drift between formats is
impossible.

Toolchain — verified present on this machine, **no new system installs required**:

| Step | Tool | Status |
|---|---|---|
| SVG → PNG (all sizes) | `rsvg-convert` | present |
| SVG → PDF | `rsvg-convert -f pdf` | present |
| PNG set → multi-res `.ico` | Python **Pillow 12.1.1** | present |
| SVG minification | `npx svgo` | node v26.2.0 / npx 11.16.0 present |

`svgo`, `inkscape`, `imagemagick`, `png2ico`, `icotool` and `optipng` are all ABSENT as
system binaries; the pipeline above is chosen specifically to avoid them. `generate.sh`
must fail loudly with an actionable message if `rsvg-convert` or Pillow is missing, rather
than silently producing a partial matrix.

## 9. Acceptance criteria

1. Both curves in `mark-full-*.svg` share one path definition under an affine transform.
2. No delivered SVG contains a `font-family` attribute.
3. The chosen accent passes ≥3:1 against both `#FFFFFF` and `#0D1117`; the measured
   figures are recorded in `BRAND.md`.
4. Tier C renders with all strokes ≥2px at 16×16 and is visually inspected at that size,
   not merely generated.
5. `favicon.ico` contains 16, 32 and 48px entries.
6. `generate.sh` run from a clean checkout reproduces every file under `png/`,
   `favicon/`, `social/*.png` and `pdf/` byte-for-byte identically to what is committed.
   This requires the pipeline to strip encoder metadata and embedded timestamps
   (`rsvg-convert` PNG output and Pillow `.ico` output are deterministic; PDF creation
   dates must be pinned or removed). If a format cannot be made reproducible, it is
   excluded from this criterion explicitly rather than silently.
7. README renders the correct variant under both GitHub themes via `<picture>`.
8. `BRAND.md` documents clear space, per-tier minimum sizes, the hex table, misuse rules,
   and the JetBrains Mono OFL notice.

## 10. Workflow

This is a separate workstream from `feat/volorder-t-minimal`. It gets its own tracking
issue on `develop` and its own branch, worked **inline** in the current checkout per
`AGENTS.md` (no per-phase worktree).

Changes land on the `JMSBPP/cfmm-vol-markets` fork and reach `d2p-finance` only by pull
request. `develop-gate` runs on push even though no `forge` or `plank` source is touched;
CI, not a local render, is the gate.

## 11. Decision log

| Decision | Chosen | Rejected |
|---|---|---|
| Brand scope | This repo only | Org mark; product brand |
| Target curve | Same convex curve (skew) | U-shaped smile; smile built from curve + mirror |
| Morphism label | `σ²` (variance) | `σ` (vol); `Σ` (accumulator) |
| Composition | Diagonal, both planes preserved | Vertical stack; overhead arc; single frame with four axes |
| Axis naming | `X`,`Y` / `K`,`σ²` | `asset`,`numéraire` |
| Plane annotation | Stacked ratio glyph inside each frame | Plain axis labels; slope notation on tangents in both planes |
| Reduced icon | Two solid plane-blocks + σ² arc | Curve+tangent single plane; σ²-arc alone |
| Colour | Ink + single accent on the arc | Two-tone per plane with gradient; pure monochrome |
| Wordmark | Monospace lockup (JetBrains Mono) | Academic serif; glyph only |
