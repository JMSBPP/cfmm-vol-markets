
import [\(W\)](../Window.spec)


# TYPE


	\[
	\begin{aligned}
		\Big (\forall_{N} \mid N \leq W \, \wedge \, N \neq 1 \, :  \frac{\sum_{j=1}^{N} \, i_j}{W} > 1\Big )  \implies \texttt{ArithmeticMeanIsEVMImplementable}
	\end{aligned}
\]

> This is under the approach of definitning evm implementable as being able to store the full word
which requires beign greater than one, with decimals greater than one at the cost of some precision loss


\[
	\begin{aligned}
		i_{\text{max}} = 887272 \\
		i_{\text{min}}= - i_{\text{max}}
	\end{aligned}
\]

\[
	\begin{aligned}
		W_{\text{day}} \, &:= \, 24 \cdot 60 \cdot 60
	\end{aligned}
\]
\[
	\begin{aligned}
		\Big (i_j \leftarrow i_{\text{max}}, W \leftarrow W_{\text{day}}\Big) \implies \Big (\forall_{N} \mid N \leq W \, \wedge \, N \neq 1 \, : \,\sum_{j=1}^{N} \, i_j >  i_{\text{max}}\, \wedge \, \frac{\sum_{j=1}^{N} \, i_j}{W} > 1\Big )  
	\end{aligned}
\]


Under the above definition of arithmetic mean evm implementable clearly having a window size greater for some running \(N\) violates the implementable definition
\[
	\begin{aligned}
	    \texttt{not} \Big (\texttt{ArithmeticMeanIsEVMImplementable}\Big) \implies \, W > \sum_{j=1}^{N} \, i_j
	\end{aligned}
\]

The above is highly likely when:
- \(W\) is allowed to be *small enough*
- \(i_j < W\) and there is low variance around \(i_j\) on the generator of the tick sequence

> The above explanation is to be more ellaborated

\[
	\begin{aligned}
		i_{\mu} \, (W) & = \frac{1}{W} \, \sum_{j=1}^{W} \, i_j
	\end{aligned}
\]

\( -887272\leq  i_{\mu} \, (W)\leq 887272. \)


# ARITHMETIC_MEAN EVM

Note that if we store:

\[
	\begin{aligned}
		\texttt{sstore} (\sum_{j=1}^W i_j) \iff \texttt{sstore} (W \cdot i_{\mu} \, (W))
	\end{aligned}
\]


More generally:
\[ 
	\begin{aligned}
		f_{\texttt{ts}}: \texttt{Tick} \,(\texttt{ts}) \leadsto \texttt{Tick} \,(\texttt{ts})\\
		
		M_f(i_1,\ldots,i_W) = f^{-1}\left( \frac{1}{W}\sum_{j=1}^{W} f(i_j) \right)
	\end{aligned}
\]

such that:
- Signed domain: \\(f\\) must accept negative, zero, and positive ticks.
- Monotonicity: preserve the ordering of ticks.
- Bounded computation: all intermediate values must have known bounds.
- Determinism: fixed-point evaluation must have defined rounding and error limits.
- Tick-spacing compatibility: the final result must be quantized to the appropriate spacing \\(\Delta_i\\).




## OLD v PENDING
Let's see how Panoptic, Uniswap V3 and Algebra handle this
# [REFS](./REFS.md)

# TYPE

- is a functional over a \(\texttt{TickPath}\):

\[
	\begin{aligned}
		\texttt{TickAverage} :: W \,\times \,\{i_j\}_{j=1}^{n<W} \, \mapsto \texttt{Tick}
	\end{aligned}
\]

// set_tick ( \(i_{n+1}\))
//   W <- \(\texttt{windowSize} \, (\texttt{TickAverage})\) 
//   n <- \(\texttt{currentValsLen} \, (\texttt{TickAverage})\)
//   \(\sum_{j=1}^{n} \log_{2} \, i_j \) <- \(\texttt{pop} \, (\texttt{TickAverage})\)
//   if n == W {
//      \(\texttt{write_on_storage} (\texttt{TickAverage}, \, \frac{\sum_{j=1}^{W} \log_{2} \, i_j}{W})\)
//      \(\texttt{setCurrentValsLen} \, (\texttt{TickAverage}, 1)\)
//   while n < W {
//         \(\texttt{push} \, (\texttt{TickAverage},  \sum_{j=1}^{n+1} \log_{2} \, i_j)\) 
//         \(\texttt{setCurrentValsLen} \, (\texttt{TickAverage}, n + 1) \)
//  }
//

For some fixed natural \(W\) less than \(2^{256}\) and a sequence of ticks of length \(W\), define:
This is we pick a tick spacing \(\Delta_i = 2\)

\[
	\begin{aligned}
		 i_{\mu} \, (W) \, &= \, \Big (\prod_{j=1}^{W} i_{j}\Big)^{\frac{1}{W}}	\\
		 \iff \\
	     i^{\texttt{log}}_{\mu} (W) = \log_{2} \, i_{\mu} (W) \, &= \, \frac{\sum_{j=1}^{W} \log_{2} \, i_j}{W}  \\
		\iff \\
        i_{\mu} (W) \, &= \, 2^{\frac{\sum_{j=1}^{W} \log_{2} \, i_j}{W}}
	\end{aligned}
\]

Consider \(W \, = \, 3\) and \(i_{1} = 1440\); \(i_{2} = 1350\); \(i_{3} = 1500\) then:

\[
	i_{\mu} (3) = 1428
\]

\[
	\begin{aligned}
		g_1 = 1440 \\
		g_2 = 1944000 \\
		g_3 = 2916000000
	\end{aligned}
\]	

\[
	\begin{aligned}
		\frac{\log_{2} g_1}{1} = 10 \\
		(\frac{\log_{2} g_2}{2} = 20, \, \frac{\log_{2} \, i_{2}}{2} = 7 ) \\
		\implies \\
		\log_{2} f (i_{2}) &= \frac{\log_{2} g_2}{2} \, - \frac{\log_{2} g_1}{1} \, + \, \frac{\log_{2} \, i_{2}}{2} \\
		&= 17
	\end{aligned}
\]

For what values of \(i, \log_{2} (i) < 1\) 

Now:

\[
	\begin{aligned}
		(i_{\mu} (1) = 1440, 1 ) \\
		(i_{\mu} (2) = 1394, 2) \\
	    (i_{\mu} (3) = 1428,3)
	\end{aligned}
\]

