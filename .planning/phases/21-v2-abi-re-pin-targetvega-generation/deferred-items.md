# Deferred items — Phase 21

## From 21-03 (RPIN-04 stale-pin demo) — **RESOLVED by 21-05 (commit `c3f2ee3`)**

> **CLOSED 2026-08-01.** `sc4_no_retired_value_is_live` now compares retired and live pin
> values NUMERICALLY, exactly as the fix below prescribes, and a value that does not parse
> as hex FAILS rather than being skipped. **Verified by re-running 21-03's identical `jq`
> injection:** the suite reports **4 failures where 21-03 recorded 3**, the new one being
> `sc4_no_retired_value_is_live` naming which retired entry leaked. `rig-pins.json` restored
> byte-identical (sha256 `ecc8dcc3…1c8c845a` before and after); suite back to 65/65. The
> original item is preserved below for the reasoning that produced it.

**`sc4_no_retired_value_is_live` is length-sensitive and misses a LEFT-PADDED retired value.**

During the RPIN-04 observed-RED demo, `.topics.VolOrderCreated.topic0` was set to the
left-padded 32-byte form of `retired.topic_order_created_stale`
(`0x0000…0000a8892769`). Three checks reddened as predicted — but
**`sc4_no_retired_value_is_live` stayed GREEN while a retired value was, in fact, live.**

Cause: the check compares pin values as *lowercased strings*
(`offchain/test/Main.hs`, `sc4_no_retired_value_is_live`). The live pin was 66 characters
and the retired entry is 10 (`0xa8892769`), so the string comparison found no match even
though the two denote the same number.

Consequence: the guard that exists to stop a retired constant coming back to life can be
defeated by zero-padding, which is exactly the form a topic0 takes on the wire.

**Not fixed here, deliberately.** The check is Phase 20's (`20-05`), the blind spot is
pre-existing rather than introduced by 21-03, and 21-03's scope is RPIN-04/RPIN-06. The fix
is to compare retired and live values NUMERICALLY (parse both with the same hex reader,
skipping the non-hex `_note` key) rather than as strings.

Owner: whoever next touches the SC-4 pin guards (candidate: 21-05).

## From 21-03, MEASURED, NOT FIXED — dead build-depends outside this plan's blast radius

`cabal build --enable-tests -j all --ghc-options=-Wunused-packages` reports:

- **library:** `web3-crypto` is unused. Pre-existing — 21-03 did not touch anything that
  imported it. (`time` was also unused *because of* 21-03's change and WAS removed.)
- **test suite:** `mwc-random` is unused. Added by 21-01 for plan 21-04's drawn-order
  checks; removing it would only force 21-04 to add it back.

Neither is a correctness problem. Recorded so the next reader knows both were measured and
consciously left.
