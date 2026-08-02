---
phase: 22-live-stochastic-drivers
plan: 02
subsystem: offchain-decoding
tags: [haskell, abi-decoding, twos-complement, uniswap-v4, slot0, keccak, cast, foundry]

# Dependency graph
requires:
  - phase: 20-deploy-rig
    provides: "rig-pins.json (generated topic0 pins), Rig.Manifest, the offchain literal-purge rule"
  - phase: 21-v2-abi-repin
    provides: "VolOrder.Decode primitives (hex_to_integer, data_word, be_integer), the synthetic_log test harness, the length-guard discipline from RPIN-04"
provides:
  - "RealizedVol.Decode — E3 TimepointWritten (5 words, 3 SIGNED) and E5 FeeApplied (2 words) decoders with two's-complement sign extension and length/topic guards"
  - "CheatSwap.Types — pool_state_slot (keccak(poolId || 6)), compose_slot0 masked at bit 184, check_cheat_tick enforcing the G4 domain"
  - "CheatSwap.Encoding — encode_extsload and encode_swap via cast, selector never transcribed"
  - "The first signed-integer decoding anywhere in offchain/"
  - "MEASURED refutation of two plan predictions (mutant discriminator; calldata size)"
affects: [22-03, 22-04, 22-05, 22-06, subgraph-v6]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Every SIGNED field needs at least one NEGATIVE pin of its own"
    - "Word composition masked at the FEE boundary (184), not the price boundary (160)"
    - "Client-side domain guard before any calldata is built (G4)"
    - "Selector derived at test time from the signature string parsed back out of the encoder's own source"

key-files:
  created:
    - offchain/lib/RealizedVol/Decode.hs
    - offchain/lib/CheatSwap/Types.hs
    - offchain/lib/CheatSwap/Encoding.hs
  modified:
    - offchain/test/Main.hs
    - cfmm-replicationPlank-rpc-api.cabal

key-decisions:
  - "RealizedVol.Decode is a DECODER only — the module name is not evidence the no-writeTimepoint-client decision was violated; the haddock says so explicitly"
  - "ONE signed_word covers tick/averageTick/tickCumulative because the emitter sign-extends all three to the full 256-bit word regardless of declared width"
  - "compose_slot0 masks at 184 so protocolFee/lpFee survive BY CONSTRUCTION (G5b) rather than by care"
  - "POOLS_SLOT = 6 is CONSUMED from the pinned DynamicFeeHook.plk constant, never re-derived from v4-core"
  - "The swap calldata is 388 bytes (4 + 32*12), not the planned 324 — MEASURED"
  - "encode_extsload/hex32 given test coverage beyond plan scope: a wrong nibble order yields well-formed calldata pointing at a slot nothing ever wrote"

patterns-established:
  - "Negative-pin rule: a positive pin on a signed field is a value assertion blind to the only thing that makes the field signed"
  - "Guard-preserving prose: comment wording must not create permanent false positives in the greps that are the workstream's only evidence"

requirements-completed: []

# Metrics
duration: 47min
completed: 2026-08-02
---

# Phase 22 Plan 02: Pure Offchain Surface (E3/E5 Decoders, Slot0 Composition, Swap Calldata) Summary

**The entire chain-independent layer Phase 22 needs: two's-complement E3/E5 log decoders (the first signed-integer decoding anywhere in `offchain/`), the bit-184 slot0 composition that fixes the two-PoolManager blocker, and `cast`-shelled swap calldata whose selector is recomputed rather than typed — with four mutants applied and TWO plan predictions measured false.**

## Performance

- **Duration:** 47 min
- **Started:** 2026-08-02T15:32:00Z
- **Completed:** 2026-08-02T16:19:12Z
- **Tasks:** 3 (two of them TDD)
- **Files created:** 3 · **Files modified:** 2

## Accomplishments

- `RealizedVol.Decode` decodes E3 (`[timestamp, tick, volatilityCumulative, averageTick, tickCumulative]`, three of them signed) and E5 (`[sigma, fee]`) from synthetic logs, with `>= 160` / `>= 64` length guards, a topic0 guard AND a poolId guard.
- `CheatSwap.Types.pool_state_slot` reproduces the `cast keccak`-measured slot `eeab88fa…c4c6dd16` exactly; `compose_slot0` provably preserves bits >= 184 and takes bits 0..183 from `packSlot0For`; `check_cheat_tick` rejects the four out-of-domain ticks with a message naming both the bound and G4.
- `CheatSwap.Encoding` emits 36-byte `extsload` and 388-byte `swap` calldata; the swap selector is recomputed at test time from the signature string parsed back out of the module's own source.
- `cabal test` moved **65/65 → 68/68**, exit 0, **zero `-Wall` warnings**, literal purge still empty.
- **Chain-independence PROVEN, not asserted:** the final 68/68 run happened with `pgrep anvil` EMPTY. The guard grep is back to 0.
- **Four mutants APPLIED**, all four files restored **sha256-identical**.

## Task Commits

1. **Task 1 RED: failing E3/E5 decode checks** — `1858e23` (test)
2. **Task 1 GREEN: E3/E5 decoders with sign extension** — `5203e99` (feat)
3. **Task 1 FIX: pin the E3 tick with a NEGATIVE value** — `a90b150` (fix)
4. **Task 2 RED: failing slot0 composition + G4 checks** — `e4653c1` (test)
5. **Task 2 GREEN: slot derivation, 184-bit composition, G4 guard** — `49060eb` (feat)
6. **Task 3: extsload + PoolSwapTest.swap calldata** — `05b279d` (feat)

## Files Created/Modified

- `offchain/lib/RealizedVol/Decode.hs` (148 lines) — E3/E5 decoders, `signed_word`, and the haddock carrying the three reasons (length guard, uniform sign extension, the poolId-sentinel filtering rule from `notes/DATA_CONTRACT.md`).
- `offchain/lib/CheatSwap/Types.hs` (130 lines) — `pools_slot`, `pool_state_slot`, `compose_slot0`, `check_cheat_tick`, `word32be`. The module header leads with the `PriceSetterPoolManager` blocker.
- `offchain/lib/CheatSwap/Encoding.hs` (118 lines) — `encode_extsload`, `encode_swap`, `swap_signature`, `extsload_signature`, `hex32`.
- `offchain/test/Main.hs` — three new checks (`driv01_e3_decode_behavior`, `driv01_slot0_composition_behavior`, `driv01_swap_calldata_shape`), registered in `main`.
- `cfmm-replicationPlank-rpc-api.cabal` — three modules added to `exposed-modules`. **No new dependency**; `web3-crypto` (for `keccak256`) was already a library dependency.

## THE MEASURED RESULTS (the point of this plan)

### Mutant 1 — `signed_word` deleted from `tw_tick` only: **GREEN. PREDICTION REFUTED.**

The plan asserted this mutant "MUST go RED". It was applied and `cabal test` reported **66/66, exit 0**.

**Why:** the plan's own `<behavior>` block pins `tick = 37`. `signed_word` is the IDENTITY on non-negative words, so the field was pinned by a value that cannot distinguish a signed read from an unsigned one. `averageTick = -200` and `tickCumulative = -123456789` covered their own fields; nothing covered `tick`.

**This is the third time a predicted discriminator has been refuted in this workstream** (21-03: an inequality assertion stayed green under a value-breaking mutant; 21-04: a bit-length-spread assertion failed to separate log-uniform from linear). The pattern is now clear enough to state as a rule, and it is written into the check:

> **Every signed field needs at least one NEGATIVE pin of its own.** A positive pin on a signed field is a value assertion that is blind to the only thing that makes the field signed.

**Fixed, not noted** (`a90b150`): added `driv01_e3_tick_negative = -3145` and a second synthetic E3 payload. The POSITIVE payload was KEPT — it proves `signed_word` leaves the non-negative half alone, which is the other half of the contract.

**Re-measured after the fix:** the identical mutant now reddens —
`tw_tick = 115792089237316195423570985008687907853269984665640564039457584007913129636791, expected -3145` — 65/66, exit 1. Restored, sha256 `0d8e6466…af16b9f` unchanged.

### Mutant 2 — `>= 160` becomes `>= 128`: **RED as predicted.**

`FAIL driv01_e3_decode_behavior: a 159-byte E3 payload DECODED.` 65/66, exit 1. Restored sha256-identical.

### Mutant 3 — composition mask 184 becomes 160: **RED as predicted.**

`FAIL driv01_slot0_composition_behavior: bits 0..183 of the composed word are 8118641595373165710621469245738952174188706263886001, expected packSlot0For's 1803493020466334201063347083571893246255421745686705.` 66/67, exit 1. Restored, sha256 `2f28819b…08ddd7` unchanged.

This mutant only discriminates because the two test words carry **different tick bits** (`5555` vs `1234`). Had both sides shared a tick, masking at 160 and at 184 would be indistinguishable — the same class of blindness as mutant 1, avoided by construction here.

### Mutant 4 — `pools_slot` 6 becomes 5: **RED as predicted.**

`pool_state_slot gave 9488d15e…7777c8ad, but cast keccak … is eeab88fa…c4c6dd16.` 66/67, exit 1. Restored sha256-identical.

### The calldata size — **PREDICTION REFUTED, measured with `cast`.**

The plan specified `4 + 32*10 = 324` bytes. The actual encoding is **388 bytes = `4 + 32*12`**:

```
head: PoolKey 5 | SwapParams 3 | TestSettings 2 | offset to hookData 1  = 11 words
tail: hookData length word (zero data words follow)                     =  1 word
```

Both tuples are **static**, so they are inlined into the head rather than pointed at; `bytes` is the only dynamic member and it still costs an offset word AND a length word even when empty. The 324 figure dropped both `bytes` words. The check now pins **all twelve words individually** (`word 10 == 352`, `word 11 == 0` included), so the head/tail split is asserted rather than assumed.

## Decisions Made

- **`RealizedVol.Decode` is named for whose events these are, not for a client.** CONTEXT's locked decision forbids anything that calls `writeTimepoint`. The module header states, first paragraph, that this reads logs and nothing else — so a later reader cannot mistake the module name for evidence the decision was violated.
- **One `signed_word` for all three signed E3 fields.** The emitter runs `@evm_signextend` over `tick`, `averageTick` AND `tickCumulative` (`SIGN_BYTE_I24_EV` twice, `SIGN_BYTE_I56_EV` once) before `@mstore32`, so all three arrive extended to the full word regardless of declared width. A per-width mask would be wrong for all three.
- **The topic0-only filter is documented as WRONG, in-module.** `RealizedVolatilityMod` emits the SAME topic0 with `poolId = bytes32(0)`. The decoder matches `expected_pool_id` as well, but that does not close the case: the hook and the module both emit E3 with a real poolId, and only `changeAddress` separates them. The haddock says so because there is nowhere else a caller is guaranteed to look.
- **Mask at 184, and the third wrong answer named.** Masking at 160 takes `packSlot0For`'s sqrtPrice while keeping the target's tick (G5a violation); taking the whole word imports `PriceSetterPoolManager`'s fee bits. Both are recorded in the haddock beside the correct one.
- **`min_sqrt_price_limit` is safe at every G4 tick, and the reason is recorded as arithmetic, not as faith:** `getSqrtPriceAtTick(-887259) = 4297706459` sits ~2.5e6 units above `4295128740`, so v4's `MIN_SQRT_PRICE < limit < slot0.sqrtPriceX96` never inverts inside the domain. The floor-degeneracy claim is explicitly flagged **PREDICTION, measured by 22-04**, in the source.
- **`tickSpacing` has no default anywhere.** The check passes **60**, deliberately not 20 — a hardcoded `TICK_SPACING = 20` inside the encoder would be invisible to any check that also passed 20.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] The E3 tick was pinned by a value that could not discriminate**

- **Found during:** Task 1, measuring mutant 1
- **Issue:** `driv01_e3_tick = 37` is positive; `signed_word` is the identity on it; the mutant the plan predicted would redden left the suite GREEN at 66/66. A green-under-mutant check is a defect, per the standing correction.
- **Fix:** added `driv01_e3_tick_negative = -3145` and a second synthetic payload; kept the positive payload for the other half of the contract.
- **Files modified:** `offchain/test/Main.hs`
- **Verification:** mutant re-applied, now RED at 65/66; module restored sha256-identical.
- **Committed in:** `a90b150`

**2. [Rule 2 - Missing Critical] `encode_extsload` and `hex32` had no coverage**

- **Found during:** Task 3
- **Issue:** the plan's check covered `encode_swap` only. `hex32` is the one hand-rolled encoder in the module, and a wrong nibble order produces a **well-formed 36-byte calldata pointing at a slot nothing has ever written** — `extsload` on a wrong slot returns zero rather than reverting, and a zero slot0 decodes to `tick = 0`, which is a legal tick. Silent by construction.
- **Fix:** extended `driv01_swap_calldata_shape` with the extsload half — exact 36-byte length, selector recomputed from `extsload_signature`, and the argument word read back and compared to `pool_state_slot`'s output.
- **Files modified:** `offchain/test/Main.hs`
- **Verification:** 68/68, exit 0.
- **Committed in:** `05b279d`

**3. [Rule 1 - Bug] New prose broke the chain-independence guard**

- **Found during:** Task 3 verification
- **Issue:** the guard is `grep -cE 'cast call|HttpProvider|8545' offchain/test/Main.hs` = 0. Writing "cast calldata" run-together in a comment matches the `cast call` alternative as a substring, taking the count from 0 to 2. Nothing opened a socket — but the guard would have reported a permanent false positive on a comment, which retires the guard rather than satisfying it. The guard is the only evidence the suite opens no socket.
- **Fix:** the prose spells it "`cast`'s `calldata` subcommand", and the note explaining why **describes** the pattern instead of quoting it (the first attempt at the note re-tripped the grep on itself).
- **Files modified:** `offchain/test/Main.hs`
- **Verification:** guard count back to 0; 68/68 exit 0 with anvil DOWN.
- **Committed in:** `05b279d`

---

**Total deviations:** 3 auto-fixed (2 bugs, 1 missing critical). **No Rule 4 escalation.**
**Impact:** all three are correctness fixes to the evidence layer itself. No scope creep — no production behaviour was added beyond the plan's three modules.

## Instructions NOT Followed, and Why

- **The plan's `4 + 32*10 = 324` byte assertion was NOT written.** It is false; `388` was measured and asserted instead, with the head/tail derivation recorded in the check.
- **`grep -cE '^\s*(tw_tick|tw_avg_tick|tw_tick_cum)\s*=\s*signed_word'` was evaluated with a leading `,?` allowance.** The record-syntax lines begin with `, ` in this codebase's formatting; the count is **3** as required, matching the three signed fields.

## Issues Encountered

- The self-referential guard trip (deviation 3) took two passes: the comment explaining why the pattern must not be written verbatim contained the pattern verbatim.
- `cabal build --enable-tests -j all` was used throughout. The bare `cabal build -j all` remains unused — it is vacuous, confirmed four times in Phase 21.

## Things NOT Done (deliberately, in scope for later plans)

- **Nothing was run against a chain.** This plan is pure by design; every value is either computed locally or measured with `cast` as a pure encoder. `pgrep anvil` was EMPTY for the final gate.
- **No `Rpc` module and no driver loop.** `compose_slot0` has no caller yet — 22-03/22-04 wire it to `anvil_setStorageAt` and the swap.
- **The floor-degeneracy prediction is unmeasured** and labelled as such in `CheatSwap/Encoding.hs`. 22-04 owns it.
- **Territory respected:** `git status --porcelain src/ test/ foundry-scripts/ Makefile foundry.toml remappings.txt` is EMPTY. `offchain/rig/` and the 22-01 artifacts were not touched.

## Next Phase Readiness

Ready. The three modules are exposed, warning-free and exercised. 22-03/22-04 need from here:

- `pool_state_slot` + `compose_slot0` + `encode_extsload` for the cheat write against the TARGET `PoolManager`.
- `check_cheat_tick` as the pre-send domain guard (G4).
- `encode_swap` with `tickSpacing` read from `rig-manifest.json` — **never a constant**, or `beforeSwap` reverts with empty reason data.
- `decode_timepoint_written` / `decode_fee_applied` for reading the evidence back, **with a `changeAddress == DynamicFeeHook` filter added by the caller** — the decoder cannot enforce it.

**Carry-forward for 22-04 and beyond:**

1. The negative-pin rule (above) generalises past this plan: any future signed field, in any decoder, needs a negative pin.
2. The 388-byte figure and the twelve-word layout are now pinned in the suite; a v4-core `PoolSwapTest` signature change reddens `driv01_swap_calldata_shape` rather than failing live.
3. `min_sqrt_price_limit`'s safety argument holds for `zeroForOne = true` across the whole G4 domain, but the near-floor `amount1 ~ 0` degeneracy is a PREDICTION and must be measured before anything relies on it.

## Requirement Status — DRIV-01 deliberately NOT marked complete

This plan's frontmatter carries `requirements: [DRIV-01]`, but so do **22-01, 22-03, 22-04 and
22-05**. DRIV-01 is "the stochastic price path drives ... E3 emitted per step with the submitted
tick" — an outcome that requires a chain. This plan is PURE by construction and nothing here has
touched one. `requirements mark-complete DRIV-01` was therefore **NOT run**; REQUIREMENTS.md still
shows it Pending, correctly. 22-05 is the plan that closes it.

## Self-Check: PASSED

All 6 claimed files exist on disk. All 6 claimed commits resolve in `git log --all`. All three
claimed exports are present in their modules. The `signed_word` field count is 3 (`tw_tick`,
`tw_avg_tick`, `tw_tick_cum`). `cabal build --enable-tests -j all` exit 0 / 0 warnings and
`cabal test` exit 0 at 68/68 were both re-run at self-check time with **no anvil process running**.

---
*Phase: 22-live-stochastic-drivers*
*Completed: 2026-08-02*
