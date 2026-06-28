# Price-Impact Differential Gateway: GAMS priceImpact ↔ Plank PriceImpactKernelHarness

**Date:** 2026-06-28
**Status:** Draft — under review (two-step reviewer pass applied; peer coordination + external forge verification pending)
**Owner session:** gamsdiff track (worktree `../cfmm-wt/gamsdiff`, branch `feat/gamsdiff`)
**Target:** diff the GAMS price-impact kernel (post-trade sqrt price) against the Plank
`PriceImpactKernelHarness` (`getNextSqrtPriceFromAmount0RoundingUp`).

## 1. Purpose

Extend the gamsdiff middle layer with a second, focused differential gateway: a fixture
driver + Foundry diff test comparing the GAMS `priceImpact` reference (post-trade sqrt
price, η=1/2) against the on-chain Uniswap V3 `getNextSqrtPriceFromAmount0RoundingUp`
exposed by `PriceImpactKernelHarness.plk`. This is motivationally the building block beneath
the CES "long" payoff (`CESLongPayoff.plk`), but the diff is self-contained and does not
depend on it; the CES payoff diff is **deferred** until the GAMS agent materializes a payoff
reference (§9).

## 2. Established facts (verified — several by empirical reviewer runs)

- **GAMS macro** (`model/PricingKernel.gms:68`):
  `priceImpactKernel_Add0(sqrtP, L, dx) = L·sqrtP / (L + dx·sqrtP/2^96)` → Q64.96 post-trade
  sqrt price. Verified numerically equal to EVM `getNextSqrtPriceFromAmount0RoundingUp(add=true)`
  reduced: `(L·2^96·sqrtP)/(L·2^96 + dx·sqrtP)`. The `dx·sqrtP/2^96` asymmetry (L scaled by
  2^96, dx not) is load-bearing.
- **GAMS fixture driver** `model/PriceImpactKernelFixture.gms` computes
  `priceImpact('s1', tick, dxD) = priceImpactKernel_Add0(priceKernel('s1',tick), Lbar, dxVal(dxD))`
  over a 1×241×3 grid (723 rows) and `execute_unload`s 6 symbols to the **git-tracked**
  `model/price_impact_kernel.gdx` (which does NOT contain `priceKernel`).
- **Inputs** (`model/_PriceImpactKernelInputs.gms`): `Lbar = unity = 1e18`;
  `dxD = {small, medium, large}`, `dxVal = {1e15, 1e17, 1e18}`.
- **`gdx=` dumps all symbols (confirmed by reviewer run):** running the fixture driver with the
  `gdx=<file>` CLI option writes `priceKernel` (14460 records) **and** `priceImpact` (723) plus
  sets/scalars — independent of the `execute_unload`. So one read-only run yields inputs+outputs.
- **Plank harness** `test/gamsUtils/PriceImpactKernelHarness.plk`:
  `getNextSqrtPriceFromAmount0RoundingUp(uint160 sqrtPX96, uint128 liquidity, uint256 amount, bool add) returns (uint256)`,
  selector `0x157f652f`, calldata words at 4/36/68/100. `add=true` has no revert path on this
  grid; `add=false` overflow guards revert (irrelevant here).
- **Lossless input rounding (empirically verified, GRID-DEPENDENT):** on this grid every
  float64 `priceKernel` value is `> 2^52`, where doubles are integer-valued (spacing 2^43–2^44),
  so `round(priceKernel)` is **exactly** the float GAMS fed the macro — the EVM receives
  bit-identical input. Reviewer measured `max|round(p)−p| = 0` over all 241 ticks.
  **This holds ONLY for `sqrtP ≫ 2^52`** (true for tick ≳ −610000; this grid is −120..120). A
  future wide-tick fixture would enter the lossy regime and must re-derive its budget (§10).
- **Measured error & tolerance:** reviewer's GAMS-float-vs-exact-integer-EVM(round-up) diff over
  the full 241×3 grid: `max rel = 2.021e-16` (≈1 float64 ULP at 4e28), at tick 60 / `large`.
  Error budget (this grid): input quantization = **0** (lossless), EVM round-up bias ≤ ~2.5e-29
  rel (min priceImpact ~3.95e28), GAMS full-formula IEEE error ~2e-16 (empirical, 4-op macro).
  Total empirical floor ≈ **2.02e-16**.
- **Tolerance decision:** Foundry `EPS = 1e3` (= `1e-15` relative), matching the sister test
  `PricingKernelPlank.diff.t.sol:47` and giving ~5× headroom over the 2.02e-16 floor. (The GAMS
  spec's §D9 `1e-12` is a separate GAMS-internal cross-validation tolerance; the Foundry diff is
  held tighter for stronger regression detection — a ~1e-13/1e-14 bias would pass 1e-12 but is
  caught at 1e-15.)
- **Scales/casts:** `priceImpact`/`priceKernel` ~8e28 fit uint160 (≤~1.46e48); `Lbar=1e18` fits
  uint128; `dx≤1e18` fits uint256; `dx·sqrtP ≈ 8e46 ≪ 2^256`. Casts `uint160(sqrtP)`,
  `uint128(liquidity)` safe.
- **`foundry.toml`** already grants `fs_permissions` read for `./test/gamsDiff/fixtures`.
- **`vm.parseJsonUint(string,string)`** exists in vendored forge-std (confirmed) — primary path,
  no fallback needed.

## 3. Non-negotiable constraints

- **venv only** — every Python invocation via `uv run --project tools/gamsdiff`; never system Python.
- **Functional core / imperative shell** — pure transforms in `core.py`; GAMS execution + file
  I/O only in `shell.py`/`__main__.py`. Frozen dataclasses, full typing, no inheritance.
- **Minimal TDD** — pure logic written test-first with pytest.
- **Focused second path, minimal shared code** — reuse `to_sqrt_price_x96`, `tick_from_grid`,
  `to_json`; add price-impact-specific types/builder/loader. No config-driven framework.
- **Never edit `.gms` source** — GAMS driven read-only via `gdx=` (GAMS agent owns `model/*.gms`).
  Note: running the driver does rewrite the git-tracked `model/price_impact_kernel.gdx` and emits
  a transient all-symbols GDX — see §6/§10 (read-only applies to `.gms` sources, not the FS).
- **GAMS cwd MUST be `model/`** — `PriceImpactKernelFixture.gms` `$include`s resolve there.
- **Tolerance** — Foundry `EPS = 1e3` (= `1e-15` relative).
- **uint in JSON** — decimal strings; ticks as ints.

## 4. Architecture & data flow

```
model/PriceImpactKernelFixture.gms  ($includes PricingKernel.gms + _PriceImpactKernelInputs.gms)
   │  gamsapi: GamsWorkspace(working_directory=<repo>/model, system_directory=GAMS_SYS)
   │           .add_job_from_file("PriceImpactKernelFixture.gms").run(GamsOptions(gdx="<transient>.gdx"))
   ▼  (action=CE; gdx= dumps ALL symbols incl. priceKernel — no .gms edits)
<transient>.gdx   (git-ignored; NOT model/price_impact_kernel.gdx)
   │  gams.transfer: read priceImpact(s,t,dxD), priceKernel(s,t), Lbar, dxVal(dxD), etaWeight
   ▼
pure core: join priceKernel[tick] (sqrtP in) × dxVal[dxD] (amount in) → priceImpact[tick,dxD]
           (expected) → 723 ImpactRecord → round() → flattened JSON
   ▼
test/gamsDiff/fixtures/price_impact_kernel.json   (committed, platform-pinned)
   │  vm.readFile + vm.parseJsonIntArray + vm.parseJsonUintArray + vm.parseJsonUint
   ▼
PriceImpactKernelPlank.diff.t.sol → assertApproxEqRel(
       getNextSqrtPriceFromAmount0RoundingUp(sqrtPX96In[i], liquidity, amount0In[i], true),
       expected[i], EPS)        [runs on the build host / CI — see §10]
```

Run the fixture model fresh (not the committed GDX) because the committed GDX lacks
`priceKernel` (input sqrtP); the `gdx=` dump yields inputs+outputs in one read-only run, matching
the existing pricing-kernel driver pattern.

## 5. Python additions (`tools/gamsdiff/`)

### 5.1 Pure core (`core.py`) — append

- `@dataclass(frozen=True) ImpactRecord` — `tick: int`, `sqrt_p_x96: int`, `amount0_in: int`,
  `expected_sqrt_price_x96: int`.
- `impact_records_to_fixture(records, *, liquidity, eta, gams_version, platform) -> dict`
  builds the flattened schema in §6. Validates: `len(records) > 0`; all values `> 0`; and
  `expected < sqrt_p` **strictly** (a token0-input trade with `dx>0` must lower the price;
  `expected == sqrt_p` would signal a zero/overflowed-dx regression). Raises `ValueError` otherwise.
- Reuse `to_sqrt_price_x96` and `to_json`. (Document that `round()` is lossless here because all
  `sqrt_p`/`expected` exceed 2^52 — see §2; not true for a future wide-tick grid.)

### 5.2 Imperative shell (`shell.py`) — append

- `load_impact_records(*, model_workdir, sysdir) -> ImpactGrid` (a small frozen result carrying
  `records: tuple[ImpactRecord, ...]` and `liquidity: int`):
  - `GamsWorkspace(working_directory=model_workdir, system_directory=sysdir)`;
    `add_job_from_file("PriceImpactKernelFixture.gms")`; `run(GamsOptions(gdx=<transient>))`.
  - Read via `gams.transfer.Container`: `priceImpact` (filter `s1`), `priceKernel` (filter `s1`),
    `Lbar`, `dxVal`, `etaWeight`. Parse tick ordinal from label `k<n>` (never row position).
  - **Assert `etaWeight == 0.5`** from the GDX (guard against an η≠0.5 GDX silently mismatching a
    0.5-labelled fixture).
  - Join: for each tick `k<n>` and each dxD,
    `ImpactRecord(tick=tick_from_grid(n), sqrt_p_x96=round(priceKernel[s1,k_n]),
     amount0_in=round(dxVal[dxD]), expected_sqrt_price_x96=round(priceImpact[s1,k_n,dxD]))`.
  - Return 723 records sorted by `(tick, amount0_in)`, plus `liquidity = round(Lbar)`.
  - Loud failures: missing symbol, empty records, empty `s1` subset, unparseable label, η≠0.5.
- Reuse existing `write_fixture`.

### 5.3 CLI (`__main__.py`)

Add a second console entry `gamsdiff-impact` (pyproject `[project.scripts]`) →
`gamsdiff.__main__:main_impact`, wiring `load_impact_records` → `impact_records_to_fixture` →
`write_fixture` to `test/gamsDiff/fixtures/price_impact_kernel.json`. `eta=BALANCED_ETA`,
`gams_version="54.1.0"` (consistent with the existing pricing fixture's metadata). Existing
`gamsdiff` entry unchanged.

## 6. Fixture format

`test/gamsDiff/fixtures/price_impact_kernel.json`:

```json
{
  "symbol": "priceImpact",
  "source": "model/PriceImpactKernelFixture.gms",
  "scale": "Q64.96",
  "eta": 0.5,
  "add": true,
  "liquidity": "1000000000000000000",
  "gamsVersion": "54.1.0",
  "platform": "linux-x86_64",
  "count": 723,
  "ticks": [ -120, -120, -120, -119, ... ],
  "sqrtPX96In": [ "...", ... ],
  "amount0In": [ "1000000000000000", "100000000000000000", "1000000000000000000", ... ],
  "expectedSqrtPriceX96": [ "...", ... ]
}
```

- Four length-723 parallel arrays (`ticks` ints; rest decimal strings) + `liquidity` scalar
  (decimal string). `add=true` constant metadata. Flattened so the Solidity loop indexes directly.
- Platform-pinned (`gamsVersion`/`platform`); float64 low bits are platform-dependent, safe
  because `EPS` (1e-15) ≫ the ~2e-16 floor by ~5×.
- The transient all-symbols GDX from the driver run (`<transient>.gdx`, 14460+ rows) MUST be
  git-ignored (add the pattern to `.gitignore`); never commit it. The committed artifact is only
  the JSON fixture. (The driver run also rewrites the GAMS-owned, git-tracked
  `model/price_impact_kernel.gdx`; do not stage that change — it belongs to the GAMS branch.)

## 7. Foundry diff test (`test/gamsDiff/PriceImpactKernelPlank.diff.t.sol`)

Mirrors `PricingKernelPlank.diff.t.sol`:

1. `setUp()` deploys `test/gamsUtils/PriceImpactKernelHarness.plk` via `plankDeployFFI` (backend
   `"sona"`, dep `v3=lib/plankified-univ3/plank/lib`). Selector `0x157f652f`. **Requires the
   harness `.plk` to be present in this branch (§9 B1) and the submodules initialized (§9 M1).**
2. `_getNextSqrtPrice(uint160 sqrtP, uint128 L, uint256 amount, bool add) returns (uint256)`:
   `LibCall.staticCallContract` with `abi.encodeWithSelector(SEL, sqrtP, L, amount, add)`, decode
   `uint256`.
3. Read fixture: `vm.readFile` + `vm.parseJsonIntArray(json, ".ticks")` +
   `vm.parseJsonUintArray(json, ".sqrtPX96In"/".amount0In"/".expectedSqrtPriceX96")` +
   `vm.parseJsonUint(json, ".liquidity")`. Assert all array lengths == count == 723.
4. Loop: `actual = _getNextSqrtPrice(uint160(sqrtPX96In[i]), uint128(liquidity), amount0In[i], true);`
   `assertApproxEqRel(actual, expected[i], EPS);` with `EPS = 1e3` (= `1e-15` relative;
   `assertApproxEqRel`'s bound is 1e18-scaled, `1e-15·1e18 = 1e3`). `expected > 0` (§5.1) ⇒ no
   div-by-zero; round-up bias keeps `true ≤ actual < sqrtP`, within EPS.
5. Sanity guard: locate the tick-0 / `medium`-dx row by scanning for
   `ticks[i]==0 && amount0In[i]==1e17` (do NOT hardcode the index), assert `actual < 2^96` (a
   token0-input trade lowers the price) and `actual == expectedSqrtPriceX96[i]` within EPS.

## 8. TDD plan

- **Unit (pytest, pure core):** `impact_records_to_fixture` schema keys (incl. `eta`, `add`,
  `liquidity`, `count`), decimal-string encoding, lengths == count, flattening order, index 0 =
  smallest `(tick, amount)`; validation cases — empty records, non-positive value, and
  `expected >= sqrt_p` each raise.
- **Integration (one test, skips without GAMS):** run `load_impact_records` against real GAMS,
  assert 723 records, `etaWeight==0.5` enforced, and a known spot (tick 0 / medium dx) matches the
  committed GDX value within float tolerance.
- **Foundry:** `forge test --match-path test/gamsDiff/PriceImpactKernelPlank.diff.t.sol` — runs on
  the build host / CI only (see §10), NOT in this worktree.

## 9. Cross-session coordination & sync prerequisites (ordered, blocking the test)

1. **Sync GAMS sources (MINOR-5):** merge `feat/gams` (HEAD `0efde00`) into `feat/gamsdiff` so
   `PriceImpactKernelFixture.gms`, `_PriceImpactKernelInputs.gms`, the `priceImpactKernel_Add0`
   macro, and the committed GDX are present. Real merge (diverged at `4ed2dc5`); disjoint files
   except possibly `Makefile`. **Prerequisite before `gamsdiff-impact` can run.**
2. **Vendor the harness (B1 — BLOCKER):** `PriceImpactKernelHarness.plk` exists only on
   `feat/plank`, not in this branch (`test/gamsUtils/` here has only `PriceKernelHarness.plk`).
   `test/gamsUtils/` is regular committed content (not a submodule), and neither the `feat/gams`
   merge nor "submodule init" brings it. Obtain it from `feat/plank` (cherry-pick the file or
   copy+commit into `test/gamsUtils/`, mirroring how `PriceKernelHarness.plk` lives here) and
   coordinate with **`ul2inqpl`** so the two copies don't diverge (single source via `develop`
   later). **Prerequisite before the diff test can deploy.**
3. **Build-host prerequisites (M1 — MAJOR):** the Foundry test requires
   `git submodule update --init --recursive` for `plankified-univ3` (for `v3::math::sqrt_price_math`)
   and the `bunni-v2`/solady chain (for `LibCall`), plus `remappings.txt` mapping `bunni-v2=`,
   `plank-foundry-deployer=`, `v3=`. This worktree leaves submodules uninitialized by design, so
   the test runs only where they are initialized (build host / sol-tests worktree / CI).
4. **GAMS agent (`43wxo1px`) — deferred CES:** request a CES-payoff reference GDX symbol (e.g.
   `cesLongPayoff(s,t,dxD) = (P·Δ^I − Δ^O)²`) so a third focused fixture+test can diff against
   `CESLongPayoff.cesLongPayoff` (selector `0x1dbad771`). Not built here; no blocker for this gateway.

## 10. Verification status & out of scope

- **External verification dependency (MAJOR-3):** in this worktree only the **pytest layer**
  (fixture shape/validation) is checkable; `lib/forge-std`/`plankified-univ3` are uninitialized, so
  the GAMS↔EVM **equivalence** (the gateway's point) runs only on a host with submodules + plank +
  forge. The equivalence is currently corroborated by the reviewer's offline GAMS+EVM replica
  (max 2.02e-16) and the GAMS-side cross-check (`PriceImpactKernelTest.gms` property 3). The
  Foundry pass MUST be confirmed on such a host before the gateway is considered done.
- **Out of scope:** editing `.gms`/the GAMS model; the CES-payoff diff (deferred, §9.4);
  generalizing gamsdiff into a config-driven framework (explicitly chosen against); `add=false` /
  token1-input paths; mainnet fork testing.
- **Deferred wide-tick stress fixture (MAJOR-2):** any future fixture entering `sqrtP < 2^52`
  (tick ≲ −610000, within the EVM domain `MIN_TICK=-887272`) breaks the lossless-`round()`
  assumption and CANNOT inherit the `EPS=1e3`/2e-16 budget; it must re-derive tolerance with the
  input-quantization term included.

## 11. Open items to verify before locking implementation

- Confirm running `PriceImpactKernelFixture.gms` with `gdx=` yields `priceKernel` (2-D) + `priceImpact`
  in one run — RESOLVED by reviewer (both present; `execute_unload` file has neither extra).
- `vm.parseJsonUint(string,string)` — RESOLVED (present in vendored forge-std); use as primary, no
  fallback.
- On the build host: `uint160(sqrtPX96In[i])` round-trips Q96 values (max ~8e28 ≤ uint160 max) and
  the full 723-row forge test passes within `EPS=1e3`.
