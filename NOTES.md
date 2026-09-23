For the LiquidityChunkMinterAlgebra

> NOTE: This session is heacy on user approved code-chunks, where even for the test set up. Ask the user if a code chunk is to be approved

- The ERC20, is the minimal we have been using with Compose that only allows for transfer and balance check. This is for both tokens. The compiler issues are handled, setting the compiler to higher to 0.8.30 and getting the bytecode for the algebra contracts that require 0.8.20 using the .bytecode approach

- Inside test/helpers/ We place the no-op ALgebraCallback helper as a NoOpCallback.plk file that has the interface

- Shared Algebra test infra lives under `test/helpers/Algebra/` (`AlgebraIntegralDeployer`, `IntegralPoolBootstrap`). **Deployer** = bytecode only. **Integration bootstrap** = deployer + on-chain init → `ReadyPool`. Use `bootstrap(vm)` from client tests; do not duplicate `_algebraPoolFixture` without `initialize`.
