# Streaming premium = LP fee revenue (theta-leg bridge)

 The discrete Black–Scholes claim and its Δ-hedge live in
import [$\pi$ / $\Delta X$ / $\phi_{Z}$ / $\bar\phi^{\star}$ / $\sigma_X$](./FINANCE.md).
This note locks the **theta leg**: the option's per-unit time-decay premium IS the LP's
cumulative adaptive-fee revenue, per unit liquidity.

## Lattice theta — the 𝐝t-leg of 𝐝π

\[
\Theta(i,j)\;:=\;\partial_t\pi\;=\;\frac{\pi(i,j{+}1)-\pi(i,j)}{\Delta t}
\qquad(\text{the }\mathbf{d}t\text{ leg of }\mathbf{d}\pi,\ \text{FINANCE 6.7})
\]

By backward induction (FINANCE 6.18) a long claim decays in calendar time, so the **signed**
\(\Theta<0\). The **ATM magnitude** is the lattice theta held at the **strike tick**
\(i_K=\log_\lambda K\) (where \(P_X(i_K)=K\) — spot equals strike), read along the time axis \(j\):

\[
\Theta_{\text{ATM}}(j)\;:=\;\big|\Theta(i_K,j)\big|\;=\;-\,\Theta(i_K,j)
\]

— the **center column** of the tree (balanced up/down moves), NOT the diagonal \(i=j\) (the all-up
boundary node, deep ITM/OTM). With time-to-maturity \(\tau=(J-j)\,\Delta t\) and ATM level \(k=K\):

\[
\Theta_{\text{ATM}}(\tau)=\frac{k\,\sigma_X}{\sqrt{8\pi \tau}},\qquad
\int_0^T\Theta_{\text{ATM}}\,d\tau=k\,\sigma_X\sqrt{\tfrac{T}{2\pi}}
\]

The \(1/\sqrt{\tau}\) is the ATM-theta blow-up at expiry (\(\tau\to0\)); the argument \(\tau\) is
time-to-maturity, not a node index — \(\Theta_{\text{ATM}}\) fixes the price tick at \(i_K\) and varies
in time, it is **not** the diagonal \(\Theta(i,i)\).

— Panoptic's streaming premium \(P=\int\mathcal S(t)\,\theta\,dt\) (Eq. 1) and Kristensen's ATM
premium \(k\sigma\sqrt{T/2\pi}\) (§3.4.2) **agree exactly** (the integral rebuilds the premium).

## The theta-leg identity (per unit liquidity)

The LP **sells** π (short the option = long the fee stream), earning \(-\Theta\) per step. Over
the tick-path \(\mathbf I_X(\tau)\), the accumulated theta-premium equals gross fee revenue
\(\Upsilon^{\phi}\) **divided by deployed liquidity** \(L\):

\[
P_\pi\;:=\;\sum_{i_X\in\text{path}}\big(-\Theta(i_X,j)\big)\,\Delta t
\;\overset{\text{fair }\phi}{=}\;
\frac{\Upsilon^{\phi}\!\big(\mathbf I_X(\tau)\big)}{L},\qquad
\Upsilon^{\phi}:=\sum_{i_X\in\text{Bucket}}\phi(\,;\sigma_X)\,\Delta X(i_X)
\]

— the discrete twin of Panoptic's \(\int\theta\) and the \(\Delta\Upsilon/L\) fee revenue of
CFMM_DISCRETE (cfmm-theory KB — not vendored). The \(\div L\) is dimensional:
\(P_\pi\) is a per-unit premium, \(\Upsilon^{\phi}\) a gross asset revenue.

## Fair-fee calibration (no-arbitrage)

Equality holds when the fee is fair (Kristensen Eq. 3.16), with the **total** fee
\(\phi=\bar\phi^{\star}+\phi_{Z}\) (not the floor alone):

\[
\sigma_X=\mathrm{IV}=2\,\phi(\,;\sigma_X)\sqrt{\mathrm{VOL}/L}
\iff
\mathrm{VOL}/L=\Big(\tfrac{\sigma_X}{2\,\phi(\,;\sigma_X)}\Big)^2
\]

Out of equilibrium the adaptive surcharge \(\phi_{Z}(\,;\sigma_X)\) moves the total fee to
**re-pin** realized \(\Upsilon^{\phi}/L\) onto \(P_\pi\) as \(\sigma_X\) drifts — what
\(\phi_{Z}\) (the VolatilityOracle-driven controller) is FOR.

## Caveat — the gamma leg

\(\Upsilon^{\phi}\) is **gross** fee revenue (theta leg only). The LP also bears
**impermanent loss / LVR** (the gamma leg) \(\mathrm{IL}=\sum(\Delta X)^2/\ell\) (CFMM_DISCRETE),
the \(\Gamma\)-cost mirror of theta (\(\sim\tfrac12\Gamma(\Delta X)^2\), \(1/\ell\) the curvature).
Net option-equivalent \(\mathrm{RnL}=\Upsilon^{\phi}-\mathrm{IL}\): so \(P_\pi=\Upsilon^{\phi}/L\)
is the **gross theta identity**, the net is \(P_\pi-\text{(hedge cost)}=\mathrm{RnL}/L\). Every
"\(\int\)" here is notational — the operative object is the discrete sum \(\sum\).

## Economic Meaning

π is the **perpetual single-tick LP-claim** — a covered-call / cash-secured-put on the pool
(Kristensen §3.1–3.2). Its theta \(\Theta=\partial_t\pi\) is the per-block **time-decay the LP
harvests as Uniswap-v3 swap fees** on the trading flow \(\Delta X\). The adaptive fee
\(\bar\phi^{\star}+\phi_{Z}\) is the **on-chain controller** — the Algebra `VolatilityOracle`
(realized \(\sigma_X\)) feeding `baseFee + adaptiveFee` — that holds gross fee revenue
\(\Upsilon^{\phi}/L\) equal to the fair theta-premium \(P_\pi\) across volatility regimes. The
gamma leg (IL) is the hedging cost the same flow \(\Delta X\) incurs; net LP P&L is
\(\mathrm{RnL}=\Upsilon^{\phi}-\mathrm{IL}\).

### Implementation pointer
No Solidity twin beyond the existing `@cryptoalgebra` VolatilityOracle (\(\sigma_X\)) and the
`baseFee + adaptiveFee` dynamic-fee plugin already cited in [FINANCE](./FINANCE.md).
