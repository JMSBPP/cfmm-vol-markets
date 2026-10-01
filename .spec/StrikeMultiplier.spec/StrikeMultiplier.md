
# TYPE
	\[
	\begin{aligned}
		r_{\sqrt{P}}\,  \in \mathrm{u256} \\
		r_{\sqrt{P_K}}\, > 0 \\
	    r^{+}_{\sqrt{P}} (r_{\sqrt{P}}) :: r_{\sqrt{P_K}} \to r_{\sqrt{P_K}} \\
		r^{-}_{\sqrt{P}} (r_{\sqrt{P}}) :: r_{\sqrt{P_K}} \to r_{\sqrt{P_K}} \\
		\\
		\forall_{r_{\sqrt{P}}} \,r^{+}_{\sqrt{P}} (r_{\sqrt{P}}) + r^{-}_{\sqrt{P}} (r_{\sqrt{P}}) = 2 	\\
		r^{(-1)} \, (r_{\sqrt{P}}) :: r_{\sqrt{P}} \to r_{\sqrt{P}} \\
		\forall_{r_{\sqrt{P}}} r^{(-1)} \, (r^{(-1)} \, (r_{\sqrt{P}})) = 1
	\end{aligned}
	\]




> This is to be placed on SqrtPriceX96Pair.md on its .spec/
For \(\sqrt{P_L}, \sqrt{P_U} \in \mathrm{Q64.96}\):

\[
	\begin{aligned}
		pc ::(\sqrt{P_L}, \sqrt{P_U}); \\
		pc (\sqrt{P_L}, \sqrt{P_U}) :: \sqrt{P_L} \times  \sqrt{P_U}  \to pc \\
	    pc (\sqrt{P_L}, \sqrt{P_U}) = pc (\sqrt{P_U}, \sqrt{P_L}) \\
		\\
		\sqrt{P_L} (pc):: pc \to \sqrt{P_L} \\
		\sqrt{P_U} (pc) :: pc \to \sqrt{P_U}
	\end{aligned}
\]

Now, for \(\sqrt{P_K} \in \mathrm{Q64.96}\):

\[
	\begin{aligned}
		r_{\sqrt{P}} (pc) :: pc \to r_{\sqrt{P}} \\
		\sqrt{P_L} (pc,\sqrt{P_K}) :: pc \times \sqrt{P_K} \, \to \,  \mathrm{Q64.96} \\
		\\
	    \sqrt{P_U} (pc,\sqrt{P_K}) :: pc \times \sqrt{P_K} \, \to \,  \mathrm{Q64.96} \\
		\\
		\forall_{pc, \sqrt{P_K}} \quad \sqrt{P_L} \Big (pc,\sqrt{P_K}\Big) = \sqrt{P_L} (pc) \quad \wedge \quad \sqrt{P_U} (pc,\sqrt{P_K}) = \sqrt{P_U} (pc)
	\end{aligned}
\]


> This is to be placed on the Strike.md


Consider some \(\sqrt{P} \in \mathrm{Q64.96}\) and some \(\Delta \in \mathrm{u256}\):

\[
	\begin{aligned}
        \sqrt{P_K} \, (r_{\sqrt{P}},\Delta,\sqrt{P}) :: r_{\sqrt{P}} \times \sqrt{P} \times \Delta \to \sqrt{P_K} \\
		\sqrt{P_K} \, \, (r_{\sqrt{P}},\Delta,0 ) = 0
	\end{aligned}
\]


# DEFINE

# REFINE

\[
	\begin{aligned}
		\mathrm{inv}:: r_{\sqrt{P}} \to \frac{1}{1- r_{\sqrt{p}}} \leq 0
	\end{aligned}
\]
