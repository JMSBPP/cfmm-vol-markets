# LIT-LATTICE-CONTROL — Theory survey: static control on a discrete tick / binomial lattice

> Produced 2026-06-28 (read-only research artifact). Companion to `MAPPING-SYNTHESIS.md`,
> `LEAN-MAP.md`, `GAMS-MAP.md` in this directory.
>
> **Framing being served.** We design a *controller that runs statically over a discrete
> tick lattice*. The recursion / iteration index is a **spatial discrete coordinate** — the
> tick index `i ∈ [−120, 120]`, spacing `Δi` — **not time**. "Dynamic over the lattice, not
> over time." The market state space is a **binomial (recombining) lattice** (±1 tick moves;
> CRR option-pricing lattice). Every controller object must be **EVM-computable**: algebraic,
> matrix-expressible, fixed-point — **no on-chain iterative solver, no float pow/log, no NLP**.
> The proven static inversions (`lean/exp/eta.lean`: `sigma_xs_poly_target_exists`,
> `deltaI_star`, `eta_split_kernel_identity`, …) are the per-position set-point maps this
> literature is meant to *frame*, not replace.
>
> **Sourcing note.** arXiv (arxiv MCP) was primary. Classic results that predate or sit
> outside arXiv (CRR, Bamieh–Paganini–Dahleh, D'Andrea–Dullerud, Carr–Madan,
> Breeden–Litzenberger) are cited as journal/textbook references with **no fabricated arXiv
> ids**. Full text was read for the static-replication paper (1406.5430); ar5iv HTML
> conversion failed for 2509.09269 and 2403.14231, so those rest on their (detailed)
> abstracts plus the canonical literature they extend.

---

## Top 3 must-reads

1. **Bamieh, Paganini & Dahleh (2002), *Distributed control of spatially invariant
   systems*** (classic) — paired with the modern computational instance **Ballotta,
   Arbelaiz, Gupta, Schenato & Jovanović, arXiv:2509.09269 (2025)**. This is the single
   closest formalism: a system indexed by a spatial coordinate whose optimal feedback is a
   *function over space*, made **block-diagonal by the spatial Fourier transform** — exactly
   our "feedback as a function of tick index `i`, decoupled per spatial frequency."

2. **Carr & Madan (2001), *Optimal positioning in derivative securities*** +
   **Breeden & Litzenberger (1978)** (classic) — paired with **Bossu, Crépey & Nguyen,
   arXiv:2403.14231, *Spanning Multi-Asset Payoffs With ReLUs* (2024)**. Static spanning of a
   target payoff by a continuum/grid of options = the **payoff-replication reading of static
   control**; ReLU (piecewise-linear) bases on a strike grid are literally our tick lattice.

3. **Cox, Ross & Rubinstein (1979), *Option pricing: a simplified approach*** (classic) —
   the **binomial recombining lattice** and **backward induction** as a controlled recursion
   over a spatial (price) coordinate. Defines the state space the controller lives on.

---

## Curated entries

### A. Spatially-distributed / spatially-invariant systems control (the core analogy)

**A1. Distributed control of spatially invariant systems**
Bashir Bamieh, Fernando Paganini, Munther A. Dahleh. *IEEE Trans. Automatic Control* 47(7),
1091–1107 (2002). [classic — not on arXiv]
- Systems whose dynamics commute with spatial shifts (here: shifts along the tick index).
  The spatial Fourier transform block-diagonalizes the operator, so an LQR/H₂/H∞ problem
  over the whole spatial domain *decouples into an independent finite-dimensional problem at
  each spatial wavenumber `θ`*. The optimal controller is the inverse transform of the
  per-wavenumber gains → a **convolution kernel over space whose taps decay exponentially
  with spatial distance** ("inherent degree of decentralization").
- **Grounds our lattice controller.** The tick lattice `i ∈ [−120,120]` is the spatial axis.
  A shift-invariant control law is a fixed **Toeplitz/banded gain matrix** `u = −K x`,
  `K[i,j] = κ(i−j)`, computed off-chain per-wavenumber and applied on-chain as one
  banded matrix–vector product (cheap, no solver). Exponential tap decay justifies
  truncating to a small `n ≤ 3–4` band — the very on-chain budget in `MAPPING-SYNTHESIS.md`.
  This is the formalism that makes "dynamic over the lattice, not over time" rigorous.

**A2. The role of communication delays in the optimal control of spatially invariant
systems** — arXiv:2509.09269 (2025)
Luca Ballotta, Juncal Arbelaiz, Vijay Gupta, Luca Schenato, Mihailo R. Jovanović.
- Modern, explicit instance of A1: optimal **proportional (static) feedback** for spatially
  invariant systems, decoupled in the spatial frequency domain. Gives **closed-form optimal
  gains in two tractable limits** — *expensive control* (gain factors into a filter of the
  state + the delay-free optimal gain) and *small delay* (gain is a linear perturbation of
  the delay-free gain). Explicitly studies how gains lose/keep **spatial locality** and
  treats the **multi-agent case coupled through circulant matrices**.
- **Grounds our lattice controller.** The "expensive-control" and "small-perturbation"
  closed forms are exactly the regime where the gain reduces to a precomputable, banded
  spatial kernel — EVM-portable. The **circulant** coupling matches a periodic/wrapped tick
  grid; circulants are diagonalized by the DFT, so the per-tick gain is a one-shot algebraic
  map. Best modern reference for "static feedback as a function over the lattice, in
  closed form."

**A3. Distributed control design for spatially interconnected systems**
Raffaello D'Andrea, Geir E. Dullerud. *IEEE Trans. Automatic Control* 48(9), 1478–1495
(2003). [classic — not on arXiv]
- Companion to A1 for *heterogeneous / finite-extent* spatial interconnections (not pure
  shift-invariance): well-posedness, stability and performance reduce to **LMIs with the
  same banded sparsity as the spatial interconnection**; the controller inherits the
  structure of the plant (each site talks only to neighbors).
- **Grounds our lattice controller.** Our tick grid is *finite* (`[−120,120]`) with boundary
  ticks, so it is interconnected rather than perfectly shift-invariant. A3 is the recipe for
  a **per-tick gain with explicit nearest-neighbor sparsity** and an off-chain LMI feasibility
  check — the gain matrix is then a fixed banded operator the EVM just multiplies by.

**A4. H₂-Optimal Decentralized Control over Posets: a state-space solution for
state-feedback** — arXiv:1111.1498 (2011)
Parikshit Shah, Pablo A. Parrilo.
- When the information/coupling structure is a **partial order (poset = lattice in the
  order-theoretic sense)**, the H₂-optimal decentralized controller is obtained by solving a
  **small number of *uncoupled* standard Riccati equations**, one per poset element, with
  controller pieces living in the **incidence algebra** of the poset (a pair of
  mutually-inverse transfer functions encoding state prediction along order paths).
- **Grounds our lattice controller.** This is the literal realization of "algebraic Riccati /
  fixed-gain laws *indexed by lattice position* rather than by time-step." If we read the tick
  order (or the up/down binomial order) as a poset, the controller becomes a handful of
  **precomputed constant gains keyed by position** — assembled off-chain, evaluated on-chain
  with no solve. Tightest match to the "Riccati-indexed-by-lattice-position" anchor question.

**A5. Convex reformulation of LMI-based distributed controller design with non-block-diagonal
Lyapunov functions** — arXiv:2404.04576 (2024)
Yuto Watanabe, Sotaro Fushimi, Kazunori Sakurama.
- Synthesizes **state-feedback gains with a prescribed sparsity pattern** (graph structure);
  when the pattern is **chordal** the LMI relaxation is necessary-and-sufficient (exact). Gives
  a constructive off-chain route to a structured gain.
- **Grounds our lattice controller.** The path-graph of the tick lattice (and the DAG of the
  binomial tree) are chordal, so A5 says a **sparse banded gain can be synthesized exactly**
  off-chain — directly producing the fixed `K[i,j]` operator the on-chain kernel applies.
  Supporting/methods reference rather than a headline.

### B. Backward induction / replication on the binomial (recombining) lattice

**B1. Option pricing: a simplified approach (CRR binomial model)**
John C. Cox, Stephen A. Ross, Mark Rubinstein. *J. Financial Economics* 7(3), 229–263
(1979). [classic — not on arXiv]
- The market state space is a **recombining binomial lattice** (±1 multiplicative moves);
  value is computed by **backward induction** — at each node the price is an algebraic,
  one-step convex combination of its two children. The recursion index is the *price/step
  coordinate*, and the per-node replicating portfolio `(Δ shares, B bond)` is a **closed-form
  algebraic map** of the two child values (no solver).
- **Grounds our lattice controller.** This *is* the binomial tick lattice named in the
  framing. Backward induction = a **controlled recursion over a spatial coordinate** whose
  per-node update is pure algebra — the canonical "static-on-lattice" computation. The CRR
  node-local delta-hedge is the prototype of a per-tick control action with a closed form.

**B2. Recombining binomial tree for the constant-elasticity-of-variance (CEV) process**
— arXiv:1410.5955 (2014)
Hi Jun Choe, Jeong Ho Chu, So Jeong Shin.
- Builds a **recombining lattice whose nodes are placed by a finite-difference scheme**
  emulating a state-dependent (CEV) diffusion, with **linear complexity** in lattice size and
  an analytic envelope for the exercise boundary.
- **Grounds our lattice controller.** CEV (`σ ∝ S^β`) is the *elasticity* knob — our `η`/`ξ`
  elasticity in CFMM terms. B2 shows how to lay out a **non-uniform, elasticity-aware
  recombining tick lattice** with linear-cost, FD-derived node spacing — a template for a
  `Δi` grid that reflects the pricing-kernel elasticity while staying matrix/recursion-cheap.

**B3. GMWB riders in a binomial framework: pricing, hedging, diversification**
— arXiv:1410.7453 (2014)
Cody B. Hyndman, Menachem Wenger.
- Constructs **explicit perfect-hedging strategies on a binomial lattice that are funded using
  only periodic fee income**, and decomposes a complex liability into term-certain payments +
  option pieces, all by lattice backward induction.
- **Grounds our lattice controller.** "Replication funded by fee income" is precisely the
  CFMM control objective (fee revenue → target payoff exposure). B3 is a worked example of
  **fee-funded static replication on the binomial lattice** — the financial twin of our
  controller's reference-tracking objective, with everything reduced to node-local algebra.

### C. Static / algebraic spanning of a payoff across a grid (replication = static control)

**C1. Optimal positioning in derivative securities**
Peter Carr, Dilip Madan. *Quantitative Finance* 1(1), 19–37 (2001); see also Carr & Madan,
*Towards a theory of volatility trading* (1998). [classic — not on arXiv]
- Any twice-differentiable payoff `f(S)` is **statically spanned**:
  `f(S) = f(κ) + f'(κ)(S−κ) + ∫₀^κ f''(K)(K−S)⁺dK + ∫_κ^∞ f''(K)(S−K)⁺dK`.
  The replicating weights are `f''(K)dK` — a **closed-form, position-by-strike map**; no
  dynamics, no rebalancing.
- **Grounds our lattice controller.** This is the "static control = inversion across a grid"
  reading: discretize strikes onto the **tick lattice** and the spanning integral becomes a
  **matrix–vector product** `w = M f` mapping target payoff samples to per-tick option
  weights. It is the financial mirror of A1's "feedback as a function over space," and it is
  exactly EVM-computable (one fixed matrix). The variance-swap special case (`f'' ∝ 1/K²`)
  ties directly to our `σ`/variance-target inversion (`sigma_xs_poly_target_exists`).

**C2. Prices of state-contingent claims implicit in option prices**
Douglas T. Breeden, Robert H. Litzenberger. *J. Business* 51(4), 621–651 (1978). [classic]
- The **Arrow–Debreu state price** at price level `K` is the second strike-derivative of the
  call price, `∂²C/∂K²`. State prices are a **basis indexed by the price coordinate**.
- **Grounds our lattice controller.** Gives the dual basis for C1: per-tick **Arrow–Debreu
  weights** are the natural state coordinates of the lattice controller. Any per-tick target
  (exposure, slippage, variance) is hit by an inner product against this basis — algebraic,
  one-shot, on-chain-cheap.

**C3. A robust algorithm and convergence analysis for static replications of nonlinear
payoffs** — arXiv:1406.5430 (2014) *(full text read)*
Jingtang Ma, Dongya Deng, Harry Zheng.
- Replicates a nonlinear payoff by a **linear-spline (piecewise-linear) interpolant on a
  strike grid**; between knots `f(S) ≈ Σ b_i (X_i−S)⁺/(S−X_i)⁺` with slope-change weights
  `b_i = [f(X_{i+1})−f(X_i)]/h_i`. Strikes are placed by an **equidistribution equation**
  `h_i ρ_i = (1/n)Σ_j h_j ρ_j` with curvature density `ρ_i` (cluster knots where `f''` is
  large), giving a proven **O(n⁻²) convergence** rate. For *fixed* market strikes it reduces
  to a quadratic-hedging linear system **`Q w = u`** (`Q` = payoff covariances, `u` = payoff
  cross-moments).
- **Grounds our lattice controller.** The cleanest "static replication over a grid as a
  *finite linear system*" — `Q w = u` is solved **once off-chain**; on-chain we evaluate the
  fixed weights. The equidistribution rule is a principled, EVM-relevant recipe for **placing
  ticks (choosing `Δi`) by payoff curvature** — i.e. a non-uniform tick grid argument that
  complements our fixed-`Δi` inversions. `O(n⁻²)` quantifies the error of a small on-chain
  band.

**C4. Spanning multi-asset payoffs with ReLUs** — arXiv:2403.14231 (2024)
Sébastien Bossu, Stéphane Crépey, Hoang-Dung Nguyen.
- Distributional formulation of static spanning by vanilla/basket options; **unique solution
  iff the payoff is even and absolutely homogeneous**, with a **Fourier closed form**.
  Because real payoffs are **piecewise-linear**, the basis is naturally **ReLUs** (`(S−K)⁺`),
  and discrete spanning over a finite strike grid is a one-hidden-layer (linear-in-weights)
  fit.
- **Grounds our lattice controller.** A **ReLU = a kinked basis function at a tick** — the
  lattice spanning basis. C4 says spanning a target exposure is a **linear-in-weights solve
  over the tick grid** (a one-layer affine map), with a Fourier/algebraic closed form when
  structure permits — i.e. the EVM evaluates a fixed affine combination of per-tick hinge
  functions. The strongest modern statement that "control over the tick lattice = a static
  piecewise-linear spanning map."

### D. Discrete boundary-value / finite-state structure (supporting frame)

**D1. Two-point boundary-value problems of discrete optimal control**
Arthur E. Bryson & Yu-Chi Ho, *Applied Optimal Control* (1975), Ch. 2–6; cf. H.B. Keller,
*Numerical Methods for Two-Point Boundary-Value Problems* (1968). [textbook]
- Discrete-time optimal control yields a **two-point boundary-value problem** (state forward,
  costate backward) on the index set; for the LQ case it collapses to the **discrete Riccati
  recursion** and a constant-gain law. Read with the index as a **spatial coordinate**, this
  is a boundary-value problem *over the lattice with conditions at the two tick endpoints*
  `i₋, i₊`.
- **Grounds our lattice controller.** Legitimizes treating the tick band `[i₋, i₊]` as a
  **discrete BVP**: pin behavior at the endpoints (our band-min/band-max theorems
  `pi_trader_half_band_*`) and solve the interior algebraically. The forward-state /
  backward-costate split is the static analog of CRR backward induction (B1).

**D2. A control-oriented notion of finite-state approximation** — arXiv:1105.3788 (2011)
Danielle C. Tarraf.
- Certified controller synthesis when sensors/actuators take **finitely many values**:
  approximate the plant by a finite-memory machine for control purposes.
- **Grounds our lattice controller.** Our actuator/state are **quantized fixed-point**
  (int24 ticks, WAD/Q96). D2 is the right lens for arguing a **finite-tick controller is a
  certified approximation** of the real-valued kernel — relevant to the quantization /
  rounding spec flagged open in `MAPPING-SYNTHESIS.md`. Supporting reference.

### E. CFMM-side bridge (replication / function-maximizing AMMs)

**E1. Data-driven static hedging of exchange-traded options** — arXiv:2302.00728 (2023)
Vikranth Lokeshwar Dhandapani, Shashi Jain.
- Interpretable **semi-static** replication of a long-dated claim by a self-financing
  portfolio of shorter options + cash, benchmarked against the **Carr–Wu static hedge**.
- **Grounds our lattice controller.** A concrete, tested instance of C1/C3 with the
  Carr-lineage static hedge as baseline; useful as the empirical/engineering counterpart when
  validating a per-tick replication map. Peripheral but confirms the static-spanning route is
  practical and outperforms naive hedges.

---

## Recommended theoretical frame for static control on the tick / binomial lattice

**Single best-fit formalism: control of *spatially-invariant (shift-invariant) systems over
the tick lattice*, diagonalized by the lattice DFT — i.e. the Bamieh–Paganini–Dahleh frame
(A1), in its closed-form static-feedback instance (A2), realized financially as Carr–Madan /
Breeden–Litzenberger static spanning over the grid (C1/C2/C4).**

Why this and not the alternatives:

- It is the only frame in which the **iteration index is genuinely a spatial coordinate** and
  the controller is *by construction* a **function over that coordinate** (`K[i,j]=κ(i−j)`),
  matching "dynamic over the lattice, not over time" exactly.
- The **spatial Fourier / DFT decoupling** turns whole-lattice synthesis into **independent
  per-wavenumber algebraic problems** (a constant gain or one Riccati per frequency), all
  solved **off-chain**; on-chain reduces to one **fixed banded (Toeplitz/circulant)
  matrix–vector product** — precisely the EVM-computable, no-solver constraint. The
  poset/Riccati result (A4) supplies the "Riccati-indexed-by-lattice-position" piece, and
  exponential tap decay (A1) justifies the small on-chain band (`n ≤ 3–4`).
- It **unifies cleanly with the financial layer**: Carr–Madan/Breeden–Litzenberger static
  spanning (C1/C2) and the ReLU/linear-spline discretizations (C3/C4) express the *same*
  object — a linear map from a per-tick target to per-tick weights, `w = M f` / `Q w = u` —
  so the controller's set-point map and the payoff-replication map are one matrix. Our
  already-proven static inversions (`sigma_xs_poly_target_exists`, `deltaI_star`,
  `eta_split_kernel_identity`) slot in as the **per-position (per-wavenumber) set-point
  entries** of that operator.
- The **CRR binomial lattice (B1)** supplies the recombining ±1-tick **state space** the
  operator acts on, and **backward induction** is the static recursion that fills it; the CEV
  recombining tree (B2) shows how to make the node spacing elasticity-aware.

Operational implication: treat the controller as **one off-chain synthesis → one on-chain
fixed banded/affine map over the tick lattice**. Off-chain (GAMS/Lean): DFT-decouple the
shift-invariant kernel, solve per-wavenumber for the constant gains (or assemble the
Carr–Madan/spline weights), truncate by spatial decay. On-chain (Plank/EVM): evaluate the
resulting **banded Toeplitz `K` (or hinge-basis affine map)** — a handful of `mulDiv`s, no
pow/log, no solve, saturating at the band endpoints (the discrete-BVP boundary conditions of
D1). This is the lattice-native, EVM-feasible realization the milestone needs.
