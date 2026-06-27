"""Imperative shell: the only side effects (GAMS execution, GDX read, file write)."""
import os
import re

from gams import GamsWorkspace, GamsOptions
import gams.transfer as gt

from gamsdiff.core import GridRecord

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
