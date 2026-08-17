---
phase: 10-streaming-premium-reconstruction-and-reestimation
plan: 02
subsystem: chain-access
tags: [abi, jsonrpc, keccak, feegrowth, wraparound, sign-extension, golden-fixture, haskell, offline-tests]

# Dependency graph
requires:
  - phase: 10-streaming-premium-reconstruction-and-reestimation
    plan: 01
    provides: "Wave-0 PROCEED on the hourly design; Chunk entity + exact getTicks; the width!=0 census"
  - phase: 09-upsilon-econometric-estimation
    provides: "Panel.Variance (wordAt, getLogsChunk retry/backoff, decodeTick/decodeSqrtPriceX96), the 62-example offline suite"
provides:
  - "Chain.Abi: the single ABI/word-arithmetic implementation in the repo — decodeWordAt (raw returndata, sign-extended), encodeWord/encodeUint256/encodeInt24/encodeAddress/encodeBytesDynamic, decodeUint128Pair (currency0=right slot), diffMod (unchecked mod 2^n), feeGrowthInside (Pool.sol L488-511 three-branch identity), keccak256Hex/selector (crypton Keccak_256), hexToBytes/bytesToHex/bytesToInteger"
  - "Chain.Rpc: the single JSON-RPC transport — RpcEnv/defaultBaseEnv/drpcFailoverEnv, generic rpcPost (retry/backoff lifted verbatim), ethCall/ethGetBlockByNumber/ethBlockNumber, BlockTag/blockTagHex/blockTagValue, BlockHeader, decodeCallResult (fail-loud envelope decoder)"
  - "test/fixtures/premium-acc-golden.json: frozen live-probe accumulators (blocks 44.5M/47M/latest) proving the decode path offline"
  - "Panel.Variance refactored to import both modules (wordAt deleted; getLogsChunk + currentHeadBlock call the lifted transport) with its public API unchanged"
affects: [10-03, 10-04, 10-05, 10-06, 10-07, 10-08]

# Tech tracking
tech-stack:
  added:
    - "crypton (library) — legacy Keccak-256 (Crypto.Hash.Algorithms.Keccak_256), NOT SHA3-256"
    - "memory (library) — Data.ByteArray.Encoding Base16 for hash/hex conversion"
    - "aeson (tests.unit) — RpcSpec parses the golden fixture JSON directly"
  patterns:
    - "Single-implementation rule enforced by deletion: Panel.Variance.wordAt and its forked RPC retry loop are removed, not duplicated — the 09-05 divergence lesson made structural"
    - "decodeWordAt operates on RAW returndata bytes; hex text is converted once at the boundary (Panel.Variance decodeTick/decodeSqrtPriceX96 via hexToBytes . decodeUtf8) so encode/decode round-trip"
    - "Fail-loud transport: ethCall/decodeCallResult return Left on empty returndata (0x), missing result, or JSON-RPC error — a zero accumulator is never manufactured from absent state"
    - "Offline golden fixture: raw returndata frozen from live probes; every test/Chain spec passes `! grep -rE https?://`"

key-files:
  created:
    - "econometrics/src/Chain/Abi.hs"
    - "econometrics/src/Chain/Rpc.hs"
    - "econometrics/test/Chain/AbiSpec.hs"
    - "econometrics/test/Chain/RpcSpec.hs"
    - "econometrics/test/fixtures/premium-acc-golden.json"
  modified:
    - "econometrics/src/Panel/Variance.hs"
    - "econometrics/package.yaml"
    - "econometrics/test/Spec.hs"

key-decisions:
  - "decodeCallResult takes a JSON-RPC envelope Value (not a raw hex string) so one function satisfies all three behavior bullets: decode a stored result, reject empty 0x returndata, and surface a JSON-RPC error message."
  - "blockTagHex tested against the ARITHMETICALLY CORRECT 0x2a70420 for 44,500,000; the plan literal 0x2a76d80 was wrong (Rule 1)."
  - "TDD RED/GREEN collapsed to one feat commit per task: a Haskell spec importing a not-yet-existing module fails at COMPILE time, which would leave the whole suite non-building at a committed RED — so module+spec land together, always-green."

patterns-established:
  - "Any new chain-touching spec must (a) read only a frozen fixture, (b) contain no URL/transport literal, and (c) be registered in package.yaml tests.unit.other-modules AND wired into test/Spec.hs — an omission is a silent skip."

requirements-completed: [CTX-FEE]

# Metrics
duration: ~1h wall (single session)
completed: 2026-07-21
---

# Phase 10 Plan 02: Chain-Access Substrate (Chain.Abi + Chain.Rpc) Summary

**The ABI codec and JSON-RPC client the premium read route needs are built and fully tested OFFLINE: sign extension, `unchecked` wraparound at both 128 and 256 bits, the three-branch `feeGrowthInside` identity, and Keccak-256 (proven distinct from SHA3-256) are each a named, filterable spec; `Panel.Variance`'s forked `wordAt` and RPC retry loop are DELETED and re-sourced from the two new single-implementation modules; and a frozen live-probe fixture reproduces the three RESEARCH accumulator invariants with zero network access. Suite 62 → 89/0.**

## Public APIs (consumed by 10-03 .. 10-06)

### `Chain.Abi`
```haskell
decodeWordAt      :: Bool -> Int -> ByteString -> Integer   -- signed? -> word idx -> RAW returndata -> value
encodeWord        :: Integer -> ByteString                  -- 32-byte big-endian (mod 2^256)
encodeUint256     :: Integer -> ByteString                  -- alias of encodeWord
encodeInt24       :: Int -> ByteString                      -- 32-byte two's-complement (neg -> leading 0xff)
encodeAddress     :: Text -> ByteString                     -- 0x-address -> 32-byte left-padded word
encodeBytesDynamic:: ByteString -> (ByteString, ByteString) -- (head placeholder, len-word ++ padded tail)
decodeUint128Pair :: Integer -> (Integer, Integer)          -- (left=currency1, right=currency0)
diffMod           :: Int -> Integer -> Integer -> Integer   -- (a-b) mod 2^n, always in [0,2^n)
feeGrowthInside   :: Int -> Int -> Int -> Integer -> Integer -> Integer -> Integer
                                                             -- tickCurrent tickLower tickUpper global lowerOut upperOut
keccak256Hex      :: ByteString -> Text                     -- lowercase hex, no 0x (crypton Keccak_256)
selector          :: Text -> ByteString                     -- first 4 bytes of keccak256 of the signature
hexToBytes        :: Text -> ByteString                     -- 0x-hex -> raw bytes (even length; else empty)
bytesToHex        :: ByteString -> Text                     -- raw bytes -> lowercase hex, no 0x
bytesToInteger    :: ByteString -> Integer                  -- big-endian
```
`feeGrowthInside` branches (all `mod 2^256`, all non-negative): `tickCurrent < tickLower -> lower-upper`; `tickCurrent >= tickUpper -> upper-lower`; else `global-lower-upper`. Boundary is asymmetric — `tickCurrent == tickUpper` takes the `>=` branch. `decodeUint128Pair` right slot is **currency0 (ETH)**, the reconciliation target.

### `Chain.Rpc`
```haskell
data RpcEnv = RpcEnv { reUrl :: Text, reMaxRetries :: Int, reBackoffMicros :: Int }
defaultBaseEnv, drpcFailoverEnv :: RpcEnv        -- mainnet.base.org ; base.drpc.org (archive-capable)
rpcPost             :: RpcEnv -> Text -> [Value] -> IO (Either String Value)   -- method -> params -> result
ethCall             :: RpcEnv -> Text -> ByteString -> BlockTag -> IO (Either String ByteString)
ethGetBlockByNumber :: RpcEnv -> Integer -> IO (Either String BlockHeader)
ethBlockNumber      :: RpcEnv -> IO (Either String Integer)
data BlockTag = BlockNumber Integer | Latest
blockTagHex         :: Integer -> Text           -- minimal lowercase 0x; blockTagHex 44500000 == "0x2a70420"
blockTagValue       :: BlockTag -> Value
data BlockHeader = BlockHeader { bhNumber :: Integer, bhTimestamp :: Integer }
decodeCallResult    :: Value -> Either String (Integer, Integer)   -- envelope -> (currency1 left, currency0 right)
```
`ethCall` and `decodeCallResult` FAIL LOUD: empty returndata (`0x`), missing `result`, or a JSON-RPC `error` object all yield `Left` — never a decoded zero. The retry/backoff loop lives ONLY in `rpcPost`.

## Golden fixture

`econometrics/test/fixtures/premium-acc-golden.json` — chunk `tokenType=0 [-199680,-197280]`, owner = PanopticPool, vegoid 8. Four readings, each with the recorded `expected_currency0_x64` and a synthesised 32-byte `result` word (value in the currency0/right slot, currency1/left = 0; `returndata_synthesised: true` in `_provenance` because RESEARCH recorded only the decoded accumulator, not the full 64-byte returndata):

| block | leg | atTick | currency0 X64 |
|-------|-----|--------|---------------|
| 44,500,000 | gross (short) | stored | `0x3363c8e16f43182fb` |
| 47,000,000 | gross (short) | stored | `0x3cac79361af8320491` |
| 47,000,000 | owed (long) | stored | `0x40929eb1367967c87b` |
| latest | gross | −200000 | `0x42c22ac671fe20c945` |

Proven offline: monotone in block height (gross 44.5M < gross 47M), owed(47M) > gross(47M), atTick-extrapolated > stored.

## Task Commits

1. **Task 1: Chain.Abi — codec, sign extension, wraparound, feeGrowthInside, keccak** — `8849e9b` (feat)
2. **Task 2: Chain.Rpc — lift transport out of Panel.Variance, freeze the golden fixture** — `3feec71` (feat)

## Verification

- `stack test` — **89 examples, 0 failures** (Phase-9/10-01 baseline of 62 preserved; +27 new: 19 Abi, 4 Rpc, 4 premium-golden).
- Targeted filters all exit 0: `-m "Chain.Abi"`, `-m "wraparound"`, `-m "feeGrowthInside"`, `-m "Chain.Rpc"`, `-m "premium golden"`, `-m "Panel.Variance"` (the refactor did not change behaviour).
- `stack build` clean of new `-Wall` warnings on all touched files (pre-existing `Subgraph.hs`/`Main.hs` warnings are out of scope).
- `! grep -rE 'https?://' econometrics/test/Chain/` — the hspec suite is fully offline.
- `! grep -n 'wordAt ::' src/Panel/Variance.hs` — the duplicate ABI implementation is gone; `grep -E '^import +Chain\.Rpc' src/Panel/Variance.hs` — the transport is lifted, not forked.
- Both new spec modules registered in `package.yaml` `tests.unit.other-modules` and wired into `test/Spec.hs`.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Plan's `blockTagHex` golden literal was arithmetically wrong**
- **Found during:** Task 2
- **Issue:** The plan and its acceptance behavior assert `blockTagHex 44500000 == "0x2a76d80"`. 44,500,000 in hex is `0x2a70420` (verified: `0x2a70420` = 33554432 + 10485760 + 458752 + 1024 + 32 = 44,500,000). `0x2a76d80` would be 44,527,488.
- **Fix:** Implemented `blockTagHex` correctly (minimal lowercase, no leading zeros) and tested against `0x2a70420`, with an in-test comment noting the plan literal was wrong. Encoding the wrong literal would have shipped a knowingly-false test.
- **Files:** `src/Chain/Rpc.hs`, `test/Chain/RpcSpec.hs`
- **Commit:** `3feec71`

**2. [Rule 3 - Blocking] `tests.unit` lacked an `aeson` dependency**
- **Found during:** Task 2
- **Issue:** `RpcSpec` parses the golden fixture JSON directly (the fixture is a bespoke shape, not a `Panel.*` library type), so the test module imports `Data.Aeson`; the `tests.unit` stanza did not depend on `aeson`, causing a hidden-package compile error.
- **Fix:** Added `aeson` to `tests.unit.dependencies` in `package.yaml`.
- **Files:** `econometrics/package.yaml`
- **Commit:** `3feec71`

**3. [Rule 3 - Blocking] Comment wording collided with the plan's `!grep` acceptance criteria**
- **Found during:** Task 2 verification
- **Issue:** The acceptance criteria `! grep -rE '...|httpLBS|parseRequest' test/Chain/RpcSpec.hs` and `! grep 'publicnode\|llamarpc' src/Chain/Rpc.hs` reject those literal tokens anywhere in the file, including prose comments — my first-draft comments named them descriptively.
- **Fix:** Reworded the comments to describe the same facts without the forbidden literal tokens. No code behavior change.
- **Files:** `src/Chain/Rpc.hs`, `test/Chain/RpcSpec.hs`
- **Commit:** `3feec71`

### Process note (not a code deviation)

**TDD RED/GREEN collapsed to one commit per task.** The plan is `type: tdd`. In Haskell, a spec that imports a not-yet-existing module fails at COMPILE time, so a separately-committed RED would leave the entire test suite non-building at that commit. Each task therefore lands module + spec together, verified green against the targeted `-m` filters before commit — the always-green invariant the executor requires. The internal RED→GREEN iteration still happened (e.g., the `blockTagHex` literal and the ambiguous-type/aeson build errors were caught by running the specs before committing).

## Authentication Gates

None. All work is offline (frozen fixtures); no RPC endpoint was contacted and no secret was introduced.

## Next Phase Readiness

- **10-03 (epoch↔block index):** consume `ethGetBlockByNumber`/`blockTagHex`/`BlockHeader` for the HOURLY-epoch binary search; `diffMod`/`bytesToInteger` are available. Remember 10-01's downstream flag — hourly grid means ~2832 boundaries, not 119.
- **10-04 (read schedule):** build `getAccountPremium` calldata with `selector` + `encodeBytesDynamic` (dynamic `bytes poolKey` first arg) + `encodeAddress`/`encodeInt24`/`encodeUint256`; decode returns via `ethCall` + `decodeUint128Pair` (currency0 = right slot). Re-estimate call volume against the hourly grid before locking.
- The single-transport/single-codec rule is now enforced by deletion — future chain code must import `Chain.Rpc`/`Chain.Abi`, never re-roll a retry loop or word reader.

---
*Phase: 10-streaming-premium-reconstruction-and-reestimation*
*Completed: 2026-07-21*

## Self-Check: PASSED

- All 9 claimed files exist on disk (5 created, 3 modified, + this SUMMARY).
- Both task commits (8849e9b, 3feec71) exist in history.
- No home-absolute paths or keys in the created source/fixture files.
