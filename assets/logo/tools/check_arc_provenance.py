"""Provenance check for the morphism arc (spec §2.3).

Spec §2.3 claims "the connector is made of the thing it connects": the green arc
is not freehand, it is a piece of the hyperbola it points away from. Concretely,
`morphism-arc` is asserted to be two sub-arcs of `curve-source` carried into the
gap between the planes by ONE orientation-reversing similarity of the plane,

    S(z) = a * conj(z) + b        (a, b complex; conj = complex conjugate)

This module reconstructs that claim from the exact construction parameters and
reports the per-control-point residual, so the claim is checkable by anyone
rather than resting on the author's word.

NOT A SHIPPING INVARIANT. This checks a design-rationale claim about how the
artwork was built, not a property a delivered file must satisfy. It MUST NOT be
wired into validate.sh (or any other gate) as a blocking check: a future
redesign of the arc could legitimately break it without breaking any deliverable.
Its companion `svgcheck.py` holds the rules that are binding.

Why an orientation-REVERSING similarity: the hyperbola bulges toward its own
plot origin. A rotation would carry that bulge to the lower-right of the arrow
(a sagging arc); the reflection puts it on the upper-left, so the arrow rises.
"""

from __future__ import annotations

import argparse
import pathlib
import re
import sys
import xml.etree.ElementTree as ET

# ---------------------------------------------------------------------------
# Construction parameters — the exact values used to draw the arc.
#
# `curve-source` is authored as FIVE cubic Bezier segments over the hyperbola
# x*y = k (k = 0.126 in unit plot coordinates), with u-breakpoints
#
#     0.14, 0.20, 0.29, 0.4345, 0.62, 0.90
#
# so segment i (0-based) spans [breakpoint[i], breakpoint[i+1]]. The segments
# are NOT equal in u — assuming they are is the single easiest way to get a
# wrong answer here. The arc is built from segments 2 and 3, i.e. u in
# [0.29, 0.62]; those two happen to straddle the curve's 45-degree point.
#
# The similarity is pinned by two endpoint constraints, not fitted:
#     start of segment 2  ->  ARC_START
#     end   of segment 3  ->  ARC_TIP
# ARC_TIP is the arrowhead apex. The visible shaft stops short of it (see
# TAIL_TRIM below), so a two-point fit against the arc's OUTER ENDPOINTS as
# they appear in the SVG recovers the wrong scale — the far endpoint in the
# file is a truncation, not the image of the segment end.
# ---------------------------------------------------------------------------
SEGMENT_INDICES = (2, 3)
ARC_START = complex(232, 282)
ARC_TIP = complex(312, 202)

# The gap that lets the sigma-squared glyph interrupt the shaft, and the tail
# trim that tucks the shaft's end inside the arrowhead, are both measured in
# ARC-SPACE ARC LENGTH (not in the Bezier parameter, and not in source-space
# units). Arc length is approximated by a uniform-parameter polyline over the
# two-segment composite; SAMPLES is per segment.
GAP_HALF_LENGTH = 20.0       # px, either side of the glyph centre
GAP_CENTRE_FRACTION = 0.455  # of total arc length, measured from the start
TAIL_TRIM = 21.0             # px removed from the far end, hidden by the arrowhead
SAMPLES = 800

# Agreement threshold, chosen from the rounding budget BEFORE running the check:
# both the generator and Figma's SVG exporter write coordinates to 3 decimal
# places, so each control point carries up to 5e-4 px of rounding error. De
# Casteljau splitting is a convex combination (weights sum to 1, non-amplifying)
# and the similarity scales by |a| ~ 1.9, so the achievable agreement is bounded
# near 1e-3 px. 0.05 px is ~50x that budget, and 1/160 of the arc's 8 px stroke,
# so anything at or below it is invisible at any rendered size and consistent
# with an exact construction. A path that had been resampled — by a boolean op,
# an outline-stroke, or a hand redraw — would land at >= 0.5 px, an order of
# magnitude clear of this line.
TOLERANCE = 0.05

SVG_NS = "http://www.w3.org/2000/svg"
_NUMBER = re.compile(r"[-+]?\d*\.?\d+(?:[eE][-+]?\d+)?")
_COMMAND = re.compile(r"[A-Za-z][^A-Za-z]*")


def parse_cubics(d: str) -> list[list[list[complex]]]:
    """Split a path's `d` into subpaths, each a list of cubic segments.

    Each cubic is four control points [P0, P1, P2, P3] as complex numbers.
    Absolute M/C only — the two paths this tool reads contain nothing else, and
    silently accepting more would let a changed export slip through unnoticed.
    """
    subpaths: list[list[list[complex]]] = []
    current: complex | None = None
    for chunk in _COMMAND.findall(d):
        op, nums = chunk[0], [float(n) for n in _NUMBER.findall(chunk[1:])]
        if op == "M":
            if len(nums) != 2:
                raise ValueError(f"M with {len(nums)} coordinates; expected 2")
            current = complex(nums[0], nums[1])
            subpaths.append([])
        elif op == "C":
            if current is None:
                raise ValueError("C before any M")
            if len(nums) % 6:
                raise ValueError(
                    f"C with {len(nums)} coordinates; expected a multiple of 6"
                )
            for i in range(0, len(nums), 6):
                pts = [current] + [
                    complex(nums[i + j], nums[i + j + 1]) for j in (0, 2, 4)
                ]
                subpaths[-1].append(pts)
                current = pts[3]
        else:
            raise ValueError(f"command {op!r} unsupported; expected absolute M/C")
    if not subpaths or not all(subpaths):
        raise ValueError("path contains no cubic segments")
    return subpaths


def path_by_id(root: ET.Element, node_id: str) -> str:
    for element in root.iter(f"{{{SVG_NS}}}path"):
        if element.get("id") == node_id:
            return element.get("d", "")
    raise ValueError(f"no <path id={node_id!r}> in the document")


def bezier(pts: list[complex], t: float) -> complex:
    mt = 1.0 - t
    return (
        mt**3 * pts[0]
        + 3 * mt * mt * t * pts[1]
        + 3 * mt * t * t * pts[2]
        + t**3 * pts[3]
    )


def de_casteljau(pts: list[complex], t: float) -> tuple[list[complex], list[complex]]:
    """Split one cubic at parameter t into (head, tail)."""
    p01 = pts[0] + (pts[1] - pts[0]) * t
    p12 = pts[1] + (pts[2] - pts[1]) * t
    p23 = pts[2] + (pts[3] - pts[2]) * t
    q = p01 + (p12 - p01) * t
    r = p12 + (p23 - p12) * t
    s = q + (r - q) * t
    return [pts[0], p01, q, s], [s, r, p23, pts[3]]


def solve_similarity(
    p: complex, q: complex, p_image: complex, q_image: complex
) -> tuple[complex, complex]:
    """The unique orientation-reversing similarity carrying p->p_image, q->q_image."""
    a = (q_image - p_image) / (q - p).conjugate()
    return a, p_image - a * p.conjugate()


def fit_similarity(
    sources: list[complex], images: list[complex]
) -> tuple[complex, complex]:
    """Complex least-squares fit of w = a*conj(z) + b over the correspondences."""
    zeta = [z.conjugate() for z in sources]
    mean_z = sum(zeta) / len(zeta)
    mean_w = sum(images) / len(images)
    numerator = sum(
        (w - mean_w) * (z - mean_z).conjugate() for z, w in zip(zeta, images)
    )
    denominator = sum(abs(z - mean_z) ** 2 for z in zeta)
    a = numerator / denominator
    return a, mean_w - a * mean_z


def arclength_table(
    segments: list[list[complex]], scale: float
) -> tuple[list[tuple[float, float]], float]:
    """Cumulative ARC-SPACE length against the composite parameter g in [0, 2].

    g <= 1 indexes the first segment at t = g; g > 1 indexes the second at
    t = g - 1. Lengths are measured on the source segments and multiplied by
    `scale` = |a|, which is exactly the arc-space length because a similarity
    scales every length by the same factor.
    """
    table: list[tuple[float, float]] = []
    total = 0.0
    previous = segments[0][0]
    for i in range(1, 2 * SAMPLES + 1):
        g = i / SAMPLES
        which, t = (0, g) if g <= 1.0 else (1, g - 1.0)
        point = bezier(segments[which], t)
        total += abs(point - previous) * scale
        previous = point
        table.append((total, g))
    return table, total


def g_at(table: list[tuple[float, float]], target: float) -> float:
    for cumulative, g in table:
        if cumulative >= target:
            return g
    return 2.0


def reconstruct(segments: list[list[complex]], scale: float) -> list[list[complex]]:
    """The two source sub-arcs the shaft stubs are claimed to be, in SOURCE space."""
    table, total = arclength_table(segments, scale)
    centre = GAP_CENTRE_FRACTION * total
    g1 = g_at(table, centre - GAP_HALF_LENGTH)
    g2 = g_at(table, centre + GAP_HALF_LENGTH)
    g3 = g_at(table, total - TAIL_TRIM)
    if not g1 < 1.0 < g2 < g3:
        raise ValueError(f"split parameters left their expected segments: {(g1, g2, g3)!r}")
    lower = de_casteljau(segments[0], g1)[0]
    remainder = de_casteljau(segments[1], g2 - 1.0)[1]
    upper = de_casteljau(remainder, (g3 - g2) / (2.0 - g2))[0]
    return [lower, upper]


def nearest_distance(point: complex, polyline: list[complex]) -> float:
    """Distance from `point` to a polyline, as a point-to-segment minimum."""
    best = float("inf")
    for u, v in zip(polyline, polyline[1:]):
        d = v - u
        denominator = abs(d) ** 2
        t = 0.0 if denominator == 0 else ((point - u) * d.conjugate()).real / denominator
        t = max(0.0, min(1.0, t))
        best = min(best, abs(point - (u + d * t)))
    return best


def fmt(pts: list[complex]) -> str:
    return " ".join(f"({p.real:g}, {p.imag:g})" for p in pts)


def fmt_c(z: complex) -> str:
    return f"{z.real:.6f} {'-' if z.imag < 0 else '+'} {abs(z.imag):.6f}i"


def check(path: pathlib.Path) -> tuple[float, list[str]]:
    root = ET.parse(path).getroot()
    source = parse_cubics(path_by_id(root, "curve-source"))
    arc = parse_cubics(path_by_id(root, "morphism-arc"))

    if len(source) != 1 or len(source[0]) != 5:
        raise ValueError("curve-source is not one subpath of 5 cubics")
    if len(arc) != 2 or any(len(s) != 1 for s in arc):
        raise ValueError(
            "morphism-arc is not two subpaths of one cubic each (found "
            f"{[len(s) for s in arc]!r}) — the sigma-squared gap makes it two"
        )

    lines = [f"file: {path.name}"]
    segments = [source[0][i] for i in SEGMENT_INDICES]
    lines.append(f"curve-source segments {SEGMENT_INDICES} of 5  (u in [0.29, 0.62])")
    for index, segment in zip(SEGMENT_INDICES, segments):
        lines.append(f"  segment {index}: {fmt(segment)}")

    a, b = solve_similarity(segments[0][0], segments[1][3], ARC_START, ARC_TIP)
    lines.append(f"claimed  a = {fmt_c(a)}   |a| = {abs(a):.6f}")
    lines.append(f"claimed  b = {fmt_c(b)}")

    stubs = reconstruct(segments, abs(a))
    expected = [[a * z.conjugate() + b for z in stub] for stub in stubs]
    observed = [arc[0][0], arc[1][0]]

    fitted_a, fitted_b = fit_similarity(
        [z for stub in stubs for z in stub],
        [w for stub in observed for w in stub],
    )
    lines.append(f"fitted   a = {fmt_c(fitted_a)}   |a| = {abs(fitted_a):.6f}")
    lines.append(f"fitted   b = {fmt_c(fitted_b)}")
    lines.append(
        f"|a_fit - a_claimed| = {abs(fitted_a - a):.6g}   "
        f"|b_fit - b_claimed| = {abs(fitted_b - b):.6g}"
    )

    worst = 0.0
    lines.append("per-control-point residual (px on the 512 grid):")
    for s, (exp, obs) in enumerate(zip(expected, observed)):
        for i, (e, o) in enumerate(zip(exp, obs)):
            residual = abs(e - o)
            worst = max(worst, residual)
            lines.append(
                f"  stub {s} P{i}  expected ({e.real:9.3f}, {e.imag:9.3f})  "
                f"in file ({o.real:9.3f}, {o.imag:9.3f})  residual {residual:.6f}"
            )

    # Independent of the split parameters: carry the arc back through S^-1 and
    # measure how far each sampled point lands from curve-source itself. This is
    # the check that does not depend on any number in the parameter block above.
    polyline = [bezier(seg, i / 400.0) for seg in segments for i in range(401)]
    back_worst = 0.0
    for stub in observed:
        for i in range(101):
            w = bezier(stub, i / 100.0)
            back_worst = max(back_worst, nearest_distance(((w - b) / a).conjugate(), polyline))
    lines.append(
        "independent check: 202 points sampled off the arc, mapped back through S^-1, "
        f"worst distance to curve-source = {back_worst:.6f} px (source space) "
        f"= {back_worst * abs(a):.6f} px (arc space)"
    )
    return max(worst, back_worst * abs(a)), lines


def main(argv: list[str]) -> int:
    default = pathlib.Path(__file__).resolve().parent.parent / "svg" / "mark-full-light.svg"
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("file", nargs="?", type=pathlib.Path, default=default)
    args = parser.parse_args(argv[1:])

    worst, lines = check(args.file)
    print("\n".join(lines))
    print(f"worst residual {worst:.6f} px   tolerance {TOLERANCE:.3f} px")
    if worst < TOLERANCE:
        print(
            "OK    morphism-arc is an exact image of curve-source segments "
            f"{SEGMENT_INDICES} under S(z) = a*conj(z) + b"
        )
        return 0
    print(
        f"FAIL  morphism-arc is only an APPROXIMATE image of curve-source (worst "
        f"residual {worst:.6f} px) — record it as an approximation, not an identity",
        file=sys.stderr,
    )
    return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
