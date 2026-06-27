




fst --> tdd --> { init {} , run {} }


.sol {
	ContollerEntryPoint.sol :: IHook.sol {
		addr plkWrapper;
		
		beforeSwap() {
		   LibCall.callContract(plkWrapper,msg.amount,abi.encodeWithSignature(IHooks.beforeSwap)
	
	    }
	}

}


Fixed-Income CFMM {}
<
- How do we engineer any financial product from tuning parameters on dynamic fee kernel AND the
]'liquidityDensity function ?


- Start with single LP position and create a swap continuum


---> This is the state is 

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

