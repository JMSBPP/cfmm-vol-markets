# [TYPE:: WEINERGENERATOR](MAIN_REF# MODEL)

[Shock](../Shock/Shock.md) · [Pips](https://github.com/JMSBPP/cfmm-types/blob/develop/.spec/types/Pips/Pips.md) · [Ray](https://github.com/JMSBPP/cfmm-types/blob/develop/.spec/types/Ray/Ray.md) · [TimeSpacing](https://github.com/JMSBPP/cfmm-types/blob/develop/.spec/types/TimeSpacing/TimeSpacing.md) · [IO](../IO/IO.md)

Plank: `src/types/WeinerGenerator.plk`. types.toml: `WeinerGenerator`.
PRD: [#146](https://github.com/JMSBPP/cfmm-vol-markets/issues/146) refine · [#145](https://github.com/JMSBPP/cfmm-vol-markets/issues/145) define · [#143](https://github.com/JMSBPP/cfmm-vol-markets/issues/143) type · parent [#136](https://github.com/JMSBPP/cfmm-vol-markets/issues/136).
Prereq: [#149](https://github.com/JMSBPP/cfmm-vol-markets/issues/149) / [#150](https://github.com/JMSBPP/cfmm-vol-markets/issues/150) `Shock(Pips)`; [cfmm-types#26](https://github.com/JMSBPP/cfmm-types/issues/26) `TimeSpacing.sqrt_dt`.

**Replace** legacy `ShockPips` / seal-reveal / passed-`eps` `deltaW`. Channel-built
\(\Delta W(\bar{dt})\) via `Shock(Pips)` under Eff = `[Timestamp]` (WeinerView).
Local `SQRT_DT_RAY_*` / `sqrt_dt_ray` **removed** — import `cfmm_types::TimeSpacing.sqrt_dt`.

## Std / host candidates

| Candidate | Fit |
|-----------|-----|
| Legacy `ShockPips` / seal-reveal | **Replace** |
| `Shock(T)` + `run_shock` | **Reuse** — entropy channel (`T=Pips`) |
| `cfmm_types::Pips` / `Ray` | **Reuse** — mag; product on Ray scale |
| `TimeSpacing.sqrt_dt` | **Reuse** — √(dt)·RAY table (#26); not host-local |
| `TimeSpacing` / `Window` | **Reuse** — `dt` domain + `n(dt)` |
| `IO` / `Option` | **Reuse** — wrap + outcome |
| New `Outcome`/`Result` | **Reject** |

> KEEP THIS NOTATION

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
\\[1em]
\sqrt{\bar{dt}}
&=
\mathrm{TimeSpacing.sqrt\_dt}(\bar{dt})
\quad(\mathrm{Ray};\ \text{lib table, not host})
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

### \(\mathrm{io}
::
\mathrm{WeinerCmd}
\to
\mathrm{IO}(\mathrm{WeinerCmd})\)

\[
\begin{aligned}
\mathrm{io}(\mathrm{cmd}) &= \mathrm{IO}\{\mathrm{inner}\leftarrow\mathrm{cmd}\} \\
\text{pure wrap; no Eff}
\end{aligned}
\]

### \(\mathrm{run}_{\mathrm{weiner}}
::
\mathrm{IO}(\mathrm{WeinerCmd})
\to
\mathrm{Option}(\mathrm{DeltaW}(2))\)

\[
\begin{aligned}
s &= \mathrm{Shock.run\_shock}(\mathrm{Shock.io}(\mathrm{ShockCmd}\{j\})) \\
\mathrm{mag} &= \mathrm{val}(s).\mathrm{val}
\quad(\mathrm{Pips},\,\mathrm{u16})
\\
\sqrt{\bar{dt}} &= \mathrm{TimeSpacing.sqrt\_dt}(2)
\\
\mathrm{run}_{\mathrm{weiner}}(\mathrm{io}(\mathrm{WeinerCmd}\{j\}))
&=
\mathrm{Some}\bigl(\mathrm{DeltaW}(2)\{\mathrm{val}\leftarrow
\lfloor\mathrm{rayVal}(\sqrt{\bar{dt}})\cdot\mathrm{mag}/\mathrm{PIPS}\rfloor\}\bigr)
\\
\text{BTT:}&\ \mathtt{WeinerGeneratorRunWeiner.btt}
\\
\text{laws:}&\ \text{Some; different }\Delta W\text{ across }j\text{ (not eq)}
\end{aligned}
\]

### \(\mathrm{val}
::
\mathrm{DeltaW}(\bar{dt})
\to \mathrm{u256}\)

\[
\begin{aligned}
\mathrm{val}(dw) &= dw.\mathrm{val}
\end{aligned}
\]
