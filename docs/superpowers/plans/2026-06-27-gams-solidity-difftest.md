# GAMS→Solidity Differential Testing (Pricing Kernel) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a thin uv-managed Python middle layer that drives a read-only GAMS run of `model/PricingKernel.gms`, emits a committed Q64.96 JSON fixture, and a Foundry diff test that asserts `getSqrtRatioAtTick` matches the GAMS reference within a relative tolerance.

**Architecture:** Functional core / imperative shell. Pure transforms (GDX records → kernel points → fixture JSON) in `core.py`, all I/O (gamsapi execution, GDX read, file write) in `shell.py`, ~15-line CLI in `__main__.py`. Foundry owns pass/fail over the committed fixture.

**Tech Stack:** Python 3.11+, uv, gamsapi[transfer]==54.1.*, pandas, pytest; Foundry/forge-std v1.16.1.

## Global Constraints

- **venv only** — every Python invocation runs via `uv run` against the project venv; never system Python.
- **Functional programming** — frozen dataclasses, free pure functions, no inheritance, full type annotations; side effects only in `shell.py`/`__main__.py`.
- **TDD** — write the failing test first for every pure function; run it red, then green.
- **Thin API** — public surface = CLI `uv run gamsdiff` + the pure functions in `core.py`. No frameworks.
- **Never edit `.gms` source** — GAMS is driven read-only via `gdx=` option (GAMS-dev session owns `model/*.gms`).
- **GAMS cwd MUST be `model/`** — `PricingKernel.gms:1` is `$include primitives.gms`, resolved against the working directory (BUILD.md).
- **Dependency pins** — `gamsapi[transfer]==54.1.*`; forge-std ≥ 1.16.1 (vendored).
- **Tolerance** — Foundry `EPS = 1e3` (= `1e-15` relative; float64 noise floor ≈ 2.2e-16).
- **uint256 in JSON** — emitted as decimal strings; ticks as JSON ints.
- **Tick index** — always the GAMS 1-based ordinal parsed from the set label `k<n>`, never a pandas row position.
- **Scope = `test/gamsDiff/` + `tools/gamsdiff/`** only. `foundry.toml` change requires Plank-session coordination (spec §13).

---

### Task 1: Pre-flight GAMS execute-mode smoke test

De-risks the single most unproven assumption: that `gamsapi` can execute `PricingKernel.gms` (this repo has only ever run `action=c`). No package code yet — a throwaway check whose evidence gates the rest.

**Files:**
- Create (throwaway, not committed): `/tmp/claude-1000/.../scratchpad/smoke_gams.py`

**Interfaces:**
- Produces: confirmation that `gams.transfer` reads `priceKernel`, and the golden value `tick 0 (k121, s1) == 79228162514264337593543950336`.

- [ ] **Step 1: Write the smoke script**

```python
# smoke_gams.py — throwaway pre-flight check
import os
from gams import GamsWorkspace, GamsOptions
import gams.transfer as gt

REPO = "/home/jmsbpp/cfmms-playground/cfmm-replicationPlank"
MODEL_DIR = os.path.join(REPO, "model")
SYS = "/usr/gams/gams54.1_linux_x64_64_sfx"

ws = GamsWorkspace(working_directory=MODEL_DIR, system_directory=SYS)
opt = GamsOptions(ws)
opt.gdx = "pricing_kernel.gdx"
job = ws.add_job_from_file("PricingKernel.gms")
job.run(opt)

m = gt.Container(os.path.join(MODEL_DIR, "pricing_kernel.gdx"))
df = m.data["priceKernel"].records
print("columns:", list(df.columns))
print("rows:", len(df))
# locate s1, k121 (tick 0)
print(df.head())
```

- [ ] **Step 2: Run it**

Run: `uv run --with 'gamsapi[transfer]==54.1.*' python /tmp/.../smoke_gams.py`
(or, if uv project already exists, `uv run python smoke_gams.py`)
Expected: exits 0; prints column names (domain columns + `value`), `rows: 14460` (60 spacings × 241 ticks), and a `value` of `7.922816e+28` for the `s1,k121` row.

- [ ] **Step 3: Record findings**

If it fails (license, cwd, API mismatch), STOP and report — the plan's GAMS path needs revision. If it passes, note the exact `df.columns` names (needed for Task 7) and proceed. Delete the scratch file.

---

### Task 2: Scaffold the uv project

**Files:**
- Create: `tools/gamsdiff/pyproject.toml`
- Create: `tools/gamsdiff/gamsdiff/__init__.py` (empty)
- Create: `tools/gamsdiff/tests/__init__.py` (empty)
- Create: `tools/gamsdiff/README.md`

**Interfaces:**
- Produces: a runnable `uv` project; `uv run pytest` works (collects 0 tests).

- [ ] **Step 1: Write `pyproject.toml`**

```toml
[project]
name = "gamsdiff"
version = "0.1.0"
description = "GAMS->Solidity differential-testing fixture generator (pricing kernel)"
requires-python = ">=3.11"
dependencies = [
    "gamsapi[transfer]==54.1.*",
    "pandas",
]

[project.scripts]
gamsdiff = "gamsdiff.__main__:main"

[dependency-groups]
dev = ["pytest"]

[build-system]
requires = ["hatchling"]
build-backend = "hatchling.build"

[tool.pytest.ini_options]
testpaths = ["tests"]
```

- [ ] **Step 2: Write `README.md`**

```markdown
# gamsdiff

Thin functional-core/imperative-shell layer that drives a read-only GAMS run of
`model/PricingKernel.gms`, reads the result via `gams.transfer`, and writes a
committed Q64.96 JSON fixture consumed by `test/gamsDiff/PricingKernelPlank.diff.t.sol`.

## Rules
- **Run everything through `uv run`** (never system Python).
- Never edits `.gms` sources; GAMS is driven read-only via the `gdx=` option.

## Usage
    uv run --project tools/gamsdiff gamsdiff
Regenerates `test/gamsDiff/fixtures/pricing_kernel.json`. Fixtures are platform-pinned.
```

- [ ] **Step 3: Create empty package/test `__init__.py` files**

```bash
mkdir -p tools/gamsdiff/gamsdiff tools/gamsdiff/tests
: > tools/gamsdiff/gamsdiff/__init__.py
: > tools/gamsdiff/tests/__init__.py
```

- [ ] **Step 4: Verify the project resolves**

Run: `uv run --project tools/gamsdiff pytest -q`
Expected: "no tests ran" (exit 0/5), venv created, deps resolved.

- [ ] **Step 5: Commit**

```bash
git add tools/gamsdiff/pyproject.toml tools/gamsdiff/uv.lock tools/gamsdiff/README.md tools/gamsdiff/gamsdiff/__init__.py tools/gamsdiff/tests/__init__.py
git commit -m "chore(gamsdiff): scaffold uv project for GAMS->Solidity diff fixtures"
```

---

### Task 3: `core.to_sqrt_price_x96`

**Files:**
- Create: `tools/gamsdiff/gamsdiff/core.py`
- Test: `tools/gamsdiff/tests/test_core.py`

**Interfaces:**
- Produces: `to_sqrt_price_x96(value: float) -> int`.

- [ ] **Step 1: Write the failing test**

```python
# tools/gamsdiff/tests/test_core.py
from gamsdiff.core import to_sqrt_price_x96

def test_to_sqrt_price_x96_q96_value_is_rounded_to_int():
    # tick 0 reference: 2^96
    assert to_sqrt_price_x96(79228162514264337593543950336.0) == 79228162514264337593543950336

def test_to_sqrt_price_x96_uses_python_bankers_rounding():
    # documents that round() is banker's rounding (no-op on real Q96-scale data)
    assert to_sqrt_price_x96(2.5) == 2
    assert to_sqrt_price_x96(3.5) == 4
```

- [ ] **Step 2: Run test to verify it fails**

Run: `uv run --project tools/gamsdiff pytest tests/test_core.py -v`
Expected: FAIL — `ModuleNotFoundError`/`ImportError: cannot import name 'to_sqrt_price_x96'`.

- [ ] **Step 3: Write minimal implementation**

```python
# tools/gamsdiff/gamsdiff/core.py
"""Pure transforms for the GAMS pricing-kernel diff fixture. No I/O."""


def to_sqrt_price_x96(value: float) -> int:
    """Round a GAMS float64 value (already scaled by 2^96) to its nearest integer.

    Above 2^52 the float64 is already integer-valued (granularity ~2^44), so this
    is effectively a no-op on real data; the reference is therefore quantized to
    ~2^44 and is not exact-integer ground truth. round() is banker's rounding.
    """
    return round(value)
```

- [ ] **Step 4: Run test to verify it passes**

Run: `uv run --project tools/gamsdiff pytest tests/test_core.py -v`
Expected: PASS (2 passed).

- [ ] **Step 5: Commit**

```bash
git add tools/gamsdiff/gamsdiff/core.py tools/gamsdiff/tests/test_core.py
git commit -m "feat(gamsdiff): to_sqrt_price_x96 (round GAMS Q96 float to int)"
```

---

### Task 4: `core.tick_from_grid`

**Files:**
- Modify: `tools/gamsdiff/gamsdiff/core.py`
- Test: `tools/gamsdiff/tests/test_core.py`

**Interfaces:**
- Produces: `tick_from_grid(tick_index: int, spacing: int = 1) -> int`.

- [ ] **Step 1: Write the failing test (append to test_core.py)**

```python
from gamsdiff.core import tick_from_grid

def test_tick_from_grid_maps_gams_ordinal_to_int24_tick():
    # tickVal = ord(tick) - 121 ; labels k1..k241 -> -120..120
    assert tick_from_grid(1) == -120
    assert tick_from_grid(121) == 0
    assert tick_from_grid(241) == 120

def test_tick_from_grid_scales_by_spacing():
    # spacing is the GAMS ord(s) multiplier, not a label index
    assert tick_from_grid(241, spacing=2) == 240
```

- [ ] **Step 2: Run test to verify it fails**

Run: `uv run --project tools/gamsdiff pytest tests/test_core.py -k tick_from_grid -v`
Expected: FAIL — `ImportError: cannot import name 'tick_from_grid'`.

- [ ] **Step 3: Write minimal implementation (append to core.py)**

```python
def tick_from_grid(tick_index: int, spacing: int = 1) -> int:
    """Map a GAMS 1-based ordinal (label ``k<n>``) to the int24 tick.

    Derived from the equivalence T = tickVal * spacing, where
    tickVal = ord(tick) - 121. ``spacing`` is the GAMS ``ord(s)`` value.
    """
    return (tick_index - 121) * spacing
```

- [ ] **Step 4: Run test to verify it passes**

Run: `uv run --project tools/gamsdiff pytest tests/test_core.py -k tick_from_grid -v`
Expected: PASS (2 passed).

- [ ] **Step 5: Commit**

```bash
git add tools/gamsdiff/gamsdiff/core.py tools/gamsdiff/tests/test_core.py
git commit -m "feat(gamsdiff): tick_from_grid (GAMS ordinal -> int24 tick)"
```

---

### Task 5: Dataclasses + `core.records_to_points`

**Files:**
- Modify: `tools/gamsdiff/gamsdiff/core.py`
- Test: `tools/gamsdiff/tests/test_core.py`

**Interfaces:**
- Consumes: `to_sqrt_price_x96`, `tick_from_grid`.
- Produces: `GridRecord(tick_index: int, value: float)` (frozen), `KernelPoint(tick: int, expected_sqrt_price_x96: int)` (frozen), `records_to_points(rows: Iterable[GridRecord], spacing: int = 1) -> tuple[KernelPoint, ...]`.

- [ ] **Step 1: Write the failing test (append to test_core.py)**

```python
import pytest
from gamsdiff.core import GridRecord, KernelPoint, records_to_points

def test_records_to_points_maps_ordinal_and_value():
    rows = [GridRecord(tick_index=121, value=79228162514264337593543950336.0)]
    assert records_to_points(rows) == (
        KernelPoint(tick=0, expected_sqrt_price_x96=79228162514264337593543950336),
    )

def test_records_to_points_rejects_non_positive_value():
    with pytest.raises(ValueError):
        records_to_points([GridRecord(tick_index=121, value=0.0)])
```

- [ ] **Step 2: Run test to verify it fails**

Run: `uv run --project tools/gamsdiff pytest tests/test_core.py -k records_to_points -v`
Expected: FAIL — `ImportError`.

- [ ] **Step 3: Write minimal implementation (append to core.py)**

```python
from collections.abc import Iterable
from dataclasses import dataclass


@dataclass(frozen=True)
class GridRecord:
    """One GAMS priceKernel record: 1-based tick ordinal and the Q96-scaled value."""

    tick_index: int
    value: float


@dataclass(frozen=True)
class KernelPoint:
    """One diff point: int24 tick and the expected Q64.96 sqrt price."""

    tick: int
    expected_sqrt_price_x96: int


def records_to_points(
    rows: Iterable[GridRecord], spacing: int = 1
) -> tuple[KernelPoint, ...]:
    """Pure transform from GAMS records to diff points. Validates value > 0."""
    points: list[KernelPoint] = []
    for r in rows:
        if r.value <= 0:
            raise ValueError(f"non-positive priceKernel value at tick_index={r.tick_index}: {r.value}")
        points.append(
            KernelPoint(
                tick=tick_from_grid(r.tick_index, spacing),
                expected_sqrt_price_x96=to_sqrt_price_x96(r.value),
            )
        )
    return tuple(points)
```

- [ ] **Step 4: Run test to verify it passes**

Run: `uv run --project tools/gamsdiff pytest tests/test_core.py -k records_to_points -v`
Expected: PASS (2 passed).

- [ ] **Step 5: Commit**

```bash
git add tools/gamsdiff/gamsdiff/core.py tools/gamsdiff/tests/test_core.py
git commit -m "feat(gamsdiff): GridRecord/KernelPoint + records_to_points"
```

---

### Task 6: `core.points_to_fixture` + `core.to_json`

**Files:**
- Modify: `tools/gamsdiff/gamsdiff/core.py`
- Test: `tools/gamsdiff/tests/test_core.py`

**Interfaces:**
- Consumes: `KernelPoint`.
- Produces: `points_to_fixture(points, *, symbol, source, spacing, gams_version, platform) -> dict`, `to_json(fixture: dict) -> str`.

- [ ] **Step 1: Write the failing test (append to test_core.py)**

```python
import json
from gamsdiff.core import points_to_fixture, to_json

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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `uv run --project tools/gamsdiff pytest tests/test_core.py -k fixture -v`
Expected: FAIL — `ImportError`.

- [ ] **Step 3: Write minimal implementation (append to core.py)**

```python
import json


def points_to_fixture(
    points: tuple[KernelPoint, ...],
    *,
    symbol: str,
    source: str,
    spacing: int,
    gams_version: str,
    platform: str,
) -> dict:
    """Build the forge-friendly fixture dict (uint256 as decimal strings)."""
    return {
        "symbol": symbol,
        "source": source,
        "scale": "Q64.96",
        "spacing": spacing,
        "gamsVersion": gams_version,
        "platform": platform,
        "count": len(points),
        "ticks": [p.tick for p in points],
        "expectedSqrtPriceX96": [str(p.expected_sqrt_price_x96) for p in points],
    }


def to_json(fixture: dict) -> str:
    """Serialize the fixture to deterministic JSON text."""
    return json.dumps(fixture, indent=2) + "\n"
```

- [ ] **Step 4: Run test to verify it passes**

Run: `uv run --project tools/gamsdiff pytest tests/test_core.py -k fixture -v`
Then full core suite: `uv run --project tools/gamsdiff pytest tests/test_core.py -v`
Expected: PASS (all core tests green).

- [ ] **Step 5: Commit**

```bash
git add tools/gamsdiff/gamsdiff/core.py tools/gamsdiff/tests/test_core.py
git commit -m "feat(gamsdiff): points_to_fixture + to_json (forge-friendly schema)"
```

---

### Task 7: `shell.load_grid_records` + `shell.write_fixture`

**Files:**
- Create: `tools/gamsdiff/gamsdiff/shell.py`
- Test: `tools/gamsdiff/tests/test_shell.py`

**Interfaces:**
- Consumes: nothing from core (returns `GridRecord` from core).
- Produces: `load_grid_records(*, model_workdir, sysdir, model_file="PricingKernel.gms", gdx_name="pricing_kernel.gdx", symbol="priceKernel", spacing_index=1) -> tuple[GridRecord, ...]`, `write_fixture(path: str, text: str) -> None`, and module constants `DEFAULT_MODEL_WORKDIR`, `DEFAULT_SYSDIR`, `DEFAULT_OUTPUT`.

> **NOTE:** use the exact `records` column names confirmed in Task 1. The code below assumes `gams.transfer` names domain columns `tickSpacingDomain` and `tick`; if Task 1 showed different names (e.g. `uni_0`), substitute them here.

- [ ] **Step 1: Write the failing integration test (skips without GAMS)**

```python
# tools/gamsdiff/tests/test_shell.py
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `uv run --project tools/gamsdiff pytest tests/test_shell.py -v`
Expected: FAIL — `ImportError` (no `shell` module). (The integration test will skip if GAMS is absent; the `write_fixture` test must still fail on import.)

- [ ] **Step 3: Write minimal implementation**

```python
# tools/gamsdiff/gamsdiff/shell.py
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
```

- [ ] **Step 4: Run tests**

Run: `uv run --project tools/gamsdiff pytest tests/test_shell.py -v`
Expected: `test_write_fixture_writes_text` PASS; the GAMS test PASS if GAMS present, else SKIP.

- [ ] **Step 5: Commit**

```bash
git add tools/gamsdiff/gamsdiff/shell.py tools/gamsdiff/tests/test_shell.py
git commit -m "feat(gamsdiff): shell load_grid_records (gamsapi+transfer) + write_fixture"
```

---

### Task 8: CLI wiring + generate the committed fixture

**Files:**
- Create: `tools/gamsdiff/gamsdiff/__main__.py`
- Create (generated, committed): `test/gamsDiff/fixtures/pricing_kernel.json`

**Interfaces:**
- Consumes: `shell.load_grid_records`, `shell.write_fixture`, `shell.DEFAULT_*`, `core.records_to_points`, `core.points_to_fixture`, `core.to_json`.
- Produces: `main() -> None` (console entry point `gamsdiff`).

- [ ] **Step 1: Write `__main__.py`**

```python
# tools/gamsdiff/gamsdiff/__main__.py
"""CLI: wire shell -> pure core -> shell. Regenerates the committed fixture."""
import platform as _platform

from gamsdiff import shell
from gamsdiff.core import points_to_fixture, records_to_points, to_json

_SPACING_INDEX = 1  # v1: s1 slice


def main() -> None:
    records = shell.load_grid_records(
        model_workdir=shell.DEFAULT_MODEL_WORKDIR,
        sysdir=shell.DEFAULT_SYSDIR,
        spacing_index=_SPACING_INDEX,
    )
    points = records_to_points(records, spacing=_SPACING_INDEX)
    fixture = points_to_fixture(
        points,
        symbol="priceKernel",
        source="model/PricingKernel.gms",
        spacing=_SPACING_INDEX,
        gams_version="54.1.0",
        platform=f"{_platform.system().lower()}-{_platform.machine()}",
    )
    shell.write_fixture(shell.DEFAULT_OUTPUT, to_json(fixture))
    print(f"wrote {len(points)} points -> {shell.DEFAULT_OUTPUT}")


if __name__ == "__main__":
    main()
```

- [ ] **Step 2: Generate the fixture (requires GAMS)**

Run: `uv run --project tools/gamsdiff gamsdiff`
Expected: `wrote 241 points -> .../test/gamsDiff/fixtures/pricing_kernel.json`.

- [ ] **Step 3: Sanity-check the fixture**

Run: `uv run --project tools/gamsdiff python -c "import json;d=json.load(open('test/gamsDiff/fixtures/pricing_kernel.json'));print(d['count'], d['ticks'][0], d['expectedSqrtPriceX96'][d['ticks'].index(0)])"`
Expected: `241 -120 79228162514264337593543950336` (tick 0 maps to 2^96).

- [ ] **Step 4: Commit**

```bash
git add tools/gamsdiff/gamsdiff/__main__.py test/gamsDiff/fixtures/pricing_kernel.json
git commit -m "feat(gamsdiff): CLI + committed pricing_kernel fixture (s1, 241 ticks)"
```

---

### Task 9: Foundry differential test

**BLOCKED until Plank session (`ul2inqpl`) adds `fs_permissions` to `foundry.toml`** (spec §13). Do not start until confirmed.

**Files:**
- Modify: `test/gamsDiff/PricingKernelPlank.diff.t.sol`
- Modify (by Plank session, or delegated): `foundry.toml`

**Interfaces:**
- Consumes: `test/gamsDiff/fixtures/pricing_kernel.json`, existing `setUp()` + `_getSqrtRatioAtTick(int24)`.

- [ ] **Step 1: Confirm `foundry.toml` grants read access**

```toml
fs_permissions = [{ access = "read", path = "./test/gamsDiff/fixtures" }]
```
Verify present (added by `ul2inqpl` or delegated). Without it, `vm.readFile` reverts.

- [ ] **Step 2: Write the test body (append the function to the contract)**

```solidity
import {stdMath} from "forge-std/StdMath.sol";

// EPS = 1e3  (1e-15 relative; float64 noise floor ~2.2e-16 -> ~4x headroom)
uint256 constant EPS = 1e3;
uint256 constant TWO_96 = 79228162514264337593543950336; // 2^96

function test_PricingKernel_matches_getSqrtRatioAtTick() public view {
    string memory json = vm.readFile("test/gamsDiff/fixtures/pricing_kernel.json");
    int256[] memory ticks = vm.parseJsonIntArray(json, ".ticks");
    uint256[] memory expected = vm.parseJsonUintArray(json, ".expectedSqrtPriceX96");
    assertEq(ticks.length, expected.length, "fixture array length mismatch");
    assertEq(ticks.length, 241, "expected 241 ticks (s1 slice)");

    // sign-extension regression guard: endpoints straddle 2^96
    assertLt(_getSqrtRatioAtTick(-120), TWO_96, "tick -120 should be < 2^96");
    assertGt(_getSqrtRatioAtTick(int24(120)), TWO_96, "tick 120 should be > 2^96");

    for (uint256 i = 0; i < ticks.length; i++) {
        uint256 actual = _getSqrtRatioAtTick(int24(ticks[i]));
        assertApproxEqRel(actual, expected[i], EPS);
    }
}
```

- [ ] **Step 3: Run the test**

Run: `forge test --match-path test/gamsDiff/PricingKernelPlank.diff.t.sol -vvv`
Expected: PASS. If `assertApproxEqRel` reports `% Delta` slightly above `Max % Delta`, record the observed value and (only with justification) bump `EPS` toward `1e4`.

- [ ] **Step 4: Commit**

```bash
git add test/gamsDiff/PricingKernelPlank.diff.t.sol
git commit -m "test(gamsDiff): diff PricingKernel vs getSqrtRatioAtTick (assertApproxEqRel)"
```

---

### Task 10: Makefile target

**Files:**
- Modify: `Makefile`

> **NOTE:** `Makefile` is in the Plank session's domain per CLAUDE.md (`foundry.toml`/build config). Confirm via `claude-peers` or delegate, like Task 9's `foundry.toml`.

**Interfaces:**
- Produces: `make gams-fixtures`.

- [ ] **Step 1: Add the target**

```makefile
# gams-fixtures: regenerate committed GAMS->Solidity diff fixtures (read-only GAMS run).
.PHONY: gams-fixtures
gams-fixtures:
	uv run --project tools/gamsdiff gamsdiff
```

- [ ] **Step 2: Verify**

Run: `make gams-fixtures`
Expected: `wrote 241 points -> .../pricing_kernel.json` (no diff if fixture unchanged on this platform).

- [ ] **Step 3: Commit**

```bash
git add Makefile
git commit -m "build: make gams-fixtures target (uv run gamsdiff)"
```

---

## Self-Review

**Spec coverage:** §3 data flow → Tasks 7–9; §4.1 pure core → Tasks 3–6; §4.2 shell → Task 7; §4.3 CLI → Task 8; §5 fixture format → Tasks 6, 8; §6 Solidity → Task 9; §7 TDD → Tasks 3–7; §8 error handling → Tasks 5, 7; §9 Makefile/venv → Tasks 2, 10; §10 generalization → covered by `spacing` params (Tasks 4, 5); §11 smoke test/pins → Tasks 1, 2; §13 coordination → gating notes on Tasks 9, 10. ✔

**Placeholder scan:** all steps contain runnable code/commands; the only deferred detail is the GDX column names, explicitly resolved by Task 1 and flagged in Task 7. ✔

**Type consistency:** `GridRecord(tick_index, value)`, `KernelPoint(tick, expected_sqrt_price_x96)`, `to_sqrt_price_x96`, `tick_from_grid`, `records_to_points`, `points_to_fixture`, `to_json`, `load_grid_records`, `write_fixture`, `DEFAULT_MODEL_WORKDIR/DEFAULT_SYSDIR/DEFAULT_OUTPUT`, `main` — names/signatures consistent across Tasks 3–10. ✔
