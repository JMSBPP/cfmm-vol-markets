from gamsdiff.core import to_sqrt_price_x96

def test_to_sqrt_price_x96_q96_value_is_rounded_to_int():
    # tick 0 reference: 2^96
    assert to_sqrt_price_x96(79228162514264337593543950336.0) == 79228162514264337593543950336

def test_to_sqrt_price_x96_uses_python_bankers_rounding():
    # documents that round() is banker's rounding (no-op on real Q96-scale data)
    assert to_sqrt_price_x96(2.5) == 2
    assert to_sqrt_price_x96(3.5) == 4
