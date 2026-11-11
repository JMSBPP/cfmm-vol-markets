# Summary of changes for run d9917276-397c-415e-bc84-ed728ad72ce5
I restarted the control layer in g-space in the new module `RequestProject/TickGSpaceControl.lean`. It builds cleanly, is sorry-free, and is axiom-clean (only `propext`, `Classical.choice`, `Quot.sound`); the earlier κ/IVT layer in `RequestProject/TickControlLayer.lean` is left untouched and is not used here — in particular nothing in the new module rests on `Classical.choose`.

**State space.** State `x_j = g(i_j) = exp(β i_j)`, output `y_j = ln σ(i_j) = α − ln x_j`, input `u_j = ε_j` (Shape B: the shocks are the exogenous input and are never solved for; every statement is "for an arbitrary fixed ε stream").

**Design of A, B (g-native, multiplicative).** `x_j = A · x_{j−1} · B_j(u_j)` with `B_j(u) = exp(b_j·u)`, where `b` is the deterministic per-step shock log-gain schedule (Lamperti form `b_j = β σ_j √d̄t`, tied in by `gGain` / `stepVol_of_gGain`), and the single drift gain is given in closed form as a log-bridge correction:
`A = exp(lnGainA)`, `lnGainA = ((α − ln σ̄ − β i₀) − Σ_{j=1}^{N} b_j ε_j)/N`.
The shock stream enters only through the explicit finite sum `shockSum`, so A and B are plain arithmetic expressions in `(α, β, σ̄, i₀, N, b, ε)` — cron-computable in one pass.

**What is proved.**
- Well-defined path: `xPath_pos` (the g-state is strictly positive, so `ln` and hence the tick and output are defined at every node) and `xPath_closed_form` (`x_n = x₀·exp(n·lnGainA + Σ_{j≤n} b_j ε_j)`).
- Gain characterisation: `gainA_pow_spec` (`A^N·x₀·exp(Σ b ε) = e^α/σ̄`).
- Lag identity: `gStep_eq` (`g(Δi_j) = A·B_j(ε_j)`) and `xPath_lag_identity` (`x_j = x_{j−1}·g(Δi_j)`), with the induced tick recursion `iPath_succ` and its Euler reading `iPath_euler_step`.
- Terminal pin, in all four forms: `xPath_terminal` (`x_N = e^α/σ̄`), `yOut_terminal` (`y_N = ln σ̄`), `vol_terminal` (`σ(i_N) = σ̄`), `iPath_terminal` (`i_N = (α − ln σ̄)/β`) — for every realized shock stream.
- σ-profile consistency: `vol_eq_expAlpha_div_x` (`σ(i_j) = e^α/x_j`), `yOut_eq` (`y_j = α − β i_j`, output matrix `C = −β`), `yOut_eq_log_vol`, `vol_eq_exp_yOut`, plus `tickMap_iPath` (the change of variable is exact).
- Forge order: `forgeEvaluationOrder` / `forgeEvaluationOrder_spec` package the consumer pipeline ε → (A,B) → {x_j} → {i_j} together with a single statement collecting initialisation, the multiplicative recursion, positivity, `g(i_j) = x_j`, the lag identity, the σ profile and the terminal pin. `exampleParams` witnesses that the parameter hypotheses (β > 0, d̄t > 0, σ̄ > 0, N ≥ 1) are jointly satisfiable, so no statement is vacuous.

The Properties table has been updated with the new g-space definitions and proved properties; all work is committed.

# Summary of changes for run ad1c3b4c-d1bc-49d4-b32a-a568e6d09a44
I added the open-loop base control layer in the new module `RequestProject/TickControlLayer.lean`, building on the existing `g(i) = exp(β i)` / `σ(i) = exp(α − β i)` results (the affine ⊗ no-go was not reopened). Everything compiles and is sorry-free and axiom-clean (only `propext`, `Classical.choice`, `Quot.sound`).

What is in the module:

- **Recursion.** `tickRec D S ε i0 κ`: the diffusion-shaped Euler scheme `i_j = i_{j-1} + κ·D(i_{j-1}) + S(i_{j-1})·ε_j`, with `D` the md drift increment `(d̄t/β)·μ(i)` (`modelMu`, `tickDrift`, where `μ(i) = μ_F/(L√p) − σ_F²/(2L²p)` and `√p = exp(β i)`) and `S` the diffusion increment `σ(i)·√d̄t` (`tickDiff`). The shock stream `{ε_j}` is an arbitrary fixed exogenous sequence throughout — it is never solved for or refit. `tickRec_unique_path` characterises the path, `tickRec_continuous` gives continuity of the endpoint map in `κ`.
- **One-parameter drift family / profile preservation.** Only `κ` multiplies the drift; `tickRec_diffusion_profile` and `forgePath_diffusion_coeff` show the shock at each step enters with coefficient exactly `σ(i_{j-1})·√d̄t = exp(α − β i_{j-1})·√d̄t`, so the volatility profile is untouched by the control.
- **Existence of κ\*.** `exists_kappa_of_bounds`: for any fixed `{ε_j}`, when the drift increment is bounded below by a positive constant and the diffusion increment is bounded, there is a `κ*` with `i_N = i(N)`; it is located inside the explicit bracket `[kappaLower, kappaUpper]` computed in closed form from the shock stream (so bisection finds it), the two-sided bounds `tickRec_lower_bound` / `tickRec_upper_bound` supplying the bracket and the intermediate value theorem the root. `exists_kappa_model` instantiates this for the md coefficients on the tick bucket `[i_l, i_u]` (coefficients evaluated at the bucket-clamped state, agreeing with the model ones inside the bucket), under `β > 0`, `d̄t > 0`, `N ≥ 1` and the condition that the flow drift dominates the convexity correction at the lower tick.
- **Uniqueness.** `tickRec_endpoint_strictMono` / `kappa_unique`: with a strictly positive drift increment and the step-size condition that each Euler step is nondecreasing in the state, `κ ↦ i_N(κ)` is strictly increasing, hence `κ*` is unique.
- **Forge schedule.** `ForgeParams` bundles the parameters, `iN = (α − ln σ̄)/β` is the terminal tick pinned by the target, `kappaStar` is `κ*`, `forgePath` the emitted tick history; `forgePath_vol_terminal` proves `σ(i_N) = σ̄`. `forgeEvaluationOrder` and `forgeEvaluationOrder_spec` package the consumer's order — obtain `ε` → solve `κ*` → emit `{i_j}` — together with the proof that the emitted history starts at `i(0)`, follows the recursion under the given shocks, and realizes `σ̄`. `exampleParams` witnesses that the parameter hypotheses are jointly satisfiable, so none of the statements is vacuous.

The Properties table has been updated with these deliverables; all listed properties are proved. Work is committed.

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