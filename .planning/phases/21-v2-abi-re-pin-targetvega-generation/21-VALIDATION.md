---
phase: 21
slug: v2-abi-re-pin-targetvega-generation
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-07-31
---

# Phase 21 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Source: 21-RESEARCH.md `## Validation Architecture` — the authoritative req→test map lives there.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | **none by design** — plain `exitcode-stdio-1.0` runner (`offchain/test/Main.hs`, 546 lines, 44 checks). A check is a named `IO (Either String ())`; all run, process exits nonzero if any fail. No test framework in `build-depends` and none needed. |
| **Config file** | `cfmm-replicationPlank-rpc-api.cabal`, `test-suite cfmm-replicationPlank-rpc-api-test` stanza |
| **Quick run command** | `cabal test` — **measured: 44/44, exit 0, seconds, NO chain required** |
| **Full suite command** | `cabal build -j all && cabal test` (zero `-Wall` warnings is part of the gate) |
| **Live-rig commands** (not part of `cabal test`) | `bash offchain/rig/deploy-rig.sh`, `bash offchain/rig/verify-rig.sh`, `bash offchain/rig/generate-pins.sh` |
| **Chain-independence** | `cabal test` is chain-independent TODAY (measured with anvil down). RPIN-05 is the only requirement that threatens this — research §5.4 recommends a provenance-bearing capture artifact over a live call inside the suite. Preserve chain-independence. |

---

## Sampling Rate

- **Per task commit:** `cabal build -j all && cabal test` (full suite, seconds, no chain)
- **Per wave merge:** the above **plus** `bash offchain/rig/generate-pins.sh && git diff --exit-code offchain/rig/rig-pins.json`
- **Phase gate:** `deploy-rig.sh` → `verify-rig.sh` → `capture-batch-return.sh` → `cabal build -j all && cabal test` green, **plus the observed-RED demos recorded verbatim before any green is reported** (RPIN-04's stale-topic0 pin; RPIN-06's perturbed-targetVega readback)

---

## Requirements → Test Map (summary — authoritative table in 21-RESEARCH.md)

| Req | Automated check | Exists? |
|-----|-----------------|---------|
| RPIN-01 | `sc4_pin_selector_create_order`, `sc4_cast_agreement`, `sc4_ground_truth_encoder` (pin half) | ✅ passing |
| RPIN-01 | new: `encode_create_order` 4 args decode back to `(strike,width,skew,targetVega)`; leading 4 bytes vs *recomputed* keccak | ❌ Wave 0 |
| RPIN-02 | new: 4-field input word over a constructed corner corpus (`1`, `2^96−1`, `2^96` REJECT, `2^95`, alternating-bit); bits ≥224 zero | ❌ Wave 0 |
| RPIN-03 | new: 248-bit storage round-trip + **≥1 order exhibited whose input word ≠ storage word** | ❌ Wave 0 |
| RPIN-04 | `sc4_pin_topic0_VolOrderCreated`, `sc4_falsifiable`, `sc4_no_retired_value_is_live` — reuse `verify_pin` verbatim | ✅ passing |
| RPIN-04 | new: `decode_order_created` decodes a synthetic **v2** `Change` (**2 topics, 4 data words** — it is a REWRITE, not a constant swap) and returns `Nothing` for a v1-shaped one | ❌ Wave 0 |
| RPIN-05 | capture via `offchain/rig/capture-batch-return.sh` (live rig), assert in `cabal test` against the v4.0 golden incl. N=0 at exactly 64 bytes | ❌ Wave 0 — only chain-dependent work |
| RPIN-06 | new: perturb bits 152..247 of a storage word, assert `verify_mined_order`'s comparison FAILS; live confirmation deferred to Phase 22 | ❌ Wave 0 |
| VEGA-01 | new: fixed-seed draw of N orders, every `targetVega ∈ [1, 2^96−1]` AND in band (`System.Random.MWC.create`, no new dep) | ❌ Wave 0 |
| VEGA-01 | new: generator guards at draw time — drive `draw_target_vega` with an inverted/degenerate `VegaDraw`, require loud failure | ❌ Wave 0 |
| regression | `sc3_literal_purge` — **will redden on a careless comment** (research §7.3) | ✅ passing |
| regression | pin regeneration unaffected by the V1 purge | ✅ **VERIFIED byte-identical** |
| regression | zero `-Wall` warnings | ✅ baseline exit 0, 0 warnings |

---

## Wave 0 Gaps

- [ ] New checks in `offchain/test/Main.hs` — RPIN-01 (encoder half), RPIN-02, RPIN-03, RPIN-04 (decoder half), RPIN-06, VEGA-01. **No new file** — CONTEXT locks one suite.
- [ ] `offchain/rig/capture-batch-return.sh` + `offchain/rig/batch-return-capture.json` — RPIN-05, the only new chain-touching artifact.
- [ ] Shared constructed field-boundary corpus (helper inside `Main.hs`), kept **separate** from VEGA-01's drawn values.
- [ ] Framework install: **none.** Adding `vector`, `tasty` or `hspec` is a deviation to justify, not a default.

---

## Standing Findings the Plans Must Carry

- **F1 (report, never edit):** `src/modules/pos_spec/VolOrderManagerMod.plk:177-188` carries a **stale V1 comment block** ("bits ≥128 MUST BE ZERO", "width … is the TOP field") contradicting that same file's V2 code at 229–235. Plank's territory. An implementer who trusts it ships a V1 packer that passes every offchain test and is silently skipped on-chain.
- **RPIN-04 scope:** the emitter is `@evm_log2` (2 topics, 4 data words); the shipped decoder matches 3 topics from the v1 emitter. `OrderCreatedEvent` loses `orderOwner`/`orderCreatedAt`, gains `orderId`/`orderTargetVega`; `-Wall` will orphan `Data.Time.*` imports.
- **E1 v2 has not been OBSERVED on chain** (anvil was down during research) — the decode shape is derived from emitter source. Capture a real log while the rig is up for RPIN-05.
