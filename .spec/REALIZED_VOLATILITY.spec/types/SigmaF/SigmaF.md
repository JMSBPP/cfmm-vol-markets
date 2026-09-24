# [TYPE:: SIGMA_F](MAIN_REF# MODEL)

`-- types.toml: SigmaF` · [#151](https://github.com/JMSBPP/cfmm-vol-markets/issues/151) (Ray pin)

\[
\begin{aligned}
\mathrm{SigmaF}
&\leftarrow
\sigma_F
:=
\mathrm{u256}_{\mathrm{RAY}}
\\
\mathrm{RAY}
&:=
\mathrm{RAY\_UNIT}
=
10^{27}
\quad(\mathtt{cfmm\_types::Ray})
\\[1em]
\mathrm{intro}
&::
\mathrm{u256} \to \mathrm{SigmaF}
\\
\mathrm{intro}(x)
&=
\sigma_F
\\[1em]
\Delta Q_{M}
&:=
\sigma_F \cdot \Delta W
\\
\mathrm{token\_amount}
&::
\mathrm{SigmaF} \to \Delta W(\bar{dt}) \to \mathrm{u256}
\\
\mathrm{TokenAmount}
&=
\frac{\sigma_F \cdot \lvert \Delta W(\bar{dt}) \rvert}{\mathrm{RAY}}
\\
\mathrm{Dir}
&=
\mathrm{sign}(\Delta W)
\\
\mathrm{Eff}^{\mathrm{SigmaF}}
&=
[\,]
\\[1em]
&\text{hole: }\mathtt{token\_amount}\text{ body — define phase}
\end{aligned}
\]

## Std / host reuse

| Candidate | Fit |
|-----------|-----|
| `cfmm_types::Ray` (`RAY_UNIT`) | **Reuse** — product scale authority |
| `types::Numerics::RAY` | **Reject** as scale authority |
| `WeinerGenerator::DeltaW(dt)` | **Reuse** — `token_amount` input |
| `std::option::Option` | N/A this type (pure) |
| New host `Ray` / `Outcome` | **Reject** |

CEV / $\sigma(i)$ / $\pi^{\sigma}$ below are notation for later slices, not operations of `SigmaF`.

\[
\begin{aligned}
L_{1/2}
&:=
\mathrm{liquidity}(\mathrm{LiquidityChunk})
:
\mathrm{u128}
\\
\sqrt{p}
&:
\mathrm{u160}_{\mathrm{Q64.96}}
\\
\sigma(i)
&:=
\left(
\frac{\sigma_F}
{L_{1/2}\,\ln(1.0001)\,\sqrt{p}}
\right)^{2}
\in
\mathrm{u88}_{\mathrm{tick}^{2}}
\\
\Delta i_{\mathrm{diff}}
&:=
\frac{\sqrt{\sigma(i)}\cdot \Delta W}{\mathrm{RAY}}
\\
\mu_{\mathrm{It\hat{o}}}(i)
&:=
-\tfrac{1}{2}
\left(
\frac{\sigma_F}
{L_{1/2}\,\sqrt{p}}
\right)^{2}
\\
\sigma_{K}
&:
\mathrm{u88}_{\mathrm{tick}^{2}}
\\
\pi^{\sigma}
&=
\bar L \, \bigl(\sigma(i)-\sigma_{K}\bigr)
\end{aligned}
\]
