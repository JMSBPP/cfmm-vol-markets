# Phase 8: panoptic vol-claim lean4 formalization - Research

**Researched:** 2026-07-19
**Domain:** Lean4 / Mathlib formalization of a discrete lattice (CRR) option-pricing calculus — payoff identity, streaming-premium θ kernel, and the vega-like greek υ
**Confidence:** HIGH on toolchain/stack/existing-code/Aristotle; MEDIUM-HIGH on the mathematical decomposition; the load-bearing risk (central-binomial asymptotic) is HIGH-confidence identified.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Scope & home**
- **Extend `vol_markets`** — new modules live inside the existing `vol_markets` lib (e.g. `vol_markets/Panoptic.lean`, `vol_markets/Upsilon.lean`; exact file split is planner's call), added to the lib's `roots` in `lean/lakefile.toml`. No new lean_lib.
- **Lean scope = analytical blocks only**: payoff identity, replication decomposition, θ kernel, υ definition + properties. The **econometric blocks** (Q_M = Q_M(υ=0) + υσ² regression, υ(t) linearization, Panoptic-subgraph access) are **not Lean objects** — handled via the **`structural-econometrics` skill**, producing a derived econometric model-spec artifact (markdown) alongside the Lean work.
- **ATM/OTM null hypothesis** (Δυ/Δi maximal at the money, exponentially decaying OTM): **state as a Lean conjecture** (Prop, no proof) — the econometric track tests it; Lean pins the exact statement.
- **Replication decomposition**: **structural definition** — the affine-in-options form is the *definition* of the replication price with α₁, α₂ free parameters; prove consistency/dimension lemmas only. Deriving α's from the Demeterfi log-contract argument is deferred.

**Calculus foundation**
- **Lattice-first**: θ, υ, and premiums are difference quotients / finite sums on the tick×time lattice per the cfmm-discrete notes. Continuous forms appear only as closed-form targets.
- **θ closed form is DERIVED from the lattice**: formalize the backward-induction derivation (cfmm-discrete FINANCE §6.7/§6.18 → STREAMING_PREMIUM) so θ_ATM(τ) = kσ/√(8πτ) is a **theorem**, not a definition. Phase's heaviest proof obligation — the main Aristotle stage.
- **υ definition**: finite difference in σ² — υ(σ², Δσ²) = (π(σ²+Δσ²) − π(σ²))/Δσ², a lattice object dimensionally matching ΔQ_v, implementable as a Lens read.
- **Premium integral**: `Finset.sum` over lattice steps — premium = Σ_j θ(i,j)·Δt; the ∫θ dt form is noted as the continuum limit only.

**Aristotle proof workflow**
- **New Aristotle project for this phase** (e.g. `panoptic-upsilon`) — do NOT `continue` the legacy IDLE projects (uploads replace server files).
- **Labor split**: definitions, dimension/algebra lemmas, and conjecture statements proved/checked locally (`lake build` must pass); the lattice→closed-form θ derivation and hard inequalities go to Aristotle as sorry'd theorems.
- **Staged, strictly serial submissions**: Stage 1 = payoff π^σ + υ definition + premium sums; Stage 2 = lattice→θ closed-form derivation; Stage 3 (optional) = conjecture upgrades. Each stage submitted only after the prior task's proof has landed locally — NEVER queue/parallel `aristotle continue` (the `--files` upload overwrites the in-flight task's server-side proof).
- **API key**: stored in this worktree's `.env` (gitignored, never committed); aristotle commands read it at call time via `--api-key` or the `ARISTOTLE_API_KEY` env var.

**Spec hygiene & references**
- **Fix the θ sign typo in `spec/protocol/panoptic.md`** against the cfmm-discrete derivation (Gaussian kernel needs exp(−[·]²/2σ²t)) so markdown and Lean agree.
- **Demeterfi et al.**: replace the dangling `../refs/DemeterfietalVarianceSwaps.pdf` link with **URL + citekey** (Demeterfi, Derman, Kamal, Zou 1999, "More Than You Ever Wanted To Know About Volatility Swaps", Goldman Sachs QS Research Notes). Do NOT vendor the PDF.
- **cfmm-discrete notes**: **both** — vendor the load-bearing notes (user's own writing: at minimum FINANCE.md, STREAMING_PREMIUM.md, DIFFERENTIATION.md; planner judges the rest) into `spec/protocol/refs/cfmm-discrete/`, AND keep the citekey pointing at the cfmm-theory knowledge base as canonical. No `~/`/`$HOME` paths may remain in tracked files (Phase-1 rule).
- **Commit timing**: clean + commit `spec/protocol/panoptic.md` at **phase start** — first plan task fixes sign + refs, vendors notes, commits; formalization proceeds from a pinned, tracked spec.

### Claude's Discretion
- Exact module/file split inside `vol_markets` and lemma naming.
- Which cfmm-discrete notes beyond the three named are load-bearing enough to vendor.
- Stage boundaries within the staged-serial Aristotle plan if the dependency graph demands a different cut.
- Whether the υ finite-difference → derivative convergence lemma is attempted this phase or deferred (leaning deferred).

### Deferred Ideas (OUT OF SCOPE)
- Derive α₁, α₂ from the Demeterfi log-contract static-replication argument (integral over strikes).
- υ finite-difference → continuous-derivative convergence lemma (Δσ²→0) — likely next phase.
- Econometric estimation execution (Panoptic subgraph data pull + regression run) — structural-econometrics skill produces the model spec this phase; estimation is separate work.
- Contract-level υ tracking on a Lens.sol / plank state-viewer — belongs to plank (`ul2inqpl`) / Solidity-testing tracks.
- LeanEVM re-introduction for on-chain proofs — out until the on-chain proof phase (toolchain bump required).
</user_constraints>

## Summary

This phase formalizes `spec/protocol/panoptic.md` as Lean4 modules inside the existing `vol_markets` Lake library. The mathematical substance is a **discrete Cox–Ross–Rubinstein (CRR) lattice option calculus** already fully worked out in the user's own `cfmm-discrete/` notes (Forgy's discrete stochastic calculus): the tick axis `i = log_λ P_X` is the diffusion axis, `Δt = (Δi)²` collapses drift+diffusion to the discrete Black–Scholes/heat operator, and options are priced by backward induction with a **constant** risk-neutral probability `q = (λe^{rΔt}−1)/(λ²−1)`. Everything the Lean proofs must mirror is stated in those notes (load-bearing: FINANCE.md §6.7/§6.18, STREAMING_PREMIUM.md, DIFFERENTIATION.md; supporting: BINARY_TREES.md, COORDINATES.md, INTEGRATION.md).

The existing `vol_markets` code (`PosSpec.lean`, `Flow.lean`, `RiskDesign.lean`) and the `exp/eta.lean` reference establish strong, reusable conventions: `import Mathlib` wholesale, `set_option maxHeartbeats 4000000 / relaxedAutoImplicit false / autoImplicit false`, real-valued definitions first with EVM fixed-point images as separate lemmas, `noncomputable def` for `rpow`/`Real` objects, `Finset.sum`/`Finset.range` accumulators, and the tick→price grid `tickPrice Δi i = λ^{(i/2)·Δi}` with `λ = 1.0001`. The new modules reuse this grid for the strike tick `i_K` and mirror `Flow.deltaShares` (ΔQ_v = ΔQ_M / p_risk) for the υ dimensional-bridge lemma.

The **heaviest and highest-risk obligation** is deriving `θ_ATM(τ) = kσ/√(8πτ)` from lattice backward induction. Mathlib v4.28.0 **has Stirling's formula** (`Stirling.factorial_isEquivalent_stirling`, `tendsto_stirlingSeq_sqrt_pi`, `le_factorial_stirling`) and the **Wallis product**, but does **NOT** package the sharp central-binomial-coefficient asymptotic `C(2m,m)/4^m ~ 1/√(πm)` (only crude bounds like `four_pow_le_two_mul_self_mul_centralBinom`), and has **no de Moivre–Laplace / discrete local-CLT** lemma. The √(8π) constant is exactly `2√(2π)` from the standard-normal peak `φ(0)=1/√(2π)`; the discrete route to it runs through the central-binomial peak probability, which must be **built from Stirling** — this is the chunk to hand Aristotle. `lake build vol_markets` currently passes clean (8030 jobs, exit 0), so the starting state is green.

**Primary recommendation:** Split into `vol_markets/Panoptic.lean` (payoff π^σ + ΔQ_v identity + structural replication decomposition + premium `Finset.sum` + lattice CRR operator + θ definition) and `vol_markets/Upsilon.lean` (υ finite-difference + ΔQ_v dimensional bridge + ATM/OTM `Prop` conjecture). Prove all definitions/algebra/dimension lemmas locally; hand the single hard theorem `θ_ATM(τ) = kσ/√(8πτ)` — decomposed into a central-binomial-from-Stirling lemma + assembly — to a **new** Aristotle project as a `sorry`'d goal, submitted strictly serially.

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Lean 4 | `leanprover/lean4:v4.28.0` (pinned in `lean/lean-toolchain`) | proof language | project-wide pin; matches Aristotle |
| Mathlib | `v4.28.0` (pinned in `lean/lakefile.toml` + `lake-manifest.json`) | real analysis, `Finset.sum`, `rpow`, Stirling, Wallis, central binomial | the only math dependency; imported wholesale |
| Lake | bundled with the toolchain (`~/.elan/bin/lake`) | build/dep manager | project uses `lakefile.toml` (TOML, not Lean) |
| aristotlelib | `2.1.0` (`~/.local/bin/aristotle`) | automated theorem proving for the hard θ derivation | the established heavy-proof workflow for this repo |

### Supporting (Mathlib modules the proofs will touch)
| Module | Purpose | When to Use |
|--------|---------|-------------|
| `Mathlib.Analysis.SpecialFunctions.Pow.Real` (`Real.rpow`) | tick→price `λ^x`, exponent algebra (`rpow_add`, `rpow_natCast`) | payoff/price coordinates (already used in `PosSpec`, `eta`) |
| `Mathlib.Algebra.BigOperators` (`Finset.sum`, `Finset.range`, `Finset.sum_range_succ`) | premium accumulator Σ θ·Δt; backward-induction unrolling | premium sums, telescoping |
| `Mathlib.Analysis.SpecialFunctions.Stirling` | `factorial_isEquivalent_stirling`, `tendsto_stirlingSeq_sqrt_pi`, `le_factorial_stirling`, `le_log_factorial_stirling` | the √(8π)/√(2π) constant route |
| `Mathlib.Data.Real.Pi.Wallis` (`Wallis.tendsto_W_nhds_pi_div_two`) | underlies Stirling; the π/2 limit | if the central-binomial asymptotic is built from scratch |
| `Mathlib.Data.Nat.Choose.Central` (`Nat.centralBinom`, `four_pow_le_two_mul_self_mul_centralBinom`, `four_pow_lt_mul_centralBinom`) | symmetric-walk peak node `C(2m,m)/4^m` | ATM node probability |
| `Mathlib.Analysis.SpecialFunctions.Gaussian.GaussianIntegral` | `∫ exp(−x²)` normalization; `1/√(2π)` peak | continuum-limit target / cross-check |
| `Mathlib.Probability.ProbabilityMassFunction.Binomial` | binomial PMF (if a probabilistic framing of the walk is chosen) | optional; the combinatorial `centralBinom` route is lighter |
| `Mathlib.Topology.Order` / `Filter.Tendsto` + `Asymptotics.IsEquivalent` | asymptotic statement of `θ_ATM ~ kσ/√(8πτ)` as `τ→0` | matches `eta.lean`'s `Tendsto`-style asymptotics |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Combinatorial central-binomial route (`Nat.centralBinom` + Stirling) | `Mathlib.Probability` binomial PMF + a CLT-flavoured argument | Mathlib has no discrete local-CLT; the combinatorial route reuses existing Stirling machinery and is far more tractable for Aristotle |
| Deriving `√(8π)` from the discrete peak | Asserting the continuum BS-theta and taking `Δt→0` | violates the locked "lattice-first, θ is DERIVED" decision; keep continuum as a *target*, not the definition |

**Installation:** none — toolchain, Mathlib, and Aristotle are already present. Adding modules is a `lean/lakefile.toml` `roots` edit only.

**Version verification (verified live 2026-07-19):**
- `lean/lean-toolchain` → `leanprover/lean4:v4.28.0`
- `lean/lakefile.toml` require `mathlib` `rev = "v4.28.0"`; `lake-manifest.json` `inputRev: "v4.28.0"`
- `aristotle --version` → `aristotlelib 2.1.0`
- `~/.elan/bin/{lake,lean,elan}` present; `.lake/` prebuilt (7.1 GB — Mathlib already compiled)

## Architecture Patterns

### Recommended Project Structure
```
lean/
├── lakefile.toml                    # add new roots under [[lean_lib]] name = "vol_markets"
├── vol_markets/
│   ├── Main.lean                    # existing (EVMDesignSpace: discounted sums, admissible region)
│   ├── PosSpec.lean                 # existing: tickPrice, skewTick, lam=1.0001  ← REUSE for i_K grid
│   ├── Flow.lean                    # existing: deltaShares (ΔQ_v), payoff π, liquidity  ← REUSE for υ bridge
│   ├── RiskDesign.lean              # existing: clamp01, X96 rounding model (EVM-image pattern)
│   ├── Panoptic.lean                # NEW: π^σ payoff + ΔQ_v identity + replication decomp + premium sums + CRR + θ
│   └── Upsilon.lean                 # NEW: υ finite-difference + ΔQ_v dimensional bridge + ATM/OTM conjecture
spec/
├── panoptic.md                      # fix sign/refs, commit at phase start
└── refs/
    └── cfmm-discrete/               # NEW: vendor FINANCE.md, STREAMING_PREMIUM.md, DIFFERENTIATION.md (+ planner's call)
```
(`spec/protocol/refs/` does not yet exist; `spec/protocol/panoptic.md` is currently untracked — confirmed via `git status`.)

### Pattern 1: Real-first, EVM-image-second (house style)
**What:** Every economic object is a `ℝ`-valued `def`; fixed-point (Q64.96/X96/RAY) behaviour is a *separate* lemma section, never mixed into the real definition.
**When to use:** all new definitions.
**Example (from `RiskDesign.lean`):**
```lean
-- real spec
def haircutFactor (h : ℝ) : ℝ := clamp01 (1 - h)
-- EVM image, isolated section
def X96 : ℕ := 2 ^ 96
def mulX96Down (amount weightX96 : ℕ) : ℕ := amount * weightX96 / X96
lemma mulX96Down_le (amount weightX96 : ℕ) (hw : weightX96 ≤ X96) :
    mulX96Down amount weightX96 ≤ amount := ...
```

### Pattern 2: File header / options block (copy verbatim)
**What:** Every `vol_markets` file opens identically.
```lean
import Mathlib
import vol_markets.PosSpec   -- and/or vol_markets.Flow as needed
open scoped BigOperators
open Real
set_option maxHeartbeats 4000000
set_option relaxedAutoImplicit false
set_option autoImplicit false
```
`vol_markets/Main.lean` additionally raises `maxHeartbeats 8000000`, `maxRecDepth 4000`, `synthInstance.*`, and `open scoped Nat Classical Pointwise` — use that heavier header for the θ-derivation file if `centralBinom`/`Stirling` elaboration is slow.

### Pattern 3: Lattice objects as `Finset.sum` over `Finset.range` (matches Panoptic's streaming accumulator)
**What:** Premiums and backward-induction unrollings are finite sums; use `Finset.sum_range_succ` for induction. `exp/eta.lean` already proves the arithmetic-progression-sum-of-squares closed form (`sum_sq_arith`) by `induction n <;> simp_all [Finset.sum_range_succ] ; ring` — the exact idiom for the premium telescoping.
**Example (premium):**
```lean
noncomputable def streamingPremium (θ : ℕ → ℝ) (Δt : ℝ) (N : ℕ) : ℝ :=
  ∑ j ∈ Finset.range N, θ j * Δt
```

### Pattern 4: υ as a finite difference + dimensional bridge to ΔQ_v
**What:** `υ(σ², Δσ²) = (π(σ²+Δσ²) − π(σ²)) / Δσ²`, mirroring `Flow.deltaShares dQM prisk = dQM / prisk`. The bridge lemma should surface that υ occupies the same slot as `ΔQ_v` (the "build on top of panoptic" claim) — an explicit equality/dimension-correspondence lemma anchored to `Flow.deltaShares`.

### Anti-Patterns to Avoid
- **Reading θ_ATM on the tree diagonal `Θ(i,i)`.** STREAMING_PREMIUM.md is explicit: ATM theta is the **center column** at the strike tick `i_K = log_λ K` read along the time axis `j` (balanced up/down node), NOT the all-up boundary node `i=j` (deep ITM/OTM). Encode `i_K` as a fixed price index and vary `j`; guard this with a lemma name/docstring.
- **Defining θ_ATM by its closed form.** The locked decision requires it be a *theorem* from backward induction. Define θ as the lattice `dt`-leg `Θ(i,j) = (π(i,j+1) − π(i,j))/Δt`; prove the closed form.
- **Mixing `Real` and EVM fixed-point in one def** (breaks Pattern 1).
- **`continue`-ing a legacy Aristotle project** (uploads overwrite server files; MEMORY "Aristotle: no queue").

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| `n! ≈ √(2πn)(n/e)ⁿ` | a custom Stirling bound | `Stirling.factorial_isEquivalent_stirling`, `le_factorial_stirling`, `le_log_factorial_stirling`, `tendsto_stirlingSeq_sqrt_pi` | Mathlib proves it (via Wallis); reproving is enormous |
| Wallis product / π-limit | hand-rolled `∏ (2k)²/((2k−1)(2k+1))` | `Mathlib.Data.Real.Pi.Wallis` (`Wallis.tendsto_W_nhds_pi_div_two`) | already there; Stirling depends on it |
| Central binomial basic facts | custom `(2n choose n)` bounds | `Nat.centralBinom`, `centralBinom_eq_two_mul_choose`, `four_pow_le_two_mul_self_mul_centralBinom` | crude bounds exist; only the *sharp asymptotic* is missing (see Pitfall 1) |
| Gaussian normalization `∫e^{−x²}=√π`, `φ(0)=1/√(2π)` | custom integral | `Mathlib.Analysis.SpecialFunctions.Gaussian.GaussianIntegral` | continuum-limit cross-check |
| Exponent algebra `λ^{a+b}=λ^a λ^b` | manual | `Real.rpow_add`, `Real.rpow_natCast`, `Real.rpow_lt_rpow_left_iff` | pattern already used across `PosSpec`/`eta` |
| Finite-sum induction | manual index juggling | `Finset.sum_range_succ` + `induction … <;> simp_all` | the `sum_sq_arith` idiom in `eta.lean` |

**Key insight:** Mathlib supplies *every* ingredient of `θ_ATM = kσ/√(8πτ)` **except** the one gluing step — the sharp central-binomial asymptotic — which must be assembled from Stirling. Do not re-derive Stirling or Wallis; do assemble the central-binomial-to-Gaussian-peak step (that is the Aristotle job).

## Common Pitfalls

### Pitfall 1: The √(8π) constant has no ready-made Mathlib lemma
**What goes wrong:** A plan assumes Mathlib has `C(2m,m) ~ 4^m/√(πm)` or a de Moivre–Laplace local CLT and budgets the θ derivation as a one-liner.
**Why it happens:** Mathlib *does* have Stirling and Wallis, so the constant "feels" available. But `grep` confirms: `Mathlib.Data.Nat.Choose.Central` has only crude bounds (`four_pow_lt_mul_centralBinom`, `four_pow_le_two_mul_self_mul_centralBinom`); there is **no** `Tendsto`/`IsEquivalent` sharp central-binomial asymptotic and **no** discrete-local-CLT / de Moivre–Laplace lemma anywhere in the tree.
**How to avoid:** Budget an explicit Aristotle sub-lemma: `centralBinom_isEquivalent : (fun m => (Nat.centralBinom m : ℝ)) ~[atTop] fun m => 4^m / Real.sqrt (π * m)`, derived from `factorial_isEquivalent_stirling`. The `√(8π)` then follows from `2·√(2π)` (the `φ(0)=1/√(2π)` peak, `√τ = √(m·Δt)`). Cross-check numerically: at ATM `p(t0)=K`, the spec's kernel prefactor is `Kσ/√(8πt)`, so as `t→0` `θ_ATM(τ)→kσ/√(8πτ)` with `k=K` (the `exp(−σ²t/8)` factor →1).
**Warning signs:** a plan task claiming θ_ATM "follows directly from `Stirling`" with no central-binomial intermediate.

### Pitfall 2: θ_ATM read at the wrong lattice location
**What goes wrong:** Formalizing ATM theta as the diagonal `Θ(i,i)` (the all-up boundary), producing a deep-OTM value instead of the ATM blow-up `1/√τ`.
**Why it happens:** The recombining tree's `(i,j)` indexing tempts `i=j`; STREAMING_PREMIUM.md explicitly warns against it.
**How to avoid:** Fix the *price* tick at `i_K = log_λ K` (reuse `PosSpec.tickPrice`/`lam`) and vary *time* `j`; `τ = (J−j)·Δt`. Name the lemma so the center-column choice is legible.
**Warning signs:** a definition of θ_ATM whose value doesn't diverge as `τ→0`.

### Pitfall 3: Sign typo propagating from spec to Lean
**What goes wrong:** The spec's θ kernel (line 36 of `spec/protocol/panoptic.md`) has a **positive** exponent `exp( [−ln(p/K)+σ²t/2]² / (2σ²t) )` — a Gaussian requires a **negative** exponent. If transcribed as-is, the Lean kernel blows up instead of decaying and no closed form matches.
**Why it happens:** Missing leading minus inside `exp`.
**How to avoid:** The first hygiene task must correct it to `exp( −[−ln(p(t0)/K)+σ²t/2]² / (2σ²(·)t) )` (CONTEXT: "Gaussian kernel needs exp(−[·]²/2σ²t)"). Verified against STREAMING_PREMIUM.md's `θ_ATM(τ)=kσ/√(8πτ)` and `∫₀ᵀθ dτ = kσ√(T/2π)`: only the negative-exponent form yields these. Formalize from the *corrected* spec.
**Warning signs:** Lean and markdown disagree; the ATM specialization doesn't reduce to the closed form.

### Pitfall 4: Aristotle submission bundle missing toolchain/manifest
**What goes wrong:** Submitting only `.lean` files; Aristotle can't reproduce the Mathlib environment or picks a different toolchain.
**Why it happens:** Assuming `--files`/`--project-dir` need only sources.
**How to avoid:** A submission bundle mirrors the reference archive layout: `lakefile.toml` (require mathlib `rev = v4.28.0`, one `[[lean_lib]]` with `globs`), `lean-toolchain` (`leanprover/lean4:v4.28.0`), `lake-manifest.json`, and a source subdir (the reference used `RequestProject/` with `globs = ["RequestProject.+"]`). Pass the whole directory via `--project-dir`. The pin **must** be `v4.28.0` on both toolchain and Mathlib to match the local build and the legacy bundles.
**Warning signs:** Aristotle errors on unknown Mathlib lemmas or a toolchain mismatch.

### Pitfall 5: Parallel/queued Aristotle `continue` overwriting proofs
**What goes wrong:** Two `continue --files` calls in flight; the second upload replaces the first task's server-side proof.
**Why it happens:** Treating stages as parallelizable.
**How to avoid:** Strictly serial — submit Stage N+1 only after Stage N's proof has landed locally (download and `lake build` green). This is a locked decision and a standing MEMORY note.

## Code Examples

### Tick→price grid + strike tick (reuse existing `PosSpec`)
```lean
-- Source: lean/vol_markets/PosSpec.lean (verified in-repo)
noncomputable def lam : ℝ := 1.0001
noncomputable def tickPrice (Δi i : ℝ) : ℝ := lam ^ ((i / 2) * Δi)
-- strike tick i_K = log_λ K : reuse tickPrice; i_K is the center column for θ_ATM
```

### ΔQ_v identity to mirror for υ (reuse existing `Flow`)
```lean
-- Source: lean/vol_markets/Flow.lean (verified in-repo)
noncomputable def deltaShares (dQM prisk : ℝ) : ℝ := dQM / prisk   -- ΔQ_v = ΔQ_M / p_risk
-- υ mirrors this shape as a finite difference in σ²; bridge lemma ties υ to this slot
```

### CRR backward-induction operator (from cfmm-discrete FINANCE §6.15/6.18)
```lean
-- Source: /home/jmsbpp/learning/cfmm-theory/cfmm-discrete/FINANCE.md (to be vendored)
-- π(i,j) = e^{−rΔt}·[ q·π(i+1,j+1) + (1−q)·π(i−1,j+1) ],  q = (λ e^{rΔt} − 1)/(λ² − 1)  (constant)
noncomputable def q (lam r Δt : ℝ) : ℝ := (lam * Real.exp (r * Δt) - 1) / (lam^2 - 1)
noncomputable def crrStep (lam r Δt : ℝ) (up dn : ℝ) : ℝ :=
  Real.exp (-r * Δt) * (q lam r Δt * up + (1 - q lam r Δt) * dn)
```

### Lattice theta (dt-leg) and the target closed form
```lean
-- Source: cfmm-discrete/STREAMING_PREMIUM.md (to be vendored)
-- Θ(i,j) := (π(i,j+1) − π(i,j)) / Δt          (dt-leg of dπ; signed Θ < 0 for a long claim)
-- TARGET THEOREM (Aristotle): with τ = (J−j)·Δt, k = K, σ = ln λ / √Δt,
--   Θ_ATM(τ) = k·σ / Real.sqrt (8 * π * τ)
-- and    ∑_{steps} Θ_ATM · Δt  →  k·σ·Real.sqrt (T / (2*π))
```

### Asymptotic-statement idiom (matches `eta.lean`)
```lean
-- Source: lean/exp/eta.lean (Tendsto/nhdsWithin idiom, verified in-repo)
Filter.Tendsto (fun τ => Θ_ATM τ * Real.sqrt (8 * π * τ)) (nhdsWithin 0 (Set.Ioi 0))
  (nhds (k * σ))
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `import Mathlib` + LeanEVM for EVM types | LeanEVM removed 2026-07-16 (needs toolchain v4.30.0); EVM images modelled directly (`ℕ`, `2^96`) | conglomeration (docs/plans/2026-07-16) | do NOT re-add LeanEVM this phase; model `i24`/`u88`/Q64.96 as `ℝ`/`ℕ` with rounding lemmas |
| lakefile.lean | `lakefile.toml` (TOML) with explicit `roots` | current | adding a module = editing the `roots` list, not a glob |
| Continuous BS PDE as primitive | discrete CRR lattice as exact; continuum is the `Δt→0` derived limit | cfmm-discrete notes | θ/υ/premiums are lattice objects; continuum forms are targets only |

**Deprecated/outdated:**
- LeanEVM (`Philogy/LeanEVM`) — removed; restore only when on-chain proofs begin (toolchain bump).
- The dangling `../refs/DemeterfietalVarianceSwaps.pdf` link — replace with citekey/URL, no vendored PDF.

## Open Questions

1. **Does the central-binomial→Gaussian-peak lemma fit one Aristotle task?**
   - What we know: Stirling + Wallis are in Mathlib; the assembly is standard but multi-step (Stirling ratio → `centralBinom_isEquivalent` → peak `1/√(πm)` → `√(8π)` via `2√(2π)` and `√τ=√(mΔt)`).
   - What's unclear: whether Aristotle closes it in one shot or needs it pre-split into (a) `centralBinom_isEquivalent` and (b) the θ assembly.
   - Recommendation: plan Stage 2 as **two** sorry'd lemmas (asymptotic + assembly) so a partial Aristotle result is still mergeable; keep them in one file.

2. **`r → 0` / driftless simplification for the ATM closed form?**
   - What we know: STREAMING_PREMIUM's `kσ/√(8πτ)` is the driftless (Bachelier/Kristensen) ATM theta; the spec's kernel carries a `σ²t/2` drift term that vanishes at leading order as `τ→0`.
   - What's unclear: whether the phase formalizes the general-`r` kernel or the `r=0` ATM specialization.
   - Recommendation: formalize the ATM specialization (`p(t0)=K`, leading `τ→0` term) — that is exactly the locked target `kσ/√(8πτ)`; keep general-`r` as a definition without the closed-form theorem.

3. **Which cfmm-discrete notes beyond the three named to vendor?**
   - What we know: FINANCE.md (CRR operator, q, σ-bridge), STREAMING_PREMIUM.md (θ_ATM, center column, integral), DIFFERENTIATION.md (discrete Itô, ∂_t/∂_i²) are directly load-bearing. BINARY_TREES.md (the `Δt=(Δi)²` heat-operator collapse and the geometric-grid⟹CRR argument) is **also effectively load-bearing** for the θ derivation.
   - Recommendation: vendor FINANCE.md, STREAMING_PREMIUM.md, DIFFERENTIATION.md, **and** BINARY_TREES.md; COORDINATES.md and INTEGRATION.md are supporting context (vendor optional). Note these notes contain relative links to sibling notes (`../cfmm-options/notes/NOTATION.md`, `../lp-derivatives/notes/CFMM_DISCRETE.md`) that will dangle once vendored — the hygiene task should neutralize or annotate those.

## Validation Architecture

For a Lean formalization the "test" is compilation: a theorem is validated iff its file builds with **no `sorry`** (and no `axiom` leak). `lake build` is the test runner; `#print axioms <thm>` is the "no cheating" assertion.

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Lean 4 elaborator + Lake (`~/.elan/bin/lake`) |
| Config file | `lean/lakefile.toml` (+ `lean/lean-toolchain`, `lean/lake-manifest.json`) |
| Quick run command | `cd lean && lake build vol_markets` |
| Full suite command | `cd lean && lake build` (defaultTargets = exp, vol_markets, tao) |
| Baseline (2026-07-19) | `lake build vol_markets` → **GREEN**, 8030 jobs, exit 0 |

### Phase Requirements → Test Map
(No formal REQ-IDs assigned; decisions from 08-CONTEXT.md are the requirements.)

| Decision | Behavior | Test Type | Automated Command | File Exists? |
|----------|----------|-----------|-------------------|-------------|
| Spec hygiene | θ sign fixed, refs de-pathed, notes vendored, spec committed | build+grep | `git ls-files spec/protocol/panoptic.md && ! grep -rn '\$HOME\|/home/jmsbpp' spec/` | ❌ Wave 0 (spec untracked, `spec/protocol/refs/` absent) |
| π^σ payoff + ΔQ_v identity | payoff def + identity lemmas compile | unit | `cd lean && lake build vol_markets` (Panoptic.lean) | ❌ Wave 0 (module new) |
| Replication decomposition (structural) | affine-in-options def + consistency/dimension lemmas | unit | `cd lean && lake build vol_markets` | ❌ Wave 0 |
| Premium `Finset.sum` | Σ θ·Δt def + telescoping lemma | unit | `cd lean && lake build vol_markets` | ❌ Wave 0 |
| υ finite-difference + ΔQ_v bridge | υ def + `deltaShares`-slot bridge lemma | unit | `cd lean && lake build vol_markets` (Upsilon.lean) | ❌ Wave 0 |
| ATM/OTM null hypothesis | `Prop` conjecture pinned (no proof) | typecheck | `cd lean && lake build vol_markets` | ❌ Wave 0 |
| θ_ATM = kσ/√(8πτ) | lattice→closed-form theorem, no `sorry` | proof (Aristotle) | `cd lean && lake build vol_markets && lake env lean --run scripts/checkAxioms` *(or `#print axioms`)* | ❌ Wave 0 (hard; Aristotle) |

### Sampling Rate
- **Per task commit:** `cd lean && lake build vol_markets` (incremental; Mathlib cached).
- **Per wave merge:** `cd lean && lake build` (full defaultTargets).
- **Phase gate:** full `lake build` green **and** the θ theorem carries no `sorry`/no unexpected `axiom` (`#print axioms panoptic_theta_atm` shows only `propext`/`Classical.choice`/`Quot.sound`) before `/gsd:verify-work`.

### Wave 0 Gaps
- [ ] `spec/protocol/panoptic.md` — correct θ sign, replace Demeterfi PDF link with citekey/URL, remove `~/` NOTE path, then `git add`/commit (currently untracked).
- [ ] `spec/protocol/refs/cfmm-discrete/` — create; vendor FINANCE.md, STREAMING_PREMIUM.md, DIFFERENTIATION.md, BINARY_TREES.md; neutralize dangling sibling links.
- [ ] `lean/vol_markets/Panoptic.lean` — new module (payoff, replication, premium, CRR, θ).
- [ ] `lean/vol_markets/Upsilon.lean` — new module (υ, bridge, conjecture).
- [ ] `lean/lakefile.toml` — add both new files to the `vol_markets` `roots`.
- [ ] Aristotle bundle scaffold — `lakefile.toml`/`lean-toolchain`/`lake-manifest.json` + source subdir mirroring the reference archive layout, for Stage-2 submission.
- [ ] (optional) `#print axioms` check step to assert the θ proof is `sorry`-free after Aristotle returns.

Framework install: none needed (toolchain, Mathlib `.lake` prebuilt, Aristotle 2.1.0 all present).

## Sources

### Primary (HIGH confidence)
- In-repo Lean modules (read directly): `lean/vol_markets/{PosSpec,Flow,RiskDesign,Main}.lean`, `lean/exp/eta.lean` — conventions, reusable defs, asymptotic idioms.
- In-repo config: `lean/lakefile.toml`, `lean/lean-toolchain`, `lean/lake-manifest.json` — pins (Lean/Mathlib v4.28.0).
- Mathlib source (in `.lake/packages/mathlib`): `Mathlib/Analysis/SpecialFunctions/Stirling.lean` (Stirling formula, global bounds), `Mathlib/Data/Nat/Choose/Central.lean` (central binomial bounds), `Mathlib/Data/Real/Pi/Wallis.lean`, `Mathlib/Analysis/SpecialFunctions/Gaussian/GaussianIntegral.lean` — verified presence/absence of lemmas by grep.
- cfmm-discrete notes (read in depth): `FINANCE.md` (§6.7 dt-leg, §6.15/6.18 CRR, σ-bridge), `STREAMING_PREMIUM.md` (θ_ATM center-column, `kσ/√(8πτ)`, integral), `DIFFERENTIATION.md` (discrete Itô), `BINARY_TREES.md` (`Δt=(Δi)²` heat operator, geometric-grid⟹CRR), `COORDINATES.md`, `INTEGRATION.md`.
- Aristotle CLI: `aristotle {--help, submit --help, continue --help, download --help}` (v2.1.0); reference bundle layout from `lean/archive/arsitotleTaoCFMM.tar.gz`.
- Live commands: `lake build vol_markets` (GREEN, 8030 jobs); `git status` (spec untracked); `.env` (ARISTOTLE_API_KEY present, gitignored).

### Secondary (MEDIUM confidence)
- `spec/protocol/panoptic.md` (the target; contains the sign typo to fix) — read directly.
- 08-CONTEXT.md, .planning/REQUIREMENTS.md, .planning/STATE.md, CLAUDE.md — scope/ownership.

### Tertiary (LOW confidence)
- External references cited but NOT fetched this pass (out of research scope — the *notes* are the operative source): Panoptic whitepaper arXiv:2204.14232 (θ streaming premium Eq. 1); Demeterfi–Derman–Kamal–Zou 1999 (variance-swap replication); "Kristensen §3.4.2" ATM premium `kσ√(T/2π)` as cited inside STREAMING_PREMIUM.md. Treat the closed forms as sourced from the user's own vendored notes, not re-verified against the papers.

## Metadata

**Confidence breakdown:**
- Standard stack / toolchain: HIGH — pins read directly, `lake build` green, Aristotle version confirmed.
- Existing-code reuse & conventions: HIGH — all four `vol_markets` files + `eta.lean` read in full.
- Mathlib coverage (Stirling yes, sharp central-binomial no, local-CLT no): HIGH — confirmed by grep across the pinned Mathlib tree.
- Mathematical decomposition (CRR→θ_ATM): MEDIUM-HIGH — the derivation chain is standard and matches the notes; the exact Aristotle-lemma cut is a judgement call (Open Q1).
- Pitfalls (sign typo, center column, bundle layout, serial Aristotle): HIGH — each verified against a primary source.

**Research date:** 2026-07-19
**Valid until:** ~2026-08-18 (30 days; stable — pinned toolchain/Mathlib, local notes). Re-verify if the toolchain/Mathlib pin bumps (would move Stirling/centralBinom lemma availability) or if a newer aristotlelib changes CLI flags.
