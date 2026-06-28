# Price-Impact Kernel — GAMS reference (η=½) design

*Spec · 2026-06-28 · owner: GAMS-development agent (`43wxo1px`, worktree `cfmm-wt/gams`, branch `feat/gams`)*

## 1. Context

A new Plank harness has been added on the plank peer's track:

> `cfmm-wt/plank/test/gamsUtils/PriceImpactKernelHarness.plk` — exposes Uniswap V3's `getNextSqrtPriceFromAmount0RoundingUp(uint160 sqrtPX96, uint128 liquidity, uint256 amount, bool add) → uint256` as a single external entrypoint, selector `0x157f652f`.

It is a companion to the existing `PriceKernelHarness.plk` (which exposes `getSqrtRatioAtTick` and is already diff-tested against `priceKernel`). The differential-testing pipeline (gamsdiff peer `0hpyy1t4`) currently ships `model/pricing_kernel.gdx` → `test/gamsDiff/fixtures/pricing_kernel.json` → a Foundry `assertApproxEqRel` diff. This spec extends that pipeline with the **post-trade** sqrt price.

The formula to mirror (harness docstring, also `model/exp/eta.md` in both the gams and lean4-spec worktrees) — for the η=½ kernel, `add = true` direction (sell X for Y):

$$P_{1/2}(\Delta^I) \;=\; \frac{\bar L \cdot P_{1/2}(i)}{\bar L \;+\; \Delta^I \cdot P_{1/2}(i)}$$

with `sqrtP = P_{1/2}(i) = sqrtPX96`, `L̄ = liquidity`, `Δ^I = amount`. The η=½ kernel is `priceKernel(s, t)` already shipped in `model/PricingKernel.gms`.

## 2. Goal

Produce a GAMS reference value for the post-trade sqrt price over a fixed grid of `(sqrtP, L̄, Δ^I)` inputs, exported to GDX, so the gamsdiff peer can extend their existing CLI to emit a JSON fixture and write a Foundry diff test against `PriceImpactKernelHarness`.

## 3. Decisions (with rationale)

| # | Decision | Why |
|---|----------|-----|
| D1 | **Macro signature = literal η=½ mirror.** `priceImpactKernel(sqrtP, L, dx) = L · sqrtP / (L + dx · sqrtP)`. | The EVM harness covers only η=½. A tunable-η GAMS version has no on-chain counterpart to diff against. YAGNI. The η-CES generalization is *enabled* by the lean4-proven kernel-split identity (`CFMM.Eta.eta_split_kernel_identity`) but blocked on an η-CES EVM function. |
| D2 | **Implementation = GAMS `$macro`** (not a Parameter). | Takes its inputs by argument, so it composes with anything that produces a sqrtP (`priceKernel`, `tunablePricingKernel`, or a raw scalar). Avoids the `inventory`-set clash that prevents `PricingKernel` from `$include`ing `TradingRegion`. |
| D3 | **Input grid: 1 spacing × 241 ticks × 3 dx × 1 L̄ = 723 rows.** | Matches the existing `pricing_kernel.gdx` footprint (1 × 241). Single L̄ keeps the fixture small while the dx sweep covers the regimes of the formula. |
| D4 | **`L̄` = `1e18`**, fixed (from `dynamic/InitState.gms`'s canonical state). | Already the canonical value in the model; exactly representable in IEEE doubles. |
| D5 | **dx values = ratio sweep**: `L̄/1000`, `L̄/10`, `L̄` (i.e. `1e15`, `1e17`, `1e18`). | The formula's behavior is governed by the `dx/L̄` ratio — small / mid / full-`L̄` stresses the three regimes. All exactly representable in IEEE doubles (no input quantization vs. the EVM). |
| D6 | **GDX schema = single 3-D `Parameter` + the input scalars**: `priceImpact(s, t, dxD)`, plus `Lbar` scalar and `dxVal(dxD)`. | Mirrors the `pricing_kernel.gdx` shape (one canonical output parameter). The input metadata makes the GDX self-describing so the gamsdiff CLI can reconstruct calldata without out-of-band knowledge. |
| D7 | **Direction = `add = true` only.** | The harness reverts on `add = false` overflow guards — that's strict-revert territory in the EVM, not the GAMS reference's job. Diff only the happy path. |
| D8 | **Rounding = none (IEEE double).** | Uniswap rounds the division UP; GAMS computes in doubles. The existing pipeline already uses `assertApproxEqRel`, accepting this. Bit-exact integer match is out of scope and would belong on the gamsdiff peer's track (mulDiv emulation). |

## 4. Architecture (files affected)

```
model/
├── PricingKernel.gms                 EDIT: add `priceImpactKernel` $macro (1 line + comment)
├── PriceImpactKernelFixture.gms      NEW : grid driver, computes priceImpact, execute_unload to GDX
├── test/
│   └── PriceImpactKernelTest.gms     NEW : assert-only test for the macro (no diff)
└── price_impact_kernel.gdx           NEW : committed generated fixture
                                            (mirrors the committed pricing_kernel.gdx)
docs/superpowers/specs/
└── 2026-06-28-price-impact-kernel-gams-design.md   NEW : this spec
```

No `Makefile` change. `make test-gams` auto-discovers `model/test/*.gms`. The fixture driver `PriceImpactKernelFixture.gms` is **not** under `test/` (it's a generator, not an assertion test) and is invoked by the gamsdiff peer's CLI / `make gams-fixtures` target.

## 5. The macro

```gams
* priceImpactKernel(sqrtP, L, dx): post-trade sqrt price for the η = 1/2 kernel,
* selling X for Y (Uniswap V3 add=true direction). Mirrors
* v3::math::sqrt_price_math::getNextSqrtPriceFromAmount0RoundingUp(P, L, dx, true)
* exposed by PriceImpactKernelHarness.plk. Algebraic identity (harness docstring;
* derivation in model/exp/eta.md):
*     P_{1/2}(Δ^I) = (L · P) / (L + Δ^I · P)
* The three operands enter the EVM at their on-chain scale (P in Q64.96, L raw,
* dx raw); the formula is a pure ratio, so scales cancel. Uniswap rounds the
* division UP; GAMS uses IEEE doubles — diff uses assertApproxEqRel.
* TODO(eta-CES): a tunablePriceImpactKernel(sqrtP, L, dx, e) is reachable via
* the lean4-proven kernel-split identity (CFMM.Eta.eta_split_kernel_identity),
* but is blocked on an η-CES post-trade EVM function existing to diff against.
$macro priceImpactKernel(sqrtP, L, dx) ( (L) * (sqrtP) / ( (L) + (dx) * (sqrtP) ) )
```

Composes as `priceImpactKernel(priceKernel(s, t), Lbar, dxVal('large'))` — `sqrtP` is sourced from `priceKernel` (or, in a future tunable-η experiment, `tunablePricingKernel`).

## 6. Fixture driver — `model/PriceImpactKernelFixture.gms`

```gams
$include PricingKernel.gms                     * priceKernel, priceImpactKernel, lambda, unity, ticks

Scalar Lbar; Lbar = power(10, 18);             * canonical L̄ from dynamic/InitState.gms
Set    dxD  / small, medium, large /;
Parameter dxVal(dxD);
dxVal('small')  = Lbar / 1000;                 * 1e15
dxVal('medium') = Lbar /   10;                 * 1e17
dxVal('large')  = Lbar;                        * 1e18

* Restrict to s1 to mirror the existing pricing_kernel.gdx footprint (1 × 241).
Set sFix(tickSpacingDomain) / s1 /;

Parameter priceImpact(sFix, tick, dxD);
priceImpact(sFix, tick, dxD) =
    priceImpactKernel( priceKernel(sFix, tick), Lbar, dxVal(dxD) );

execute_unload 'price_impact_kernel.gdx', priceImpact, Lbar, dxVal;
```

**Resulting GDX:**
- `priceImpact(s, t, dxD)` — 1 × 241 × 3 = **723 rows**, the post-trade `sqrtPX96`.
- `Lbar` scalar — the fixed liquidity used.
- `dxVal(dxD)` — the three dx values keyed by label.

## 7. Test — `model/test/PriceImpactKernelTest.gms`

Runs under `make test-gams` (action=ce so `abort` fires). Three properties asserted across the full grid; **no diff against the EVM in this test** — that lives in the Solidity diff (gamsdiff track).

1. **Zero-input no-op:** for every `(s, t)`, `priceImpactKernel(priceKernel(s, t), Lbar, 0) == priceKernel(s, t)` exactly. Called with a literal `0` for `dx` (the fixture's `dxD` grid does **not** include zero — it spans `{L̄/1000, L̄/10, L̄}` to stress non-trivial impact).
2. **Monotone in `dx`:** `priceImpact(s, t, 'small') > priceImpact(s, t, 'medium') > priceImpact(s, t, 'large')` for all `(s, t)`. Captures the swap-direction sign.
3. **Algebraic identity (sanity):** `priceImpactKernel(P, L, dx) · (L + dx · P) ≈ L · P` within relative tolerance `1e-12`. Re-derives the formula end-to-end as a cross-check against typo bugs in the macro body.

## 8. Handoff to the gamsdiff peer (`0hpyy1t4`)

Strictly out of my scope — listed here to make the contract explicit:

- Extend `tools/gamsdiff/` to read `model/price_impact_kernel.gdx` and emit `test/gamsDiff/fixtures/price_impact_kernel.json` with a forge-friendly schema (analogous to `pricing_kernel.json`).
- Add a Foundry diff test that loads the JSON, calls `PriceImpactKernelHarness.getNextSqrtPriceFromAmount0RoundingUp(sqrtPX96, Lbar, dx, true)`, and `assertApproxEqRel`s against the GAMS reference value at a peer-chosen tolerance.
- Extend `make gams-fixtures` (already owned by the gamsdiff CLI) to invoke `PriceImpactKernelFixture.gms` so the committed GDX is regeneratable.

I will ping `0hpyy1t4` via `claude-peers send_message` after PR-ing this branch, so they know the GDX schema is available and the handoff is unblocked.

## 9. Out of scope (explicit YAGNI)

- **Tunable-η post-trade form.** No EVM counterpart exists; the lean4 kernel-split identity opens a path but the actual on-chain function would need to be written first. Captured only as a `TODO(eta-CES)` comment on the macro.
- **`add = false` direction.** Harness reverts on overflow guards; not exercised in the diff.
- **Multi-`L̄` or multi-`tickSpacing` sweeps.** Deferred until the single-axis sweep produces clean diffs and the gamsdiff peer has a JSON+forge pipeline that handles the 3-D shape.
- **`getNextSqrtPriceFromAmount1*` (token1-input) and `getAmount0/1Delta*` (delta amount).** Distinct harnesses; each gets its own spec when its harness lands.
- **Bit-exact integer match to the EVM `mulDivRoundingUp`.** The pipeline's accepted contract is `assertApproxEqRel`; emulating Uniswap's UP rounding in GAMS doubles is gamsdiff-side concern if ever needed.

## 10. Success criteria

- `model/PricingKernel.gms` defines `priceImpactKernel` and `make compile-gams` stays green (still 6 ok). `make test-gams` discovers and passes the new `PriceImpactKernelTest.gms` — final report is **2 test files passed** (the existing `PricingKernelTest.gms` for tunable-eta + the new `PriceImpactKernelTest.gms`), covering **4 asserted properties total** (the existing tunable-eta equivalence + the 3 new properties in §7).
- `model/PriceImpactKernelFixture.gms` runs under `gams … action=ce` with exit 0 and produces a deterministic `model/price_impact_kernel.gdx` (committed).
- The GDX, opened with `gdxdump`, contains `priceImpact`, `Lbar`, `dxVal` symbols with the documented shapes and row count (723).
- `0hpyy1t4` has been notified via `claude-peers send_message` with the GDX path, schema, and a one-line handoff summary.

## 11. References

- Plank harness: `cfmm-wt/plank/test/gamsUtils/PriceImpactKernelHarness.plk` (this branch).
- Sister harness already diff-tested: `cfmm-wt/plank/test/gamsUtils/PriceKernelHarness.plk`.
- Uniswap V3 reference: `lib/plankified-univ3/plank/lib/math/sqrt_price_math.plk` (`getNextSqrtPriceFromAmount0RoundingUp`).
- Spec layer (math): `model/exp/eta.md` (gams worktree, brief) and the more developed copy on the lean4-spec worktree (`CFMM.Eta.eta_split_kernel_identity`, proven via Aristotle).
- Existing differential-testing pattern: `cfmm-wt/gamsdiff/tools/gamsdiff/`, `cfmm-wt/gamsdiff/model/pricing_kernel.gdx`, `cfmm-wt/gamsdiff/test/gamsDiff/fixtures/pricing_kernel.json`.
- This GAMS track's scope memory: `gams-agent-scope.md`.
