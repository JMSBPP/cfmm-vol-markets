

Consider a sequence of ticks generated after \(N\) events \( \{i_j\}_{j=1}^{N}\) given by the generating f
such that for fixed integers \(i_{-}, i_{+} \in \mathbb{Z} \):

\[
	\begin{aligned}
		\forall_{j} \, i_j \, \in [i_{-}, i_{+} ]
	\end{aligned}
\]

Consider a fixed initial state-partition delta \(\bar \Delta_i \in \mathbb{N}\) and define:

\[
	\begin{aligned}
		\#_{\bar \Delta_i} \, &= \, \frac{| i_{+} \, - i_{-}|}{\bar \Delta i}
	\end{aligned}
\]

Given \(i_{\mu} \, \in [i_{-}, i_{+} ]\)


\[
	\begin{aligned}
\sigma_{\bar \Delta_i} \, (\Delta_i;\cdot)\, &= \frac{1}{\#_{\bar \Delta_i}} \, \sum_{j=1}^{\#_{\bar \Delta_i}-1} \, (i_{-} \, + j \, \bar \Delta_i  \, - i_{\mu})^2\\
		&= \, (i_- - i_\mu)^2
        \, - \, \Delta_i \, (i_- - i_\mu) \, \#_{\bar \Delta_i} \, (\#_{\bar \Delta_i} - 1)
        \, + \, \Delta_i^2 \, \#_{\bar \Delta_i} \, (\#_{\bar \Delta_i} - 1) \, (2\#_{\bar \Delta_i} - 1) / 6
	\end{aligned}
\]

A representative trader has asset-cash inventory to \((I, O)\)  market, define \(p \equiv \frac{O}{I}\):

which has its respective \(i (p)\) one-to-one coordinate, Thus, for \(p(i)\):

\[
	\begin{aligned}
		\eta_i \, &= \, \frac{O}{O\, + p (i)\, I}; \quad 1 \, - \eta_i = \, \frac{p(i)\, I}{O\, + \,p(i)\, I}
	\end{aligned}
\]


Then define: 

\[
	\begin{aligned}
		\tilde \eta_i \, &= \, \frac{\eta_i}{\sum_{j\neq i} \eta_j}
	\end{aligned}
\]
\[
	\begin{aligned}
		\#_{\bar \Delta_i} \, \sigma_{\bar \Delta_i} \, (\Delta_i;\cdot) \, &\equiv \, \sum_{j=1}^{\#_{\bar \Delta_i}-1} \, \bar \eta_j  \, (i_{-} \, + j \, \bar \Delta_i  \, - i_{\mu})^2
	\end{aligned}
\];

By construction:

\[
	\begin{aligned}
		\sum_{j=1}^{\#_{\bar \Delta_i}-1} \, \tilde \eta_j &= 1 
	\end{aligned}
\]


And define a custom payoff:

\[
	\begin{aligned}
		\pi^{+} \, (\Delta_i;\cdot) \, &\equiv \, \#_{\bar \Delta_i} \, \sigma_{\bar \Delta_i} \, (\Delta_i;\cdot) 
	\end{aligned} \tag{1}
\]


With replication argument, for \(\Delta_i \, \in \mathbb{N}; \, \Delta_i \in [1,200]\), with:
\[
	\begin{aligned}
		\Delta^2 \pi(\bar \Delta_i) = \pi(\bar \Delta_i+1) - 2\pi(\bar \Delta_i) + \pi(\bar \Delta_i-1)
	\end{aligned}
\]

\[
	\begin{aligned}
		\pi^{+} \, (\Delta_i;\cdot) \, &\equiv \, \pi^{+} \, (\Delta_i) \, (\Delta_i \, - \, \Delta_i \, (i_\mu))\, + \Delta \, \pi^{+} \, (\Delta_i)\, + \, \cdots  \\
		& \cdots \, \sum_{\bar \Delta_i = 1}^{\Delta (i_\mu)} \, \max (0, \bar \Delta_i \, -\, \Delta_i ) \, \Delta^2 \pi^+(\bar \Delta_i) \,   + \sum_{\bar \Delta_i =  \Delta (i_\mu)}^{200} \max (0, \Delta_i \, -\, \bar \Delta_i ) \, \Delta \pi^{+}(\bar \Delta_i)
	\end{aligned}
\]


Given \(\bar \eta \in (0,1)\). We have a pricing structure 

\[
	\begin{aligned}
		p_{\bar \eta} \, (\Delta_i ;i) \, = \lambda^{i\, \Delta_i\, \bar \eta}
	\end{aligned}
\]

And the price update rule given \(\bar L > 0\):


\[
	\begin{aligned}
		p_{\bar \eta} \, (\cdot ; i , \Delta^{I}, \bar L) \, &= \frac{\bar L \, p_{\bar \eta} \, (\cdot ; i)}{\bar L\, + \, p_{\bar \eta} \, (\cdot ; i)\, \Delta^I}
	\end{aligned}
\]


and output rule:

\[
	\begin{aligned}
		\Delta^O \, \, (\cdot ; i , \Delta^{I}) &= \, L \, (p_{\bar \eta} \, (\cdot ; i , \Delta^{I}, \bar L)\, - \, p_{\bar \eta} \, (\Delta_i ;i) \,)
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



Note that:

\[
	\begin{aligned}
		p_{\eta} \, (i) =  p_{1/2} \, (\lfloor \eta \, i \rfloor) \, p_{1/2} \, (i \, - \, \lfloor \eta \, i \rfloor)
	\end{aligned}
\]

However given a fixed \(\bar \Delta_i \) that defines tick spacing for any two ticks \((i,j)\):

\[
	\begin{aligned}
		i \, = j + \bar \Delta_i
	\end{aligned}
\]

And we denote pricing under a custom admissible state partition delta \(\Delta_i \neq \bar \Delta_i\) by \(p_{(\eta, \Delta_i )} \, (i)\) and we need the values \((i^{\star}, i^{\circ})\) such that:

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

Now the above \(\bar L\) satisfies:

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


## DYNAMICS

(di = 20 ,i = 100, i_l = -120, i_u = 120, L(i) = 1e18, Y = 100e18)

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



## IMPLEMENTATION DETAILS

[]~/cfmms-playground/cfmm-replicationPlank/lib/plankified-univ3/plank/lib/math/sqrt_price_math.plk

getNextSqrtPriceFromAmount0RoundingUp = fn (sqrtPX96: u256, liquidity: u256, amount: u256, add: bool) {}


getNextSqrtPriceFromAmount0RoundingUp(uint160 sqrtPX96, uint128 liquidity, uint256 amount, bool add)

Unistrata {
 
`src/UnistrataHook.sol` {
			 `src/libraries/VarianceLib.sol`, 
			 `NavLib.sol`, 
			 `WaterfallLib.sol`
		  } ---> PositionManager --> tokenId. {
			   - deposit ->  { RangeFeeAccrual ; ShortCallIl}
			   
	       }
	
	Shizo  {
		
	
	}
	
	Mochi-Yiedld {}
	
	Centrifuge {
		test/core/spoke/unit/BalanceSheet.t.sol:: BalanceSheetTestDeposit{ 
		    testDepositERC6909
 	 		
			 testDepositERC20

	    }
	}
	
}
	

#

