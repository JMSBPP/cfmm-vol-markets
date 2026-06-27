# gamsdiff

Thin functional-core/imperative-shell layer that drives a read-only GAMS run of
`model/PricingKernel.gms`, reads the result via `gams.transfer`, and writes a
committed Q64.96 JSON fixture consumed by `test/gamsDiff/PricingKernelPlank.diff.t.sol`.

## Elasticity (eta) and the 1/2 constraint

`PricingKernel.gms` defines `tunablePricingKernel(s, t, e)`, a generalization of the
pricing kernel with a tunable weight `e` (the elasticity `eta = eta_x_y / unity`).
Only the balanced 50/50 pool, `eta = 1/2`, reduces to the fixed sqrt `priceKernel`
that equals the EVM `getSqrtRatioAtTick`. Therefore the differential fixture is
**pinned to `eta = 1/2`** (`core.BALANCED_ETA`, recorded in the fixture's `eta` /
`kernel` fields) — it is the only weight with an on-chain counterpart. `eta != 1/2`
yields an asymmetric bonding curve that can only be validated off-chain (out of scope
here). The Python reads the stored `priceKernel` symbol, which is exactly
`tunablePricingKernel` at `eta = 1/2`.

## Rules
- **Run everything through `uv run`** (never system Python).
- Never edits `.gms` sources; GAMS is driven read-only via the `gdx=` option.

## Usage
    uv run --project tools/gamsdiff gamsdiff
Regenerates `test/gamsDiff/fixtures/pricing_kernel.json`. Fixtures are platform-pinned.
