# Phase 22: Live Stochastic Drivers - Context

**Gathered:** 2026-08-02
**Status:** Ready for planning — upstream gate (issue #17) RESOLVED 2026-08-02, PR #18 merged to develop @ 2039f27

<domain>
## Phase Boundary

Both stochastic drivers run end-to-end against the live rig under the V2 ABI and produce
the real event set — the milestone's acceptance bar and the v6.0 subgraph's input.
Requirements: DRIV-01, DRIV-02.

</domain>

<decisions>
## Implementation Decisions

### DRIV-01 ARCHITECTURE — the roadmap's wording is SUPERSEDED (user decision)

**The roadmap's SC-1 says the driver "drives `RealizedVolatilityMod.writeTimepoint(uint32,int24)`
once per step". That is exactly the offchain intervention the user does NOT want, and it is
superseded here.**

User's stated intent, verbatim: *"by setting prices and moving across time the timepoints will
write themselves on the Hook. This is the intended thing, such that the only thing a client can
do is query the DB api. There must be an init pool script and from there one can run write_price,
and create_order and realizedVol works with no offchain intervention."*

**This architecture is real and already implemented — VERIFIED, not assumed:**
`src/modules/protocol_integrations/DynamicFeeHook.plk:129` — `beforeSwap` calls
`rv_write_timepoint` on the pre-swap tick read via `extsload`, then emits the E3/E4/E5 chain
with the real bound poolId (matching issue #13's description of the premium rig).

**Consequence for the phase:** there is NO new `RealizedVol.*` offchain client module. DRIV-01
is satisfied by making the hook fire, not by calling the vol module. The "focused research pass
on the E3 side" the roadmap flags (a `writeTimepoint` client) is CANCELLED by this decision.

### The cheat-swap pattern (user's design for entering the hook)

The gap the user identified: *"we need a cheat for swaps — a swap that allows us to enter the
swap thing without changing the price by the swap, but by our actual price specified on the
write_price argument. So it can enter the hook. But this is an artifact that must be generated
off chain within the write_price."*

So `write_price` gains a second responsibility: besides cheating slot0, it generates the
seed/placeholder **swap calldata** that lets a minimal swap enter the hook.

Intended per-step sequence:
1. `write_price` cheats slot0 to the desired tick (existing `anvil_setStorageAt` flow, unchanged)
2. a **minimal-amount swap** executes purely to trigger `beforeSwap`
3. the hook reads the **pre-swap** tick — i.e. the cheated one — and writes THAT timepoint
4. the swap's own price impact is irrelevant; the next step re-cheats slot0

Sound against the current `beforeSwap` (it records pre-swap state), but see the gate below —
whether the hook needs a guard is an open question posed to the plank track in issue #17.

### UPSTREAM GATE — issue #17: **RESOLVED 2026-08-02, gate is OPEN**

The plank track delivered in PR **#18**, **merged to `develop` @ `2039f27`** (verified:
`foundry-scripts/deploy/InitSwappableRig.s.sol` present on develop; F2's fix live —
`DeployDynamicFeeHook.s.sol` now `TICK_SPACING = 20`).

**`InitSwappableRig.s.sol`** runs AFTER `DeployDynamicFeeHook.s.sol`, taking env from its
printed manifest (`POOL_MANAGER`, `HOOK`, `TOKEN0`, `TOKEN1`):
`forge script foundry-scripts/deploy/InitSwappableRig.s.sol --tc InitSwappableRig --rpc-url local --broadcast --via-ir`
— **no `--ffi`** (pure Solidity), `--broadcast` required for our broadcast-JSON manifest
workflow. It deploys the vendored `PoolSwapTest` + `PoolModifyLiquidityTest` (nothing
authored), funds + approves, mints ONE full-range position (±887260, L=1e21), and runs a probe
swap **asserted on `lastTimepointTimestamp` strictly advancing** — a passing run PROVES
timepoints self-write. New manifest lines: swapRouter, modifyLiquidityRouter, tick range,
liquidity, probe deltas, timepoint ts before/after.

**Correction they made to our issue's wording:** approvals go **deployer → routers**, NOT
deployer → PoolManager (settlement is `CurrencySettler.settle → transferFrom` pulled *by the
router*). Do not re-approve the manager.

#### The five guard answers — BINDING constraints on the driver

- **G1 — same-second repeats (the one that WILL bite):** the write guard is **one timepoint per
  distinct uint32 TIMESTAMP; blocks are irrelevant** (`RealizedVolatilityStateLib.plk:114`
  compares timestamps only). Anvil mines several blocks per second, so two swaps in different
  same-second blocks silently no-op the second write (no E3; E5 + fee still served).
  **The driver MUST advance the clock ≥1s between writes it expects recorded, and E3 is the
  ground truth of what landed** — never the swap count. This settles the stride question: stride
  ≥ 1s is not a preference, it is a correctness requirement.
- **G2 — non-monotonic timestamps: NOT guarded.** The Algebra-ported oracle assumes a
  non-decreasing u32 clock; a backwards clock corrupts window math **silently**. We own clock
  monotonicity. **This vindicates the fail-loudly-before-sending decision — it is the only
  signal that exists.**
- **G3 — arbitrary cheated tick jumps: safe.** The oracle measures tick deltas; a cheated jump is
  indistinguishable from a traded one. Recording the pre-swap (= cheated) tick is exactly what
  `beforeSwap` does. The cheat-swap pattern is confirmed sound.
- **G4 — the real hazard is liquidity-accounting desync.** Cheat-moves never CROSS ticks, so the
  rig must hold **ONLY the one full-range position** — minting any additional range breaks the
  invariant silently. And the cheat domain must be pinned to ticks **strictly inside
  [−887260, +887260]**: the TickMath-valid slivers out to ±887272 sit OUTSIDE the position, where
  global liquidity claims 1e21 that isn't there.
- **G5 — slot0 hygiene:** write `sqrtPriceX96` AND `tick` **consistently**
  (`sqrtPrice = getSqrtPriceAtTick(tick)`) in the same word, and **preserve bits ≥184**
  (protocolFee/lpFee — zeroing is harmless today, latent bug under any future protocol-fee
  config). Also: a cheat near the bottom of the range **inverts a hardcoded probe direction** —
  pick `zeroForOne`/`sqrtPriceLimitX96` relative to the cheated price in the minimal-swap loop.

#### Consequences this phase MUST handle

- **The current rig is STALE.** F2 changed `TICK_SPACING` 10 → 20, so previously recorded ts=10
  rigs must be rebuilt: re-run `DeployDynamicFeeHook.s.sol` before `InitSwappableRig.s.sol`.
- **Re-pin required.** Byte-identical compiled hex does NOT preserve source sha256. Both
  `src/modules/pos_spec/VolOrderManagerMod.plk` (F1 comment rewrite) and
  `foundry-scripts/deploy/DeployDynamicFeeHook.s.sol` (F2) have new source hashes, and
  `foundry-scripts/deploy/InitSwappableRig.s.sol` must be ADDED to the pin set —
  `offchain/rig/import-paths.txt` + `IMPORT-PIN.md`, re-imported the same verbatim/pinned way
  Phase 20 did, from the new develop ref.
- **F1's rewrite describes `targetVega@128..255 unmasked top`** where our client packs u96 at
  128..223 with bits ≥224 zero by construction. These are compatible — 128..255 is the *unmasked
  read region* (dirty bits inflate past 2^96−1 and are rejected by `target_vega_fits_packed`),
  not a widened field. The planner should confirm this rather than treat it as a layout change.

#### Original blockers (now closed — kept for the record)

Verified blockers at filing time:
- `DeployDynamicFeeHook.s.sol` **never mints liquidity** (no `modifyLiquidity` call) — a swap
  against a zero-liquidity pool cannot execute.
- **No unlock-callback router exists anywhere in the tree** —
  `grep -rl 'unlockCallback\|IUnlockCallback' src/ foundry-scripts/ test/` returns nothing.
  v4's `PoolManager` cannot be swapped from an EOA.
- Tokens are NOT the gap: the script's `MinimalToken` already has public `mint`/`approve`.
- Useful finding relayed in the issue: v4-core's canonical `PoolSwapTest` is **already vendored**
  at `lib/panoptic-v2-core/lib/v4-core/src/test/PoolSwapTest.sol` — the plank track should wire
  and deploy it rather than author a router.

Per the user, the init-pool-with-hook script is **the plank development tree's** deliverable, not
this workstream's. Issue #17 asks for it and also poses the guard question (same-block repeats vs
the B1 no-op at `DynamicFeeHook.plk:25`, non-monotonic timestamps, arbitrarily-jumping cheated
ticks). Planning may proceed now; EXECUTION blocks on #17 landing on `develop`, imported the same
verbatim/pinned way Phase 20 imported the rig.

### Timestamps
- **Fixed stride from the seeded `INIT_TS`** — each step is `INIT_TS + k*stride`. Deterministic,
  replayable from the recorded seed, monotonic by construction, independent of wall clock and
  block timing. SC-5's reproducibility requirement effectively demands the timestamps replay
  identically too.
- NOTE: with the hook writing timepoints, the timestamp the buffer records is the hook's own
  clock, not a client-supplied argument. The stride therefore governs how far the driver advances
  chain time between steps (`evm_increaseTime`/`evm_mine`) rather than a `uint32` argument. The
  planner must reconcile the stride with the hook's same-block no-op (B1).

### Non-advancing timestamp
- **Fail loudly before sending**, client-side, with an attributable message — matching this
  codebase's domain-guard discipline (`StochasticPriceGen`'s NaN guard, `pack_vol_order_input`'s
  field validation). Catch it where the cause is known rather than letting it become a silent
  on-chain no-op.

### Claude's Discretion
- Where the swap-calldata artifact lives in `write_price`'s return/type surface.
- Stride value and the concrete chain-time advance mechanism.
- Evidence-artifact shape and mid-run failure policy — NOT YET DISCUSSED (the "Evidence &
  failure" and "Run shape & seed" gray areas were selected but overtaken by the architecture
  correction). The planner should follow Phase 20/21 precedent: committed provenance-bearing
  artifacts, loud failure with tx hashes, one documented command, recorded seed.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### The hook's self-writing vol chain (the corrected DRIV-01 mechanism)
- `src/modules/protocol_integrations/DynamicFeeHook.plk` — esp. **:20-30** (the beforeSwap
  contract: pre-swap tick → `rv_write_timepoint` → vol → fee → E5) and **:129** (the actual
  `rv_write_timepoint` call). **:25** documents the B1 same-block no-op.
- `foundry-scripts/deploy/DeployDynamicFeeHook.s.sol` — what the rig stands up today, and what
  it does NOT (no liquidity, no router)
- GitHub issue **#17** — the swappable-pool ask + the guard question (the gate)
- GitHub issue **#13** — the original handoff describing the premium rig and both drivers

### Event contract (what the drivers must produce)
- `notes/DATA_CONTRACT.md` — field→scale table, emission-order guarantees
- `src/interfaces/market_state_measurements/RealizedVolatilityInterface.plk` — E3/E6
- `src/interfaces/protocol_integrations/DynamicFeeHookInterface.plk` — E5 + the hook's
  real-poolId instances of E3/E4/E6

### Phase framing
- `.planning/ROADMAP.md` — Phase 22 detail (5 success criteria; **SC-1's mechanism is superseded
  by this context's architecture decision** — the required OUTCOME, E3 emitted per step with the
  submitted tick, is unchanged)
- `.planning/REQUIREMENTS.md` — DRIV-01, DRIV-02
- `.planning/phases/21-.../21-VERIFICATION.md` + the five 21-*-SUMMARY.md files — the V2 client
  this phase drives, and its open findings (F3, F4, follow-ups #2/#5)
- `docs/superpowers/verification/2026-07-22-stochastic-order-gen-verification.md` — the N=0
  64-byte contract SC-4 tests, and the tracked follow-ups

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `offchain/lib/StochasticPriceGen/Rpc.hs` — the two-tier driver pattern (bare `Web3` action +
  `_and_report` wrapper) DRIV-01's runner mirrors; currently folds `write_price` over a
  simulated tick path.
- `offchain/lib/StochasticOrderGen/Rpc.hs` — DRIV-02's driver already exists and is V2-complete
  after Phase 21 (`OrderShape` + `LogUniform` vega + chunked `create_orders`).
- `offchain/lib/Rig/Manifest.hs` — all addresses come from here; a new router address means a new
  manifest key (and the deploy script must print it for the cross-check).
- `offchain/rig/deploy-rig.sh` / `verify-rig.sh` — the rig lifecycle and liveness probes a
  swappable-pool step extends.
- `offchain/rig/capture-batch-return.sh` — the provenance-bearing artifact pattern for evidence.

### Established Patterns
- Live evidence over assertion: every prior phase captured real chain artifacts with provenance.
- `cabal test` MUST stay chain-independent (measured with anvil stopped in Phase 21).
- Manifest-only addresses; the literal-purge grep covers `offchain/` `*.hs` and `*.sh`.
- Zero `-Wall` warnings; **`cabal build --enable-tests -j all`** is the real gate (`cabal build
  -j all` is vacuous — confirmed four times in Phase 21).

### Integration Points
- `offchain/app/Main.hs` — composes the drivers in one `runWeb3'`; `write_price` and the order
  driver both already run there.
- `PriceSetter.Rpc.write_price` — gains the swap-calldata artifact responsibility.

</code_context>

<specifics>
## Specific Ideas

- "The only thing a client can do is query the DB api" — the guiding principle: the offchain side
  observes, the chain computes. No client-side `writeTimepoint`.
- "If so, the approach is to write the issue on develop branch" — the user's standing instruction
  for anything needing plank-side work; issue #17 is that.
- Both price drivers stay: `write_price`/PriceSetterHook is ADDED beside, never replaced
  (roadmap SC-1, unchanged by the architecture correction).

</specifics>

<deferred>
## Deferred Ideas

- The v6.0 subgraph indexing this phase's event stream — queued milestone (issue #14).
- Whether `write_price`'s slot0 cheat should eventually be replaced by real price-moving swaps —
  out of scope; the cheat-swap pattern deliberately keeps price control offchain.

</deferred>

---

*Phase: 22-live-stochastic-drivers*
*Context gathered: 2026-08-02*
