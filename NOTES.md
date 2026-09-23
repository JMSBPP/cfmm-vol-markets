For the LiquidityChunkMinterAlgebra track

> NOTE: Heavy user-approved code-chunks, including test setup.

- Compose **FlowToken** (transfer + balanceOf) for both pool tokens; tests at **>=0.8.30**; Algebra core via **`.bytecode/algebra`** (`AlgebraIntegralDeployer` under `test/helpers/Algebra/`).
- **`IntegralPoolBootstrap.bootstrap(vm)`** → `ReadyPool` (createPool + initialize). Use in **run_mint** integration tests, not to re-assert `mint_algebra` field copies.
- **`test/helpers/NoOpCallback.plk`** — `IAlgebraMintCallback` stub until `run_mint` adds payment.

### `io_mint` vs `mint_algebra` tests

- **`mint_algebra`** — constructor gate only (`LiquidityChunkMinterAlgebra.t.sol` + BTT).
- **`io_mint`** — pure `IO { inner: command }` wrap; **no Forge duplicate** (no second harness selector, no identity test). Covered by Plank compile on `LiquidityChunkMinter.plk` + **`run_mint(Algebra)`** BTT/integration (bootstrap, adapter, pool).

### Module kinds under `test/helpers/Algebra/`

- **Deployer** — bytecode only (`AlgebraIntegralDeployer`).
- **Integration bootstrap** — deployer + on-chain init (`IntegralPoolBootstrap` → `ReadyPool`).
