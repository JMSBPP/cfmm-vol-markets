import os
import shutil
import pytest

from gamsdiff import shell
from gamsdiff.core import GridRecord

_HAVE_GAMS = shutil.which("gams") is not None and os.path.isdir(shell.DEFAULT_SYSDIR)

@pytest.mark.skipif(not _HAVE_GAMS, reason="GAMS not available")
def test_load_grid_records_returns_241_points_for_s1():
    rows = shell.load_grid_records(
        model_workdir=shell.DEFAULT_MODEL_WORKDIR, sysdir=shell.DEFAULT_SYSDIR,
    )
    assert len(rows) == 241
    assert all(isinstance(r, GridRecord) for r in rows)
    by_index = {r.tick_index: r for r in rows}
    assert by_index[121].value == pytest.approx(79228162514264337593543950336.0, rel=1e-9)

def test_write_fixture_writes_text(tmp_path):
    p = tmp_path / "f.json"
    shell.write_fixture(str(p), '{"ok": true}\n')
    assert p.read_text() == '{"ok": true}\n'


@pytest.mark.skipif(not _HAVE_GAMS, reason="GAMS not available")
def test_load_impact_records_returns_723_for_s1():
    grid = shell.load_impact_records(
        model_workdir=shell.DEFAULT_MODEL_WORKDIR, sysdir=shell.DEFAULT_SYSDIR,
    )
    assert grid.liquidity == 10**18
    assert len(grid.records) == 723
    # ascending sort by (tick, amount0_in); first tick is -120
    assert grid.records[0].tick == -120
    # every post-trade price strictly below its input sqrt price
    assert all(r.expected_sqrt_price_x96 < r.sqrt_p_x96 for r in grid.records)
    # three distinct dx amounts present
    assert {r.amount0_in for r in grid.records} == {10**15, 10**17, 10**18}
