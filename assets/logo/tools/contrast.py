"""WCAG 2.1 relative luminance and contrast ratio. Stdlib only.

Reference: https://www.w3.org/TR/WCAG21/#dfn-relative-luminance
"""

from __future__ import annotations


def _channel_to_linear(c: float) -> float:
    """sRGB gamma decode for a single channel in [0, 1]."""
    return c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4


def relative_luminance(hex_colour: str) -> float:
    """Relative luminance of an sRGB colour given as 6-digit hex."""
    h = hex_colour.lstrip("#")
    if len(h) != 6:
        raise ValueError(f"expected 6-digit hex, got {hex_colour!r}")
    try:
        r, g, b = (int(h[i : i + 2], 16) / 255.0 for i in (0, 2, 4))
    except ValueError as exc:
        raise ValueError(f"not a hex colour: {hex_colour!r}") from exc
    return (
        0.2126 * _channel_to_linear(r)
        + 0.7152 * _channel_to_linear(g)
        + 0.0722 * _channel_to_linear(b)
    )


def contrast_ratio(fg: str, bg: str) -> float:
    """WCAG contrast ratio between two colours. Symmetric; always >= 1.0."""
    lo, hi = sorted((relative_luminance(fg), relative_luminance(bg)))
    return (hi + 0.05) / (lo + 0.05)
