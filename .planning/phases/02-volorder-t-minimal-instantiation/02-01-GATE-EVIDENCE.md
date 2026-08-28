# Phase 2 / plan 02-01 gate evidence — plank pin bump, suite unchanged

- **Branch:** `feat/volorder-t-minimal`  **PR:** https://github.com/JMSBPP/cfmm-vol-markets/pull/62 (DRAFT)  **Issue:** #61
- **Pre-bump tree:** `a623b97` (= `origin/develop` at the branch point) — push-build `33167936025`.
  `develop-gate` could NOT run on this tree: GitHub refuses a zero-diff PR
  (`No commits between develop and feat/volorder-t-minimal`, measured). The gate-path pre-bump
  baseline is therefore the last green gate on `develop`, **`33124709716` on `7a6b25f`**, valid because
  `git diff 7a6b25f a623b97 -- . ':!.planning' ':!docs' ':!notes' ':!AGENTS.md' ':!TODO.md'` is **empty**
  (proved before use — the source tree is byte-identical).
- **Post-bump tree:** `5ccefd6` — push-build `33168564429` (success), develop-gate **`33168567137`**
  (https://github.com/JMSBPP/cfmm-vol-markets/actions/runs/33168567137), `gate` check = pass.
- **Intermediate RED run:** `8872eca` — develop-gate `33168041777` FAILED (forge 271 succeeded / 1 failed,
  plank 36 ok / 2 failed) on ONE cause: `error: unknown field` / `\`addr\` has no field \`raw\``. See Anomalies.
- **Pin:** `30f3bdcd405057ef7394dd9bf703f5923b03134a` (`feat/arrays`, HTTP 404) → `00c0a1aa3cb40b63de81c6ca4f92bec392b423c3` (`main`)
- **Harvested:** 2026-08-28T11:55:02Z

## Toolchain (GATE_POST2, quoted)

    forge Version: 1.5.1-v1.5.1
    Commit SHA: b0a9dd9ceda36f63e2326ce530c10e6916f4b8a2
    (plank job) Finished `release` profile [optimized] target(s) in 0.86s   ← warm rebuild at 00c0a1a

Cold `plankc` rebuild at the new pin, measured on `33168041777` forge job `Run make plank-toolchain`:
**11:40:45 → 11:41:37 = 52 s** (job timeout 25 min). The plank job then rebuilt warm in 1 s.
This closes the Phase 1 open item "timeout-minutes cold-runner headroom" for the plank toolchain.

## Suite — pre vs post (quoted, not paraphrased)

| | GATE_PRE `33124709716` | GATE_POST2 `33168567137` |
|---|---|---|
| `Ran N test suites …` | `Ran 75 test suites in 6.01s (34.05s CPU time): 273 tests passed, 0 failed, 3 skipped (276 total tests)` | `Ran 75 test suites in 6.41s (31.21s CPU time): 273 tests passed, 0 failed, 3 skipped (276 total tests)` |
| `VolOrderToPanopticTokenId.t.sol` | `Ran 10 tests for test/protocol_integrations/VolOrderToPanopticTokenId.t.sol:VolOrderToPanopticTokenIdTest` / Suite result: ok | same line / Suite result: ok |
| `Suite result: ok` / `FAILED` counts | 75 / 0 | 75 / 0 |
| `[SKIP` lines | 3 (below) | 3 (identical text) |
| `compile-plank:` | `compile-plank: 38 ok, 0 failed, 0 skipped` | `compile-plank: 38 ok, 0 failed, 0 skipped` |
| compile-plank OK/FAIL entry set | 38 entries | **IDENTICAL** (`diff` empty) |
| `warning` line count (forge job) | 236 | 236 |

Verbatim, one run per line (so both quotes are separately greppable):

    GATE_PRE   33124709716  Ran 10 tests for test/protocol_integrations/VolOrderToPanopticTokenId.t.sol:VolOrderToPanopticTokenIdTest
    GATE_POST2 33168567137  Ran 10 tests for test/protocol_integrations/VolOrderToPanopticTokenId.t.sol:VolOrderToPanopticTokenIdTest
    GATE_PRE   33124709716  compile-plank: 38 ok, 0 failed, 0 skipped
    GATE_POST2 33168567137  compile-plank: 38 ok, 0 failed, 0 skipped

`[SKIP` lines, GATE_PRE:

    [SKIP: loop-conformance.json absent at offchain/rig/loop-conformance.json - run the live sequence] test__priceInvarianceUnderVolumePath() (gas: 0)
    [SKIP: spec oracle not wired: SpecOracle.health() reports TransportFailure (RED-05). Wired in Phase 7, enforced in Phase 11 (CI-04).] test__fuzz_differential__volOrder(uint256,uint256,uint256,uint256,uint256,uint256,uint256) (runs: 0, μ: 0, ~: 0)
    [SKIP: spec oracle not wired: SpecOracle.health() reports TransportFailure (RED-05). Wired in Phase 7, enforced in Phase 11 (CI-04).] test_differential__volOrder__anchor() (gas: 0)

`[SKIP` lines, GATE_POST2:

    [SKIP: loop-conformance.json absent at offchain/rig/loop-conformance.json - run the live sequence] test__priceInvarianceUnderVolumePath() (gas: 0)
    [SKIP: spec oracle not wired: SpecOracle.health() reports TransportFailure (RED-05). Wired in Phase 7, enforced in Phase 11 (CI-04).] test__fuzz_differential__volOrder(uint256,uint256,uint256,uint256,uint256,uint256,uint256) (runs: 0, μ: 0, ~: 0)
    [SKIP: spec oracle not wired: SpecOracle.health() reports TransportFailure (RED-05). Wired in Phase 7, enforced in Phase 11 (CI-04).] test_differential__volOrder__anchor() (gas: 0)

Both differential tests still skip on the exact RED-05 reason string `spec oracle not wired` — Phase 1 state preserved.

## Verdict

**GREEN ON UNCHANGED SUITE: yes.** Suite count, pass/fail/skip, regression-floor test count, skip set,
forge commit, compile-plank summary and per-file entry set are all identical between the pre-bump and
post-bump gate runs. The compiler moved alone. VORD-02 bit-identity later has ONE variable.

## Migration applied

Commit `8872eca` (pin + 15 planned edits) and `5ccefd6` (3 unplanned edits, see Anomalies):

- `.gitmodules`: `branch = feat/arrays` → `branch = main` (1 line).
- `lib/plank-monorepo` gitlink: `30f3bdc` → `00c0a1a` (staged from the local checkout, which was
  already at the target; verified by `git -C lib/plank-monorepo rev-parse HEAD` before staging).
- `std::addr::` → `std::core::addr::`: `src/modules/VolOrderManagerMod.plk:2`, `src/lib/pos_spec/TickVolatilityLib.plk:2`, `test/lib/pos_spec/TickVolatilityLibHelper.plk:4`.
- `import std::core_ops::bool_to_u256;` deleted: `src/types/pos_spec/VolRangeWidth.plk:4`, `src/lib/market_state_measurements/RealizedVolatilityStateLib.plk:26`, `src/types/market_state_measurements/Timepoint.plk:4`, `test/types/pos_spec/VolRangeWidthHelper.plk:3`, `test/types/pos_spec/VolOrderValidationHarness.plk:33`.
- `bool_to_u256(` → `@bool_to_u256(` (7 sites): `Timepoint.plk:60`, `RealizedVolatilityStateLib.plk:39`, `VolRangeWidthHelper.plk:73,78,83,88`, `VolOrderValidationHarness.plk:51`.
- `addr.raw` → `cast_addr(addr, u256)` (3 sites): `TickVolatilityLib.plk:26,54`, `VolOrderManagerMod.plk:38`; `cast_addr` added to `VolOrderManagerMod.plk:2`'s import list.
- `notes/TOOLCHAIN_PINS.md` §7 appended.
- `memptr` in `lib/plankified-univ3/plank/lib/abi.plk` confirmed unreachable: `grep -rn 'v3::abi' src/ test/` → 0.

Makefile / workflow lines that reference the pin's LAYOUT (read, none names the SHA or branch — they
consume the gitlink): `Makefile:258` (`--dep std=lib/plank-monorepo/std/`), `:275` (`PLANK_DEV_EXEC`),
`:278` (`cargo build --release` in `plankc/`); `develop-gate.yml:130` and `:168-170` (submodule init +
`make plank-toolchain` + `make compile-plank`, both jobs); `push-build.yml:173` (`make plank-toolchain`).

## Anomalies

1. **Zero-diff draft PR refused** — plan Task 1 step 4 assumed it would open. `GATE_PRE` as written
   cannot exist; substituted as described at the top, with the source-tree-identity proof. Plan amended
   in `a3aedb9` before the substitution was relied on.
2. **A 4th migration cost the census missed:** `std/core/addr.plk` at `00c0a1a` is
   `addr = struct { as_uint: u160 }` (was `{ raw: u256 }`). The planning-time census grepped IMPORT
   PATHS and `memptr`, not FIELD READS on imported std types, so the three `.raw` sites were invisible
   until the gate went red. Fixed via upstream's own `cast_addr` accessor after the maintainer chose
   "amend the plan first" (`a3aedb9`); recorded in TOOLCHAIN_PINS §7 with the lesson.
3. **`--evm-version` contingency NOT needed** — the Osaka default emitted nothing the pinned forge
   rejected; `compile-plank` and all FFI builds went green without pinning an EVM version.
4. `error: could not lock config file …/.gitconfig` appears twice in EVERY run's log including the
   green pre-bump run (`grep -c` → 2 in both) — runner checkout noise, not ours, unchanged.
5. `GATE_POST2` forge job carried 236 `warning` lines, equal to the pre-bump count — the new compiler
   introduced no new warnings on this suite.
