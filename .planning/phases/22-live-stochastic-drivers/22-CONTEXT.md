# Phase 22: Live Stochastic Drivers - Context

**Gathered:** 2026-08-02
**Status:** Ready for planning — **with a hard upstream gate (issue #17)**

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

### UPSTREAM GATE — issue #17 (filed 2026-08-02)

**Phase 22 cannot execute until the rig's pool is SWAPPABLE.** Verified blockers:
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
