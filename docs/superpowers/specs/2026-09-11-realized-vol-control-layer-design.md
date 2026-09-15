# Design: Realized-volatility open-loop control layer

**Date:** 2026-09-11  
**Topic:** Lock the missing “base control layer” for `.spec/REALIZED_VOLATILITY.md`, then continue Aristotle project `be429bef-1ac0-407a-85ec-48d1aa157201` so it proposes the discrete recursion and proves terminal pinning.  
**Scope:** Spec notes + Lean (Aristotle continue). Forge-script cron is a documented consumer only — not implemented in this slice.  
**Status:** Brainstorm approved (Approach A; Design §1–§2).

## Motivation

`REALIZED_VOLATILITY.md` already has:

- net-flow → tick diffusion with \(\sigma(i)=e^{\alpha-\beta i}\), \(\beta=\ln 1.0001\);
- terminal \(i(N)=(\alpha-\ln\bar\sigma)/\beta\);
- injective map \(g(i)=e^{\beta i}\) with \(g(x-y)=g(x)/g(y)\) (Aristotle `TickDualMapping`, sorry-free).

What is missing is the **control** that produces an open-loop tick path realizing \(\bar\sigma\) for a forge-script cron that emits `TickHistory`.

## Decisions (locked)

| Choice | Decision |
|--------|----------|
| Runtime shape | Open-loop path (forge cron evaluates a schedule; no online feedback) |
| Path shape | Diffusion-shaped (\(\mu(i),\sigma(i)\) from the md SDE) |
| Terminal pin | **Drift scale** — one scalar \(\kappa\) on drift; do not refit shocks |
| Noise | Solidity randomness pattern: trusted sealed seed ⊕ future `blockhash` → \(\varepsilon_j\) ([solidity-patterns/randomness](https://fravoll.github.io/solidity-patterns/randomness.html)) |
| Aristotle job | **Fill gaps** — we state requirements; it proposes the discrete recursion and proves the pin |
| Delivery mode | **Approach A** — requirements block in the md + `aristotle continue` on `be429bef-…` |

## Architecture

```
seed / blockhash  →  ε_j (PRNG)  →  solve κ*  →  {i_j}_0^N  →  TickHistory (forge cron)
         ↑                              ↑
   randomness pattern            drift-scale pin
         ↑                              ↑
   abstract in Lean              Aristotle constructs + proves
```

- **Lean / Aristotle:** own the math (recursion + \(\kappa^\star\)).
- **Forge cron (later):** evaluate that math; optionally act as the trusted party for commit–reveal, or simulate it on anvil.
- **Reuse:** `TickDualMapping` / \(g\) remain given; do not re-open the affine-\(\otimes\) no-go.

## Normative requirements (to append to `.spec/REALIZED_VOLATILITY.md`)

### Control layer (requirements)

**Goal.** Open-loop forge-cron schedule: diffusion-shaped tick path; noise from the Solidity seed⊕`blockhash` PRNG; one drift scalar pins \(i(N)\) implied by target \(\bar\sigma\).

**Given.**

- \(\sigma(i)=e^{\alpha-\beta i}\), \(\beta=\ln 1.0001\), \(g(i)=e^{\beta i}\), inverse \(i=\ln(g(i))/\beta\).
- Terminal: \(\sigma(N)=\bar\sigma \implies i(N)=(\alpha-\ln\bar\sigma)/\beta\).
- Discrete tick increment form from the net-flow section (\(\mu(i),\sigma(i),\Delta W\)), with \(\Delta W_j=\sqrt{\bar dt}\,\varepsilon_j\).

**Requirements.**

1. **Inputs:** \(i(0)\), \(\bar\sigma\) (hence \(i(N)\)), \(\bar dt\), \(N\), and a fixed PRNG stream \(\{\varepsilon_j\}_{j=1}^{N}\) (abstract; interpret as derived from `keccak(seed, blockhash, j)`).
2. **Recursion:** Propose \(i_j=i_{j-1}+\Delta i_j(\mu_\kappa,\varepsilon_j)\) where the drift is a one-parameter family \(\mu_\kappa=\kappa\cdot\mu(\cdot)\) (or an equivalent single scalar on the md drift).
3. **Pin:** For any fixed \(\{\varepsilon_j\}\), construct (or uniquely determine) \(\kappa^\star\) such that \(i_N=i(N)\).
4. **Preserve:** Keep the diffusion-coefficient / \(\sigma(i)\) profile; **do not** refit or replace \(\varepsilon_j\).
5. **Output:** \(\{i_j\}_{j=0}^{N}\) and \(\kappa^\star\), sufficient for a forge script to evaluate the path after \(\varepsilon\) is known.

**Out of scope for Aristotle.** On-chain commit–reveal protocol, gas batching, Plank `TickState` / factory types.

## Aristotle continue prompt (draft)

Project: `be429bef-1ac0-407a-85ec-48d1aa157201`

```text
Continue from TickDualMapping / g(i)=exp(β·i) as given — do not reopen the affine ⊗ no-go.

We need the open-loop base control layer for a forge-script cron that emits a TickHistory
realizing target σ̄. Requirements (normative):

- Diffusion-shaped discrete tick path from the realized-vol md SDE (μ(i), σ(i), ΔW).
- Noise ε_j is exogenous (Solidity pattern: sealed seed ⊕ future blockhash → PRNG). Treat
  {ε_j} as an arbitrary fixed sequence; do not solve for the shocks.
- Pin the terminal by a single drift scale κ: μ_κ = κ·μ(·) (or equivalent one-parameter
  drift family) so that i_N = i(N) = (α − ln σ̄)/β.
- Prove: for any fixed {ε_j}, κ* exists constructively (or uniquely under stated
  hypotheses) with i_N = i(N); path well-defined; σ(i) profile preserved.
- Output Lean: the recursion, κ* construction, and a short summary of forge evaluation
  order: obtain ε → solve κ* → emit {i_j}.

Stay sorry-free. New module under RequestProject/ is fine.
```

## Forge handoff (documentation only)

1. Cron obtains \(\varepsilon_j\) (live commit–reveal, or anvil/`vm` simulation of the same interface).
2. Evaluate Aristotle’s \(\kappa^\star\) and recursion.
3. Write `TickHistory` / path artifact.

No forge implementation in this design slice.

## Testing / verification

- `lake build` on the continued Aristotle artifact; `#print axioms` on pin/recursion theorems must not include `sorryAx`.
- Grep/build warnings: no `declaration uses 'sorry'`.
- Manual check: summary states forge order `ε → κ* → path`.

## Non-goals

- Implementing the forge cron or Plank types in this slice.
- Replacing PRNG shocks with a fully solved shock path.
- Time-change or Brownian-bridge pinning.

## Implementation follow-up (after this spec is approved)

1. Append the Control-layer requirements block to `.spec/REALIZED_VOLATILITY.md` (replace the dangling “missing control” sentence).
2. `aristotle continue` with the prompt above; download artifact into `.spec/REALIZED_VOLATILITY.lean/`.
3. `lake build` + axiom check (same bar as the dual-mapping run).
4. Later track: forge script that evaluates the Lean recursion (separate plan).
