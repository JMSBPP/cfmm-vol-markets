
import [MEV](feat/plank::notes/VOLATILITY_INSTRUMENTS.md)

Consider the state, input and output vectors respectively:

\[
	\begin{aligned}
		x &= 
		\begin{bmatrix}
			\phi \\
			\nu \\
			\pi^{\phi} \\
			\pi^{\varphi}
		\end{bmatrix} \, \quad 		u_{\text{ex}}= 
		\begin{bmatrix}
			\Delta Q_X \\
			\Delta Q_M \\
			\sigma^2 \, (i (t))
		\end{bmatrix}
		\, \quad y = \begin{bmatrix}
			\pi^\sigma \\
			\widehat\pi^\sigma\
		\end{bmatrix} \quad u_{\text{en}} = \, \begin{bmatrix} \tau_{\text{MEV}} \\ \phi_M \\ \phi_X \end{bmatrix} \quad \Theta_{\sigma} = \begin{bmatrix} \sigma_K^2 \\ \#_{\sigma} \\ s_{\upsilon}\\ \Delta Q_{\upsilon}\end{bmatrix} 
	\end{aligned}
\]


\(\pi^{\varphi} \equiv \pi^{\phi} - \pi^{\text{LVR}}\)

For feedback conctrol we have:

\[
	\begin{aligned}
		e^{\sigma} \, &= |\pi^{\sigma} - \widehat \pi^{\sigma}|
	\end{aligned}
\]
> Note from the above we can compute and/or get \( (\pi^{\text{LVR}}, \mathbb{P}_{\text{ARB}}, \lambda_{\text{ARB}}, \pi^{\text{ARB}} , \pi^{\text{linear}} )\)

which induce the state-space representation:


\[
	\begin{aligned}
		\begin{cases}
			x_{t+1} &= \, \partial_{(t+1,t)} \, x_t \, + \, \partial_{(x,u)}\, u_t \\
			y_t &= \, \partial_{(y,x)}\, x_t \, + \, \partial_{(y,u)} \, u_t
		\end{cases}
	\end{aligned}
\]


Note that under \(\otimes_{\phi}\) we have:
	
\[
	\begin{aligned}
		\begin{bmatrix} (1-\phi_X)(1- \tau_{\text{MEV}}) \\ (1 - \phi_M)(1 - \tau_{\text{MEV}}) \\ (1- \phi_X)( 1 - \phi_M)\end{bmatrix}\equiv \nabla \phi \approx \partial_{(x,x)} (\phi)\,+ \,\partial_{(x,u)} (\phi)
		\end{aligned}
\]


\[
	\begin{aligned}
		\phi_X (t) \, &= \Phi \, (\Theta_{\phi}; \sigma^2 (i (t)))
	\end{aligned}
\]

This is, we are assuming \(\forall_t \phi_M (t) = \bar \phi_M\)


Because of the theorem that syays that \((\beta_j , \gamma_j)\) does not control for \(\lambda_{\text{MEV}}\) we fix them for all t. And for simplicity we fix \((\beta_R, \gamma_R, \alpha_R)\):

Note: 

\[
	\begin{aligned}
		\partial \pi^{\sigma} \, &\approx \, \frac{\partial \, \pi^{\sigma}}{\partial \, \phi} \, \phi \, + \, \frac{\partial \, \pi^{\sigma}}{\partial \, \pi^{\phi}} \, \pi^{\phi} \, + \, \frac{\partial \, \pi^{\sigma}}{\partial \, \nu} \, \nu \, + \, \frac{\partial\, \pi^{\sigma}}{\partial \Delta Q_X} \, \Delta Q_X \, + \frac{\partial\, \pi^{\sigma}}{\partial \Delta Q_M} \, \Delta Q_M + \cdots \\
		\\
		&\approx + \cdots + \, \frac{\partial \, \pi^{\sigma}}{\partial \sigma^2} \, \sigma^2 \, + \frac{\partial \, \pi^{\sigma}}{\partial \, \tau_{\text{MEV}}} \, \tau_{\text{MEV}} \, + \, \frac{\partial \, \pi^{\sigma}}{\partial \, \phi_M} \, \phi_M \, + \, \frac{\partial \, \pi^{\sigma}}{\partial \, \phi_{X}} \, \phi_X
	\end{aligned}
\] 


Using the rule:

\[
	\begin{aligned}
		\partial \, \pi^{\sigma} \, &= \, \partial \Big [ \sum_{i_K} L (i_k) \, \pi^{l} \, (\sigma \, (i_k; \cdot))\Big] \\
		\implies \\
        \frac{\partial \, \pi^{\sigma}}{\partial \, \pi^{\phi}} \, &= \, \sum_{i_K} \, \frac{\partial L \, (i_K)}{\partial \pi^{\phi}} \, \pi^{l} \, (\sigma \, (i_k; \cdot))
	\end{aligned}
\]

And:

\[
	\begin{aligned}
		\frac{\partial \, \pi^{\sigma}}{\partial L (i_K)} &= \pi^{l} \, (\sigma \, (i_k; \cdot))
	\end{aligned}	
\]


Structurally we have by definition of fee payoff:

\[
	\begin{aligned}
		\pi^{\phi} \, &\equiv \phi_M \, \Delta Q_M \, + \, p_{(\eta , \Delta_i)} \, \phi_X \, \Delta Q_M \\
		\implies \\
		\frac{\partial \pi^{\phi}}{\partial \phi}\, &= \, \frac{\partial \phi_M}{\partial \phi} \, \Delta Q_M + p_{(\eta, \Delta_i)}\, \frac{\partial \phi_X}{\partial \phi} \Delta Q_X \\
		\\
		&= \frac{\Delta Q_M}{(1 -  \tau_{\text{MEV}})(1 - \phi_X)} \, +\, \frac{p_{(\eta, \Delta_i)}\,\Delta Q_X}{(1 -  \tau_{\text{MEV}})(1 - \phi_M)}
	\end{aligned}
\]

Note also:

\[
	\begin{aligned}
		(\frac{\partial \pi^{\sigma}}{\partial \phi_M} , \frac{\partial \pi^{\sigma}}{\partial \phi_X}) \, &= \, (p_{(\eta \, \Delta_i)}\, \Delta Q_X\, , \Delta Q_M)
	\end{aligned}
\]


Now for high hazard rate of MEV the ratio of utilization rate is expected to have a raise on the numerator by the defnition itself of the rate and a reduction on the denominator by discouraging liquidity. Thus making the overall effect expansionary on the utilization and we assume constant


\(\bar{\mathcal{G}}_{(\nu, \lambda_{\text{MEV}})} := \frac{\partial \nu}{\partial \lambda_{\text{MEV}}} > 0\):


Since our goal is to control:

\[
	\begin{aligned}
	\boxed{
\mathcal G_{\widehat\pi^\sigma,\tau_{\mathrm{MEV}}}
:=
\frac{\partial\widehat\pi^\sigma}
{\partial\tau_{\mathrm{MEV}}}
\bigg|_{\lambda_{\mathrm{MEV}}}
}

	\end{aligned}
\]



We define the protocol mev only control channel as:

\[
\boxed{
\frac{\partial\widehat{\pi}^\sigma}
{\partial\tau_{\mathrm{MEV}}}
=

\frac{\partial\widehat{\pi}^\sigma}{\partial L}
\frac{\partial L}{\partial\pi^\phi}
\frac{\partial\pi^\phi}{\partial\phi}
\frac{\partial\phi}{\partial\nu}
\frac{\partial\nu}{\partial\tau_{\mathrm{MEV}}}.
}
\]


Note on \(\partial_{(y, u)}\) the term:

\[
	\begin{aligned}
		\frac{\partial \pi^{\sigma}}{\partial \sigma^2} \in \Big ( \underbrace{\Delta Q_{\upsilon}}_{\text{user input}}, \frac{\partial \pi^{\sigma}}{\partial \sigma^2}(\lambda_{\text{MEV}}) \Big)
	\end{aligned}
\]

Equating the contractual payoff with the payoff realized by the
liquidity kernel gives the target replication relation

\[
    \pi^\sigma
    \equiv^{R}
    \widehat{\pi}^{\sigma},
\]

where

\[
    \pi^\sigma
    =
    \Delta Q_v^{\star}
    \bigl(
        \sigma^2(i(t))-\sigma_K^2
    \bigr)^+,
\]

and

\[
    \widehat{\pi}^{\sigma}
    =
    \sum_{i_K}
    L(i_K)\,
    \pi^l
    \bigl(
        \sigma(i_K;\Theta_\sigma)
    \bigr).
\]

Thus, solving for \(\tau_{\text{MEV}}\) on the minimization:
> note: This needs verification

\[
\boxed{
\begin{aligned}
\tau_{\mathrm{MEV}}^\star
=
1-
\frac{1}{\Delta Q_v^\star}
\Bigg[
&
\sum_{i_K}
\pi^{l}\bigl(\sigma(i_K;\cdot)\bigr)
\frac{\partial L(i_K)}{\partial\pi^\phi}
\Bigg]
\,
\Bigg[
\frac{\Delta Q_M}{1-\phi_X}
+
\frac{
p_{(\eta,\Delta_i)}\Delta Q_X
}{
1-\phi_M
}
\Bigg]
\frac{\partial\phi}{\partial\nu}
\frac{\partial\nu}{\partial\tau_{\mathrm{MEV}}}.
\end{aligned}
}
\]

