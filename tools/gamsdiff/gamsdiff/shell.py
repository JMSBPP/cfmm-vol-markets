"""Imperative shell: the only side effects (GAMS execution, GDX read, file write)."""
import os
import re
from dataclasses import dataclass

from gams import GamsWorkspace, GamsOptions
import gams.transfer as gt

from gamsdiff.core import GridRecord, ImpactRecord, tick_from_grid

_REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
DEFAULT_MODEL_WORKDIR = os.path.join(_REPO, "model")
DEFAULT_SYSDIR = "/usr/gams/gams54.1_linux_x64_64_sfx"
DEFAULT_OUTPUT = os.path.join(_REPO, "test", "gamsDiff", "fixtures", "pricing_kernel.json")

_LABEL_RE = re.compile(r"^k(\d+)$")


def load_grid_records(
    *,
    model_workdir: str,
    sysdir: str,
    model_file: str = "PricingKernel.gms",
    gdx_name: str = "pricing_kernel.gdx",
    symbol: str = "priceKernel",
    spacing_index: int = 1,
) -> tuple[GridRecord, ...]:
    """Run GAMS read-only (cwd=model_workdir, gdx unload), read `symbol` for the
    selected spacing, and return GridRecords keyed by the GAMS 1-based tick ordinal."""
    ws = GamsWorkspace(working_directory=model_workdir, system_directory=sysdir)
    opt = GamsOptions(ws)
    opt.gdx = gdx_name
    job = ws.add_job_from_file(model_file)
    job.run(opt)  # raises GamsException on non-zero status

    gdx_path = os.path.join(model_workdir, gdx_name)
    container = gt.Container(gdx_path)
    if symbol not in container.data:
        raise KeyError(f"symbol {symbol!r} not found in {gdx_path}")
    df = container.data[symbol].records
    if df is None or len(df) == 0:
        raise ValueError(f"symbol {symbol!r} has no records in {gdx_path}")

    spacing_label = f"s{spacing_index}"
    sub = df[df["tickSpacingDomain"].astype(str) == spacing_label]
    if len(sub) == 0:
        raise ValueError(f"no records for spacing {spacing_label!r} in {symbol!r}")

    records: list[GridRecord] = []
    for _, row in sub.iterrows():
        m = _LABEL_RE.match(str(row["tick"]))
        if not m:
            raise ValueError(f"unexpected tick label: {row['tick']!r}")
        records.append(GridRecord(tick_index=int(m.group(1)), value=float(row["value"])))
    records.sort(key=lambda r: r.tick_index)
    return tuple(records)


def write_fixture(path: str, text: str) -> None:
    """Write fixture text, creating parent dirs."""
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as fh:
        fh.write(text)


@dataclass(frozen=True)
class ImpactGrid:
    """Result of a price-impact GAMS run: the diff rows plus the shared liquidity Lbar."""

    records: tuple[ImpactRecord, ...]
    liquidity: int


def load_impact_records(*, model_workdir: str, sysdir: str) -> ImpactGrid:
    """Run PriceImpactKernelFixture.gms read-only (gdx= dumps all symbols), read priceImpact
    (output) + priceKernel (input sqrtP) + Lbar + dxVal + etaWeight, and join into 723 rows."""
    ws = GamsWorkspace(working_directory=model_workdir, system_directory=sysdir)
    opt = GamsOptions(ws)
    opt.gdx = "price_impact_all.gdx"
    job = ws.add_job_from_file("PriceImpactKernelFixture.gms")
    job.run(opt)

    gdx_path = os.path.join(model_workdir, "price_impact_all.gdx")
    c = gt.Container(gdx_path)
    for sym in ("priceImpact", "priceKernel", "Lbar", "dxVal", "etaWeight"):
        if sym not in c.data:
            raise KeyError(f"symbol {sym!r} not found in {gdx_path}")
        if c.data[sym].records is None or len(c.data[sym].records) == 0:
            raise ValueError(f"symbol {sym!r} has no records in {gdx_path}")

    eta = float(c.data["etaWeight"].records["value"].iloc[0])
    if eta != 0.5:
        raise ValueError(f"expected etaWeight=0.5, got {eta}")
    liquidity = round(float(c.data["Lbar"].records["value"].iloc[0]))

    dx_df = c.data["dxVal"].records
    dxmap = {str(row["dxD"]): round(float(row["value"])) for _, row in dx_df.iterrows()}

    pk = c.data["priceKernel"].records
    pk_s1 = pk[pk["tickSpacingDomain"].astype(str) == "s1"]
    sqrtp: dict[int, int] = {}
    for _, row in pk_s1.iterrows():
        m = _LABEL_RE.match(str(row["tick"]))
        if not m:
            raise ValueError(f"unexpected priceKernel tick label: {row['tick']!r}")
        sqrtp[int(m.group(1))] = round(float(row["value"]))
    if not sqrtp:
        raise ValueError("priceKernel has no records for s1 — cannot build sqrtP lookup")

    pi = c.data["priceImpact"].records
    pi_s1 = pi[pi["s"].astype(str) == "s1"]
    if len(pi_s1) == 0:
        raise ValueError("no priceImpact records for s1")
    records: list[ImpactRecord] = []
    for _, row in pi_s1.iterrows():
        m = _LABEL_RE.match(str(row["tick"]))
        if not m:
            raise ValueError(f"unexpected priceImpact tick label: {row['tick']!r}")
        n = int(m.group(1))
        records.append(
            ImpactRecord(
                tick=tick_from_grid(n),
                sqrt_p_x96=sqrtp[n],
                amount0_in=dxmap[str(row["dxD"])],
                expected_sqrt_price_x96=round(float(row["value"])),
            )
        )
    records.sort(key=lambda r: (r.tick, r.amount0_in))
    return ImpactGrid(records=tuple(records), liquidity=liquidity)
