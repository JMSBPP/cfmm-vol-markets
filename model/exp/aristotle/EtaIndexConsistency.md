# The `N → #` index mapping: meaning, economics, and consistency

*Companion to `exp/EtaIndexConsistency.lean`. Every claim below is backed by a
machine-checked Lean theorem; the Lean name is given in `code font`. The
mean–variance `MV_γ[·]` layer is deliberately **out of scope** here (per the
request — "ignore what is under MV()"); we only check that the **dynamics
section** is internally consistent and explain what the `N → #` mapping must be.*

---

## The question

In the *DYNAMICS* block you have, after `N` events/agents:

* a tick sequence `{i_j}_{j=1}^N` with `i_j = i_μ + α_j·Δᵢ`, all `i_j ∈ [i_-, i_+]`;
* the implied state-partition delta `Δᵢ(j) = (i_j − i_μ)/α_j`;
* a payoff series `{π(Δᵢ(j))}_{j=1}^N`;
* inventory weights `{η̃_j}`.

But the weights `η̃` and the dispersion `σ` were defined as sums **over the tick
grid**, `Σ_{j=1}^{#_{Δ̄ᵢ}−1}`. The event index `j = 1,…,N` and the grid index
`j = 1,…,#−1` are *different index sets*. For `E^{η̃}[π] = Σ_j η̃_j π_j` to even
type-check, "there must be a mapping from `N` to `#`." What is it, what does it
mean economically, and is the dynamics section correct?

## Short answer

**The dynamics section is correct.** The only thing it leaves implicit is the
identification of the two index sets, and that identification is forced to be the
**occupation (pushforward) measure** of agents onto ticks. The number that
governs the η̃-measure is the tick count `K = #_{Δ̄ᵢ} − 1` (the admissible
*interior* ticks of `[i_-, i_+]` at spacing `Δ̄ᵢ`), **not** the raw event count
`N`. A one-to-one event↔tick relabelling is consistent only in the knife-edge
case `N = #−1`; in general the consistent object is the occupation map, which
conserves both probability mass and expectations.

---

## 1. The dynamics algebra is internally consistent

The entry law and the implied-spacing read-off are *exact inverses* for any
nonzero step count `α_j`:

* `impliedDelta_entry` : `Δᵢ( i_μ + α·Δᵢ ) = Δᵢ` (you recover the spacing you put in);
* `entry_impliedDelta` : `i_μ + α·Δᵢ(j) = i_j` (you recover the tick you observed).

So `Δᵢ(j) = (i_j − i_μ)/α_j` is a well-defined per-event observable, and the
payoff series `{π(Δᵢ(j))}` is well-posed. No inconsistency here — provided
`α_j ≠ 0`, i.e. each agent actually moves off `i_μ` by an integer number of ticks.

## 2. Why an index map is *needed*, and when a bijection works

The σ / η̃ objects live on the **tick grid**, not on event-time. The spec sum
`Σ_{j=1}^{#−1}` runs over the `# − 1` *interior* tick positions:

* `interior_tick_count` : `|{1,…,#−1}| = # − 1`.

A literal one-to-one relabelling of the `N` events by the `K` ticks (a bijection
`Fin N ≃ Fin K`) exists **iff** the two counts coincide:

* `event_tick_bijection_iff` : `Nonempty (Fin N ≃ Fin K) ↔ N = K`.

So a direct event↔tick indexing is only consistent in the special case
`N = #_{Δ̄ᵢ} − 1`. Economically: exactly one agent per admissible interior tick.
That is the "clean" regime, but it is not generic.

## 3. The generic, economically meaningful map: occupation measure

For `N ≠ #−1` the right object is not a bijection but the **occupation /
pushforward measure**. Assign each event to the tick it occupies,
`b : Fin N → Fin K`, and push its η̃-mass onto that tick:

```
w♯(k) = Σ_{j : b j = k} w_j           -- `occupation`
```

This is *the* mapping "from `N` to `#`", and it is consistent in the strongest
possible sense:

* `occupation_sum` : `Σ_k w♯(k) = Σ_j w_j` — total mass is conserved;
* `occupation_isProb` : a probability measure on events ↦ a probability measure
  on ticks (so `Σ_j η̃_j = 1` over events becomes `Σ_k η̃♯_k = 1` over ticks —
  the spec's "by construction `Σ η̃ = 1`" survives the remap);
* `occupation_expectation` : `E_w[X ∘ b] = E_{w♯}[X]` — **expectations are
  invariant** under the remap.

The last identity is the precise statement that the event-indexed series
`{π(Δᵢ(j))}_{j=1}^N` and the grid sum `Σ_{j=1}^{#−1}` compute the **same**
η̃-expectation. Consistency of the dynamics = mass/expectation conservation under
the occupation map, which always holds.

**Economic reading.** `w♯` is the empirical *occupation distribution* of agents
across the price-tick lattice — how the `N` order-flow events pile up on the
`#−1` admissible ticks of `[i_-, i_+]`. The economically meaningful indexing is
therefore **by tick coordinate** (distance from `i_-`), not by chronological
event order:

* The state space dimension is `K = #_{Δ̄ᵢ} − 1`, fixed by the geometry
  (`i_-, i_+, Δ̄ᵢ`) via `#_{Δ̄ᵢ} = ⌊(i_+ − i_-)/Δ̄ᵢ⌋` (the repo's `sharp`), and
  **independent of how many agents `N` arrive**.
* More agents than ticks (`N > #−1`) ⇒ several events share a tick; their masses
  *add* (`occupation`), giving a heavier η̃-weight on busy ticks.
* Fewer agents than ticks (`N < #−1`) ⇒ some ticks get `η̃♯_k = 0`; they drop
  out of the σ-sum with no inconsistency.
* The chronological label `j` of an event is economically irrelevant for σ and
  the η̃-expectation; only *which tick* it lands on matters. This is exactly why
  the spec can freely reuse the symbol `j` for both the event and the tick index:
  the consistent bridge between them is the occupation map.

**Constraint check.** All `i_j ∈ [i_-, i_+]` ⇒ `b` indeed lands in the `#−1`
interior ticks (its codomain). `i_j = i_μ + α_j·Δᵢ` with integer `α_j` ⇒ events
sit on the `Δᵢ`-lattice through `i_μ`; for them to coincide with the `Δ̄ᵢ`-grid
of the σ-sum one needs `Δᵢ` and `Δ̄ᵢ` to be commensurable through `i_μ` — when
`Δᵢ = Δ̄ᵢ` the two lattices agree and the occupation map is the identity binning.

## 4. σ is itself a tick-probability second moment

This closes the loop with the σ definition that motivated the question:

* `sigma_realized_eq_uniform_expectation` : the model's `sigma_realized` is
  exactly the **uniform** η̃-expectation `E_{1/#}[(i_- + k·Δᵢ − i_μ)²]` over the
  `#` ticks — i.e. the equal-weight member `η̃_j = 1/#` of the spec identity
  `#·σ = Σ_{j=1}^{#−1} η̃_j (i_- + j·Δ̄ᵢ − i_μ)²`.
* `sigma_second_moment_decomp` : for **any** tick measure `w` (e.g. the inventory
  η̃-weights), the second moment about `i_μ` splits as
  `Σ_k w_k (tick_k − i_μ)² = Var_w[tick] + (E_w[tick] − i_μ)²`
  (parallel-axis / bias–variance). So σ is genuinely a mean–variance object: a
  tick-variance plus the squared bias of the mean tick from the reference `i_μ`.

Hence the η̃-weighted payoff/dispersion machinery is consistent precisely because
σ, η̃ and the payoff series are all functionals of the **same** tick-probability
measure; the occupation map is what transports that measure between the
event index `1,…,N` and the tick index `1,…,#−1`.

---

## Theorem index

| Claim | Lean name |
|---|---|
| implied spacing inverts the entry law | `impliedDelta_entry`, `entry_impliedDelta` |
| number of interior ticks is `#−1` | `interior_tick_count` |
| event↔tick bijection ⇔ `N = #−1` | `event_tick_bijection_iff` |
| occupation map (the `N → #` mapping) | `occupation` |
| mass conserved | `occupation_sum` |
| probability ↦ probability | `occupation_isProb` |
| expectation conserved (consistency) | `occupation_expectation` |
| uniform tick measure is a probability | `uniform_isProb` |
| `sigma_realized` = uniform tick expectation | `sigma_realized_eq_uniform_expectation` |
| σ = variance + squared bias | `sigma_second_moment_decomp` |

All theorems compile with no `sorry` and depend only on the standard axioms
(`propext`, `Classical.choice`, `Quot.sound`). Build target:
`exp.EtaIndexConsistency` (registered in `lakefile.toml`).
