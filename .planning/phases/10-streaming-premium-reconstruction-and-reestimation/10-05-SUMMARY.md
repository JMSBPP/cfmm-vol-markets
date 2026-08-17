---
phase: 10-streaming-premium-reconstruction-and-reestimation
plan: 05
subsystem: premium-read
tags: [panoptic, sfpm, getAccountPremium, calldata, abi-dynamic-bytes, x64, telescoping, wraparound, premium-flags, haskell, offline-tests]

# Dependency graph
requires:
  - phase: 10-streaming-premium-reconstruction-and-reestimation
    plan: 02
    provides: "Chain.Abi (selector, encodeBytesDynamic/encodeInt24/encodeAddress/encodeUint256/encodeWord, decodeWordAt, decodeUint128Pair, diffMod, keccak256Hex) + Chain.Rpc (ethCall, RpcEnv, BlockTag) + the frozen premium-acc-golden.json fixture"
  - phase: 10-streaming-premium-reconstruction-and-reestimation
    plan: 04
    provides: "Panoptic.Chunk: ChunkKey, LegChunk (lcLegIndex/lcChunkKey/lcIsLong/lcLiquidity/lcStrike/lcWidth), storedValueTick = 8388607"
provides:
  - "Panoptic.Sfpm: poolKeyBytes (keccak == known poolId), getAccountPremiumCalldata / getAccountLiquidityCalldata (derived selector, dynamic bytes head/tail 0x100 offset), decodeAccountPremium/decodeAccountLiquidity (length-defensive, currency0=right slot, fail-loud), getAccountPremium/getAccountLiquidity (Chain.Rpc-threaded live reads), constants sfpmAddress/panopticPoolAddress/vegoidConst/atTickSentinel"
  - "Panoptic.Premium: AccReading, PremiumObs, PremiumFlag (ChunkEmpty | AccFrozen | Extrapolated), accDelta (diffMod 128), premiumWei (X64 + long-negate), telescope (EXACT decomposition), isFrozenAcc, multiplierWedge (nu=1/8 Rational), buildPremiumObs (fan-out via lcLiquidity)"
affects: [10-06, 10-07, 10-08, 10-09, 10-11]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "The poolKey ABI encoding is proven byte-for-byte by ONE identity: keccak256(poolKeyBytes) == the known poolId 96d4b53a..288c0a. If that check fails, no downstream number is trustworthy and no network call is made."
    - "The function selector is DERIVED from the signature string via Chain.Abi.selector, never a hardcoded 4-byte literal (a hardcoded selector is silently wrong if a type name or comma is off)."
    - "Length-defensive returndata decode: >=64B => two right-aligned uint128 words (real ABI), >=32B => a single LeftRight-packed word (the golden fixture shape), shorter => Left. currency0 is always the RIGHT slot."
    - "Telescoping is tested as EXACT integer equality (not approximate): with L a multiple of 2^64 there is no per-delta flooring loss, so Sigma per-epoch premia == endpoint premium for any monotone chain."

key-files:
  created:
    - "econometrics/src/Panoptic/Sfpm.hs"
    - "econometrics/src/Panoptic/Premium.hs"
    - "econometrics/test/Panoptic/SfpmSpec.hs"
    - "econometrics/test/Panoptic/PremiumSpec.hs"
  modified:
    - "econometrics/package.yaml"
    - "econometrics/test/Spec.hs"

key-decisions:
  - "decodeAccountPremium decodes DEFENSIVELY on returndata length: the real chain returns two uint128 as two right-aligned 32-byte words (64B), while the frozen golden fixture is a single LeftRight-packed word (32B). Both paths return (currency0, currency1) with currency0 in the low/right 128 bits. A return < 32 bytes (incl. empty 0x) is Left, never a decoded zero."
  - "getAccountLiquidity/decodeAccountLiquidity are implemented (not deferred): RESEARCH Pitfall 5 — getAccountPremium silently returns the STORED accumulator when netLiquidity == 0, making a flat stretch ambiguous between 'no fees' and 'chunk empty'. Recording liquidity beside every premium read is what disambiguates them; the PremiumFlag ChunkEmpty is set from arNetLiquidity == 0."
  - "telescope sums per-delta premiumWei (each floored at 2^64), and its spec asserts EXACT equality with the endpoint premiumWei. This is exact precisely when L is a multiple of 2^64 (no cross-term flooring drift); the tests construct L that way. On real data the per-epoch flooring residual is < 1 wei/epoch and belongs to the gate's rounding wedge, not to this identity."
  - "buildPremiumObs honours the plan signature [LegChunk] -> Map (ChunkKey,epoch,isLong) AccReading -> [PremiumObs] and leaves poTokenId blank: a LegChunk carries no tokenId because the accumulator is POOL-WIDE. The driver (10-06) attaches the tokenId via the readScheduleRaw fan-out, whose ReadRow retains rrTokenId. This module owns only the delta->wei arithmetic and the flagging."

requirements-completed: [CTX-PREM, CTX-GATE]

# Metrics
duration: ~9m
completed: 2026-07-21
---

# Phase 10 Plan 05: SFPM Premium Read (Sfpm + Premium) Summary

**`Panoptic.Sfpm` encodes the `getAccountPremium` call — dynamic `bytes poolKey` head/tail, selector derived from the signature, poolKey proven byte-for-byte by its keccak matching the known poolId — and decodes the frozen live returndata to the exact RESEARCH accumulators; `Panoptic.Premium` turns X64 accumulator differences into per-leg, per-epoch premium in wei with mod-2^128 wraparound, long-leg negation, an EXACT telescoping identity, and explicit frozen/empty-chunk flags. All proven offline (suite 117 → 147, +30 examples).**

## Performance

- **Duration:** ~9 min
- **Started:** 2026-07-21T17:05:59Z
- **Tasks:** 2 (both TDD/offline)
- **Files:** 6 (4 created, 2 modified)

## Accomplishments

- **Proved the entire poolKey encoding with one check.** `poolKeyBytes` is the 160-byte `abi.encode(PoolKey{currency0=ETH, currency1=USDC, fee=500, tickSpacing=10, hooks=0})`; `keccak256 poolKeyBytes` equals the known poolId `96d4b53a…288c0a` in a passing spec. This single identity validates the five-word layout byte-for-byte — if it failed, nothing downstream could be trusted and no network call would fire.
- **Encoded the dynamic `bytes poolKey` argument correctly.** `getAccountPremiumCalldata` is `4 + 8*32 + 32 + 160 = 452` bytes: a selector DERIVED from `getAccountPremium(bytes,address,uint256,int24,int24,int24,uint256,uint256)`, eight head slots whose slot 0 carries the byte offset `0x100` (not the data), then the dynamic tail (length word `160` + poolKey). Negative ticks appear sign-extended (leading `0xff`); `atTick = Nothing` encodes the `8388607` stored-value sentinel; `Just t` encodes the live-extrapolation tick.
- **Decoded the frozen live returndata to the exact RESEARCH values, offline.** `decodeAccountPremium` reads each `premium-acc-golden.json` reading and returns the recorded `expected_currency0_x64` in the currency0 (right) slot; empty `0x` returndata is `Left`, never a spurious zero. `getAccountLiquidity`/`decodeAccountLiquidity` return `(removed, net)` so a `netLiquidity == 0` flat stretch is distinguishable from real zero fees (RESEARCH Pitfall 5).
- **Made the premium arithmetic correct-by-construction.** `premiumWei` applies the X64 (`2^64`) scale — not X128, not X96 — and negates for long legs exactly as `PanopticPool._getPremia` L2296-2298; `accDelta` is `diffMod 128` (unchecked uint128 wraparound), so a value wrapped past `2^128-1` yields a small positive delta, never a ~1.15e77 garbage magnitude.
- **Asserted the telescoping identity EXACTLY.** For a monotone accumulator chain and an L that is a multiple of `2^64`, `telescope` (the sum of consecutive-delta premia) equals the endpoint `premiumWei` exactly — the algebraic property the reconciliation gate rests on (the panel is a *decomposition* of the ground truth, not an independent estimate).
- **Flagged, never hid, the ambiguous zeros.** `PremiumFlag` distinguishes `ChunkEmpty` (`netLiquidity == 0`), `AccFrozen` (`isFrozenAcc`, within 1% of the `2^128-1` cap that freezes owed and gross together — Pitfall 6), and `Extrapolated` (a real `atTick`, not the sentinel). `buildPremiumObs` carries these through to every observation. `multiplierWedge` returns the `nu = 1/8` Panoptic multiplier as an exact `Rational` (1 when R=0, ≤ 1.125 on the long side) for the 10-11 cross-walk — it reports the wedge, it does not apply it.

## Panoptic.Sfpm Public API

```
sfpmAddress, panopticPoolAddress :: Text
vegoidConst :: Integer            -- 8 (nu = 1/8)
atTickSentinel :: Int             -- 8388607 = type(int24).max
poolKeyBytes :: ByteString        -- 160B; keccak == known poolId
getAccountPremiumCalldata   :: ChunkKey -> Maybe Int -> Bool -> ByteString
getAccountLiquidityCalldata :: ChunkKey -> ByteString
decodeAccountPremium   :: ByteString -> Either String (Integer, Integer)  -- (currency0, currency1)
decodeAccountLiquidity :: ByteString -> Either String (Integer, Integer)  -- (removed, net)
getAccountPremium   :: RpcEnv -> ChunkKey -> Maybe Int -> Bool -> BlockTag -> IO (Either String (Integer, Integer))
getAccountLiquidity :: RpcEnv -> ChunkKey -> BlockTag -> IO (Either String (Integer, Integer))
```

## Panoptic.Premium Public API

```
data AccReading = AccReading { arChunkKey, arBlock, arEpoch, arIsLong, arAtTick
                             , arAcc0, arAcc1, arNetLiquidity, arRemovedLiquidity, arEndpoint }
data PremiumObs = PremiumObs { poTokenId, poLegIndex, poEpoch, poPremiumWei0, poPremiumWei1
                             , poIsLong, poStrikeTick, poFlags }
data PremiumFlag = ChunkEmpty | AccFrozen | Extrapolated
accDelta        :: Integer -> Integer -> Integer                 -- diffMod 128
premiumWei      :: Integer -> Integer -> Integer -> Bool -> Integer   -- X64, long-negate
telescope       :: [Integer] -> Integer -> Bool -> Integer       -- EXACT decomposition
isFrozenAcc     :: Integer -> Bool                               -- within 1% of 2^128-1
multiplierWedge :: Integer -> Integer -> Bool -> Rational        -- 1 + nu*R/N (long), 1 + nu*R^2/(N*T) (short)
buildPremiumObs :: [LegChunk] -> Map (ChunkKey, Integer, Bool) AccReading -> [PremiumObs]
```

## PremiumFlag semantics (10-06 .. 10-09 MUST propagate)

| Flag | Set when | Why the gate/analysis needs it |
|---|---|---|
| `ChunkEmpty` | `arNetLiquidity == 0` at the reading block | `getAccountPremium` silently returned the STORED (non-extrapolated) accumulator — a flat stretch is "chunk empty", not "no fees" (Pitfall 5) |
| `AccFrozen` | `isFrozenAcc arAcc0 \|\| isFrozenAcc arAcc1` | once an accumulator hits the `2^128-1` cap, `addCapped` freezes owed+gross together and every delta is 0 forever — indistinguishable from "no fees" unless the level is checked (Pitfall 6) |
| `Extrapolated` | `arAtTick /= storedValueTick` | the reading used a live `feeGrowthInside` extrapolation rather than the stored value |

A flagged observation is **not** auto-dropped, but it is **never invisible** — the flags flow to the panel CSV so the gate and analysis can stratify on them.

## Verification

- `cd econometrics && stack test econometrics:test:unit --fast --ta '-m "Panoptic.Sfpm"'` — 11/0.
- `… --ta '-m "premium golden"'` — 5/0 (4 existing Rpc + 1 new Sfpm golden decode).
- `… --ta '-m "telescoping"'` — 4/0; `… --ta '-m "premium sign"'` — 4/0.
- `stack test` — **147 examples, 0 failures** (117 baseline + 12 Sfpm + 18 Premium).
- `stack build` clean of new `-Wall` warnings on all four created files.
- All Task-1 and Task-2 acceptance greps PASS (selector signature, `96d4b53a…` keccak assertion, `8388607`, `getAccountLiquidity`, `sfpmAddress`, `diffMod 128`, `2 ^ (64`, `ChunkEmpty`/`AccFrozen`, `multiplierWedge`, `premium-acc-golden.json`).
- `! grep -rE 'https?://'` on both spec files and both source files — the path is fully offline.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Odd-length hex accumulators need padding before `hexToBytes`**
- **Found during:** Task 1 (the "premium golden" decode) and Task 2 (the golden-derived case).
- **Issue:** The frozen `expected_currency0_x64` values are odd-length hex (e.g. `0x3363c8e16f43182fb`, 17 nibbles). `Chain.Abi.hexToBytes` requires an even nibble count and returns empty on odd input, so a naive `bytesToInteger . hexToBytes` decoded to `0` and the golden assertion failed (`expected: 0`).
- **Fix:** Added a `hexToInteger` test helper that strips the `0x` prefix and left-pads an odd nibble count with `0` before `hexToBytes` (the same padding `Chain.Rpc.hexTextToInteger` already applies). Source modules are unaffected — real returndata is always full 32-byte words.
- **Files:** `econometrics/test/Panoptic/SfpmSpec.hs`, `econometrics/test/Panoptic/PremiumSpec.hs`.
- **Commit:** `6360ffd`, `56e0f49`.

**2. [Test-truthfulness] Corrected an off-by-2^64 expected value in the Extrapolated-flag test**
- **Found during:** Task 2 full-suite run.
- **Issue:** A first draft asserted `poPremiumWei0 == 4` for readings with `arAcc0` deltas of `4 * 2^64` and `L = 2^64` — but `premiumWei` then yields `4 * 2^64`, not `4`. The assertion, not the code, was wrong (this is exactly the "off by 2^64" diagnostic RESEARCH Pitfall 2 warns about).
- **Fix:** Set the reading `arAcc0` values to `5` and `9` (delta `4`) with `L = 2^64`, so the premium is a clean `4` wei and the assertion is faithful to the X64 scaling.
- **Files:** `econometrics/test/Panoptic/PremiumSpec.hs`.
- **Commit:** `56e0f49`.

**3. [Cleanliness] Avoided `head`/`last`/`!!` partial-function `-Wall` warnings in the specs**
- **Found during:** Task 2.
- **Issue:** GHC 9.10's `-Wall`/`-Wx-partial` flags `head`/`last`/`!!` on list literals.
- **Fix:** Bound the chain endpoints explicitly and pattern-matched the fixture reading list — no behaviour change, zero new warnings.
- **Files:** `econometrics/test/Panoptic/PremiumSpec.hs`.
- **Commit:** `56e0f49`.

### Process note (not a code deviation)

**TDD RED/GREEN collapsed to one `feat` commit per task**, following the 10-02 precedent: a Haskell spec importing a not-yet-existing module fails at COMPILE time, so a separately-committed RED would leave the whole suite non-building. Each task lands module + spec together, verified green against the targeted `-m` filters before commit. The internal RED→GREEN iteration still happened (the odd-hex-padding and off-by-2^64 failures above were caught by running the specs before the final commit).

## Authentication Gates

None. Both tasks are fully offline against the frozen `premium-acc-golden.json` fixture and synthetic accumulator chains; no RPC endpoint was contacted and no secret was introduced.

## Issues Encountered

- Two spec failures during iteration (odd-length golden hex → 0; off-by-2^64 expected premium), both TEST-side truthfulness fixes surfacing correct on-chain arithmetic rather than code defects. No source defect.

## Next Phase Readiness

- **10-06 (execution):** call `getAccountPremiumCalldata` per deduplicated `ReadRow`, issue via `getAccountPremium`/`ethCall`, and record `getAccountLiquidity` alongside so `ChunkEmpty` is set; budget against the HOURLY ~30k–60k / ~70–140 min envelope, re-probing archive availability (~2026-08-19). Attach `rrTokenId` to each `PremiumObs` (buildPremiumObs leaves `poTokenId` blank by design).
- **10-07/10-08 (the gate):** `telescope` is the load-bearing identity — Σ per-epoch premia over a spell must equal the endpoint (mint→burn) premium; read spell endpoints at the exact mint/burn blocks (the `rrEndpoint`-tagged rows from 10-04). Stratify by `poIsLong` (long-premium capping wedge) and run the gate in wei, before USD conversion.
- **10-11 (cross-walk):** report the MEASURED `multiplierWedge` distribution (the ν=1/8 Lean-vs-Panoptic wedge) in `lean-haskell-crosswalk.md`, not an asserted bound.

---
*Phase: 10-streaming-premium-reconstruction-and-reestimation*
*Completed: 2026-07-21*

## Self-Check: PASSED

- All 7 claimed files exist on disk (4 created, 2 modified, + this SUMMARY).
- Both task commits (6360ffd, 56e0f49) exist in history.
- Suite 117 → 147/0 (+12 Sfpm, +18 Premium); `keccak256(poolKeyBytes)` == known poolId asserted in a passing spec; telescoping asserted as EXACT integer equality; no network/URL in any of the four created source/spec files.
