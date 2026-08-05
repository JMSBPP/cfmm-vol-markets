
For a fixed  \(\bar L\) satisfies that satisfies:

\[
	\begin{aligned}
		\bar L \, = \, \sum_{i} \, L(i) \\
		L(i) \, = \, \bar L \, \ell \, (\cdot; i)
	\end{aligned}
\]

where, for \(\xi \neq 1\):

\[
	\begin{aligned}
		\ell \, (\xi, \#_{\Delta_i} ; i) \, &= \, \frac{\xi^{i}}{\sum_{j=1}^{\#_{\Delta_i}} \xi^{j}}; \quad \sum_{i} \, \ell \, (\cdot; i) = 1
	\end{aligned}
\]

and moves on the region:

\[
	\begin{aligned}
		p_{(\eta, \Delta_i)} \, ( i , \Delta^{I}, \bar L) = p_{(\eta, \Delta_i)} \, ( i , \Delta^{I}, \bar L \, + \, \Delta \bar L)
	\end{aligned}
\]

Let the liquidity participation ratio be

\[
\begin{aligned}
    p_{(\eta, \Delta_i)}^{\ell}
    \,&\equiv\,
    \frac{\Delta \bar L}{\bar L}.  \, \implies \,  (p_{\eta}(i)\, p_{(\eta, \Delta_i)}^{\ell} \, \Delta^I, p_{(\eta, \Delta_i)}^{\ell} \,\Delta^O)
\end{aligned}
\]


Then define the liquidity payoff by

\[
\begin{aligned}
    \pi^{-}
    \,&\equiv\,
    -\,\pi^{+}\!\left(
        p_{\eta}(i)\,
        \frac{\Delta \bar L}{\bar L}\,
        \Delta^I,\,
        \frac{\Delta \bar L}{\bar L}\,
        \Delta^O
    \right).
\end{aligned}
\]


Consider a fixed initial state-partition delta \(\bar \Delta_i \in \mathbb{N}\) and define:

\[
	\begin{aligned}
		\#_{\bar \Delta_i} \, &= \, \frac{| i_{+} \, - i_{-}|}{\bar \Delta i}
	\end{aligned}
\]

Given \(i_{\mu} \, \in [i_{-}, i_{+} ]\) We have a pricing structure 

\[
	\begin{aligned}
		p_{\eta , \Delta_i } \, (i) \, = \lambda^{i\, \Delta_i\, \eta}; \, \eta \in [0,1]
	\end{aligned}
\]

We denote pricing under a custom admissible state partition delta \(\Delta_i \neq \bar \Delta_i\) by \(p_{(\eta, \Delta_i )} \, (i)\) and we need the values \((i^{\star}, i^{\circ})\) such that:

\[
	\begin{aligned}
		p_{(\eta, \Delta_i )} \, (i) \, &= p_{(1/2, \bar \Delta_i)} \, (i^{\star})\, p_{(1/2, \bar \Delta_i)} \, (i^{\circ})
	\end{aligned}
\];

These are: tick pairs \((i^{\star}, i^{\circ})\) that satisfy \( (i^\star + i^\circ) \cdot \overline{\Delta}_i = 2 \cdot i \cdot \Delta_i \cdot \eta \)

If the agent enters its \(\eta_i\) inventory-weighted split define:

\[
	\begin{aligned}
		i^{\star} \, = \, \lfloor \eta_i \, \frac{2\, i \, \Delta_i \eta}{\bar \Delta_i} \rfloor; \quad i^{\circ} \, = \, \lfloor \frac{2\, i \, \Delta_i \eta}{\bar \Delta_i} \rfloor \, - \, i^{\star}
	\end{aligned}
\]

Once a \(\#_{\sigma}\)  it define a custom payoff:
 
\[
	\begin{aligned}
		\pi^{+} \, (\Delta_i;\cdot) \, &\equiv \, \#_{\bar \Delta_i} \, \sigma \, (\Delta_i;\cdot) 
	\end{aligned} \tag{1}
\]

Where:


\[
	\begin{aligned}
\sigma \, (\Delta_i;\cdot)\, &= \frac{1}{\#_{ \Delta_i}} \, \sum_{j=1}^{\#_{\bar \Delta_i}-1} \, (i_{-} \, + j \,  \Delta_i  \, - i_{\mu})^2\\
		&= \, (i_- - i_\mu)^2
        \, - \, \Delta_i \, (i_- - i_\mu) \, \#_{\bar \Delta_i} \, (\#_{\bar \Delta_i} - 1)
        \, + \, \Delta_i^2 \, \#_{\bar \Delta_i} \, (\#_{\bar \Delta_i} - 1) \, (2\#_{\bar \Delta_i} - 1) / 6
	\end{aligned}
\]


The price update rule given \(\bar L > 0\):


\[
	\begin{aligned}
		p_{(\eta, \Delta_i )} \, (\cdot ; i , \Delta^{I}, \bar L) \, &= \frac{\bar L \, p_{(\eta, \Delta_i )} \, (\cdot ; i)}{\bar L\, + \, p_{(\eta, \Delta_i )} \, (\cdot ; i)\, \Delta^I}
	\end{aligned}
\]


With output rule:

\[
	\begin{aligned}
		\Delta^O \, \, (\cdot ; i , \Delta^{I}) &= \, \bar L \, (p_{(\eta, \Delta_i)} \, ( i , \Delta^{I}, \bar L)\, - \, p_{(\eta, \Delta_i )} \, (i) \,)
	\end{aligned}
\]



Structurally we require:

\[
	\begin{aligned}
		\pi_\eta^{+}
			\, &= \, (p_{\eta}(i)\Delta^I)^{1/(1-\eta)} \, - \, (\Delta^O)^{1/(1-\eta)}
				\, - \, 1/(1-\eta) \, (\Delta^O)^{\eta/(1-\eta)} \, (p_{\eta}(i)\Delta^I - \Delta^O)
	\end{aligned}
\]



## VOLATILTIY TERM STRUCTURES

\[
	\begin{aligned}
		\sigma_{\eta} \,(\cdot) = \delta \cdot P_{(\eta, \Delta_i)} (i)^\eta
	\end{aligned}
\]

where the return volatility is given by:

\[
	\begin{aligned}
		σ_{\eta}^{(-1)}(\cdot) = \delta P_{(\eta, \Delta_i)}^{\eta -1} \, (i)^{\eta -1}
	\end{aligned}
\]


## DYNAMICS
Consider a sequence of ticks generated after \(\mathcal{E}:= \{ 1,\cdots ,N\} \) events the event-indexed tick sequence \( \{i_j\}_{j=1}^{N}\) 
such that for fixed integers \(i_{-}, i_{+} \in \mathbb{Z} \):

\[
	\begin{aligned}
		\forall_{j} \, i_j \, \in [i_{-}, i_{+} ]
	\end{aligned}
\]

It can enter as from \(i_{\mu}\): 

\[
	\begin{aligned}
		i_j = i_{\mu} \, + \alpha_j \, \Delta_i
	\end{aligned}
\]

Which defines:

\[
	\begin{aligned}
		\Delta_i (j) = \frac{i_j - i_\mu}{\alpha_j}
	\end{aligned}
\]


And thus we have the payoffs sequence \( \{\pi \, (\Delta_i (j))\}_{j=1}^{N}\) and we have \( \{\tilde \eta_j \}_{j=1}^{N}\)
(This seems to call from the definition above \[
	\begin{aligned}
		\#_{\bar \Delta_i} \, \sigma_{\bar \Delta_i} \, (\Delta_i;\cdot) \, &\equiv \, \sum_{j=1}^{\#_{\bar \Delta_i}-1} \, \bar \eta_j  \, (i_{-} \, + j \, \bar \Delta_i  \, - i_{\mu})^2
	\end{aligned}
\];
Define the occupation (binning) map

\[
\begin{aligned}
    b
    \,:\,
    \mathcal{E}
    \,\longrightarrow\,
    \{1\, \cdots \, \#_{\Delta_i}\},
\end{aligned}
\]

where \(b(j)\) denotes the admissible tick occupied by the \(j\)-th event. The induced tick probability measure is

\[
\begin{aligned}
    \bar\eta_k
    \,&\equiv\,
    \sum_{j\,:\,b(j)=k}
    \tilde\eta_j,
    \qquad
    k\in \, \{1\, \cdots \, \#_{\Delta_i}\}.
\end{aligned}
\]

By construction,

\[
\begin{aligned}
    \sum_{k=1}^{\#_{\bar\Delta_i}-1}
    \bar\eta_k
    =
    \sum_{j=1}^{N}
    \tilde\eta_j
    =
    1.
\end{aligned}
\]

Consequently, it preserves expectations

\[
\begin{aligned}
    \sum_{j=1}^{N}
    \tilde\eta_j
    \pi\!\left(b(j)\right)
    =
    \sum_{k=1}^{\#_{\bar\Delta_i}-1}
    \bar\eta_k
    \pi(k).
\end{aligned}
\]

Hence the weighted tick dispersion may be written equivalently as

\[
\begin{aligned}
    \#_{\bar\Delta_i}
    \sigma_{\bar\Delta_i}(\Delta_i;\cdot)
    &=
    \sum_{k=1}^{\#_{\bar\Delta_i}-1}
    \bar\eta_k
    \left(
        i_-
        +
        k\,\bar\Delta_i
        -
        i_\mu
    \right)^2.
\end{aligned}
\]

The moments are:

\[
	\begin{aligned}
        \mathbb{E}^{\tilde \eta} \, \Big [ \pi \Big] \, &= \, \sum_{j=1}^N \, \tilde \eta_j \, \pi_j \, \quad \, \sigma^{(\tilde \eta)} \, = \, \sum_{j}^{N}\tilde \eta_j \Big (\pi_j \, - \, \mathbb{E}^{\tilde \eta} \, \Big [ \pi \Big]\Big)^2
	\end{aligned}
\]


Since 

\[
	\begin{aligned}
	\forall_{i \in \mathcal{E}} \, \quad 
		\eta_i \, &= \, \frac{O}{O\, + p (i)\, I}; \quad 1 \, - \eta_i = \, \frac{p(i)\, I}{O\, + \,p(i)\, I}
	\end{aligned}
\]


Let, we introduce the intended multivariable feedback

\[ 
	\begin{aligned}
		I = I(\Delta i\, , \eta; \pi^{+}), \quad O = O(\Delta i\, , \eta\, ; \pi^{+}) 
	\end{aligned}
\]

on which agents rebalance inventories after observing payoff through trading with goal of delta hedging.

Then


\[
	\begin{aligned}
		\eta_i \, &= \, \eta_{i} \, (\Delta_i , \eta; \hat \pi^{+})
	\end{aligned}
\]


And from the normalized

\[
	\begin{aligned}
		\tilde \eta_i \, &= \, \frac{\eta_i}{\sum_{j\neq i} \eta_j} \\
		\\
		\implies \\
		\\
		\tilde \eta_i &= \tilde \eta_i \, (\Delta_i , \eta, \hat \pi^{+}) 
	\end{aligned}
\]


Let:

\[
	\begin{aligned}
		i_{\mu} \, &= \, \mathbb{E}^{(\tilde \eta)} [i] \\
		\\
		&= \, \sum_{b(j)} \tilde \eta_i \, (\Delta_i , \eta; \hat \pi^{+})  \, i_j \\
		\\
		\implies \\
		\\
		i_{\mu} \, &= \, i_{\mu} \, + \, \Delta_i \, \sum_{j}^{N} \, \tilde \eta_i \, (\Delta_i , \eta; \hat \pi^{+})  \, \alpha_j
	\end{aligned}
\]


Which induces  the rational-expectations restriction:

\[
	\begin{aligned}
		\sum_{j}^{N} \, \tilde \eta_i \, (\Delta_i , \eta; \hat \pi^{+})  \, \alpha_j \, &= \,  0
	\end{aligned}
\]
The expected signed displacement from \(i_{\mu}\) is zero under the trader’s inventory-induced probability measure.

Under which, given \(\alpha := \{\alpha_j\}_{j=1}^N, \tilde \eta := \{\tilde \eta_j\}_{j=1}^N\):

\[
\begin{aligned}
    \pi^+
    &=
    \sum_{j=1}^{N}
    \tilde \eta_i \, (\Delta_i , \eta; \hat \pi^{+}) \, \left(
        i_j-i_\mu
    \right)^2 \\
    &=
    \Delta_i^2
    \sum_{j=1}^{N}
    \, \tilde \eta_i \, (\Delta_i , \eta; \hat \pi^{+})  \,
    \alpha_j^2
\end{aligned}
\]


Define **variance capacity** as:

\[
	\begin{aligned}
		\Sigma ( \Delta_i , \eta \, ; \, \alpha, \tilde \eta, \pi^{+}) \, &= \, \sum_{j=1}^{N}
    \, \tilde \eta_i \, (\Delta_i , \eta; \hat \pi^{+})  \,
    \alpha_j^2 
	\end{aligned}
\]
Now:

\[
	\begin{aligned}
		\frac{\partial \pi^+}{\partial \Delta_i} \, &= \, 2\, \Delta_i \, \Sigma \, ( \Delta_i , \eta \, ; \cdot ) \, + \, \Delta_i^2 \, \frac{\partial \Sigma \, ( \Delta_i , \eta \, ; \cdot )}{\partial \Delta_i}
	\end{aligned}
\]


To start indetifying the structure of the relations of the parameters with the 
From the output rule we define the bonding curve curvature:

\[
	\begin{aligned}
		\kappa \, &\equiv \frac{\partial^2 \Delta^O}{\partial p_{(\eta, \Delta_i )} \, (i)^2} 
	\end{aligned}
\]

From where:

\[
	\begin{aligned}
		\frac{\partial^2 \Delta^O}{\partial p_{(\eta, \Delta_i )} \, (i)^2} \, &=  \frac{2\, \Delta^I \, \bar L^3}{ (\bar L \, + \, \Delta^I \, p_{(\eta, \Delta_i )} \, (i) )^3} \\
		\\
		\iff \\
		\kappa \, &= \, \frac{2\, \Delta^I \, \bar L^3}{ (\bar L \, + \, \Delta^I \, p_{(\eta, \Delta_i )} \, (i) )^3} \\ 
		\\
		\implies  \\
		\\
		\frac{\partial| \kappa |}{\partial \Delta_i} < 0
	\end{aligned}
\]


From there since \(\frac{\partial \Delta^O}{\partial |\kappa|} < 0\) then: \(\frac{\partial \Delta^O}{\partial \Delta_i} > 0\)

Since:

\[ 
	\begin{aligned}
		I' = I - \Delta^I, \quad O' = O + \Delta^O. 
	\end{aligned}
\]

Large slippage changes the inventory ratio \( \frac{O'}{I'}\); then for *manby states* we have:

\[
	\begin{aligned}
		\frac{\partial \tilde \eta_i }{\Delta_i} < 0
	\end{aligned}
\]

Thus there exists regions where:

\[
	\begin{aligned}
		\frac{\partial \pi^+}{\partial \Delta_i} \, \equiv  \, 2\, \Sigma \, + \Delta_i \, \frac{\partial \Sigma}{\partial \Delta_i} \, &= \, 0 
	\end{aligned}
	
\]


Since \(\tilde \eta_j\) is a latent state, we approximate by the iventory implied observer:

\[
	\begin{aligned}
		\tilde \eta_j \, &\sim \, \frac{\frac{O}{O \, + p_{(\Delta_i , \eta)} (j)\, I}}{\sum_{m \neq j} \Big [ \frac{O}{  \, O \, + p_{(\Delta_i , \eta)} (m)\, I}\Big]}
	\end{aligned}
\]


From setting \(\tilde \eta_j \) such that:

\[
	\begin{aligned}
		\frac{\partial \tilde \eta_i }{\Delta_i} < 0 \\
		\\
		\tilde \eta_i \propto \exp{(-\beta \mathcal{C}_{\kappa}\, (\Delta_i ; i))}
	\end{aligned}
\]


Starting from: 

\[
	\begin{aligned}
	    \mathcal{C}_{\kappa} \, (\Delta_i ) \, & = \mathcal{C} \, (\Delta_i )
	\end{aligned}
\]

such that:

\[
	\begin{aligned}
		\frac{\partial^2 \mathcal{C}_{\kappa} }{(\partial \Delta^O )^2} \, = |\kappa|
	\end{aligned}
\]

Where:


\[
	\begin{aligned}
		\mathcal{C}_{\kappa}\, (\Delta_i; j, \eta^{\star}) = \frac{\kappa(\Delta_i)}{2}(\Delta O(\Delta_i))^2 + \chi(\eta_j(\Delta_i) - \eta_j^\star)^2
	\end{aligned}
\]	

The problem is:
\[
	\begin{aligned}
		(\Delta_i^{\star} \, , \, \eta^{\star}) \, &\equiv \, \arg \max \Big [ \pi^{+} \, (\Delta_i , \eta ; \alpha) \, - \mathcal{C} \, (\Delta_i )\Big ]
	\end{aligned}
\]


Then \(\eta^{\star}\) solves:


\[
	\begin{aligned}
		\Sigma ( \Delta_i ,  \eta^{\star} \, ;\cdot) \, &= \, \sum_{j=1}^{N}
    \, \tilde \eta_i \, (\Delta_i , \eta^{\star} \, ;\cdot)  \,
    \alpha_j^2 
	\end{aligned}
\]

And \(\Delta_i^{\star}\) solves:

\[
    \begin{aligned}
		2\Delta_i^{\star} \Sigma (\Delta_i^{\star}) + (\Delta_i^{\star})^2 \Sigma (\Delta_i^{\star}) = \frac{\partial \mathcal{C}_{\kappa}}{\partial \Delta_i} (\Delta_i^{\star}) 
	\end{aligned}
\]


Gives:


\[
	\begin{aligned}
		\pi^{+} \, (\cdot)^{\star} &\equiv \,  \pi^{+} \, (\eta^{\star}, \Delta_i^{\star})
	\end{aligned}
\]


Define:
\[
	\begin{aligned}
		\mathcal{G}_{\Delta_i} \, &\equiv \, \frac{\partial \pi^+}{\partial \Delta_i}; \, \mathcal{G}_{\eta} \, \equiv \, \frac{\partial \pi^{+}}{\partial \eta} \\
		\\
		\mathcal{G}_{ff} \, &\equiv \mathcal{G}_{\Delta_i} \, + \, \mathcal{G}_{\eta}
	\end{aligned}
\]

And since the obrserved payoff before the input is \(\hat \pi^{+}\).

We have:

\[
	\begin{aligned}
		\mathcal{G}_{fb} \, &\equiv \, \frac{\partial \pi^+}{\pi^{+} \, (\cdot)^{\star}}
	\end{aligned}
\]




Then we stabish that

\[
\begin{aligned}
\lambda_t &\sim \mathcal U(0.6,1.0)
\\
N_t \mid \lambda_t &\sim \mathrm{Poisson}(\lambda_t)
\end{aligned}
\]


\[
\begin{aligned}
\bar \Delta y_t &\sim \mathcal U(19,21)
\\
\Delta y_{n,t} &\sim \mathrm{LogNormal}(\mu_t,\sigma_{\Delta y}^2),
\qquad
\sigma_{\Delta y}=1.2
\end{aligned}
\]

 ping -> {1,0}

How to generate/proxy such randomnesss on the EVM?
    --> There must be a kernel for a binomial distribution ?
	block.difficuly, block.prevrandao
  
\[
\mathbb E[\Delta \, y_{n,t}]
=
\exp\!\left(\mu_t+\frac{\sigma_{\Delta y}^2}{2}\right)
=
\bar \Delta y_t.
\]

\[
\mu_t
=
\ln(\bar \Delta y_t)-\frac{\sigma_{\Delta y}^2}{2}.
\]

\[
\mathbb{I}_{n,t}
=
\begin{cases}
+1, & \text{buy } X \text{ with } Y,\\
-1, & \text{sell } X \text{ for } Y,
\end{cases}
\qquad
\mathbb P(\mathbb{I}_{n,t}=1)=\mathbb P(\mathbb{I}_{n,t}=-1)=\frac12.
\]

\[
\Delta Y\, (t)
=
\sum_{n=1}^{N_t}
\mathbb{I}_{(n,t)} \, \Delta y_{(n,t)}.
\]

The deterministic proxy for this is: 

\[
	\begin{aligned}
		\Delta y\, (t) \, &= \, 19 \, + 1.0001^{\eta \, t^4}
	\end{aligned}
\]


