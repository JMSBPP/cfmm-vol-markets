
import [MEV](feat/plank::notes/VOLATILITY_INSTRUMENTS.md)
<

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
		\end{bmatrix} \quad u_{\text{control}} = \tau_{\text{MEV}}
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
			x_{\text{next}} &= \, \partial_{(x,x)} \, x \, + \, \partial_{(x,u)}\, u \\
			y &= \, \partial_{(y,x)}\, x \, + \, \partial_{(y,u)} \, u
		\end{cases}
	\end{aligned}
\]


We use the notation/convention:


> note: \(\tilde{\phi}\) is the sigmoid
\[
	\begin{aligned}
		\partial_{(x,u)} \, (\phi) &= \, 
		\begin{bmatrix}
			\frac{\partial \phi}{\partial \Delta Q_M} \, (\phi_M, \tau_{\text{MEV}}) \\
			\frac{\partial \phi}{\partial \Delta Q_X} \, (\phi_X, \tau_{\text{MEV}}) \\
			\frac{\partial \phi}{\partial \sigma^2} \, (\Theta_{\phi}; \nu_t) \\
			\frac{\partial \phi}{\partial \tau_{\text{MEV}}}
		\end{bmatrix}\, \quad \, 
		\partial_{(x,x)} \, (\phi)
		\begin{bmatrix}
			\frac{\partial \phi}{\partial \tilde{\phi} \, (\, ; \, )} \\
			\frac{\partial \phi}{\partial \pi^{\phi}} \\
			\frac{\partial \phi}{\partial \pi^{\varphi}}
		\end{bmatrix}
	\end{aligned}
\]

Note that under \(\otimes_{\phi}\) we have:
	
\[
	\begin{aligned}
		\begin{bmatrix} (1-\tilde{\phi_X})(1- \tau_{\text{MEV}}) \\ (1 - \tilde{\phi_M})(1 - \tau_{\text{MEV}}) \\ (1- \tilde{\phi_X})( 1 - \tilde{\phi_M})\end{bmatrix}\equiv \nabla \phi \approx \partial_{(x,x)} (\phi)\,+ \,\partial_{(x,u)} (\phi)
		\end{aligned}
\]


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


Note on \(\partial_{(y, u)}\) the term:

\[
	\begin{aligned}
		\frac{\partial \pi^{\sigma}}{\partial \sigma^2} \in \Big ( \underbrace{\Delta Q_{\upsilon}}_{\text{user input}}, \frac{\partial \pi^{\sigma}}{\partial \sigma^2}(\lambda_{\text{MEV}}) \Big)
	\end{aligned}
\]


Then we have the problem:


\[
\inf_{\tau_{\text{MEV}}} \, \left\| \Delta Q_v^{\star} - \frac{\partial \widehat\pi^{\sigma}}{\partial \sigma^2}(x, \tau_{\text{MEV}}, \lambda_{\text{MEV}}) \right\|
\] subject to [Theorem 20](MEV)




