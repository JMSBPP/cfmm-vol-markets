import [\(\mathcal{L}\)](@spec/LiquidityChunk.spec/LiquidityChunk.md)

import [\(\pi^{c|p}\)](@spec/CoveredCall.spec/CoveredCall.md)

import [\(\pi^{\mathrm{RAN}}\)](@spec/RangeAccrual.spec/RangeAccrual.md)

# TYPE

\[
	\begin{aligned}
		\pi(\bar L; j)
		&::
		\mathcal{L}
		\times
		j
		\\
		\\
		\mathrm{kind}
		&=
		\mathrm{dependent}
		\quad(\mathcal{L},\, j)
	\end{aligned}
\]

# DEFINE

\[
	\begin{aligned}
		\forall\, j
		\quad
		\pi(\bar L; j)
		&=
		\pi^{c|p}(\bar L; j)
		+
		\pi^{\mathrm{RAN}}(\bar L; j)
	\end{aligned}
\]

# REFINE
