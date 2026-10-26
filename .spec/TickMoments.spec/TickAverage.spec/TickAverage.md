
import [\(W\)](../Window.spec)


Let's see how Panoptic, Uniswap V3 and Algebra handle this
# [REFS](./REFS.md)

# TYPE

- is a functional over a \(\texttt{TickPath}\):

\[
	\begin{aligned}
		\texttt{TickAverage} :: W \,\times \,\{i_j\}_{j=1}^{n<W} \, \mapsto \texttt{Tick}
	\end{aligned}
\]

//  set_tick does after it sets it is write the value on a stack data structure and keep count of the numbers that have entered the stack, while the number of items that have entered the stack is less than the window the following happens, the last item entered the stack pops and then it gets added the incoming value and then divided by the window size, then the resulting number is stored back to the stack. Then if a client queries it pops the item on the stack.


// Now. Once the number of items reaches the window size it writes the value to a storage data strucuture that now has keys to fetch the values. From now we can assume the keys are the current timestamp once it writes it it sets the currentValsLen back to one

// Let's formalize this:

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

