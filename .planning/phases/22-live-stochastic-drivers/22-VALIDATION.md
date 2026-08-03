---
phase: 22
slug: live-stochastic-drivers
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-08-02
---

# Phase 22 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Source: 22-RESEARCH.md `## Validation Architecture` — the authoritative req→test map lives there.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | **None** — hand-rolled `Check` list in `offchain/test/Main.hs` (1962 lines), `exitcode-stdio-1.0`; prints `PASS`/`FAIL` per check, `exitFailure` on any failure |
| **Config file** | `cfmm-replicationPlank-rpc-api.cabal` (`test-suite cfmm-replicationPlank-rpc-api-test`) |
| **Quick run** | `cabal test` — currently **65/65**, exit 0 |
| **Full gate** | **`cabal build --enable-tests -j all && cabal test`** — `cabal build -j all` alone is VACUOUS (confirmed 4×) |
| **Chain dependency** | **NONE — and this MUST be preserved.** Phase 21 measured it with anvil stopped; `grep -cE 'cast call\|HttpProvider\|8545' offchain/test/Main.hs` = 0 |
| **Live-evidence mechanism** | committed provenance-bearing JSON written by a shell script under `offchain/rig/`, asserted over by the suite (Phase 20/21 precedent) |
| **Extra gates** | zero `-Wall` warnings; `sc3_literal_purge`; `verify-import.sh` (SC-1); `verify-rig.sh` (SC-2) |

---

## Sampling Rate

- **Per task commit:** `cabal build --enable-tests -j all && cabal test` (seconds, no chain)
- **Per wave merge:** the above **plus** `bash offchain/rig/verify-import.sh`; for rig-touching waves also `bash offchain/rig/deploy-rig.sh && bash offchain/rig/verify-rig.sh`
- **Phase gate:** the README sequence top to bottom, a seed-replay run, and the chain-independence re-measurement (`deploy-rig.sh --stop` → `pgrep anvil` empty → `cabal test`) — **re-measured, never inherited**

---

## Requirements → Test Map (summary — authoritative table in 22-RESEARCH.md)

| Req / SC | Check | Exists? |
|----------|-------|---------|
| Re-pin (pre-req) | `verify-import.sh` over 37 paths @ `2039f27` | ✅ needs 3 pin rows + 1 new path |
| Re-pin (pre-req) | `check-upstream.sh` names `InitSwappableRig.s.sol` | ✅ needs `REQUIRED_PATHS` entry |
| Rig (pre-req) | `deploy-rig.sh` gains the 6th step; asserts probe `timepoint ts after > before` | ✅ needs step + 2 addresses |
| Rig (pre-req) | `verify-rig.sh` covers all 9 contracts | ✅ needs 2 probes |
| DRIV-01 / SC-1 | `driv01_e3_per_step_matches_submitted` — E3 count == steps, `timestamp == t0 + k·stride`, tick == submitted, strictly increasing | ❌ Wave 0 |
| DRIV-01 / SC-1 | `driv01_no_same_second_noop` — `count(E5) == count(E3)` (G1 detector) | ❌ Wave 0 |
| DRIV-01 / SC-1 | `driv01_e3_decode_behavior` — 2 topics, ≥160-byte guard, **sign-extended int24/int56** | ❌ Wave 0 (reuse 21-03's synthetic `Change` helper) |
| DRIV-01 / SC-1 | `write_price`/PriceSetterHook flow still runs unchanged | ✅ shipped — assert it |
| DRIV-02 / SC-2 | `driv02_single_order_live` — status 1, one E1 v2, block-pinned readback incl. targetVega | ❌ Wave 0 (live path shipped, assertion not) |
| DRIV-02 / SC-3 | `driv02_mixed_batch_live` — preview PATTERN match, orderCount delta, per-id readback, **`skew=65535` rejected tuple** | ❌ Wave 0 |
| DRIV-02 / SC-4 | `driv02_zero_arrival_is_64_bytes` — needs a DIRECT `create_orders _ _ []` call; the generator sends nothing at N=0 | ❌ Wave 0 |
| SC-5 | README sequence + `RIG_SEED` replay produces identical tick path and identical `e3.tick` series | ❌ Wave 0; README has 3 stale spots |
| Cross-cutting | suite chain-independent | ✅ pattern exists — **re-measure** |
| Cross-cutting | `sc3_literal_purge`, zero `-Wall` warnings | ✅ |

---

## Wave 0 Gaps

- [ ] Re-import/re-pin to `2039f27`: 2 changed files, 1 added, 36 → 37 paths (`import-paths.txt`, `IMPORT-PIN.md`, `check-upstream.sh`)
- [ ] `deploy-rig.sh` 6th step (`InitSwappableRig`, no `--ffi`) + swapRouter/modifyLiquidityRouter manifest keys + `Rig.Manifest.hs` fields
- [ ] The **pool-mismatch fix** (see blocker below) — compose slot0 from the target pool's own word
- [ ] Clock control via `evm_setNextBlockTimestamp` (absolute); NOT `evm_increaseTime`
- [ ] E3/E5 decoders + **signed-integer (int24/int56) decoding — none exists anywhere in `offchain/`**
- [ ] Seeded RNG for SC-5 replay (`createSystemRandom` is unseeded today)
- [ ] The driver loop, its evidence artifact, and the suite checks over it
- [ ] `offchain/rig/README.md` staleness fixes (3 places)
- [ ] Framework install: **none** — adding `vector`/`tasty`/`hspec` is a deviation to justify

---

## Standing Findings the Plans Must Carry

- **🔴 BLOCKER — `write_price` cheats the WRONG pool.** `PriceSetterHookScript` deploys its own second `PoolManager` (manifest `PriceSetterPoolManager`) and binds `PriceSetterHook` to a pool there (currencies `(0,1)`, fee 3000, tickSpacing 60, zero liquidity). `DynamicFeeHook` is on a different manager. Cheat-then-swap would write one pool and swap another — failing **silently** (E3 still fires, status 1, only the tick is wrong). Fix is inside `offchain/`, no new Solidity: compose the word from `PoolManager.extsload(keccak(poolId‖6))` OR-ed with `packSlot0For(tick)` masked at bit 184.
- **G1 reproduced empirically** (anvil 1.5.1): three back-to-back txs → `…13, …14, …14`. Lever is `evm_setNextBlockTimestamp` (absolute; anvil rejects backwards with a named error). `evm_increaseTime` is wall-clock-relative — measured a `-85682546` offset. `anvil_setStorageAt` does not mine and composes cleanly.
- **F1 is COMPATIBLE — no client change.** `targetVega@128..255` is an unmasked *read region* (`shr(128, word)`, no mask); `target_vega_fits_packed` rejects `> 2^96−1`. Our u96@128..223 packing is the accepted subset. The feared layout finding does not exist.
- **G5 already satisfied** — `packSlot0For` derives sqrtPrice from the tick and starts from `readSlot0()` with masked setters; bits ≥184 carry through. CONTEXT's suspicion was FALSE.
- **A receipt carries no returndata** — SC-4's "exactly 64 bytes" is observable only through the preview `eth_call`, never the mined tx. Do not write a check that pretends otherwise.
- **Import scope:** `notes/VOLATILITY_INSTRUMENTS.md` also changed on develop but is NOT in the import set — a glob must not pull it in.
- **F4 bites here** — the rig is being rebuilt, and capture freshness cannot see a module change (`manager` is a bytecode-independent CREATE address).
- Swaps must originate from `deployer` (index 0) — the only funded/approved account.
- **Checks must pin VALUES, not relations** — a plan's predicted mutant discriminator has been wrong twice. Measure discrimination; never assume it.
