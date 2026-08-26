# TOOLING — Control-Theory Modeling Language / Toolchain Selection

> **Generated:** 2026-06-28 · **Mode:** READ-ONLY tooling assessment (no implementation).
> **Question:** what is the off-chain control-design analog of *GAMS* (optimization)
> and *Lean* (proof) for this project's **static control kernel** — closed-form
> algebraic inversion (pick `Δi`, and where needed `η/ξ/ι`, to hit a kernel-level
> target such as cross-sectional vol `σ_target`) indexed over a discrete tick /
> binomial lattice, with the designed law exported to **fixed-point EVM** (Plank/
> Solidity, WAD 1e18, Q64.96)?
> **Companion docs:** `MAPPING-SYNTHESIS.md` (in-scope object = static kernel),
> `EVM-CONTROL-PRIMITIVES-MAP.md` (on-chain primitive reality).

---

## 0. The decision frame (what the tool actually has to do here)

Two facts from the companion maps drive everything:

1. **The in-scope "controller" is algebra, not a dynamical loop.** Per the
   `MAPPING-SYNTHESIS.md` scope correction, this milestone is the *static* kernel:
   closed-form inversions already proven in `lean/exp/eta.lean`
   (`sigma_xs_poly_target_exists`, `eta_pi_trader_zero_slippage`, …). The tool's
   job is to **derive / re-derive / verify those closed forms and emit their
   constants** — not to run an MPC or simulate a feedback loop. The dynamic /
   DP-on-lattice layer (`inf_Θ d(π,Υ^φ)`) is explicitly deferred.

2. **The EVM cannot solve — only evaluate.** Per `EVM-CONTROL-PRIMITIVES-MAP.md §3–4`:
   Plank's only numeric type is `u256`; there is `mulDiv` (512-bit) and Q96 tick
   math, but **no matrix type, no inverse/solve, no signed fixed-point mul/div, no
   saturation, no WAD `exp/ln`**. The hard rule is *"design `A,B,K` off-chain;
   the chain evaluates `K·x` + saturating update."* So requirement R3 is **not**
   "generate Solidity" — no tool does that natively — it is *"produce verified
   constants / gain matrices in a form that quantizes cleanly to WAD/Q64.96."*

**Consequence that decides the ranking:** the binding requirement is a **CAS that
does exact set-point inversion and carries exact rationals** (so quantization to
WAD 1e18 / Q64.96 is deterministic and auditable, like the GDX→fixture→`gamsdiff`
pattern this repo already runs at EPS≈1e-15), **scriptable from the existing
Python/`uv` + Make + Lean + Foundry CLI**. Heavy continuous-time control toolboxes
score *lower* here, not higher, because the in-scope object is static algebra.

The AMM control literature corroborates the shape: optimal dynamic-fee problems
admit **approximate closed-form solutions** and **collapse to a static constant
when volatility is constant** (Baggiani–Herdegen–Sánchez-Betancourt 2025,
arXiv:2506.02869; Ghasemlu 2026, arXiv:2606.21769; Campbell–Bergault–Milionis–Nutz
2025, arXiv:2508.08152) — i.e. the off-chain tool must do closed-form algebra +
a finite-difference/numeric cross-check, not on-chain optimization.

### Requirement weights (justified)

| # | Requirement | Weight | Why this weight |
|---|-------------|:------:|-----------------|
| R1 | Static / algebraic / matrix + set-point inversion **and** discrete lattice / DP indexing | 0.25 | The actual object. Continuous-only transfer-function tools partially miss it. |
| R2 | Symbolic (derive/verify closed forms) **and** numeric simulation | 0.25 | Symbolic is the GAMS/Lean analog; numeric is the cross-check oracle. |
| R3 | Path to fixed-point, EVM-implementable export (constants/gains, ideally codegen) | 0.20 | No tool emits Solidity; differentiator is *exact-rational → clean quantization*. |
| R4 | Open-source (proprietary = fallback only) | 0.15 | Project policy: avoid proprietary lock-in. |
| R5 | Composes with GAMS + Lean + Foundry/Plank, reproducible CLI | 0.15 | Must drop into the `uv`/Make/forge pipeline without a new runtime tax. |

Scores are 0–5 per requirement; weighted total = Σ(score·weight).

---

## 1. Comparison table (verified June 2026)

| Candidate | License | R1 static+lattice | R2 symbolic+numeric | R3 fixed-point export | R4 OSS | R5 pipeline fit | **Weighted** |
|-----------|---------|:---:|:---:|:---:|:---:|:---:|:---:|
| **SymPy** | BSD-3 | 4 | 5 | 4 | 5 | 5 | **4.55** |
| **Julia: Symbolics.jl + ControlSystems.jl** | MIT | 4 | 4.5 | 4 | 5 | 3.5 | **4.20** |
| ModelingToolkit.jl (SciML) | MIT | 3.5 | 4.5 | 4 | 5 | 3.5 | 4.08 |
| **Maxima** | GPL | 4.5 | 4 | 3.5 | 4.5 | 3.5 | 4.03 |
| Mathematica + System Modeler *(proprietary)* | Proprietary | 5 | 5 | 4 | 1 | 3 | 3.90 |
| Drake (RobotLocomotion) | BSD-3 | 4.5 | 3.5 | 3 | 5 | 3 | 3.80 |
| MATLAB + Simulink + Fixed-Point Designer *(proprietary)* | Proprietary | 4.5 | 4 | **5** | 1 | 3 | 3.78 |
| CVXPY (+ cvxpygen / cvxpylayers) | Apache-2.0 | 3 | 2.5 | 3 | 5 | 4.5 | 3.40 |
| python-control | BSD-3 | 2.5 | 2 | 2 | 5 | 4.5 | 2.95 |
| OpenModelica | GPLv3 / OSMC-PL | 2.5 | 3 | 2.5 | 3.5 | 3 | 2.85 |

**Maturity snapshot (all verified active in 2025–2026):** SymPy 1.14.0 (2025-04);
Symbolics.jl 7.29 / ControlSystems.jl 1.15.5 / ModelingToolkit 1.45 (all 2026-06);
Maxima 5.49 (2025); Drake v1.54 (2026-06); CVXPY 1.9.1 / cvxpygen 1.0 (2026-05);
python-control 0.10.2 (2025-07); OpenModelica 1.26 (2025-10); Mathematica 14.3 (2025-08).

**Universal caveat (drives R3 everywhere):** *no* candidate emits integer/fixed-point
or Solidity natively. Every one can only **export off-chain-computed constants /
gain matrices**; the float→WAD 1e18 / Q64.96 scaling and Plank/Solidity emission is
custom work in all cases. The *only* ecosystem with genuine native fixed-point
codegen is **MATLAB Fixed-Point Designer / HDL Coder — and it is proprietary**, so
it stays a fallback. The differentiator among the open-source tools is therefore
*how cleanly the symbolic layer hands you exact constants to quantize*: SymPy's
`Rational`/`nsimplify` and Maxima's exact arithmetic are the strongest there.

---

## 2. Per-candidate notes (strengths / weaknesses vs the 5 requirements)

### SymPy — BSD-3 · **rank 1**
- **What:** pure-Python CAS — `solve/solveset/linsolve/nonlinsolve`, symbolic
  `Matrix`, `summation`, `cse` (common-subexpression elimination), `ccode`/`codegen`/`lambdify`.
- **R1:** set-point inversion is its sweet spot — `solve` reproduces the
  `sigma_xs_poly_target` quadratic-root closed form directly; lattice expressions
  via `summation`/symbolic Bellman recursions written by hand. **Weakness:**
  built-in *discrete-time control* (Z-transform/Jury) is a 2025 GSoC WIP, and there
  is no DP/value-iteration primitive — irrelevant for the static kernel, relevant
  only if/when the deferred dynamic layer arrives.
- **R2:** full CAS + numeric via `lambdify`→NumPy. **R3:** exact `Rational`
  arithmetic → deterministic WAD/Q64.96 quantization; `cse`+`ccode` give an
  auditable constant/kernel emit (the most controllable float→fixed path). No
  Solidity target. **R4:** BSD. **R5:** best — already wired into this repo via the
  `sympy` MCP server and the `uv` workflow; trivially scriptable headless.

### Julia: Symbolics.jl + ControlSystems.jl — MIT · **rank 2**
- **What:** Symbolics.jl is a modern CAS (`symbolic_solve`: exact roots ≤ deg 4 +
  factoring, multivariate via Gröbner, transcendental via `ia_solve`);
  ControlSystems.jl is the de-facto open-source control toolbox (discrete `ss`,
  `c2d`, `lqr` → **constant gain matrix `K`** for `u[k]=−K x[k]`).
- **R1:** strong — genuine *control toolchain* identity (the open-source
  MATLAB-Control-Toolbox analog), discrete state-feedback + constant-gain matrices
  natural; no native DP/lattice solver. **R2:** Symbolics CAS slightly less general
  than SymPy on messy transcendental solve, but `build_function` is a real
  advantage. **R3 (key differentiator):** `build_function` emits **C (`CTarget`)**
  and Julia — a ready **reference oracle** for differential testing against the
  on-chain Plank, fitting this repo's `gamsdiff` pattern; still float, no
  fixed-point. **R4:** MIT. **R5:** weaker — adds a *new language runtime* to a
  Python/GAMS/Lean repo; reproducible via `Project.toml`/`Manifest.toml`, file/CLI
  bridge only.
- *RobustAndOptimalControl.jl (MIT)* and *ModelingToolkit.jl (MIT)* are
  extensions of this stack (H∞/LQG; acausal DAE modeling) — **overkill for a static
  algebraic kernel**; reach for MTK only if the kernel grows into a simulated
  dynamical model.

### Maxima — GPL · standalone-CAS alternative
- The cleanest *standalone* GAMS-analog: `maxima -b script.mac` batch CLI, exact
  symbolic `solve`/`linsolve`, symbolic matrices, and **`solve_rec` for
  recurrence/difference equations** — the standout for **discrete tick/binomial-
  lattice and DP-style recursions** (R1 best-in-class among OSS). Weakness: numeric
  *simulation* is weak (it is a CAS, not a sim env), codegen is Fortran/C via
  `gentran` (float, no fixed-point), and it is a separate Lisp tool outside the
  Python pipeline (R5). GPL is permissive enough for constant export (no FMU-style
  artifact copyleft). *Note: confirm `solve_rec` against the v5.49 manual before
  committing to lattice-DP derivations — the 2025 docs page was not surfaced live.*

### Drake — BSD-3 · DP/lattice specialist
- The **only** candidate with built-in **dynamic programming**: `FittedValueIteration`
  (barycentric-mesh, infinite-horizon Bellman) + a real `drake::symbolic` engine
  and `MathematicalProgram` (LP/QP/SOCP/SDP/SOS). Directly relevant to the
  *deferred* discrete-lattice value-iteration layer, not the static kernel.
  Weaknesses: heavyweight C++/`pydrake` install, no fixed-point/Solidity export,
  symbolic engine is not a general CAS. **Park it for the dynamic layer.**

### CVXPY (+ cvxpygen, cvxpylayers) — Apache-2.0 · optimization-DSL niche
- Use only when a gain/`Δi` is the **argmin of a convex design problem** (e.g.
  minimize vol-target error s.t. feasibility); it *solves*, it does not derive
  closed forms (R2 low). `cvxpygen` emits embedded **C** (float, not EVM); export
  numeric constants only. Python/`uv`-native (R5 good).

### python-control — BSD-3 · low fit
- MATLAB-style numeric LTI (state-space/freq, LQR, `dlqr`, `c2d`). Numeric only,
  no CAS, no codegen, continuous-transfer-function leaning — little for static
  algebraic inversion over a tick lattice or fixed-point export. Lowest fit.

### OpenModelica — GPLv3 / OSMC-PL · numeric-sim complement
- Equation-based acausal DAE modeling + strong numeric simulation (`omc script.mos`
  CLI, C codegen, FMU export). **Not a general CAS** — won't hand you an arbitrary
  closed-form inverse. Best as a *validation/simulation oracle*, not the derivation
  engine. **Copyleft flag:** exported Co-Sim FMUs carry GPL3/OSMC-PL on some
  generated source (OpenModelica issue #9197) — matters if artifacts ship.

### Mathematica / MATLAB — proprietary · FALLBACK ONLY
- **Mathematica + System Modeler** (v14.3): most capable single stack — full CAS,
  `Solve`/`RSolve` (recurrences/lattice), discrete `StateSpaceModel`,
  `CCodeGenerator` C emit. **Proprietary EULA → cross-check oracle only.**
- **MATLAB + Simulink + Fixed-Point Designer / HDL Coder:** the *only* ecosystem
  with **native fixed-point codegen** (R3=5) — the one genuine technical edge — but
  **proprietary**; flag as fallback if the manual WAD/Q64.96 emit ever becomes the
  bottleneck. Not recommended given project policy.

---

## 3. Ranked recommendation

### 🥇 Primary: **SymPy** (BSD-3) — for the in-scope static kernel
It is the closest fit to *this milestone's* object: closed-form set-point
inversion is exactly `solve`/`solveset`, exact `Rational` arithmetic makes the
WAD 1e18 / Q64.96 quantization deterministic and reviewable, `cse`+`ccode` give an
auditable constant/kernel export, and **it is already integrated** (the `sympy`
MCP server + `uv`), so it adds zero new runtime to the GAMS+Lean+Foundry pipeline.
It plays the GAMS-role (algebraic derivation) while **Lean stays the proof
authority** — SymPy gives CAS-level *computational* verification of the same
closed forms Lean proves, not a competing proof.

### 🥈 Secondary / co-primary: **Julia Symbolics.jl + ControlSystems.jl** (MIT)
Adopt this when the work acquires a genuine *control* shape — discrete
state-feedback, constant-gain matrices `K` from `lqr`/`place`, or a need for a
**C reference oracle** via `build_function` to differential-test against the
on-chain Plank (mirrors the existing `gamsdiff` fixtures). It is the real
open-source analog of the MATLAB Control System Toolbox, fully MIT, and its codegen
story for the float reference is stronger than SymPy's. Cost: a new language
runtime in the repo — justified only once constant-gain/state-space design (not
pure scalar inversion) is on the table.

**Specialists to keep on the bench (not now):** **Drake** (`FittedValueIteration`)
or **Maxima** (`solve_rec`) for the *deferred* DP-on-lattice dynamic layer;
**Mathematica/MATLAB** as proprietary cross-check / fixed-point-codegen fallback
only.

---

## 4. How it slots into the GAMS + Lean + Plank pipeline

```
                 design / derive                verify                 realize
  ┌──────────────┐   closed form    ┌──────────────┐  exact   ┌──────────────────┐
  │  SymPy        │  solve(σ_xs =    │  Lean         │  match   │  Plank / Solidity │
  │ (off-chain    │  σ_target → Δi⋆) │ eta.lean      │  proof   │  src/*.plk        │
  │  CAS, role of │  ───────────────▶│ (proof        │ ◀──────▶ │  mulDiv + Q96     │
  │  GAMS algebra)│  Rational consts │  authority)   │          │  (evaluator only) │
  └──────┬────────┘                  └──────────────┘          └─────────▲────────┘
         │ cse + ccode / Rational→WAD,Q64.96 quantization                │
         │ emit constants + (optional) C/Julia reference oracle          │ differential
         ▼                                                               │ test (EPS≈1e-15)
  ┌─────────────────────────────────────────────────────────────────────┴──────────┐
  │  test/gamsDiff-style fixtures: {inputs, SymPy/Julia reference outputs} as JSON/CSV │
  │  forge --via-ir runs the Plank impl over the same inputs, compares to tolerance   │
  └───────────────────────────────────────────────────────────────────────────────────┘
```

Concrete workflow (mirrors the existing `make gams-fixtures` / `gamsdiff` step):
1. **Derive** in a `uv run` SymPy script: solve the kernel inversion symbolically,
   keep results as exact `Rational` (e.g. `Δi⋆(n,d,σ_target)`).
2. **Cross-check against Lean:** the closed form must equal the proven
   `lean/exp/eta.lean` statement — SymPy is the computational check, Lean the proof.
   (GAMS remains the numeric optimization/ground-truth side where a problem is an
   actual optimization rather than an inversion.)
3. **Quantize** the constants to WAD 1e18 / Q64.96 deterministically from the
   exact rationals; emit a constant-gain / parameter table + a fixture file.
4. **Realize on-chain:** Plank evaluates the closed form / `K·x` with `mulDiv`,
   the hand-written signed-fixed `mulDiv` and saturating-clamp helpers flagged in
   `EVM-CONTROL-PRIMITIVES-MAP.md §3` (controller must *saturate, never revert*).
5. **Differentially test:** drop the SymPy (or Julia `build_function` C) reference
   values into a `gamsDiff`-style fixture and diff the Plank output under
   `forge --via-ir` at the project's EPS tolerance.

This keeps the toolchain coherent: **GAMS = numeric optimization ground truth,
Lean = machine-checked proof, SymPy = algebraic design + reference oracle, Plank =
fixed-point evaluator** — with Julia/Symbolics as the upgrade path when the design
becomes matrix/state-space and a compiled C reference oracle is wanted.

---

## 5. Sources
- SymPy: https://github.com/sympy/sympy · control LTI https://docs.sympy.org/latest/modules/physics/control/lti.html
- Symbolics.jl: https://github.com/JuliaSymbolics/Symbolics.jl · build_function https://docs.sciml.ai/Symbolics/stable/manual/build_function/ · solver https://docs.sciml.ai/Symbolics/stable/manual/solver/
- ControlSystems.jl: https://github.com/JuliaControl/ControlSystems.jl · RobustAndOptimalControl.jl https://github.com/JuliaControl/RobustAndOptimalControl.jl · ModelingToolkit.jl https://github.com/SciML/ModelingToolkit.jl
- Maxima: https://maxima.sourceforge.io/docs/manual/Matrices-and-Linear-Algebra.html · https://sourceforge.net/projects/maxima/
- Drake: https://github.com/RobotLocomotion/drake · controllers https://drake.mit.edu/pydrake/pydrake.systems.controllers.html
- CVXPY: https://github.com/cvxpy/cvxpy · cvxpygen https://github.com/cvxgrp/cvxpygen · cvxpylayers https://github.com/cvxpy/cvxpylayers
- python-control: https://github.com/python-control/python-control
- OpenModelica: https://openmodelica.org/useresresources/license/ · FMU-GPL https://github.com/OpenModelica/OpenModelica/issues/9197
- Mathematica/Wolfram: https://www.wolfram.com/language/core-areas/controls/ · CCodeGenerator https://reference.wolfram.com/language/CCodeGenerator/tutorial/CodeGeneration.html
- AMM control literature: arXiv:2506.02869 (Optimal Dynamic Fees in AMMs), arXiv:2606.21769 (Stochastic-control LVR fees), arXiv:2508.08152 (Optimal Fees for Liquidity Provision)
```
