"""Evaluate accent candidates against the spec's hard contrast gate.

Usage:  python3 check_accent.py [#RRGGBB ...]
Exit 0 if EVERY candidate passes both bounds, 1 otherwise.
"""

from __future__ import annotations

import sys

from contrast import contrast_ratio, relative_luminance

CANVAS_LIGHT = "#FFFFFF"
CANVAS_DARK = "#0D1117"
MIN_RATIO = 3.0

DEFAULT_CANDIDATES = ["#2FBF71", "#E0A526", "#1B9E5A", "#B07A12"]


def luminance_window() -> tuple[float, float]:
    """The L range in which a colour clears MIN_RATIO against both canvases."""
    lo = MIN_RATIO * (relative_luminance(CANVAS_DARK) + 0.05) - 0.05
    hi = (relative_luminance(CANVAS_LIGHT) + 0.05) / MIN_RATIO - 0.05
    return lo, hi


def main(argv: list[str]) -> int:
    candidates = argv[1:] or DEFAULT_CANDIDATES
    lo, hi = luminance_window()
    print(f"required luminance window: L in [{lo:.4f}, {hi:.4f}]\n")
    print(f"{'candidate':<12}{'L':>9}{'vs light':>11}{'vs dark':>10}  verdict")
    ok = True
    for c in candidates:
        lum = relative_luminance(c)
        light = contrast_ratio(c, CANVAS_LIGHT)
        dark = contrast_ratio(c, CANVAS_DARK)
        passed = light >= MIN_RATIO and dark >= MIN_RATIO
        ok &= passed
        print(
            f"{c:<12}{lum:>9.4f}{light:>11.2f}{dark:>10.2f}  "
            f"{'PASS' if passed else 'FAIL'}"
        )
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
