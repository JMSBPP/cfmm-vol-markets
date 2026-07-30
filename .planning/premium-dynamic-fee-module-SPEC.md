# Premium — DynamicFee module (Increment 5) design spec (v2)

Status: DRAFT v2 (post review-round-1). Reviewed by Reality Checker + Solidity Smart Contract
Engineer; both NEEDS WORK, no BLOCKER. v2 folds in: explicit `(alpha1|alpha2)==0` parenthesization,
calldata input-cleaning (mask fields + MASK_U88), owner-gating (user decision), a real deployed
plugin as the differential oracle, the uninitialized-zero-fee hazard, and slot/return/static-struct
minors. Scope: **volatility passed in**, **full plugin surface**, **owner-gated** (locked).

## 0. Context — the fee-as-premium pipeline

```
RealizedVolatilityMod.getAverageVolatility(tick, ts) -> uint88 vol   (DONE)
DynamicFeeMod.getCurrentFee(vol) -> uint16 fee = get_fee(vol, stored_config)   (THIS)
   -> trading fee accrued as premium on the Panoptic position built via v4 hooks
```

Actually SETTING the fee on the pool (a v4 `beforeSwap`-style hook) is a FOLLOW-UP layer; this
increment delivers the fee calculator + owner-gated config store that such a hook calls.

## 1. Deliverables

1. **`src/lib/premium/AdaptiveFee.plk`** — add:
   - `validate_fee_configuration(config)` — `require((alpha1 +% alpha2 +% base_fee) <= 0xffff)` and
     `require((gamma1 != 0) and (gamma2 != 0))`. Operates on ALREADY-MASKED fields (§3).
   - `initial_fee_configuration() -> AlgebraFeeConfiguration` — defaults (2900,12000,360,60000,59,8500,100).
2. **`src/modules/premium/DynamicFeeMod.plk`** — the owner-gated stateful module (§2).
3. **`src/interfaces/premium/DynamicFeeInterface.plk`** — the 4 selectors + owner (pattern match).

## 2. Module behavior

Storage (two slots, hashed labels — MINOR fix, RealizedVolatilityMod convention):
- `SLOT_FEE_CONFIG = keccak256("DynamicFeeMod.FeeConfig")` — the packed u144 config.
- `SLOT_OWNER = keccak256("DynamicFeeMod.Owner")` — the config admin.

`init { return_runtime(); }` — both slots start zero. Owner is captured **TOFU**: the FIRST
`initializeDynamicFee` caller becomes owner (no constructor-arg mechanism exists in this codebase yet;
PriceSetterHook still stubs it). Alternative if the codebase later establishes constructor-arg reading:
owner = deployer via `@evm_caller()` in init. Getters are open (view); setters are owner-gated.

| Method | ABI | Behavior |
|---|---|---|
| `getCurrentFee` | `getCurrentFee(uint88 volatilityAverage) -> uint16` | `vol = calldataload(4) & MASK_U88`; load config `c`; **`if (afc_alpha1(c) \| afc_alpha2(c)) == 0 return afc_base_fee(c)`** (parenthesized — §MAJOR-1); else `get_fee(vol, c)` |
| `initializeDynamicFee` | `initializeDynamicFee((uint16,uint16,uint32,uint32,uint16,uint16,uint16))` | build config from 7 calldata words **masked to width** (§3); owner TOFU: `if owner==0 { sstore(SLOT_OWNER, caller) } else { require(caller==owner) }`; `validate_fee_configuration`; `sstore(SLOT_FEE_CONFIG, pack(config))` |
| `changeFeeConfiguration` | `changeFeeConfiguration((uint16,uint16,uint32,uint32,uint16,uint16,uint16))` | `require(@evm_caller() == owner)` (reverts if owner unset → 0); masked build; validate; store |
| `getFeeConfig` | `getFeeConfig() -> (uint16,uint16,uint32,uint32,uint16,uint16,uint16)` | load `c`; write 7 words to memory `0x00..0xC0`; `return(ptr, 0xE0)` (224 bytes) — MINOR: no existing single-word helper covers this |
| `owner` | `owner() -> address` | `sload(SLOT_OWNER)` (for tests/introspection) |

The `getCurrentFee` short-circuit is behavior-preserving (confirmed: `sigmoid(x,g,0,beta)==0` on all
paths) — a faithful gas optimization. **Precedence (MAJOR-1):** Solidity binds `|` tighter than `==`;
Plank has NO type-safety net (both operands u256), so the wrong parse `alpha1 | (alpha2==0)` would
typecheck silently. The condition MUST be written `(afc_alpha1(c) | afc_alpha2(c)) == 0`.

## 3. Input cleaning (MAJOR-2 — the landmine)

Solidity's ABI decoder delivers CLEAN `uintN` (high bits masked); Plank gets raw calldata words. Two
divergences the reference does not have, both fixed by masking to declared width at the boundary:
- **Struct fields:** mask each to width when building the config from calldata —
  `alpha1/alpha2/gamma1/gamma2/base_fee & 0xffff`, `beta1/beta2 & 0xffffffff` — BEFORE `validate` and
  `pack`. Otherwise a raw `gamma` word with low-16-bits=0 but dirty high bits passes `!= 0`, then
  `pack` masks it to 0 → stored `gamma=0` → `sigmoid`'s `@evm_div(...,0)` returns 0 SILENTLY (the
  reference reverts). Same class for the `alpha1+alpha2+base_fee <= 0xffff` sum (dirty bits inflate it
  → spurious revert). (`algebra_fee_config_pack` masks internally, but `validate` runs pre-pack.)
- **Volatility:** `getCurrentFee` masks `calldataload(4) & MASK_U88` before `get_fee` (RealizedVolatility
  Mod:224 precedent; `MASK_U88 = 0xFFFFFFFFFFFFFFFFFFFFFF`, Timepoint.plk:13). An unmasked dirty-high
  input yields a huge `vol/15`, saturating both sigmoids — a divergence from the true-uint88 reference.

Static-struct ABI (confirmed by both reviewers): the all-value-type tuple encodes INLINE (no offset
word) → the 7 fields sit at calldata `4,36,68,100,132,164,196`. **Invariant to note:** this holds ONLY
while every config member stays static; adding any dynamic member (bytes/string/array) inserts a
32-byte offset pointer and shifts every offset by +32.

## 4. Access control (owner-gated — user decision)

`initializeDynamicFee` / `changeFeeConfiguration` require `@evm_caller() == owner` (init sets owner
TOFU on first call). Getters open. This CLOSES the standalone config-hijack hole the reference avoids
only via its gating connector (`DynamicFeePluginImplementation.sol:11-13`) — which we are not porting.

## 5. Known limitations / hazards
- **Uninitialized zero-fee HAZARD (RC MAJOR).** Before the owner's `initializeDynamicFee`, config is
  zero → `getCurrentFee` returns `base_fee = 0` (faithful to the reference's zero-config short-circuit,
  `DynamicFeePluginImplementation.sol:26`). In the fee-as-premium pipeline a zero fee means positions
  silently accrue NO premium. This is NOT enshrined as correct behavior: the deployer MUST call
  `initializeDynamicFee` before any pool relies on `getCurrentFee`. The calling hook SHOULD assert the
  module is initialized (owner != 0) before trusting the fee. We keep the reference's zero-config
  return (no divergent revert) but document the operational requirement loudly.
- Fee CALCULATOR + owner-gated config store only; does NOT set the fee on a pool (no beforeSwap hook)
  — follow-up layer.
- Volatility passed in (decoupled); the module does not read RealizedVolatilityMod itself.
- Assumes the module is a standalone CALL-reached contract, NOT delegatecall-composed (its fixed slots
  would then need the reference's ERC-7201 namespacing).

## 6. Test plan (TDD — RED first)

The stateful surface is diffed against a REAL deployed plugin oracle, not a reconstruction (MAJOR-4):
**vendor `test/premium/refs/DynamicFeePluginImplementation.sol`** (byte-identical: pragma relaxed,
AdaptiveFee import → the vendored `./AdaptiveFee.sol`, config types from the dep) + vendor the small
`DynamicFeeStorage.sol` (namespaced slot; works standalone). This oracle has no access control (matches
the impl) so the test deploys it, CALLs `initializeDynamicFee`, and diffs the stateful surface. Our
module's owner-gate is tested SEPARATELY (Plank-only), since the oracle has none.

Stateful harness: deploy + CALL to set (init/change), STATICCALL to read (getCurrentFee/getFeeConfig/
owner) — the RealizedVolatilityMod pattern.

1. **validate / initial (lib).** `validate_fee_configuration` reverts on `gamma==0` and on
   `alpha1+alpha2+base_fee > 0xffff`; `initial_fee_configuration` packs to the golden layout ==
   vendored `AdaptiveFee.initialFeeConfiguration()`.
2. **getCurrentFee == real plugin.** After `initializeDynamicFee(C)` on both, `getCurrentFee(vol)`
   equals the deployed `DynamicFeePluginImplementation.getCurrentFee(vol)` over fuzzed valid C × uint88
   vol (this transitively covers the short-circuit AND get_fee, non-circular).
3. **getFeeConfig == real plugin.** `getFeeConfig()` == the oracle's, 7 fields.
4. **Short-circuit explicit.** `alpha1=alpha2=0` ⇒ `getCurrentFee(vol) == base_fee` (concrete value,
   for all vol) and == the oracle.
5. **Dirty-bits negative test (MAJOR-2).** Feed a struct with dirty high bits on `gamma` (low 16 = 0)
   and a dirty-high `uint88` volatility via RAW calldata (bypassing the clean ABI encoder); assert the
   Plank module matches the reference: revert-for-revert on the zero-gamma, value-for-value on vol.
6. **Owner-gate.** `changeFeeConfiguration` from a non-owner reverts (config unchanged); from the owner
   succeeds. First `initializeDynamicFee` sets owner; a second init from a different caller reverts.
7. **Uninitialized.** Before init, `getCurrentFee(vol) == 0` and `owner() == 0` — asserted as the
   documented hazard state (test comment flags it), matching the oracle's zero-config behavior.

## 7. References
- Real (vendored) `DynamicFeePluginImplementation.sol` (getCurrentFee short-circuit :26, init/change
  :17-34, getFeeConfig :37-48), `DynamicFeeStorage.sol` (namespace slot), vendored `AdaptiveFee.sol`.
- `src/modules/market_state_measurements/RealizedVolatilityMod.plk` (SLOT convention :16-22, run{}
  dispatch + CALL/STATICCALL :239-304, MASK_U88 use :224).
- `src/types/premium/AlgebraFeeConfiguration.plk`, `src/lib/premium/AdaptiveFee.plk`.
- `IAlgebraDynamicFeePlugin.getCurrentFee() -> uint16` (the interface satisfied).
