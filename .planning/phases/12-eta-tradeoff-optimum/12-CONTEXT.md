# Phase 12 — CONTEXT: Optimal η for the FLAIR/MEV trade-off

**Origin (user, 2026-07-30/31):** after Phase 11 proved the fee block cannot
trade off FLAIR against MEV (M6a degeneracy; T24 flat-fee escape REFUTED),
the user directed: "the answer is exploring [demand structure]" via
Capponi's curvature results — "derive the optimal η for the FLAIR/MEV
trade-off and send the workload to Aristotle." Runs PARALLEL-sanctioned.

## Inputs in place

- **Phase 11 layer (all proven, on both remotes):**
  `MevOptimization.lean` (ptrade kernel: `ptrade_mem_Ioc`, `_strictAntiOn`,
  `_strictConvexOn`, `_monotoneOn_dt/_sigma`; λ_ARB monotonicity block,
  solved infimum, `Theta_lambdaMEV_identification`) and
  `MevJointProgram.lean` (`joint_corner_degeneracy`,
  `mev_ge_flat_under_flair_budget_false` + witness, `mevTotal`, `mevNet`,
  `taxFraction`; path-level `flairPath`/`mevPath`).
  `FlairOptimization.lean` (λ_FLAIR affine identification, corner).
  `VolInstrument.priceEta η Δi i = λ^((i/2)·Δi·η)` with `_pos`,
  `_strictMono` (η·Δi > 0), `priceEta_one = tickPrice`.
- **The anchor:** Capponi & Jia, *The Adoption of Blockchain-based
  Decentralized Exchanges* (arXiv:2103.08842), §5.1: pricing family
  `F_k = (1−k)·A·F₀ + k·F₁` (linear → constant-product), curvature ↑ k;
  **Lemma** (curvature lemma 1): expected arb-loss ratio ↓ k AND investors'
  surplus ratio ↓ k; **Proposition** (curvature proposition, α > β): LP
  expected payoff ↑ on [0,k*], ↓ on [k*,1], interior k* ∈ (0,1); liquidity
  freeze least likely at k*; **welfare Proposition**: deposit efficiency
  and social welfare maximized at k*. PDF:
  `../plank/refs/mev/CapponiJiaAdoptionDEX.pdf`. Four sibling Capponi PDFs
  beside it (JIT, LitToDark, DiscreteClearing, Timeboost).
- **The η location requirement** (plank todo #227, user-authored): η is an
  asset-demand parameter — a substitution elasticity between asset and
  cash; hook location beforeSwap/afterSwap; "find the best economic
  controller APPLICATION for η then plank maps it to implementation."
- Memory: `eta-curvature-controller` (the mapping k ↔ η and the
  de-degeneration argument).

## The mathematical target

1. **Transcription** (notation precedence BINDING: Capponi's `k` maps ONTO
   our `η`; every remap in a notation-map paragraph; our η/λ/γ/φ never
   reassigned): the curvature family in the doc's geometry — either
   Capponi's F_k mixture verbatim with `k → (η-derived)`, or the exact
   relation between `priceEta`'s exponent η and the mixture curvature —
   the RESEARCH must decide which transcription is faithful AND provable,
   and surface the decision if genuinely ambiguous.
2. **The two-sided lemma in our objects:** an arb-loss functional
   decreasing in curvature (channel: slippage — relate to λ_ARB or a
   Capponi-faithful loss ratio; do NOT conflate with ptrade's fee channel
   without proof) AND a surplus/volume functional decreasing in curvature.
3. **The interior optimum:** LP-payoff single-peakedness and existence of
   η* (Capponi's k*-analog) — the FIRST interior optimum in the entire
   program (everything in Θ_φ was corner/saturation). Where the discrete
   tick geometry departs from Capponi's continuum two-period model, label
   OPEN honestly rather than force the transcription.
4. **The joint program over (Θ_φ, η):** fee block at its proven corner
   (import Phase 11 results by name), η carrying the trade-off; state
   sup-FLAIR/inf-MEV jointly with η interior — the de-degeneration theorem.

## Workflow constraints (binding, unchanged)

- Doc-driven Aristotle: new doc block in VOLATILITY_INSTRUMENTS.md (after
  the M-blocks / near ### MEV or its own `## ETA` section — placement per
  plan), minimal prose MAXIMAL math, notation gate (this time η is the
  PROTECTED symbol; Capponi's `k`, `α`, `β` are the externals needing
  remaps — note doc α/β collisions with Θ_φ's α, β: Capponi's arrival
  params get NEW symbols), HEAVY USER APPROVAL before insertion, two-
  reviewer gates on doc block and prompt, sha-pinning, strictly-serial
  per-project queue discipline (parallel NEW projects sanctioned).
- Bundle: doc + ALL proved modules (13 by now); Aristotle authors
  statements AND proofs; hypothesis pre-empt paragraph mandatory (the
  provers corrected T15/T17 — expect positivity/domain hypotheses).
- Landing: byte-identity, build, axiom sweep, fidelity diff, both remotes,
  LEAN_TRACEABILITY rows, doc summarization pass, memory.
- Plank consumer: todo #227 closure — the η controller application answer
  feeds plank's hook implementation mapping.
