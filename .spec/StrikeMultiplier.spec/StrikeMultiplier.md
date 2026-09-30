
# TYPE
\[
	\begin{aligned}
		\mathrm{StrikeMultiplier (r)}:= \{r \in \mathrm{u256} \mid \forall_{\mathrm{Strike (\star)}} \, \mathrm{Strike} (r\cdot \mathrm{Strike (\star)}) \, \vee \, \mathrm{Strike} \, \Big (\frac{\mathrm{Strike} (\star)}{r} \Big )\}
	\end{aligned}
\]



# DEFINE

# REFINE

\[
	\begin{aligned}
		\mathrm{inv}:: r_{\sqrt{P}} \to \frac{1}{1- r_{\sqrt{p}}} \leq 0
	\end{aligned}
\]
