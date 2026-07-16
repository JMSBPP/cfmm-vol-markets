# Phase 8: Reference Integrity & Kernel Mock — Context

**Gathered:** 2026-07-15
**Status:** Ready for planning
**Source:** Carried from the mandatory two-step parallel review of the v2.0 roadmap (Reality Checker + Solidity Smart Contract Engineer), whose 4 MAJORs were resolved into ROADMAP.md at commit b7ea835.

<domain>
## Phase Boundary

This phase makes the differential **baseline** trustworthy and the variance **kernel** callable in isolation. It delivers three small, verifiable things:

1. **VDIFF-01 (pin):** the Algebra reference the diff suite compiles against can no longer be silently replaced.
2. **VDIFF-01 (mock):** a distinctly-named mock exposing Algebra's `internal pure` `_volatilityOnRange`, proven CALLED by a differential probe.
3. **VDIFF-03 (descoped):** delete the one incorrect raw-vs-normalized scalar-vol assertion and document why those quantities differ.

It does **NOT** implement the variance diff itself (that is Phase 9) and does **NOT** port Algebra's window-normalized `getAverageVolatility` (deferred — see Deferred Ideas).

**Why this phase exists first:** the reference is a mutable, untracked `node_modules` file. It was **already accidentally corrupted once this session** — an Emacs auto-fill split an identifier (`tickCumulative` → `tickC umulative`) and broke the build; `npm ci` silently restores upstream. Every later phase's "exact" claim is meaningless if the thing being compared against can move.
</domain>

<decisions>
## Implementation Decisions (LOCKED — do not re-litigate; these came out of the two-step review)

### The pin (VDIFF-01)
- The baseline is **NOT one file**. `test/MarketStatisticsTest.t.sol:5-8` imports **three** package files:
  `VolatilityOraclePluginImplementation.sol`, `libraries/VolatilityOracle.sol`, `libraries/VolatilityOracleStorage.sol`.
  VDIFF-04 drives Algebra **through `VolatilityOraclePluginImplementation` via delegatecall** (`MarketStatisticsTest.t.sol:162-173`).
  Pinning only `VolatilityOracle.sol` is **false assurance** — pin the whole closure (+ transitive imports), or the package tarball hash.
- The check must **FAIL LOUDLY (red)** when the `node_modules` copy diverges from the pin. Prove it by *deliberately editing a reference file and observing red* — a check that has never been seen failing is not a check.
- `remappings.txt` has **no** cryptoalgebra entry; resolution comes from `foundry.toml`'s remappings block
  (`@cryptoalgebra/volatility-oracle-plugin/=node_modules/@cryptoalgebra/volatility-oracle-plugin/contracts`).
  **If vendoring under `lib/`, CONFIRM the remapping actually redirects** — otherwise the suite silently keeps compiling against `node_modules` and the pin is theatre.

### The mock (VDIFF-01 scaffolding)
- `_volatilityOnRange` is **`internal pure`, storage-free, all value args** (`VolatilityOracle.sol:287-312`). A one-line wrapper exposes it. This is the easy part — do not over-engineer.
- The package **already ships** `node_modules/@cryptoalgebra/volatility-oracle-plugin/contracts/test/MockVolatilityOracle.sol` (an `IVolatilityOracle` tick-cumulative double that does **not** expose `_volatilityOnRange`).
  **Use a DISTINCT name** to avoid shadowing/confusion.
- Algebra pins `pragma solidity =0.8.20` — the mock must compile under a compatible solc.
- The probe must **differentially assert** the mock's `_volatilityOnRange` against Plank's `calculate_realized_volatility` on a **non-degenerate** input (`tick0 != tick1`, so `b != 0`). A "returns nonzero" probe is too weak (review MINOR-5) — it proves reachability, not correctness.
- **Bound `dt >= 1`.** `dt = 0` is a KNOWN, excluded divergence: Solidity `/` reverts on div-by-zero **even under `unchecked`** (Panic 0x12), while EVM `SDIV(N,0)` returns **0 silently**.

### VDIFF-03 (DESCOPED by review — this is the whole requirement now)

**CORRECTION (2026-07-15, found by the planner and verified):** the earlier framing below — inherited from the reviewers' wording "delete the current wrong assertion" and written here as fact **without verification** — was WRONG. **No such assertion exists.** `grep -rn "getAverageVolatility" test/ --include=*.sol` returns only:
  - `RealizedVolatilitySmoke.t.sol:15` — a **declaration** in `IRealizedVolatility`, **never called**
  - `MarketStatisticsTest.t.sol:175-179` — the Algebra ref's own `getAverageVolatilityLast` getter
  - `MarketStatisticsTest.t.sol:440` — used in the zero-assertion `console.log` term-structure test
There is **no assertion on it anywhere**. Planning a deletion of a non-existent assertion would be a fantasy task that "completes" vacuously.

**What VDIFF-03 actually is:** the risk is a *loaded gun*, not an existing bug. `RealizedVolatilitySmoke.t.sol:15` declares `getAverageVolatility(int24,uint32)` on `IRealizedVolatility` — declared, unused, one `assertEq` away from the mistake. So:
- **Remove that unused declaration surface** so the wrong diff cannot be written by reflex.
- **Document** that Plank's raw `get_average_volatility` (`RealizedVolatilityMod.plk:221-224`, the last timepoint's raw `volatilityCumulative`) and Algebra's window-normalized `getAverageVolatility` (`VolatilityOracle.sol:195-242` — Bessel-corrected + WINDOW-normalized) are **DIFFERENT quantities** and must not be diffed. Any scalar vol check uses the stored `volatilityCumulative` field (Phase 9 / VDIFF-04).
- The executor MUST **re-verify this survey before editing** and branch if reality differs again.
- Note: the selectors differ (`getAverageVolatility` = 0x8171455c vs `getAverageVolatilityLast` = 0xc3c8050a), so a shared-interface call would revert rather than mis-compare — which is *why* the mistake hasn't bitten yet.

### Claude's Discretion
- Pin mechanism: vendored copy under `lib/` vs checksum manifest vs tarball hash — pick whichever most simply achieves "red on divergence" without breaking import resolution.
- Where the check runs (a `make` target, a forge test, or a script) — as long as it is observable and wired so it actually runs.
- Mock file location/name (must be distinct from the package's `MockVolatilityOracle`).
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### The reference of record (Algebra)
- `node_modules/@cryptoalgebra/volatility-oracle-plugin/contracts/libraries/VolatilityOracle.sol` — `_volatilityOnRange` (287-312), `getAverageVolatility` (195-242), `_createNewTimepoint`, `_getAverageTick`. THE thing being pinned.
- `node_modules/@cryptoalgebra/volatility-oracle-plugin/contracts/VolatilityOraclePluginImplementation.sol` — the delegatecall target the Algebra ref drives.
- `node_modules/@cryptoalgebra/volatility-oracle-plugin/contracts/libraries/VolatilityOracleStorage.sol` — the storage layout the ref reads.

### Plank side
- `src/lib/market_state_measurements/RealizedVolatilityLib.plk` — `calculate_realized_volatility` (the kernel being probed).
- `src/modules/market_state_measurements/RealizedVolatilityMod.plk` — `get_average_volatility` (221-224, the raw accumulator whose wrong assertion is deleted), plus the ABI dispatch.

### Test infrastructure to BUILD ON, not re-create
- `test/PlankTestBase.sol` — centralizes the 6 `Dependency[]` module roots; keep in lockstep with `Makefile:PLANK_DEP`.
- `test/MarketStatisticsTest.t.sol` — the Algebra + UniV3 refs and their getters.
- `test/market_state_measurements/RealizedVolatility.diff.t.sol` — the merged Phase 0-1 driver (`_initAll`/`_writeAll`, `_assertThreeWayAt`).
- `.planning/ROADMAP.md` — Phase 8 success criteria (authoritative, review-hardened).

### Config
- `foundry.toml` — `via_ir = true`, `optimizer = true` are now defaults; the remappings block resolves cryptoalgebra.
</canonical_refs>

<specifics>
## Specific Ideas / Hard Constraints

- **`make compile-plank` passing is NOT evidence.** Plank does not type-check code unreachable from `run{}`. This project already shipped a "13 ok / 0 failed" gate that was green on an EMPTY module. Only CALLING a module proves anything. Every acceptance criterion must be an observable test outcome — never "it compiles".
- Every forge invocation needs `--via-ir --optimize` (now defaulted in `foundry.toml`; `--via-ir` alone hits stack-too-deep).
- Bit-exactness IS achievable and guaranteed within int24 ticks × uint32 `dt` — both reviewers independently confirmed: kernel numerator peaks ~2^149 ≪ 2^256, `@evm_sdiv` == Solidity `/`, `uint88` mask-after-add ≡ truncate-before-add. Do not hedge the probe with a tolerance.
- Keep deliverables SMALL: the pin + its red-on-divergence proof, the mock + its differential probe, the VDIFF-03 deletion + doc. Nothing else.
</specifics>

<deferred>
## Deferred Ideas

- **Porting Algebra's window-normalized `getAverageVolatility` to Plank** — production work (its own `_getVolatilityCumulativeAt` binary search, windowed interpolation, Bessel's correction). Both reviewers flagged that implementing it here is scope creep dressed as test setup, AND redundant with VDIFF-04's stored-field diff. Explicitly OUT of this milestone.
- The variance diff itself (kernel fuzz + full-timepoint field-by-field) — Phase 9.
- The `span > 2×WINDOW` and sub-WINDOW corpora — Phase 10.
- Edges + the full mutation battery + `make` wire-up — Phase 11.
- A Uniswap-V3 `OracleLib`-based volatility reference (todo items 6-7) — deferred at milestone level; UniV3 has no volatility accumulator, so it would re-derive Algebra's own formula and diff against itself.
</deferred>

---

*Phase: 08-reference-integrity-kernel-mock*
*Context gathered: 2026-07-15 — carried from the v2.0 roadmap two-step review (b7ea835)*
