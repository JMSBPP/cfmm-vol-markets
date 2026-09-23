# [TYPE:: SHOCK](MAIN_REF# MODEL)

[Pips](https://github.com/JMSBPP/cfmm-types/blob/develop/.spec/types/Pips/Pips.md) · [Ray](https://github.com/JMSBPP/cfmm-types/blob/develop/.spec/types/Ray/Ray.md) · [IO](../IO/IO.md) · [WeinerGenerator](../WeinerGenerator/WeinerGenerator.md)

Plank: `src/types/Shock.plk`. types.toml: `Shock`.
PRD: [#149](https://github.com/JMSBPP/cfmm-vol-markets/issues/149) · parent [#136](https://github.com/JMSBPP/cfmm-vol-markets/issues/136).
Prereq of [#143](https://github.com/JMSBPP/cfmm-vol-markets/issues/143) (WeinerGenerator channel `DeltaW`).

Host-owned **generic** `Shock(T)`. First instantiation: `T = Pips` (`cfmm_types::Pips`).
Not pure: Eff reads global time and produces a random shock valued in `T`.

## Std / host candidates

| Candidate | Fit |
|-----------|-----|
| Legacy `ShockPips` | **Reject as the carrier** — replaced by `Shock(Pips)` |
| `cfmm_types::Pips` | **Reuse** as `T` for Weiner |
| `cfmm_types::Ray` | **Import** for √-scale inputs when product path migrates |
| Host `IO` / `Outcome` | **Reuse** wrap pattern; `run` returns `Option(Shock(T))` (Outcome law: Some/None) |
| `std::option::Option` | **Reuse** as `run` result |
| Draft `Timestamp` | **Eff module** — Timestamp view of env time (refine path) |

\[
\begin{aligned}
\mathrm{Shock}(T)
&\leftarrow
\{\mathrm{inner}:T\}
\\[1em]
\mathrm{io}
&::
\mathrm{ShockCmd}
\to
\mathrm{IO}(\mathrm{ShockCmd})
\\[1em]
\mathrm{run}
&::
\mathrm{IO}(\mathrm{ShockCmd})
\to
\mathrm{Option}(\mathrm{Shock}(T))
\\[1em]
\mathrm{val}
&::
\mathrm{Shock}(T)
\to T
\\[1em]
\mathrm{run}(\mathrm{io}(\mathrm{cmd}))
&=
\mathrm{Some}(\mathrm{Shock}(T))
\quad\text{iff Timestamp env + entropy succeed}
\\[1em]
\mathrm{None}
&=
\text{Timestamp / entropy failure}
\\[1em]
\mathrm{Eff}^{\mathrm{Shock}}
&=
[\mathrm{Timestamp}]
\end{aligned}
\]

## SIDE_EFFECTS

\[
\begin{aligned}
\mathrm{Eff}
&=
[\mathrm{Timestamp}]
\\
T=\mathrm{Pips}
&\text{ is the first Weiner instantiation (channel shock in pips)}
\end{aligned}
\]

### First behavior (define later)

\(\mathrm{run}(\mathrm{io}(\ldots))\) **success** for `Shock(Pips)`: Timestamp present → `Some(Shock(Pips))`.

Holes (type phase — no bodies):

- `io` / `run` / `val` (and optional `magnitude` alias)
- Timestamp view selector used by `run`

## Pin

`lib/cfmm-types` must include `Pips` (and `Ray` for later √·mag product). Import: `cfmm_types::Pips::*`.
