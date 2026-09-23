# [TYPE:: WEINERGENERATOR](MAIN_REF# MODEL)

[Shock](../Shock/Shock.md) · [Pips](https://github.com/JMSBPP/cfmm-types/blob/develop/.spec/types/Pips/Pips.md) · [Ray](https://github.com/JMSBPP/cfmm-types/blob/develop/.spec/types/Ray/Ray.md) · [TimeSpacing](https://github.com/JMSBPP/cfmm-types/blob/develop/.spec/types/TimeSpacing/TimeSpacing.md) · [IO](../IO/IO.md)

Plank: `src/types/WeinerGenerator.plk`. types.toml: `WeinerGenerator`.
PRD: [#143](https://github.com/JMSBPP/cfmm-vol-markets/issues/143) · parent [#136](https://github.com/JMSBPP/cfmm-vol-markets/issues/136).
Prereq: [#149](https://github.com/JMSBPP/cfmm-vol-markets/issues/149) / [#150](https://github.com/JMSBPP/cfmm-vol-markets/issues/150) `Shock(Pips)`.

**Replace** legacy `ShockPips` / seal-reveal / passed-`eps` `deltaW`. Channel-built
\(\Delta W(\bar{dt})\) via `Shock(Pips)` under Eff = `[Timestamp]` (WeinerView).

## Std / host candidates

| Candidate | Fit |
|-----------|-----|
| Legacy `ShockPips` / seal-reveal | **Replace** |
| `Shock(T)` + `run_shock` | **Reuse** — entropy channel (`T=Pips`) |
| `cfmm_types::Pips` / `Ray` | **Reuse** — mag; √dt·mag → Ray-scale |
| `TimeSpacing` / `Window` | **Reuse** — `dt` domain + `n(dt)` |
| `IO` / `Option` | **Reuse** — wrap + outcome |
| New `Outcome`/`Result` | **Reject** |

\[
\begin{aligned}
\mathrm{DeltaW}(\bar{dt})
&\leftarrow
\{\mathrm{val}:\mathrm{u256}\}
\quad(\text{Ray-scale; Ray carrier later})
\\[1em]
\mathrm{WeinerCmd}
&\leftarrow
\{\mathrm{j}:\mathrm{u256}\}
\\[1em]
\mathrm{io}
&::
\mathrm{WeinerCmd}
\to
\mathrm{IO}(\mathrm{WeinerCmd})
\\[1em]
\mathrm{run}_{\mathrm{weiner}}
&::
\mathrm{IO}(\mathrm{WeinerCmd})
\to
\mathrm{Option}(\mathrm{DeltaW}(\bar{dt}))
\\[1em]
\mathrm{val}
&::
\mathrm{DeltaW}(\bar{dt})
\to \mathrm{u256}
\\[1em]
\mathrm{run}_{\mathrm{weiner}}(\mathrm{io}(\mathrm{WeinerCmd}\{j\}))
&=
\mathrm{Some}(\mathrm{DeltaW}(\bar{dt}))
\\
&\quad\text{iff }\mathrm{Shock.run\_shock}\text{ succeeds and }\sqrt{\bar{dt}}\cdot\mathrm{mag}\text{ forms}
\\[1em]
\mathrm{None}
&=
\text{Shock / Timestamp / entropy failure}
\\[1em]
\mathrm{Eff}^{\mathrm{Weiner}}
&=
[\mathrm{Timestamp}]
\quad(\mathrm{WeinerView})
\end{aligned}
\]

## SIDE_EFFECTS

\[
\begin{aligned}
\mathrm{Eff}
&=
[\mathrm{Timestamp}]
\\
\bar{dt}
&\in
\mathrm{TimeSpacing}
\end{aligned}
\]

### First behavior (define later — #145)

\(\mathrm{run}_{\mathrm{weiner}}(\mathrm{io}(\ldots))\) **success** for one valid \(\bar{dt}\) (e.g. \(2\)):
`Some(DeltaW(dt))`.

Holes (type phase — no bodies):

- `io` / `run_weiner` / `val`
- Product \(\sqrt{\bar{dt}}\cdot\mathrm{mag}\) inside `run_weiner` (define)
