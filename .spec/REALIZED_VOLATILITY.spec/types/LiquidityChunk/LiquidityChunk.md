# [TYPE:: LIQUIDITY_CHUNK](MAIN_REF# MODEL)

[CEVLocalTickVolatility](../CEVLocalTickVolatility/CEVLocalTickVolatility.md) · [LiquidityChunkMinter](../LiquidityChunkMinter/LiquidityChunkMinter.md)

Distinct from `VegaTarget`. This carrier represents a mintable concentrated-liquidity position; `VegaTarget` remains an economic target pending [#131](https://github.com/JMSBPP/cfmm-vol-markets/issues/131).

\[
\begin{aligned}
s
&:\mathrm{TickSpacing}
,\quad
\mathrm{TickSpacing}(x)=
\begin{cases}
1 & x=0\\
x & 1\le x\le 200\\
200 & x>200
\end{cases}
\\
\mathrm{LiquidityTick}
&\leftarrow
\Sigma\,s:\mathrm{TickSpacing}.\ i:\mathrm{int24}
\quad\text{where }i\bmod s=0
\\
\mathrm{LiquidityChunk}
&\leftarrow
\Sigma\,s:\mathrm{TickSpacing}.\ \{
i_l:\mathrm{LiquidityTick}\ s,
i_u:\mathrm{LiquidityTick}\ s,
L:\mathrm{u128}
\}
\\
i_l&<i_u
\\
L&>0
\\[1em]
\mathrm{intro}
&::
\mathrm{u256}
\to\mathrm{int24}
\to\mathrm{int24}
\to\mathrm{u128}
\to\mathrm{LiquidityChunk}
\\[1em]
\mathrm{packPanoptic}
&::
\mathrm{LiquidityChunk}\to\mathrm{u256}
\\
\mathrm{packPanoptic}
&=
\underbrace{i_l}_{24}
\mathbin{\|}\underbrace{i_u}_{24}
\mathbin{\|}\underbrace{0}_{80}
\mathbin{\|}\underbrace{L}_{128}
\\
\mathrm{unpackPanoptic}
&::
s\to\mathrm{u256}\to\mathrm{LiquidityChunk}
\end{aligned}
\]

Invalid construction reverts descriptively:

- `TickOutOfBounds`
- `TickNotAligned`
- `TicksMisordered`
- `ZeroLiquidity`
- `ReservedBitsNonzero`

Internal representation is typed fields, not the packed word. Define behaviors:

- [`LiquidityChunk.btt`](./LiquidityChunk.btt) — `intro`
- [`LiquidityChunkPack.btt`](./LiquidityChunkPack.btt) — `pack_panoptic`
- [`LiquidityChunkUnpack.btt`](./LiquidityChunkUnpack.btt) — checked `unpack_panoptic`

The public `intro` boundary accepts raw spacing and ticks, applies the shared
`cfmm-types::TickSpacing` normalization, then constructs both dependent ticks.
