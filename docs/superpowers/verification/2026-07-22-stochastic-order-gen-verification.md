# StochasticOrderGen — verification record & tracked follow-ups

**Date:** 2026-07-22
**Scope:** the StochasticOrderGen segment of PR #9 (`feat/rpc-api` → `develop`).
**Why this file exists:** the working evidence trail (per-task implementer reports,
repl transcripts, progress ledger) lives in `.superpowers/sdd/`, which is gitignored
— and GitHub issues are disabled on this repo. The PR-gate Reality Checker flagged
that merging would otherwise delete both the evidence and the deferred-work list.
This file is the durable distillation of both.

## Success criteria → evidence

Spec: `docs/superpowers/specs/2026-07-21-stochastic-order-gen-design.md`.

| # | Criterion | Evidence |
|---|-----------|----------|
| 1 | `VolOrder.{Encoding,Decode,Rpc}` gain the five functions with the exact signatures | In-tree; per-task reviews approved each |
| 2 | `StochasticOrderGen.{Types,Simulate,Report,Rpc}` exist with the described exports | In-tree |
| 3 | `pack_vol_order_input` bit layout verified against `packInput` before any live call | Repl cross-check (Task 1); independently re-verified by three later reviewers against `test/pos_spec/VolOrderManagerBatch.t.sol:57` and the contract's own decode, including edge `(2^88-1, 2^24-1, 65534)` |
| 4 | Poisson draw > `length orders` fails clearly with zero RPC calls | Guard precedes `mapM create_orders`; `simulate_batch_count` does no I/O (code trace). Live: `Poisson 50` vs 1 order fired the guard with the exact message (Task 7). The original "block number unchanged" observation cannot itself prove zero `eth_call`s — the code trace is the proof |
| 5 | > 128 orders split into multiple sequential calls, never one oversized call | Live: `Poisson 145` drew 146 → chunks `[128, 18]`, both mined; ran 4× (same fixed seed, so one scenario repeated — one chunk-split shape exercised, including a full-128 chunk) |
| 6 | Preview per-order results match what landed, incl. an invalid order as `(False, 0)` without revert | Live: `[good, skew=65535, good]` → `(True,585),(False,0),(True,586)`; adjacent ids prove the skipped order consumed no id |
| 7 | Out-of-range `vol_target` in `[2^88, 2^104)` fails before calldata is built | Repl: `2^88+1` → `Left "vol_target out of range …"` (Task 1); bound re-verified against `VolOrderValidationLib.plk`'s `MAX_STRIKE` by later reviewers |
| 8 | `orderCount()`-delta + `getOrderPacked` readback matches the preview in a live run | Live, repeatedly (chunked runs + best-effort run). Independently re-derived off the rig by the PR-gate Reality Checker via `cast`: `orderCount()==591`, slot-0 sentinel `==0`, ids 585/586/587/588–591 all decode to the exact submitted orders, block count consistent |
| 9 | Non-canonical bool word rejected | Repl: hand-built payload with bool word `2` → `Left "… non-canonical bool word at index 0: 2"` (Task 2) |
| 10 | `cabal build` clean, zero warnings | Every task + every fix commit |

**Id semantics (the one mid-flight correction):** the contract mints ids 1-based
(`id = orderCount + 1`; slot 0 permanently zero as the nonexistent-order sentinel).
The plan's original 0-based readback range was corrected from contract source before
the first live run (commit `443070a`) and empirically confirmed by the live ids above.

## PR-gate findings and how they were resolved (commit `HEAD` of this change)

- **Consistency check anchored on preview's absolute ids** (specialist M1): now
  compares the count delta against the preview's success *pattern* (stateless
  validation ⇒ pattern is preview-stable) and derives expected ids from the locally
  read counter. A concurrent writer now causes a loud, correctly-attributed failure
  instead of a misleading "preview diverged" message.
- **Readbacks at `Latest`** (specialist M2): `after_count` and every `getOrderPacked`
  now pinned to `BlockWithNumber (receiptBlockNumber receipt)`.
- **`receiptStatus` never checked on the batch path** (specialist M4): `create_orders`
  now fails loudly on a reverted transaction (with tx hash); `report_batch_result`
  prints the status line. The singular `create_order` path keeps its existing
  report-the-revert behavior.
- **Tx hash absent from mismatch diagnostics** (Reality Checker M2): both failure
  messages now carry the tx hash — the receipt itself is lost when the `fail`
  escapes as an `IOException`, so the message is the surviving handle on committed
  state.
- **skew accept-set seam** (specialist M3): deliberately **kept**, now documented at
  the validator. Client bounds are field-width bounds; skew's business rule is one
  tighter (`[1, 65534]`). `skew = 65535` is the only client-passing,
  contract-rejected input and is the test vector that exercises best-effort
  semantics end-to-end (spec Testing step 4). Callers wanting pre-flight business
  validation must bound skew themselves.
- **Spec decision 10 overclaimed independence** (Reality Checker M3): the remaining
  single-writer-window assumption is now stated in the spec, with its failure mode
  (loud, post-commit) named.
- **`length preview == length orders`** now asserted explicitly (specialist m1).

## Tracked follow-ups (deferred deliberately, all fail-safe as-is)

1. **Interleaved per-chunk reporting.** `run_order_gen` reports only after the whole
   fold; a mid-fold failure discards the reports of chunks that already mined (their
   tx hashes now survive in the error message, which is the minimal fix). A per-chunk
   reporting callback would make partial runs fully self-describing.
2. **Harden `decode_create_orders_result` header validation** (one themed change):
   check the offset word against `0x20`; compute the length guard in `Integer` before
   narrowing `count` to `Int`; currently unexploitable against this contract
   (hardcoded `0x20`, `count <= 128`).
   > **MEASURED 2026-08-01 (plan 21-05) — still OPEN, now with evidence.** The offset
   > leniency was demonstrated rather than inferred: flipping the last hex character of
   > the outer offset word in `offchain/rig/batch-return-capture.json` (`0x20` → `0x21`)
   > leaves `decode_create_orders_result` decoding the bytes **successfully and
   > silently**, while a Solidity `abi.decode` would follow the corrupted pointer. The
   > suite is not blind — `rpin05_live_bytes_match_the_external_golden` reddens on it —
   > but the decoder is. "Currently unexploitable" still holds against this contract.
3. **Shared `MAX_BATCH` constant** between `VolOrder.Rpc` and
   `StochasticOrderGen.Rpc` (and a comment tying both to the contract's
   `MAX_BATCH = 128`). All three sites agree today; divergence is fail-safe.
4. **`read_order_count` should require exactly 32 return bytes** —
   `hex_to_integer` maps an empty return (codeless address) to `0` instead of
   failing; currently masked because the preview decode rejects first.
5. **Whole-word storage verification** in `verify_mined_order`: recompute the full
   expected storage word (incl. `tickSpacing = 20` at bits 104–127) and compare
   whole words, catching tickSpacing drift and junk high bits the 3-field unpack
   ignores.
   > **PARTIALLY ADDRESSED 2026-08-01 (plans 21-01, 21-05) — the production half is
   > still OPEN.** Plan 21-01's `rpin03_storage_round_trip` asserts the tickSpacing slot
   > at bits 104..127 equals the module constant `20` and that bits >= 248 are zero,
   > over six `vega_corners`. That is TEST-side coverage of the property, against a word
   > built by the test's own `pack_storage_reference`. **`verify_mined_order`
   > (`offchain/lib/VolOrder/Rpc.hs:94-104`) is unchanged**: it still compares the
   > 4-field record produced by `unpack_vol_order_storage`, which discards bits 104..127
   > and bits 248..255 before the comparison — so a mined word with drifted tickSpacing
   > or junk high bits is still ACCEPTED. That is exactly what this item asked to catch.
   > 21-05 checked this rather than transcribing its plan's claim that the item was
   > fully addressed; it is not.
6. **Golden-vector round-trip tests** for the three bit layouts in the (currently
   stub) cabal test-suite: corners `(1,1,1)`, `(2^88-1, 2^24-1, 65534)`, and the
   rejected `(·,·,65535)`.
7. **Dead event decoder**: `VolOrder.Decode.decode_order_created` /
   `Report.report_order_created` target the legacy module's event; the deployed
   pos_spec module emits no logs. Already filed as its own follow-up spec (spec Out
   of scope); delete or mark legacy when that lands.
   > **OBSOLETE 2026-08-01 (plan 21-05). Do not action this item.** Its premise —
   > "the deployed pos_spec module emits no logs" — is now FALSE: V2 emits
   > `emit_vol_order_created` on both the strict and the batch path
   > (`src/lib/events/VolEventsLib.plk:47-54`, `@evm_log2` over a 128-byte buffer).
   > The decoder is LIVE, not dead, and plan 21-03 re-pinned it to the V2 shape (two
   > topics, four data words, `orderId` from the indexed topic) and confirmed it
   > against the first E1 v2 log ever captured off a real chain. Deleting the decoder
   > as this item proposes would have removed live code. Superseded in place rather
   > than deleted, so the reasoning that produced it stays legible.
8. **Cross-track (Plank session)**: the legacy `src/modules/VolOrderManagerMod.plk`
   + `src/modules/VolOrderManager.s.sol` pair still deploys the old event-emitting,
   multicall-less contract into the same nominal role; a rig deployed via the wrong
   script reproduces exactly the stale-rig failure that paused Task 9.
