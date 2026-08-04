# Phase 22: Live Stochastic Drivers — Research

**Researched:** 2026-08-02
**Domain:** Uniswap v4 hook-driven realized-volatility oracle; anvil node cheats (storage + clock);
Haskell (GHC 9.10.3) JSON-RPC drivers; verbatim/pinned cross-track import
**Confidence:** HIGH on everything measured on this machine and read out of source; MEDIUM on the two
items that could not be executed without importing plank-track files (the `InitSwappableRig` compile
and the end-to-end cheat-swap run).

---

<user_constraints>
## User Constraints (from `22-CONTEXT.md`)

### Locked Decisions

**DRIV-01 ARCHITECTURE — the roadmap's wording is SUPERSEDED (user decision).**
The roadmap's SC-1 says the driver "drives `RealizedVolatilityMod.writeTimepoint(uint32,int24)` once
per step". That is exactly the offchain intervention the user does NOT want, and it is superseded.
User's stated intent, verbatim: *"by setting prices and moving across time the timepoints will write
themselves on the Hook. This is the intended thing, such that the only thing a client can do is query
the DB api. There must be an init pool script and from there one can run write_price, and create_order
and realizedVol works with no offchain intervention."*
**Consequence:** there is NO new `RealizedVol.*` offchain client module. DRIV-01 is satisfied by making
the hook fire, not by calling the vol module. The "focused research pass on the E3 side" the roadmap
flags (a `writeTimepoint` client) is CANCELLED by this decision.

**The cheat-swap pattern (user's design for entering the hook).**
*"we need a cheat for swaps — a swap that allows us to enter the swap thing without changing the price
by the swap, but by our actual price specified on the write_price argument. So it can enter the hook.
But this is an artifact that must be generated off chain within the write_price."*
Intended per-step sequence:
1. `write_price` cheats slot0 to the desired tick (existing `anvil_setStorageAt` flow, unchanged)
2. a **minimal-amount swap** executes purely to trigger `beforeSwap`
3. the hook reads the **pre-swap** tick — i.e. the cheated one — and writes THAT timepoint
4. the swap's own price impact is irrelevant; the next step re-cheats slot0

**UPSTREAM GATE — issue #17: RESOLVED 2026-08-02, gate is OPEN.** PR #18 merged to `develop` @ `2039f27`.
`InitSwappableRig.s.sol` runs AFTER `DeployDynamicFeeHook.s.sol`, env `POOL_MANAGER`/`HOOK`/`TOKEN0`/
`TOKEN1`, no `--ffi`, `--broadcast` required. Approvals go **deployer → routers**, NOT deployer →
PoolManager. Do not re-approve the manager.

**The five guard answers — BINDING constraints on the driver:**
- **G1 — same-second repeats:** the write guard is **one timepoint per distinct uint32 TIMESTAMP;
  blocks are irrelevant** (`RealizedVolatilityStateLib.plk:114`). Anvil mines several blocks per
  second, so two swaps in different same-second blocks silently no-op the second write (no E3; E5 +
  fee still served). **The driver MUST advance the clock ≥1s between writes it expects recorded, and
  E3 is the ground truth of what landed** — never the swap count. Stride ≥ 1s is a correctness
  requirement, not a preference.
- **G2 — non-monotonic timestamps: NOT guarded.** The Algebra-ported oracle assumes a non-decreasing
  u32 clock; a backwards clock corrupts window math **silently**. We own clock monotonicity. This
  vindicates the fail-loudly-before-sending decision.
- **G3 — arbitrary cheated tick jumps: safe.** The oracle measures tick deltas; a cheated jump is
  indistinguishable from a traded one. The cheat-swap pattern is confirmed sound.
- **G4 — the real hazard is liquidity-accounting desync.** Cheat-moves never CROSS ticks, so the rig
  must hold **ONLY the one full-range position**. The cheat domain must be pinned to ticks **strictly
  inside [−887260, +887260]**.
- **G5 — slot0 hygiene:** write `sqrtPriceX96` AND `tick` **consistently**
  (`sqrtPrice = getSqrtPriceAtTick(tick)`) in the same word, and **preserve bits ≥184**
  (protocolFee/lpFee). Also: a cheat near the bottom of the range **inverts a hardcoded probe
  direction** — pick `zeroForOne`/`sqrtPriceLimitX96` relative to the cheated price.

**Consequences this phase MUST handle:** the current rig is STALE (F2 changed `TICK_SPACING` 10 → 20);
a **re-pin is required** (`VolOrderManagerMod.plk` F1 rewrite, `DeployDynamicFeeHook.s.sol` F2, plus
`InitSwappableRig.s.sol` ADDED to `offchain/rig/import-paths.txt` + `IMPORT-PIN.md`, re-imported the
same verbatim/pinned way Phase 20 did). **F1's `targetVega@128..255 unmasked top` should be confirmed
compatible with our u96@128..223 packing rather than treated as a layout change.**

**Timestamps:** *Fixed stride from the seeded `INIT_TS`* — each step is `INIT_TS + k*stride`.
Deterministic, replayable from the recorded seed, monotonic by construction, independent of wall clock
and block timing. With the hook writing timepoints, the stride governs how far the driver advances
chain time between steps (`evm_increaseTime`/`evm_mine`) rather than a `uint32` argument.

**Non-advancing timestamp:** *Fail loudly before sending*, client-side, with an attributable message.

**Specific ideas (binding):** "The only thing a client can do is query the DB api" — the offchain side
observes, the chain computes. No client-side `writeTimepoint`. Both price drivers stay:
`write_price`/PriceSetterHook is ADDED beside, never replaced.

### Claude's Discretion
- Where the swap-calldata artifact lives in `write_price`'s return/type surface.
- Stride value and the concrete chain-time advance mechanism.
- Evidence-artifact shape and mid-run failure policy — NOT YET DISCUSSED. The planner should follow
  Phase 20/21 precedent: committed provenance-bearing artifacts, loud failure with tx hashes, one
  documented command, recorded seed.

### Deferred Ideas (OUT OF SCOPE)
- The v6.0 subgraph indexing this phase's event stream — queued milestone (issue #14).
- Whether `write_price`'s slot0 cheat should eventually be replaced by real price-moving swaps — out
  of scope; the cheat-swap pattern deliberately keeps price control offchain.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description (REQUIREMENTS.md) | Research Support |
|----|-------------------------------|------------------|
| **DRIV-01** | "The stochastic price path drives `RealizedVolatilityMod.writeTimepoint(uint32,int24)` per step against the rig, each write emitting E3 `TimepointWritten` (the existing `write_price` flow stays available, unchanged)" | **Mechanism superseded by CONTEXT** — the hook self-writes. §2 (the pool-mismatch BLOCKER and the composition recipe that fixes it), §4 (`PoolSwapTest.swap` calldata, verified `cast` encoding), §5 (clock control, measured), §6 (slot0 hygiene — already satisfied), §7 (E3 decode, which does not exist yet). The *outcome* — one E3 per step carrying the submitted tick — is unchanged and is what §7 makes checkable. |
| **DRIV-02** | "Stochastic V2 VolOrder creation runs against the rig — single + batch under the V2 ABI — with the preview/readback consistency check (incl. targetVega) passing live and E1 v2 observed under the pinned topic0" | §3 (the F1 layout question — resolved: no client change), §8 (mixed-batch and N=0 exercises the generator does NOT currently produce), §9 (evidence artifact + failure policy). The client is already V2-complete after Phase 21; DRIV-02 is exercise + evidence, not new encoding. |
</phase_requirements>

---

## Summary

Three things dominate the plan.

**First, a blocker the context did not know about.** `write_price` cannot cheat the pool the hook is
bound to. `PriceSetterHookScript` stands up its **own second `PoolManager`** (recorded in the manifest
as `PriceSetterPoolManager`) and binds `PriceSetterHook` to a pool on *that* manager, with currencies
`(address(0), address(1))`, static fee 3000, tickSpacing 60 and **zero liquidity**. The
`DynamicFeeHook` lives on a *different* `PoolManager`, on a dynamic-fee pool with `MinimalToken`
currencies and (post-F2) tickSpacing 20. So the per-step sequence in CONTEXT — cheat slot0, then swap
into `beforeSwap` — writes to one pool and swaps on another. This is the phase's highest-severity
finding. It is fixable **entirely inside `offchain/`** with no new Solidity and no new upstream issue:
compose the cheated word from `PoolManager.extsload(slot)` (target pool's fee bits, preserved) and
`PriceSetterHook.packSlot0For(tick)` (the audited on-chain `getSqrtPriceAtTick` + tick pack). Details
and the exact recipe are in §2.

**Second, everything CONTEXT asked to be *confirmed* confirms, and one thing it feared is already
fine.** F1's `targetVega@128..255 unmasked top` is a *read region*, not a widened field — the batch
loop reads `@evm_shr(128, word)` with no mask and `target_vega_fits_packed` rejects anything past
2^96−1 (§3). Our Phase-21 packing (u96 at 128..223, bits ≥224 zero) is correct as shipped: **no client
change**. G5's "preserve bits ≥184" is *already* satisfied by `packSlot0For`, which reads the current
word and only overwrites bits 0..183 (§6) — the suspicion that the current implementation zeroes the
fee bits is FALSE. And the re-pin delta is exactly two changed files plus one added file, with nothing
else moved (§1).

**Third, the clock is the whole ballgame for DRIV-01, and it was measured, not assumed.** On this
machine (anvil 1.5.1), three back-to-back transactions produced block timestamps 1700000013,
1700000014, **1700000014** — two blocks sharing one second, which is exactly the G1 no-op. The right
lever is `evm_setNextBlockTimestamp` (absolute, deterministic, and anvil *itself* rejects a backwards
value with a named error), **not** `evm_increaseTime` (wall-clock-relative; returns a raw offset word,
which is why `InitSwappableRig` calls it through a low-level `address(vm).call`). `anvil_setStorageAt`
does not mine a block and survives an interleaved `evm_setNextBlockTimestamp`, so the per-step sequence
composes cleanly (§5).

**Primary recommendation:** Re-import + re-pin from `2039f27` first (37 paths), extend `deploy-rig.sh`
with the `InitSwappableRig` step and the two new router addresses, then build **one** new offchain
capability — a `cheat_and_swap` step composed of `anvil_setStorageAt` (composed word) →
`evm_setNextBlockTimestamp(t_k)` → `PoolSwapTest.swap(...)` from the **deployer** account — and prove
what landed by decoding E3 out of the swap receipt's logs, never by counting swaps.

---

## 1. The re-import / re-pin — measured delta

**Method:** `git fetch origin develop` (→ `2039f2783598866a337115df4a265a75e8842e82`), then
`git diff --stat 9f5ccba 2039f27 -- $(cat offchain/rig/import-paths.txt)`. Current tree verified clean
against the old pin first: `offchain/rig/verify-import.sh` → *"SC-1 OK: 36 imported paths
content-identical to 9f5ccba… and sha256-matched to IMPORT-PIN.md"*, exit 0.

**Delta inside the pinned set — exactly two files (HIGH):**

| Path | Change | New sha256 (`git show 2039f27:<path> \| sha256sum`) |
|------|--------|------------------------------------------------------|
| `foundry-scripts/deploy/DeployDynamicFeeHook.s.sol` | F2: `int24 constant TICK_SPACING = 10` → `20` + a 3-line comment | `f282e0942d0f013e04541957d74245bcd932bb3cbdb4f8628812bea219082fa0` |
| `src/modules/pos_spec/VolOrderManagerMod.plk` | F1: the stale V1 input-word comment block replaced by the V2 one (comment only; **no executable line changed** — verified by reading the batch loop) | `d9d4e228da9f96d96d40d526f851bcc5f10b3c54e4a3bb04e286fba66caa5c42` |

**To be ADDED to the pin set — exactly one file (HIGH):**

| Path | New sha256 |
|------|------------|
| `foundry-scripts/deploy/InitSwappableRig.s.sol` (199 lines) | `fba060b988086e3c81d150fefd9e43e1bcbf0ec1b5041917fd8cff8efcbb75e1` |

**Nothing else moved.** `git diff --stat 9f5ccba 2039f27 -- foundry-scripts/ src/ notes/` shows only
those three paths plus `notes/VOLATILITY_INSTRUMENTS.md` (+753 lines) — and that file is **not** in
`import-paths.txt` (it is the Lean4/math track's doc). Do not import it; do not let a broad
`notes/` glob pull it in.

**Path count goes 36 → 37.** `verify-import.sh` prints the count it read, so the number is
self-updating; `IMPORT-PIN.md` needs three row edits (two digest updates, one new row) plus the ref and
subject lines. `check-upstream.sh`'s `REQUIRED_PATHS` array should gain `InitSwappableRig.s.sol` so the
gate cannot go green on a develop that lacks it.

**Transitive closure of the new file — verified present, no further imports needed (HIGH):**
`InitSwappableRig` imports `univ4-core/test/PoolSwapTest.sol` and
`univ4-core/test/PoolModifyLiquidityTest.sol`. `remappings.txt:33` maps
`univ4-core/ → lib/panoptic-v2-core/lib/v4-core/src/`, and all three of
`…/src/test/PoolSwapTest.sol`, `…/src/test/PoolModifyLiquidityTest.sol` and
`…/test/utils/CurrencySettler.sol` (PoolSwapTest's own `../../test/utils/` import) exist in the
working tree. Everything else it imports (`PlankDeployBase`, `IPoolManager`, `IHooks`, `PoolKey`,
`PoolId`, `Currency`, `TickMath`, `BalanceDelta`) is already on the branch.

**But it is NEW COMPILATION SURFACE (MEDIUM).** `grep -rln 'PoolSwapTest\|PoolModifyLiquidityTest'
test/ src/ foundry-scripts/` returns **nothing** — no tracked file has ever pulled the routers into a
build. `forge build --via-ir` currently exits 0 on this tree (measured), but that says nothing about
the routers under `--via-ir`. **Make "import → `forge build --via-ir` exits 0 → `forge script … --tc
InitSwappableRig` runs" an early, separately-verified task**, and re-record `FORGE-DELTA.md` the way
Phase 20 did (its post-import baseline was 85/27/112).

---

## 2. `InitSwappableRig.s.sol` — verified against CONTEXT, and the pool-mismatch BLOCKER

### 2.1 The file, as read from `origin/develop`

CONTEXT's summary is **accurate on every point I could check**, with two refinements worth writing
into the plan.

| CONTEXT claim | Verdict | Evidence |
|---|---|---|
| Env contract `POOL_MANAGER`, `HOOK`, `TOKEN0`, `TOKEN1` | ✅ exact | four `vm.envAddress` calls, all REQUIRED (no `envOr` default) |
| Deploys vendored `PoolSwapTest` + `PoolModifyLiquidityTest`, nothing authored | ✅ | `new PoolSwapTest(IPoolManager(pm))`, `new PoolModifyLiquidityTest(...)` |
| Funds + approves **deployer → routers**, not the manager | ✅ | `_fund()` approves `swapR` and `liqR` only; comment names `CurrencySettler.settle → transferFrom` pulled by the router |
| ONE full-range position, ±887260, L = 1e21 | ✅ | `TickMath.minUsableTick(20)`/`maxUsableTick(20)`, `LIQUIDITY = 1e21`, `salt: bytes32(0)` |
| Probe swap asserted on `lastTimepointTimestamp` strictly advancing | ✅ | `require(tsAfter > tsBefore, "probe swap wrote NO timepoint (same-second B1 no-op?) - rig NOT proven")` |
| New manifest lines: swapRouter, modifyLiquidityRouter, tick range, liquidity, probe deltas, ts before/after | ✅ exact, 9 `console.log` lines | see §2.2 |
| `--broadcast`, no `--ffi` | ✅ | pure Solidity; the doc comment states both |

**Refinement 1 — it advances the clock itself, by 5 seconds.** Step 0 does `vm.warp(block.timestamp+5)`
and, when `block.chainid == 31337`, an `evm_increaseTime` of 5 through a low-level
`address(vm).call(abi.encodeWithSignature("rpc(string,string)", …))` — *"anvil returns the raw offset
word for evm_increaseTime, which fails the typed cheatcode's bytes-decode."* I independently confirmed
that raw-offset behaviour (§5). Consequence for us: **after `InitSwappableRig` the chain clock is
`deploy_ts + 5` at minimum, and its probe swap has already consumed one timestamp.** The driver's first
step must be strictly later than that.

**Refinement 2 — it does more asserting than CONTEXT credits it with.** It requires `t0 < t1`
(sorted), requires code at all four addresses, and — most usefully for us — **reconstructs the PoolKey
and requires it hash to `hook.poolId()`**: `require(abi.decode(ridPid,(bytes32)) == pid,
"reconstructed PoolKey does not hash to the hook's bound poolId (key drift)")`. That is a
pre-registered key-drift detector. **The driver must reconstruct the identical key**
(`currency0, currency1, fee = 0x800000, tickSpacing = 20, hooks = HOOK`) or `beforeSwap`'s own
`require(pool_id == @evm_sload(SLOT_HOOK_POOL_ID))` will revert the swap. `TICK_SPACING = 20` is a
hard constant in *both* scripts; the manifest's `pool.tickSpacing` is the value to read at runtime and
the value that proves the rig was rebuilt.

It also reads back `getAverageVolatility(int24(0), uint32(target))` and requires 32 bytes — so a
passing run proves the vol series is *servable*, not just written.

### 2.2 The nine console lines (the manifest cross-check surface)

```
swapRouter            : 0x…
modifyLiquidityRouter : 0x…
tickLower             : -887260
tickUpper             : 887260
liquidity             : 1000000000000000000000
probe delta0          : …
probe delta1          : …
timepoint ts before   : …
timepoint ts after    : …
```

`deploy-rig.sh`'s `check()` helper greps a label prefix and extracts `0x[0-9a-fA-F]{40}` — so
`'swapRouter            :'` and `'modifyLiquidityRouter :'` work verbatim. On the broadcast side both
routers are plain `new X(...)` under `startBroadcast`, so foundry records them as top-level `CREATE`
**with a populated `contractName`** — key them by name (`select(.contractName=="PoolSwapTest")`), the
`PriceSetterHook` pattern, *not* the nameless-Plank-CREATE pattern.

`timepoint ts after` is a free, machine-readable proof line: assert it > `timepoint ts before` in
`deploy-rig.sh` the way Step 6 asserts `seeded : true` today. That turns the script's internal
`require` into a rig-level acceptance check we own.

### 2.3 🔴 BLOCKER — `write_price` cheats the WRONG pool

**Measured, not inferred.** From `offchain/rig/deploy-rig.sh` and the two deploy scripts:

| | DynamicFeeHook pool | PriceSetterHook pool |
|---|---|---|
| PoolManager | `contracts.PoolManager` (`new PoolManager` inside `DeployDynamicFeeHook`) | `contracts.PriceSetterPoolManager` (**a second `new PoolManager`** inside `PriceSetterHookScript`) |
| currency0 / currency1 | two `MinimalToken`s | `address(0)` / `address(1)` |
| fee | `0x800000` (DYNAMIC) | `3000` (static) |
| tickSpacing | 20 (post-F2; 10 in the standing manifest) | 60 |
| liquidity | 1e21 full-range (after `InitSwappableRig`) | **none, by design** |
| hook flags | `BEFORE_SWAP` | `BEFORE_INITIALIZE \| AFTER_INITIALIZE` |

`PriceSetterHook.beforeInitialize` records `slot0Slot = StateLibrary._getPoolStateSlot(id)` for **its
own** pool inside **its own** manager, and `write_price` writes exactly there
(`anvil_setStorageAt(pool_manager_from_the_hook, hook.slot0Slot(), hook.packSlot0For(tick))`).
`DynamicFeeHook.beforeSwap` reads `keccak(poolId ‖ POOLS_SLOT)` out of **its** manager
(`read_current_tick`, `DynamicFeeHook.plk:78-92`). **Two different storage slots in two different
contracts.** Cheating one and swapping on the other records the *un-cheated* tick forever — and it
fails silently: E3 still fires, the receipt is status 1, only the tick value is wrong. Exactly the
class of defect this workstream exists to kill.

Note also that `PriceSetterHook`'s pool is uninhabitable for the cheat-swap pattern on its own terms:
no beforeSwap flag, no liquidity, and `currency0 = address(0)` (native ETH).

**Recommended fix — compose the word offchain, zero new Solidity, no new upstream issue (HIGH
confidence in the mechanism; MEDIUM that it runs first try, because it was not executed end-to-end):**

```
slot   = keccak256( poolId(32 bytes) ‖ uint256(6) )          -- POOLS_SLOT = 6
W_now  = eth_call PoolManager.extsload(bytes32) [slot]        -- selector 0x1e2eaeaf
W_low  = eth_call PriceSetterHook.packSlot0For(int24)[tick]   -- sqrtPriceX96 | tick<<160 | PSH fee bits
W_new  = (W_now .&. complement (2^184 - 1)) .|. (W_low .&. (2^184 - 1))
anvil_setStorageAt(PoolManager, slot, W_new)
```

Why each half:
- `POOLS_SLOT = 6` and the `keccak(poolId ‖ POOLS_SLOT)` derivation are **already documented in the
  imported source** (`DynamicFeeHook.plk:74-76` — *"LPFeeLibrary.OVERRIDE_FEE_FLAG;
  StateLibrary.POOLS_SLOT (v4-core, confirmed by review)"*). This is consuming a pinned constant, not
  re-deriving a layout. Verified reproducible: `cast keccak <poolId><0x…06>` →
  `0xeeab88fa749045a9c1259e79a7bd845c2ee229c1a4e0702e880b8251c4c6dd16` for the standing manifest's
  poolId.
- `packSlot0For` is `view`, pure in its low 184 bits with respect to which pool the hook is bound to:
  bits 0..159 = `TickMath.getSqrtPriceAtTick(newTick)`, bits 160..183 = `newTick` two's-complement.
  Only bits ≥184 are the PSH pool's own fee bits, and the mask discards them. **This reuses the
  audited on-chain TickMath instead of porting it to Haskell** — see §"Don't Hand-Roll".
- Masking at 184 preserves the *target* pool's `protocolFee` (184..207) and `lpFee` (208..231) — G5,
  satisfied by construction rather than by care.
- `packSlot0For` reverts `InvalidTick` outside `[MIN_TICK, MAX_TICK]`, a free second net under the
  client-side G4 domain guard.

**This also keeps the user's "both price drivers stay" constraint literally true**: `PriceSetterHook`
stays deployed, stays in the manifest, stays exercised on every step — now as the tick→sqrtPrice
oracle as well as its own pool's cheat target. `write_price` as it exists today is not deleted or
re-pointed; the new capability is added beside it.

**Alternatives, for the record:**

| Instead of | Could do | Why not |
|---|---|---|
| offchain composition | file another plank issue for a `packSlot0ForPool(bytes32,int24)` helper on the hook | Re-blocks the phase on cross-track turnaround; CONTEXT explicitly says planning may proceed and the gate is open. Keep as the fallback if the composition measurably fails. |
| offchain composition | port `TickMath.getSqrtPriceAtTick` to Haskell | 20+ magic constants, a bit-exactness obligation with no independent oracle in-repo, and a whole new differential-test burden. See §"Don't Hand-Roll". |
| offchain composition | re-deploy `PriceSetterHook` bound to the DynamicFeeHook pool | Impossible — a v4 pool key names exactly one hook address and the flag bits differ. |

---

## 3. F1's `targetVega@128..255` vs our u96@128..223 — **compatible, no client change** (HIGH)

CONTEXT asked for this to be confirmed rather than assumed. It is confirmed, in the executable code,
not just the comment.

`src/modules/pos_spec/VolOrderManagerMod.plk` on `2039f27`, batch loop:

```plank
let word = @evm_calldataload(100 + i * 32);
let order = build_vol_order(
    @evm_shr(16, word) & 0xFFFFFFFFFFFFFFFFFFFFFF,   // strike, MASKED to u88
    @evm_shr(104, word) & 0xFFFFFF,                  // width, MASKED to u24  (V2: now interior)
    word & 0xFFFF,                                    // skew, MASKED to u16
    @evm_shr(128, word)                               // targetVega, NO MASK
);
```

`@evm_shr(128, word)` with no mask reads bits **128..255** — 128 bits. It is a *read region*, not a
field width. The validator then applies the width:
`target_vega_fits_packed` = `vega_target_is_complete(self) & (self.vega <= 0xFFFFFFFFFFFFFFFFFFFFFFFF)`
(`VolOrderValidationLib.plk`), i.e. `vega ∈ [1, 2^96−1]`. Any dirty bit at 224..255 inflates the value
past 2^96−1 and the tuple is REJECTED (batch: skipped; strict: revert). The V1 comment gave that role
to `width`; F1 moved it to `targetVega`. Nothing about the accepted-input set changed.

Our shipped client (`offchain/lib/VolOrder/Encoding.hs`, RPIN-02, verified in `21-VERIFICATION.md`)
packs `targetVega` at 128..223 with bits ≥224 zero **by construction** and rejects out-of-range values
client-side. That is precisely the accepted subset of the 128..255 read region.

**Verdict: our client is correct as shipped. This is a documentation correction upstream, not a layout
change here. There is no highest-severity finding hiding in F1.** The one thing worth doing is a
regression assertion the phase can afford: keep/point at 21-01's `rpin02_input_word_layout` and note
in-file that 128..255 is the *read* region — so a future reader does not "fix" the packer to widen the
field.

---

## 4. Executing a swap from Haskell

### 4.1 Calldata shape — verified with `cast`

```
swap((address,address,uint24,int24,address),(bool,int256,uint160),(bool,bool),bytes)
```
selector `0x2229d0b4` (`cast sig`, measured). A full encode round-trips through `cast calldata` today:

```bash
cast calldata "swap((address,address,uint24,int24,address),(bool,int256,uint160),(bool,bool),bytes)" \
  "($TOKEN0,$TOKEN1,8388608,20,$HOOK)" "(true,-1000000,4295128740)" "(false,false)" "0x"
```
→ produced a well-formed 10-word payload with `0x800000` in the fee slot, `0x14` (20) in tickSpacing,
`-1000000` sign-extended, and `0x1000276a4` (= `MIN_SQRT_PRICE + 1`) as the limit. **This composes
with the existing `cast`-shelling pattern verbatim** (`PriceSetter.Encoding.encode_call` is
`readProcess "cast" ("calldata" : signature : args)`), so no new encoding machinery and — importantly
— **no 8-hex selector literal**, which `sc3_literal_purge` would reject (§9.3).

### 4.2 Who sends it

**The `deployer` account, not `sender`.** `InitSwappableRig._fund` mints to and approves *from*
`vm.addr(deployerKey())` = anvil index 0 = `accounts.deployer` in the manifest
(`PlankDeployBase.deployerKey()` = `vm.envOr("PRIVATE_KEY", vm.deriveKey(ANVIL_MNEMONIC, 0))`).
`accounts.sender` (index 1) has no balance and no allowance. Sending the swap from `sender` fails
inside `CurrencySettler.settle → transferFrom` — deep in the unlock callback, with an unhelpful
message. Keep `sender` for orders (unchanged) and use `deployer` for swaps.

### 4.3 Direction and price limit — the honest reading of G5

`Pool.swap`'s bound checks are: `zeroForOne` requires
`MIN_SQRT_PRICE < sqrtPriceLimitX96 < slot0.sqrtPriceX96`; `!zeroForOne` requires
`slot0.sqrtPriceX96 < sqrtPriceLimitX96 < MAX_SQRT_PRICE`.

I computed `getSqrtPriceAtTick` at the domain boundaries:

| tick | sqrtPriceX96 |
|---|---|
| −887272 (`MIN_TICK`) | 4 295 128 738 (`MIN_SQRT_PRICE` = 4 295 128 739) |
| **−887260 (G4 floor)** | **4 297 706 459** |
| 0 | 79 228 162 514 264 337 593 543 950 336 |
| **+887260 (G4 ceiling)** | **1 460 570 142 277 968 647 115 256 636 451 690 560 445 204 354 453** |
| +887272 (`MAX_TICK`) | 1 461 446 703 478 070 267 223 796 146 550 585 562 556 172 646 207 |

So **the bound check never inverts** inside the G4-legal domain: `MIN_SQRT_PRICE + 1 = 4 295 128 740` is
comfortably below 4 297 706 459 (one tick is ≈ 0.005 % ≈ 214 000 units at that price, so there is no
knife edge). The hardcoded `zeroForOne: true, sqrtPriceLimitX96: MIN_SQRT_PRICE + 1` that
`InitSwappableRig`'s probe uses is bound-safe for every legal cheated tick.

**But G5's warning is still right, for a different mechanism: reserve exhaustion.** With one full-range
position, at a tick near the floor the position holds essentially all token0 and ≈ 0 token1 — at
tick −887259 the token1 side of a 1e21 position is `L·(√P − √P_lower)` ≈ **0.0003 wei**. A
`zeroForOne` swap there buys token1 that is not there: it does not revert on the price bound, it
degenerates to `amount1 ≈ 0`. Symmetrically near the ceiling for `oneForZero`.

**Recommendation (cheap, so do it):** pick the direction from the cheated tick —
`zeroForOne = tick >= 0`, with `sqrtPriceLimitX96 = MIN_SQRT_PRICE + 1` when true and
`MAX_SQRT_PRICE − 1` when false — and guard the tick domain client-side to
`[−887260 + 1, +887260 − 1]` *before* building any calldata. **Do not assume this is what discriminates
a bug: MEASURE it** (drive one deliberate extreme-tick step and record what actually happens). This
workstream has now had a predicted discriminator refuted twice; §"Common Pitfalls" restates the rule.

### 4.4 Minimal amount

`PROBE_AMOUNT = -1e6` (exact input) against L = 1e21 is `InitSwappableRig`'s own choice and is dust —
reuse it. The deployer holds `1e30 − 1e21` of each token, so ~10^24 steps of headroom. Do not use
`amountSpecified = 0`: v4 reverts `SwapAmountCannotBeZero`, which would abort the whole tx *including*
the timepoint write (`beforeSwap` runs first, but the frame unwinds).

`PoolSwapTest` in the vendored version declares `error NoSwapOccurred()` but **never uses it** — I read
the whole file. So a degenerate-but-legal swap does not revert there. The `deltaBefore == 0` requires
mean the swap must not be nested inside another unlock; a plain EOA→router tx is fine.

---

## 5. Clock control — measured on anvil 1.5.1 (HIGH)

All of the following was executed against a scratch `anvil --silent --port 8546 --timestamp 1700000000`
on this machine.

**G1, reproduced.** Three back-to-back value transfers, reading `block latest --field timestamp` after
each: **1700000013, 1700000014, 1700000014.** Two distinct blocks, one uint32 second. Under the
cheat-swap loop the second one's `rv_write_timepoint` returns `false`, emits no E3, and still serves
E5 + the fee — a silent hole in the series. The guard is verbatim
`if vol_state.lastTimepointTimestamp == now { return false; }`
(`RealizedVolatilityStateLib.plk:114`) — an **equality** test on the u32 timestamp, with no block
number anywhere and no ordering test (hence G2).

**`evm_setNextBlockTimestamp` — the right lever.**
- `cast rpc evm_setNextBlockTimestamp 1700001000` → `null`; the next block (mined by a tx) had
  timestamp exactly `1700001000`. Repeated with `1700002000` → exact again.
- Accepts a **decimal JSON number** (`{"params":[1700003000]}` → `{"result":null}`) and a hex string.
  A plain Haskell `Integer` through `Network.JsonRpc.TinyClient.remote` therefore works — same shape as
  the existing `anvil_set_storage_at = remote "anvil_setStorageAt"`.
- **Anvil rejects a backwards value itself**: `evm_setNextBlockTimestamp 1700000500` after a block at
  1700001000 →
  `error code -32602: Timestamp error: 1700000500 is lower than previous block's timestamp`.
  This is a genuine second net for G2 that CONTEXT's "NOT guarded" (which is about the *oracle*) does
  not mention. **It does not replace the client-side guard** — it fires at send time, not before, and
  it says nothing about the seeded `INIT_TS` vs the chain's starting clock.

**`evm_increaseTime` — avoid.** `cast rpc evm_increaseTime 7` returned **`-85682546`**: an offset
relative to *wall clock*, not a timestamp, exactly as `InitSwappableRig`'s comment says. It works
(`+7` landed), but it is relative and its return value is unusable, which makes it strictly worse than
an absolute setter for a replayable run.

**`anvil_setStorageAt` composes cleanly.** Measured: it does **not** mine a block (height unchanged
5→5), the written value is immediately readable, and a `setNextBlockTimestamp` issued *before* a
`setStorageAt` still applied exactly to the block the following tx mined. So the per-step order
`setStorageAt → setNextBlockTimestamp → swap tx` is safe, and so is the reverse.

**⚠️ The seeded-`INIT_TS` reconciliation CONTEXT asks for has a wrinkle.** anvil's chain clock is
anchored to **wall clock** (with `--timestamp` supplying a fixed offset at genesis, not a frozen
clock — after 13 s of real time the first block was at `1700000013`, not `1700000000`). Today
`deploy-rig.sh` starts plain `anvil --silent`, so chain time ≈ real time (≈ 1.78 × 10⁹ in Aug 2026),
while `INIT_TS = 1700000000` is ~2.7 years in the *past*. Two consequences:

1. `INIT_TS` seeds `RealizedVolatilityMod` (the module-global, poolId = 0 series) — but the **hook**'s
   buffer is seeded at `uint32(block.timestamp)` inside `DeployDynamicFeeHook` (`initializeHook(...,
   uint32(block.timestamp))`). **The E3 series this phase produces is anchored to chain time, not to
   `INIT_TS`.** A driver that computes `INIT_TS + k*stride` would try to set timestamps in the past and
   anvil would reject them.
2. **Recommended:** add `--timestamp "$INIT_TS"` to the `anvil` invocation in `deploy-rig.sh`
   (`offchain/` — our territory; verified working). Then both series share one deterministic origin and
   the driver's `t_k` are absolute, reproducible numbers. Cost: the rig's on-chain clock changes, so
   re-run SC-5's double-deploy reproducibility check. If the planner prefers not to touch the rig, the
   fallback is: read the chain's current `block.timestamp` at driver start and record it as part of the
   run's seed material (`t_0 = now + stride`), which is replayable-in-shape but not in absolute
   timestamps.

**Recommended stride:** `stride = 1` is sufficient for correctness (the guard is equality) and keeps
the tick series densely sampled. Something like `stride = 12` (mainnet-ish block cadence) makes the
σ² window arithmetic look realistic and is equally deterministic. Either way, **assert
`t_k > t_{k-1}` client-side before any RPC**, and record the stride in the evidence artifact.

---

## 6. slot0 hygiene (G5) — already satisfied; the CONTEXT suspicion is FALSE (HIGH)

`PriceSetterHook.packSlot0For` (`src/modules/protocol_integrations/PriceSetterHook.sol:103-107`):

```solidity
function packSlot0For(int24 newTick) external view returns (bytes32) {
    Slot0 current = readSlot0();
    uint160 newSqrtPriceX96 = TickMath.getSqrtPriceAtTick(newTick);
    return Slot0.unwrap(current.setTick(newTick).setSqrtPriceX96(newSqrtPriceX96));
}
```

- `sqrtPriceX96` is **derived from the tick**, so the two are consistent by construction — G5's first
  half.
- It starts from `current` and both setters are masked read-modify-writes
  (`Slot0Library.setTick`/`setSqrtPriceX96` in v4-core), so **bits ≥184 are carried through untouched**
  — G5's second half. The file's own doc comment says so: *"fee bits preserved."*

Layout confirmed against `univ4-core/types/Slot0.sol`:
`sqrtPriceX96 [0,160) | tick [160,184) int24 two's-complement | protocolFee [184,208) | lpFee [208,232) | empty [232,256)`.

**So there is no G5 fix to make.** The only thing to preserve is this property while re-targeting the
write (§2.3): masking `packSlot0For`'s output at 184 and OR-ing the *target* pool's high bits keeps
both halves of G5 true for the pool that now matters. On today's rig those bits are zero anyway
(`protocolFee = 0`; a dynamic-fee pool stores `lpFee = 0` at initialize), which is exactly why zeroing
them would be a **latent** bug that never shows up until someone sets a protocol fee — G5's own
framing.

`readSlot0()` carries `onlyBound`; `PriceSetterHook` is bound at deploy, so the read never reverts on a
live rig. A `NotBound` revert surfaces through `decode_address`'s `either fail pure` as an *uncaught*
`IOException`, not a `Left` — a documented characteristic of `PriceSetter.Rpc` worth carrying into the
new code path's error handling (§9.2).

---

## 7. The E3/E5 observation surface

### 7.1 What exists, what does not

- `offchain/lib/VolOrder/Decode.hs` decodes **E1 only**. It exports the reusable primitives
  `hex_to_integer`, `data_word :: Int -> HexString -> Integer`, `be_integer`.
- **There is no E3 decoder, no E5 decoder, and no signed-integer decoding anywhere in `offchain/`.**
  `data_word` returns an unsigned `Integer`; E3 carries `int24 tick`, `int24 averageTick`, `int56
  tickCumulative`. Two's-complement sign extension from a 32-byte word is new (small, but new, and it
  is the kind of thing that silently returns `16777016` instead of `-200`).

### 7.2 E3, exactly

```
TimepointWritten(bytes32 indexed poolId, uint32 timestamp, int24 tick,
                 uint88 volatilityCumulative, int24 averageTick, int56 tickCumulative)
topic0 = 0x44d3c76a584327df3a91e46e185e97959195c01202945078eebb23b19c161415
```
Emitter (`VolEventsLib.plk:62-77`): `@evm_log2(buf, 160, TOPIC0_TIMEPOINT_WRITTEN, pool_id)`
→ **exactly 2 topics**, `[topic0, poolId]`, and **exactly 160 bytes = 5 data words** in order
`[timestamp, tick, volatilityCumulative, averageTick, tickCumulative]`, with `signextend` already
applied to the signed ones on the emit side (so the word is a 256-bit sign-extended value — decode by
`if w >= 2^255 then w - 2^256 else w`, which handles all three signed fields uniformly).

Mirror the E1 decoder's discipline exactly: topic0 as an **argument** (from `pin_topic0 rig
"TimepointWritten"`), a `>= 160`-byte length guard (`data_word` silently returns 0 past the end — the
same trap RPIN-04 documented), and a 2-topic pattern match.

### 7.3 E5, for the SC-1 completeness argument

```
FeeApplied(bytes32 indexed poolId, uint88 sigma, uint24 fee)
topic0 = 0x25ea110aac3c0d92bd950f999d2fafed41a751afe912d690a3e721a6eb5a84df
```
2 topics, 2 data words. **E5 fires on every swap, including B1 no-ops; E3 fires only on a real write.**
So `count(E5) − count(E3)` over a run is a *direct, on-chain measurement of how many steps the G1 guard
ate.* That is the cheapest possible falsifiable check of the clock discipline, and it is free — both
logs are in the same receipt. Recommend making `E5 == E3 == steps` an explicit assertion.

### 7.4 How to read them

Receipt logs suffice — no `eth_getLogs`. `TxReceipt`'s `receiptLogs :: [Change]` already carries every
log of the swap tx (ERC20 transfers, PoolManager `Swap`, hook E3 + E5). Filter on
`changeAddress == DynamicFeeHook` **and** `topic0 == pin` **and** `topic1 == pool.poolId`. The address
filter matters: the module-global `RealizedVolatilityMod` emits the *same* topic0 with
`poolId = bytes32(0)` (`DATA_CONTRACT.md` §2 — the sentinel is permanent and first-class), so a
topic0-only filter would conflate two series the moment anything drives the module.

`DATA_CONTRACT.md` also guarantees `FeeApplied.logIndex < Swap.logIndex` (nearest-preceding adjacency)
and `FeeApplied.fee == Swap.fee` — a join invariant available for free if the phase wants a second
independent witness that the hook actually priced the swap.

### 7.5 What SC-1/2/3 need decoded

| SC | Needs |
|----|-------|
| 1 | E3 per step: `receiptStatus == 1`, **exactly one** E3 from the hook address, decoded `(timestamp, tick)` equal to the step the driver submitted (`t_k` and the cheated tick). |
| 2 | E1 v2 (already shipped), plus the receipt-block-pinned `getOrderPacked` readback (already shipped in `verify_mined_order`). |
| 3 | The batch's `(bool,id)` pattern + `orderCount` delta + per-id readback — all already in `create_orders`. What is missing is the *mixed* batch (§8). |

---

## 8. DRIV-02: two exercises the generator does NOT currently produce

Phase 21 left the order client V2-complete, so DRIV-02 is mostly *exercise and evidence*. Two roadmap
success criteria are not reachable by just running `run_order_gen`:

**SC-4 (`N = 0`) never sends anything today.** `run_order_gen` does
`mapM (create_orders owner manager) (chunk max_batch built)`, and `chunk _ [] = []`. A zero-arrival
Poisson tick therefore produces **zero chunks → zero eth_calls → zero transactions**. The 64-byte empty
return — "the single clause in the return contract most likely to break `StochasticOrderGen`" — is
never exercised by the generator path. Phase 21 only ever saw it through `capture-batch-return.sh`'s
`eth_call`.
**Recommendation:** exercise both readings. (a) Assert the generator's `N = 0` path completes cleanly
with zero chunks; (b) call `create_orders owner manager []` **directly** once — its internal preview
`eth_call` returns the 64 bytes and `decode_create_orders_result` turns them into `[]`, then the real
tx mines with status 1 and `orderCount` unmoved. Note a transaction receipt carries **no returndata**,
so the 64-byte fact can only be observed through the `eth_call` half — say so in the plan rather than
writing a check that cannot exist.

**SC-3's mixed batch needs a deliberately-rejected tuple.** The client's own
`pack_vol_order_input` field-width validation rejects out-of-range values *before* sending, so the
rejected tuple must be width-valid and domain-invalid. Phase 21's `capture-batch-return.sh` already
identified and used the discriminator: **`skew = 65535`** (its comment: *"skew = 65535 is the ONLY
input a client can pass that the contract rejects"*), because
`spread_tick_assimetry_is_complete` admits only `[1, 65534]`. Reuse it — it is proven live.
(`strike = 0`, `width = 0` and `targetVega = 0` are also domain-invalid and width-valid; confirm
against `pack_vol_order_input`'s guards before relying on any of them, don't assume.)

---

## 9. The two undiscussed gray areas — concrete recommendations

### 9.1 Evidence-artifact shape

Follow Phase 20/21 precedent exactly: **one committed, provenance-bearing JSON**, written by a shell
script under `offchain/rig/`, asserted over by `cabal test` **without touching the chain**. That is the
pattern that made Phase 21's suite chain-independent (measured green with anvil down) while still
proving live facts.

Recommended: `offchain/rig/driver-run-capture.json`, written by the driver run itself (or by a
`capture-driver-run.sh` wrapper), carrying:

```jsonc
{
  "generatedAt": "...", "chainId": 31337,
  "generatedFrom": "<import ref>",              // 2039f27… — see §9.4, this is the F4 fix
  "rig": { "poolManager": "0x…", "hook": "0x…", "swapRouter": "0x…",
           "poolId": "0x…", "tickSpacing": 20 },
  "seed": { "rng": 123456789, "t0": 1700000005, "stride": 1 },   // the replay key
  "steps": [ { "k": 0, "tick": 37, "expected_ts": 1700000006,
               "txHash": "0x…", "status": 1,
               "e3": { "timestamp": 1700000006, "tick": 37, "volatilityCumulative": …,
                       "averageTick": …, "tickCumulative": … },
               "e5": { "sigma": …, "fee": … } } ],
  "orders": { "single": {...}, "batch": {...}, "mixed": {...}, "n0": {...} }
}
```

Then `cabal test` asserts *over the artifact*: E3 count == step count, every `e3.timestamp` ==
`t0 + k*stride`, every `e3.tick` == the submitted tick, timestamps strictly increasing,
`count(E5) == count(E3)`, statuses all 1, and freshness (§9.4). **Do not** add a chain-touching check
to the suite — that property was hard-won and is explicitly listed as an established pattern in
CONTEXT.

Note the Phase-21 trap: `blockNumber` is **not** a usable provenance field (three from-scratch deploys
gave heights 9, 11, 10). Do not pin it.

### 9.2 Mid-run failure policy

**Recommend: abort loud on the first failure, with the tx hash and the step index, *and* flush the
partial artifact before exiting.**

Reasons, in order of weight:
1. **G2 makes a corrupt series unrecoverable and invisible.** Once a bad timestamp lands, the oracle's
   window math is silently wrong for every subsequent step. Continuing produces evidence that *looks*
   fine and is not. "Complete-and-report-all" is the wrong default for a stateful accumulator.
2. It matches the codebase's existing stance — `create_orders` already `fail`s on the first
   `receiptStatus /= 1` and on the first readback mismatch, and `draw_target_vega` guards before any tx
   is built.
3. Flushing the partial artifact costs nothing and is what makes the failure debuggable — which is the
   only argument the "complete-and-report-all" side actually has.

Carry forward the documented hazard: `fail` inside a `Web3` action surfaces as an **uncaught
`IOException`, not a `Left`** (documented in `PriceSetter.Rpc` and `StochasticOrderGen.Rpc`), and it can
fire mid-fold after earlier transactions have mined. So the flush must be in the exception path
(`Control.Exception.bracket`/`finally` in `Main`), not merely after a happy return.

**Guard client-side, before every send:** `t_k > t_{k-1}`, `t_k > chain's current block.timestamp`,
`tick` strictly inside `[−887259, +887259]`, and the direction/limit consistent with the cheated tick
(§4.3). Every one of those is knowable without an RPC round trip and is exactly the "catch it where the
cause is known" discipline CONTEXT locked.

### 9.3 The seed (SC-5) — a real gap

`offchain/app/Main.hs` calls `createSystemRandom` — **unseeded and unrecorded**. SC-5 requires the run
be "reproducible from a RECORDED seed". Facts checked:
- `mwc-random-0.15.3.0` is in the store. It exports `initialize :: Vector v Word32 => v Word32 -> m Gen`,
  `createSystemSeed :: IO Seed`, `save`, `restore`, `fromSeed`, `toSeed`.
- `Seed` derives `(Eq, Show, Typeable)` — **no `Read`**, so a `Show`n `Seed` cannot be parsed back.
  Round-tripping through `fromSeed`/`toSeed` on a `Vector Word32` works.
- `vector-0.13.2.0` is already in the build plan (mwc-random depends on it), so adding `vector` to
  `build-depends` introduces **no new package** — 21-04's "no new dependency" property survives.

**Recommend:** a `RIG_SEED` env var holding a single decimal `Word32`; unset → draw one from
`createSystemSeed`, **print it and write it into the artifact**; either way
`initialize (V.singleton seed)`. Short, human-typable, replayable, and it composes with the `t0`/stride
record so the *whole* run (draws and timestamps) replays.

### 9.4 Freshness — closing Phase 21's F4 cheaply

F4: `rpin05_capture_is_present_and_fresh` asserts `chainId` + `manager` only, and `manager` is a
`CREATE` address (deployer, nonce), measured identical across three redeploys — so it cannot see a
module change.

Two observations for this phase:
- **Rebuilding the rig will NOT move `VolOrderManagerMod`.** It is deployed first and
  `InitSwappableRig` is appended at the end, so the nonce sequence up to it is unchanged. The existing
  `rpin05_*` checks stay green — no regression to plan around.
- **But `pool.poolId` and `pool.tickSpacing` WILL change** (tickSpacing 10 → 20 changes the PoolKey
  hash). Those are *discriminating* fields and they are already in the manifest. And **`generatedFrom`
  moves `9f5ccba…` → `2039f27…`** in both `rig-manifest.json` and `rig-pins.json`.
  **Recommend including `generatedFrom` (and, for the new driver artifact, `pool.tickSpacing`) in the
  freshness assertion.** That is the concrete F4 mitigation, it costs one field comparison, and unlike
  code-hash pinning it needs no new tooling. Note the tradeoff honestly: adding `generatedFrom` to
  `batch-return-capture.json` means re-capturing it (the file has no such field today) — decide whether
  that churn is worth it, or apply the field only to the new artifact.

---

## Standard Stack

No new libraries. Everything below is already in the build plan or on `PATH`.

### Core

| Tool / library | Version (verified) | Purpose | Why standard here |
|---|---|---|---|
| `anvil` | 1.5.1-stable (`b0a9dd9`) | the local chain; `anvil_setStorageAt`, `evm_setNextBlockTimestamp`, `--timestamp` | already what `deploy-rig.sh` owns |
| `forge` / `cast` | 1.5.1-stable | deploy scripts; **calldata encoding by signature string** | `PriceSetter.Encoding` already shells to `cast calldata`; keeps hex literals out of `offchain/` |
| GHC | 9.10.3 | the drivers | pinned by the cabal file |
| `web3-ethereum` / `web3-provider` / `jsonrpc-tinyclient` | in build plan | `Web3`, `TxReceipt`, `Change`, `remote` for node cheats | `anvil_set_storage_at = remote "anvil_setStorageAt"` is the existing precedent |
| `mwc-random` | 0.15.3.0 | the generators | already used |
| `aeson` | in build plan | manifest + evidence artifact | already used |

### Supporting

| Library | Purpose | When |
|---|---|---|
| `vector` (0.13.2.0) | `V.singleton :: Word32 -> Vector Word32` for `System.Random.MWC.initialize` | only if the recorded-seed design in §9.3 is adopted; **already in the plan**, add to `build-depends` |
| `bytestring` / `memory-hexstring` | E3 log payload slicing | already used by `VolOrder.Decode` |

### Alternatives Considered

| Instead of | Could use | Tradeoff |
|---|---|---|
| `cast calldata` shelling | a Haskell ABI encoder for the nested `swap` tuple | The tuple is `(static-struct, static-struct, static-struct, bytes)` — hand-rolling it is a real encoder with a real head/tail bug surface, and the project has already been bitten once by a hand-rolled head (`0x40` vs `0x20`). `cast` is an independent oracle and is already a hard dependency. |
| `evm_setNextBlockTimestamp` | `evm_increaseTime` + `evm_mine` | Wall-clock-relative, returns a raw offset (measured `-85682546`), and needs two calls. Strictly worse for replay. |
| `evm_setNextBlockTimestamp` | `anvil_setBlockTimestampInterval` | Sets a *fixed* inter-block interval — elegant for a uniform stride, but it also applies to blocks the driver did not intend (order txs), so the E3 timestamps stop being a function of `k` alone. Not recommended. |
| receipt logs | `eth_getLogs` | Receipts already carry every log of the tx and are block-pinned by construction; `eth_getLogs` adds a range/reorg surface for nothing. |

**Installation:** nothing to install. Preflight is unchanged:
`npm ci --ignore-scripts` → `git -c submodule.lib/panoptic-helper.update=none submodule update --init --recursive` → `forge build`.

---

## Architecture Patterns

### Recommended shape

```
offchain/lib/
├── PriceSetter/
│   ├── Encoding.hs      # + encode_extsload, encode_swap  (cast calldata, signature strings)
│   ├── Rpc.hs           # write_price UNCHANGED; + the composed cheat + evm_setNextBlockTimestamp
│   └── Decode.hs
├── PoolSwap/            # NEW (or fold into PriceSetter) -- PoolSwapTest.swap encoding + send
├── RealizedVol/
│   └── Decode.hs        # NEW -- E3 + E5 decoders (topic0 as ARGUMENT, length guards, sign extend)
├── Rig/Manifest.hs      # + PoolSwapTest / PoolModifyLiquidityTest in required_contracts
└── StochasticPriceGen/
    └── Rpc.hs           # run_price_gen gains the cheat-swap step per tick
offchain/rig/
├── deploy-rig.sh        # + InitSwappableRig step, + 2 router addresses, + anvil --timestamp
├── import-paths.txt     # 36 -> 37
├── verify-rig.sh        # + swapRouter/modifyLiquidityRouter bytecode probes
└── driver-run-capture.json  # NEW, committed, provenance-bearing
```

**Note the naming constraint:** CONTEXT forbids a new `RealizedVol.*` **client** (i.e. anything that
*calls* `writeTimepoint`). A `RealizedVol.Decode` that only *reads* logs is squarely inside "the only
thing a client can do is query the DB api". Make that explicit in the module haddock so a later reader
does not think the decision was violated.

### Pattern 1: the two-tier driver (existing, reuse verbatim)

Every driver module ships a bare `Web3` action and a `_and_report` wrapper that owns the provider:

```haskell
run_price_gen :: Address -> StochasticPriceGen -> GenIO -> Web3 [...]
run_price_gen_and_report :: Address -> StochasticPriceGen -> GenIO -> IO ()
```
`Main.hs` composes the bare actions inside **one** `runWeb3'`. Keep this — the new cheat-swap step is a
`Web3` action folded into `run_price_gen`, not a new top-level program.

### Pattern 2: per-step sequence (the whole of DRIV-01)

```
for k, tick_k in enumerate(path):
    guard  tick_k strictly inside [-887259, +887259]        -- G4, client-side
    guard  t_k > t_{k-1}  and  t_k > chain_head_timestamp   -- G1/G2, client-side, BEFORE any RPC
    slot   <- keccak256(poolId ‖ uint256 6)                 -- pinned constant, not re-derived
    W_now  <- eth_call PoolManager.extsload(slot)
    W_low  <- eth_call PriceSetterHook.packSlot0For(tick_k)
    anvil_setStorageAt(PoolManager, slot, compose184(W_now, W_low))
    evm_setNextBlockTimestamp(t_k)
    receipt <- send  deployer -> swapRouter  swap(key, {zeroForOne, -1e6, limit}, {false,false}, 0x)
    assert receiptStatus == 1
    e3 <- exactly one E3 from hook address with topic1 == poolId    -- else FAIL LOUD with txHash
    assert e3.timestamp == t_k  &&  e3.tick == tick_k
```

The "swap-calldata artifact generated off chain within `write_price`" that CONTEXT describes is the
`(swapRouter, calldata)` pair this step builds — recommend returning it from the price-write function
alongside the existing `(pool_manager, slot, value)` triple so the artifact is a value, not a side
effect, and can be recorded in the evidence file.

### Pattern 3: pins as arguments, never imports (existing, mandatory)

`decode_order_created` takes the topic0 as its first argument, "on purpose: this decode module acquires
no IO dependency and stays testable from pure values." The E3/E5 decoders must do the same, sourced
from `pin_topic0 rig "TimepointWritten"` / `"FeeApplied"` in `Main`.

### Anti-Patterns to Avoid

- **Counting swaps instead of E3s.** G1 makes them different numbers. E3 is the ground truth
  (CONTEXT states this as binding).
- **A topic0-only log filter.** The module-global emitter uses the *same* topic0 with
  `poolId = bytes32(0)`. Filter on emitter address AND topic1.
- **Re-approving the PoolManager.** Settlement pulls from the router; the plank track corrected our
  issue's wording on exactly this.
- **Minting any second liquidity range.** G4: silently breaks the cheat invariant.
- **Editing anything under `src/`, `test/`, `foundry-scripts/`, `Makefile`, `foundry.toml`.** Import
  verbatim; report findings; never fix in place. Phase 21 has a clean record here (`git status
  --porcelain` on those paths was clean at verification) — keep it.

---

## Don't Hand-Roll

| Problem | Don't build | Use instead | Why |
|---|---|---|---|
| tick → `sqrtPriceX96` | a Haskell `TickMath.getSqrtPriceAtTick` | `PriceSetterHook.packSlot0For(int24)` via `eth_call` | 20+ magic constants and a bit-exactness obligation against the very contract you are cheating, with no in-repo oracle. The on-chain function is already deployed, already audited by use, and already reverts `InvalidTick`. |
| slot0 word packing | a Haskell `Slot0` packer | the same `packSlot0For` output, masked at bit 184 | Gets tick/sqrtPrice consistency (G5a) and fee-bit preservation (G5b) for free; a hand packer has to re-earn both. |
| ABI-encoding the nested `swap` tuple | a Haskell encoder | `cast calldata "swap(...)" ...` | This repo's one hand-rolled encoder (`(bool,uint256)[]`) needed a byte-equality differential against solc to be trusted. `cast` is that independent oracle, already a hard dependency, and leaves no hex literal for `sc3_literal_purge` to trip on. |
| a v4 swap router | anything | vendored `PoolSwapTest` + `PoolModifyLiquidityTest`, deployed by `InitSwappableRig` | The canonical unlock-callback routers; the plank track already wired them. Authoring one is how you get `deltaBefore`/settlement bugs. |
| `keccak(poolId ‖ 6)` derivation | re-deriving `POOLS_SLOT` from v4-core | the pinned constant in `DynamicFeeHook.plk:75` (`POOLS_SLOT = 6`) | "Consume — never re-derive" is a milestone-binding rule; the value is already in an imported file with a provenance comment. |
| a run-replay mechanism | ad-hoc `--seed` parsing plus a second RNG | `System.Random.MWC.initialize (V.singleton w32)` + record `w32` | `vector` is already in the plan; `Seed` has no `Read` instance, so `show`/`read` round-tripping does not work. |

**Key insight:** every offchain quantity in this phase that *could* be computed locally already exists
as a deployed, callable function or a pinned constant on the rig. The phase's job is plumbing and
evidence, not arithmetic — and every piece of arithmetic it declines to re-implement is a differential
test it does not have to write.

---

## Common Pitfalls

### Pitfall 1 — Cheating the wrong pool (the BLOCKER)
**What goes wrong:** `write_price` writes `PriceSetterPoolManager`'s slot0; `beforeSwap` reads
`PoolManager`'s. Every E3 records the un-cheated tick.
**Why it happens:** the manifest has *two* `PoolManager`-shaped entries and the CONTEXT sequence reads
as if there were one pool.
**How to avoid:** §2.3's composed write. **Warning sign:** every `e3.tick` equals `INIT_TICK` (0) or
drifts only by swap impact, while the driver's path is clearly moving.

### Pitfall 2 — Same-second silent no-op (G1)
**What goes wrong:** two steps land in the same uint32 second; the second emits no E3 but a perfectly
healthy receipt with status 1 and an E5.
**Why:** `if vol_state.lastTimepointTimestamp == now { return false; }`, and anvil mines several blocks
per wall second (measured: 13, 14, **14**).
**How to avoid:** `evm_setNextBlockTimestamp(t_k)` with `t_k` strictly increasing; assert
`count(E3) == steps` and `count(E5) == count(E3)`.
**Warning sign:** more E5 than E3.

### Pitfall 3 — Backwards clock (G2)
**What goes wrong:** the oracle's window math corrupts silently — no revert, no event, wrong σ².
**How to avoid:** client-side monotonicity guard *before* sending. anvil's own
`-32602 Timestamp error: … is lower than previous block's timestamp` is a second net, but it fires at
send time and does not cover the `INIT_TS`-vs-chain-clock mismatch (§5).

### Pitfall 4 — Key drift reverts the swap
**What goes wrong:** any of `(currency0, currency1, 0x800000, 20, hook)` wrong → `beforeSwap`'s
`require(pool_id == SLOT_HOOK_POOL_ID)` reverts the whole tx.
**How to avoid:** build the key from the manifest (`pool.currency0/currency1/tickSpacing`,
`contracts.DynamicFeeHook`), never from a constant. **Warning sign:** a revert with empty reason data
on the swap while `InitSwappableRig`'s own probe succeeded.

### Pitfall 5 — Wrong sender
**What goes wrong:** swapping from `accounts.sender` (index 1) fails inside settlement; only
`accounts.deployer` (index 0) was minted and approved.
**How to avoid:** deployer for swaps, sender for orders. Document it, because the two are one line
apart in `Main.hs`.

### Pitfall 6 — `data_word` past the end returns 0
**What goes wrong:** a short E3 payload silently yields `tickCumulative = 0` — plausible, in range,
fabricated. This is the trap RPIN-04 documented for E1.
**How to avoid:** `BS.length (toBytes (changeData l)) >= 160` guard before decoding, mirroring the E1
decoder's `>= 128`.

### Pitfall 7 — Unsigned decode of signed fields
**What goes wrong:** `tick = -200` reads as `115792…856` (or `16777016` if you mask to 24 bits) and the
equality check against the submitted tick fails for a reason that looks like a chain bug.
**How to avoid:** one shared `signed_word :: Integer -> Integer` (`if w >= 2^255 then w - 2^256 else w`)
applied to `tick`, `averageTick`, `tickCumulative` — the emitter already `signextend`s to the full word.

### Pitfall 8 — A hex literal re-entering `offchain/`
**What goes wrong:** `sc3_literal_purge` greps `offchain --include=*.hs --include=*.sh` for
`0x[0-9a-fA-F]{40}\b|…{64}\b|…{8}\b` and fails on any match. The swap selector `0x2229d0b4` is 8 hex
digits — writing it down reddens the suite.
**How to avoid:** `cast calldata` with the signature string. (Decimal constants like `4295128739`
`MIN_SQRT_PRICE`, `6` `POOLS_SLOT`, and 6-digit `0x800000` do **not** match the patterns — verified
against the regex.)

### Pitfall 9 — Assuming the predicted discriminator
**What goes wrong:** twice now in this workstream a plan's predicted mutant discriminator has been
wrong (21-03: an inequality check stayed green under a value-breaking mutant; 21-04: a bit-length
spread check cleared a linear-vs-log law). **Every check this phase adds must PIN VALUES, and the
discrimination must be MEASURED by applying the mutant, not argued.** Candidate mutants with real bite:
drop the `evm_setNextBlockTimestamp` call (→ same-second collisions → E3 < steps); mask
`packSlot0For`'s output at 160 instead of 184 (→ tick and sqrtPrice disagree); write the composed word
to `PriceSetterPoolManager` instead of `PoolManager` (→ every `e3.tick` constant); drop the sign
extension (→ negative ticks decode huge).

### Pitfall 10 — `cabal build -j all` is not a gate
Confirmed vacuous **four times** in Phase 21 (exit 0 against a test suite that would not compile).
**The gate is `cabal build --enable-tests -j all`.** `offchain/rig/README.md` still prints the vacuous
form in its clean-machine sequence — that is one of three staleness fixes this phase owes (§"Open
Questions" / §"State of the Art").

---

## Code Examples

### Deriving the slot and composing the cheated word

```bash
# slot = keccak256(poolId ‖ uint256(POOLS_SLOT=6))   -- POOLS_SLOT pinned at DynamicFeeHook.plk:75
cast keccak 0xc26d0c664c1503d15da31243604d1904295ccb87658aa0f62ff9966f200e272e\
0000000000000000000000000000000000000000000000000000000000000006
# -> 0xeeab88fa749045a9c1259e79a7bd845c2ee229c1a4e0702e880b8251c4c6dd16   (measured)
```

```haskell
-- Slot0: sqrtPriceX96 [0,160) | tick [160,184) | protocolFee [184,208) | lpFee [208,232)
-- Verified against univ4-core/types/Slot0.sol.
compose_slot0 :: Integer -> Integer -> Integer
compose_slot0 current_word pack_slot0_for_word =
  (current_word .&. complement low184) .|. (pack_slot0_for_word .&. low184)
  where low184 = (1 `shiftL` 184) - 1
```

### The swap calldata (measured round-trip)

```bash
cast calldata "swap((address,address,uint24,int24,address),(bool,int256,uint160),(bool,bool),bytes)" \
  "($C0,$C1,8388608,20,$HOOK)" "(true,-1000000,4295128740)" "(false,false)" "0x"
# selector 0x2229d0b4 ; 4295128740 = TickMath.MIN_SQRT_PRICE + 1 ; 8388608 = 0x800000 dynamic-fee flag
```

### The clock, per step (measured against anvil 1.5.1)

```bash
cast rpc evm_setNextBlockTimestamp 1700001000    # -> null ; next mined block has exactly this ts
# backwards is rejected BY THE NODE:
cast rpc evm_setNextBlockTimestamp 1700000500
# Error: -32602: Timestamp error: 1700000500 is lower than previous block's timestamp
```

```haskell
evm_set_next_block_timestamp :: Integer -> Web3 Value
evm_set_next_block_timestamp = remote "evm_setNextBlockTimestamp"   -- decimal JSON number: accepted
```

### E3 decode skeleton (mirrors the E1 decoder's discipline)

```haskell
-- TimepointWritten(bytes32 indexed poolId, uint32 timestamp, int24 tick,
--                  uint88 volatilityCumulative, int24 averageTick, int56 tickCumulative)
-- Emitter: @evm_log2(buf, 160, TOPIC0, pool_id)  ->  2 topics, EXACTLY 160 bytes = 5 words.
-- Source: src/lib/events/VolEventsLib.plk:62-77
decode_timepoint_written :: Integer -> Integer -> Change -> Maybe TimepointWritten
decode_timepoint_written expected_topic0 expected_pool_id l =
  case changeTopics l of
    [t0, pid]
      | hex_to_integer t0  == expected_topic0
      , hex_to_integer pid == expected_pool_id
      , BS.length (toBytes (changeData l)) >= 160 -> Just TimepointWritten
          { tw_timestamp   =              data_word 0 (changeData l)
          , tw_tick        = signed_word (data_word 1 (changeData l))
          , tw_vol_cum     =              data_word 2 (changeData l)
          , tw_avg_tick    = signed_word (data_word 3 (changeData l))
          , tw_tick_cum    = signed_word (data_word 4 (changeData l))
          }
    _ -> Nothing
  where signed_word w = if w >= 2^(255::Int) then w - 2^(256::Int) else w
```

---

## State of the Art — what changed under this phase's feet

| Old | Current | When | Impact |
|---|---|---|---|
| `DeployDynamicFeeHook` `TICK_SPACING = 10` | `= 20` (F2) | PR #18, `2039f27` | **Every standing rig is stale.** The PoolKey hash changes ⇒ new `poolId`; the rig must be rebuilt, not patched. |
| No swap path into the hook | `InitSwappableRig.s.sol` (routers + 1 full-range position + asserted probe) | PR #18 | DRIV-01 becomes executable; `deploy-rig.sh` gains a 6th script and 2 manifest addresses. |
| `VolOrderManagerMod.plk` carried a V1 input-word comment contradicting its own V2 code | V2 comment (F1) | PR #18 | **Comment-only.** Source sha256 changed; bytecode did not. Re-pin required, no client change (§3). |
| `write_price` was the only price mechanism, aimed at a liquidity-free pool | cheat-swap into a *different*, liquid pool | this phase | The pool-mismatch BLOCKER (§2.3). |
| `cabal test` "does NOT skip when the rig is down, it fails" (`offchain/rig/README.md`) | **Chain-independent** — measured 65/65 with anvil stopped | Phase 21 | README row is **stale and wrong**; fix it as part of SC-5's one documented command. |
| README's "It does NOT yet place a vol order… comes back `status reverted`" | Fixed at 21-05; `cabal run` mines | Phase 21 | README section is **stale**; remove it. |
| README's `cabal build -j all` | `cabal build --enable-tests -j all` | Phase 21 (vacuous ×4) | README prints the vacuous gate. Fix. |

**Deprecated / do not use:** `RealizedVolatilityMod.writeTimepoint` as a *driver* entry point (superseded
by the user decision — the pin and selector stay in `rig-pins.json` and stay checked, they are simply
not called); `evm_increaseTime` for driver stepping; `blockNumber` as a provenance field.

---

## Open Questions

1. **Does `InitSwappableRig` compile and run on this branch's toolchain?**
   - Known: all imports resolve, all three router/settler files exist, `forge build --via-ir` currently
     exits 0.
   - Unclear: the routers have **never** been in a build here; `--via-ir` compile time and any
     stack-too-deep behaviour are unmeasured. Also unmeasured: whether appending a 6th `forge script`
     changes the `FORGE-BASELINE` numbers.
   - Recommendation: first task of the phase, verified independently, with `FORGE-DELTA.md` updated.

2. **Should `deploy-rig.sh` pass `anvil --timestamp "$INIT_TS"`?**
   - Known: it works (measured); it makes `INIT_TS + k·stride` a usable absolute schedule and unifies
     the module and hook clock origins.
   - Unclear: whether the plank deploy scripts have any wall-clock assumption (I found none), and
     whether SC-5's byte-identical-manifest property survives (it should — `generatedAt` is the only
     clock-derived manifest field, and it is already excluded).
   - Recommendation: adopt it, and re-run the SC-5 double-deploy check as the acceptance.

3. **Should `generatedFrom` be added to `batch-return-capture.json`?**
   - Known: it is the field that would have caught F4's blind spot, and it is already in both manifest
     halves.
   - Unclear: whether re-capturing a Phase-21 artifact inside Phase 22 is worth the churn.
   - Recommendation: apply it to the **new** driver artifact unconditionally; make the Phase-21
     re-capture optional and, if skipped, record the residual F4 gap explicitly rather than closing it
     on paper.

4. **Does the composed slot0 write survive a real swap end to end?**
   - Known: every component is verified in isolation (slot derivation, `extsload` selector,
     `packSlot0For` semantics, `setStorageAt` non-mining, calldata encode).
   - Unclear: nothing was executed against a rig carrying `InitSwappableRig`, because importing it is a
     Phase-22 deliverable and `foundry-scripts/` is another track's territory.
   - Recommendation: the first wave should end at an **observed** E3 whose tick equals a cheated tick
     that is not 0 and not reachable by swap impact — that single measurement discharges the BLOCKER.

5. **`DATA_CONTRACT.md` says "A same-block second write emits NOTHING."** G1 establishes the guard is
   per **timestamp**, not per block. The two coincide on most chains and diverge on anvil.
   - This is an imported, plank-owned file. **Report, do not edit** (the Phase-21 F1/F2 precedent).
   - Add it to a `22-CROSS-TRACK-FINDINGS.md`.

6. **What is the intended stride?** Left to discretion by CONTEXT. Correctness needs only ≥ 1 s.
   Recommend recording it in the artifact so the question is answered by data, not by a constant
   someone has to go read.

---

## Validation Architecture

### Test Framework

| Property | Value |
|---|---|
| Framework | **None** — a hand-rolled `data Check = Check { check_name :: String, check_run :: IO (Either String ()) }` list in `offchain/test/Main.hs` (1962 lines), `type: exitcode-stdio-1.0`. `main` maps `run_one` over the list, prints `PASS`/`FAIL` per check and `n/m checks passed`, and `exitFailure` on any failure. |
| Config file | `cfmm-replicationPlank-rpc-api.cabal` (`test-suite cfmm-replicationPlank-rpc-api-test`, `hs-source-dirs: offchain/test`) |
| Quick run command | `cabal test` (currently **65/65**, exit 0) |
| Full suite command | `cabal build --enable-tests -j all && cabal test` — **the real gate**; `cabal build -j all` alone is vacuous (confirmed 4×) |
| Chain dependency | **NONE, and this must be preserved.** Measured in Phase 21: rig stopped, `pgrep anvil` empty, `cast block-number` erroring, `cabal test` still 65/65. `grep -cE 'cast call\|HttpProvider\|8545' offchain/test/Main.hs` = 0. |
| Live-evidence mechanism | committed provenance-bearing JSON written by a shell script under `offchain/rig/`, asserted over by the suite |
| Extra gates | zero `-Wall` warnings (hard); `sc3_literal_purge` (no address/selector/topic0 literals in `offchain/**/*.{hs,sh}`); `offchain/rig/verify-import.sh` (SC-1); `offchain/rig/verify-rig.sh` (SC-2) |

### Phase Requirements → Test Map

| Req / SC | Behavior | Test type | Automated command | File exists? |
|---|---|---|---|---|
| **Re-pin (pre-req)** | 37 imported paths byte-identical to `2039f27` and sha256-matched | integration (shell) | `bash offchain/rig/verify-import.sh` | ✅ exists; **needs 3 pin-row edits + 1 new path** |
| **Re-pin (pre-req)** | upstream gate names `InitSwappableRig.s.sol` | integration (shell) | `bash offchain/rig/check-upstream.sh` | ✅ exists; needs `REQUIRED_PATHS` entry |
| **Rig (pre-req)** | routers + full-range position stand up; probe swap advances `lastTimepointTimestamp` | integration (shell) | `bash offchain/rig/deploy-rig.sh` (asserts `timepoint ts after > before` from the log, as it asserts `seeded : true` today) | ✅ script exists; **needs the 6th step + 2 addresses** |
| **Rig (pre-req)** | all 9 manifest contracts live | integration (shell) | `bash offchain/rig/verify-rig.sh` | ✅ exists; needs 2 probes |
| **DRIV-01 / SC-1** | E3 count == step count; `e3.timestamp == t0 + k·stride`; `e3.tick ==` submitted tick; strictly increasing timestamps; all statuses 1 | unit over artifact | `cabal test` → `driv01_e3_per_step_matches_submitted` | ❌ **Wave 0** |
| **DRIV-01 / SC-1** | `count(E5) == count(E3)` — no G1 no-op ate a step | unit over artifact | `cabal test` → `driv01_no_same_second_noop` | ❌ **Wave 0** |
| **DRIV-01 / SC-1** | E3 decoder: 2 topics, ≥160-byte guard, sign-extended int24/int56 | unit (pure, synthetic `Change`) | `cabal test` → `driv01_e3_decode_behavior` | ❌ **Wave 0** (21-03 built synthetic `Change` values — reuse that helper) |
| **DRIV-01 / SC-1** | `write_price` / PriceSetterHook flow still runs unchanged | integration | `cabal run` (existing `write_price psh sample_tick` step) + artifact records it | ✅ shipped, assert it still runs |
| **DRIV-02 / SC-2** | single `create_order`: status 1, one E1 v2 under the pinned topic0, block-pinned readback incl. `targetVega` | unit over artifact + live run | `cabal test` → `driv02_single_order_live`; produced by `cabal run` | ❌ **Wave 0** (the live path is shipped; the assertion is not) |
| **DRIV-02 / SC-3** | batch: `(True,id)` matches preview PATTERN, `orderCount` moves by success count, per-id readback; **mixed batch with `skew=65535`** | unit over artifact + live run | `cabal test` → `driv02_mixed_batch_live` | ❌ **Wave 0** |
| **DRIV-02 / SC-4** | `N = 0` completes cleanly; the 64-byte empty return decodes to `[]` | unit over artifact | `cabal test` → `driv02_zero_arrival_is_64_bytes` | ❌ **Wave 0** — and note the generator path sends nothing at N=0 (§8), so the direct `create_orders _ _ []` call must exist |
| **SC-5** | one documented command; run replays from the recorded seed | integration | `bash offchain/rig/README.md` sequence run top to bottom (Phase 20 precedent) + a second run with `RIG_SEED=<recorded>` producing an identical tick path and identical `e3.tick` series | ❌ **Wave 0**; README also needs 3 staleness fixes |
| **Cross-cutting** | suite stays chain-independent | integration | `bash offchain/rig/deploy-rig.sh --stop && pgrep anvil; cabal test` → exit 0 | ✅ pattern exists (Phase 21) — **re-measure, do not inherit** |
| **Cross-cutting** | no hex literals under `offchain/` | unit | `cabal test` → `sc3_literal_purge` | ✅ exists |
| **Cross-cutting** | zero `-Wall` warnings | build | `cabal build --enable-tests -j all` | ✅ |

**Manual-only / not automatable, state plainly:**
- The *first* observation that a cheated tick reaches E3 (Open Question 4) is a one-time live
  measurement; afterwards it is pinned in the artifact and the suite asserts it offline.
- A transaction receipt carries **no returndata**, so SC-4's "exactly 64 bytes" can only be observed
  through the preview `eth_call`, never through the mined tx. Do not write a check that pretends
  otherwise.

### Sampling Rate

- **Per task commit:** `cabal build --enable-tests -j all && cabal test` (seconds; no chain needed)
- **Per wave merge:** the above **plus** `bash offchain/rig/verify-import.sh` and, for waves that touch
  the rig, `deploy-rig.sh` → `verify-rig.sh` → `cabal run`
- **Phase gate:** the full `offchain/rig/README.md` sequence top to bottom, every step exit 0 (Phase 20
  precedent), then the chain-independence re-measurement, then `/gsd:verify-work`

### Wave 0 Gaps

- [ ] `offchain/lib/RealizedVol/Decode.hs` — E3 + E5 decoders with a shared `signed_word`; covers SC-1
- [ ] `offchain/rig/driver-run-capture.json` + its writer — the provenance-bearing evidence artifact;
      covers SC-1/2/3/4/5
- [ ] `offchain/test/Main.hs` — the `driv01_*` / `driv02_*` checks above (the harness itself needs no
      new infrastructure: `Check`, `guarded`, `pure_check`, synthetic `Change` construction and
      `eitherDecodeFileStrict` over a committed artifact all already exist)
- [ ] `offchain/rig/import-paths.txt` (36 → 37) + `IMPORT-PIN.md` (2 digest updates, 1 new row, new
      ref/subject) + `check-upstream.sh` `REQUIRED_PATHS`
- [ ] `offchain/rig/deploy-rig.sh` — 6th script step, `swapRouter`/`modifyLiquidityRouter` extraction +
      console cross-check, `timepoint ts after > before` assertion, (recommended) `anvil --timestamp`
- [ ] `offchain/lib/Rig/Manifest.hs` — 2 new entries in `required_contracts` (7 → 9)
- [ ] `offchain/rig/verify-rig.sh` — bytecode probes for the 2 routers
- [ ] `offchain/rig/README.md` — 3 staleness fixes (chain-independence row, the "does not prove"
      section, `cabal build --enable-tests`) + the new driver command
- [ ] `.cabal` — `vector` in `build-depends` (already in the plan; no new package) if §9.3 is adopted
- [ ] `.planning/phases/22-.../22-CROSS-TRACK-FINDINGS.md` — the `DATA_CONTRACT.md` same-block-vs-
      same-timestamp wording, and anything else found during import
- **Framework install: none.** The harness and every dependency are present.

---

## Sources

### Primary (HIGH confidence — read directly, or executed on this machine)

- `git show origin/develop:foundry-scripts/deploy/InitSwappableRig.s.sol` @ `2039f27` — full file
- `git show origin/develop:foundry-scripts/deploy/DeployDynamicFeeHook.s.sol` @ `2039f27`
- `git show origin/develop:src/modules/pos_spec/VolOrderManagerMod.plk` @ `2039f27` (batch loop +
  the F1 comment)
- `git diff --stat 9f5ccba 2039f27 -- <import-paths>` and `-- foundry-scripts/ src/ notes/`
- `offchain/rig/verify-import.sh` — run, exit 0, 36 paths clean against the old pin
- `src/modules/protocol_integrations/{DynamicFeeHook.plk,PriceSetterHook.sol}`
- `src/lib/market_state_measurements/RealizedVolatilityStateLib.plk:102-115` (the B1 guard)
- `src/lib/events/VolEventsLib.plk:62-77` (E3 emitter)
- `src/lib/pos_spec/VolOrderValidationLib.plk` (`target_vega_fits_packed`, skew `[1,65534]`)
- `src/interfaces/{market_state_measurements/RealizedVolatilityInterface,protocol_integrations/DynamicFeeHookInterface}.plk`
- `foundry-scripts/PriceSetterHook.s.sol`, `foundry-scripts/deploy/PlankDeployBase.s.sol`
- `lib/panoptic-v2-core/lib/v4-core/src/{types/Slot0.sol,libraries/TickMath.sol,test/PoolSwapTest.sol,test/PoolTestBase.sol}`
- `offchain/{app,lib,rig,test}/**` — the whole offchain tree
- `notes/DATA_CONTRACT.md` §1/§2/§6
- **Executed:** `anvil --silent --port 8546 --timestamp 1700000000` (v1.5.1-stable) + `cast rpc`
  probes of `evm_setNextBlockTimestamp`, `evm_increaseTime`, `evm_mine`, `anvil_setStorageAt`; raw
  `curl` JSON-RPC param-shape tests; `cast sig` / `cast calldata` for `PoolSwapTest.swap`;
  `cast keccak` for the slot derivation; `forge build --via-ir` (exit 0)
- **Computed:** `getSqrtPriceAtTick` at ±887272 / ±887260 / 0 via exact `Decimal` arithmetic
- `mwc-random-0.15.3.0` source tarball (`System/Random/MWC.hs`) — `Seed` derives `(Eq, Show, Typeable)`,
  no `Read`; `initialize`, `createSystemSeed`, `save`, `restore`, `toSeed`, `fromSeed` all exported

### Secondary (MEDIUM confidence)

- `.planning/phases/22-live-stochastic-drivers/22-CONTEXT.md` — the G1–G5 answers, relayed from
  issue #17; the guard *statements* were independently verified against source, the plank track's
  reasoning behind them was not re-derived
- `.planning/phases/21-.../21-VERIFICATION.md`, `.planning/STATE.md` — the shipped V2 client, F3/F4
- `.planning/ROADMAP.md` Phase 22 detail, `.planning/REQUIREMENTS.md` v5.0
- `.planning/phases/20-.../{20-CONTEXT.md,IMPORT-PIN.md}` — the import/pin discipline

### Tertiary (LOW confidence — flagged, not relied on)

- The claim that `skew = 65535` is the **only** client-passable contract-rejected input
  (`capture-batch-return.sh`'s own comment). It is *a* proven discriminator (used live in Phase 21);
  "the only" is not verified here and the plan should not depend on the exclusivity.
- Whether `--via-ir` compiles the two routers cleanly on this toolchain — untested (Open Question 1).

---

## Metadata

**Confidence breakdown:**

| Area | Level | Reason |
|---|---|---|
| Re-pin delta (§1) | **HIGH** | `git diff` against both refs, sha256s computed from `git show`, old pin verified clean first |
| `InitSwappableRig` contract (§2.1/2.2) | **HIGH** | full file read from the ref; every CONTEXT claim checked line-by-line |
| Pool mismatch BLOCKER (§2.3) | **HIGH** | two `new PoolManager(...)` in two scripts; two distinct manifest keys; two distinct slot0 reads in source |
| The composition fix (§2.3) | **MEDIUM** | every component verified in isolation and the arithmetic is elementary, but it was **not executed end to end** (would require importing plank-track files) |
| F1 layout compatibility (§3) | **HIGH** | `@evm_shr(128, word)` with no mask, read in the executable loop, plus the validator's `<= 2^96-1` |
| Swap calldata (§4.1) | **HIGH** | `cast sig` + `cast calldata` executed, output inspected word by word |
| Direction/limit bound safety (§4.3) | **MEDIUM-HIGH** | exact `Decimal` computation of `getSqrtPriceAtTick` at the boundaries; the *reserve*-exhaustion half is an analytical argument, unmeasured on chain |
| Clock control (§5) | **HIGH** | all four RPCs executed against anvil 1.5.1, including the G1 collision and the backwards rejection |
| slot0 hygiene (§6) | **HIGH** | `packSlot0For` source + `Slot0Library` setters read directly |
| E3/E5 shapes (§7) | **HIGH** | emitter source (`@evm_log2`, 160 bytes) + interface file + `DATA_CONTRACT.md` all agree |
| N=0 / mixed-batch gaps (§8) | **HIGH** | `chunk _ [] = []` read in `StochasticOrderGen/Rpc.hs`; the discriminator is Phase 21's own live-used case |
| Seed / `vector` availability (§9.3) | **HIGH** | package tarball inspected; store paths confirmed for both packages |
| Router compile under `--via-ir` | **LOW** | untested; nothing in the tree has ever imported them |

**Research date:** 2026-08-02
**Valid until:** ~2026-08-16 (14 days). The short window is deliberate: `origin/develop` is actively
moving (three of this phase's binding facts changed in the last 48 h), and the measured delta in §1 is
the phase's first executable step. **Re-run `git diff --stat <import-ref> origin/develop -- $(cat
offchain/rig/import-paths.txt)` at execution start** rather than trusting §1's table — Phase 20 already
had one research measurement expire this way (`20-01` recorded research §1 as EXPIRED).
