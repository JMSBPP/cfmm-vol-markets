/-
  exp/EtaIndexConsistency.lean

  Formal companion to `exp/EtaIndexConsistency.md`.

  Design question answered here (the DYNAMICS block of the latest spec note):

      « After `N` events/agents we get a tick sequence `{i_j}_{j=1}^N`,
        a payoff series `{π(Δᵢ(j))}_{j=1}^N`, and inventory weights `{η̃_j}`.
        But the η̃-weights and the dispersion σ were defined as a sum over the
        tick grid `Σ_{j=1}^{#_{Δ̄ᵢ}-1}`.  For consistency there must be a
        mapping from `N` to `#`.  What is the meaningful choice of indexes,
        with economic meaning, given the constraints already exposed? »

  ANSWER (made precise and machine-checked below).

  (1) The dynamics algebra is internally consistent.  The entry law
      `i_j = i_μ + α_j·Δᵢ` and the implied-spacing read
      `Δᵢ(j) = (i_j − i_μ)/α_j` are *exact inverses* for any nonzero step
      count `α_j` (`impliedDelta_entry`, `entry_impliedDelta`).  So `Δᵢ(j)`
      is a well-defined observable of event `j`.

  (2) The σ / η̃ objects live on the **tick grid**, not on event time.  The
      spec sum `Σ_{j=1}^{#−1}` runs over the `# − 1` *interior* tick
      positions (`interior_tick_count`).  A bijective relabelling of the `N`
      events by the `K` ticks exists **iff** `N = K = #−1`
      (`event_tick_bijection_iff`).  So a one-to-one event↔tick indexing is
      only consistent in the knife-edge case `N = #−1`.

  (3) The economically meaningful map for the generic case `N ≠ #−1` is the
      **occupation (pushforward) measure**.  Each event is assigned to the
      tick it occupies, `b : Fin N → Fin K`, and the η̃-mass it carries is
      pushed onto that tick: `w♯(k) = Σ_{j : b j = k} w_j` (`occupation`).
      This map *preserves total mass* (`occupation_sum`, `occupation_isProb`)
      and, crucially, *preserves expectations*: the event-indexed average of
      any tick-functional equals its tick-indexed average under the
      pushforward weights, `E_w[X∘b] = E_{w♯}[X]` (`occupation_expectation`).
      This is the precise sense in which the time series `{π(Δᵢ(j))}_{j=1}^N`
      and the grid sum `Σ_{j=1}^{#−1}` compute the *same* η̃-expectation: the
      "mapping from N to #" is the occupation map, and economic consistency =
      mass/expectation conservation under it.  Economically `w♯` is the
      empirical *occupation distribution* of agents across ticks; the support
      `K = #−1` (the number of admissible interior ticks in `[i_-, i_+]`),
      not the raw event count `N`, is the dimension that matters.

  (4) σ itself is a tick-probability second moment.  The model's
      `sigma_realized` is exactly the **uniform** η̃-expectation of the squared
      deviation over the `#` ticks (`sigma_realized_eq_uniform_expectation`),
      i.e. the equal-weight member `η̃_j = 1/#` of the spec identity
      `#·σ = Σ_{j=1}^{#−1} η̃_j (i_- + j·Δ̄ᵢ − i_μ)²`; and for *any*
      tick-measure `w` the second moment about `i_μ` splits into the
      η̃-variance plus the squared bias of the mean tick from `i_μ`
      (`sigma_second_moment_decomp`).

  Reuses: `CFMM.MeanVariance.{E, Var, IsProb, normalize, normalize_isProb,
  second_moment_decomp}` (`exp/MeanVarianceEta.lean`) and
  `CFMM.Eta.{sharp, sigma_realized}` (`exp/eta.lean`).  No fees and no new
  economic primitives are introduced.
-/
import Mathlib
import exp.eta
import exp.MeanVarianceEta

open scoped BigOperators
open CFMM.MeanVariance

namespace CFMM.IndexConsistency

/-! ## 1. The dynamics algebra is correct: the implied state-partition delta -/

/-- The implied state-partition delta read off event `j`: from the entry law
    `i_j = i_μ + α_j · Δᵢ`, the spacing is recovered as
    `Δᵢ(j) = (i_j − i_μ)/α_j`. -/
noncomputable def impliedDelta (i_mu i_j α : ℝ) : ℝ := (i_j - i_mu) / α

/-
**Inversion (dynamics correct).** The entry law and the implied-delta read
    are exact inverses for any nonzero step count `α`:
    `impliedDelta i_μ (i_μ + α·Δᵢ) α = Δᵢ`.
-/
theorem impliedDelta_entry (i_mu Δi α : ℝ) (hα : α ≠ 0) :
    impliedDelta i_mu (i_mu + α * Δi) α = Δi := by
  unfold impliedDelta; field_simp [hα]; ring;

/-
Conversely, the entry law reproduces the observed tick from the implied
    delta: `i_μ + α · Δᵢ(j) = i_j` for `α ≠ 0`.
-/
theorem entry_impliedDelta (i_mu i_j α : ℝ) (hα : α ≠ 0) :
    i_mu + α * impliedDelta i_mu i_j α = i_j := by
  unfold impliedDelta; rw [ mul_div_cancel₀ _ hα ] ; ring;

/-! ## 2. The N → # index map: counting interior ticks -/

/-
Number of **interior** tick positions `j = 1, …, # − 1` of the σ-grid: the
    index set of the spec sum `Σ_{j=1}^{#−1}` has cardinality `# − 1`.
-/
theorem interior_tick_count (n : ℕ) : (Finset.Ico 1 n).card = n - 1 := by
  convert Nat.card_Ico 1 n using 1

/-
**Consistency requirement `N = # − 1`.** An index-preserving bijection
    between the `N` event labels and the `K` tick labels exists **iff** the
    counts agree. The σ-sum ranges over `K = # − 1` interior ticks, so the
    event index `j = 1,…,N` can be identified one-to-one with the tick index
    `j = 1,…,#−1` exactly when `N = # − 1`.
-/
theorem event_tick_bijection_iff (N K : ℕ) :
    Nonempty (Fin N ≃ Fin K) ↔ N = K :=
  Fin.equiv_iff_eq

/-! ## 3. The economically meaningful map: the occupation (pushforward) measure -/

variable {N K : ℕ}

/-- **Occupation measure.** Given an assignment `b : Fin N → Fin K` of each of
    the `N` events to one of the `K` ticks, and event weights `w`, the induced
    tick weight is the total η̃-mass landing on that tick:
    `w♯(k) = Σ_{j : b j = k} w j`. This IS the map "from N to #". -/
noncomputable def occupation (b : Fin N → Fin K) (w : Fin N → ℝ) : Fin K → ℝ :=
  fun k => ∑ j ∈ Finset.univ.filter (fun j => b j = k), w j

/-
**Mass is preserved** by the pushforward: total weight is conserved.
-/
theorem occupation_sum (b : Fin N → Fin K) (w : Fin N → ℝ) :
    ∑ k, occupation b w k = ∑ j, w j := by
  convert Finset.sum_fiberwise Finset.univ b w

/-
A probability measure on events maps to a probability measure on ticks.
-/
theorem occupation_isProb (b : Fin N → Fin K) (w : Fin N → ℝ)
    (hnn : ∀ j, 0 ≤ w j) (h1 : ∑ j, w j = 1) : IsProb (occupation b w) := by
  exact ⟨ fun k => Finset.sum_nonneg fun j _ => hnn j, by rw [ occupation_sum, h1 ] ⟩

/-
**Expectations agree (consistency).** The η̃-weighted average of any
    tick-functional `X` over the `N` events equals its average over the `K`
    ticks under the pushforward weights: `E_w[X∘b] = E_{w♯}[X]`. This is the
    precise sense in which the event-indexed payoff series `{π(Δᵢ(j))}_{j=1}^N`
    and the tick-indexed σ-sum `Σ_{j=1}^{#−1}` compute the same expectation
    once the `N → #` occupation map is applied.
-/
theorem occupation_expectation (b : Fin N → Fin K) (w : Fin N → ℝ) (X : Fin K → ℝ) :
    E w (fun j => X (b j)) = E (occupation b w) X := by
  unfold E occupation;
  simp +decide only [Finset.sum_filter, Finset.sum_mul];
  rw [ Finset.sum_comm, Finset.sum_congr rfl ] ; aesop

/-! ## 4. η̃ is a probability measure on the tick grid; σ is its second moment -/

/-- **Uniform tick measure** `η̃_j = 1/#`, the equal-weight special case of the
    inventory weights. -/
noncomputable def uniform (K : ℕ) : Fin K → ℝ := fun _ => 1 / (K : ℝ)

/-
The uniform tick measure is a probability measure when there is at least
    one tick.
-/
theorem uniform_isProb (K : ℕ) (hK : 0 < K) : IsProb (uniform K) := by
  constructor;
  · exact fun _ => by unfold uniform; positivity;
  · simp +decide [ uniform, Finset.sum_const, nsmul_eq_mul, hK.ne' ]

/-
The model's `sigma_realized` is exactly the **uniform** η̃-expectation of the
    squared deviation over the `#` tick positions — the equal-weight member
    `η̃_j = 1/#` of the spec identity
    `#·σ = Σ_{j=1}^{#−1} η̃_j (i_- + j·Δ̄ᵢ − i_μ)²`.
-/
theorem sigma_realized_eq_uniform_expectation
    (i_minus i_plus i_mu : Int) (Δi : ℝ) :
    CFMM.Eta.sigma_realized i_minus i_plus i_mu Δi
      = E (uniform (CFMM.Eta.sharp i_minus i_plus Δi))
          (fun k : Fin (CFMM.Eta.sharp i_minus i_plus Δi) =>
            ((i_minus : ℝ) + (k : ℝ) * Δi - (i_mu : ℝ)) ^ 2) := by
  by_cases h : Eta.sharp i_minus i_plus Δi = 0 <;> simp_all +decide [ E, uniform ];
  · unfold Eta.sigma_realized; aesop;
  · unfold Eta.sigma_realized; simp +decide [ Finset.mul_sum _ _ _, mul_comm ] ;
    rw [ Finset.sum_range ]

/-- **σ is a variance plus a squared bias (parallel axis).** For any
    tick-probability measure `w` (e.g. the inventory η̃-weights), the spec's
    second moment of the tick about the reference `i_μ` decomposes as the
    η̃-variance of the tick plus the squared distance of the mean tick from
    `i_μ`. This is why σ is genuinely a mean–variance object. -/
theorem sigma_second_moment_decomp (w : Fin K → ℝ) (hw : IsProb w)
    (tick : Fin K → ℝ) (i_mu : ℝ) :
    ∑ k, w k * (tick k - i_mu) ^ 2 = Var w tick + (E w tick - i_mu) ^ 2 :=
  second_moment_decomp w tick hw i_mu

end CFMM.IndexConsistency