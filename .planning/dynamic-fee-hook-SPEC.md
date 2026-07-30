# DynamicFeeHook — v4 beforeSwap dynamic-fee (premium) hook design spec (v2)

Status: **CORE LANDED (2026-07-30) — §7 tests 1–5 + events battery GREEN; §7.6 GOAL
(vol→fee→premium E2E vs real PoolManager + SFPM) is the remaining dedicated integration
increment (REQUIRED, per the split this spec sanctions).** All resume-plan items applied:
B1 (rv_write_timepoint returns bool, no frame halt — mutation-verified 32→96 bytes), the
(base,state,window)-slot-parameterized RealizedVolatilityStateLib shared by Mod + hook
(refactored under a green suite), NEW-5 resolved as HARD one-pool-per-hook (poolId bound at
init, required in beforeSwap), research-only no-owner-gate (one-shot init + header
invariant), extsload(bytes32)=0x1e2eaeaf pinned, clean fee word asserted, initTs masked
MASK_U32. Adaptivity de-hedged: fee tracks regime DIRECTION (falls when calm) and the
hook's vol is diffed vs the REAL Algebra oracle at tolerance 0 (the differential — not the
direction test — is what kills the read-only and masked-tick mutants; recorded in the test
file). Events: the hook is the POOL-KEYED emitter — E3/E4/E5/E6 carry the real poolId
(E5 FeeApplied added to VolEventsLib). Module: src/modules/protocol_integrations/
DynamicFeeHook.plk; tests: test/protocol_integrations/DynamicFeeHook.t.sol (11).

Original parked header below for the record.

Prior status: **PARKED — BLOCKED pending todo 6-9 (windowed getAverageVolatility).** Two review rounds done
(Reality Checker + Solidity Engineer). Premise VERIFIED (premia ARE the pool swap fees) and ALL v4
plumbing CONFIRMED. Round-2 (this v2) found the hook's core value is NOT REAL yet: `get_average_
volatility` (RealizedVolatilityMod.plk:222) is a monotone CUMULATIVE stub, not Algebra's window-
normalized average, so the fee only ratchets up and never tracks the regime. **User decision: finish
todo 6-9 (the windowed reader) FIRST, then resume this hook.** Also: research-only, NO owner-gate this
increment (no sound mechanism exists for a CREATE2/flagged hook — caller-at-CREATE = factory, vm.etch
skips init; owner must arrive via a constructor/factory arg, todo.md:178).

### Resume plan (apply when todo 6-9 lands)
- **B1 (BLOCKER, both reviewers):** the hook's `write_timepoint` wrapper MUST strip the
  `return_u256(EMPTY)` same-block early-out (RealizedVolatilityMod.plk:133 — `return_u256` = `@evm_return`,
  halts the frame) → replace with a plain no-op return so `beforeSwap` continues to the 96-byte tuple;
  else a 2nd same-block swap returns 32 zero-bytes and the hook fails (SFPM swapInAMM does >1 swap/block).
- **§4 fork resolved:** FACTOR RealizedVolatilityMod's `write_timepoint`/`get_average_volatility`/
  `initialize_timepoint_buffer` + support (`load_ring_state`, `read_window`) into a shared
  (base,state,window)-slot-parameterized lib both Mod and hook bind (they hardcode 3 module slots today).
- **NEW-5 (pool_id keying):** key the hook's vol-buffer slots by `pool_id` OR state a hard one-pool-per-
  hook constraint (a v4 hook is normally many-pools; a fixed buffer comingles ticks across pools).
- **Goal test (§7.6) de-hedged + vol→fee→premium:** the E2E premium test is REQUIRED (not deferrable),
  and add a vol→fee link test (Test #2 must assert the fee tracks regime DIRECTION — only possible once
  the windowed reader lands).
- **Owner:** research-only invariant in the hook header ("MUST NOT back a live pool until owner via
  constructor/factory arg"); config test-seeded/open this increment.
- MINORs: pin single-arg `extsload(bytes32)` selector; clean the fee return word (high 29 bytes zero);
  keep `initTs` mask identical to the beforeSwap clock (MASK_U32) so the first post-seed `dt` is sane.

--- (original v2 design below; the reader/adaptivity claims apply only AFTER todo 6-9) ---

Prior status: DRAFT v2. Scope (user decisions): **co-located vol-oracle + dynamic-fee in one hook**
(Algebra base-plugin shape) · **LDF params do NOT enter the fee** (position-side only) · flagged hook
address, real PoolManager.

## 0. Economic grounding (VERIFIED by review, corrected wording)

Panoptic option premia are **derived from** the underlying pool's accrued Uniswap swap fees:
`premium = collected_fees × (totalLiquidity / netLiquidity²) × VEGOID_spread`
(SFPM V4:1129-1169 `_getPremiaDeltas`; PanopticPool:196-197). So the pool-fee override **scales the
fee revenue that becomes the premium base** — the hook's purpose is real. Corrected from v1: premia are
NOT *identical* to the fees — they are `fees × a position-side utilization/spread multiplier`, so the
fee controls premia **proportionally, holding utilization constant**.

**LDF params (locked): do NOT enter the fee.** `getCurrentFee` stays a pure function of volatility
(faithful to Algebra). The LDF shape acts entirely on the POSITION side: it sets a chunk's
`netLiquidity` and its share of swap volume, hence its `collected` fees, hence its premium. So "control
premia with the LDF params" = a vol-driven fee applied to LDF-shaped positions; the LDF→premium link is
derived + TESTED here (§7), not asserted.

```
v4 pool (fee = DYNAMIC_FEE_FLAG 0x800000, poolKey.hooks = DynamicFeeHook @ BEFORE_SWAP_FLAG addr)
  beforeSwap:  write pre-swap tick to OWN vol buffer  ->  vol = getAverageVolatility(self)
               ->  fee = get_fee(vol, own config)  ->  return fee | OVERRIDE_FEE_FLAG
Panoptic SFPM v4.initializeAMMPool(poolKey) accepts arbitrary hooked/dynamic-fee pools -> positions
   accrue the vol-driven fee as premium
```

## 1. Objective

`src/modules/protocol_integrations/DynamicFeeHook.plk` — a v4 hook that CO-LOCATES: (i) an Algebra-style
realized-volatility timepoint buffer (its own storage, over `RealizedVolatilityLib` — already
slot-parameterized), and (ii) the AdaptiveFee config + `get_fee`. Its `beforeSwap` WRITES the current
tick to its buffer, reads the average volatility, computes the fee, and overrides the swap fee.

## 2. beforeSwap behavior (BLOCKER fix: write-then-read)

`beforeSwap(address sender, PoolKey key, SwapParams params, bytes hookData) -> (bytes4, BeforeSwapDelta, uint24)`.
Calldata (CONFIRMED): `sender@4`, `key@36` (currency0@36..hooks@164), `params@196`, hookData offset@292.

```
1. require @evm_caller() == pool_manager                              (only PoolManager calls hooks)
2. pool_id = @evm_keccak256(calldata @36, 160)                        (v4 PoolId = keccak of the PoolKey)
3. tick    = read_current_tick(pool_id)                               (extsload slot0; §3)
4. write_timepoint(@evm_timestamp() & 0xffffffff, tick)               (WRITE to OWN buffer -- the fix)
5. vol     = get_average_volatility(tick, @evm_timestamp() & 0xffffffff)   (read OWN buffer)
6. fee     = get_fee(vol, own_packed_config)                          (AdaptiveFee, self config)
7. return ( beforeSwap.selector , 0 , fee | OVERRIDE_FEE_FLAG(0x400000) )   -- exactly 96 bytes
```

Step 4 is the BLOCKER resolution: without a per-swap write the vol series is frozen and the fee never
adapts. Writing the pre-swap tick each swap advances realized variance (Algebra's plugin does exactly
this). Return words (Solidity review): word1 = `beforeSwap.selector` LEFT-aligned (high 4 bytes), word2
= clean zero, word3 = `(fee | 0x400000)` with **high 29 bytes zero** (parseFee mloads the full word;
dirty bits corrupt the fee / could hit the 0x800000 dynamic bit).

## 3. read_current_tick (CONFIRMED facts)

- `state_slot = @evm_keccak256(pool_id . POOLS_SLOT)`, **POOLS_SLOT = 6** (StateLibrary.sol:11; slot =
  keccak(abi.encodePacked(poolId, bytes32(6))), :324-326).
- `slot0 = extsload(pool_manager, state_slot)` — staticcall the **single-arg `extsload(bytes32)->bytes32`**
  overload (IExtsload has 3 overloads — pin this selector). Reentrancy-safe: beforeSwap is a CALL, extsload
  has no lock guard.
- `tick = @evm_signextend(2, @evm_shr(160, slot0))` — Slot0: sqrtPriceX96@[0,160), tick@[160,184) signed
  (Slot0.sol:8-9,36-51). Drop v1's redundant `& 0xffffff` (signextend already ignores bits ≥24).

## 4. Co-located storage + config (the writer resolution)

The hook owns, in its storage (distinct hashed slots):
- **Vol buffer**: the RealizedVolatilityMod state — `SLOT_TIMEPOINT_BUFFER_BASE` (ring), `SLOT_REALIZED_
  VOL_STATE`, `SLOT_TIMEPOINT_BUFFER_WINDOW_SIZE`. The hook defines its own `write_timepoint` /
  `get_average_volatility` wrappers binding THESE slots over `RealizedVolatilityLib` (slot-parameterized).
  Implementation choice (for review/TDD): FACTOR RealizedVolatilityMod's wrappers into a shared
  slot-parameterized lib both use (preferred, avoids divergence), OR duplicate the thin binding layer.
- **Fee config**: `SLOT_FEE_CONFIG` (packed u144, via `algebra_fee_config_pack`).
- **Config admin + pool manager**: `SLOT_OWNER`, `SLOT_POOL_MANAGER`.

Initialization: `initializeHook(poolManager, config, initTick, initTs)` (owner path) seeds the buffer
(`initialize_timepoint_buffer`) + stores config + poolManager. `getAverageVolatility` needs a seeded
buffer (uninitialized → revert or a defined empty-vol behavior — §6).

## 5. Security — owner wiring (MAJOR, both reviewers): NOT TOFU

v1's TOFU (first caller = owner) is **front-runnable**: the hook is deployed at a publicly-derivable
flagged address; an attacker calls `initializeHook` first, seizes ownership, points the config/vol at
malicious values, and forces the fee (up to ~6.55%, or 0% → zero premia). Resolution:
- **Preferred**: set owner + poolManager **atomically at deploy** (constructor args → `immutable`-style
  slots written once in `init`). BLOCKED on Plank's unestablished constructor-arg mechanism (todo.md:178
  — the very "Hook requirements" this task depends on). If that mechanism lands, use it.
- **Interim (research milestone only)**: a deployer-pinned owner captured in `init` via `@evm_caller()`
  (owner = deployer, set once at CREATE, NOT front-runnable — the deploy tx's sender), IF the sona
  backend exposes caller during construction; else a deployer-restricted one-shot init in the SAME
  deploy tx. HARD invariant: **MUST NOT back a live pool until owner-capture is deploy-atomic.** Config
  changes owner-gated + ideally timelocked.
This is the concrete remaining decision for v2 review (which interim mechanism), not a soft defer.

## 6. Known limitations / notes (review findings folded in)
- **Premia = fees × utilization multiplier** (not identical) — §0. Fee controls premia proportionally
  under constant utilization.
- **SFPM's own ITM swaps hit the fee**: `swapInAMM` (SFPM V4:742) calls `POOL_MANAGER.swap` on this
  pool, so `beforeSwap` fires (and writes a timepoint + applies the vol-fee) during Panoptic's internal
  rebalancing too. Acceptable (more vol samples), but stated.
- **Unconfigured → silent 0% fee** (both reviewers): a zero fee config makes `get_fee` return
  base_fee=0; `0 | OVERRIDE_FEE_FLAG` is a *valid* 0% override → zero premia, no revert. The hook MUST
  guard: `beforeSwap` reverts (or refuses to override) if not initialized (owner==0 / config==0). Tested.
- **Pool must be DYNAMIC_FEE_FLAG-initialized** by the deployer (LPFeeLibrary) — else the override is
  ignored. A flag-LESS return silently yields 0% (dynamic pools store lpFee=0) — the override flag is
  ALWAYS OR'd; negative test asserts this.
- The full PriceSetterHook framework beyond beforeSwap (`beforeInitialize` binding, PriceUpdate log,
  DEST_CHAIN/origin, AlgebraFactory guard, builderCode/todo-17) stays deferred.

## 7. Test plan (TDD — RED first) — now tests the GOAL

Vol/fee unit + the end-to-end premium-control test the RC required.

1. **beforeSwap fee == self-composition.** After `initializeHook(config)` + seeded buffer at a known
   tick, `beforeSwap` (as PoolManager) returns `get_fee(get_average_volatility(tick,ts), config) |
   0x400000`, selector correct, delta 0, and the return word is clean (high bytes zero).
2. **Write advances the series (adaptivity).** Call `beforeSwap` across several ticks/timestamps;
   assert `get_average_volatility` (hence the returned fee) CHANGES — proving the writer makes it
   adaptive (guards the BLOCKER: a read-only hook would return a constant).
3. **read_current_tick.** Against a mock PoolManager storing slot0 at
   `keccak(abi.encodePacked(poolId, bytes32(6)))`, the read tick == the pool's tick (golden + negative).
4. **Caller guard / uninitialized / unconfigured.** non-PoolManager reverts; before init reverts;
   zero-config does NOT silently override at 0% (reverts or refuses).
5. **Owner gate** (§5 interim mechanism) — non-owner config change reverts; owner-capture not
   front-runnable under the chosen mechanism.
6. **GOAL — premium control (the RC-required test).** Deploy the hook at a `BEFORE_SWAP_FLAG` address
   (vm.etch); real PoolManager initializes a DYNAMIC_FEE pool with `hooks = hook`; mint an LDF-shaped
   SFPM/Panoptic seller position; run equal swap volume under a LOW-vol config vs a HIGH-vol config;
   assert the position's accrued premium (`collected`/premium accumulator) is HIGHER under the higher
   adaptive fee — proving the hook controls premia on LDF-shaped positions. (If the full Panoptic mint
   plumbing is too heavy for one increment, split: cover 1-5 first, then this as a dedicated
   integration increment — but it is REQUIRED, not optional.)

## 8. References
- SFPM V4 `_getPremiaDeltas`:1129-1169, `swapInAMM`:742, `initializeAMMPool`:339; PanopticPool:196-197;
  PanopticFactoryV4:118-205 (accepts arbitrary hooked/dynamic pool).
- v4 (all confirmed): IHooks.beforeSwap:103; Hooks.sol flags:28-43, validate:110, callHook:130-134,
  96-byte return:257; LPFeeLibrary DYNAMIC_FEE_FLAG:15/OVERRIDE_FEE_FLAG:19/MAX_LP_FEE:25;
  StateLibrary POOLS_SLOT:11, _getPoolStateSlot:324; Slot0:8-9,36-51; IExtsload:9; BeforeSwapDelta.ZERO.
- Ported: RealizedVolatilityMod (write_timepoint:127, get_average_volatility:222),
  RealizedVolatilityLib (slot-parameterized buffer ops), CallbackRealizedVolatilityLib (stateful path),
  DynamicFeeMod / AdaptiveFee (get_fee), AlgebraFeeConfiguration (pack).
- todo.md:173-182 (PriceSetterHook + CallbackRealizedVolatilityLib requirement), :61 (builderCode/17).
