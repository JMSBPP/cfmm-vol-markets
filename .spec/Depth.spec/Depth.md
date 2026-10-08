> carrier [#155](https://github.com/JMSBPP/cfmm-vol-markets/issues/155)

import [\(\Delta Q_M\)](@spec/DeltaQ_M.spec/DeltaQ_M.md)

import [\(\mathcal{L}\)](@spec/LiquidityChunk.spec/LiquidityChunk.md)

import [\(\sqrt{P}(j)\)](@spec/ObsStep.spec/ObsStep.md)

# TYPE

\[
	\begin{aligned}
		\delta(\bar L;\sqrt{P}(j))
		&::
		\Delta Q_M(\bar L;\sqrt{P}(j))
		\to
		\mathrm{amount}
		\\
		\\
		\mathrm{kind}
		&=
		\mathrm{dependent}
		\quad(\mathcal{L},\,\sqrt{P}(j))
	\end{aligned}
\]

# DEFINE

\[
	\begin{aligned}
		\delta(\bar L;\sqrt{P}(j))
		&=
		\frac{\Delta Q_M(\bar L;\sqrt{P}(j))}{2}
		\\
		\\
		\Delta Q_M(\bar L;\sqrt{P}(j))
		&=
		2\,\delta(\bar L;\sqrt{P}(j))
	\end{aligned}
\]

# REFINE
