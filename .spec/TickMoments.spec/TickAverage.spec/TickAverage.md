
import [\(W\)](../Window.spec)


# TYPE



Nota that a pre-requisite of this is having clear tick semantics. And clear tick semantics depn on tick spaing


int24 internal constant MAX_TICK_SPACING = 500;
int24 internal constant MIN_TICK_SPACING = 1;


Let's work the tickSpacing semantics




## OLD v PENDING
- The current implementation has the flaw of log2 not receiving negative inputs but tikc domain is defined over some negative integers too
- The proposed solution is use for the log calculation a always positive tick measure from where no important information is lost
- Consider this 2 tick observation case \(i_1 = -1500, i_2 = 1500\). Clearly
	\(i_{\mu} = 0\) but using  \(i_{\mu}^{\texttt{log}} = \frac{ \log_2 (\mid i_1 \mid ) + \log_2 ( \mid i_2 \mid )}{2} \neq 0\); assuminig the proces is taking raw abs values for ticks
	Then for our case we want \(g (i_1, i_2) > 0; \quad \log_2 (g (i_1, i_2)) = 0\). For this case the condition is 
	\(g(i_1 , i_2) = 1\). But in particular we want
	
	\[
		\begin{aligned}
			i_{\mu}^{\texttt{log}} \Big ( g(i_1 , i_2) \Big ) \, &=  \, i_{\mu}
		\end{aligned}
	\]
	
   - But what is the problem with accumalating the raw arithmetic average ?
      res: sub-optimal precission loss
     
	 If you were to have \(i_1 = 1 , i_2 = 2\) then \(i_{\mu} = 1.5\) since we have to transform back to tick we use the floor to transform giving us \(\hat{i_{\mu}} = \lfloor i_{\mu} \rfloor = 1\) then:
	 
	 \[
		\begin{aligned}
			e_{\mu}\,  &:= \, \mid \hat{i_{\mu}} - i_{\mu} \mid \\ 
			&= \, \frac{1}{2}
		\end{aligned}
	 \]
	 
	 When can this be problematic ? since we always round to ticks we always have precision loss function that are not on tick dimensions, or in other words  \(e_{\mu} \in (0,1)\)
 This is we are not concerned unless \(e_{\mu} \in [1,N]; \, N < \infty\)  can this be a case ?



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

