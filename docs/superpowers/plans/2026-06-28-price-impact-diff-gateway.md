# Price-Impact Differential Gateway Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a focused second differential gateway diffing the GAMS `priceImpact` reference (post-trade sqrt price, η=1/2) against the Plank `PriceImpactKernelHarness.getNextSqrtPriceFromAmount0RoundingUp`.

**Architecture:** Functional core / imperative shell, reusing the existing gamsdiff package. New pure builder + shell loader + a second CLI entry generate a committed flattened JSON fixture (723 rows); a new Foundry diff test consumes it. Minimal shared code — reuse `to_sqrt_price_x96`, `tick_from_grid`, `to_json`, `write_fixture`, `_LABEL_RE`.

**Tech Stack:** Python 3.11+, uv, gamsapi[transfer]==54.1.*, pandas, pytest; Foundry/forge-std v1.16.1; plank toolchain.

## Global Constraints

- **venv only** — every Python command via `uv run --project tools/gamsdiff`; never system Python.
- **Functional programming** — frozen dataclasses, free pure functions, no inheritance, full type annotations; side effects only in `shell.py`/`__main__.py`.
- **TDD** — write the failing test first for every pure function; run red, then green.
- **Never edit `.gms` source** — GAMS driven read-only via `gdx=`; do not stage changes to `model/*.gms` or `model/price_impact_kernel.gdx` (GAMS-owned).
- **GAMS cwd MUST be `model/`** — `PriceImpactKernelFixture.gms` `$include`s resolve there.
- **Tolerance** — Foundry `EPS = 1e3` (= `1e-15` relative; measured floor 2.02e-16).
- **uint in JSON** — decimal strings; ticks as JSON ints.
- **Scale/casts** — `priceImpact`/`priceKernel` Q64.96 ~8e28 fit uint160; `Lbar=1e18` fits uint128; `dx≤1e18` fits uint256.
- **GAMS_SYS** — `/usr/gams/gams54.1_linux_x64_64_sfx`.
- **Lossless `round()` holds ONLY for `sqrtP ≫ 2^52`** (this grid, ticks −120..120).

---

### Task 1: Sync prerequisites (merge feat/gams, vendor harness, gitignore transient GDX)

Git/setup task — no TDD. Brings the GAMS sources and the Plank harness into this branch and prevents committing the transient all-symbols GDX.

**Files:**
- Merge: `feat/gams` → `feat/gamsdiff` (brings `model/PriceImpactKernelFixture.gms`, `model/_PriceImpactKernelInputs.gms`, the `priceImpactKernel_Add0` macro in `model/PricingKernel.gms`, committed `model/price_impact_kernel.gdx`).
- Create: `test/gamsUtils/PriceImpactKernelHarness.plk` (vendored from `feat/plank`).
- Modify: `.gitignore` (ignore the transient driver GDX).

- [ ] **Step 1: Merge feat/gams**

```bash
cd /home/jmsbpp/cfmms-playground/cfmm-wt/gamsdiff
git merge --no-edit feat/gams
```
Expected: merge commit (or conflicts only in `Makefile`). If `Makefile` conflicts, keep both sides' targets (ours: `gams-fixtures`; theirs: `test-gams`, `compile-gams` test-exclusion) and `git add Makefile && git commit --no-edit`.

- [ ] **Step 2: Verify GAMS sources arrived**

```bash
ls model/PriceImpactKernelFixture.gms model/_PriceImpactKernelInputs.gms model/price_impact_kernel.gdx
grep -c priceImpactKernel_Add0 model/PricingKernel.gms
```
Expected: all three paths exist; grep prints `1`.

- [ ] **Step 3: Vendor the harness from feat/plank**

```bash
git show feat/plank:test/gamsUtils/PriceImpactKernelHarness.plk > test/gamsUtils/PriceImpactKernelHarness.plk
grep -c 0x157f652f test/gamsUtils/PriceImpactKernelHarness.plk
```
Expected: file written; grep prints `1` (selector present).

- [ ] **Step 4: Gitignore the transient driver GDX**

Append to `.gitignore`:
```
# gamsdiff: transient all-symbols GDX produced by the price-impact driver run
model/price_impact_all.gdx
```

- [ ] **Step 5: Commit**

```bash
git add test/gamsUtils/PriceImpactKernelHarness.plk .gitignore
git commit -m "chore(gamsdiff): sync feat/gams + vendor PriceImpactKernelHarness.plk; ignore transient GDX"
```
(The merge commit from Step 1 is separate; do not stage `model/` changes — they came via the merge.)

---

### Task 2: Pure core — `ImpactRecord` + `impact_records_to_fixture`

**Files:**
- Modify: `tools/gamsdiff/gamsdiff/core.py`
- Test: `tools/gamsdiff/tests/test_core.py`

**Interfaces:**
- Consumes: nothing new (reuses module).
- Produces: `ImpactRecord(tick: int, sqrt_p_x96: int, amount0_in: int, expected_sqrt_price_x96: int)` (frozen); `impact_records_to_fixture(records: tuple[ImpactRecord, ...], *, liquidity: int, eta: float, gams_version: str, platform: str) -> dict`.

- [ ] **Step 1: Write the failing test (append to test_core.py)**

```python
from gamsdiff.core import ImpactRecord, impact_records_to_fixture

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
    assert fx["count"] == 2
    assert fx["ticks"] == [0, 0]
    assert fx["sqrtPX96In"] == ["79228162514264337593543950336", "79228162514264337593543950336"]
    assert fx["amount0In"] == ["100000000000000000", "1000000000000000000"]
    assert fx["expectedSqrtPriceX96"] == ["72025602285694800000000000000", "39614081257132200000000000000"]

def test_impact_fixture_rejects_expected_ge_sqrt_p():
    bad = (ImpactRecord(tick=0, sqrt_p_x96=10, amount0_in=5, expected_sqrt_price_x96=10),)
    import pytest
    with pytest.raises(ValueError):
        impact_records_to_fixture(bad, liquidity=10**18, eta=0.5, gams_version="x", platform="y")

def test_impact_fixture_rejects_empty():
    import pytest
    with pytest.raises(ValueError):
        impact_records_to_fixture((), liquidity=10**18, eta=0.5, gams_version="x", platform="y")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `uv run --project tools/gamsdiff pytest tools/gamsdiff/tests/test_core.py -k impact -v`
Expected: FAIL — `ImportError: cannot import name 'ImpactRecord'`.

- [ ] **Step 3: Write minimal implementation (append to core.py)**

```python
@dataclass(frozen=True)
class ImpactRecord:
    """One price-impact diff row: int24 tick, input sqrt price, input amount0, expected post-trade sqrt price."""

    tick: int
    sqrt_p_x96: int
    amount0_in: int
    expected_sqrt_price_x96: int


def impact_records_to_fixture(
    records: tuple[ImpactRecord, ...],
    *,
    liquidity: int,
    eta: float,
    gams_version: str,
    platform: str,
) -> dict:
    """Build the forge-friendly flattened price-impact fixture (uint as decimal strings).

    Validates each row: all values > 0 and expected < sqrt_p strictly (a token0-input trade
    with dx > 0 must lower the post-trade price; expected == sqrt_p signals a zero/overflowed
    dx regression). round()-ing the GAMS float inputs is lossless on this grid (sqrt_p >> 2^52).
    """
    if not records:
        raise ValueError("no impact records")
    if liquidity <= 0:
        raise ValueError(f"non-positive liquidity: {liquidity}")
    for r in records:
        if min(r.sqrt_p_x96, r.amount0_in, r.expected_sqrt_price_x96) <= 0:
            raise ValueError(f"non-positive value at tick={r.tick}, amount0_in={r.amount0_in}")
        if r.expected_sqrt_price_x96 >= r.sqrt_p_x96:
            raise ValueError(
                f"expected ({r.expected_sqrt_price_x96}) must be < sqrt_p ({r.sqrt_p_x96}) "
                f"at tick={r.tick}, amount0_in={r.amount0_in}"
            )
    return {
        "symbol": "priceImpact",
        "source": "model/PriceImpactKernelFixture.gms",
        "scale": "Q64.96",
        "eta": eta,
        "add": True,
        "liquidity": str(liquidity),
        "gamsVersion": gams_version,
        "platform": platform,
        "count": len(records),
        "ticks": [r.tick for r in records],
        "sqrtPX96In": [str(r.sqrt_p_x96) for r in records],
        "amount0In": [str(r.amount0_in) for r in records],
        "expectedSqrtPriceX96": [str(r.expected_sqrt_price_x96) for r in records],
    }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `uv run --project tools/gamsdiff pytest tools/gamsdiff/tests/test_core.py -v`
Expected: PASS (all core tests green).

- [ ] **Step 5: Commit**

```bash
git add tools/gamsdiff/gamsdiff/core.py tools/gamsdiff/tests/test_core.py
git commit -m "feat(gamsdiff): ImpactRecord + impact_records_to_fixture (price-impact, eta=1/2)"
```

---

### Task 3: Imperative shell — `load_impact_records` + `ImpactGrid`

**Files:**
- Modify: `tools/gamsdiff/gamsdiff/shell.py`
- Test: `tools/gamsdiff/tests/test_shell.py`

**Interfaces:**
- Consumes: `core.ImpactRecord`, `core.tick_from_grid`.
- Produces: `ImpactGrid(records: tuple[ImpactRecord, ...], liquidity: int)` (frozen); `load_impact_records(*, model_workdir: str, sysdir: str) -> ImpactGrid`.

- [ ] **Step 1: Write the failing integration test (append to test_shell.py)**

```python
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `uv run --project tools/gamsdiff pytest tools/gamsdiff/tests/test_shell.py -k impact -v`
Expected: FAIL — `AttributeError: module 'gamsdiff.shell' has no attribute 'load_impact_records'` (or SKIP if GAMS absent — then verify import-level failure differently; on the build host GAMS is present).

- [ ] **Step 3: Write minimal implementation (append to shell.py)**

First extend the imports at the top of `shell.py`:
```python
from gamsdiff.core import GridRecord, ImpactRecord, tick_from_grid
```
(Replace the existing `from gamsdiff.core import GridRecord` line.)

Then append:
```python
from dataclasses import dataclass


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

    eta = float(c.data["etaWeight"].records["value"].iloc[0])
    if eta != 0.5:
        raise ValueError(f"expected etaWeight=0.5, got {eta}")
    liquidity = round(float(c.data["Lbar"].records["value"].iloc[0]))

    dx_df = c.data["dxVal"].records
    dx_cols = list(dx_df.columns)
    dxmap = {str(row[dx_cols[0]]): round(float(row[dx_cols[-1]])) for _, row in dx_df.iterrows()}

    pk = c.data["priceKernel"].records
    pk_cols = list(pk.columns)
    pk_s1 = pk[pk[pk_cols[0]].astype(str) == "s1"]
    sqrtp: dict[int, int] = {}
    for _, row in pk_s1.iterrows():
        m = _LABEL_RE.match(str(row[pk_cols[1]]))
        if not m:
            raise ValueError(f"unexpected priceKernel tick label: {row[pk_cols[1]]!r}")
        sqrtp[int(m.group(1))] = round(float(row[pk_cols[-1]]))

    pi = c.data["priceImpact"].records
    pi_cols = list(pi.columns)
    pi_s1 = pi[pi[pi_cols[0]].astype(str) == "s1"]
    if len(pi_s1) == 0:
        raise ValueError("no priceImpact records for s1")
    records: list[ImpactRecord] = []
    for _, row in pi_s1.iterrows():
        m = _LABEL_RE.match(str(row[pi_cols[1]]))
        if not m:
            raise ValueError(f"unexpected priceImpact tick label: {row[pi_cols[1]]!r}")
        n = int(m.group(1))
        records.append(
            ImpactRecord(
                tick=tick_from_grid(n),
                sqrt_p_x96=sqrtp[n],
                amount0_in=dxmap[str(row[pi_cols[2]])],
                expected_sqrt_price_x96=round(float(row[pi_cols[-1]])),
            )
        )
    records.sort(key=lambda r: (r.tick, r.amount0_in))
    return ImpactGrid(records=tuple(records), liquidity=liquidity)
```

- [ ] **Step 4: Run tests**

Run: `uv run --project tools/gamsdiff pytest tools/gamsdiff/tests/test_shell.py -v`
Expected: `test_load_impact_records_returns_723_for_s1` PASS (GAMS present on build host) or SKIP (no GAMS); existing shell tests still PASS.

- [ ] **Step 5: Commit**

```bash
git add tools/gamsdiff/gamsdiff/shell.py tools/gamsdiff/tests/test_shell.py
git commit -m "feat(gamsdiff): shell load_impact_records (gdx= all-symbols) + ImpactGrid"
```

---

### Task 4: CLI `gamsdiff-impact` + generate the committed fixture

**Files:**
- Modify: `tools/gamsdiff/gamsdiff/__main__.py`
- Modify: `tools/gamsdiff/pyproject.toml`
- Create (generated, committed): `test/gamsDiff/fixtures/price_impact_kernel.json`

**Interfaces:**
- Consumes: `shell.load_impact_records`, `shell.DEFAULT_MODEL_WORKDIR`, `shell.DEFAULT_SYSDIR`, `core.impact_records_to_fixture`, `core.to_json`, `core.BALANCED_ETA`, `shell.write_fixture`.
- Produces: `main_impact() -> None` (console entry `gamsdiff-impact`).

- [ ] **Step 1: Add the console script to pyproject.toml**

In `[project.scripts]`, add alongside the existing `gamsdiff` entry:
```toml
gamsdiff-impact = "gamsdiff.__main__:main_impact"
```

- [ ] **Step 2: Add `main_impact` to `__main__.py`**

Extend the imports:
```python
from gamsdiff.core import BALANCED_ETA, impact_records_to_fixture, points_to_fixture, records_to_points, to_json
```
Add a module constant and the function:
```python
import os.path as _ospath

_IMPACT_OUTPUT = _ospath.join(
    _ospath.dirname(shell.DEFAULT_OUTPUT), "price_impact_kernel.json"
)


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
```

- [ ] **Step 3: Generate the fixture (requires GAMS)**

Run: `uv run --project tools/gamsdiff gamsdiff-impact`
Expected: `wrote 723 impact rows -> .../test/gamsDiff/fixtures/price_impact_kernel.json`.

- [ ] **Step 4: Sanity-check the fixture**

Run: `uv run --project tools/gamsdiff python -c "import json;d=json.load(open('test/gamsDiff/fixtures/price_impact_kernel.json'));print(d['count'], d['eta'], d['add'], len(d['ticks']), len(d['expectedSqrtPriceX96']))"`
Expected: `723 0.5 True 723 723`.

- [ ] **Step 5: Confirm the transient GDX is ignored**

Run: `git status --porcelain model/price_impact_all.gdx`
Expected: empty output (ignored). If it appears, fix `.gitignore` (Task 1 Step 4) before committing.

- [ ] **Step 6: Commit (do NOT stage model/ changes)**

```bash
git add tools/gamsdiff/gamsdiff/__main__.py tools/gamsdiff/pyproject.toml test/gamsDiff/fixtures/price_impact_kernel.json
git commit -m "feat(gamsdiff): gamsdiff-impact CLI + committed price_impact_kernel fixture (723 rows)"
```

---

### Task 5: Foundry diff test `PriceImpactKernelPlank.diff.t.sol`

Write + commit the test. It runs on the build host / a worktree with submodules initialized (this worktree leaves them uninit), so the in-worktree deliverable is the committed test; the forge pass is confirmed externally (spec §10).

**Files:**
- Create: `test/gamsDiff/PriceImpactKernelPlank.diff.t.sol`

**Interfaces:**
- Consumes: `test/gamsUtils/PriceImpactKernelHarness.plk` (Task 1), `test/gamsDiff/fixtures/price_impact_kernel.json` (Task 4).

- [ ] **Step 1: Write the test**

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {PlankDeployer, BuildOptions, Dependency} from "plank-foundry-deployer/PlankDeployer.sol";
import {LibCall} from "bunni-v2/lib/solady/src/utils/LibCall.sol";

/// @title PriceImpactKernelPlankdiffTest
/// @notice Diffs the GAMS price-impact kernel (post-trade sqrt price, eta=1/2) against the
///         on-chain Uniswap V3 reference exposed by `PriceImpactKernelHarness.plk`
///         (`getNextSqrtPriceFromAmount0RoundingUp`, add=true, token0-input).
/// @dev Pure reader harness, deployed locally (no fork). Fixture is the GAMS priceImpact
///      grid (1 spacing x 241 ticks x 3 dx = 723 rows). Inputs (sqrtPX96In, amount0In,
///      liquidity) are bit-identical to what GAMS used (round() is lossless at Q96 scale),
///      so the diff isolates only the GAMS-float-vs-EVM-integer formula error (~2e-16).
contract PriceImpactKernelPlankdiffTest is Test, PlankDeployer {
    // getNextSqrtPriceFromAmount0RoundingUp(uint160,uint128,uint256,bool)
    bytes4 constant SEL = 0x157f652f;
    // EPS = 1e3 (1e-15 relative; measured floor ~2.02e-16, ~5x headroom)
    uint256 constant EPS = 1e3;
    uint256 constant TWO_96 = 79228162514264337593543950336; // 2^96

    address public HARNESS;

    function setUp() public {
        BuildOptions memory opts;
        opts.backend = "sona";
        Dependency[] memory deps = new Dependency[](1);
        deps[0] = Dependency("v3", "lib/plankified-univ3/plank/lib");
        opts.dependencies = deps;
        HARNESS = plankDeployFFI("test/gamsUtils/PriceImpactKernelHarness.plk", opts);
    }

    function _next(uint160 sqrtP, uint128 L, uint256 amount, bool add) internal view returns (uint256) {
        return abi.decode(
            LibCall.staticCallContract(HARNESS, abi.encodeWithSelector(SEL, sqrtP, L, amount, add)),
            (uint256)
        );
    }

    function test_PriceImpact_matches_getNextSqrtPriceFromAmount0RoundingUp() public view {
        string memory json = vm.readFile("test/gamsDiff/fixtures/price_impact_kernel.json");
        int256[] memory ticks = vm.parseJsonIntArray(json, ".ticks");
        uint256[] memory sqrtPIn = vm.parseJsonUintArray(json, ".sqrtPX96In");
        uint256[] memory amount0In = vm.parseJsonUintArray(json, ".amount0In");
        uint256[] memory expected = vm.parseJsonUintArray(json, ".expectedSqrtPriceX96");
        uint256 liquidity = vm.parseJsonUint(json, ".liquidity");
        assertEq(ticks.length, 723, "expected 723 rows");
        assertEq(sqrtPIn.length, 723);
        assertEq(amount0In.length, 723);
        assertEq(expected.length, 723);

        bool sawSanity;
        for (uint256 i = 0; i < ticks.length; i++) {
            uint256 actual = _next(uint160(sqrtPIn[i]), uint128(liquidity), amount0In[i], true);
            assertApproxEqRel(actual, expected[i], EPS);
            // sanity: tick 0, medium dx (1e17) -> post-trade price strictly below 2^96
            if (ticks[i] == 0 && amount0In[i] == 1e17) {
                assertLt(actual, TWO_96, "tick0 medium-dx post-trade price should be < 2^96");
                sawSanity = true;
            }
        }
        assertTrue(sawSanity, "sanity row (tick 0, dx=1e17) not found in fixture");
    }
}
```

- [ ] **Step 2: Compile-check if submodules are available, else skip with a note**

Run (build host only): `forge build --skip test 2>/dev/null; forge test --match-path test/gamsDiff/PriceImpactKernelPlank.diff.t.sol -vvv`
Expected (build host): PASS, 723 `assertApproxEqRel` checks within EPS, sanity row found.
In this worktree (submodules uninit): `forge` cannot resolve `v3`/`LibCall` — do NOT run; the committed test is the deliverable and forge verification is an external (build-host/CI) dependency per spec §10.

- [ ] **Step 3: Commit**

```bash
git add test/gamsDiff/PriceImpactKernelPlank.diff.t.sol
git commit -m "test(gamsDiff): diff GAMS priceImpact vs getNextSqrtPriceFromAmount0RoundingUp (assertApproxEqRel)"
```

---

## Self-Review

**Spec coverage:** §4 data flow → Tasks 3–5; §5.1 core → Task 2; §5.2 shell → Task 3; §5.3 CLI → Task 4; §6 fixture (flattened, transient-GDX gitignore) → Tasks 1, 4; §7 Foundry → Task 5; §8 TDD → Tasks 2–5; §9 sync prereqs (merge B1/M1, vendor harness, gitignore) → Task 1; §10 external forge verification → Task 5 Step 2; tolerance EPS=1e3, etaWeight assert, strict expected<sqrt_p, computed sanity index → Tasks 2/3/5. ✔

**Placeholder scan:** all steps carry runnable code/commands; no TBD/TODO. ✔

**Type consistency:** `ImpactRecord(tick, sqrt_p_x96, amount0_in, expected_sqrt_price_x96)`, `impact_records_to_fixture(..., liquidity, eta, gams_version, platform)`, `ImpactGrid(records, liquidity)`, `load_impact_records(*, model_workdir, sysdir)`, `main_impact`, selector `0x157f652f`, `EPS=1e3` — consistent across Tasks 2–5. Reused names (`to_sqrt_price_x96`, `tick_from_grid`, `to_json`, `write_fixture`, `_LABEL_RE`, `BALANCED_ETA`, `DEFAULT_MODEL_WORKDIR/DEFAULT_SYSDIR/DEFAULT_OUTPUT`) match the existing package. ✔
