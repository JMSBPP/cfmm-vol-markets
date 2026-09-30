\[
     \begin{aligned}
       \sigma_K = 16.000 (\textrm{uint88}) \\
       L(\sigma) = 100.000 = 100.000 \times 1\mathrm{e}8 \\
       \bar L = \frac{L(\sigma)}{\sigma_K^2} \\
       \pi^{\sigma} = \bar L \times (\sigma(i(t))^2 - \sigma_K^2)
      \end{aligned}
\]

Given:



\[
	\begin{aligned}
		\sigma_{W} (t) \equiv \mathrm{Vol} (\mathrm{Window}; t) \, &= (\mathrm{Window})^{-1} \times \sum_{t=t_{\text{now}} - \text{Window}}^{t_{\text{now}}} \Big [i(t_{\text{now}}) \, - \, i_{\mu} (t)\Big ]^2
	\end{aligned}
\]


\[
	\begin{aligned}
		\sigma_{\text{factory}} : T \times \bar \sigma \to \text{TickPath} \equiv \{i\}_{j=0}^{N}
	\end{aligned}
\]

\[
	\begin{aligned}
		\sigma (t_N) = \bar \sigma 
	\end{aligned}
\]

# PRE-REQ

## **Window**
-------
The convention is, lets stablish a fixed time frequency \(\bar dt\). and start \(t_0 \leftarrow \bar t\); This gives:

\[
	\begin{aligned}
		t_1 \leftarrow t_0 + \bar dt \\
		\cdots \\
		t_i \leftarrow t_{i-1} + \bar dt
	\end{aligned}
\]


\[
\begin{aligned}
	\mathrm{Window} = 24\times 60 \times 60
\end{aligned}
\]

\[
	\begin{aligned}
		\textrm{Window} = \sum_{i=0}^{\text{Window}/\bar dt} \bar t_i
	\end{aligned}
\]


## **WeinerGenerator**

 \(\Delta W (t_i) = \sqrt{\bar dt} \, \cdot\, \epsilon \, (t_i); \quad \epsilon (t_i) \sim \mathcal{N} \, (0,1)\)
 
 
# MODEL

Consider a net-flow numeriare diffusion as:

\[
	\begin{aligned}
		\Delta Q_{M} (t_i) \, &= \mu_F \, \bar dt \, + \, \sigma_{F} \, \Delta W (t_i)
	\end{aligned}
\]

------


## **CEVLocalTickVolatility**


\[
	\begin{aligned}
		\sigma (i (t_i)) \, & = \frac{\sigma_F}
{L_{1/2}\ln(1.0001)\sqrt{p (i(t_i))}}\, 
	\end{aligned}
\]


## **CEVLocalTickDrift**


\[
	\begin{aligned}
		\mu (i (t_i))\, &= \, \frac{\mu_F}{L_{1/2}\sqrt{p \, (t_i)}}
-\frac{\sigma_F^2}{2L_{1/2}^2p (i(t_i))}
	\end{aligned}
\]



## **TickDynamics**

\(\Delta i (t_i) \equiv i (t_i) - i (t_{i-1})\);

By making \(\sigma (p) = \delta \, \sqrt{p} \) we have under CPMM, \(\delta = \frac{2\, \sigma_F}{ L_{1/2}}\)


\[
	\begin{aligned}
		\Delta i (t_i) \, = \, \frac{1}{\ln(1.0001)}
\left[
\frac{\mu_F}{L_{1/2}\sqrt{p \, (t_i)}}
-\frac{\sigma_F^2}{2L_{1/2}^2p (t_i)}
\right]\bar{dt}
\\
&+
\frac{\sigma_F}
{L_{1/2}\ln(1.0001)\sqrt{p (t_i)}}
\Delta W (t_i), \\

i(t_i) \, \in \, [i_l, i_u]
	\end{aligned}
\]


since \(i(p(t)) = \log_{1.0001} \sqrt{p(t)} \), then is equivalent to:


\[
	\begin{aligned}
		\Delta p (t_{i}) \, = \, \Big (\frac{2 \, \mu_F}{L_{1/2}} \,\sqrt{p (t_i)} + \, \frac{\sigma_F^2}{(L_{1/2})^2}\Big) \, \bar dt \, + \, \frac{2\, \sigma_F}{ L_{1/2}} \, \sqrt{p (t_i)} \, \Delta \, W (t_i)
	\end{aligned}
\]

### Theorem:

Under CEV, and CPMM \(\textrm{TickPath}\) that realized \(\bar \sigma\) has the endpoint:

\[
	\begin{aligned}
		i(t_N) = \frac{\alpha \, -\, \ln \bar \sigma}{\ln (1.0001)}
	\end{aligned}
\]

#### *Proof*

\[
	\begin{aligned}
		\ln \bigg ( \sigma (i (t_i))\bigg ) &= \ln (\sigma_F) - \Big ( \ln L_{1/2} + \ln \ln 1.0001 + \ln \sqrt{p (i (t_i))}\Big) \\
		&= \, \underbrace{
\ln\left(
\frac{\sigma_F}
{L_{1/2}\ln(1.0001)}
\right)
}_{\alpha}
-
\underbrace{\ln(1.0001)}_{\beta}
\,i(t_i)
	\end{aligned}
\]

So **\(\ln\sigma\) is affine in tick \(i\)**, and, the original nonlinear relation can be recovered as

$$
\boxed{
\sigma (i)=e^{\alpha-\beta \, i}.
}
$$


Then:

\[
	\begin{aligned}
		i(t_N) = \frac{\alpha \, -\, \ln \bar \sigma}{\ln (1.0001)}
	\end{aligned}
\]














-- OLD


Since \(\Delta i (t_i) \equiv i (t_i) - i (t_{i-1})\);

Define:

\[
	\begin{aligned}
		g \, ( i (t_j)) \, \equiv \, \exp (\beta \, \cdot \, i (t_j))
	\end{aligned}
\]


Note:

\[
	\begin{aligned}
		g (\Delta i (t_j)) \, &= \frac{g \, ( i (t_j))}{g \, ( i (t_{j-1}))}; \, \quad i (g(i (t_j))) = \frac{\ln(g(i (t_j)))}{\beta}
	\end{aligned}
\]


Note that under this transformation we have the lag identity
\(g(i(t_j)) = g(\Delta i(t_j))\, g(i(t_{j-1}))\).


And the state-space:

\[
	\begin{aligned}
		g(i(t_j)) = g(\Delta i(t_j))\, g(i(t_{j-1})) \\
		\ln\sigma\big(i(t_j)\big)=\alpha - \beta \, i (t_j)
	\end{aligned}
\]

State and output:

\[
	\begin{aligned}
		x_j &= g\big(i(t_j)\big)=e^{\beta\, i(t_j)}, \\
		y_j &= \ln\sigma\big(i(t_j)\big)=\alpha-\ln x_j,
	\end{aligned}
\]

with lag identity \(x_j = x_{j-1}\cdot g(\Delta i_j)\).

Treat exogenous PRNG shocks as the input, \(u_j=\varepsilon_j\) (seed⊕`blockhash`). Multiplicative recursion with explicit gains:

\[
	\begin{aligned}
		x_j &= A\, x_{j-1}\, B_j(\varepsilon_j), \qquad
		B_j(u)=\exp(b_j\, u), \\
		A &= \exp(\texttt{lnGainA}), \qquad
		\texttt{lnGainA}
		= \frac{(\alpha-\ln\bar\sigma-\beta\, i_0)-\sum_{j=1}^{N} b_j\varepsilon_j}{N}.
	\end{aligned}
\]

**Canonical \(b_j\) (Lamperti).** The per-step log-gain schedule is deterministic (not solved from \(\varepsilon\)):

\[
	\begin{aligned}
		b_j &= \beta\,\sigma_j\,\sqrt{\bar dt},
	\end{aligned}
\]

so a unit shock moves \(\ln x=\beta i\) by \(b_j\varepsilon_j\), and the induced tick Euler step has volatility exactly \(\sigma_j\). Here \(\{\sigma_j\}\) is a fixed schedule (constant \(\sigma\), or \(\sigma(i)\) along a reference path); it is not re-fit from the realized shocks. With this choice,

\[
	\begin{aligned}
		i_j &= i_{j-1} + \frac{\texttt{lnGainA}}{\beta} + \sigma_j\sqrt{\bar dt}\,\varepsilon_j.
	\end{aligned}
\]

Shock stream enters only via the finite sum \(\sum b_j\varepsilon_j\) (cron: one pass). Proved: \(x_N=e^{\alpha}/\bar\sigma\), \(y_N=\ln\bar\sigma\), lag identity \(x_j=x_{j-1}\cdot g(\Delta i_j)\), \(\sigma=e^{\alpha}/x\).
