import json
import pytest

# Task 3
from gamsdiff.core import to_sqrt_price_x96
# Task 4
from gamsdiff.core import tick_from_grid
# Task 5
from gamsdiff.core import GridRecord, KernelPoint, records_to_points
# Task 6
from gamsdiff.core import points_to_fixture, to_json
# Tunable kernel (elasticity-aware): balanced 50/50 weight, the only EVM-testable eta
from gamsdiff.core import BALANCED_ETA
# Task 2: ImpactRecord + impact_records_to_fixture
from gamsdiff.core import ImpactRecord, impact_records_to_fixture

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
    with pytest.raises(ValueError):
        records_to_points([GridRecord(tick_index=121, value=-1.0)])

_PTS = (
    KernelPoint(tick=-120, expected_sqrt_price_x96=78754240422857016427656773632),
    KernelPoint(tick=0, expected_sqrt_price_x96=79228162514264337593543950336),
)

def test_balanced_eta_is_one_half():
    # The balanced 50/50 pool weight (eta_x_y/unity = 1/2): the only elasticity the
    # EVM getSqrtRatioAtTick represents, so the only one the diff test can verify.
    assert BALANCED_ETA == 0.5

def test_points_to_fixture_schema():
    fx = points_to_fixture(_PTS, symbol="priceKernel", source="model/PricingKernel.gms",
                           spacing=1, gams_version="54.1.0", platform="linux-x86_64",
                           eta=BALANCED_ETA)
    assert fx["symbol"] == "priceKernel"
    assert fx["scale"] == "Q64.96"
    assert fx["spacing"] == 1
    assert fx["gamsVersion"] == "54.1.0"
    assert fx["platform"] == "linux-x86_64"
    assert fx["source"] == "model/PricingKernel.gms"
    # tunable-kernel elasticity: the balanced-pool weight pinned for the EVM diff
    assert fx["eta"] == 0.5
    assert fx["kernel"] == "tunablePricingKernel(eta=0.5)"
    assert fx["count"] == 2
    assert fx["ticks"] == [-120, 0]
    # uint256 as decimal strings; index 0 is tick -120
    assert fx["expectedSqrtPriceX96"] == [
        "78754240422857016427656773632", "79228162514264337593543950336",
    ]

def test_to_json_roundtrips_and_lengths_agree():
    fx = points_to_fixture(_PTS, symbol="priceKernel", source="s", spacing=1,
                           gams_version="54.1.0", platform="linux-x86_64", eta=BALANCED_ETA)
    parsed = json.loads(to_json(fx))
    assert len(parsed["ticks"]) == len(parsed["expectedSqrtPriceX96"]) == parsed["count"]


_IMPACT = (
    ImpactRecord(tick=0, sqrt_p_x96=79228162514264337593543950336, amount0_in=100000000000000000,
                 expected_sqrt_price_x96=72025602285694800000000000000),
    ImpactRecord(tick=0, sqrt_p_x96=79228162514264337593543950336, amount0_in=1000000000000000000,
                 expected_sqrt_price_x96=39614081257132200000000000000),
)

def test_impact_fixture_schema():
    fx = impact_records_to_fixture(_IMPACT, liquidity=10**18, eta=0.5,
                                   gams_version="54.1.0", platform="linux-x86_64")
    assert fx["symbol"] == "priceImpact"
    assert fx["scale"] == "Q64.96"
    assert fx["eta"] == 0.5
    assert fx["add"] is True
    assert fx["liquidity"] == "1000000000000000000"
    assert fx["gamsVersion"] == "54.1.0"
    assert fx["source"] == "model/PriceImpactKernelFixture.gms"
    assert fx["count"] == 2
    assert fx["ticks"] == [0, 0]
    assert fx["sqrtPX96In"] == ["79228162514264337593543950336", "79228162514264337593543950336"]
    assert fx["amount0In"] == ["100000000000000000", "1000000000000000000"]
    assert fx["expectedSqrtPriceX96"] == ["72025602285694800000000000000", "39614081257132200000000000000"]

def test_impact_fixture_rejects_expected_ge_sqrt_p():
    bad = (ImpactRecord(tick=0, sqrt_p_x96=10, amount0_in=5, expected_sqrt_price_x96=10),)
    with pytest.raises(ValueError):
        impact_records_to_fixture(bad, liquidity=10**18, eta=0.5, gams_version="x", platform="y")

def test_impact_fixture_rejects_empty():
    with pytest.raises(ValueError):
        impact_records_to_fixture((), liquidity=10**18, eta=0.5, gams_version="x", platform="y")

def test_impact_fixture_rejects_non_positive_liquidity():
    with pytest.raises(ValueError):
        impact_records_to_fixture(_IMPACT, liquidity=0, eta=0.5, gams_version="x", platform="y")

def test_impact_fixture_rejects_non_positive_row_value():
    bad = (ImpactRecord(tick=0, sqrt_p_x96=100, amount0_in=0, expected_sqrt_price_x96=50),)
    with pytest.raises(ValueError):
        impact_records_to_fixture(bad, liquidity=10**18, eta=0.5, gams_version="x", platform="y")
