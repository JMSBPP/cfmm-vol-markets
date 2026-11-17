# TYPE

\[
	\begin{aligned}
		\mathrm{Pair}\,(X,Y)
		&::
		(\mathrm{token}_0,\,\mathrm{token}_1,\,\mathrm{asset\_index})
		\\
		\\
		\mathrm{kind}
		&=
		\mathrm{plain}
		\\
		\\
		\mathrm{token}_0
		&::
		\mathrm{Pair}\,(X,Y)
		\to
		\mathrm{Address}
		\\
		\mathrm{token}_1
		&::
		\mathrm{Pair}\,(X,Y)
		\to
		\mathrm{Address}
		\\
		\mathrm{asset\_index}
		&::
		\mathrm{Pair}\,(X,Y)
		\to
		\{0,1\}
		\\
		\\
		\{X,\,Y\}
		&=
		\{\mathrm{token}_0,\,\mathrm{token}_1\}
	\end{aligned}
\]

# DEFINE

\[
	\begin{aligned}
		\mathrm{pair}(a,\,b,\,\mathrm{asset\_idx})
		&::
		\mathrm{Address}
		\times
		\mathrm{Address}
		\times
		\mathrm{u256}
		\to
		\mathrm{Pair}\,(X,Y)
		\\
		\\
		a = b
		&\Longrightarrow
		\mathrm{revert}
		\\
		\mathrm{asset\_idx} > 1
		&\Longrightarrow
		\mathrm{revert}
		\\
		\\
		\mathrm{token}_0
		&=
		\min(a,\,b)
		\\
		\mathrm{token}_1
		&=
		\max(a,\,b)
		\\
		\mathrm{token}_0
		&<
		\mathrm{token}_1
		\\
		\\
		\mathrm{asset\_idx} = 0
		&\Longrightarrow
		\mathrm{asset} = a
		\\
		\mathrm{asset\_idx} = 1
		&\Longrightarrow
		\mathrm{asset} = b
		\\
		\mathrm{asset} = \mathrm{token}_0
		&\Longrightarrow
		\mathrm{asset\_index} = 0
		\\
		\mathrm{asset} = \mathrm{token}_1
		&\Longrightarrow
		\mathrm{asset\_index} = 1
		\\
		\\
		\mathrm{token}_{\mathrm{asset\_index}}
		&=
		\mathrm{asset}
		\\
		\mathrm{token}_{1-\mathrm{asset\_index}}
		&\neq
		\mathrm{asset}
	\end{aligned}
\]

# REFINE
