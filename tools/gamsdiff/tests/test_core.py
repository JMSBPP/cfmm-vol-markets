import json
import pytest
from gamsdiff.core import to_sqrt_price_x96, tick_from_grid, GridRecord, KernelPoint, records_to_points, points_to_fixture, to_json

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

def test_records_to_points_maps_ordinal_and_value():
    rows = [GridRecord(tick_index=121, value=79228162514264337593543950336.0)]
    assert records_to_points(rows) == (
        KernelPoint(tick=0, expected_sqrt_price_x96=79228162514264337593543950336),
    )

def test_records_to_points_rejects_non_positive_value():
    with pytest.raises(ValueError):
        records_to_points([GridRecord(tick_index=121, value=0.0)])

_PTS = (
    KernelPoint(tick=-120, expected_sqrt_price_x96=78754240422857016427656773632),
    KernelPoint(tick=0, expected_sqrt_price_x96=79228162514264337593543950336),
)

def test_points_to_fixture_schema():
    fx = points_to_fixture(_PTS, symbol="priceKernel", source="model/PricingKernel.gms",
                           spacing=1, gams_version="54.1.0", platform="linux-x86_64")
    assert fx["symbol"] == "priceKernel"
    assert fx["scale"] == "Q64.96"
    assert fx["spacing"] == 1
    assert fx["gamsVersion"] == "54.1.0"
    assert fx["platform"] == "linux-x86_64"
    assert fx["count"] == 2
    assert fx["ticks"] == [-120, 0]
    # uint256 as decimal strings; index 0 is tick -120
    assert fx["expectedSqrtPriceX96"] == [
        "78754240422857016427656773632", "79228162514264337593543950336",
    ]

def test_to_json_roundtrips_and_lengths_agree():
    fx = points_to_fixture(_PTS, symbol="priceKernel", source="s", spacing=1,
                           gams_version="54.1.0", platform="linux-x86_64")
    parsed = json.loads(to_json(fx))
    assert len(parsed["ticks"]) == len(parsed["expectedSqrtPriceX96"]) == parsed["count"]
