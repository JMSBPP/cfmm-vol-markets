# GAMS → Solidity Differential Testing: Python Middle Layer

**Date:** 2026-06-27
**Status:** Draft — under review (two-step reviewer pass applied; pending peer coordination, see §13)
**Owner session:** GAMS↔Solidity differential testing (PID 299098; agent in `claude-peers`)
**First vertical slice:** `model/PricingKernel.gms` vs `test/gamsUtils/PriceKernelHarness.plk`
via `test/gamsDiff/PricingKernelPlank.diff.t.sol`

## 1. Purpose

Build a thin, progressive Python "middle layer" that brings GAMS model output into
Foundry differential tests. The layer extracts a GAMS-computed reference quantity,
serializes it to a committed JSON fixture, and a Foundry test asserts the on-chain
Solidity implementation matches the reference within a relative tolerance.

The first slice diffs the GAMS pricing kernel's `tick → sqrtPriceX96` mapping
against Uniswap V3's `getSqrtRatioAtTick` exposed through `PriceKernelHarness.plk`.

### Non-negotiable constraints

- **venv isolation.** Everything Python runs inside an isolated virtual environment
  managed by **uv**. No invocation may use system Python. Every entry point is
  `uv run` against the project venv.
- **Minimal TDD.** Pure logic is written test-first with `pytest`.
- **Functional programming.** Functional core / imperative shell. Pure functions for
  all transforms; side effects (GAMS execution, file I/O) confined to the edges.
  Frozen dataclasses, no inheritance, full typing.
- **Very thin, minimal API.** Public surface is one CLI entry point plus a handful
  of importable pure functions. No framework, no plugin system, no config sprawl.

## 2. Established facts (verified by review)

- No Python exists in the repo root yet — greenfield.
- GAMS 54.1 at `/usr/gams/gams54.1_linux_x64_64_sfx/gams`. `gamsapi[transfer]` ships
  with the install and is `pip install`-able into the venv. Research notes:
  `.agents/gams/research/REPORT.md`.
- `foundry.toml` has `ffi = true` but **no `fs_permissions`** — `vm.readFile` is
  blocked until that is added (see §6, §13). Vendored forge-std is **v1.16.1**.
- `model/PricingKernel.gms` already emits the EVM number format:
  ```gams
  priceKernel(s,tick) = (lambda/unity) ** (tickVal(tick) * tickSpacingVal(s) / 2) * power(2, 96);
  ```
  This equals the EVM Q64.96 sqrt price `sqrt(1.0001^(tick·spacing)) · 2^96`.
  `lambda/unity = 1.0001` exactly; `tickVal(tick) = ord(tick) − 121 ∈ [−120, 120]`
  for `k1*k241`; `tickSpacingVal(s) = ord(s)` (so `s1 → 1`). `PricingKernel.gms` has
  **no `Model`/`Solve`** — pure parameter assignment, so `action=CE` needs no solver
  license.
- `getSqrtRatioAtTick` (`lib/plankified-univ3/.../tick_math.plk`) returns
  `sqrt(1.0001^tick) · 2^96` as a Q64.96 integer; valid range `|tick| ≤ 887272`;
  it is an exact-integer **approximation** (precomputed bit constants, ≈1 ULP error).
  The −120…120 range sits well inside `[MIN_SQRT_RATIO, MAX_SQRT_RATIO]`, so no
  callee revert.
- **Error budget (verified):** the GAMS float64 reference is quantized to the float64
  ULP near 2^96 (≈ 2^44 ≈ 1.76e13 absolute → relative ≈ 2^−52 ≈ **2.2e-16**). The
  EVM algorithm error is ~1 ULP at Q96 (relative ~1e-29), negligible. So the diff's
  dominant discrepancy is float64 (~2.2e-16); a *wrong* formula yields relError ~1e18.
  The test is therefore neither trivially-passing nor impossible-to-pass.

## 3. Architecture & data flow

```
model/PricingKernel.gms   ($include primitives.gms — MUST run with cwd = model/)
   │  gamsapi: GamsWorkspace(working_directory=<repo>/model, system_directory=GAMS_SYS)
   │           .add_job_from_file("PricingKernel.gms").run(GamsOptions(gdx="pricing_kernel.gdx"))
   ▼  (executes action=CE, writes pricing_kernel.gdx; no .gms edits)
model/pricing_kernel.gdx
   │  gams.transfer.Container("model/pricing_kernel.gdx") → pandas records for `priceKernel`
   ▼
pure core: records → KernelPoint[] → round() → JSON
   ▼
test/gamsDiff/fixtures/pricing_kernel.json   (committed, platform-pinned artifact)
   │  vm.readFile + vm.parseJsonIntArray(json, ".ticks") + vm.parseJsonUintArray(json, ".expectedSqrtPriceX96")
   ▼
PricingKernelPlank.diff.t.sol → assertApproxEqRel(getSqrtRatioAtTick(tick), expected, EPS)
```

The Python layer's responsibility ends at the JSON fixture. **Foundry owns pass/fail.**
Because the fixture is committed, `forge test` runs in CI with neither GAMS nor Python
present.

### GAMS execution boundary

The layer **drives a read-only GAMS run** through `gamsapi` and **never edits any
`.gms` source**. The model is unloaded to GDX via the `gdx=` GAMS option (not via a
`.gms` `execute_unload`), so the model file is untouched. This stays within this
session's "consume GAMS output" charter while keeping the pipeline self-contained.
Recorded in `CLAUDE.md`; read-only execution acknowledged by the GAMS-dev session
(§13).

## 4. Python package `tools/gamsdiff/`

Layout (functional core / imperative shell):

```
tools/gamsdiff/
├── pyproject.toml          # uv project; deps: gamsapi[transfer]==54.1.*, pandas
├── uv.lock                 # committed
├── README.md               # how to run; venv rules
├── gamsdiff/
│   ├── __init__.py
│   ├── core.py             # PURE — no I/O (TDD target)
│   ├── shell.py            # EFFECTS — gamsapi run + transfer read + file write
│   └── __main__.py         # CLI wiring (uv run gamsdiff)
└── tests/
    ├── test_core.py        # unit tests for pure functions
    └── test_shell.py       # one integration test, skips without GAMS
```

### 4.1 Pure core (`core.py`)

Zero I/O. Fully unit-testable with plain values.

- `@dataclass(frozen=True) GridRecord` — `tick_index: int` (GAMS **1-based ordinal**,
  i.e. `n` from label `k<n>`), `value: float`. Decouples the core from pandas.
- `@dataclass(frozen=True) KernelPoint` — `tick: int`, `expected_sqrt_price_x96: int`.
- `to_sqrt_price_x96(value: float) -> int` — returns `round(value)`. The GAMS value is
  already Q96-scaled, so this only rounds the float64. NOTE: above 2^52 the float64 is
  already integer-valued (granularity 2^44), so `round()` is effectively a no-op on
  real data and the reference is inherently quantized to 2^44 — it is **not** exact
  integer ground truth. Python `round()` is banker's rounding; the helper test
  documents this (§7).
- `tick_from_grid(tick_index: int, spacing: int = 1) -> int` — returns
  `(tick_index − 121) * spacing`. `tick_index` is the GAMS 1-based ordinal (never a
  pandas positional index). `spacing` is the GAMS `ord(s)` value (the multiplier), not
  a label index. Single source of truth for the GAMS-grid → int24 mapping, derived
  from `T = tickVal · spacing`.
- `records_to_points(rows, spacing: int = 1) -> tuple[KernelPoint, ...]` — pure
  transform. Validates `value > 0`; raises `ValueError` otherwise.
- `points_to_fixture(points, *, symbol, source, spacing, gams_version, platform) -> dict`
  and `to_json(fixture: dict) -> str` — serialize to the §5 schema. uint256 values are
  emitted as decimal strings (verified to coerce on forge-std v1.16.1).

### 4.2 Imperative shell (`shell.py`)

The only side effects in the package.

- `load_grid_records(*, model_workdir, sysdir, model_file="PricingKernel.gms", gdx_name="pricing_kernel.gdx", symbol="priceKernel", spacing_index=1) -> tuple[GridRecord, ...]`:
  - **MUST** construct `GamsWorkspace(working_directory=model_workdir, system_directory=sysdir)`
    where `model_workdir` is the repo's `model/` dir — required so `$include
    primitives.gms` (`PricingKernel.gms:1`) resolves (BUILD.md mandates cwd=`model/`).
  - `job = ws.add_job_from_file(model_file)`; `job.run(GamsOptions(ws, gdx=gdx_name))`
    (executes + writes the GDX). Raise with an actionable message on non-zero status.
  - Read with `gams.transfer.Container(<model_workdir>/<gdx_name>)`; pull the
    `symbol` records DataFrame; **derive `tick_index` from the GAMS set label `k<n>`**
    (parse the integer suffix), never the DataFrame row position; filter to the
    selected `spacing_index` (v1: `s1`); return plain `GridRecord` values.
  - Capture the GAMS version (from the workspace / system) and OS string to pass into
    the fixture metadata for platform-pinning (§5, M-reproducibility).
- `write_fixture(path: str, text: str) -> None` — writes the JSON file.

### 4.3 CLI (`__main__.py`)

~15 lines wiring shell → core → shell:

```
records = load_grid_records(...)                 # effect
points  = records_to_points(records, spacing=1)  # pure
text    = to_json(points_to_fixture(...))        # pure
write_fixture(out_path, text)                    # effect
```

Defaults target the v1 slice (`PricingKernel.gms`, symbol `priceKernel`, spacing `s1`,
output `test/gamsDiff/fixtures/pricing_kernel.json`). `GAMS_SYS` defaults to the
BUILD.md path; `model_workdir` defaults to `<repo>/model`. Both overridable by env/flag.

### 4.4 Public API

The entire surface is:
- CLI: `uv run gamsdiff` (regenerates the fixture).
- Importable pure functions: `to_sqrt_price_x96`, `tick_from_grid`,
  `records_to_points`, `points_to_fixture`, `to_json`, and the `KernelPoint` /
  `GridRecord` dataclasses.

## 5. Fixture format

`test/gamsDiff/fixtures/pricing_kernel.json`:

```json
{
  "symbol": "priceKernel",
  "source": "model/PricingKernel.gms",
  "scale": "Q64.96",
  "spacing": 1,
  "gamsVersion": "54.1.0",
  "platform": "linux-x86_64",
  "count": 241,
  "ticks": [-120, -119, ...],
  "expectedSqrtPriceX96": ["78754240422857016427656773632", "..."]
}
```

- Index 0 corresponds to tick −120, whose value is `78754240422857016427656773632`
  (tick 0 would be `2^96 = 79228162514264337593543950336`).
- `ticks`: int array, read with `vm.parseJsonIntArray(json, ".ticks")`.
- `expectedSqrtPriceX96`: decimal-string array, read with
  `vm.parseJsonUintArray(json, ".expectedSqrtPriceX96")` (decimal strings verified to
  coerce on the vendored forge-std v1.16.1).
- Parallel arrays (not array-of-structs) avoid Foundry JSON struct-decoding pitfalls.
- `gamsVersion`/`platform` make the fixture **platform-pinned**: because `priceKernel`
  uses the real-power operator `**` (libm `exp/log`), low bits of ~half the values are
  platform/GAMS-version dependent and the fixture is *not* byte-reproducible across
  hosts. This is safe because `EPS` (§6) is ~3 orders of magnitude above the float64
  noise floor; any future byte-equality check must key on `gamsVersion`+`platform`.

## 6. Solidity side (`test/gamsDiff/PricingKernelPlank.diff.t.sol`)

Extends the existing `setUp()` (which deploys the harness via `plankDeployFFI`, backend
`"sona"`). Adds:

1. **Prerequisite:** `foundry.toml` must grant read access (owned by the Plank session
   — coordination in §13):
   ```toml
   fs_permissions = [{ access = "read", path = "./test/gamsDiff/fixtures" }]
   ```
   Without it `vm.readFile` reverts before any assertion.
2. Read the fixture once, then index with `.key` (two-arg cheatcodes; forge-std ≥ 1.16.1):
   ```solidity
   string memory json = vm.readFile("test/gamsDiff/fixtures/pricing_kernel.json");
   int256[]  memory ticks    = vm.parseJsonIntArray(json, ".ticks");
   uint256[] memory expected = vm.parseJsonUintArray(json, ".expectedSqrtPriceX96");
   assertEq(ticks.length, expected.length);
   ```
3. Loop: `uint256 actual = _getSqrtRatioAtTick(int24(ticks[i]));`
   `assertApproxEqRel(actual, expected[i], EPS);` — `assertApproxEqRel` uses
   `stdMath.percentDelta` internally, which handles the unsigned absolute difference
   (no hand-rolled `abs` underflow), guards div-by-zero, and prints `% Delta` vs
   `Max % Delta` on failure. Do **not** hand-roll `abs(a−e)*1e18/e`.
4. `EPS = 1e3` (i.e. `1e-15` relative, since `assertApproxEqRel` uses a 1e18-scaled
   bound). Rationale comment in code: float64 noise floor ≈ 2.2e-16, so 1e-15 gives
   ~4× headroom while remaining a *meaningful* precision check (1e-12 would be ~4500×
   looser than the floor and only catches gross errors). Record the observed max
   `% Delta` in a comment after the first green run; loosen to 1e-14 only if libm
   cross-platform drift proves it flaky, with justification.
5. **Sign-extension regression guard:** assert the two endpoints straddle 2^96 to pin
   correct `int24` two's-complement handling, e.g.
   `assertLt(_getSqrtRatioAtTick(-120), 1<<96)` and
   `assertGt(_getSqrtRatioAtTick(120), 1<<96)`.

`int24` handling: `parseJsonIntArray` returns `int256[]`; `int24(ticks[i])` is safe for
−120…120. The harness forwards the sign-extended 32-byte word and uses `@evm_slt`/`-tick`,
which is correct for negatives (verified). Overflow headroom: `actual·1e18` at v1 max
(`~8e28·1e18 = 8e46`) and even at full-range `MAX_SQRT_RATIO·1e18 ≈ 1.46e66` stays
under `2^256 ≈ 1.16e77`; safe for the §10 generalization. (Re-check only if WAD scale
is ever raised to ≥1e27.)

This file lives under `test/gamsDiff/`, the *differential comparison layer*. Note
`test/` is broadly owned by the Solidity-testing session — coordination in §13.

## 7. TDD plan

Write tests before implementation.

**Unit (`pytest`, pure core — runs with no GAMS, no EVM):**
- `to_sqrt_price_x96`: exercises the helper contract in isolation (golden value +
  banker's-rounding boundary, e.g. assert `round(2.5)==2` per Python semantics). Note
  it is a no-op on real Q96-scale data; this test covers the function, not the data path.
- `tick_from_grid`: mapping table `tick_index ∈ {1, 121, 241} → {−120, 0, 120}`, plus a
  `spacing = 2` case (`tick_index=241 → 240`).
- `records_to_points`: synthetic records → expected `KernelPoint` tuple; `value ≤ 0`
  raises `ValueError`; verifies `tick_index` is treated as the GAMS ordinal.
- `to_json` / `points_to_fixture`: schema keys present (incl. `gamsVersion`, `platform`,
  `scale`), uint values are decimal strings, array lengths equal `count`, index 0 maps
  to tick −120.

**Integration (one test, `test_shell.py`):** runs real GAMS via `gamsapi` from
`model/`, asserts a non-empty fixture with 241 ticks matching the schema. Auto-skips
when `gams`/`GAMS_SYS` unavailable, so the unit suite stays portable.

**Foundry:** `forge test --match-path test/gamsDiff/PricingKernelPlank.diff.t.sol`
over the committed fixture.

## 8. Error handling

- **Shell (loud failures):** missing `GAMS_SYS`/`gams`; `GamsJob` non-zero status;
  `$include` resolution failure (wrong cwd); symbol absent from the GDX; empty record
  set for the requested spacing; GDX file not written.
- **Pure core:** non-positive values, array-length mismatches, non-integer/garbage tick
  labels → typed exceptions with actionable messages. No silent fallbacks.

## 9. Makefile + venv integration

- `make gams-fixtures` → `uv run --project tools/gamsdiff gamsdiff` (regenerates and
  overwrites the committed fixture).
- Hard rule, documented in `tools/gamsdiff/README.md`: every Python invocation goes
  through `uv run` against the project venv — never system Python.
- Regenerated fixtures are committed so `forge test` needs neither GAMS nor Python.
  Fixtures are platform-pinned (§5); regeneration on a different host changes low bits
  but stays within `EPS`.

## 10. v1 scope ("progressive") and what generalizes

**v1 (this slice):** pin `tickSpacing = 1` (the `s1` slice), emit the 1-D `k1*k241`
tick vector (241 points, ticks −120 … 120), one fixture, one diff test green.

**Generalizes later behind the same pure functions, not in v1:**
- 2-D `(spacing × tick)` grid (`s1*s60`) — `records_to_points`/`tick_from_grid` already
  parameterize `spacing` (passing the GAMS `ord(s)` value). Effective tick reaches
  ±7200, still far inside the overflow ceiling.
- Additional GAMS symbols / kernels — same shell+core shape, new fixture + diff test.

## 11. Implementation ordering & assumptions to verify (first steps)

1. **Execute-mode smoke test FIRST** (before building the package): drive
   `gamsapi`/`GamsJob.run` on `PricingKernel.gms` from `model/` with `gdx=` and confirm
   it exits 0 and `gams.transfer` reads `priceKernel`. Record the exit code and a
   sample value (tick 0 must equal `79228162514264337593543950336`). This repo has
   only ever run `action=c` (compile) — execute mode is unproven here.
2. Confirm `gamsapi` PyPI version is compatible with the local GAMS 54.1
   `system_directory`; pin `gamsapi==54.1.*` in `pyproject.toml`.
3. Confirm `vm.parseJsonUintArray` coerces the decimal strings on the vendored
   forge-std v1.16.1 (reviewer-verified; re-check if forge-std is bumped). Fallback:
   emit `0x…` hex strings.
4. Cross-check `T = tickVal · spacing` against `model/spec/pricingKernel.md` (the
   equivalence is already stated in `PricingKernel.gms`, so this is confirmation).

## 12. Out of scope

- Editing any `.gms` source (GAMS-dev session, PID 175812).
- The broader `test/` Foundry suite beyond `test/gamsDiff/` (Solidity-testing, PID 284909).
- Production Solidity under `src/`, deploy scripts, Plank `.plk` compiler work
  (Plank session, `ul2inqpl`).
- Lean4 proofs and `model/spec/*.md` math authoring (Lean4 + Math session).
- High-precision (mpmath) reference recomputation — relative tolerance against the
  GAMS float64 is sufficient for v1.

## 13. Cross-session coordination (prerequisite to execution)

This spec touches files owned by other instances per project `CLAUDE.md`. Before
implementation:

- **Plank session (`ul2inqpl`)** — owns `foundry.toml`. Needs the `fs_permissions`
  read entry (§6.1) added, OR delegated to this session. **Blocking.**
- **Solidity-testing session (PID 284909 / `e0q9pae8`)** — broadly owns `test/`. Confirm
  it cedes `test/gamsDiff/` (the differential layer) to this session. **Blocking.**
- **GAMS-dev session (PID 175812 / `43wxo1px`)** — owns `.gms` + compilation. Confirm
  read-only `gamsapi` execution of `PricingKernel.gms` (no source edits) is acceptable.
- Ensure this session (PID 299098) is present in the `CLAUDE.md` ownership map.

Resolution of these is tracked before the artifact is treated as ready to execute.
