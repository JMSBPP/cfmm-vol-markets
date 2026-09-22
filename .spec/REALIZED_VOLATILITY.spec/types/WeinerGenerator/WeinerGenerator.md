[MAIN](.spec/REALIZED_VOLATILITY.md## **WeinerGenerator**)
[COMM](.spec/REALIZED_VOLATILITY.spec/communication.mmd)
[BLOB](git blob 44a6f306093537d16a3aaa8d419d218ec924dc1a → `.spec/REALIZED_VOLATILITY.md`)
[EPS](https://fravoll.github.io/solidity-patterns/randomness.html)

\[
\begin{aligned}
\Delta W (t_i) &= \sqrt{\bar dt} \, \cdot\, \epsilon \, (t_i) \\
\epsilon (t_i) &\sim \mathcal{N} \, (0,1)
\end{aligned}
\]

EVM \(\epsilon\): sealed-seed ⊕ future `blockhash` PRNG (Solidity Patterns — Randomness). Not single-block `blockhash` alone.
