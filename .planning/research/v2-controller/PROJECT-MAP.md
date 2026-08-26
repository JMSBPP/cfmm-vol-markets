# PROJECT-MAP — CFMM Payoff Replication (Plank ↔ GAMS), oriented for the EVM adaptive controller

**Generated:** 2026-06-28 · **Audience:** the on-chain (EVM/Plank) adaptive-feedback-controller designer
· **Mode:** read-only survey. Citations are file paths + commit subjects. Unknowns are marked `unknown`.

---

## 1. What the project is

A research-engineering framework to **replicate an arbitrary contingent payoff `Φ(S_T)` out of CFMM fee
revenue** by tuning two parameter families: the **dynamic fee kernel** and the **liquidity density
function (LDF) / bonding curve**. Two tracks that historically didn't talk:

- **On-chain:** CFMM dynamics written in **Plank** (`.plk`, custom EVM language; compiler
  `lib/plank-monorepo/plankc/`, `v0.1.1`, backend `sona`), compiled to bytecode via FFI
  (`lib/plank-foundry-deployer` `plankDeployFFI`), behind a Uniswap-V4-style `beforeSwap` hook.
  Solidity/Foundry is thin glue.
- **Off-chain:** a **GAMS** algebraic model that solves for optimal curve/fee parameters.

Source of truth for scope: `.planning/PROJECT.md`, `.planning/REQUIREMENTS.md`, `.planning/ROADMAP.md`.

**The current milestone (v1) is OPEN-LOOP PLUMBING with a STUB GAMS solver** — prove a parameter set
flows `GAMS output → encode to Plank fixed-point → write via initVolTermStructure → read back & round-trip
verify`, bound to one authoritative kernel. It explicitly does **not** prove payoff replication, run a
real optimizer, or assert LDF conformance (`.planning/REQUIREMENTS.md` v2 section).

> **Direct relevance to you:** the **closed-loop adaptive feedback controller** is the *named next
> milestone*. It is `CTRL-01` (control law in `src/DynamicCFMM.plk` that updates `xi`/`iota` as the
> market evolves) and `CTRL-02` (V4 `beforeSwap` hook driving it on-chain), both listed under
> **v2 / Out of Scope** in `.planning/REQUIREMENTS.md:83-86` and `.planning/PROJECT.md:39`. Phase 7's
> `PIPE-02` guard *actively keeps in-loop updates out* of v1 (`.planning/ROADMAP.md:121,164`). Your
> milestone is the thing v1 was built to sit under.

---

## 2. Branch / worktree topology

`develop` is the **integration branch** (the gate target). Per-peer feature branches live in
worktrees off it (`scripts/peers.tsv`, `.agents/evm-controller/ONBOARDING.md`). All eight worktrees
currently share the same base snapshot `987912c chore(migration): snapshot peer WIP before cutting
develop`; tracks diverge above it.

| Worktree | Branch | Owns | Built (evidence) |
|---|---|---|---|
| `cfmm-replicationPlank` (main) | `feat/gams-solidity-difftest` | **GAMS↔Sol differential bridge** (PID 299098) | gamsdiff pipeline + worktree infra: `cc88cde build: make gams-fixtures target`, `dd36c00 idempotent worktree-per-peer setup script`, `eaf97a2 migration runbook`. WIP/untracked: `225a..c/`, `lean/`, three `docs/superpowers/specs/2026-06-28-*` design docs. |
| `cfmm-wt/ci` | `feat/ci` | **CI + version control** | Same tip as main (`987912c`); the CI lane *designs* live as untracked specs in main: `track-loose-deps-design.md` (track 4 loose forge deps: v4-core submodule @`59d3ecf5`, vendor unistrata/shizo/mochi-yield) and `develop-gate-design.md`. STATE.md not returned on this branch (`unknown` whether `.planning/` is carried). |
| `cfmm-wt/evm-controller` | `feat/evm-controller` | **on-chain EVM controller** (YOUR track) | Onboarding + peer registration only so far: `bcd1816 docs(evm-controller): onboarding brief`, `3069957 feat(wt): register evm-controller peer`. Branch also carries the merged gate + develop history. **No controller code yet.** |
| `cfmm-wt/gams` | `feat/gams-payoff` | **GAMS model** (PID 175812) | Real payoff scaffolding (ahead of the v1 "stub" plan): `efba2c8 feat(gams): payoff scaffolding + first per-theorem program (zero-slippage)`, `41c211a PayoffModule rolled-up assertion test driver`, `94150f3 reconcile spec §8 with shipped test rollup`, spec revs 2–4, `spec-preflight` Makefile target. Untracked GDX/build outputs. |
| `cfmm-wt/gamsdiff` | `feat/gamsdiff` | **GAMS→Sol diff gateway** (PID 299098) | `tools/gamsdiff` python pkg + fixtures + Plank harness: `be52311 gamsdiff-impact CLI + committed price_impact_kernel fixture (723 rows)`, `674284a price-impact-kernel fixture driver + committed GDX`, `bf332b6 docs(gamsDiff): handoff for the price-impact diff-test author`. |
| `cfmm-wt/lean4-spec` | `feat/lean4-spec` | **Lean4 proofs + math spec** (PID 253818) | Discharged eta-payoff theorems via Aristotle: `b8662df Aristotle re-discharges — all 9 theorems now proven`, `841df7b Aristotle proves band-max (golden-bound)`, `091e794 commit lake-manifest.json (v4.30.0 + LeanEVM pins)`, doc set under `lean/exp/eta_*.md`. |
| `cfmm-wt/plank` | `feat/plank` | **Plank `.plk` + Solidity glue + bridge** (`ul2inqpl`) | `490b706 fix(market): make ReferenceMarket compile`, `938ab96 add PriceImpactKernelHarness`, `8c8b1e4 add CESLongPayoff stateless ½-kernel trader payoff`. Owns `src/`, `foundry.toml`, `remappings.txt`. |
| `cfmm-wt/sol-tests` | `feat/sol-tests` | **Foundry test suite** (PID 284909) | Differential tests consuming gamsdiff fixtures: `3bec7c2 differential test for price-impact kernel vs getNextSqrtPriceFromAmount0RoundingUp`, `7f9c0c1 guard pricing-kernel fixture pinned to balanced eta=1/2`, merges from `develop`. |

> Ownership rules (do not edit another track's files) are codified in `CLAUDE.md` and restated in
> `.agents/evm-controller/ONBOARDING.md`. **`src/` is currently 100% Plank and owned by `ul2inqpl`** —
> coordinate file layout for the controller contract with that peer before writing under `src/`.

---

## 3. `.planning/` divergence between branches

Per-branch `.planning/STATE.md` (`git show origin/<branch>:.planning/STATE.md`):

- **Identical** across `develop`, `feat/evm-controller`, `feat/gamsdiff`, `feat/lean4-spec`,
  `feat/plank`, `feat/sol-tests`: `milestone: v1.0`, `status: executing`,
  `stopped_at: Completed 01-01-PLAN.md (sanitized baseline)`, `completed_phases: 1`, `percent: 50`.
  i.e. the *plan-of-record* (`.planning/`) has **not** advanced past **Phase 1 plan 01-01** on any
  branch — the real work below lives in code/specs, not in updated `.planning/` phase state.
- `feat/ci` and `feat/gams-payoff`: `STATE.md` did **not** return content — `unknown` whether those
  branches carry `.planning/` (likely they branched before/around it or dropped it).
- **Caveat:** the roadmap's "Phase 5 = stub GAMS solver" is already overtaken on `feat/gams-payoff`,
  which has *real* per-theorem payoff programs (`efba2c8`). The planning docs lag the code.

The roadmap (`.planning/ROADMAP.md`) phase order, for reference: 1 Repo restructure → 2 Vendoring +
shared kernel + toolchain pin → 3 Encoding contract + theory grounding → 4 Plank bridge-surface impl
& compile → 5 GAMS stub emitter → 6 open-loop runtime bridge → 7 e2e run.

---

## 4. The integration gate (`.github/workflows/develop-gate.yml`)

Found on `feat/evm-controller` and `feat/gams` worktrees (not on `feat/ci` tip / main checkout).
PR-only trigger into `develop`. Structure:

- **`approve`** (hosted, `environment: develop-gate`) — the single human-in-the-loop approval gate;
  one click *before* untrusted code runs on the self-hosted runner.
- Five heavy jobs, all `needs: [approve]`, all on `[self-hosted, cfmm-build]`:
  1. **`forge`** — `forge test --via-ir --offline`, with the panoptic-safe submodule init
     (`init lib/panoptic-v2-core`; set `submodule.lib/panoptic-helper.update none`; then recursive).
     `--offline` is mandatory or forge re-inits recursively and hangs on the `panoptic-helper` cycle.
  2. **`gams`** — `make compile-gams`.
  3. **`plank`** — `git submodule update --init lib/plankified-univ3` then `make compile-plank`.
  4. **`gamsdiff`** — `cd tools/gamsdiff && uv sync --frozen && uv run pytest`.
  5. **`lean`** — `cd lean && lake build`, with a **no-`sorry`/`admit` guard** via Lean's own
     compiler warning (`declaration uses 'sorry'` ⇒ fail). Passes trivially if no `lean/` project yet.
- **`gate`** — the **sole required check** (branch protection blocks merge until green); aggregates
  the five results (`success`|`skipped` ok, else fail).

**Implication for you:** your controller PR must keep the **whole** suite green — a broken
`.gms`/`.plk`/pytest/Lean anywhere reds `gate` and blocks every peer. Build locally the panoptic-safe
way and use `forge test --via-ir --offline` (`.agents/evm-controller/ONBOARDING.md §1-2`).

---

## 5. Dependencies & handoffs between tracks

Data/spec flow (open-loop v1):

```
payoff spec ─▶ GAMS (model/*.gms) ─▶ GDX ─▶ gamsdiff (tools/gamsdiff: GDX→JSON fixtures)
                   │                              │
                   │                              ▼
            (Lean proves the         test/gamsDiff/fixtures/*.json  +  DiffContract.sol (selectors/EPS)
             payoff/kernel math)              │
                   │                          ▼
                   ▼                  sol-tests: *.diff.t.sol  ──diffs──▶  Plank harness (.plk via plankDeployFFI)
            lean/exp/eta_*.md                                              test/gamsUtils/*Harness.plk
```

Concrete, evidenced handoffs:

- **GAMS → gamsdiff → sol-tests.** gamsdiff turns GAMS GDX into committed JSON fixtures + a Plank
  harness and hands them to the Foundry diff-test author:
  `test/gamsDiff/PRICE_IMPACT_HANDOFF.md`, fixture `test/gamsDiff/fixtures/price_impact_kernel.json`
  (723 rows), harness `test/gamsUtils/PriceImpactKernelHarness.plk` (selector `0x157f652f`,
  signature `getNextSqrtPriceFromAmount0RoundingUp(uint160,uint128,uint256,bool)`), tolerance
  `assertApproxEqRel EPS=1e3` (1e-15 rel, measured floor 2.02e-16). Consumed by
  `test/gamsDiff/PriceImpactKernelPlank.diff.t.sol` (`3bec7c2`, sol-tests).
- **Contract guard (CI lane).** `docs/superpowers/specs/2026-06-28-diff-handoff-contract-design.md`
  pins the producer→consumer interface via a JSON Schema + committed Solidity constants
  (`test/gamsDiff/DiffContract.sol`, `price_impact.contract.json`), CI-checked without forge.
- **Plank ↔ GAMS bridge (the v1 deliverable, still a zero-line gap).** Write path is
  `IMarketDynamics.initVolTermStructure` (selector const `0xd9c112ef` in
  `src/interfaces/IMarketDynamics.plk` — flagged *likely wrong* in `.planning/ROADMAP.md:171`,
  recompute from the signature). State lives in `src/ReferenceMarket.plk` (flat slots
  `SLOT_LIQUIDITY=0, SLOT_TICK_SPACING=1, SLOT_CURRENT_TICK=2, SLOT_TICK_LOWER=3, SLOT_TICK_UPPER=4`;
  the `init` body that stores the vol-term-structure is still a TODO stub). Read-back via
  `IMarketDynamicsLens` getters (`getPriceElasticity`/`getStatePartitionDelta`/`getBaseTick`).
- **Lean → math correctness.** Lean proves the payoff/kernel theorems the GAMS model and controller
  rely on (`lean/exp/eta.lean`, `lean/exp/eta_*.md`); the gate's no-`sorry` guard keeps them honest.
- **CI → everyone.** `feat/ci` must make the 4 loose forge deps resolvable from a clean clone
  (`track-loose-deps-design.md`) — prerequisite for the self-hosted gate to build at all.

### Where the EVM controller depends on the others

1. **Control law (math) — Lean, already proven.** `lean/exp/eta_pi_trader_delta_control.md` answers
   *exactly* the controller's core question: **can the protocol adaptively control trader payoff by
   adjusting tick spacing `Δi`?** Proven theorem `lean/exp/eta.lean ::
   pi_trader_half_strictly_increasing_in_Δi`:
   - Trader payoff (Carr–Madan squared-slippage form) `π_{1/2} = (P_{1/2}(i)·Δ^I − Δ^O)²` with
     `P_{1/2}(i) = λ^{i·Δi}`.
   - **Large-trade regime `Δ^I ≥ L̄`:** `π` is strictly increasing in `Δi` ⇒ **tick spacing is a clean
     one-parameter control knob.**
   - **Small-trade regime `Δ^I < L̄`:** the residual flips sign at `P = L̄/(L̄−Δ^I)` ⇒ `π` first
     decreases to zero then increases — **non-monotonic; control must be piecewise**, conditioned on
     which side of the zero-crossing the trade lies. This is the single most important design fact for
     your controller: the actuator (`Δi` = `statePartitionDelta`/`tickSpacing`) is only monotone in
     the large-trade regime.
2. **Actuators / state surface — Plank (`ul2inqpl`).** The controller updates `xi` (≈
   `priceElasticity`/LDF `alpha`) and `iota` (≈ `statePartitionDelta`/`tickSpacing`, `baseTick`) — the
   same parameters the v1 bridge writes via `initVolTermStructure` and reads via the lens. You need
   that write/read surface to **exist and compile** (Phase 4, `PLNK-01..04`) before a closed loop can
   actuate. Today those `.plk` bodies are stubs (`.planning/STATE.md` blockers; `ReferenceMarket.plk`
   `init` is a comment-only TODO).
3. **Plant model / reference outputs — GAMS + gamsdiff.** The price-impact kernel
   (`getNextSqrtPriceFromAmount0RoundingUp`) under `src/exp/CESLongPayoff.plk` is the per-swap state
   transition your controller closes the loop around; GAMS provides the reference trajectory and
   gamsdiff the verified fixtures/tolerances.
4. **Hook integration — Plank/V4.** `CTRL-02` is a V4 `beforeSwap` hook driving the controller
   on-chain; the `beforeSwap` hook scaffold is Plank-owned. `unknown`: no hook contract exists yet.
5. **CI — must stay green.** Your PRs go `feat/evm-controller → develop` through the same `gate`.

---

## 6. Key facts & open questions for the controller designer

- **Controller is v2/next-milestone, not yet started.** No `src/DynamicCFMM.plk` (or any controller
  file) exists on any branch; `feat/evm-controller` carries only onboarding + the merged gate.
- **The control law is already formalized and proven** (regime-dependent monotonicity in `Δi`) —
  reuse `lean/exp/eta_pi_trader_delta_control.md` + `eta.lean` as the spec, don't re-derive.
- **Actuator parameters:** `xi`↔`priceElasticity`/LDF `alpha`; `iota`↔`statePartitionDelta`/
  `tickSpacing`/`baseTick`. Fixed-point conventions WAD `1e18` + Q64.96 (kernel,
  `.planning/REQUIREMENTS.md` KERN/MAP).
- **Prerequisites that are still incomplete:** the open-loop bridge (`initVolTermStructure` body,
  lens getters) is a zero-line gap; selector `0xd9c112ef` is suspected wrong; most `.plk` sources are
  stubs/parse-errors. A closed loop sits on top of all of this.
- **Coordinate `src/` layout with `ul2inqpl`** before writing controller Solidity/Plank; never touch
  `foundry.toml`/`remappings.txt`/other peers' files (`CLAUDE.md`, ONBOARDING §0).
- **`unknown`:** exact home of the controller contract (Plank vs Solidity wrapper); whether the V4
  `beforeSwap` hook exists; whether `feat/ci`/`feat/gams-payoff` carry `.planning/`.
