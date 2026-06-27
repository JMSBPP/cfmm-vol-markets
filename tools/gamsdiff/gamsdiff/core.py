"""Pure transforms for the GAMS pricing-kernel diff fixture. No I/O."""

import json
from collections.abc import Iterable
from dataclasses import dataclass


def to_sqrt_price_x96(value: float) -> int:
    """Round a GAMS float64 value (already scaled by 2^96) to its nearest integer.

    Above 2^52 the float64 is already integer-valued (granularity ~2^44), so this
    is effectively a no-op on real data; the reference is therefore quantized to
    ~2^44 and is not exact-integer ground truth. round() is banker's rounding.
    """
    return round(value)


def tick_from_grid(tick_index: int, spacing: int = 1) -> int:
    """Map a GAMS 1-based ordinal (label ``k<n>``) to the int24 tick.

    Derived from the equivalence T = tickVal * spacing, where
    tickVal = ord(tick) - 121. ``spacing`` is the GAMS ``ord(s)`` value.
    """
    return (tick_index - 121) * spacing


@dataclass(frozen=True)
class GridRecord:
    """One GAMS priceKernel record: 1-based tick ordinal and the Q96-scaled value."""

    tick_index: int
    value: float


@dataclass(frozen=True)
class KernelPoint:
    """One diff point: int24 tick and the expected Q64.96 sqrt price."""

    tick: int
    expected_sqrt_price_x96: int


def records_to_points(
    rows: Iterable[GridRecord], spacing: int = 1
) -> tuple[KernelPoint, ...]:
    """Pure transform from GAMS records to diff points. Validates value > 0."""
    points: list[KernelPoint] = []
    for r in rows:
        if r.value <= 0:
            raise ValueError(f"non-positive priceKernel value at tick_index={r.tick_index}: {r.value}")
        points.append(
            KernelPoint(
                tick=tick_from_grid(r.tick_index, spacing),
                expected_sqrt_price_x96=to_sqrt_price_x96(r.value),
            )
        )
    return tuple(points)


def points_to_fixture(
    points: tuple[KernelPoint, ...],
    *,
    symbol: str,
    source: str,
    spacing: int,
    gams_version: str,
    platform: str,
) -> dict:
    """Build the forge-friendly fixture dict (uint256 as decimal strings)."""
    return {
        "symbol": symbol,
        "source": source,
        "scale": "Q64.96",
        "spacing": spacing,
        "gamsVersion": gams_version,
        "platform": platform,
        "count": len(points),
        "ticks": [p.tick for p in points],
        "expectedSqrtPriceX96": [str(p.expected_sqrt_price_x96) for p in points],
    }


def to_json(fixture: dict) -> str:
    """Serialize the fixture to deterministic JSON text."""
    return json.dumps(fixture, indent=2) + "\n"
