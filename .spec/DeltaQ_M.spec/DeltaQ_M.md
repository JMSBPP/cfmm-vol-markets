import [\(\mathcal{L}\)](@spec/LiquidityChunk.spec/LiquidityChunk.md)

import [\(\sqrt{P}(j)\)](@spec/ObsStep.spec/ObsStep.md)

import [\(\mathrm{Pair}\)](@spec/Pair.spec/Pair.md)

# TYPE

\[
	\begin{aligned}
		\bar L &:\mathcal{L} \\
		\\
		\mathrm{Exposure}
		&\leftarrow
		(\mathrm{amount}_0,\,\mathrm{amount}_1)
		\\
		\\
		\mathrm{Exposure}(\bar L;\sqrt{P}(j))
		&:\mathrm{Exposure}
		\\
		\\
		\Delta Q_M(\bar L;\sqrt{P}(j),\,\mathrm{Pair})
		&:\mathrm{amount}
		\\
		\\
		\mathrm{kind}
		&=
		\mathrm{dependent}
		\quad(\mathcal{L},\,\sqrt{P}(j),\,\mathrm{Pair})
	\end{aligned}
\]

# DEFINE

\[
	\begin{aligned}
		L &:= \bar L.L \\
		a &:= \sqrt{P}(i_l) \\
		b &:= \sqrt{P}(i_u) \\
		s &:= \sqrt{P}(j) \\
		\\
		\mathrm{amount}_0(x,y,L)
		&=
		L\Bigl(\frac{1}{x}-\frac{1}{y}\Bigr)
		\qquad(0<x<y)
		\\
		\\
		\mathrm{amount}_1(x,y,L)
		&=
		L\,(y-x)
		\qquad(x<y)
		\\
		\\
		\mathrm{Exposure}(\bar L;j)
		&=
		\mathrm{Exposure}(\bar L;\sqrt{P}(j))
		\\
		\\
		s\le a
		&\Longrightarrow
		\mathrm{Exposure}(\bar L;s)
		=
		\bigl(\mathrm{amount}_0(a,b,L),\,0\bigr)
		\\
		\\
		a<s<b
		&\Longrightarrow
		\mathrm{Exposure}(\bar L;s)
		=
		\bigl(\mathrm{amount}_0(s,b,L),\,\mathrm{amount}_1(a,s,L)\bigr)
		\\
		\\
		s\ge b
		&\Longrightarrow
		\mathrm{Exposure}(\bar L;s)
		=
		\bigl(0,\,\mathrm{amount}_1(a,b,L)\bigr)
		\\
		\\
		\Delta Q_M(\bar L;j,\,\mathrm{Pair})
		&=
		\Delta Q_M(\bar L;\sqrt{P}(j),\,\mathrm{Pair})
		\\
		\\
		\Delta Q_M(\bar L;\sqrt{P}(j),\,\mathrm{Pair})
		&=
		\mathrm{Exposure}(\bar L;\sqrt{P}(j))_{\,1-\mathrm{asset\_index}(\mathrm{Pair})}
	\end{aligned}
\]

# REFINE

\[
	\begin{aligned}
		a=0
		&\Longrightarrow
		\mathrm{undefined}
		\\
		a<s<b \;\wedge\; s=0
		&\Longrightarrow
		\mathrm{undefined}
	\end{aligned}
\]
