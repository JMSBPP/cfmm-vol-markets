# TODO — Controller-Design Worklist (user ↔ agent)

This file is the **pending-work handshake** between the user and the EVM-controller
agent. It tracks the GAMS-agent **optimization exercises that have merged into
`develop`** and reframes each as a **controller-design task**: *"we need to design
such a controller (static, on the tick lattice, EVM-computable)."*

- **Intake:** each merged GAMS/Lean optimization result on `develop` → one
  controller-design entry below.
- **Design layer:** static, fixed `L̄`, representative agent, η = ½ (η-split as the
  generalization path). See the design basis:
  `.planning/research/v2-controller/STATIC-CONTROL-KERNEL-SPEC.md` and the catalog
  `.planning/research/v2-controller/CONTROLLERS.md`.
- **Ships:** controller designs land on `feat/evm-controller` → PR → `develop` (gate-green).

## Refresh (re-fetch the latest merged GAMS optimization results)

```bash
# preferred (needs network/auth):
gh pr list --state merged --base develop --limit 30 \
  --json number,title,headRefName,mergedAt \
  | jq -r '.[] | "#\(.number) [\(.headRefName)] \(.title)"'
# offline fallback — scan develop for merged GAMS/Lean optimization results:
git log --oneline develop | grep -iE "gams|payoff|optim|eta|kernel|zero.?slip|sigma|variance|band"
```
> Automating this fetch (a script that diffs new merges since last sync and appends
> rows here) is itself a pending task — see INTAKE below.

## Controller-design tasks (from merged GAMS/Lean results)

Legend: owner `agent` = design/spec; `user` = decision/approval needed. Status:
`pending` → `designed` (spec written) → `implemented` (future milestone).

- [~] **C1 · zero-slippage spacing controller** — realize the proven zero-slippage minimizer `Δᵢ⋆ = log(L̄/(L̄−Δᴵ))/(logλ·i)` (usage policy deferred to band-max companion).
  src: `develop` `6369fc6` program (1) / `e79e0a7`,`4300459`; proof `pi_trader_half_zero_at_deltaI_star` + `eta_pi_trader_zero_slippage.md`; GAMS `eta_pi_trader_zero_slippage.gms`. owner: agent. status: **exercise drafted** → `research/v2-controller/exercises/EX-01-zero-slippage-spacing-controller.md` · §6 design Qs open (EVM route, ×2 factor, rounding).
- [ ] **C2 · σ-target controller** — pick `Δᵢ⋆(n,d,σ_target)` (quadratic root) to hit a cross-section vol target.
  src: `develop` `6fa115f`/`ddea352` (`sigma_xs_poly_target_exists`). owner: agent. status: **pending** · proof case for Phase 10; needs fixed-point `sqrt` (gap G5).
- [ ] **C3 · band-min controller** — `Δᵢ = Δᵢ_min` (large-trade left edge), cheapest clamp.
  src: `develop` `905be3a` (band-min). owner: agent. status: **pending** · EVM-ready.
- [ ] **C4 · band-max / variance-swap controller** — endpoint rule at `Δᵢ_max`.
  src: `develop` `841df7b`/`753c7de` (band-max + golden bound). owner: agent. status: **pending** · interior-hump sliver open (gap G4).
- [ ] **C5 · small-signal-gain controller** — `π/Δᴵ² → P²(P−1)²`.
  src: proven set `b8662df`. owner: agent. status: **pending** · EVM-ready.
- [ ] **C6 · 3-point parabolic argmin** — solver-free lattice argmin of the convex payoff.
  src: GAMS-validated ≡ NLP argmin. owner: agent. status: **pending** · EVM-portable.
- [ ] **C7 · η-split kernel realization** — `P_η(i)=P½(i₋)P½(i₊)`, `i₋=⌊ηi⌋`.
  src: `eta_split_kernel_identity`. owner: agent. status: **pending** · generalization path off η=½.
- [ ] **C9 · realized-variance aggregator** — lattice rollback collapsed to closed form.
  src: `eta_sigma_xs_realized_connection`. owner: agent. status: **pending** · EVM-ready.

## Blocked / awaiting upstream (needs the user or the GAMS agent)

- [ ] **GAMS optimization program (3)** — programs (1),(2),(4) merged (`6369fc6`); **(3) not yet on `develop`**. owner: GAMS agent / user. status: **awaiting merge**.
- [ ] **G1 · stochastic swap-flow reference** — no GAMS ground-truth model; Plank stubs only (C10). owner: user+GAMS. status: **awaiting**.
- [ ] **G2 · general η≠½** — needs fixed-point `pow`/linearization. owner: agent (design) + user (priority). status: **deferred**.
- [ ] **G5 · fixed-point primitives** — signed `mulDiv`, `sqrt`, clamp/saturation (blocks C2 on-chain). owner: agent + ul2inqpl (src/ layout). status: **pending (Phase 10/impl milestone)**.
- [ ] **G6 · liquidity-kernel ξ/ι** — normalization + actuator semantics (`ℓ` unit-sum unrealized at ι=1). owner: agent + GAMS. status: **open**.
- [ ] **INTAKE automation** — script to append new merged-PR results here since last sync. owner: agent. status: **pending**.

---
*Seeded 2026-06-28 from `develop` merge history. Re-run the Refresh block to update.*
