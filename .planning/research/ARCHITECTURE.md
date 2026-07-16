# Architecture Research

**Domain:** VegaAccountMod vault — collateral→vega-exposure issuance module inside an existing layered Plank/Foundry codebase (milestone v3.0)
**Researched:** 2026-07-16
**Confidence:** HIGH (every integration claim below is quoted from a file actually read: `RealizedVolatilityMod.plk`, `Timepoint.plk`, `RealizedVolatilityInterface.plk`, `RealizedVolatilityLib.plk`, `TimepointDecoder.sol`, `RealizedVolatility.diff.t.sol`, `std/constructor.plk`, `PlankTestBase.sol`, `Makefile`, `v3 full_math.plk`, `StorageIndex.plk`, `TimeWindow.plk`)

---

## Standard Architecture

The vault is NOT a new architecture — it is a fifth vertical slice through the four layers the oracle already occupies. The layering is authoritative and enforced by `PlankTestBase.sol`/`Makefile:PLANK_DEP` (six module roots: `v3`, `std`, `pos_spec`, `lib`, `types`, `interfaces`).

### System Overview

```
┌──────────────────────────────────────────────────────────────────────┐
│  test/exposure/VegaAccount.diff.t.sol   (Foundry, one file per module) │
│  ┌───────────────┐ ┌──────────────────┐ ┌───────────────────────────┐ │
│  │ VegaExposure  │ │ IssuanceRefMock  │ │ VegaAccountKernelHarness  │ │
│  │ Decoder.sol   │ │ .sol (FullMath)  │ │ .plk (pure-lib ABI probe) │ │
│  │ (ONLY if pkd) │ │                  │ │                           │ │
│  └───────────────┘ └──────────────────┘ └───────────────────────────┘ │
├──────────────────────────────────────────────────────────────────────┤
│  MODULE (stateful entrypoint)   src/modules/exposure/VegaAccountMod.plk│
│  ┌────────────────────────────────────────────────────────────────┐  │
│  │ init{ return_runtime(); }   run{ selector dispatch }             │  │
│  │  SELECTOR_DEPOSIT · SELECTOR_SET_PRISK · state-reader selectors   │  │
│  │  SLOT_* (keccak-derived) reads/writes · p_risk setter+validate   │  │
│  └────────────────────────────────────────────────────────────────┘  │
├──────────────────────────────────────────────────────────────────────┤
│  INTERFACE   src/interfaces/exposure/VegaAccountInterface.plk          │
│  const SELECTOR_DEPOSIT = 0x… ; SELECTOR_SET_PRISK ; reader selectors  │
├──────────────────────────────────────────────────────────────────────┤
│  LIB (pure, no storage)   src/lib/exposure/VegaIssuanceLib.plk         │
│  haircut_risk_price(oracle,h) · issue(dM,pRiskX96) · admissible(dM,QΣ) │
│         └── reuses v3::math::full_math::{mulDiv, mulDivRoundingUp}      │
├──────────────────────────────────────────────────────────────────────┤
│  TYPES (packed / record)   src/types/exposure/VegaExposure.plk         │
│  VegaExposure record · risk Q-types (RiskPrice X96, Haircut Q0.64)     │
└──────────────────────────────────────────────────────────────────────┘
        SLOTs (module storage):  totalDeposits · totalShares ·
                                 riskWeightedShares · pRisk   (4 words)
```

### Component Responsibilities

| Component | Responsibility | Mirrors / Source |
|-----------|----------------|------------------|
| `src/types/exposure/VegaExposure.plk` | The issuance record + risk fixed-point types. **Record, not a ring-packed word** (see tension §Types). | analogue of `Timepoint.plk`, but does NOT fit one word |
| `src/lib/exposure/VegaIssuanceLib.plk` | ALL pure math: haircut price `oracle/(1−h)`, `ΔQ_v = mulDiv(ΔM, Q96, pRiskX96)` floor, division-free admissibility. No storage. | analogue of `RealizedVolatilityLib.plk` (module holds zero math) |
| `src/interfaces/exposure/VegaAccountInterface.plk` | `const SELECTOR_* = keccak256(sig)[0:4]` declarations only. | analogue of `RealizedVolatilityInterface.plk` |
| `src/modules/exposure/VegaAccountMod.plk` | `init{return_runtime();}` + `run{}` selector dispatch; SLOT reads/writes; `p_risk` setter+validation; three state-var updates; state readers. | analogue of `RealizedVolatilityMod.plk` |
| `test/exposure/VegaAccount.diff.t.sol` | One file, several contracts: lib-kernel probe, lib fuzz vs Solidity mock, module smoke (dispatch called green), admissibility. | analogue of `RealizedVolatility.diff.t.sol` |

---

## (1) The dispatch pattern VegaAccountMod mirrors — quoted from `RealizedVolatilityMod.plk`

**Constructor (`init` block).** The skeleton is already correct here:

```
import std::constructor::return_runtime;   // std/constructor.plk
init{ return_runtime(); }
```

`return_runtime` (`lib/plank-monorepo/std/constructor.plk`) is:
```
const return_runtime = fn () never {
    let buf = @malloc_uninit(@runtime_length());
    @evm_codecopy(buf, @runtime_start_offset(), @runtime_length());
    @evm_return(buf, @runtime_length());
};
```
It is the standard deployment constructor — copies the runtime section and returns it as the deployed code. `Makefile:102` confirms every entrypoint MUST have an `init` block ("`.plk` files have no init block would fail with 'missing init'"). **The skeleton's `import` + `init{ return_runtime(); }` need no change.** No new `std` capability is required; `std` already provides it.

**Selector extraction — identical first line of `run{}`:**
```
let selector = @evm_shr(224, @evm_calldataload(0));
```

**Dispatch — if/else-if chain against `const SELECTOR_*`,** terminating each write branch with `@evm_stop()` and each view branch with `return_u256(...)`, unknown selector falls through to `revert_empty()`:
```
if selector == SELECTOR_INITIALIZE_TWAP {
   let block_timestamp = @evm_calldataload(4) & MASK_U32;   // arg0 at 4
   let tick            = @evm_calldataload(36);              // arg1 at 36 (signed → unmasked)
   ...
   @evm_stop();
} else if selector == SELECTOR_GET_TWAP_TICK {
   ...
   return_u256(get_twap_tick(dt, tick, current_timestamp));
}
...
revert_empty();
```

**Calldata word offsets:** arg *n* is at `4 + 32*n` → `4, 36, 68, …`. Unsigned args are masked (`& MASK_U32`); signed args are left as loaded (Solidity sign-extends into the full word). **For the vault everything is unsigned** (collateral amount, share amounts, an X96 price), so the signed-masking footgun the oracle documents does not apply — a genuine simplification.

**What VegaAccountMod copies, one-for-one:**

| Oracle piece | Vault equivalent |
|--------------|------------------|
| `let selector = @evm_shr(224, @evm_calldataload(0));` | same, verbatim |
| `SELECTOR_INITIALIZE_TWAP` write branch → `@evm_stop()` | `SELECTOR_DEPOSIT`: read `dM = @evm_calldataload(4)` (u256, no mask), compute+store, `return_u256(exposure)` (deposit returns the issued units) |
| `write_window`/`read_window` settable-param pattern | `SELECTOR_SET_PRISK`: read `pRisk = @evm_calldataload(4)`, **validate then sstore** |
| state-reader selectors (`lastIndex`, `readWindow`, `getTimepointPacked`) → `return_u256` | `totalDeposits()`, `totalShares()`, `riskWeightedShares()`, `pRisk()` readers |
| `SLOT_* = 0x…` keccak of a namespaced string | `SLOT_* = keccak256("VegaAccountMod.<Field>")` |

**How the settable `p_risk` should be stored & validated — mirror `write_window`/`read_window`:**
```
// oracle's settable window (RealizedVolatilityMod.plk:30-36)
const write_window = fn(window: TimeWindow) void {
      @evm_sstore(SLOT_TIMEPOINT_BUFFER_WINDOW_SIZE, pack_time_window(window));
};
const read_window = fn() TimeWindow { unpack_time_window(@evm_sload(SLOT_...)) };
```
Vault version: `SLOT_P_RISK = keccak256("VegaAccountMod.PRisk")`. The setter validates with `require` from `std::error`:
```
const require = fn (condition: bool) void { if !condition { @evm_revert(@malloc_uninit(0), 0); } };
```
Validation gates, both machine-checked in Lean:
- `require(pRisk > 0)` — exogenous-price sanity (PROJECT.md key decision: "validated > 0").
- If `p_risk` is set from `(oracle, h)` on-chain: enforce `h < 1` inside `haircut_risk_price` (Lean `haircutRiskPrice_ge_oracle`). In v1 with a directly-set exogenous `pRisk`, the `h<1` guard lives in the *lib* and is exercised by the lib fuzz, not necessarily by the setter — a scope choice to make explicit in the plan.

**Storage: packed word vs separate slots.** The oracle packs `ss_index|timestamp|isInitialized` into ONE word (`pack_realized_volatility_state`) because they are all small (≤48 bits) and co-updated. The vault's three balances are full-width `u256` accounting totals → **they do NOT co-pack; use one keccak-derived SLOT each** (`SLOT_TOTAL_DEPOSITS`, `SLOT_TOTAL_SHARES`, `SLOT_RISK_WEIGHTED_SHARES`), plus `SLOT_P_RISK`. This is simpler than the oracle's packed-state word and is the right call — do not invent a packed state word where the fields are word-sized.

---

## (2) `src/types/exposure/VegaExposure.plk` — LIVE fields, and the spec/scope tension

The spec (`spec/entities/types/exposure.md`) declares five fields:
```solidity
struct VegaExposure { uint128 exposure; uint160 priceVolX96; address collateralToken; address underlyingToken; uint16 riskOracleId; }
```
The current stub has two, **mis-named** relative to the spec:
```
const VegaExposure = struct{ collateralUnits:u256, priceVol: u256 };
```

**Structural fact (blocks any "pack like Timepoint" instinct):** `exposure` (128) + `priceVolX96` (160) = **288 bits > 256** before the two 160-bit addresses and the u16 are even counted. Unlike `Timepoint` (241 bits, fits one word and lives in a ring read via `getTimepointPacked`), **`VegaExposure` cannot be a single packed word.** It is a plain multi-field record. Consequence: it needs neither a ring `array_slot` layout nor a bit-offset `pack/unpack` pair, and (see §4) **no Solidity decoder** unless a branch deliberately ABI-returns a packed word.

**Field-by-field liveness under the v1 scope** (PROJECT.md: exogenous/settable `p_risk`, no oracle wiring, no token transfers, H1 only):

| Field | Live in v1? | Reasoning / tension |
|-------|-------------|---------------------|
| `exposure` (u128 = `N_v = ΔM/p`) | **LIVE** | The issuance output. This is the vault's reason to exist. |
| `priceVolX96` (u160) | **LIVE**, but re-interpreted | Spec ties it to `p_vol(σ̄)`; v1 has **no** `p_vol` (its pos_spec type still has 5 red harness tests, explicitly deferred). In v1 this field carries the **exogenous `p_risk`** (X96). Name it `priceVolX96` to honor the spec, but document that in v1 it is `p_risk`, not `p_vol(σ̄)`. **State the tension, don't silently rename.** |
| `collateralToken` (address) | **DEAD in v1** | "no token transfers" ⇒ no `transferFrom`, no address is dereferenced. Scaffold as a field only if per-market identity is needed; otherwise defer. |
| `underlyingToken` (address) | **DEAD in v1** | same as above. |
| `riskOracleId` (u16) | **DEAD in v1** | **Direct conflict:** exogenous `p_risk` means there is no oracle to look up, so an oracle id indexes nothing. The stub's `SLOT_RISK_ORACLE_ID` and `SLOT_UNDERLYING_MARKET_ID` are pre-scaffolding for a v2 wiring that PROJECT.md explicitly defers ("oracle wiring to RealizedVolatilityMod deferred"). **Flag: `riskOracleId` is dead code in v1.** |

**Recommended v1 type (2 LIVE fields, addresses/oracleId deferred with a comment):**
```
// v1: exogenous p_risk, no token transfers. Address / oracleId fields are
// SCAFFOLDED-DEFERRED (dead until oracle wiring lands in a later milestone).
const VegaExposure = struct {
    exposure:     u256,   // u128  N_v = ΔM / p_risk   (issued vega units)
    priceVolX96:  u256    // u160  Q64.96 price used   (v1: the exogenous p_risk, NOT p_vol(σ̄))
    // collateralToken / underlyingToken / riskOracleId  -> deferred (no transfers, no oracle in v1)
};
```
Rename note: the stub's `collateralUnits` conflates the *input* `ΔM` with the *output* exposure — the spec's `exposure` is `N_v`. Fix the name when completing the type. Also add the risk fixed-point companions the milestone lists ("Q0.96/X96 risk types"): a `RiskPriceX96` (Q64.96) and a `Haircut` (Q0.64) newtype so the lib signatures are typed rather than bare `u256`.

**Where the three STATE variables live (not in VegaExposure):** `totalDeposits`, `totalShares`, `riskWeightedShares` are *module* storage scalars (own SLOTs), kept distinct per Lean `discounted_claim_counterexample`. `VegaExposure` is the per-deposit computed record / return value, not the module's balance sheet.

---

## (3) Lib vs module split — mirror `RealizedVolatilityLib` (module holds zero math)

`RealizedVolatilityMod` delegates every arithmetic step to `RealizedVolatilityLib` (`calculate_realized_volatility`, `calculate_avg_tick`, `twap_tick`). The vault follows the same discipline.

**`src/lib/exposure/VegaIssuanceLib.plk` — PURE, no `@evm_sload/sstore`:**

| Function | Signature (sketch) | Lean lemma it discharges | Notes |
|----------|--------------------|--------------------------|-------|
| floor mulDiv | reuse `v3::math::full_math::mulDiv(a,b,denom)` | `mulX96Down_le` / `mulX96Down_one` | **Already exists** at `lib/plankified-univ3/plank/lib/math/full_math.plk` (`mulDiv`, `mulDivRoundingUp`). Do NOT reimplement — import `import v3::math::full_math::{mulDiv};` and `v3::math::fixed_point_96::{Q96}`. |
| haircut risk price | `haircut_risk_price(oracleX96, h) -> RiskPriceX96` = `oracle/(1−h)` | `issuance_haircut_equiv`, `haircutRiskPrice_ge_oracle` | Enforce `require(h < ONE)`. **`risk.md`'s current `price/haircut` formula is REFUTED in Lean** (singular at h=0, wrong monotonicity) — must be corrected to `oracle/(1−h)` BEFORE this lib is written (see build order step 0). |
| issuance | `issue(dM, pRiskX96) -> u256` = `mulDiv(dM, Q96, pRiskX96)` (floor) | `mulX96Down_le/one` | `ΔQ_v = ΔM / p_risk` with X96 scaling. |
| admissibility | `admissible(dM, totalDepositsSigma) -> bool` | `admissible_iff_mul`, `deltaShares_admissible_iff` | **Division-free** predicate; collapses to `ΔM ≤ Q_M^Σ`. Pure boolean, no revert (module decides whether to `require` it). |

**`src/modules/exposure/VegaAccountMod.plk` — stateful ONLY:** selector dispatch, SLOT reads/writes, `p_risk` setter+validation, the three state-var updates, state readers. It *calls* the lib for the numbers, exactly as `write_timepoint` calls `calculate_avg_tick`. Keeping the admissibility `require` in the module (not the lib) mirrors how the oracle keeps `require(dt != 0)` at the `get_twap_tick` entrypoint while the lib stays total.

---

## (4) Solidity test-side mirror

Follows `RealizedVolatility.diff.t.sol` exactly: **one file, several contracts, weakest→strongest claim**, driven by `PlankTestBase.deployPlank(path)`.

**Reference mock (analogue of `test/mocks/AlgebraVolatilityKernelMock.sol`):** `IssuanceRefMock.sol` re-implements the H1 pipeline in Solidity using a `mulDiv` — either `v3-core/contracts/libraries/FullMath.sol` (present in `lib/`) or solady's `FullMathLib`. It computes `p_risk = oracle*1e?/(1−h)`, `N_v = mulDiv(dM, Q96, pRisk)`, and the admissibility bool, tolerance 0, as the differential oracle for each Lean-lemma fuzz property.

**Plank kernel harness (analogue of `RealizedVolatilityKernelHarness.plk`):** `test/exposure/VegaAccountKernelHarness.plk` — a TEST-ONLY ABI wrapper over the pure lib so `issue`/`haircut_risk_price`/`admissible` can be fuzzed **without** the storage/dispatch path. This is what lets the lib be tested before the module compiles (see build order).

**Decoder — likely NOT needed in v1 (contrast with `TimepointDecoder.sol`).** `TimepointDecoder.sol` exists because the oracle returns a *packed 241-bit word* via `getTimepointPacked`. The vault's state readers return **scalars** (`totalDeposits`, `totalShares`, `riskWeightedShares`, `pRisk`, and `deposit`'s `exposure`), so there is nothing to decode. The interface author's own rationale applies verbatim: exposing scalars means the test "does NOT have to mirror Plank's storage-slot derivation … which would be two more unverified mirrors checking an unverified implementation." **Add a `VegaExposureDecoder.sol` only if a branch deliberately ABI-returns a packed multi-field `VegaExposure` word — do not build it speculatively.**

**Lean-lemma → fuzz-property map (the test oracle):**

| Property | Contract in the diff file |
|----------|---------------------------|
| `mulX96Down_le` / `mulX96Down_one` | `VegaIssuanceKernelDiffTest` (lib vs mock, N-D fuzz) |
| `issuance_haircut_equiv` | same |
| `haircutRiskPrice_ge_oracle` (with `h<1`) | same, + a probe point with an external hand-derived anchor |
| `deltaShares_admissible_iff` | `VegaAccountAdmissibilityTest` |
| dispatch is live / deposit changes state / three vars stay distinct | `VegaAccountSmokeTest` (module deploy + **called** green) |

**Acceptance rule inherited from the oracle file (GLOBAL RULE):** "it compiles" is never acceptance — `plank build` does not type-check code unreachable from `run{}`. `VegaAccountMod` leaves `PLANK_SKIP` only when a `deposit`/`setPRisk` call returns green, never on compile alone.

---

## (5) Suggested build order (dependency-respecting; independently-testable units flagged)

```
0. Correct spec/entities/types/risk.md   (kill price/haircut → oracle/(1−h)) + sync exposure.md
      └─ DOC ONLY. BLOCKS step 2 (the lib formula is refuted until this is fixed). No test.
1. src/types/exposure/VegaExposure.plk   (2 live fields + RiskPriceX96 / Haircut Q-types)
      └─ compile-only; independently "testable" only by being imported. No decoder needed.
2. src/lib/exposure/VegaIssuanceLib.plk   (haircut price, issue=mulDiv floor, admissible)
      └─ ★ HIGHEST-VALUE INDEPENDENTLY TESTABLE UNIT. Test via VegaAccountKernelHarness.plk
         + IssuanceRefMock.sol BEFORE any module/storage exists — exactly how the oracle
         proved its variance kernel (RealizedVolatilityKernelDiffTest) ahead of the module.
         Reuses v3::math::full_math::mulDiv (no new math to verify).
3. src/interfaces/exposure/VegaAccountInterface.plk   (SELECTOR_DEPOSIT, SET_PRISK, readers)
      └─ declaration only; `cast sig` each selector (the interface file's VDIFF note warns a
         wrong selector const silently mis-dispatches).
4. src/modules/exposure/VegaAccountMod.plk   (dispatch + SLOTs + setter/validate + readers)
      └─ testable only end-to-end (VegaAccountSmokeTest). Leaves PLANK_SKIP when CALLED green.
5. Makefile + PlankTestBase parity check.
```

**Dependency notes for the roadmapper:**
- Steps 1–3 are each independently *authored*; step 2 is the one that is independently *tested* with a full differential (the others are compile/decl-only). Sequence the Lean-lemma fuzz battery entirely inside step 2 — it does not need the module.
- **No new `PLANK_DEP` root is required.** `exposure/` is a subfolder under the existing `types` root (`src/types`) and `lib` root (`src/lib`), so imports resolve as `types::exposure::VegaExposure::*` and `lib::exposure::VegaIssuanceLib::*`. `PlankTestBase.sol`'s six-root list (v3, std, pos_spec, lib, types, interfaces) already covers every import the vault needs — **confirm, don't add.** The only Makefile change is **removing** `src/modules/exposure/VegaAccountMod.plk` from `PLANK_SKIP` at the end of step 4.
- The stub currently imports only `std::constructor::return_runtime` — correct and sufficient for the constructor. The module will additionally need `std::error::require`, `v3::util::{return_u256, revert_empty}`, `v3::math::full_math::mulDiv`, `types::exposure::VegaExposure::*`, `lib::exposure::VegaIssuanceLib::*`, `interfaces::exposure::VegaAccountInterface::*` — all under already-declared roots.

---

## Data Flow

### `deposit(collateralAmt)` → issued vega units
```
caller ──deposit(ΔM)──▶ run{}: selector==SELECTOR_DEPOSIT
   ├─ dM        = @evm_calldataload(4)                     (u256, unsigned, no mask)
   ├─ pRisk     = @evm_sload(SLOT_P_RISK)                  ; require(pRisk > 0)
   ├─ QΣ        = @evm_sload(SLOT_TOTAL_DEPOSITS)
   ├─ require( admissible(dM, QΣ) )                        (lib, division-free)
   ├─ Nv        = issue(dM, pRisk) = mulDiv(dM, Q96, pRisk)  (lib, floor)
   ├─ sstore SLOT_TOTAL_DEPOSITS       = QΣ + dM
   ├─ sstore SLOT_TOTAL_SHARES         = shares + Nv
   ├─ sstore SLOT_RISK_WEIGHTED_SHARES = rws  + Nv          (d ≡ 1 in v1; kept DISTINCT)
   └─ return_u256(Nv)
```
Three writes to three distinct SLOTs — the Lean `discounted_claim_counterexample` invariant that `totalShares` ≠ `riskWeightedShares` is preserved structurally even though `d ≡ 1` makes them numerically equal in v1.

### `setPRisk(pRiskX96)` (settable exogenous parameter)
```
caller ──setPRisk(p)──▶ selector==SELECTOR_SET_PRISK
   ├─ p = @evm_calldataload(4) ; require(p > 0)     (mirror write_window)
   └─ sstore SLOT_P_RISK = p ; @evm_stop()
```

---

## Anti-Patterns (specific to this integration)

### Packing `VegaExposure` into one word "like Timepoint"
**What people do:** copy `Timepoint.plk`'s bit-offset `pack/unpack` for `VegaExposure`.
**Why it's wrong:** the two live fields alone are 128+160 = 288 bits > 256; it does not fit, and unlike `Timepoint` it is not a ring entry read as a packed word. Forcing a pack either truncates `priceVolX96` or spills to a second word for no benefit.
**Do instead:** a plain multi-field record; word-sized state totals in separate SLOTs; scalar state readers → no Solidity decoder.

### Wiring `riskOracleId` / oracle lookup in v1
**What people do:** honor all five spec fields and thread `riskOracleId` into a price lookup.
**Why it's wrong:** v1 `p_risk` is exogenous (`setPRisk`); there is no oracle to index. PROJECT.md defers oracle wiring. The id would index nothing — dead state, dead branch.
**Do instead:** carry `p_risk` in `priceVolX96` / `SLOT_P_RISK`; leave `riskOracleId` and the token addresses as commented-deferred scaffolding.

### Reimplementing `mulDiv`
**What people do:** hand-roll a 512-bit `mulDiv` in the exposure lib.
**Why it's wrong:** `v3::math::full_math::{mulDiv, mulDivRoundingUp}` already exists, already backs the UniV3 port, and is the same Chinese-remainder `FullMath` the Solidity mock will use — reimplementing adds an *unverified* mirror on the Plank side.
**Do instead:** `import v3::math::full_math::{mulDiv};`.

### Treating a green compile as done
**What people do:** remove `VegaAccountMod.plk` from `PLANK_SKIP` when it compiles.
**Why it's wrong:** `plank build` doesn't type-check code unreachable from `run{}` (documented in `RealizedVolatility.diff.t.sol`: a "13 ok" gate once passed on an empty module).
**Do instead:** leave `PLANK_SKIP` only when a `deposit` call executes green in the smoke test.

### `risk.md`'s `price/haircut` as the formula
**What people do:** implement the lib from `spec/entities/types/risk.md` as written.
**Why it's wrong:** Lean refutes `price/haircut` (singular at h=0, wrong monotonicity). The machine-checked form is `p_risk = oracle/(1−h)` (`issuance_haircut_equiv`).
**Do instead:** correct `risk.md` first (build-order step 0), then implement `oracle/(1−h)` with `require(h < 1)`.

---

## Integration Points

### Internal boundaries

| Boundary | Communication | Notes |
|----------|---------------|-------|
| module ↔ lib | direct `import` + call | module holds zero math; lib holds zero storage (mirrors Mod↔Lib in the oracle) |
| module ↔ types | `import types::exposure::VegaExposure::*` | record + risk Q-types; resolves under existing `types` root |
| module ↔ std | `std::constructor::return_runtime`, `std::error::require` | already available; skeleton's constructor import is correct |
| module ↔ v3 | `v3::util::{return_u256, revert_empty}`, `v3::math::full_math::mulDiv`, `v3::math::fixed_point_96::Q96` | reuse; no new math |
| test ↔ module | `PlankTestBase.deployPlank(path)` → FFI `plank build` at test time | no `make compile-plank` needed to reach a `.plk` edit |
| test ↔ lib | `VegaAccountKernelHarness.plk` (ABI over pure lib) | lets step-2 lib be diffed before the module exists |

### New vs modified (explicit)

**NEW files:** `src/lib/exposure/VegaIssuanceLib.plk`, `src/interfaces/exposure/VegaAccountInterface.plk`, `test/exposure/VegaAccount.diff.t.sol`, `test/exposure/VegaAccountKernelHarness.plk`, `test/mocks/IssuanceRefMock.sol` (and `test/exposure/VegaExposureDecoder.sol` **only if** a packed word is returned).

**MODIFIED files:** `src/types/exposure/VegaExposure.plk` (complete the record + add risk Q-types), `src/modules/exposure/VegaAccountMod.plk` (fill dispatch/storage/readers — the skeleton's `import`/`init` stay), `spec/entities/types/risk.md` (correct the formula), `spec/entities/types/exposure.md` (sync to RiskDesign.lean / annotate deferred fields), `Makefile` (drop `VegaAccountMod.plk` from `PLANK_SKIP`).

**UNCHANGED / confirm-only:** `PlankTestBase.sol` and `Makefile:PLANK_DEP` roots — the six existing roots already cover `exposure/` as a subfolder of `types`/`lib`. No new root.

---

## Confidence & Open Questions

- **HIGH** on dispatch/constructor/lib-split/storage/test patterns — all quoted from read files.
- **HIGH** that `mulDiv` and `return_runtime` exist and are the right primitives — files read directly.
- **MEDIUM** on the exact liveness call for the two token-address fields: "no token transfers" is stated in the milestone context, so they are functionally dead, but whether v1 wants them as inert *identity* metadata (single-market vs multi-market vault) is a product choice the roadmap/plan should settle. The oracle-id field is unambiguously dead under exogenous `p_risk`.
- **Open (needs the Lean source, not read here):** the precise fixed-point convention of `haircut_risk_price` (is `h` a Q0.64 fraction, and is `p_risk` returned Q64.96?) and the exact scaling in `issue` (`Q96` numerator vs a WAD) — resolve against `../cfmm-wt/lean4-spec/lean/vol_markets/RiskDesign.lean` before writing step 2. This is the one arithmetic detail this architecture pass could not pin from repo files alone.

## Sources

- `src/modules/market_state_measurements/RealizedVolatilityMod.plk` (dispatch, settable-param, state-reader, packed-state patterns)
- `src/types/market_state_measurements/Timepoint.plk` (packed-word layout contrast)
- `src/lib/market_state_measurements/RealizedVolatilityLib.plk` (pure-lib discipline)
- `src/interfaces/market_state_measurements/RealizedVolatilityInterface.plk` (selector-const pattern)
- `test/market_state_measurements/RealizedVolatility.diff.t.sol`, `TimepointDecoder.sol`, `test/mocks/AlgebraVolatilityKernelMock.sol` (test-side mirror pattern)
- `lib/plank-monorepo/std/{constructor,error,storage,math}.plk` (constructor, require, map_slot_hash)
- `lib/plankified-univ3/plank/lib/math/full_math.plk` (mulDiv availability), `.../storage.plk` (array_slot), `v3/util.plk` (return_u256/revert_empty)
- `test/PlankTestBase.sol`, `Makefile` (module roots, PLANK_SKIP, FFI-at-test-time)
- `spec/entities/types/exposure.md`, `spec/entities/types/risk.md`, `.planning/PROJECT.md` (scope, deferred items, Lean design authority)

---
*Architecture research for: VegaAccountMod vault (H1 issuance, exogenous risk price) — milestone v3.0*
*Researched: 2026-07-16*
