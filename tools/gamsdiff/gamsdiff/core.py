"""Pure transforms for the GAMS pricing-kernel diff fixture. No I/O."""


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
