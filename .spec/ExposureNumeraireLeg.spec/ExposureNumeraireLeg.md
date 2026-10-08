import [\(E_{X/Y}\)](@spec/Exposure.spec/Exposure.md)

import [\(\mathrm{Pair}\,(X,Y)\)](@spec/Pair.spec/Pair.md)

# TYPE

\[
	\begin{aligned}
		\Delta Q_M^{L}
		&::
		E_{X/Y}(L)
		\to
		\mathrm{amount}
		\\
		\\
		\mathrm{kind}
		&=
		\mathrm{dependent}
		\quad(E_{X/Y},\,\mathrm{Pair}\,(X,Y))
	\end{aligned}
\]

# DEFINE

\[
	\begin{aligned}
		\Delta Q_M^{L}
		&=
		E_{X/Y}(L)_{\,1-\mathrm{asset\_index}(\mathrm{Pair})}
	\end{aligned}
\]

# REFINE
