import [\(\mathrm{Exposure}\)](@spec/Exposure.spec/Exposure.md)

import [\(\mathrm{Pair}\)](@spec/Pair.spec/Pair.md)

# TYPE

\[
	\begin{aligned}
		\Delta Q_M^{L}
		&:\mathrm{amount}
		\\
		\\
		\mathrm{kind}
		&=
		\mathrm{dependent}
		\quad(\mathrm{Exposure},\,\mathrm{Pair})
	\end{aligned}
\]

# DEFINE

\[
	\begin{aligned}
		\Delta Q_M^{L}
		&=
		\mathrm{Exposure}_{\,1-\mathrm{asset\_index}(\mathrm{Pair})}
	\end{aligned}
\]

# REFINE
