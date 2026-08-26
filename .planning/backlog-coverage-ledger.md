# Backlog Coverage Ledger — `todo.md` + `notes/STOCHASTIC_MODEL.md`

Purpose: account for **100% of the items** in `todo.md` and `notes/STOCHASTIC_MODEL.md` — every atom gets a
disposition, so nothing is silently dropped. "Coverage" = every item is *accounted for*, not
that every item is *implemented in this session*. Ordering is a **proposal** pending user
approval. Nothing here is executed without the user approving each code change (heavy-
intervention mode: no autonomous agents).

Status legend:
- ✅ **DONE** — already implemented/verified (evidence noted)
- 🔀 **OTHER-TRACK** — owned by a paused milestone or a peer worktree; account for, don't build here
- ❓ **RESEARCH** — open question → produces a written decision/note, not code
- 🎯 **ACTIONABLE-HERE** — in this session's plank/experiment-rig scope; build with user in loop
- ⚠️ **STALE** — the file's claim is outdated vs the current tree

Disposition is my recommendation; the **Scope** and **Order** are the two decisions I need from you.

---

## A. `todo.md`

| ID | Item (todo#) | Status | Evidence / Note | Disposition |
|----|-------------|--------|-----------------|-------------|
| T1 | Algebra avg history test (1) | ✅ DONE | marked done | closed |
| T2 | Avg algo via UniV3 OracleLib (2) | ✅ DONE | marked done | closed |
| T3 | spec_order type system (10) | ✅ DONE | marked done | closed |
| T4 | Algebra volatility history test (5) | ✅ DONE | marked done | closed |
| T5 | Plank implementation (4) | ✅ DONE | commit e2609ba | closed |
| T6 | Differential Algebra vs UniV3 (3, partial) | 🔀 OTHER-TRACK | v2.0: tick-avg done (Ph 8–9); variance = Ph 10–11 **paused** | defer → v2.0 |
| T7 | Differential testing with Plank (5, NEXT) | 🔀 OTHER-TRACK | v2.0 `plank-voldiff-plan.md`, Ph 10–11 | defer → v2.0 |
| T8 | vol algo via UniV3 OracleLib (6) | 🔀 OTHER-TRACK | v2.0 scope boundary marks this **low-value/deferred** | defer → v2.0 |
| T9 | risk type system (11): RiskMeasureLib/RiskDiscount empty bodies | ⚠️ STALE | **deleted as refuted** (7a01862); not empty-to-fill | close as refuted (confirm) |
| T10 | Haskell API (12, in progress) | 🔀 OTHER-TRACK | rpc_api peer `mv15a18k` (PR #9) | defer → peer |
| T11 | VegaAccountMod skeleton / PLANK_SKIP (13) | ⚠️ STALE | v3.0 **shipped** it live; PLANK_SKIP empty | close as done |
| T12 | How to track vega from panoptic? (14) | ❓ RESEARCH | design question; precedes PanopticVegaLens | research note |
| T13 | PanopticVegaLens module (14) | 🎯 ACTIONABLE | tracks vega per strike vs realized vol | build (later wave) |
| T14 | StochasticProcess / `ExchangeRateDifussion` (14) | 🎯 ACTIONABLE | **impose stochastic process on tick — direct successor to PriceSetterHook**; math in NOTES (N1–N4) | build (early) |
| T15 | 14.1 entry point univ4 poolKey → Plank | 🎯 ACTIONABLE | | build |
| T16 | 14.2 entry point panoptic → Plank (reactive) | 🎯 ACTIONABLE | partially scaffolded: `MarketStateSocket.plk` | build |
| T17 | 14.3 pool that ONLY allows arbitrary price setting | ✅ DONE | **PriceSetterHook** (PR #11 merged + deploy script a0dfa12) | closed |
| T18 | PanopticTokenId type vs Panoptic schema (15) | 🎯 ACTIONABLE | | build (later wave) |
| T19 | Build LDF (16, in progress) | ✅ DONE | LDF geometry types shipped: PriceCoordinate+EtaSplitKernel (8fe5f7b), PricePair (d094776), PriceOrderedPair (b17fef7), PriceBucket (981b7b4); 7 fuzz tests green; grounded in lean4-spec `eta_split_kernel_identity` (see N7) | closed |
| T20 | map builderCode on panoptic ↔ Algebra dynamic-fee code (17) | 🎯 ACTIONABLE | | build (later wave) |
| T21 | comptime vs function advantages (16 sect.) | ❓ RESEARCH | Plank language question | research note |
| T22 | discrete integral on Plank + API (16 sect.) | ❓ RESEARCH | Accumulator for cumulativeAmount over ticks | research note |
| T23 | Option type at EVM level (16 sect.) | ❓ RESEARCH | `std/option.plk` study | research note |
| T24 | Accumulator type at EVM level (16 sect.) | ❓ RESEARCH | `std/utils.plk` study | research note |
| T25 | feat/arrays upgrades multicall for vega create order | 🔀 OTHER-TRACK | pointer; depends on Plank `feat/arrays` branch | track, don't build |

## B. `notes/STOCHASTIC_MODEL.md`

| ID | Item | Status | Evidence / Note | Disposition |
|----|------|--------|-----------------|-------------|
| N0 | `ControllerEntryPoint.sol :: IHook` (beforeSwap → plkWrapper via LibCall) | 🎯 ACTIONABLE | reactive socket partially real: `MarketStateSocket.plk` + `IMarketStateSocket.plk` | build (ties to T16) |
| N1 | Fixed-Income CFMM: engineer product from dynamic-fee kernel + LDF | ❓ RESEARCH | frames LDF work (T19) | research note → feeds T19 |
| N2 | Single LP position + swap continuum; state (di=20,i=100,i_l=−120,i_u=120,L=1e18,Y=100e18) | 🎯 ACTIONABLE | concrete fixture for experiment rig | build (early, with T14) |
| N3 | Stochastic spec: λ~U(.6,1), N_t\|λ~Poisson, Δȳ~U(19,21), Δy~LogNormal(σ=1.2), I=±1 p½, ΔY(t)=Σ I·Δy | 🎯 ACTIONABLE | **the stochastic process to impose** — core of T14 | build (early) |
| N4 | EVM randomness proxy: prevrandao/difficulty; binomial kernel? | ❓→🎯 | research → then implement RNG source for N3 | research then build |
| N5 | Deterministic proxy Δy(t)=19+1.0001^(η·t⁴) | 🎯 ACTIONABLE | deterministic alternative to N3 for reproducible runs | build (early) |
| N6 | `sqrt_price_math.plk` getNextSqrtPriceFromAmount0RoundingUp empty body | 🔀 OTHER-TRACK | lives in `lib/plankified-univ3` (submodule) | defer → plankified-univ3 track |
| N7 | LDF type design: PriceCoordinate / PricePair / PriceOrderedPair / PriceBucket / TickBucket | ✅ DONE (≡T19) | all shipped; `basis 1.0001` NOT stored (delegated to tick_math.plk via EtaSplitKernel); η = subs_elasticity (Q64.96); TickBucket consumed from lib/TickUtils. Closes types::PricePair + types::PriceBucket in LiquidityAmounts.plk (VegaNominal/Portafolio still missing → later phase) | closed |
| N8 | Unistrata (UnistrataHook + VarianceLib/NavLib/WaterfallLib → PositionManager → tokenId → deposit) | 🔀 OTHER-TRACK | `lib/unistrata` dependency study | reference, don't build |
| N9 | Shizo {} | 🔀 OTHER-TRACK | `lib/shizo` (reactive deps) study | reference |
| N10 | Mochi-Yield {} | 🔀 OTHER-TRACK | `lib/mochi-yield` study | reference |
| N11 | Centrifuge BalanceSheet deposit tests (ERC6909/ERC20) | 🔀 OTHER-TRACK | dependency study | reference |
| N12 | VOLATILITY_INSTRUMENTS heading (empty) | ❓ RESEARCH | empty section; Lean track has VolInstrument.lean | note as pointer |

---

## Proposed disposition tally (100% accounted for: 25 todo atoms + 13 notes atoms = 38)

- ✅ DONE / closed: T1–T5, T17 (+ ⚠️ close: T9, T11) = **8**
- 🔀 OTHER-TRACK (defer, not built here): T6, T7, T8, T10, T25, N6, N8, N9, N10, N11 = **10**
- ❓ RESEARCH note (decision, not code): T12, T21, T22, T23, T24, N1, N12 (+ N4 research half) = **7–8**
- 🎯 ACTIONABLE-HERE (build, user-gated): T13, T14, T15, T16, T18, T19, T20, N0, N2, N3, N4, N5, N7 = **13**

## Proposed execution order for the 🎯 ACTIONABLE set (the experiment-rig through-line)

**Wave 1 — Impose a stochastic process on the tick** (direct successor to PriceSetterHook):
1. N2 — pin the single-LP experiment state fixture (di=20, i=100, …)
2. N4 (research) → decide the on-EVM RNG source (prevrandao vs supplied seed)
3. N5 — deterministic proxy Δy(t)=19+1.0001^(η·t⁴) first (reproducible, no RNG risk)
4. N3 / T14 — the full stochastic `ExchangeRateDifussion` (λ/Poisson/LogNormal/±1) driving tick writes through PriceSetterHook

**Wave 2 — Entry points into Plank:**
5. T15 — univ4 `PoolKey` → Plank entry point (14.1)
6. N0 + T16 — panoptic → Plank reactive entry point, building on `MarketStateSocket.plk` (14.2)

**Wave 3 — LDF:**
7. N1 (research framing) → T19 + N7 — the PriceCoordinate/PricePair/PriceBucket LDF type system

**Wave 4 — Panoptic vega:**
8. T12 (research) → T13 — PanopticVegaLens vega tracking
9. T18 — PanopticTokenId type
10. T20 — builderCode ↔ Algebra dynamic-fee map

**Language research notes (fold into whichever wave first needs them):** T21, T22, T23, T24.

---

## Resolved decisions (2026-07-27)

1. **Scope = `src/` or `test/` only.** In-scope = items whose deliverable is a file under `src/`
   or `test/` in THIS worktree (experiment drivers under `foundry-scripts/` count, as PriceSetterHook's
   does). OUT of the *build* set, recorded here only for accounting:
   - lib/ submodule work → **N6, N8, N9, N10, N11** (Unistrata/Shizo/Mochi/Centrifuge/sqrt_price_math)
   - external peer repo → **T10** (Haskell API, rpc_api)
   - paused sibling milestone → **T6, T7, T8** (v2.0 vol-diff, its own roadmap) and **T25** (feat/arrays pointer)
   - pure-research questions with no src/test artifact → **T12, T21, T22, T23, T24, N1, N12, N4-research** →
     folded in as **design inputs** to the item that needs them, not standalone deliverables.
2. **Order = experiment-rig through-line** (Waves 1→4 above).
3. **GSD form = new milestone v5.0** "Experiment Rig", Phases 20–23, per-item PLAN.md. Heavy user
   intervention: no autonomous coding agents; each PLAN and each code change is user-approved;
   mandated two-step review (Reality Checker + specialist) runs on the roadmap and each plan.

## Reframe (2026-07-27, user)

- **Executable spec = `todo.md` items + the inline code-comment sketches in both files.**
  notes/STOCHASTIC_MODEL.md *prose/math* (the λ/Poisson/LogNormal derivation N3, moment relations) is **secondary
  context, NOT a build target.** The code SKETCHES are authoritative; the surrounding math is support.
- **Process space = pure TICK process on a NO-LIQUIDITY pool.** Drops the amount↔tick map (Solidity
  B1), the LogNormal primitive gap (Reality B1), and the moment check (Reality M3) — all tied to the
  now-secondary NOTES math. Phase 20's real deliverable is the **`ExchangeRateDifussion` type +
  `StochasticConfig`** sketch from `todo.md` (§14), a tick-space process producing `nObs` tick
  observations, driven through PriceSetterHook.
- **Verification lives in a forge test** via the hook's proven `TickCheat`/`vm.store`→`vm.load` path
  (in-process, assertable), NOT the external `cast rpc` live-node path (dissolves Reality B2).

## Atom-count correction (Reality m1/m2)

N7 (LDF PriceCoordinate/PricePair/PriceBucket) is NOT from notes/STOCHASTIC_MODEL.md — it is `todo.md`§16, already
tracked as **T19**. So T19≡N7 (one source, one atom). notes/STOCHASTIC_MODEL.md has **12** atoms (N0–N6, N8–N12),
not 13. Raw-bullet coverage of both files is complete; the earlier "38 atoms" tally double-counted
the paired items (N3/T14, N0/T16, T19/N7). True in-scope build-item count = **10**.

## Re-scope (2026-07-28, user): v5.0 = Phases 21–23 only

**Phase 20 / `ExchangeRateDifussion` is OFF-CHAIN Haskell work** — the calls are driven off-chain
(rpc_api peer `mv15a18k`'s `StochasticOrderGen`, imposing the tick via `setStorageAt` against
PriceSetterHook, which we already shipped for exactly this). So **T14, N2, N3, N4, N5 → OTHER-TRACK
(Haskell/off-chain)**; Phase 20 is delegated, not built here. Our on-chain scope is the surfaces that
off-chain track calls into: Phases 21–23.

## In-scope build set for v5.0 (Phases 21–23, src/test deliverables only)

Phase 21 — Entry Points (split per review; these are the reactive-price-socket architecture from
commit 0cc21de, currently half-scaffolded/non-compiling):
  - **EXPR-04 / T15** — univ4 `PoolKey` → Plank: complete `MarketId` (`{id:bytes32, key:cbytes}`) +
    its constructor from a `PoolKey`, CALLED-green (id == canonical univ4 PoolId). *Foundational — the
    socket and hook both reference market identity, so this is first.*
  - **EXPR-05 / N0** — `ControllerEntryPoint` synchronous `beforeSwap` v4 hook (greenfield, absent).
  - **EXPR-06 / T16** — `MarketStateSocket` reactive-network socket (greenfield: author slots/selectors/
    bodies so it compiles + is CALLED-green; uses the `reactive-smart-contracts` skill).
Phase 22 — LDF Type System: **T19/N7** (design input N1); must satisfy the existing dangling consumer
`LiquidityAmounts.plk` (imports `PricePair`/`PriceBucket`).
Phase 23 — Panoptic Vega Lens: **T13** (design input T12), **T18** (cite panoptic-v2-core TokenId
layout; `PanopticTokenId.plk` + `PanopticTokenIdSetterLib.plk` exist as placeholders), **T20**.
