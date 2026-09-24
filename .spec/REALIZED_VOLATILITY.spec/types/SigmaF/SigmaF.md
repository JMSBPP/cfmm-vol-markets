# [TYPE:: SIGMA_F](MAIN_REF# MODEL)

`-- types.toml: SigmaF` · [#151](https://github.com/JMSBPP/cfmm-vol-markets/issues/151)

BTT: [SigmaFIntro.btt](SigmaFIntro.btt) · [SigmaFIntroFromU256.btt](SigmaFIntroFromU256.btt)

\[
\begin{aligned}
\mathrm{SigmaF}(N)
&\leftarrow
\{\,r \mid r : N\,\}
\\
N
&=
\mathrm{Ray}
\quad\text{(only instantiation this slice)}
\\
\mathrm{SigmaF}(\mathrm{Ray})
&\leftarrow
\{\,r : \mathrm{Ray}\,\}
\\[1em]
\mathrm{intro}
&::
\mathrm{Ray} \to \mathrm{SigmaF}(\mathrm{Ray})
\\
\mathrm{intro}(r)
&=
\{\,r\,\}
\\
\mathrm{intro\_from\_u256}
&::
\mathrm{u256} \to \mathrm{SigmaF}(\mathrm{Ray})
\\
\mathrm{intro\_from\_u256}(x)
&=
\mathrm{intro}(\mathrm{Ray.intro}(x))
\\[1em]
\mathrm{Eff}^{\mathrm{SigmaF}}
&=
[\,]
\\[1em]
&\text{no }\mathtt{token\_amount}\text{ — product owned by }\mathrm{TokenAmountStock}
\end{aligned}
\]

### \(\mathrm{intro}
::
\mathrm{Ray}
\to
\mathrm{SigmaF}(\mathrm{Ray})\)

\[
\begin{aligned}
\mathrm{intro}(r)
&=
\{\,r\,\}
\\
\mathrm{Eff}^{\mathrm{intro}}
&=
[\,]
\end{aligned}
\]

Plank: `intro`. BTT: [SigmaFIntro.btt](SigmaFIntro.btt).

### \(\mathrm{intro\_from\_u256}
::
\mathrm{u256}
\to
\mathrm{SigmaF}(\mathrm{Ray})\)

\[
\begin{aligned}
\mathrm{intro\_from\_u256}(x)
&=
\mathrm{intro}(\mathrm{Ray.intro}(x))
\\
\mathrm{Eff}^{\mathrm{intro\_from\_u256}}
&=
[\,]
\end{aligned}
\]

Plank: `intro_from_u256`. BTT: [SigmaFIntroFromU256.btt](SigmaFIntroFromU256.btt).

## Std / host reuse

| Candidate | Fit |
|-----------|-----|
| `cfmm_types::Ray` | **Reuse** — phantom `N`, carrier field, `Ray.intro` |
| `types::Numerics::RAY` | **Reject** as scale authority |
| `WeinerGenerator::DeltaW(dt)` | N/A on SigmaF (used by Base/Stock) |
| `token_amount` on SigmaF | **Reject** — moved to Stock (#151) |
| New host Ray / Outcome | **Reject** |

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
\frac{\sqrt{\sigma(i)}\cdot \Delta W}{\mathrm{unit}(N)}
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
