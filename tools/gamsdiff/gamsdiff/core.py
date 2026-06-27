"""Pure transforms for the GAMS pricing-kernel diff fixture. No I/O."""


def to_sqrt_price_x96(value: float) -> int:
    """Round a GAMS float64 value (already scaled by 2^96) to its nearest integer.

    Above 2^52 the float64 is already integer-valued (granularity ~2^44), so this
    is effectively a no-op on real data; the reference is therefore quantized to
    ~2^44 and is not exact-integer ground truth. round() is banker's rounding.
    """
    return round(value)
