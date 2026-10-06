


CEFI
- Implied volatility is locked on the primum paid *ex-ante*:


\[
	\begin{aligned}
		\bigg (p_{\pi}^{BS} \Big (\sqrt{P} , \sigma_{BS-IV} \Big) \bigg )_{(\sqrt{P_K}, T)} \, = \, \bigg(p_{\pi}^{\text{mkt}}\bigg)_{(\sqrt{P_K}, T)}
	\end{aligned}
\]


DEFI:
## REQUIREMENTS
- Integrating with CEVStateRunner and CEVStateView

At each timestep \(t = t_0 + j \bar \Delta t\).

> NOTE: Each \(t\) is fabricated from a swap
Given a fixed liquidity chunk \(\bar L\) we are querying its [principal](https://github.com/cryptoalgebra/Algebra/src/contracts/periphery/libraries/PositionValue.sol::principal)

\[
	\begin{aligned}
		\Theta_{\text{val}} (\bar L; j)  \, &= \pi \, (\bar L; j+1) - \pi \, (\bar L; j) \\
		\\
		\Delta Q_M \, (\bar L; j)\, &= \, \Delta Q_M (\bar L;\sqrt{P} (j) ) \\
		
		\delta \, (\bar L; j)\, &= \, \frac{\Delta Q_M (\bar L;\sqrt{P} (j) )}{2} \\
		\\
		\sigma \, (\bar L; j) \, &= \, 2\, \cdot \frac{\Theta_{\text{val}} (\bar L; j)}{\delta \, (\bar L; j)} \\
		\Theta \, (\bar L; j ) \, &= \Theta_{\text{val}} (\bar L; j) \times \delta \, (\bar L; j) \, \times\sigma \, (\bar L; j) 
	\end{aligned}
\]


Now, given \([t_0, t_N] =\{j\}_{j=1}^{N} = \text{seq} (j; \#_{\text{swaps}}))\)

> This is the implementation uni v3 uses for doing integrals and is also to be referenced by discrete calculus integrals

Note that \(j\) is such that there are isomorphisms:

\[
	\begin{aligned}
		\Delta: j \to (\Delta_X, \Delta_M, \sqrt{P}) \\
		\phi: j \to \phi_{\text{val}}
	\end{aligned}
\]
\[
	\begin{aligned}
		\Theta_{\text{val}} \, (\bar L; \{j\}_{j=1}^{N}) \, &= \, \int_{t_0}^{t_N} \, \Theta_{\text{val}} (\bar L; j (t)) \, \mathrm{d}
		t \\
		\\
	    \delta \, (\bar L; \{j\}_{j=1}^{N})\, &= \, \int_{t_0}^{t_N} \delta \, (\bar L; j (t)) \, \mathrm{d}t \\ 
		\\
		\sigma \, (\bar L; \{j\}_{j=1}^{N}) \, &= \, 2\, \frac{\Theta_{\text{val}} \, (\bar L; \{j\}_{j=1}^{N})}{\delta \, (\bar L; \{j\}_{j=1}^{N})} \\
		\\
		\Theta \, (\bar L; \{j\}_{j=1}^{N}) \, &= \Theta_{\text{val}} \, (\bar L; \{j\}_{j=1}^{N}) \, \times \, \delta \, (\bar L; \{j\}_{j=1}^{N}) \, \times \, \sigma \, (\bar L; \{j\}_{j=1}^{N}) \\
		\\
		\mathrm{V} \, (\{j\}_{j=1}^{N}) \, &= \, \int_{t_0}^{t_N} \, \upsilon\, (\Delta (j (t))) \, \mathrm{d}t
   	\end{aligned}
\]

Note; that the function \(v\) is such that \(V\) is a valid swap volume metric, thus we need to define formally what "valid" is

\[
	\begin{aligned}
		\Big (\forall_{j}\, \phi (j) = \bar \phi \Big ) \, \implies \, \bar \phi \, \mathrm{V} \, (\{j\}_{j=1}^{N}) \, = \, \Theta_{\text{val}} \, (\bar L; \{j\}_{j=1}^{N}) \, \wedge \, \mathrm{V} \, (\{j\}_{j=1}^{N}) \, = \, \frac{\sigma \, (\bar L; \{j\}_{j=1}^{N})}{2} \, \delta \, (\bar L; \{j\}_{j=1}^{N})
	\end{aligned}
\]
\[
	\begin{aligned}
		\bar \delta (\bar L; \{j\}_{j=1}^{N})\, &= \text{average depth} \, \quad \wedge \,  \Big (\forall_{j}\, \phi (j) = \bar \phi \Big ) \, \implies \, \sigma \, (\bar L; \{j\}_{j=1}^{N}) \, \approx \, 2\, \frac{\mathrm{V} \, (\{j\}_{j=1}^{N})}{N\, \bar \delta (\bar L; \{j\}_{j=1}^{N})}
	\end{aligned}
\]

When the fee rate varies over the window take. Given \(\Upsilon_{\phi} \, (\bar L;\{j\}^{N})\):

\[
	\begin{aligned}
		\sigma \, (\bar L; \{j\}_{j=1}^{N}) = 2 \, \frac{\Upsilon_{\phi} \, (\bar L;\{j\}^{N})}{N\, \bar \delta (\bar L; \{j\}_{j=1}^{N}) }
	\end{aligned}
\]

> NOTE: The above algebraic relationships allows type parametrization. For instance:

\[
	\begin{aligned}
		\Delta Q_M \, (\bar L, \delta) \, = \, 2\, \delta
	\end{aligned}
\]


Then we have the first constructor for the type implied volatility as:

\[
	\begin{aligned}
		\sigma_{\phi} (\{j\}_{j=1}^{N}) = \sigma \, (\bar L; \{j\}_{j=1}^{N})
	\end{aligned}
\]

Consider the realized volatility type \(\sigma_{RV} \, (\{j\}_{j=1}^{N})\); then define the payoff type constructor:

\[
	\begin{aligned}
		\pi (\sigma_{RV}; \{j\}_{j=1}^{N}) &= \frac{\int_{t_0}^{t_N} \, \delta \, (\bar L; j) \, \sigma_{RV} \, (\{j\}_{j=1}^{N}) \, \mathrm{d}t}{2}
	\end{aligned}
\]

and then define the payoff type constructor:

\[
	\begin{aligned}
		\pi (\bar L, \sigma_{RV}; \{j\}_{j=1}^{N}) \, &\equiv \, \Upsilon_{\phi} \, (\bar L;\{j\}^{N}) \, - \, \pi (\sigma_{RV}; \{j\}_{j=1}^{N})
	\end{aligned}
\]

And the following must hold. This is to be proved:

\[
	\begin{aligned}
		\pi (\bar L, \sigma_{RV}; \{j\}_{j=1}^{N}) \, &= \, \frac{\int_{t_0}^{t_N} \,\delta \, (\bar L; j) \, \Big ( \, \sigma \, (\bar L; j) - \, \sigma_{RV} \, (\{j\}_{j=1}^{N})\Big) \, \mathrm{d}t }{2}
	\end{aligned}
\]
> Note that this allow to parametrize the payoff if the value of inmplied volatility is constant, or of liquidity depth


Define:

\[
	\begin{aligned}
		\alpha (\bar L, \sigma_{RV}; \{j\}^{N}) \, &= \, \frac{\Upsilon_{\phi} \, (\bar L;\{j\}^{N})}{\pi (\sigma_{RV}; \{j\}_{j=1}^{N})} 
	\end{aligned}
\]
