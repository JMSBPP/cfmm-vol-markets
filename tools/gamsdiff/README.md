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
