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

| Tier | Size range | Master | Contents |
|---|---|---|---|
| **A — full mark** | ≥ 128px | `mark-full-*` | Both planes framed, both curves, price tangent, both ratio glyphs, σ² arc with label |
| **B — icon** | 64–127px | `icon-*` | Planes as notched blocks; σ² arc **with label**. No curves, no ratio glyphs, no axis letters |
| **C — mid** | 24–63px | `icon-mid-*` | Tier B **minus the σ² label**. Notch retained |
| **D — micro** | 16–23px | `icon-micro-*` | Blocks + arc only. Notch and label both drop |

Tier B abstracts each plane to a filled block because mass is the only thing that reads
reliably at small sizes. The two-object structure survives as form even when nothing inside
the frames can be drawn — this was the governing constraint on the reduction.

The notch is an **L-shaped slot cut inside the block** (32u axis rule, 32u slot, 76u bulk),
not a bite taken out of its corner. Cutting it inside leaves the 140u silhouette intact,
which is what allows the notch to sit at each block's true origin corner exactly as in
tier A, rather than being displaced to avoid the corner the arc springs from.

### 3.1 Why four tiers and not three (amended 2026-08-28)

The tier table originally ran A / B / C with tier B spanning 24–127px and carrying the σ²
label throughout. **Rendered evidence contradicted it.** At 32px — inside tier B's own
stated range — the label resolves to roughly three grey pixels, while the notch remains
crisp (rule 2.00px, slot 2.00px, bulk 4.75px). The two elements do not fail at the same
size, so one boundary cannot serve both.

Splitting the old tier B at 64px lets each element be dropped at the size where it actually
stops resolving, instead of dropping both at whichever fails first. The 24–63px band —
where favicons and avatars live — therefore keeps the axis hint it can render and loses only
the label it cannot.

Every tier is the same mark minus elements. A tier is never rebalanced or redrawn to look
better on its own; that would break the family resemblance the ladder exists to preserve.

**The arc path data is byte-identical across tiers B, C and D.** This is a binding
invariant, verified alongside §2.5's curve identity.

## 4. Lockups

Three, all setting `cfmm-vol-markets` in **JetBrains Mono Light**:

| Lockup | Mark used | viewBox | Aspect | **Minimum width** |
|---|---|---|---|---|
| `lockup-horizontal-*` | tier A full mark | `0 0 2212 436` | 5.0734 : 1 | **649px** |
| `lockup-horizontal-b-*` | tier B icon | `0 0 2212 436` | 5.0734 : 1 | **325px** |
| `lockup-stacked-*` | tier A full mark | `0 0 512 576` | 8 : 9 | **160px** |

Monospace is native to a kebab-case repository name and ties the mark to the Plank/Foundry
toolchain register. **Light, not Regular:** a Regular stem is ~15u against the mark's 6–8u
strokes, and the wordmark then shouts over the mark it is meant to accompany.

### 4.1 Minimum sizes are derived, not chosen

The tier ladder of §3 governs lockups too. A lockup's floor is the width at which its
embedded mark reaches that mark's own tier floor:

- **Horizontal, tier A** — the mark is 436u of 2212u width, i.e. 19.7%. Tier A's floor is
  128px, so the lockup floor is 128 / 0.197 = **649px**. Below that the fractions and axis
  letters are unreadable. This is why the tier-B variant exists at all: README headers are
  typically 400–600px, which is *under* this floor.
- **Horizontal, tier B** — the icon is rescaled by s = 0.9693 (arc 44u → 42.65u), a pure
  similarity, so it reproduces the standalone tier-B margin exactly when the icon sits at
  its own 64px floor — lockup width ≈ 285px. Rounded up to **325px** for margin. The arc
  itself does not fall under 2px until ≈104px of lockup width, but the *wordmark* becomes
  unreadable long before that, so the wordmark, not the arc, is the binding constraint here.
- **Stacked, tier A** — the mark occupies 435.662u of the 576u height, and height is 1.125×
  width, so the mark is 0.851× the lockup width. 128 / 0.851 = 150px, rounded to **160px**.

**Below its floor, a lockup is not used — the bare mark or icon is.** A lockup rendered
under its floor is the same defect §7.1 rejects at the other end of the ladder: art shown at
a size it was not drawn for.

### 4.2 Vendored outlines

**Glyph outlines MUST be vendored into the SVG** (converted to paths). No `font-family`
reference, and no `<text>` element, may survive in a delivered file — a lockup that depends
on an installed font is a lockup that renders wrong on someone else's machine. JetBrains
Mono is OFL-licensed, so embedding outlines is permitted; the licence notice belongs in
`assets/logo/BRAND.md`.

Note for whoever edits these in Figma: `figma.flatten()` outlines text but **drops the
fill's variable binding**, which silently ships a dark variant in `#000000`. Re-bind the
fill after outlining and verify the dark files contain `#E8EAED` and no `#000000`.

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
- Clear space around the mark: **one plane-block width** on all sides. Documented in
  `BRAND.md`.

### 6.1 The 2px floor — what it binds (clarified 2026-08-28)

**Every LOAD-BEARING STROKE must render at ≥ 2px at the minimum size of the tier it appears
in.** Load-bearing means the mark's legibility depends on it: the morphism arc, and the
frame and curve strokes of the full mark.

This is per-tier, not global. Each tier sets its arc weight so it clears 2px at *its own*
floor, which is why the weights differ and increase as the tiers shrink:

| Tier | Floor | Arc weight | Rendered at floor | Margin |
|---|---|---|---|---|
| B | 64px | 44u | 5.50px | +175% |
| C | 24px | 56u | 2.63px | +31% |
| D | 16px | 80u | 2.50px | +25% |

A weight that sits *exactly* on the floor is rejected as fragile — any later nudge puts it
under. `+25%` is the working minimum margin.

**The floor does NOT bind detail features whose absence would not stop the mark being read.**
The notch's 32u axis rule renders 1.50px at tier C's 24px floor, below 2px, and this is
accepted: the notch is a hint, not a stroke the mark depends on, and it was validated
empirically — the alpha map at 24px shows genuinely empty pixels in the slot rather than a
grey smear. It reads as a *light* L, which is the intended effect at that size.

Stated because the distinction is otherwise invisible: read as binding every ink feature,
this clause would have condemned a notch that demonstrably works.

**Pixel-counting is a smoke test, not the gate.** A stroke at 45° straddles the pixel grid
and is not solid-dominant until roughly 2.8px, so a correct diagonal stroke will report more
anti-aliased pixels than solid ones. The geometric arithmetic above is what clears the floor;
the pixel count only catches gross error. Counts are also not comparable across tiers — tier
C carries the L-slot, whose 1.50px rule and slot contribute edge pixels that tier D has none
of.

## 7. Deliverables

All under `assets/logo/`. No ignore rule in `.gitignore` affects this path (verified).

```
assets/logo/
├── BRAND.md                    clear space, min sizes, misuse rules, hex, font licence
├── README.md                   file index + regeneration command
├── generate.sh                 derives every raster + .ico + .pdf from svg/ masters
├── svg/
│   ├── mark-full-{light,dark,currentcolor}.svg
│   ├── icon-{light,dark,currentcolor}.svg          tier B — ≥64px, notched + σ² label
│   ├── icon-mid-{light,dark}.svg                   tier C — 24–63px, notched, no label
│   ├── icon-micro-{light,dark}.svg                 tier D — 16–23px, plain blocks
│   ├── lockup-horizontal-{light,dark}.svg          tier-A mark  — use ≥649px
│   ├── lockup-horizontal-b-{light,dark}.svg        tier-B icon  — use ≥325px
│   └── lockup-stacked-{light,dark}.svg             tier-A mark  — use ≥160px
├── png/
│   ├── mark-full-{light,dark}-{512,1024,2048}.png
│   ├── icon-{light,dark}-{16,32,48,64,128,256,512}.png
│   └── lockup-{horizontal,horizontal-b,stacked}-{light,dark}-{512,1024,2048}.png
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

**Each raster is generated from the master for the tier whose range contains its RENDERED
size.** An earlier version of this section said the opposite — that the icon family should
use tier-B art at every pixel size, so that an app icon is "the same identity at 32px and at
512px". That was wrong, and §3.1 records why: at 32px the tier-B label is unreadable, so
using tier-B art there ships noise rather than identity. Identity is preserved by the
degradation ladder itself — every tier is the same mark minus elements — not by rendering
one master at sizes it was not drawn for.

| Raster | Source master |
|---|---|
| `png/icon-*-16.png`, `favicon/favicon-16x16.png`, 16px entry of `favicon.ico` | `icon-micro-*` (tier D, 16–23px) |
| `png/icon-*-{32,48}.png`, `favicon-32x32.png`, the 32 and 48 entries of `favicon.ico` | `icon-mid-*` (tier C, 24–63px) |
| `png/icon-*-{64,128,256,512}.png`, `apple-touch-icon.png` (180), `android-chrome-{192,512}` | `icon-*` (tier B, ≥64px) |
| `png/mark-full-*`, `pdf/mark-full.pdf` | `mark-full-*` (tier A) |
| `png/lockup-horizontal-*`, `social/og-card-1280x640.png` | `lockup-horizontal-*` |
| `png/lockup-horizontal-b-*` | `lockup-horizontal-b-*` |
| `png/lockup-stacked-*` | `lockup-stacked-*` |

All three lockup families rasterise at the same `{512, 1024, 2048}` widths — **width only**,
never `-h`. They are 5.0734 : 1 and 8 : 9; forcing a height distorts them. Only the mark and
icons are square and take both dimensions.

Note `apple-touch-icon.png` at 180px and `android-chrome-192x192.png` sit in tier B and
therefore carry the σ² label; the 32 and 48 favicon entries sit in tier C and do not. That
is intended: a home-screen icon is looked at, a favicon is glanced at.

`generate.sh` encodes this mapping. A raster generated from the wrong tier master is a
defect, not a cosmetic difference.

**Why PDF:** `spec/` is a Lean/LaTeX repository. A raster logo in a typeset paper is
visible as a raster logo; the vector PDF is what `\includegraphics` should receive.

**Why `safari-pinned-tab.svg` is separate:** it must be a single-colour, single-path SVG
with no strokes — a distinct artefact, not a copy of an existing master.

**The social card needs an explicit inset rule, not scale-to-fit.** The horizontal lockup is
5.0734 : 1 and the card is 1280 × 640, i.e. 2 : 1. Naive fitting fails both ways: fit-to-width
yields a 252px-tall lockup adrift in a 640px card, and fit-to-height yields a 1624px-wide
lockup that overflows. Task 8 must place the lockup at a stated width with stated margins —
letterboxed deliberately — rather than scaling it to the frame.

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
