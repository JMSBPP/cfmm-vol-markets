# Phase 8: panoptic vol-claim lean4 formalization - Context

**Gathered:** 2026-07-18
**Status:** Ready for planning

<domain>
## Phase Boundary

Formalize `spec/protocol/panoptic.md` in the `lean/` Lake project: the contract as a volatility option (payoff π^σ = ΔQ_v·(σ²(i(t)) − σ²_K)⁺ and the ΔQ_v identity), the vol-claim price as an option-replication cost (structural decomposition p_πσ = p₀ + α₁·p_call + α₂·p_put), the streaming-premium θ kernel (derived on the lattice), and the vega-like greek υ ≡ Δπ/Δσ² with its ATM/OTM identification hypotheses. Includes spec hygiene (fix θ sign typo, repair references, commit the spec) and vendoring the load-bearing cfmm-discrete notes. Lean4-track phase, independent of Phases 2–7 (owned by other peer sessions).

</domain>

<decisions>
## Implementation Decisions

### Scope & home
- **Extend `vol_markets`** — new modules live inside the existing `vol_markets` lib (e.g. `vol_markets/Panoptic.lean`, `vol_markets/Upsilon.lean`; exact file split is planner's call), added to the lib's `roots` in `lean/lakefile.toml`. No new lean_lib.
- **Lean scope = analytical blocks only**: payoff identity, replication decomposition, θ kernel, υ definition + properties. The **econometric blocks** (Q_M = Q_M(υ=0) + υσ² regression, υ(t) linearization, Panoptic-subgraph access) are **not Lean objects** — they are handled via the **`structural-econometrics` skill**, producing a derived econometric model-spec artifact (markdown) alongside the Lean work.
- **ATM/OTM null hypothesis** (Δυ/Δi maximal at the money, exponentially decaying OTM): **state as a Lean conjecture** (Prop, no proof) — the econometric track tests it; Lean pins the exact statement.
- **Replication decomposition**: **structural definition** — the affine-in-options form is the *definition* of the replication price with α₁, α₂ free parameters; prove consistency/dimension lemmas only. Deriving α's from the Demeterfi log-contract argument is deferred.

### Calculus foundation
- **Lattice-first**: θ, υ, and premiums are difference quotients / finite sums on the tick×time lattice per the cfmm-discrete notes (the spec's NOTE: "calculus is this one"). Continuous forms appear only as closed-form targets.
- **θ closed form is DERIVED from the lattice**: formalize the backward-induction derivation (cfmm-discrete FINANCE §6.7/§6.18 → STREAMING_PREMIUM) so θ_ATM(τ) = kσ/√(8πτ) is a **theorem**, not a definition. This is the phase's heaviest proof obligation — budget it as the main Aristotle stage.
- **υ definition**: finite difference in σ² — υ(σ², Δσ²) = (π(σ²+Δσ²) − π(σ²))/Δσ², a lattice object dimensionally matching ΔQ_v (the spec's bridge claim), implementable as a Lens read.
- **Premium integral**: `Finset.sum` over lattice steps — premium = Σ_j θ(i,j)·Δt, matching the streaming-premium accumulator Panoptic implements; the ∫θ dt form is noted as the continuum limit only.

### Aristotle proof workflow
- **New Aristotle project for this phase** (e.g. `panoptic-upsilon`) — do NOT `continue` the legacy IDLE projects (uploads replace server files).
- **Labor split**: definitions, dimension/algebra lemmas, and conjecture statements proved/checked locally (`lake build` must pass); the lattice→closed-form θ derivation and hard inequalities go to Aristotle as sorry'd theorems.
- **Staged, strictly serial submissions**: Stage 1 = payoff π^σ + υ definition + premium sums (foundations); Stage 2 = lattice→θ closed-form derivation; Stage 3 (optional) = conjecture upgrades. Each stage submitted only after the prior task's proof has landed locally — NEVER queue/parallel `aristotle continue` (the `--files` upload overwrites the in-flight task's server-side proof).
- **API key**: stored in this worktree's `.env` (gitignored, never committed); aristotle commands read it at call time via `--api-key`.

### Spec hygiene & references
- **Fix the θ sign typo in `spec/protocol/panoptic.md`** against the cfmm-discrete derivation (Gaussian kernel needs exp(−[·]²/2σ²t)) so markdown and Lean agree.
- **Demeterfi et al.**: replace the dangling `../refs/DemeterfietalVarianceSwaps.pdf` link with **URL + citekey** (Demeterfi, Derman, Kamal, Zou 1999, "More Than You Ever Wanted To Know About Volatility Swaps", Goldman Sachs QS Research Notes). Do NOT vendor the PDF (public repo; redistribution rights unclear).
- **cfmm-discrete notes**: **both** — vendor the load-bearing notes (user's own writing: at minimum FINANCE.md, STREAMING_PREMIUM.md, DIFFERENTIATION.md; planner judges the rest) into `spec/protocol/refs/cfmm-discrete/`, AND keep the citekey pointing at the cfmm-theory knowledge base as canonical. No `~/`/`$HOME` paths may remain in tracked files (Phase-1 rule).
- **Commit timing**: clean + commit `spec/protocol/panoptic.md` at **phase start** — first plan task fixes sign + refs, vendors notes, commits; the formalization proceeds from a pinned, tracked spec.

### Claude's Discretion
- Exact module/file split inside `vol_markets` and lemma naming.
- Which cfmm-discrete notes beyond the three named are load-bearing enough to vendor.
- Stage boundaries within the staged-serial Aristotle plan if the dependency graph demands a different cut.
- Whether the υ finite-difference → derivative convergence lemma is attempted this phase or deferred (leaning deferred).

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase target
- `spec/protocol/panoptic.md` — the spec being formalized (currently untracked; committed after hygiene fixes as the first task). Defines π^σ, the replication decomposition, the θ kernel, and υ.

### Discrete financial calculus (proof source material)
- Local cfmm-theory knowledge base, `cfmm-discrete/` notes — **to be vendored into `spec/protocol/refs/cfmm-discrete/` at phase start**; until then they live in the user's local KB outside the repo:
  - `FINANCE.md` §6.7 (dt-leg of dπ), §6.18 (backward induction) — the lattice Black–Scholes machinery the θ derivation must follow
  - `STREAMING_PREMIUM.md` — lattice theta Θ(i,j), ATM column selection (center column at i_K, NOT the i=j diagonal), θ_ATM(τ) = kσ/√(8πτ), ∫θ dτ = kσ√(T/2π); equates streaming premium with LP fee revenue
  - `DIFFERENTIATION.md`, `INTEGRATION.md`, `BINARY_TREES.md`, `COORDINATES.md` — supporting lattice calculus
- Reference these ONLY via the vendored `spec/protocol/refs/cfmm-discrete/` paths or citekey in tracked files — never via home-absolute paths.

### Existing Lean modules (build on, don't duplicate)
- `lean/vol_markets/PosSpec.lean` — tick/price grid `tickPrice Δi i = λ^((i/2)·Δi)` with λ = 1.0001; skew tick; the strike tick i_K machinery should reuse this grid
- `lean/vol_markets/Flow.lean` — `deltaShares dQM prisk = dQM / prisk` (ΔQ_v), premiums/payoff π, bang-bang schedule; υ's dimensional bridge to ΔQ_v anchors here
- `lean/vol_markets/RiskDesign.lean` — clamp01, distance/riskPrice/haircut separation, X96 rounding model (pattern for EVM-facing lemma style)
- `lean/lakefile.toml` — lib wiring; new roots must be added under `[[lean_lib]] name = "vol_markets"`
- `lean/exp/eta_pi_variance_swap_signature.md` — prior variance-swap notes in the exp track (context, not a dependency)

### External papers
- Panoptic: arXiv:2204.14232 (https://arxiv.org/pdf/2204.14232) — perpetual-option streaming premium; source of the θ kernel form
- Demeterfi, Derman, Kamal, Zou (1999), "More Than You Ever Wanted To Know About Volatility Swaps", Goldman Sachs Quantitative Strategies Research Notes — replication-cost pricing of vol claims (cite by URL/citekey; no vendored PDF)

### Project conventions
- `docs/plans/2026-07-16-lean-conglomeration.md` — how the Lake project was assembled; Mathlib pinned at v4.28.0; LeanEVM deliberately removed until on-chain proofs begin (do not re-add this phase)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `PosSpec.tickPrice` / `PosSpec.lam`: the λ = 1.0001 tick grid — the strike tick i_K = log_λ K and price coordinates for the lattice reuse this
- `Flow.deltaShares`: ΔQ_v = ΔQ_M / p_risk — the object υ is dimensionally matched against
- `RiskDesign` module style: real-valued spec + explicit EVM-image (Q64.96/RAY) rounding lemmas — the pattern υ-as-Lens-read lemmas should follow
- Build conventions: `set_option relaxedAutoImplicit false` / `autoImplicit false`, `maxHeartbeats 4000000`, `import Mathlib` wholesale

### Established Patterns
- Real-valued definitions first, EVM fixed-point images as separate lemmas (never mixed)
- Module docstrings state the EVM types (i24 ticks, u88 vols, Q64.96 prices) the reals model
- Lake libs use `srcDir = "."` with explicit `roots` lists — adding files requires a lakefile edit

### Integration Points
- `lean/lakefile.toml` `vol_markets` roots list — new modules wire in here
- `vol_markets.Main` / `Flow` import chain — new modules import `PosSpec`/`Flow`, are imported by nothing yet
- Aristotle CLI (`~/.local/bin/aristotle`, aristotlelib 2.1.0) — submit/continue/download; key in worktree `.env`

</code_context>

<specifics>
## Specific Ideas

- The spec's own NOTE declares the cfmm-discrete notes the authoritative calculus ("CALCULUS IS THIS ONE") — the lattice-first decision implements that directive.
- υ matters because it "dimensionally lives in the place of ΔQ_v" — the formalization should surface this as an explicit type/dimension correspondence lemma, since it is the bridge on which "build on top of panoptic from our protocol or vice versa" rests.
- θ_ATM must be read at the strike-tick **center column** of the tree, not the i=j diagonal (STREAMING_PREMIUM.md is explicit; a natural formalization mistake to guard against).
- The plank worktree carries its own copy at `spec/protocol/protocol_integrations/panoptic.md` (opened in the user's IDE) — this phase's canonical target is THIS worktree's `spec/protocol/panoptic.md`; divergence between the two copies is a coordination note for the plank session (`ul2inqpl`), not this phase's problem.

</specifics>

<deferred>
## Deferred Ideas

- Derive α₁, α₂ from the Demeterfi log-contract static-replication argument (integral over strikes) — later refinement of the structural definition
- υ finite-difference → continuous-derivative convergence lemma (Δσ²→0) — likely next phase
- Econometric estimation execution (Panoptic subgraph data pull + regression run) — the structural-econometrics skill produces the model spec this phase; estimation is separate work
- Contract-level υ tracking on a Lens.sol / plank state-viewer — belongs to the plank (`ul2inqpl`) / Solidity-testing tracks
- LeanEVM re-introduction for on-chain proofs — explicitly out until the on-chain proof phase (toolchain bump required)

</deferred>

---

*Phase: 08-panoptic-vol-claim-lean4-formalization*
*Context gathered: 2026-07-18*
