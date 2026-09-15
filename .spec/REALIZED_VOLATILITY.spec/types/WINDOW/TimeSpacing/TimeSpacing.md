# [TYPE:: TIME_SPACING](https://github.com/JMSBPP/cfmm-vol-markets/issues/117)

\[
\begin{aligned}
\mathrm{TimeSpacing}
&\leftarrow
\bar{dt}
:=
\{dt \in \mathrm{u8} \mid 1 \leq dt \leq 10\}
\\[1em]
\mathrm{intro}
&::
\mathrm{u8} \to \mathrm{TimeSpacing} + \bot
\\
\mathrm{intro}(dt)
&=
\begin{cases}
\bar{dt} & \text{if } dt \in \mathrm{TimeSpacing} \\
\bot & \text{if } dt \notin \mathrm{TimeSpacing}
\end{cases}
\end{aligned}
\]
