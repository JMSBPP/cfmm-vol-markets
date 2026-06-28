"""Pure transforms for the GAMS pricing-kernel diff fixture. No I/O."""

import json
from collections.abc import Iterable
from dataclasses import dataclass

# Elasticity (eta = eta_x_y / unity) of the GAMS tunablePricingKernel macro.
# eta = 1/2 is the balanced 50/50 pool, where tunablePricingKernel reduces to the
# fixed sqrt priceKernel == the EVM getSqrtRatioAtTick. It is the ONLY weight with
# an on-chain counterpart, so the differential test is pinned here; eta != 1/2
# gives an asymmetric bonding curve that can only be checked off-chain.
BALANCED_ETA = 0.5


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
    eta: float,
) -> dict:
    """Build the forge-friendly fixture dict (uint256 as decimal strings).

    ``eta`` is the tunablePricingKernel elasticity this fixture was tabulated at.
    For the EVM differential test it must be ``BALANCED_ETA`` (1/2); the field is
    metadata only (the Solidity test never reads it for math) and records which
    weight the reference corresponds to.
    """
    return {
        "symbol": symbol,
        "source": source,
        "scale": "Q64.96",
        "spacing": spacing,
        "eta": eta,
        "kernel": f"tunablePricingKernel(eta={eta})",
        "gamsVersion": gams_version,
        "platform": platform,
        "count": len(points),
        "ticks": [p.tick for p in points],
        "expectedSqrtPriceX96": [str(p.expected_sqrt_price_x96) for p in points],
    }


def to_json(fixture: dict) -> str:
    """Serialize the fixture to deterministic JSON text."""
    return json.dumps(fixture, indent=2) + "\n"


@dataclass(frozen=True)
class ImpactRecord:
    """One price-impact diff row: int24 tick, input sqrt price, input amount0, expected post-trade sqrt price."""

    tick: int
    sqrt_p_x96: int
    amount0_in: int
    expected_sqrt_price_x96: int


def impact_records_to_fixture(
    records: tuple[ImpactRecord, ...],
    *,
    liquidity: int,
    eta: float,
    gams_version: str,
    platform: str,
) -> dict:
    """Build the forge-friendly flattened price-impact fixture (uint as decimal strings).

    Validates each row: all values > 0 and expected < sqrt_p strictly (a token0-input trade
    with dx > 0 must lower the post-trade price; expected == sqrt_p signals a zero/overflowed
    dx regression). round()-ing the GAMS float inputs is lossless on this grid (sqrt_p >> 2^52).
    """
    if not records:
        raise ValueError("no impact records")
    if liquidity <= 0:
        raise ValueError(f"non-positive liquidity: {liquidity}")
    for r in records:
        if min(r.sqrt_p_x96, r.amount0_in, r.expected_sqrt_price_x96) <= 0:
            raise ValueError(
                f"non-positive value in row (tick={r.tick}): sqrt_p_x96={r.sqrt_p_x96}, "
                f"amount0_in={r.amount0_in}, expected_sqrt_price_x96={r.expected_sqrt_price_x96}"
            )
        if r.expected_sqrt_price_x96 >= r.sqrt_p_x96:
            raise ValueError(
                f"expected ({r.expected_sqrt_price_x96}) must be < sqrt_p ({r.sqrt_p_x96}) "
                f"at tick={r.tick}, amount0_in={r.amount0_in}"
            )
    return {
        "symbol": "priceImpact",
        "source": "model/PriceImpactKernelFixture.gms",
        "scale": "Q64.96",
        "eta": eta,
        "add": True,
        "liquidity": str(liquidity),
        "gamsVersion": gams_version,
        "platform": platform,
        "count": len(records),
        "ticks": [r.tick for r in records],
        "sqrtPX96In": [str(r.sqrt_p_x96) for r in records],
        "amount0In": [str(r.amount0_in) for r in records],
        "expectedSqrtPriceX96": [str(r.expected_sqrt_price_x96) for r in records],
    }
