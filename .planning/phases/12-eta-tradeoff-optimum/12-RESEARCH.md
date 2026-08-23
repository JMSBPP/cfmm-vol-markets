# Phase 12: Optimal η for the FLAIR/MEV trade-off (interior curvature controller) — Research

**Researched:** 2026-07-31
**Domain:** AMM curvature economics (Capponi–Jia arXiv:2103.08842v4 §5.1) → Lean4/Mathlib
formalization → bridge to `VolInstrument.priceEta` → joint program with the Phase 11 `Θ_φ` layer
**Confidence:** HIGH on the anchor's algebra and on the Lean route; MEDIUM on the economic
transferability of Capponi's two-period equilibrium to the tick grid (explicitly carried as
hypotheses / labelled OPEN below)

---

<user_constraints>
## User Constraints (from 12-CONTEXT.md)

### Locked Decisions (verbatim from `## Workflow constraints (binding, unchanged)`)

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

### The mathematical target (verbatim, `## The mathematical target`)

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

### Claude's Discretion

- Which transcription route (the CONTEXT explicitly delegates this — see F3, the
  recommendation is Option C).
- The E-block layout and placement in the master document.
- The exact remapped glyphs for Capponi's colliding symbols (F2).
- Bundle count (one vs two) and plan count (F10).
- Which of Capponi's Proposition 6 (welfare) content is transcribed vs labelled OPEN.

### Deferred Ideas (OUT OF SCOPE)

- Capponi §5.2 / Proposition 7 (multi-token pooling does not reduce arbitrage) — not
  mentioned in CONTEXT, not on the trade-off path.
- The four sibling Capponi PDFs (JIT, LitToDark, DiscreteClearing, Timeboost) — named in
  CONTEXT as *beside* the anchor, not as anchors.
- Plank hook implementation (beforeSwap/afterSwap wiring for todo #227) — this phase
  produces the *economic controller answer*; plank maps it to implementation.
- Re-opening any Phase 11 result. The M6a degeneracy is the motivation, not a target.
</user_constraints>

---

<phase_requirements>
## Phase Requirements (PROPOSED — adopt verbatim into ROADMAP, as 11-RESEARCH's set was)

| ID | Description | Research Support |
|----|-------------|-----------------|
| **CTX-CURVDOC** | A new `## ETA` section of blocks E0–E8 in the plank-owned `VOLATILITY_INSTRUMENTS.md`, minimal prose / maximal math, carrying the notation map, the curvature family, the two-sided lemma, the interior optimum, the η bridge, the de-degeneration and the caveats. Passes an INVERTED notation gate and HEAVY USER APPROVAL; bytes sha-pinned. | F1 (exact closed forms), F2 (the collision set and the resolutions), F9 (block layout), PIT-E1/E2/E3 |
| **CTX-CAPTRANS** | Capponi–Jia **Lemma 3** transcribed and PROVEN in our objects: the arbitrage-loss ratio and the investors' surplus ratio, each in their exact two-branch closed form, each STRICTLY ANTITONE in the curvature index, with the branch points and the continuity at the branch point. | F1 §A, F4 (T1'–T8'), F6 (`StrictAntiOn.union` verified at Mathlib `Order/Monotone/Union.lean:65`) |
| **CTX-INTERIOR** | Capponi–Jia **Proposition 5** transcribed and PROVEN: the LP excess-return function is strictly increasing below and strictly decreasing above a single peak; the peak is at the CLOSED FORM `χ* = 1 − √((1+φ)/(1+ϱ_I))`, interior iff `φ < ϱ_I`; and the liquidity-freeze-minimization corollary. Proposition 6's deposit-efficiency half transcribed; its welfare half bounded or labelled OPEN. | F1 §B, F4 (T9'–T18'), F5 (the `α > β` hypothesis geometrized as `χ_S ≤ χ_I`), PIT-E7 (no FOC — the peak is a KINK) |
| **CTX-ETABRIDGE** | The bridge OURS, proven: the geometric-grid step ratio of `VolInstrument.priceEta` is tick-independent; the discrete curvature index `χ(η) = 1 − λ^(−Δi²η/2)` is a strictly monotone bijection `(0,∞) → (0,1)`; and **`η* = ln((1+ϱ_I)/(1+φ)) / (Δi²·ln λ)`** with `curvIndex(η*) = χ*`, plus the three comparative statics. | F3 (the DECISION), F4 (T19'–T28'), F7 (the existing `lean/exp/` η layer and how not to duplicate it), PIT-E8 (the bridge is a DEFINITION; the equilibrium transfer is OPEN) |
| **CTX-DEGEN** | The de-degeneration, PROVEN and stated against Phase 11 by name: over `Θ_φ` the FLAIR-max and the ARB-min coincide (`MevJointProgram.joint_corner_degeneracy`), whereas over `η` the arb-loss ratio and the surplus ratio are BOTH strictly antitone, so no `η` is simultaneously arb-minimal and surplus-maximal; the joint optimum is (`Θ_φ` CORNER, `η` INTERIOR); and `η*` is strictly antitone in the fee, so the Phase-11 fee corner COUPLES into the curvature choice. | F5, F8, F4 (T29'–T31'), PIT-E5 (no conflation with `mevMulti`) |
| **CTX-REVIEW** | Two-reviewer gate (Reality Checker + one specialist, run in parallel, blind) on (a) the doc block and (b) the Aristotle prompt, before either is spent; sha-pinning of the bundled doc against the approved bytes; queue proven empty before submit. | F10, PIT-E10/E11, the 11-01/11-02/11-04 precedent (every gate found ≥1 BLOCKER) |
| **CTX-TRACE** | `LEAN_TRACEABILITY.md` §0 notation rows for the new symbols and §7.2 claim rows with every backticked identifier grep-verified to exist; the master doc back-annotated with `> LEAN` lines; §6's gap (b) (the demand-elasticity layer) amended; the plank todo #227 answer written down; memory updated. | F7, F11, the 11-06 precedent |
</phase_requirements>

---

## Summary

The anchor is fully transcribable, and it is transcribable as **one-dimensional real algebra**,
not as a game-theoretic equilibrium. Capponi & Jia solve their two-period model in closed form and
the closed forms are elementary: the expected arbitrage-loss ratio, the investors' surplus ratio,
the LP one-period excess return and the deposit efficiency are each **two- or three-branch
piecewise-algebraic functions of the curvature index alone**, with all equilibrium content
(arrival probabilities, shock probabilities, the deposit game, the gas fee) entering only as
**multiplicative constants**. Every monotonicity the paper asserts is a monotonicity of those
explicit expressions. Mathlib has the exact gluing tool (`StrictAntiOn.union` /
`StrictMonoOn.union`, `Order/Monotone/Union.lean:65` and `:29`), so the whole of Lemma 3,
Proposition 5 and the deposit-efficiency half of Proposition 6 is within one Aristotle bundle,
at precedent size.

Three factual corrections to the phase brief fall out of reading the PDF, and each one is
load-bearing. **(1)** The curvature results are **Lemma 3, Proposition 5, Proposition 6** — not
"Lemma 1" and "the Proposition". Lemma 1 is the unrelated one-token-shock arbitrage-profit result.
**(2)** Capponi's `α` is **not an arrival probability**: it is the *investor's private-use
premium*, the markup `(1+α)p_i` a "type i" investor places on token `i`; `β` is the *magnitude of
the price shock*. The arrival probabilities are `κ_I, κ_com, κ₁, κ₂, θ`. This matters far beyond
bookkeeping: `α` is a **demand-side valuation parameter**, which is exactly the object
`MevJointProgram`'s own T22 docstring names as the escape from the M6a degeneracy ("with demand
response FLAIR need not remain monotone and the degeneracy dissolves") and exactly what
`LEAN_TRACEABILITY` §6(b) records as the missing layer. Phase 12 is therefore filling a gap the
project has already named. **(3)** `k* = k₁ = 1 − √((1+f)/(1+α))` is a **kink**, the branch point
at which the *investor's* trade switches from draining the pool to an interior marginal condition.
It is not a stationary point; there is **no first-order condition**, and a prompt that asks for one
will produce a false or vacuous theorem.

The central design question — how Capponi's `k` relates to our `η` — has a clean answer that
is neither "transcribe verbatim" nor "re-derive from scratch". `VolInstrument.priceEta η Δi i =
λ^((i/2)·Δi·η)` has a **tick-independent step ratio** `λ^(Δi²η/2)`, so the natural discrete
curvature index — Capponi's own definition, "the rate of change of the marginal exchange rate" —
is `χ(η) := 1 − p(i)/p(i+Δi) = 1 − λ^(−Δi²η/2)`, a strictly increasing bijection from `η ∈ (0,∞)`
onto `χ ∈ (0,1)` matching Capponi's `k ∈ [0,1]` at both endpoints (`η → 0⁺` is the zero-curvature
constant-price grid; `η → ∞` is maximal curvature). Composing the interior optimum through that
bijection gives a **closed form for the phase's headline object**:

> **η\* = ln((1+ϱ_I)/(1+φ)) / (Δi² · ln λ)**, positive exactly when the investor's private-use
> premium exceeds the fee, strictly increasing in that premium, **strictly decreasing in the fee**,
> and strictly decreasing in the tick spacing squared.

The fee-monotonicity is the de-degeneration in one line: Phase 11 proved the fee block sits at its
upper corner, and that corner **lowers** the optimal curvature. The two blocks are coupled, the
`Θ_φ` coordinate is a corner, the `η` coordinate is interior, and — unlike M6a — the two objectives
over `η` (arb loss down, investor surplus down) do not share an argmax.

**Primary recommendation:** take **Option C** — transcribe Capponi §5.1 *verbatim as
one-dimensional algebra over a remapped curvature index `χ`*, carrying every equilibrium
aggregate as a free constant with sign hypotheses; then prove **our own** bridge
(`priceEta` step ratio → `χ(η)` → `η*`) and transport the interior optimum through the strictly
monotone reparametrization. Do **not** attempt to re-derive the arbitrageur's optimum on the tick
grid (that is a research programme, not a bundle), and do **not** identify the Capponi arb-loss
ratio with `MevOptimization.mevMulti` (different model, different units — the same discipline that
keeps `λ_ARB` distinct from `λ_MEV`). Label the equilibrium transfer OPEN.

---

## Findings

### F1 — The exact closed forms. Confidence: HIGH (PDF read directly, `pdftotext -layout`)

Anchor: **Capponi & Jia, "The Adoption of Blockchain-Based Decentralized Exchanges",
arXiv:2103.08842v4 [q-fin.TR], dated 21–22 July 2021.** Local:
`../plank/refs/mev/CapponiJiaAdoptionDEX.pdf`.

**The family (§5.1, p. 22):**

```
F_k(x,y) = (1−k)·A·F₀(x,y) + k·F₁(x,y),      k ∈ [0,1]
F₀(x,y) = p_A x + p_B y   (linear, zero curvature)
F₁(x,y) = x y             (constant product, maximal curvature in the family)
A = (y_A y_B / (p_A p_B))^{1/2}   (scaling coefficient)
```

Curvature of `F_k = C` is increasing in `k`. Fee `f` is the AMM's proportional trading fee.
`α` = investor private-use premium. `β` = price-shock magnitude. Lemma 1 gives `β > f` ⟹
arbitrage occurs; Lemma 2 gives `α > f` ⟹ the investor trades.

**§A — the two ratios (proof of Lemma 3, pp. 60–63).** Write
`ϖ_A ≜ (1−θ)(κ₁(1−κ₂)+κ₂(1−κ₁))` (probability an arbitrage occurs in a period) and
`k₂ ≜ 1 − √((1+f)/(1+β))`, `k₁ ≜ 1 − √((1+f)/(1+α))`. Then (A.36)/(A.38):

```
E[arb-loss ratio](k) = ϖ_A · ½ · ⎧ (1+β) − (1+f)/(1−k)        for k ∈ [0, k₂]   (corner branch)
                                 ⎨
                                 ⎩ (1+β)·k₂² / k               for k ∈ [k₂, 1]   (interior branch)
```

and (A.42)/(A.43), with `k₁` in place of `k₂` and `α` in place of `β`:

```
surplus ratio(k) =    ½ · ⎧ (1+α) − (1+f)/(1−k)         for k ∈ [0, k₁]
                          ⎨
                          ⎩ (1+α)·k₁² / k                for k ∈ [k₁, 1]
```

*(The paper writes the interior branch as `(√(1+β) − √(1+f))²/(2k)`; that equals
`(1+β)·k₂²/(2k)` by the definition of `k₂`, which is the algebraically cheaper form and the one
the prompt should specify. **Both branches were checked to agree at the branch point** —
`(1+β)(1−s)/2` with `s = √((1+f)/(1+β))` — so the glued function is continuous.)* Each branch is
manifestly strictly decreasing in `k` (`(1+f)/(1−k)` increasing; `1/k` decreasing), and the paper
says exactly that ("The above ratio is obviously decreasing in k", "which is also decreasing in
k"). **This is the whole of Lemma 3.**

**§B — the LP excess return (proof of Proposition 5, pp. 63–67).** With
`D(k) ≜ E[R_D] − E[R_A]` and the constant `ϖ_D ≜ (1−θ)(κ₁−κ₂)`, equations (A.50)–(A.52) give
three branches:

```
k ∈ [0, k₂] :   D = τ₃(k) − ϖ_D·β,   τ₃(k) = (κ_I/2)((1+f)/(1−k) − 1) − ϖ_A·½((1+β) − (1+f)/(1−k))
k ∈ [k₂, k₁]:   D = τ₂(k) − ϖ_D·β,   τ₂(k) = (κ_I/2)((1+f)/(1−k) − 1) − ϖ_A·½·(1+β)k₂²/k
k ∈ [k₁, 1] :   D = τ₁/k  − ϖ_D·β,   τ₁ = constant in k
```

`τ₃` and `τ₂` are increasing in `k` (every term is); `τ₁/k` is decreasing **iff `τ₁ > 0`**.
The paper handles `τ₁ ≤ 0` as the liquidity-freeze case where the LP payoff is `E[R_A]`, constant
in `k`. **I verified `τ₂(k₁) = τ₁/k₁` by hand** (both equal `(κ_I/2)(√((1+f)(1+α)) − 1) −
ϖ_A·½·(1+β)k₂²/k₁`), so `D` is continuous across `k₁`; the same check at `k₂` follows from §A's
branch agreement. Hence `D` is strictly increasing on `[0,k₁]`, strictly decreasing on `[k₁,1]`,
and

> **k\* = k₁ = 1 − √((1+f)/(1+α))**, interior in `(0,1)` iff `α > f`.

Proposition 5(2) (liquidity freeze least likely at `k*`) is a one-line corollary of the maximum:
`D(k*) < 0 ⟹ ∀k, D(k) < 0`. The LP payoff itself is `max(E[R_D], E[R_A])` with `E[R_A]`
constant in `k`, so it inherits the single peak.

**§C — Proposition 6.** Deposit efficiency (A.56) has the same two-branch shape with the same
branch point `k*`, increasing below and decreasing above — **directly transcribable**. The
welfare half is a sum of three pieces (LP aggregate payoff, arbitrageur payoff = 0 by
Assumption 3, investor surplus), each already shown single-peaked-or-antitone at `k*`; it is
transcribable **only as a reduced statement** over those three pieces as given functions, not as a
welfare theorem about the underlying game. See F5's OPEN list.

**Hypothesis `α > β`.** Proposition 5's displayed hypothesis is `α > β`; its proof uses `α ≥ β`
and consumes it only through **`k₁ ≥ k₂`** — i.e. only through the ordering of the two branch
points. That is the right form to transcribe: state `χ_S ≤ χ_I` as the hypothesis and prove
`ϱ_S ≤ ϱ_I ↔ χ_S ≤ χ_I` as a separate lemma, so nothing depends on the strict/non-strict
mismatch.

---

### F2 — The collision set, and why it is bigger than CONTEXT says. Confidence: HIGH (grepped)

The gate INVERTS: **`η` is now the protected symbol that MUST appear**, and the Phase-11 gate
script (`.planning/phases/11-mev-hazard-inf-program/mev-notation-gate.sh`, Rule 1) *forbids* `η`.
A new script is required; it cannot be reused.

Foreign symbols needing remaps, with the collisions actually verified in the master document and
in `lean/vol_markets/*.lean`:

| Capponi symbol | Meaning | Collides with | Remap (proposed) | Lean identifier |
|---|---|---|---|---|
| `k` | curvature index | `MevJointProgram.taxFraction (k : ℝ)` — the auction-tax multiple, M7(i); **and** `k` = the SCHEDULE.md control slope (LEAN_TRACEABILITY §0) | **`χ`** (`\chi`) | `curv` |
| `α` | investor private-use premium | `Θ_φ`'s `α_j` sigmoid amplitudes; `Panoptic.replicationPrice`'s `α₁,α₂` | **`ϱ_I`** (`\varrho_I`) | `premInv` |
| `β` | price-shock magnitude | `Θ_φ`'s `β_j` sigmoid centers; `MeanVarianceEta`'s CEV `β` | **`ϱ_S`** (`\varrho_S`) | `premShock` |
| `f` | proportional trading fee | — it **IS** our `φ` | **`φ`** (identified, not renamed) | `φ` / `fee` |
| `θ` | common-shock probability | the master doc's **option theta** `θ(p,K,σ)` — a hard collision | *never named* — absorbed (below) | — |
| `κ_I, κ_com, κ₁, κ₂` | arrival / shock probabilities | `joint_scalarization_degeneracy`'s scalarization `κ`; `BondingCurveCurvature.kappa` | *never named* — absorbed (below) | — |
| `A` | scaling coefficient of `F₀` | — | keep, or elide (it cancels) | — |

**Recommendation: absorb every probability into four free constants rather than remapping five
Greek letters.** This follows M0's own precedent ("the paper's composite `η ≜ γ√(2λ)/σ` is
deliberately never named"), it collapses the worst collisions (`θ`, `κ`) to zero, and it is
faithful because the paper's monotonicity arguments use these quantities *only* as constants:

```
ϖ_A ≜ (1−θ)(κ₁(1−κ₂)+κ₂(1−κ₁))   probability an arbitrage occurs in a period
ϖ_I ≜ κ_I                          probability an investor arrives
ϖ_H ≜ κ₁(1−θ) + κ_com·θ            the hold-benchmark coefficient (E[R_A] = ϖ_H·ϱ_S)
ϖ_D ≜ (1−θ)(κ₁−κ₂)                 the constant subtracted in D(χ)
```

**Glyph availability verified by grep against BOTH the master doc and `lean/vol_markets/`:**
`χ` 0 hits, `ϱ` 0 hits, `ϖ` 0 hits, `ρ` 0 hits. **`ν` is NOT free** — the master doc binds it at
line 703 (`ν_t = w_t/D_t`, the per-step FLAIR weight in M6b), so it must not be used. `ς` is free
but is visually confusable with `σ` and is rejected on that ground. `χ` has 3 glyph hits inside
`lean/exp/`; that is outside `vol_markets` and outside the doc, but the Lean identifiers below are
ASCII anyway, so no shadowing arises.

**The gate must therefore enforce, on the E-block section:** (1) `η` / `\eta` MUST appear
(inverted Rule 1); (2) a bare `k` or `\lambda`-unsubscripted must not appear outside
`<!-- notation-map -->` lines; (3) Capponi's `α`, `β`, `θ`, `κ` glyphs must not appear
unsubscripted-and-unmapped; (4) required tokens `2103.08842`, `\chi`, `\varrho_I`, `\varrho_S`,
`OPEN`; (5) no absolute/home paths; (6) the notation-map whitelist bounded above by the `**E1.`
header, exactly as Rule 7 does for `**M1.`.

---

### F3 — THE DESIGN DECISION: the `k ↔ η` mapping. Confidence: HIGH on the construction, MEDIUM on economic transfer

CONTEXT offers three options. **Recommendation: Option C, in the specific shape below.** The
argument is provability, and it is decisive.

**Option A alone (transcribe `F_k` verbatim, `k` remapped onto an η-derived quantity) is
insufficient** — it produces a theory about a mixture of a linear and a constant-product curve, a
family our AMM does not use, with no theorem connecting it to `priceEta`. The phase would ship a
correct formalization of somebody else's pool.

**Option B alone (re-derive two-sided monotonicity + interior optimum directly for a slippage
functional of `priceEta`'s `η`) is not feasible in one bundle** — and probably not in three. It
requires re-solving the arbitrageur's constrained optimum and the investor's constrained optimum
on a *discrete tick grid with per-tick liquidity*, then re-running the two-period deposit game.
Capponi gets closed forms only because `F_k` is a two-term smooth curve. On the grid, (A.33) and
(A.40) become lattice search problems. This is a research programme; presenting it as an
Aristotle bundle would return either `sorry`s or narrowed statements.

**Option C, concretely:**

1. **The economics is Capponi's, over a curvature index `χ ∈ (0,1)`, with equilibrium content
   frozen into constants.** Everything in F1 §A–§C, proven.
2. **The geometry is ours, and it is genuinely provable.** From `priceEta η Δi i = λ^((i/2)Δi η)`:

   ```
   priceEta η Δi (i+Δi) / priceEta η Δi i  =  λ^((Δi²·η)/2)      — INDEPENDENT of i
   ```

   Capponi's own definition of curvature is "the rate of change of the marginal exchange rate"
   (§5.1, p. 22). Its discrete form on a geometric grid is the *relative* marginal-rate increment
   per tick, which is tick-independent:

   ```
   curvIndex η Δi  ≜  1 − priceEta η Δi i / priceEta η Δi (i+Δi)  =  1 − λ^(−Δi²η/2)
   ```

   This is strictly increasing in `η`, maps `(0,∞)` bijectively onto `(0,1)`, tends to `0` as
   `η → 0⁺` (the zero-curvature constant-price grid — Capponi's `k = 0`) and to `1` as `η → ∞`
   (maximal curvature — Capponi's `k = 1`). The endpoint correspondence is exact at both ends,
   which is what licenses `χ ∈ (0,1)` as the shared domain.
3. **Transport.** `χ` strictly monotone ⟹ the single peak of `D` at `χ*` pulls back to a single
   peak of `D ∘ curvIndex` at `η* = curvIndex⁻¹(χ*)`, and the inverse is closed-form:

   ```
   1 − λ^(−Δi²η*/2) = 1 − √((1+φ)/(1+ϱ_I))
   ⟹  η*  =  ln((1+ϱ_I)/(1+φ)) / (Δi² · ln λ)          [ ln λ = ln 1.0001 > 0 ]
   ```

   with `η* > 0 ⟺ φ < ϱ_I`, `η*` strictly increasing in `ϱ_I`, **strictly decreasing in `φ`**,
   strictly decreasing in `Δi²`. All of this is `Real.rpow`/`Real.log` algebra.
4. **What is OPEN, and must be labelled so.** Step 2 defines a curvature index; it does **not**
   prove that the tick-grid AMM's arbitrage-and-investor equilibrium has Capponi's closed forms
   with `χ` in the `k` slot. That transfer is an **assumption**, and the E-block must say so in
   the same voice `LEAN_TRACEABILITY` uses for `arb_add_fee_eq_lvr` ("a bridge identity and
   nothing more"). Concretely: the theorem `lpExcessEta_isMaxOn_etaStar` is a theorem about
   `lpExcess ∘ curvIndex`; that `lpExcess` is the tick-grid AMM's LP excess return is the
   modelling hypothesis.

**A known asymmetry, recorded rather than smoothed:** Capponi's `k = 1` is CPMM and caps the
family; our `η → ∞` does not cap. So `curvIndex` covers curvatures beyond Capponi's range. This
*helps* interiority (`η*` is a genuine interior max on `(0,∞)`, not a boundary-adjacent one) but
means the E-block may not claim "`η = 1` is CPMM". In our own convention `priceEta 1 = tickPrice`
(`VolInstrument.priceEta_one`), i.e. `η = 1` is the standard sqrt-price grid — a *different*
normalization from Capponi's `k = 1`. **The prompt must forbid any theorem asserting
`curvIndex 1 = 1` or equating `η = 1` with `χ = 1`.**

---

### F4 — What is provable: the theorem set. Confidence: HIGH

Numbered `T1'…T31'` to avoid collision with Phase 11's `T1–T30`. Target trim: **26–28 delivered**,
which is exactly precedent (bundle A: 25 declarations; bundle B: 27).

**Section A — the curvature layer (Lemma 3).**

| # | Statement | Notes |
|---|---|---|
| T1' | `arbLossRatio ϖA ϱS φ χ` — the two-branch def; `chiS ϱS φ := 1 − √((1+φ)/(1+ϱS))` | def + `chiS` def |
| T2' | `chiS_mem_Ioo : φ < ϱS → 0 ≤ φ → chiS ∈ Ioo 0 1` | |
| T3' | `arbLossRatio_branch_agree` — the two branches coincide at `chiS` | pure algebra; the continuity witness |
| T4' | `arbLossRatio_strictAntiOn (Set.Ioc 0 1)` | **must return `StrictAntiOn`, not `AntitoneOn`** — via `StrictAntiOn.union` |
| T5' | `arbLossRatio_pos` on the admissible region; `arbLossRatio_eq_zero_of_fee_ge` (`ϱS ≤ φ`) | Lemma 1's `β > f` condition |
| T6' | `surplusRatio ϱI φ χ` def; `chiI ϱI φ := 1 − √((1+φ)/(1+ϱI))` | |
| T7' | `surplusRatio_strictAntiOn (Set.Ioc 0 1)` | Lemma 3(2); same route as T4' |
| T8' | `chiS_le_chiI_iff : ϱS ≤ ϱI ↔ chiS ≤ chiI` (given `0 ≤ φ`) | **this is Prop 5's `α > β` hypothesis, geometrized** |

**Section B — the interior optimum (Prop 5, Prop 6).**

| # | Statement | Notes |
|---|---|---|
| T9' | `lpExcess` — the three-branch def, with `ϖI, ϖA, ϖD, ϱS, ϱI, φ` free | |
| T10' | `lpExcess_branch_agree_chiS`, `_chiI` | I verified `τ₂(k₁) = τ₁/k₁` by hand — see F1 §B |
| T11' | `lpExcess_strictMonoOn (Set.Icc 0 chiI)` | `StrictMonoOn.union` at `chiS`; needs `chiS ≤ chiI` (T8') |
| T12' | `lpExcess_strictAntiOn (Set.Icc chiI 1)` | **needs `0 < τ₁`** — see the pre-empt list |
| T13' | `lpExcess_isMaxOn (Set.Icc 0 1) chiI` / `IsGreatest` form | **must be over the WHOLE `[0,1]`, not local** |
| T14' | `chi_star_eq : chiStar = 1 − √((1+φ)/(1+ϱI))` and `chiStar ∈ Ioo 0 1 ↔ φ < ϱI` | the closed form |
| T15' | `lpPayoff_isMaxOn` — `max(lpExcess + c, c)` peaks at `chiStar` for `c` constant in `χ` | `E[R_A]` is `χ`-constant |
| T16' | `liquidity_freeze_minimal : lpExcess chiStar < 0 → ∀ χ ∈ Icc 0 1, lpExcess χ < 0` | Prop 5(2), one line from T13' |
| T17' | `depositEfficiency` def + `_isMaxOn chiStar` | Prop 6, first half — (A.56) |
| T18' | *(OPTIONAL)* `welfareReduced_isMaxOn chiStar` under the explicit hypothesis that the arbitrageur's equilibrium payoff is `0` | mark OPTIONAL like T19 was; **an omission is an acceptable, recordable outcome** |

**Section C — the η bridge (ours).**

| # | Statement | Notes |
|---|---|---|
| T19' | `priceEta_step_ratio : priceEta η Δi (i+Δi) / priceEta η Δi i = lam ^ (Δi^2*η/2)` — **tick-independent** | the enabling algebra |
| T20' | `curvIndex η Δi := 1 − lam ^ (−Δi^2*η/2)`; `curvIndex_eq_of_priceEta` (agrees with `1 − p(i)/p(i+Δi)` for every `i`) | the definition + its meaning |
| T21' | `curvIndex_mem_Ioo : 0 < η → 0 < Δi → curvIndex ∈ Ioo 0 1` | |
| T22' | `curvIndex_strictMono` in `η` | |
| T23' | `curvIndex_tendsto_zero` (`η → 0⁺`), `curvIndex_tendsto_one` (`η → ∞`) | the endpoint correspondence with Capponi's `k = 0`, `k = 1` |
| T24' | **`etaStar ϱI φ Δi := Real.log ((1+ϱI)/(1+φ)) / (Δi^2 * Real.log lam)`** and **`curvIndex_etaStar : curvIndex (etaStar …) Δi = chiStar ϱI φ`** | **THE HEADLINE** |
| T25' | `etaStar_pos_iff : 0 < etaStar ↔ φ < ϱI` | |
| T26' | `etaStar_strictMono_premInv`, `etaStar_strictAnti_fee`, `etaStar_strictAnti_spacing` | three comparative statics |
| T27' | `lpExcessEta := lpExcess ∘ curvIndex`; `lpExcessEta_isMaxOn (Set.Ioi 0) (etaStar …)` | **must be CONSTRUCTED from T24', never delivered by hypothesizing a maximizer** — see PIT-E6 |
| T28' | `lpExcessEta_strictMonoOn (Ioc 0 etaStar)`, `_strictAntiOn (Ici etaStar)` | the two-sided shape in `η` |

**Section D — de-degeneration (composes with Phase 11).**

| # | Statement | Notes |
|---|---|---|
| T29' | `eta_no_common_argmax` — for `η₁ < η₂`, `arbEta η₂ < arbEta η₁` **and** `surpEta η₂ < surpEta η₁`; hence no `η` both minimizes arb-loss and maximizes surplus | the exact CONTRAST with `MevJointProgram.joint_corner_degeneracy`, which must be named in the docstring |
| T30' | `joint_corner_and_interior` — with `Θ_φ` at the Phase-11 corner (`flairMulti_corner_attained_levels`, `mevMulti_corner_attained_levels` cited by name) and the fee level pinned at `φ`, the pair `(Θ_φ-corner, η*)` is optimal; `Θ_φ` is a CORNER, `η` is INTERIOR | |
| T31' | `etaStar_coupled_to_fee_corner` — restating T26'(fee): raising the fee to its `Θ_φ` corner strictly LOWERS `η*` | the coupling; the phase's economic punchline |

**Anti-narrowing watch list (the 11-03 discipline).** T4'/T7'/T11'/T12' must come back **strict**;
T13' must be over the whole interval; T27' must not be a restatement of an assumed maximizer;
T24' must be an equality, not an existence claim; T29' must not be weakened to a
single-objective monotonicity.

**Hypothesis pre-empt paragraph (MANDATORY — the T15/T17 precedent).** State up front that the
prover MAY add, and the plan EXPECTS:

- **`0 < χ` on the interior branch.** `arbLossRatio` and `surplusRatio` have a **`1/χ` pole at
  `χ = 0`** — the exact structural analogue of `ptrade`'s negative-fee pole, which was live in two
  places in Phase 11 and killed T15 as specified and T17 as specified. Any compact-domain or
  limit statement must exclude `χ = 0` or stay on the corner branch. **Pre-authorize it.**
- `0 ≤ φ`, `φ < ϱ_S` (Lemma 1), `φ < ϱ_I` (Lemma 2).
- `0 < τ₁` for T12'/T13'/T15' (the non-freeze case; the paper itself splits here).
- `0 ≤ ϖ_A, ϖ_I, ϖ_D, ϖ_H`.
- `0 < Δi`, `1 < lam` for T21'–T28' (`PosSpec.one_lt_lam`, `PosSpec.lam_pos` already exist).
- `χ_S ≤ χ_I` on T11' (equivalently `ϱ_S ≤ ϱ_I`, via T8').

---

### F5 — What must be OPEN, and why. Confidence: HIGH

Honest labels, not softening. Five items:

1. **The equilibrium transfer.** That the tick-grid AMM's arbitrage/investor equilibrium has
   Capponi's closed forms with `curvIndex η Δi` in the `k` slot is **assumed**, not derived.
   Deriving it means re-solving (A.31)/(A.39) on a discrete grid with per-tick liquidity. **OPEN.**
2. **Welfare (Prop 6, second half).** Transcribable only as a statement about three given
   functions plus the Assumption-3 zero-arbitrageur-payoff hypothesis. Either bound it that way
   or leave it **OPEN** — do not state a welfare theorem about the game.
3. **The relation between the Capponi arb-loss ratio and `MevOptimization.mevMulti` (`λ_ARB`).**
   Different models (two-period discrete-shock vs MMR fast-block diffusion), different units
   (a per-period ratio of pool value vs a discrete hazard sum over `D_t`). No identification is
   attempted; **OPEN**, and the module docstring must say so as forcefully as M0 says `λ_ARB` is a
   summand of `λ_MEV` and never a sibling.
4. **Gas fees.** Capponi's Assumption 3 (the arbitrageur pays a gas fee equal to its full profit)
   is what makes the arbitrageur's equilibrium payoff `0` and makes gas the deadweight loss in the
   welfare argument. It is absorbed, not modelled. **OPEN**, and it is the reason (2) is bounded.
5. **`Θ_φ`-restricted σ-varying MEV comparison** — inherited OPEN from Phase 11
   (`LEAN_TRACEABILITY` §7.1, last M6b row). Phase 12 does not touch it and must not appear to.

---

### F6 — The Lean route. Confidence: HIGH (all citations verified at the pinned Mathlib v4.28.0)

The whole of §A/§B is piecewise-algebraic monotonicity. The decisive tool exists:

| Lemma | Location (verified) | Use |
|---|---|---|
| `StrictMonoOn.union {s t} {c} (h₁ : StrictMonoOn f s) (h₂ : StrictMonoOn f t) (hs : IsGreatest s c) (ht : IsLeast t c) : StrictMonoOn f (s ∪ t)` | `Mathlib/Order/Monotone/Union.lean:29` | glue `lpExcess` across `chiS` |
| `StrictAntiOn.union` (same shape) | `Mathlib/Order/Monotone/Union.lean:65` | glue `arbLossRatio`, `surplusRatio` across their branch points |
| `StrictMonoOn.Iic_union_Ici`, `StrictAntiOn.Iic_union_Ici` | same file, `:57`, `:70` | whole-line variants if the domain is taken as `ℝ` |
| `MonotoneOn.union_right` | same file, `:76` | non-strict fallbacks |
| `strictMonoOn_of_deriv_pos {D} (hD : Convex ℝ D) …` | `Mathlib/Analysis/Calculus/Deriv/MeanValue.lean:374` | *fallback only* — the branches are simple enough for direct algebra |

`Set.Icc a b ∪ Set.Icc b c = Set.Icc a c` (`Set.Icc_union_Icc_eq_Icc`) plus `isGreatest_Icc` /
`isLeast_Icc` supply the `IsGreatest`/`IsLeast` side conditions. For §C the needed facts are
`Real.rpow_natCast`/`rpow_neg`/`rpow_add`, `Real.rpow_lt_rpow_left_iff` (with `1 < lam`),
`Real.log_pos`, `Real.rpow_logb`-style inversion, and `Real.exp_log` — all standard; the project
already exercises `Real.rpow_lt_rpow_of_exponent_lt` and `Real.rpow_pos_of_pos` in
`VolInstrument.priceEta_strictMono`/`_pos` and in `PosSpec`.

**Note for the prompt (the 11-02 precedent, where three supplied Mathlib hints did not exist):**
supply only citations verified by grep at v4.28.0, and state explicitly which nearby lemmas do
**not** exist so the prover does not hunt.

---

### F7 — There is a large pre-existing `lean/exp/` η layer that CONTEXT does not mention. Confidence: HIGH (read)

This is the single most important process finding, and it changes the plan.

`lean/lakefile.toml` declares a built library `exp` with **14 roots** (~2,900 lines), all
registered, all in `defaultTargets`, all sorry-free (the one `sorry` string in `exp/eta.lean:602`
is inside a docstring describing a past item). Relevant modules:

| Module | What it already owns |
|---|---|
| `exp/eta.lean` | `P_half`, `L_eta eta X Y` (the **weighted-CFMM trading function** `L = X^η Y^{1−η}`), `eta_split_kernel_identity`, `pi_trader_half_*` band results, `sigma_xs`/`sigma_realized` |
| `exp/EtaReplication.lean` | `p_eta lam Δi eta i` and **`p_eta_eq_P_half_rescaled`** — the fact that the η-kernel is the ½-kernel at rescaled spacing. This is the *same* fact `priceEta` encodes. |
| `exp/BondingCurveCurvature.lean` | `kappa L D p = 2DL³/(L+Dp)³` = `∂²Δ^O/∂p²`, `kappa_eq_secondDeriv`, `kappa_pos`, `kappa_strictAntiOn_p`, `abs_kappa_strictAnti_in_Δi`, `foc_interior` |
| `exp/DynamicsOptimization.lean` | `piPlus = Δi²·S(η)`, `piPlus_isMaxOn_Δi_corner`, **`foc_eta`**, **`optimal_controls`** — its own docstring: *"a boundary optimum in Δᵢ and an interior optimum in η"* |
| `exp/ComparativeStatics.lean`, `exp/EnvelopeTheorem.lean`, `exp/MeanVarianceOptimization.lean` | value-function machinery: `exists_optimizer`, `value_isMax`, `envelope_deriv`, `value_diff_sandwich` |

Three consequences:

1. **The "interior optimum in η" claim already has a carrier in a neighbouring model.** Phase 12
   must not present it as a first. What Phase 12 adds is the *construction*: `DynamicsOptimization`
   characterizes `η*` by a first-order condition `Σ_j η̃'_j(η*)·α_j² = 0` **assuming** an interior
   maximizer; Phase 12 **proves existence and gives a closed form** from a two-sided structure.
   The E-block and the traceability rows must state that difference explicitly, or a reviewer
   will (correctly) call the result a duplicate.
2. **`η` already means the weighted-CFMM exponent** (`model/exp/eta.md`: *"elasticity η ∈ (0,1),
   the trading-function exponent L = X^η Y^{1−η}"*), and `LEAN_TRACEABILITY` §0 pins `η` to that
   file. `VolInstrument.priceEta`'s `η` is the same parameter under the grid convention
   (`priceEta 1 = tickPrice`, i.e. `η = 1` is the ½-kernel). **The E-block must state the
   convention bridge**, because a reader who takes `η ∈ (0,1)` from `eta.md` and `η ∈ (0,∞)` from
   `curvIndex` will think the phase contradicts itself. Recommended sentence: *the grid exponent
   is a multiplier on the ½-kernel; `η = 1` is the standard sqrt-price grid, `eta.md`'s
   `η = 1/2` normalization is a different chart on the same parameter.* If the two really are
   different parameters, **that is a genuine finding and must be surfaced to the user, not
   papered over** — it is the one point in this research I would not sign off as HIGH.
   Confidence on the convention bridge: **MEDIUM.**
3. **Bundle composition.** Include the 13 `vol_markets` roots plus `exp/eta.lean` and
   `exp/EtaReplication.lean` (15 modules; prior bundles were 10 and 11). Reference
   `exp/DynamicsOptimization.lean` and `exp/BondingCurveCurvature.lean` **in the prompt text only**
   ("these exist; do not re-derive"), since bundling them pulls in `MeanVarianceEta` and grows the
   dependency set without buying a lemma the new module consumes.

**Coordination risk, flagged:** `model/exp/eta.md` is MODIFIED and
`model/exp/eta_pi_trader_delta_control.md` is UNTRACKED in the working tree, while
`git log` shows `1f6b26d chore(ownership): move math-doc set from model/exp/ → lean/exp/`. Someone
(or a prior pass) is moving the η doc set. **Check `claude-peers list_peers` and the working tree
before any plan touches `lean/exp/` or `model/exp/`.**

---

### F8 — The de-degeneration argument, stated precisely. Confidence: HIGH

Phase 11 M6a: over `Θ_φ`, `sup λ_FLAIR` and `inf λ_ARB` are at the **same** point in every
coordinate, robustly to every scalarization `κ ≥ 0` (`joint_corner_degeneracy`,
`joint_beta_degeneracy`, `joint_scalarization_degeneracy`). No trade-off.

Over `η` the structure is different **and the difference is exactly Lemma 3's two-sidedness**:

```
arb-loss ratio ↓ in curvature     ⟹ the LP-loss objective wants η → ∞
investor surplus ratio ↓ in curvature ⟹ the volume/fee objective wants η → 0⁺
```

Both antitone, so their optima are at **opposite** ends of the domain — the precise negation of
M6a's "same point in every coordinate". The LP payoff, which combines them, peaks strictly
between. That is T29' + T13'/T27'.

Two further points the plan should not miss:

- **The degeneracy escape was already named inside the project.** `MevJointProgram`'s T22
  docstring: *"This is specifically a degeneracy of two volume-INELASTIC objectives … With demand
  response FLAIR need not remain monotone and the degeneracy dissolves."* And
  `LEAN_TRACEABILITY` §6(b) records the missing layer as *"the demand-elasticity / optimal-fee
  equilibrium layer"*. Capponi's `ϱ_I` **is** that demand parameter. Phase 12 should say so and
  amend §6(b) accordingly at close-out — that is a real closure, not a decoration.
- **The coupling is the punchline.** `η* = ln((1+ϱ_I)/(1+φ))/(Δi²·ln λ)` is strictly decreasing
  in `φ`. Phase 11 put `φ̄` at its **upper** corner. Therefore the fee corner **lowers** the
  optimal curvature: the two blocks are not separable even though one is a corner. State this as
  T31' and as its own E-block display.

---

### F9 — Doc block layout. Confidence: HIGH (mirrors the M-block precedent exactly)

**Placement:** a new top-level `## ETA` section **after** `### MEV`'s M8 caveats block (the master
doc currently ends at line 763 with M8). It reads as M8's successor, which is what it is. Do
**not** interleave with the M-blocks — M-block bytes are sha-pinned in `11-01-REVIEW.md` /
`11-02-RUN-RECORD.md` and 11-06 already recorded one intentional pin invalidation; a second one
should not be created casually.

| Block | Content |
|---|---|
| **E0. [NOTATION]** | The remap table (F2) with every line carrying `<!-- notation-map -->`; the anchor cite `arXiv:2103.08842v4`, **Lemma 3 / Proposition 5 / Proposition 6** named correctly; the four absorbed probability constants; the statement that `η` is PROTECTED and never reassigned; the `η = 1` ↔ ½-kernel convention bridge (F7.2); standing hypotheses `0 ≤ φ < ϱ_S ≤ ϱ_I`, `0 < Δi`. |
| **E1. [ADDITION]** | The `F_χ` family and the discrete curvature index `χ(η) = 1 − λ^(−Δi²η/2)`; tick-independence; the endpoint correspondence; the explicit warning that `η = 1 ≠ χ = 1`. |
| **E2. [ADDITION]** | The arbitrage-loss ratio, both branches, branch point `χ_S`, strict antitonicity. (Lemma 3(1)) |
| **E3. [ADDITION]** | The investors' surplus ratio, both branches, branch point `χ_I`, strict antitonicity. (Lemma 3(2)) |
| **E4. [ADDITION — THE INTERIOR OPTIMUM]** | `lpExcess`, three branches, continuity at both branch points, strict up/strict down, `χ* = χ_I` closed form, `χ* ∈ (0,1) ⟺ φ < ϱ_I`, liquidity-freeze minimization. (Prop 5) |
| **E5. [ADDITION]** | Deposit efficiency maximized at `χ*`; welfare **bounded or OPEN**. (Prop 6) |
| **E6. [ADDITION — THE BRIDGE]** | `η* = ln((1+ϱ_I)/(1+φ))/(Δi²·ln λ)`, `curvIndex(η*) = χ*`, the three comparative statics, the two-sided shape in `η`. |
| **E7. [ADDITION — THE DE-DEGENERATION]** | The contrast with M6a by name; `eta_no_common_argmax`; `(Θ_φ corner, η interior)`; the fee↔curvature coupling. |
| **E8. [CAVEATS]** | F5's five OPEN items, stated as OPEN. Plus: this is Capponi's two-period discrete-shock model, not MMR's diffusion; the two arb objects are not identified; gas is absorbed. |

---

### F10 — Workflow: one bundle, four plans. Confidence: MEDIUM-HIGH

**One bundle.** 26–28 statements is precedent-sized (bundle A: 25; bundle B: 27), the content is
one coherent chain (`χ` layer → optimum → bridge → joint), and splitting it would force the
second bundle to consume a module the first must land first — serializing two ~30-minute runs
plus two integration plans for no reduction in risk. The dependency argument that justified
Phase 11's split (bundle B genuinely consumed bundle A's `ptrade` lemmas) does **not** apply here:
Sections C and D consume only `priceEta` and the Phase-11 modules, all of which already exist.

**Four plans**, mirroring 11-01…11-06 with the two-plan-per-bundle structure collapsed once:

| Plan | Deliverable | Requirements |
|---|---|---|
| **12-01** | The E0–E8 doc block; new `eta-notation-gate.sh` (inverted); two-reviewer gate on the block; **HEAVY USER APPROVAL**; `APPROVED-DOC-SHA256` pin; insertion into the plank-owned file (edited, not committed). | CTX-CURVDOC, CTX-REVIEW |
| **12-02** | The `T1'–T31'` prompt over the 15-module bundle; hypothesis pre-empt paragraph; anti-narrowing clauses; two-reviewer gate **on the prompt**; doc fidelity re-proved at submit time; queue proven empty; single serial submit. | CTX-CAPTRANS, CTX-INTERIOR, CTX-ETABRIDGE, CTX-DEGEN, CTX-REVIEW |
| **12-03** | Integrate the returned module: import rewrite as the only edit, lakefile root registration, `lake build` green with the module's own "Built" line as evidence, axiom sweep generated from a grep, byte-identity of all 15 bundled modules, `T1'–T31'` fidelity diff against the sha-pinned prompt, explicit dispositions, push to both remotes. | CTX-CAPTRANS, CTX-INTERIOR, CTX-ETABRIDGE, CTX-DEGEN |
| **12-04** | `LEAN_TRACEABILITY` §0 rows + a new §7.2; §6(b) amended (the demand-elasticity gap is now partly closed); master-doc `> LEAN` back-annotation; the **plank todo #227 answer** written as a short, quotable statement (`η* = ln((1+ϱ_I)/(1+φ))/(Δi²·ln λ)`, controller reading, hook location implications); ROADMAP/STATE close-out; memory. | CTX-TRACE |

**Named contingency for a 5th plan:** if the 12-01 reviewer gate splits E0–E8 (most likely at E5,
the welfare block), or if the returned module omits Section C or D, insert `12-02b/12-03b` as a
second bundle rather than accepting narrowed statements. **Six plans are not justified up front**
— Phase 11 needed six because it ran two genuinely dependent bundles.

---

### F11 — Traceability shape at close-out. Confidence: HIGH

New `§7.2 ## ETA — the curvature controller and the interior η*`, same table shape as §7.1, one
row per E-block, statuses from the fidelity record only. §0 gains rows for `χ`/`curvIndex`,
`ϱ_I`/`premInv`, `ϱ_S`/`premShock`, `ϖ_*`, `η*`/`etaStar`, plus a **binding paragraph** recording
that Capponi's `k`, `α`, `β`, `θ`, `κ_*` are remapped/absorbed and that `η` is protected — the
exact mirror of the MMR collision paragraph. §6(b) is **amended, not deleted** (the 11-06
discipline): the demand-elasticity layer now has a partial carrier, with the equilibrium transfer
named as what remains OPEN. **Every backticked identifier in every new row must be grep-verified
against `^theorem|^lemma|^noncomputable def` in the landed module** — 11-06's check, which exists
because a row naming a non-existent lemma is worse than no row.

---

## Standard Stack

### Core (a proof phase — nothing to install)

| Component | Version | Purpose | Why standard |
|---|---|---|---|
| Lean 4 + Mathlib | pinned `v4.28.0` (`lean/lakefile.toml`) | the proof language | project-pinned; every prior bundle used it |
| Lake | bundled | build (`lake build`, `lake build vol_markets`) | the only build path |
| Aristotle CLI | as used in runs `cb371ee5`, `19f777ab`, `da1c9fce`, `78bac8dd` | authors statements AND proofs | the binding workflow rule: never hand-prove locally |
| `pdftotext -layout` (poppler) | system | anchor extraction | reproduces this research's evidence trail |

### Mathlib lemmas the new module will lean on (all grep-verified present at v4.28.0)

| Lemma | Location |
|---|---|
| `StrictMonoOn.union` | `Mathlib/Order/Monotone/Union.lean:29` |
| `StrictAntiOn.union` | `Mathlib/Order/Monotone/Union.lean:65` |
| `StrictMonoOn.Iic_union_Ici` / `StrictAntiOn.Iic_union_Ici` | same file, `:57` / `:70` |
| `MonotoneOn.union_right` | same file, `:76` |
| `strictMonoOn_of_deriv_pos` | `Mathlib/Analysis/Calculus/Deriv/MeanValue.lean:374` *(fallback)* |

Plus `Set.Icc_union_Icc_eq_Icc`, `isGreatest_Icc`, `isLeast_Icc`, `IsMaxOn`/`IsGreatest`,
`Real.rpow_neg`, `Real.rpow_add`, `Real.rpow_natCast`, `Real.log_pos`, `Real.exp_log`,
`Real.sqrt_lt_sqrt`, `Real.sq_sqrt` — standard, already exercised in `PosSpec` / `VolInstrument`.

### Project modules to reuse (do NOT redefine — the standing bundle rule)

`VolInstrument.priceEta`, `_pos`, `_strictMono`, `priceEta_one`; `PosSpec.lam`, `lam_pos`,
`one_lt_lam`, `tickPrice`; `FlairOptimization.flairMulti_corner_attained_levels`,
`Theta_lambda_identification`; `MevOptimization.mevMulti_corner_attained_levels`,
`Theta_lambdaMEV_identification`; `MevJointProgram.joint_corner_degeneracy`,
`joint_scalarization_degeneracy`; `exp.EtaReplication.p_eta_eq_P_half_rescaled`.

### Alternatives considered

| Instead of | Could use | Tradeoff |
|---|---|---|
| Option C (transcribe + bridge) | Option A (verbatim `F_k` only) | Cheaper, but ships no theorem about our AMM — F3 |
| Option C | Option B (re-derive on the tick grid) | Faithful, but requires re-solving two constrained optima and the deposit game on a lattice — not a bundle |
| Concrete `χ`-indexed defs | An abstract "curvature-indexed family" structure/typeclass | Elegant, but the 11-04 reviewers already caught one letter-compliant-but-empty construction; an abstraction with no non-vacuous instance is exactly that failure mode |
| Absorbing `θ, κ_*` into `ϖ_*` | Remapping all five | Five more collisions (incl. the option-theta clash) for zero mathematical content |
| Placing E-blocks inside `### MEV` | New `## ETA` section | Would disturb sha-pinned M-block bytes |

---

## Architecture Patterns

### Recommended file layout

```
lean/vol_markets/
├── EtaCurvature.lean      # NEW — Sections A–D; the 14th vol_markets root
└── (13 existing roots, untouched and byte-identical on return)

.planning/phases/12-eta-tradeoff-optimum/
├── 12-CONTEXT.md, 12-RESEARCH.md
├── eta-notation-gate.sh   # NEW — inverted gate (η REQUIRED, k/α/β/θ/κ forbidden)
├── 12-0N-PLAN.md / -SUMMARY.md
├── 12-01-REVIEW.md        # doc-block gate + APPROVED-DOC-SHA256
├── 12-02-PROMPT-REVIEW.md, 12-02-RUN-RECORD.md   # BUNDLED-DOC-SHA256, project/task ids
└── 12-03-FIDELITY.md      # T1'–T31' dispositions
```

Single new module. Splitting Sections A–D across files would force premature naming decisions and
buys nothing; the module docstring carries the caveats, as `MevOptimization`'s and
`MevJointProgram`'s do.

### P1 — Freeze the equilibrium, prove the algebra

Every quantity Capponi derives from the two-period game enters as a **free real with a sign
hypothesis** (`ϖ_A, ϖ_I, ϖ_D, ϖ_H, ϱ_I, ϱ_S, φ`). Nothing about arrival, deposits or gas is
modelled. This is the same move `FlairOptimization`/`MevOptimization` already make with `w_t`,
`a_t`, `D_t`, and it is what makes the transcription provable in one bundle.

### P2 — Glue, don't differentiate

Each branch is a sum of `c₁ + c₂/(1−χ)` or `c₃/χ` shapes whose monotonicity is one `div_lt_div`
step. Prove each branch on its closed sub-interval, prove branch agreement by `field_simp; ring`,
then glue with `StrictAntiOn.union` / `StrictMonoOn.union`. **Do not route through derivatives** —
the function is not differentiable at the branch points and the `MeanValue` route would force
`ContDiff` side goals that do not hold globally.

### P3 — Transport, don't re-prove

Section C proves `curvIndex` strictly monotone once; Sections B's results transport by
composition. `η*` is obtained by **inverting a closed form**, not by an existence argument. This
is what distinguishes T27' from `exp/DynamicsOptimization.optimal_controls`, whose `η*` is
hypothesized.

### P4 — The bundle (reproduce the bundle-A/B procedure exactly)

15 modules (13 `vol_markets` + `exp/eta` + `exp/EtaReplication`) + the doc copy +
`lean-toolchain` + `lakefile.toml` + `lake-manifest.json`; target
`RequestProject/EtaCurvature.lean`; inverse import rewrite `RequestProject.` → `vol_markets.` as
the **only** edit on return; register as a lakefile root by **appending** (11-03 found the anchor
had moved under a parallel run). Poll with `aristotle tasks`, **never `aristotle show`** (it
streams and blocks). `aristotle download --destination` writes an **archive file**, not a
directory.

### Anti-patterns to avoid

- **A first-order condition for `η*`.** The peak is a kink (F1 §B). `∂/∂η = 0` is false there.
- **Identifying `arbLossRatio` with `mevMulti`.** Different model, different units (F5.3).
- **`curvIndex 1 = 1`** or any claim that `η = 1` is Capponi's `k = 1` (F3, F7.2).
- **Editing the plank-owned doc without approval, or committing it.** Owner is `ul2inqpl`.
- **Reusing the Phase-11 notation gate.** Its Rule 1 forbids `η`; Phase 12 requires it.
- **Hand-proving locally.** Standing rule: draft statements, Aristotle proves.
- **Parallel `aristotle continue` on one project.** Parallel *new* projects are sanctioned.

---

## Don't Hand-Roll

| Problem | Don't build | Use instead | Why |
|---|---|---|---|
| Piecewise strict monotonicity | a bespoke case-split lemma | `StrictMonoOn.union` / `StrictAntiOn.union` | verified present; handles the `x < c ≤ y` cross case, which is where hand-rolled versions break |
| The optimum's existence | an EVT/compactness argument | the **closed form** T24' + T13' | EVT gives existence without location; the closed form is the deliverable |
| The curvature index | a new curvature primitive | `1 − p(i)/p(i+Δi)` from `priceEta` | it is Capponi's own definition, and it is tick-independent (T19') |
| Inverting `curvIndex` | a general inverse-function theorem | `Real.log` algebra | the map is `1 − λ^(−Δi²η/2)`; inversion is two lines |
| Capponi's probabilities | five remapped Greek symbols | four absorbed constants `ϖ_*` | avoids the option-`θ` and scalarization-`κ` collisions entirely |
| The whole proof | writing it locally | Aristotle | binding workflow rule; and the T15/T17 record shows the provers find false specifications |

**Key insight:** the anchor's economics is already reduced to one-variable algebra by the authors.
Everything expensive (the game) is in constants. Attempting to re-derive any of it is the only way
to fail this phase.

---

## Common Pitfalls

### PIT-E1: The notation gate inverts
**What goes wrong:** the Phase-11 script is reused; it fails on every line containing `η`, or is
edited to allow `η` and silently stops enforcing anything.
**How to avoid:** write `eta-notation-gate.sh` fresh (F2's six rules). **Warning sign:** the new
gate passes on the *Phase-11* addendum — it should fail there (no `η`).

### PIT-E2: Mislabelling the anchor's results
**What goes wrong:** the doc cites "Lemma 1" for the curvature lemma. `12-CONTEXT.md` does this.
Lemma 1 is the one-token-shock arbitrage-profit result; the curvature lemma is **Lemma 3**, and the
propositions are **5** (interior `k*`) and **6** (efficiency + welfare).
**How to avoid:** every citation in E0–E8 carries the number verified against the v4 PDF.
**Warning sign:** any reference to "the curvature proposition" without a number.

### PIT-E3: Treating `α`, `β` as arrival probabilities
**What goes wrong:** `12-CONTEXT.md` calls them "arrival probabilities". They are the **investor
private-use premium** and the **shock magnitude**. Under the wrong reading `k* = 1 − √((1+f)/(1+α))`
is uninterpretable, the `α > β` hypothesis is meaningless, and — worst — the demand-side link to
`LEAN_TRACEABILITY` §6(b) is lost, which is the phase's whole economic point.
**Warning sign:** any sentence describing `ϱ_I` as a probability, or as lying in `[0,1]`.

### PIT-E4: The `1/χ` pole
**What goes wrong:** a statement over a compact box including `χ = 0`. `arbLossRatio` and
`surplusRatio` blow up there; on an arbitrary box the objective is unbounded, so minimizers do not
exist — **structurally identical to `ptrade`'s negative-fee pole**, which made T15 false as
specified and T17 false as specified in Phase 11, in two separate places.
**How to avoid:** every domain is `Ioc 0 1` or a closed sub-interval of `(0,1]`; pre-authorize the
guard. **Warning sign:** any hypothesis-free `IsMinOn`/`IsMaxOn` over `Icc 0 1` touching a branch
with `χ` in a denominator.

### PIT-E5: Conflating the two arbitrage objects
**What goes wrong:** `arbLossRatio` gets identified with `MevOptimization.mevMulti`, or the module
claims to "extend λ_ARB to curvature". They come from different models with different units.
**How to avoid:** module docstring in the same voice M0 uses for `λ_ARB`/`λ_MEV`; the traceability
row says NOT IDENTIFIED. **Warning sign:** any theorem whose statement mentions both.

### PIT-E6: Duplicating (or being scooped by) `lean/exp/`
**What goes wrong:** the prompt re-derives `p_eta_eq_P_half_rescaled`, or T27' comes back as a
restatement of `DynamicsOptimization.optimal_controls` (which *hypothesizes* an interior `η*` and
characterizes it by an FOC). Then the phase's headline is a duplicate.
**How to avoid:** name both modules in the prompt as existing-and-off-limits; require T27' to be
**derived from T24'**, with the closed form appearing in the statement. **Warning sign:** an
`η*` that appears only as a bound variable with an `IsMaxOn` hypothesis.

### PIT-E7: Asking for a first-order condition
**What goes wrong:** the prompt requests `∂/∂η = 0` at `η*`. It is a kink; the derivative jumps.
A prover will either add hypotheses that make it vacuous or return a false statement.
**How to avoid:** the characterization is `curvIndex(η*) = χ_I`, a branch point. Say so.

### PIT-E8: Presenting the bridge as a derivation
**What goes wrong:** the doc reads as if Capponi's results were *proved* for the tick-grid AMM.
They are proved for `lpExcess ∘ curvIndex`; that `lpExcess` describes our AMM is a hypothesis.
**How to avoid:** E8 carries it; the module docstring carries it; the traceability row says OPEN.

### PIT-E9: `k` shadowing in Lean
**What goes wrong:** `k` as the curvature variable shadows `MevJointProgram.taxFraction (k : ℝ)`
and the SCHEDULE.md control slope. Use `curv`.

### PIT-E10: The plank-owned document
**What goes wrong:** the doc is edited or committed in the plank worktree. Owner is `ul2inqpl`.
**How to avoid:** edit-not-commit; verify plank `HEAD` unchanged before and after; re-verify
`BUNDLED-DOC-SHA256` **immediately before submit** — the live file can move while reviewers run
(11-02's procedure).

### PIT-E11: Queue discipline
Strictly serial per project; poll with `aristotle tasks`; prove the queue empty before submit.
Parallel submits to **new** projects are sanctioned; `aristotle continue` on the same project is
never parallel.

### PIT-E12: A parallel actor in `exp/`
`model/exp/eta.md` is modified and `model/exp/eta_pi_trader_delta_control.md` is untracked, and
`1f6b26d` moved the η doc set to `lean/exp/`. **Check `claude-peers list_peers` before touching
either tree**, and treat `lean/exp/*.lean` as read-only reference for this phase.

---

## Code Examples

### The curvature index and its inverse — the phase's core objects (draft signatures)

```lean
-- Source: derived from VolInstrument.priceEta (this repo) + Capponi-Jia §5.1 p.22
namespace EtaCurvature
open VolInstrument PosSpec

/-- The per-tick gross price ratio of the geometric grid.  INDEPENDENT of the tick `i`. -/
theorem priceEta_step_ratio (η Δi i : ℝ) :
    priceEta η Δi (i + Δi) / priceEta η Δi i = lam ^ (Δi ^ 2 * η / 2) := ...

/-- The discrete curvature index: the relative marginal-rate increment per tick.
    This is the anchor's own definition of curvature in discrete form. -/
noncomputable def curvIndex (η Δi : ℝ) : ℝ := 1 - lam ^ (-(Δi ^ 2 * η) / 2)

theorem curvIndex_eq_of_priceEta (η Δi i : ℝ) :
    curvIndex η Δi = 1 - priceEta η Δi i / priceEta η Δi (i + Δi) := ...

theorem curvIndex_mem_Ioo {η Δi : ℝ} (hη : 0 < η) (hΔ : 0 < Δi) :
    curvIndex η Δi ∈ Set.Ioo (0 : ℝ) 1 := ...

theorem curvIndex_strictMono (Δi : ℝ) (hΔ : 0 < Δi) :
    StrictMono (fun η => curvIndex η Δi) := ...
```

### The headline: the optimal η in closed form

```lean
/-- The anchor's `k*` (Proposition 5), in our curvature index. -/
noncomputable def chiStar (premInv fee : ℝ) : ℝ :=
  1 - Real.sqrt ((1 + fee) / (1 + premInv))

/-- THE PHASE DELIVERABLE.  `η* = ln((1+ϱ_I)/(1+φ)) / (Δi² · ln λ)`. -/
noncomputable def etaStar (premInv fee Δi : ℝ) : ℝ :=
  Real.log ((1 + premInv) / (1 + fee)) / (Δi ^ 2 * Real.log lam)

theorem curvIndex_etaStar {premInv fee Δi : ℝ}
    (hfee : 0 ≤ fee) (hpi : fee < premInv) (hΔ : 0 < Δi) :
    curvIndex (etaStar premInv fee Δi) Δi = chiStar premInv fee := ...

theorem etaStar_pos_iff {premInv fee Δi : ℝ} (hfee : 0 ≤ fee) (hΔ : 0 < Δi) :
    0 < etaStar premInv fee Δi ↔ fee < premInv := ...

/-- THE COUPLING: the Phase-11 fee corner strictly LOWERS the optimal curvature. -/
theorem etaStar_strictAnti_fee {premInv Δi : ℝ} (hΔ : 0 < Δi) :
    StrictAntiOn (fun fee => etaStar premInv fee Δi) (Set.Ico 0 premInv) := ...
```

### The two-sided lemma, glued (Lemma 3(1))

```lean
-- Source: Capponi-Jia arXiv:2103.08842v4, proof of Lemma 3, eqns (A.36)/(A.38), pp. 61-62.
noncomputable def chiS (premShock fee : ℝ) : ℝ := 1 - Real.sqrt ((1 + fee) / (1 + premShock))

noncomputable def arbLossRatio (probArb premShock fee χ : ℝ) : ℝ :=
  probArb / 2 * (if χ ≤ chiS premShock fee
                 then (1 + premShock) - (1 + fee) / (1 - χ)
                 else (1 + premShock) * (chiS premShock fee) ^ 2 / χ)

/-- Lemma 3(1).  MUST be `StrictAntiOn`; `AntitoneOn` is a NARROWING and is rejected. -/
theorem arbLossRatio_strictAntiOn {probArb premShock fee : ℝ}
    (hp : 0 < probArb) (hfee : 0 ≤ fee) (hsh : fee < premShock) :
    StrictAntiOn (arbLossRatio probArb premShock fee) (Set.Ioc (0 : ℝ) 1) := by
  -- Mathlib/Order/Monotone/Union.lean:65 -- StrictAntiOn.union at c = chiS, with
  -- isGreatest_Icc / isLeast_Icc and Set.Icc_union_Icc_eq_Icc.
  sorry
```

### The de-degeneration, stated against Phase 11 by name (T29')

```lean
/-- Over `Θ_φ` the two objectives share an argmax (`MevJointProgram.joint_corner_degeneracy`).
    Over `η` they do NOT: both ratios are strictly ANTITONE, so the arb-minimizer sits at
    `η → ∞` and the surplus-maximizer at `η → 0⁺`.  The LP payoff peaks strictly between. -/
theorem eta_no_common_argmax {probArb premShock premInv fee Δi η₁ η₂ : ℝ}
    (hΔ : 0 < Δi) (h₀ : 0 < η₁) (h : η₁ < η₂) ... :
    arbLossRatio probArb premShock fee (curvIndex η₂ Δi)
      < arbLossRatio probArb premShock fee (curvIndex η₁ Δi)
    ∧ surplusRatio premInv fee (curvIndex η₂ Δi)
      < surplusRatio premInv fee (curvIndex η₁ Δi) := ...
```

### Reproducing the anchor extraction (evidence trail for the plan)

```bash
pdftotext -layout ../plank/refs/mev/CapponiJiaAdoptionDEX.pdf /tmp/capponi.txt
sed -n '983,1115p'  /tmp/capponi.txt   # §5.1: family, Lemma 3, Prop 5, Prop 6
sed -n '3286,3570p' /tmp/capponi.txt   # proof of Lemma 3: (A.31)-(A.43)
sed -n '3567,3835p' /tmp/capponi.txt   # proof of Prop 5: (A.44)-(A.55), k* = k1
sed -n '3836,3935p' /tmp/capponi.txt   # proof of Prop 6: (A.56), welfare
```

---

## State of the Art

| Old approach | Current approach | When changed | Impact |
|---|---|---|---|
| The trade-off is controlled by the fee shape `(β_j, γ_j)` | **REFUTED** — machine-checked M6a degeneracy | Phase 11, 2026-07-31 | the controller must come from outside `Θ_φ` — this phase |
| The demand-elasticity layer is an unnamed gap | named precisely as `LEAN_TRACEABILITY` §6(b) and as `MevJointProgram` T22's docstring | Phase 11 close-out | Capponi's `ϱ_I` **is** that parameter; §6(b) is amendable at 12-04 |
| Every optimum in the program is a corner or a saturation limit | `η*` is a genuine **interior** optimum with a closed form | this phase | first interior optimum in the `Θ_φ`/`λ` program; note `exp/DynamicsOptimization` already has an interior-`η` FOC in a *different* model (F7) |
| Curvature ↔ arbitrage is folklore | Capponi–Jia give closed forms and a **two-sided** lemma | 2021 (v4) | the interior optimum exists precisely because *both* ratios fall in curvature |

**Deprecated / not to be reused:**
- `mev-notation-gate.sh` — Rule 1 forbids `η`; unusable here (PIT-E1).
- The `κ ≥ 0` scalarization framing as a *repair* — Phase 11 proved it does not repair M6a; over
  `η` it is not needed, since the peak comes from two-sidedness, not from weighting.

---

## Open Questions

1. **Is `VolInstrument.priceEta`'s `η` the same parameter as `model/exp/eta.md`'s
   `η ∈ (0,1)` trading-function exponent?** *Known:* `LEAN_TRACEABILITY` §0 pins `η` to
   `model/exp/eta.md`/`exp/eta.lean`; `priceEta 1 = tickPrice` (the ½-kernel);
   `EtaReplication.p_eta_eq_P_half_rescaled` says the η-kernel is the ½-kernel rescaled.
   *Unclear:* whether the two are the same parameter under different normalizations (my reading)
   or two distinct parameters sharing a glyph. *Recommendation:* **resolve in 12-01 with the user
   before the doc block is approved**, and state the convention explicitly in E0. If they are
   distinct, the E-blocks need a third symbol and the whole notation map changes. Confidence:
   MEDIUM. This is the one item I would not let a plan assume.

2. **How much of Proposition 6's welfare half is worth transcribing?** *Known:* the LP and
   investor pieces are already covered; the arbitrageur piece is `0` by Assumption 3. *Unclear:*
   whether a "reduced welfare" statement over three given functions carries content or is a
   tautology (the 11-04 T25 triviality failure mode). *Recommendation:* mark T18' **OPTIONAL**;
   an omission is recordable, exactly as T19 was.

3. **Does the phase want a *second* refutation-style result?** Phase 11's most valuable outputs
   were two refutations. A candidate here: *is `lpExcess` quasiconcave in `η` for every admissible
   parameter vector, or only under `τ₁ > 0`?* The `τ₁ ≤ 0` case is a flat (freeze) region, so
   strict single-peakedness is **FALSE** in general. *Recommendation:* state the strict version
   under `0 < τ₁` **and** ask for the `τ₁ ≤ 0` counterexample as an explicit optional item, so the
   boundary of the claim is machine-checked rather than asserted. Confidence: HIGH that this is
   the right shape; MEDIUM on whether it fits the bundle budget.

4. **Should the doc block quantify `ϱ_I` for a real pool?** Capponi's `α` is a private-use premium
   — unobservable. Plank's todo #227 wants an implementable controller. *Unclear:* what the
   on-chain proxy is (realized taker surplus? volume elasticity to fee changes?). *Recommendation:*
   do **not** invent a proxy in this phase; deliver `η*(ϱ_I, φ, Δi)` as the controller law and
   record "estimating `ϱ_I`" as the named follow-up for plank. Inventing a proxy would repeat the
   `υ` econometric null-result failure mode.

5. **Does `curvIndex`'s unbounded range (vs Capponi's `k ≤ 1`) break anything?** *Known:* the
   interior optimum is at `χ_I < 1`, so `η*` is attained inside the range and interiority is
   *helped*. *Unclear:* whether any transcribed statement quantifies over `k ∈ [0,1]` in a way
   that becomes false on `(0,∞)`. *Recommendation:* keep Section A/B on `χ ∈ (0,1]` and let
   Section C transport only onto `curvIndex`'s image; do not state Section A/B results directly
   over `η ∈ (0,∞)` without the image restriction.

---

## Validation Architecture

*(`workflow.nyquist_validation` is `true` in `.planning/config.json`.)*

### Test Framework

| Property | Value |
|---|---|
| Framework | Lean 4 elaborator + Lake (`lean/lakefile.toml`, Mathlib `v4.28.0`) — proofs *are* the tests |
| Config file | `lean/lakefile.toml` (the new module must be **appended** to the `vol_markets` roots) |
| Quick run command | `cd lean && lake build vol_markets` |
| Full suite command | `cd lean && lake build` (~8060 jobs at Phase-11 close) |
| Axiom sweep | `cd lean && lake env lean ../scratch/eta-curvature-axioms.lean` — file **generated by grep** from the module so it cannot silently omit a declaration |
| Notation gate | `bash .planning/phases/12-eta-tradeoff-optimum/eta-notation-gate.sh <doc>` — **new**, inverted |
| Doc fidelity | `sha256sum` pin + E-block byte diff (approved vs bundled vs live) |
| Statement fidelity | whitespace-normalized diff of every `T1'…T31'` block against the sha-pinned prompt |

### Phase Requirements → Validation Map

| Req ID | Behaviour | Type | Automated command | Exists? |
|---|---|---|---|---|
| CTX-CURVDOC | E0–E8 present, notation rules hold, bytes match the approved hash | gate | `bash .planning/phases/12-eta-tradeoff-optimum/eta-notation-gate.sh <doc>` + `sha256sum -c` | ❌ Wave 0 (new script) |
| CTX-CAPTRANS | T1'–T8' present, sorry-free, axiom-clean, **not narrowed** | build + sweep + diff | `lake build vol_markets`; axiom sweep; `12-03-FIDELITY.md` diff | ✅ pattern exists (11-03/11-05) |
| CTX-INTERIOR | T9'–T18' present; T13' over the whole interval; T18' disposition recorded | build + sweep + diff | same | ✅ |
| CTX-ETABRIDGE | T19'–T28' present; `curvIndex_etaStar` is an **equality**; T27' derived from T24' | build + sweep + diff | same, plus `grep -n 'etaStar' lean/vol_markets/EtaCurvature.lean` to confirm the closed form appears in statements | ✅ |
| CTX-DEGEN | T29'–T31' present; the Phase-11 identifiers are cited **and resolve** | build + identifier check | `grep -oE '(MevJointProgram\|MevOptimization\|FlairOptimization)\.[A-Za-z_]+' <module> \| sort -u` then confirm each against `^theorem\|^lemma\|^noncomputable def` in its home file | ✅ (11-06's loop) |
| CTX-REVIEW | two reviewers ran **in parallel, blind**, on doc and on prompt; every BLOCKER/MAJOR resolved before spend; queue proven empty | manual + record | `aristotle tasks --status RUNNING`; the two `*-REVIEW.md` artefacts | ✅ |
| CTX-TRACE | every backticked identifier in the new traceability rows is a real declaration; no absolute paths | script | identifier-existence loop over `§7.2`; `! grep -rE '/home/' <new rows>` | ✅ (11-06; note its known false-fail on quoted paths) |

### Sampling Rate

- **Per task commit:** `cd lean && lake build vol_markets` (must exit 0; `git status --porcelain lean/` must be empty on doc-only and prompt-only plans).
- **Per plan close:** full `lake build`; for 12-03 additionally the axiom sweep, the 15-module byte-identity check **before** integrating anything, and the `T1'–T31'` fidelity diff.
- **Phase gate:** full `lake build` green, `#print axioms` = `[propext, Classical.choice, Quot.sound]` for **every** declaration, notation gate PASS, both remotes pushed and verified fast-forward, before `/gsd:verify-work`.

### Wave 0 Gaps

- [ ] `.planning/phases/12-eta-tradeoff-optimum/eta-notation-gate.sh` — **new, inverted** gate (CTX-CURVDOC). The Phase-11 script cannot be reused.
- [ ] `lean/lakefile.toml` — append `"vol_markets.EtaCurvature"` to the `vol_markets` roots. **A missing root makes a green build vacuous** (11-03/11-05 both used the `Built vol_markets.X` log line as the evidence the module was actually elaborated).
- [ ] `scratch/eta-curvature-axioms.lean` — generated at 12-03, not authored.
- [ ] Resolve Open Question 1 (the `η` convention) **before** 12-01's doc block is approved.

*No framework install is needed; the toolchain is pinned and green at Phase-11 close.*

---

## Sources

### Primary (HIGH confidence)

- **`../plank/refs/mev/CapponiJiaAdoptionDEX.pdf`** — Capponi & Jia, *The Adoption of
  Blockchain-Based Decentralized Exchanges*, arXiv:2103.08842v4 [q-fin.TR], 21 Jul 2021. Read
  directly via `pdftotext -layout`: §3.3 (investor arrival, `α` as private-use premium; shocks,
  `β` as magnitude), §3.4 + eq. (3) (the arbitrage problem), Lemma 1, Lemma 2, §5.1 (the `F_k`
  family, **Lemma 3**, **Proposition 5**, **Proposition 6**), and the appendix proofs
  (A.31)–(A.56) at lines 3286–3935 of the extracted text.
- `lean/vol_markets/VolInstrument.lean` — `priceEta` (:30), `_pos` (:33), `_strictMono` (:37),
  `priceEta_one` (:44), `multiFee`, `probOr_hazard`.
- `lean/vol_markets/MevOptimization.lean` — `ptrade`, `mevHazard`, `mevMulti`, the identification
  and infimum block; module docstring's demand-elasticity caveat.
- `lean/vol_markets/MevJointProgram.lean` — `joint_corner_degeneracy` (:39),
  `joint_beta_degeneracy` (:60), `joint_scalarization_degeneracy` (:80) and its docstring naming
  demand response as the escape; `mevTotal` (:459), `taxFraction (k : ℝ)` (:406).
- `lean/vol_markets/FlairOptimization.lean` — `flairMulti_affine`, `_corner_attained_levels`,
  `Theta_lambda_identification`.
- `lean/exp/` — 14 registered roots; specifically `eta.lean`, `EtaReplication.lean`
  (`p_eta_eq_P_half_rescaled` :80), `BondingCurveCurvature.lean` (`kappa` :94 and its docstring's
  sign correction), `DynamicsOptimization.lean` (`foc_eta` :183, `optimal_controls` :201 and the
  header's "boundary optimum in Δᵢ and an interior optimum in η").
- `lean/lakefile.toml` — Mathlib pin `v4.28.0`; the `exp` / `vol_markets` / `tao` root lists.
- Mathlib v4.28.0, read in-tree at `lean/.lake/packages/mathlib/`: `Order/Monotone/Union.lean`
  (`StrictMonoOn.union` :29, `StrictAntiOn.union` :65, `.Iic_union_Ici` :57/:70,
  `MonotoneOn.union_right` :76); `Analysis/Calculus/Deriv/MeanValue.lean:374`.
- `model/vol_markets/LEAN_TRACEABILITY.md` — §0 notation dictionary and the MMR collision
  paragraph (the precedent pattern); §6's five named MEV gaps; §7.1's 14 claim rows.
- `../plank/notes/VOLATILITY_INSTRUMENTS.md` — `### MEV` blocks M0–M8 (lines 559–763), the
  `<!-- notation-map -->` marker convention, the `> LEAN` annotation style, `ν_t = w_t/D_t` at
  line 703 (the collision that rules `ν` out), the pricing-geometry block at lines 234–250.
- `.planning/phases/11-mev-hazard-inf-program/mev-notation-gate.sh` — the gate to invert.
- `.planning/ROADMAP.md` (Phase 11 plan rows, Phase 12 goal), `.planning/STATE.md`,
  `.planning/config.json`, `./CLAUDE.md`.

### Secondary (MEDIUM confidence)

- `model/exp/eta.md` — `η ∈ (0,1)` as the trading-function exponent `L = X^η Y^{1−η}`. **Modified
  and uncommitted** in the working tree; treated as evidence for Open Question 1, not as settled.
- The `η = 1 ↔ ½-kernel ↔ eta.md's η = 1/2` convention bridge (F7.2) — my reading of
  `priceEta_one` + `p_eta_eq_P_half_rescaled`; not stated anywhere as such. **Flagged for user
  confirmation.**
- The identification of Capponi's fee `f` with the document's `φ` — same economic object
  (a proportional trading fee charged to both the arbitrageur and the investor), but Capponi's is
  a constant while `φ` is `multiFee(σ)`; the transcription is at a **fixed** `φ`.

### Tertiary (LOW confidence — flagged, not relied on)

- The claim that `ϖ_A, ϖ_I, ϖ_D, ϖ_H` are the *minimal* absorbing set. They suffice for
  (A.36)–(A.56) as read; a fifth constant may surface when the E-blocks are written out.
- Any economic interpretation of `η` as "substitution elasticity" (plank todo #227's phrasing).
  For a weighted-geometric CFMM the elasticity of substitution is `1` and `η` is the **factor
  share**; the phrasing is loose and should be tightened in E0 rather than propagated.

---

## Metadata

**Confidence breakdown:**

| Area | Level | Reason |
|---|---|---|
| Capponi's closed forms and monotonicities (F1) | **HIGH** | read from the v4 PDF including the appendix proofs; the branch-agreement algebra re-derived by hand at both branch points |
| Notation collisions and remaps (F2) | **HIGH** | every glyph grepped against the master doc and `lean/vol_markets/`; `ν` found taken |
| The `k ↔ η` design decision (F3) | **HIGH** on construction and provability; **MEDIUM** on economic transfer | the algebra is elementary; the equilibrium transfer is an assumption and is labelled OPEN |
| The theorem set and Lean route (F4, F6) | **HIGH** | `StrictAntiOn.union` verified in-tree with line numbers; the pole hazard identified by analogy to a defect the project already hit twice |
| The pre-existing `lean/exp/` layer (F7) | **HIGH** on existence; **MEDIUM** on the `η` convention | lakefile and sources read; the convention question is Open Question 1 |
| De-degeneration (F8) | **HIGH** | follows from two proved-style antitonicities plus Phase 11's theorems by name |
| Workflow / plan count (F10) | **MEDIUM-HIGH** | precedent-based; the contingency for a 5th plan is named |

**Research date:** 2026-07-31
**Valid until:** 2026-08-30 for the anchor (a 2021 paper — stable); **7 days** for the repository
facts (`lean/exp/` is under concurrent edit, and Phase 11's modules were landing this same week).
