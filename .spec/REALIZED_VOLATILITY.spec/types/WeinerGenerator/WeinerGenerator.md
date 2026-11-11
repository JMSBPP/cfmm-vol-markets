[MAIN](.spec/REALIZED_VOLATILITY.md## **WeinerGenerator**)
[COMM](.spec/REALIZED_VOLATILITY.spec/communication.mmd)
[BLOB](git blob 44a6f306093537d16a3aaa8d419d218ec924dc1a → `.spec/REALIZED_VOLATILITY.md`)
[EPS](https://fravoll.github.io/solidity-patterns/randomness.html)
[ISSUE](https://github.com/JMSBPP/cfmm-vol-markets/issues/126)

\[
\begin{aligned}
\Delta W (t_i) &= \sqrt{\bar dt} \, \cdot\, \epsilon \, (t_i) \\
\epsilon (t_i) &\sim \mathcal{N} \, (0,1)
\end{aligned}
\]

## Artifacts

| Role | Path |
|------|------|
| Plank lattice | `src/types/WeinerGenerator.plk` — `ShockPips()`, `DeltaW(dt)`, `deltaW`, `mapHashToShockPips` |
| Solidity box | `src/WeinerGenerator.sol` — `seal` / `reveal` / `eps(dt,j)` / `shock(dt,j)` |
| Numerics | `src/types/Numerics.plk` — `RAY = 10**27`, `PIPS = 10**6` |
| Harness | `test/harness/types/WeinerGeneratorHarness.plk` |
| Forge tests | `test/weiner_gen/WeinerGenerator.t.sol` |
| Foundry profile | `[profile.weiner]` in `foundry.toml` (isolated from full monorepo deps) |

## Locks (summary)

- \(\sqrt{\bar{dt}}\): **comptime table** `floor(√dt · RAY)` for TimeSpacing `{2,3,4,5,6,8,9,10}` — **not** `getSqrtRatioAtTick` (that is \(\sqrt{1.0001^i}\cdot Q96\))
- Entropy: one seal/reveal → `entropyRoot`; stream \(\epsilon_j = \mathrm{map}(\mathrm{keccak}(root, j))\); \(j \in [0, Window()/dt)\)
- Clocks independent: Window/dt = **timestamps**; ceremony = **block numbers** (`vm.roll` for reveal; `vm.warp` only if Window needs wall-clock)
- EVM \(\epsilon\): sealed-seed ⊕ `blockhash(sealBlock)` ([Solidity Patterns — Randomness](https://fravoll.github.io/solidity-patterns/randomness.html))
- Hash → pips (A): high bit = sign (`neg_u256`); magnitude `(h >> 1) % (6 · PIPS)`
- Rounding: table already floors √; product toward zero via unsigned `/`
- Overflow: Plank `std::core::ops` `checked_*`; Solidity `unchecked` only for `neg_u256`-style wrap

## Notes

### Window / TimeSpacing imports

- `import cfmm_types::Window::*` and `import cfmm_types::TimeSpacing::*`
- Domain + `N = Window()/dt` come from **`TimeSpacing` / `n(dt)`** — do not re-assert `{2…10}` or reimplement `n` in WeinerGenerator
- Pin `lib/cfmm-types` to **develop** (post PR #24); `.gitmodules` branch = `develop`
- Solidity box still mirrors `WINDOW` / dt set at runtime (`_requireTimeSpacing`) — deployable path cannot call Plank comptime `TimeSpacing`

### √dt Ray table

| dt | `floor(√dt · 10²⁷)` |
|----|---------------------|
| 2 | 1414213562373095048801688724 |
| 3 | 1732050807568877293527446341 |
| 4 | 2000000000000000000000000000 |
| 5 | 2236067977499789696409173668 |
| 6 | 2449489742783178098197284074 |
| 8 | 2828427124746190097603377448 |
| 9 | 3000000000000000000000000000 |
| 10 | 3162277660168379331998893544 |

Keep Plank + Solidity tables identical.

### How to build / test

```bash
# Solidity box (isolated profile — avoids node_modules / panoptic)
FOUNDRY_PROFILE=weiner forge test -vv

# Plank harness (lattice + Window)
plank build test/harness/types/WeinerGeneratorHarness.plk \
  --dep std=lib/plank-monorepo/std/ \
  --dep types=src/types \
  --dep cfmm_types=lib/cfmm-types/src/types \
  --backend sona
```

Harness selectors: `deltaWDt2(uint256)` → `0x0bd8a551`, `mapHash(uint256)` → `0x3e1f0c74`.

### Out of scope (still)

- CEV / TickDynamics / \(\sigma_F \cdot \Delta W\) composition
- Oracle Randao collaborative PRNG
- Full-repo `forge test` without installing monorepo deps (`plank-foundry-deployer`, Algebra `node_modules`, …)
