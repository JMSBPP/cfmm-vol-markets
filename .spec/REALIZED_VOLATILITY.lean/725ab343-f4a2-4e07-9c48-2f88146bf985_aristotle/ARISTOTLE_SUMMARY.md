# Summary of changes for run 725ab343-f4a2-4e07-9c48-2f88146bf985
I solved the dual problem you posed — find a mapping `g` **and** an inner composition `⊗` for which both conditions hold — in the new file `RequestProject/TickDualMapping.lean`. Everything below compiles and is `sorry`-free.

**Why `ln` had to fail, structurally.** I first proved a rigidity theorem (`affineComposition_rigidity`): if a non-constant `g` satisfies `g(x − y) = c₁·g(x) + c₂·g(y) + c₃`, then necessarily `c₁ = 1`, `c₂ = −1`, `c₃ = g(0)` — the inner composition is *forced* to be subtraction recentred at `g(0)`, and `g` is forced to be additive; under continuity `g` must be affine (`affineComposition_forces_affine`). So inside the additive/affine class of compositions there is no genuine change of variable at all: `ln` was never going to work there, and neither would anything else.

**The dual solution.** Enlarging `⊗` from the additive to the **multiplicative** group solves it. The pair
`g = tickMap β : i ↦ exp(β·i)` with `u ⊗ v = u / v`
satisfies all three requirements simultaneously (`tickMap_isDualSolution`):
- Separability: `g(x − y) = g(x)/g(y)` (`tickMap_separable`);
- Linearity: `ln(g(i)) = β·i` — exactly linear in the tick;
- Injective with recoverable inverse `i = ln(g(i))/β`.
With `β = ln 1.0001` this `g` is precisely the square-root price `√p = 1.0001^i`, so the inner composition is the ratio of square-root prices — increments of ticks become quotients of `√p`.

**The solution is unique.** Any positive solution of the dual requirements equals `exp(β·)` (`dualSolution_unique`); its composition is forced to be division (`isDualSolution_op_eq_div`); and even from separability alone, every positive continuous `g` with `g(x−y) = g(x)/g(y)` is an exponential (`mulSeparable_unique`). Conversely `exp(β·)` admits no affine inner composition for `β ≠ 0` (`tickMap_no_affineComposition`), confirming that leaving the affine class was necessary, not merely convenient.

**Tie-back to your model.** For `σ(i) = exp(α − β·i)`: `ln σ` is affine in the tick with slope `C = −β` (`log_vol_affine`); in the transformed variable the volatility becomes a linear output map, `σ(i) = e^α / g(i)`, i.e. the transformed state is the reciprocal volatility up to scale (`vol_eq_div_tickMap`); and the terminal condition `σ(N) = σ̄` pins the endpoint tick uniquely at `i(N) = (α − ln σ̄)/β`, your formula (`terminal_tick_unique`). Finally, `exp(β·)` is exactly the Lamperti (variance-stabilising) transform of this diffusion coefficient: `Λ(i) = exp(β i − α)/β` satisfies `Λ'(i)·σ(i) = 1` (`lamperti_stabilises_variance`), so in the variable `Λ` the noise enters with a constant coefficient — the state-space form with constant input matrix that the construction was aiming at — and `Λ` is `g` up to an affine normalisation (`lamperti_eq_tickMap`), hence inherits the same multiplicative separability.

The earlier file `RequestProject/TickChangeOfVariable.lean` (the no-go for `ln`) is unchanged apart from a pointer to the new file. Both files build cleanly and all work is committed.