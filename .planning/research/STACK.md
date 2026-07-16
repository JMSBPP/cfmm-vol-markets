# Stack Research

**Domain:** EVM fixed-point vault module (Plank) — collateral→vega-exposure issuance, H1 exogenous risk price
**Researched:** 2026-07-16
**Confidence:** HIGH (every in-repo claim below was grepped/read, not assumed)

## Headline finding

**No new dependencies are required.** The one non-trivial primitive the vault needs — a
full-precision 512-bit `mulDiv(a·b/c)` — **already exists in-repo, already wired into the test
harness's module roots, and is a faithful port of Uniswap's `FullMath.mulDiv`.** The vault is a
composition problem over primitives the toolchain already ships, not a stack-expansion problem.

---

## Recommended Stack

### Core Technologies (all already present — this is a "use what's here" milestone)

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| Plank compiler `plank` | v0.1.1, backend `sona` | Compile `VegaAccountMod.plk` → EVM bytecode via FFI at test time | Pinned project toolchain; identical path already proven by `RealizedVolatilityMod` |
| `plank-foundry-deployer` | in-repo (`lib/plank-foundry-deployer`) | `deployPlank(path)` → `plankDeployFFI` → `plankBuildFFI` shells `plank build` at test time | The vault's selector-dispatch module deploys through the exact same `PlankTestBase.deployPlank` used by the vol oracle |
| Foundry (forge) | `--via-ir --optimize` defaulted | Solidity glue + differential fuzz harness | Established test discipline; `ffi = true` already set in `foundry.toml` |

### Supporting Libraries (the load-bearing find)

| Library | Version / path | Purpose | When to Use |
|---------|----------------|---------|-------------|
| **Plank `v3::math::full_math`** | `lib/plankified-univ3/plank/lib/math/full_math.plk` | `mulDiv(a,b,denominator) u256` + `mulDivRoundingUp(...)` — **512-bit full-precision, floor** | Import directly for `p_risk = mulDiv(oracle, 2^96, 2^96 − hX96)` and `shares = mulDiv(deposit, 2^96, p_risk)`. This is the whole answer to question (1). |
| solady `FixedPointMathLib` | `solady/` remap → `lib/panoptic-v2-core/lib/solady/src/utils/FixedPointMathLib.sol` (also at `lib/bunni-v2/lib/solady/...`) | `fullMulDiv(x,y,d)` / `fullMulDivUp` / `mulDiv` — trusted Solidity 512-bit floor primitive | The **primitive inside the hand-rolled Solidity reference mock** the vault's fuzz properties diff against (question 2) |
| Uniswap `FullMath` | `lib/v3-core/contracts/libraries/FullMath.sol` + original `lib/plankified-univ3/contracts/libraries/FullMath.sol` | Gold-standard `mulDiv`/`mulDivRoundingUp` | Second diff layer: prove the Plank port is bit-exact to the Solidity source it was ported from (revert edges included) |

### Development Tools

| Tool | Purpose | Notes |
|------|---------|-------|
| `PlankTestBase.plankOpts()` | Declares the six Plank module roots | `test/PlankTestBase.sol:26` already maps `Dependency("v3", "lib/plankified-univ3/plank/lib")` — so `import v3::math::full_math::{mulDiv, ...}` resolves with **zero config change**. Kept in lockstep with `Makefile:PLANK_DEP` (line 110). |
| `Makefile:PLANK_SKIP` | Rescue queue | `VegaAccountMod.plk` is the sole entry (line 127); leaves the queue only when its dispatch is *called* green, per PROJECT.md |

## Installation

```bash
# NONE. No npm install, no forge install, no git submodule add.
# The 512-bit mulDiv, the solady reference primitive, and the Uniswap FullMath
# gold standard are all already in lib/. package-lock.json is unchanged.
```

## The exact primitive (question 1 — verbatim from the repo)

`lib/plankified-univ3/plank/lib/math/full_math.plk`:

```
const mulDiv = fn (a: u256, b: u256, denominator: u256) u256 { ... }        // 512-bit, floor
const mulDivRoundingUp = fn (a: u256, b: u256, denominator: u256) u256 { ... }
```

This is a line-for-line port of Uniswap's `FullMath.mulDiv` (Remco Bloemen algorithm):
`prod1` via `@evm_mulmod(a,b,@evm_not(0))`, remainder subtraction, powers-of-two factoring,
and the 6-iteration Newton–Raphson modular inverse. It handles the intermediate `a·b` overflow
the vault genuinely hits — `deposit · 2^96` and `oracle · 2^96` both exceed 256 bits for realistic
inputs — so this routine is **required, not optional**, and it is present. `plankified-univ3`
also ships an ABI harness for it (`plank/test/FullMathTest.plk`, selectors `0xaa9a0912` /
`0x0af8b27f`), a ready template for a Plank-side mulDiv diff harness if wanted.

## Reference-mock recommendation (question 2)

Use a **two-layer diff**, not a single one:

1. **Vault logic layer (primary).** A hand-rolled Solidity mock that mirrors the Lean pseudocode
   from `RISK_ALTERNATIVES.md` / `RiskDesign.lean` — `p_risk = oracle/(1−h)` (H1), `shares =
   mulDiv(deposit, 2^96, p_risk)` floor, and the **division-free** admissibility guard (Lean
   `deltaShares_admissible_iff` collapses it to `ΔQ_M ≤ Q_M^Σ`, a plain comparison — no mulDiv in
   the guard). This mock composes **solady `FixedPointMathLib.fullMulDiv`** as its trusted mulDiv.
   Diff Plank ↔ this mock at tolerance 0, one fuzz property per Lean lemma
   (`mulX96Down_le/one`, `issuance_haircut_equiv`, `haircutRiskPrice_ge_oracle`,
   `deltaShares_admissible_iff`), mutation-verified — the same discipline that proved the vol oracle.

2. **Primitive faithfulness layer (secondary, cheap).** Diff Plank `v3::math::full_math::mulDiv`
   ↔ Uniswap `FullMath.sol` (the Solidity it was ported from) to pin the port bit-exactly,
   including revert edges (`denominator ≤ prod1`, result ≥ 2²⁵⁶). This is a one-off port-audit,
   not per-property.

Rationale for solady over OZ in layer 1: solady is **already vendored transitively** (two copies),
its `fullMulDiv` is floor and matches Uniswap/Plank semantics, and the `solady/` remapping already
resolves. Adding OpenZeppelin's `Math.mulDiv` would introduce a redundant dependency for an
identical floor result.

## Question 3 — new deps needed?

**None.** Existing toolchain is sufficient:
- mulDiv: in-repo Plank (`v3::math::full_math`), root already declared.
- Solidity reference primitive: solady, already vendored + remapped.
- Gold standard: Uniswap FullMath, already in `lib/v3-core`.
- `p_risk` is exogenous/settable this milestone (RealizedVolatilityMod wiring deferred), so **no
  oracle dependency** is pulled in.
- No npm change: `@cryptoalgebra/volatility-oracle-plugin@2.2.0` stays as-is; the vault touches nothing in it.

## Alternatives Considered

| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|-------------------------|
| In-repo Plank `v3::math::full_math::mulDiv` | Hand-write a new mulDiv in `src/lib` | Only if the vault's Q0.96 conventions ever need a variant the Uniswap port lacks (e.g. `mulDivN` by a shift). Not the case for H1 issuance — don't fork a proven routine. |
| solady `fullMulDiv` as mock primitive | OZ `Math.mulDiv`; or hand-rolled assembly mulDiv | OZ only if solady were absent (it isn't). Hand-rolled assembly never — reusing an audited lib is the point of a *reference* mock. |
| Diff vault logic vs a mock composing trusted mulDiv | Diff Plank mulDiv vs a second mulDiv only | That tests the port, not the vault. Keep it as the secondary layer; it can't catch an issuance/haircut/guard bug. |

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| `price / haircut` valuation | Lean-**refuted**: singular at h=0, wrong monotonicity (`RISK_ALTERNATIVES.md` §H, PROJECT.md) | H1 `p_risk = oracle/(1−h)` with `h < 1` enforced; reject `h=1` rather than divide by zero |
| Raw 256-bit `a*b` in the admissibility guard | Overflows; `RISK_ALTERNATIVES.md` §4 warns against it | Division-free cross-multiplied form — here it collapses to the comparison `ΔQ_M ≤ Q_M^Σ` (no product at all) |
| Adding OZ / a new mulDiv package | Redundant with in-repo Plank mulDiv + vendored solady; bloats the pinned dep closure | Existing `v3::math::full_math` + `solady/` |
| Conflating `totalDeposits` / `totalShares` / `riskWeightedShares` | Lean `discounted_claim_counterexample` refutes it | Three distinct state variables (d ≡ 1 in v1) |

## Stack Patterns by Variant

**If issuance stays H1 + exogenous p_risk (this milestone):**
- Use only `mulDiv` (floor) + a comparison guard. `mulDivRoundingUp` is available but H1 issuance
  rounds **down** (floor) per the Lean spec — use `mulDiv`, not the rounding-up variant, for shares.

**If a later milestone adds D2 clipped-linear distance or P2 max+premium:**
- The same `v3::math::full_math` covers it: `RISK_ALTERNATIVES.md`'s pipeline uses `mulDiv(...,
  roundUp)` for the D2 penalty and P2 premium — that's exactly `mulDivRoundingUp`. Still no new dep.

## Version Compatibility

| Package A | Compatible With | Notes |
|-----------|-----------------|-------|
| `plank` v0.1.1 (`sona`) | `v3::math::full_math` | Same compiler already builds `RealizedVolatilityMod`, which imports `v3::util`, `v3::storage`; `v3::math` is the same root |
| `v3` module root | `PlankTestBase.plankOpts()` + `Makefile:PLANK_DEP` | Must stay in lockstep (base contract's own doc-comment); adding a `math` import needs **no** root change — root is the dir `lib/plankified-univ3/plank/lib`, `math/full_math` is a subpath |
| solady (panoptic copy) vs solady (bunni-v2 copy) | `solady/` remap → panoptic's | Both expose identical `fullMulDiv`; remapping picks panoptic's. Pick one in the mock's import to avoid ambiguity |

## Integration notes for the roadmapper / phase planner

- **Import line the vault will use:** `import v3::math::full_math::{mulDiv, mulDivRoundingUp};`
  — resolves today, no harness edit.
- **Reference-mock file** belongs beside the diff test (pattern: `test/exposure/*.diff.t.sol`
  importing `solady/utils/FixedPointMathLib.sol` and `../PlankTestBase.sol`), mirroring
  `test/market_state_measurements/RealizedVolatility.diff.t.sol`.
- **Acceptance bar (unchanged discipline):** `VegaAccountMod` leaves `PLANK_SKIP` only when its
  `deposit` dispatch is *called* green — "it compiles" is explicitly rejected (the file's own
  GLOBAL RULE and PROJECT.md).
- **No guard-side mulDiv:** the admissibility check is a comparison; don't scaffold a 512-bit
  product there.

## Sources

- `lib/plankified-univ3/plank/lib/math/full_math.plk` — read in full; `mulDiv`/`mulDivRoundingUp` signatures + Uniswap-port algorithm — HIGH
- `lib/plankified-univ3/plank/test/FullMathTest.plk` — existing ABI harness + selectors — HIGH
- `test/PlankTestBase.sol:26` + `Makefile:PLANK_DEP` (line 110) — `v3` root wiring — HIGH
- `lib/panoptic-v2-core/lib/solady/src/utils/FixedPointMathLib.sol:436/529` + `lib/bunni-v2/lib/solady/...:455/595` — `fullMulDiv`/`mulDiv` present — HIGH
- `lib/v3-core/contracts/libraries/FullMath.sol` + `lib/plankified-univ3/contracts/libraries/FullMath.sol` — gold-standard source of the port — HIGH
- `RISK_ALTERNATIVES.md` (H1, §4 guard, §D2/P2 pipeline), `.planning/PROJECT.md` (v3.0 decisions) — design authority — HIGH
- `remappings.txt` — `solady/` and `forge-std/` remaps confirmed — HIGH

---
*Stack research for: VegaAccountMod vault (Plank), milestone v3.0*
*Researched: 2026-07-16*
