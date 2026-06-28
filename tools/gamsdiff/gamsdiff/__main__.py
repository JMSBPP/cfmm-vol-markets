# tools/gamsdiff/gamsdiff/__main__.py
"""CLI: wire shell -> pure core -> shell. Regenerates the committed fixture."""
import platform as _platform

from gamsdiff import shell
import os.path as _ospath

from gamsdiff.core import BALANCED_ETA, impact_records_to_fixture, points_to_fixture, records_to_points, to_json

_SPACING_INDEX = 1  # v1: s1 slice

_IMPACT_OUTPUT = _ospath.join(
    _ospath.dirname(shell.DEFAULT_OUTPUT), "price_impact_kernel.json"
)


def main() -> None:
    records = shell.load_grid_records(
        model_workdir=shell.DEFAULT_MODEL_WORKDIR,
        sysdir=shell.DEFAULT_SYSDIR,
        spacing_index=_SPACING_INDEX,
    )
    points = records_to_points(records, spacing=_SPACING_INDEX)
    # priceKernel is tunablePricingKernel at the balanced weight (eta = 1/2) — the
    # only elasticity the EVM getSqrtRatioAtTick can be diffed against.
    fixture = points_to_fixture(
        points,
        symbol="priceKernel",
        source="model/PricingKernel.gms",
        spacing=_SPACING_INDEX,
        gams_version="54.1.0",
        platform=f"{_platform.system().lower()}-{_platform.machine()}",
        eta=BALANCED_ETA,
    )
    shell.write_fixture(shell.DEFAULT_OUTPUT, to_json(fixture))
    print(f"wrote {len(points)} points -> {shell.DEFAULT_OUTPUT}")


def main_impact() -> None:
    grid = shell.load_impact_records(
        model_workdir=shell.DEFAULT_MODEL_WORKDIR,
        sysdir=shell.DEFAULT_SYSDIR,
    )
    fixture = impact_records_to_fixture(
        grid.records,
        liquidity=grid.liquidity,
        eta=BALANCED_ETA,
        gams_version="54.1.0",
        platform=f"{_platform.system().lower()}-{_platform.machine()}",
    )
    shell.write_fixture(_IMPACT_OUTPUT, to_json(fixture))
    print(f"wrote {len(grid.records)} impact rows -> {_IMPACT_OUTPUT}")


if __name__ == "__main__":
    main()
