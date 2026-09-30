\[
     \begin{aligned}
       \sigma_K = 16.000 (\textrm{uint88}) \\
       L(\sigma) = 100.000 = 100.000 \times 1\mathrm{e}8 \\
       \bar L = \frac{L(\sigma)}{\sigma_K^2} \\
       \pi^{\sigma} = \bar L \times (\sigma(i(t))^2 - \sigma_K^2)
      \end{aligned}
\]
`
``
We can create a cron that serves as a foundry script that generates TickHIstory taht realizes a level of volatility. This is:

Given that we have 12 seconds per block AND we have a limit of 30_000_000 gas per block, we are faced an optimization problem:

We need the minimum number, ContractualVaultPayoff is a vault that tracks the contractual payoff value measured in numeriaire as vol

Define the constant:

\[
\begin{aligned}
	\mathrm{Window} = 24\times 60 \times 60
\end{aligned}
\]

and then:

\[
	\begin{aligned}
		\mathrm{Vol} (\mathrm{Window}; t) \, &= (\mathrm{Window})^{-1} \times \sum_{t=t_{\text{now}} - \text{Window}}^{t_{\text{now}}} \Big [i(t_{\text{now}}) \, - \, i_{\mu} (t)\Big ]^2
	\end{aligned}
\]

Define:

\[
	\begin{aligned}
		\mathrm{TickState} \{ \\
		 \quad i(t)\\
		 
		 \quad \textrm{update ()} \\
		 \quad \textrm{get ()} \\
 		\} 
	\end{aligned}
\]





TickState{
	update() --->  TickVariance{
	  |                   TickState.get()
	  |	 				              ----------v 
	  |              }                  update(   ,   )
}     |                                          ----^ 
       -------> TickAverage {                   |
	                i_{u}                       |
					update (tickState.get())    |
					get()   --------------------
                 }


- Now we want a realized-volatility factory. This is:

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
		\textrm{Window} = \sum_{i=0}^{\text{Window}/\bar dt} \bar t_i
	\end{aligned}
\]

which give us a sequence of timestamps \(T = \{t_i\}_{i=0}^{N}\quad N =\frac{\text{Window}}{\bar dt}\);

Define:

\[
	\begin{aligned}
		\sigma_{\text{factory}} : T \times \bar \sigma \to \text{TickPath} \equiv \{i\}_{j=0}^{N}
	\end{aligned}
\]


Note that \(\sigma_{\text{factory}}\) is a *discrete time control macro*, formally:

\[
	\begin{aligned}
		i(t_i) = A\cdot i(t_{i-1}) + B \cdot u \\
		\sigma (t_i) = C \cdot i(t_{i}) + D \cdot u 
	\end{aligned}
\]

with terminal condition: 

\[
	\begin{aligned}
		\sigma (N) = \bar \sigma 
	\end{aligned}
\]

# MODEL

Consider a net-flow numeriare diffusion as:

\[
	\begin{aligned}
		\Delta Q_{M} (t_i) \, &= \mu_F \, \bar dt \, + \, \sigma_{F} \, \Delta W (t_i)
	\end{aligned}
\]

From where on a fixed tick-bucket \([i_l, i_u]\):

\[
	\begin{aligned}
		\Delta p (t_{i}) \, = \, \Big (\frac{2 \, \mu_F}{L_{1/2}} \,\sqrt{p (t_i)} + \, \frac{\sigma_F^2}{(L_{1/2})^2}\Big) \, \bar dt \, + \, \sigma (p (t_i)) \, \Delta \, W (t_i)
	\end{aligned}
\]
Where \(\Delta W (t_i) = \sqrt{\bar dt} \, \cdot\, \epsilon \, (t_i); \quad \epsilon (t_i) \sim \mathcal{N} \, (0,1)\)


By making \(\sigma (p) = \delta \, \sqrt{p} \) we have under CPMM, \(\delta = \frac{2\, \sigma_F}{ L_{1/2}}\)

\[
	\begin{aligned}
		\Delta p (t_{i}) \, = \, \Big (\frac{2 \, \mu_F}{L_{1/2}} \,\sqrt{p (t_i)} + \, \frac{\sigma_F^2}{(L_{1/2})^2}\Big) \, \bar dt \, + \, \frac{2\, \sigma_F}{ L_{1/2}} \, \sqrt{p (t_i)} \, \Delta \, W (t_i)
	\end{aligned}
\]

since \(i(p(t)) = \log_{1.0001} \sqrt{p(t)} \), then:

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


Since \(\Delta i (t_i) \equiv i (t_i) - i (t_{i-1})\);

\[
	\begin{aligned}
		\Delta i (t_i) \, &= \, (A -1 )\, i (t_{i-1}) \, + \, B \, u
	\end{aligned}
\]

We pinned also a functional form of volatility with respecto to tickState as not being linear:

\[
	\begin{aligned}
		\sigma (i (t_i)) \, & = \frac{\sigma_F}
{L_{1/2}\ln(1.0001)\sqrt{p (i(t_i))}}\, 
	\end{aligned}
\]

And assign:

\[
	\begin{aligned}
		\mu (i (t_i))\, &= \, \frac{\mu_F}{L_{1/2}\sqrt{p \, (t_i)}}
-\frac{\sigma_F^2}{2L_{1/2}^2p (i(t_i))}
	\end{aligned}
\]

We need to find a linear map:

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


Then if the state-space represenation is writtin in logs. We have:

\[
	\begin{aligned}
		C = -\beta=- \ln (1.0001)
	\end{aligned}
\]
And:
\[
	\begin{aligned}
		i(t_i) = A\cdot i(t_{i-1}) + B \cdot u \\
		\ln \sigma (t_i) = C \cdot i(t_{i}) + D \cdot u 
	\end{aligned}
\]

with \(D = 0\) and \(\sigma (N) = \bar \sigma \iff \ln \sigma (N) = \ln \bar \sigma\), implies that we have found the enpoint of the path:

\[
	\begin{aligned}
		i(N) = \frac{\alpha \, -\, \ln \bar \sigma}{\ln (1.0001)}
	\end{aligned}
\]

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


Note that under this transformation we have:

\[
	\begin{aligned}
		i (t_j) \, = A\, i (t_{j-1}) + B\, u(t_j)\\
		\\ 
		\implies \, \langle B = 0;\, g(A) = g (\Delta i (t_j))\,\rangle \\
		\\
		
		g (i (t_j)) \, = \, g (\Delta i (t_j)) \, g \, ( i (t_{j-1}))
	\end{aligned}
\]


This ties the state to its lag under \(g\), but does not yet steer the path to target volatility.

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

**Out of scope for the formalization.** On-chain commit–reveal protocol, gas batching, Plank `TickState` / factory types.

**Forge evaluation order (consumer).** Obtain \(\varepsilon\) → solve \(\kappa^\star\) → emit \(\{i_j\}\).
