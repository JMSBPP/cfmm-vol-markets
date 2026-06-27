from gamsdiff.core import to_sqrt_price_x96, tick_from_grid

def test_to_sqrt_price_x96_q96_value_is_rounded_to_int():
    # tick 0 reference: 2^96
    assert to_sqrt_price_x96(79228162514264337593543950336.0) == 79228162514264337593543950336

def test_to_sqrt_price_x96_uses_python_bankers_rounding():
    # documents that round() is banker's rounding (no-op on real Q96-scale data)
    assert to_sqrt_price_x96(2.5) == 2
    assert to_sqrt_price_x96(3.5) == 4

def test_tick_from_grid_maps_gams_ordinal_to_int24_tick():
    # tickVal = ord(tick) - 121 ; labels k1..k241 -> -120..120
    assert tick_from_grid(1) == -120
    assert tick_from_grid(121) == 0
    assert tick_from_grid(241) == 120

def test_tick_from_grid_scales_by_spacing():
    # spacing is the GAMS ord(s) multiplier, not a label index
    assert tick_from_grid(241, spacing=2) == 240
