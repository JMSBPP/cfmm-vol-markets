# [TYPE:: LIQUIDITY_CHUNK_MINTER](MAIN_REF# MODEL)

[LiquidityChunk](../LiquidityChunk/LiquidityChunk.md) · [IO](../IO/IO.md) · [PRD #130](https://github.com/JMSBPP/cfmm-vol-markets/issues/130)

The native V3, Algebra Integral, and V4 calldata do not form one safe flat tuple. Their union is a venue-indexed family over the existing closed venue universe.

\[
\begin{aligned}
V
&\in
\{\mathrm{V3},\mathrm{Algebra},\mathrm{V4}\}
\\
\mathrm{LiquidityChunkMint}(V)
&\leftarrow
(\mathrm{adapter},\mathrm{Pool}(V),\mathrm{payer},
\mathrm{beneficiary},\mathrm{LiquidityChunk},\mathrm{Context}(V))
\\
\mathrm{Pool}(V).\mathrm{tickSpacing}
&=\mathrm{LiquidityChunk}.\mathrm{tickSpacing}
\\[1em]
\mathrm{Context}(\mathrm{V3})
&=\varnothing
\\
\mathrm{Context}(\mathrm{Algebra})
&=\{\mathrm{leftoversRecipient}\}
\\
\mathrm{Context}(\mathrm{V4})
&=\{\mathrm{Pair},\mathrm{Registry}(\mathrm{V4}),\mathrm{salt},\mathrm{hookData}\}
\\[1em]
\mathrm{MintReceipt}(\mathrm{V3})
&=\{\mathrm{amount0},\mathrm{amount1}\}
\\
\mathrm{MintReceipt}(\mathrm{Algebra})
&=\{\mathrm{amount0},\mathrm{amount1},\mathrm{liquidityActual}\}
\\
\mathrm{MintReceipt}(\mathrm{V4})
&=\{\mathrm{callerDelta},\mathrm{feesAccrued},\mathrm{positionKey}\}
\\[1em]
\mathrm{ioMint}
&::
\mathrm{LiquidityChunkMint}(V)
\to\mathrm{IO}(\mathrm{LiquidityChunkMint}(V))
\\
\mathrm{runMint}
&::
\mathrm{IO}(\mathrm{LiquidityChunkMint}(V))
\to\mathrm{Option}(\mathrm{MintReceipt}(V))
\\[1em]
\mathrm{Eff}
&=[
\mathrm{VenueMintCall},
\mathrm{ERC20TransferFrom},
\mathrm{AuthenticatedCallbackContext},
\mathrm{V4UnlockSettlement}
]
\end{aligned}
\]

`Some(receipt)` is successful execution; `None` is adapter-call failure. No parallel Outcome wrapper is introduced because the existing `Outcome()` is fixed to `Option(u256)`.

Constructor errors:

- `PoolSpacingMismatch`
- `ZeroAdapter`
- `ZeroPayer`
- `ZeroBeneficiary`

Adapters own callback payment and settlement. The payer authorizes exact ERC-20 `transferFrom`. Callback context binds the exact pool/manager and active command hash; nested execution is rejected. The V4 adapter is the native position owner and records the beneficiary-bound `positionKey`.

Mint is positive-only. Burn/remove, Permit2, native ETH, fee-on-transfer tokens, StateView, and VegaTarget conversion are outside this type slice.

First define behavior: [`LiquidityChunkMinterAlgebra.btt`](./LiquidityChunkMinterAlgebra.btt).
It constructs and validates the Algebra-indexed command only; pool execution,
callback authentication, exact payer funding, and receipt construction remain
later define/refine slices.
