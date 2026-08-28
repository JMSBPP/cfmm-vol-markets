---
phase: 02-volorder-t-minimal-instantiation
plan: 04
status: complete
completed: 2026-08-28
executor: superpowers inline (maintainer session) — per the phase EXECUTION GATE
requirements: [VORD-01, VORD-02, VORD-03]
---

# 02-04 — VolOrder(T) over a region + the Extra(T) descriptor, test-first

> Rewritten 2026-08-28. The first version summarised `c9844d1` (local `none` tag, `vol_order_base`,
> `VolOrder(none)`), which the maintainer rejected at chunk review and `3af40fb` reverted.

| | |
|---|---|
| Design of record | `02-REGRESSION-ASSESSMENT.md` **§4a** (supersedes §4) |
| Tests (RED, first) | `613ad65`, `e4f0e0d` |
| Implementation | `dbc1259` (5 files), `1dd1ce0` (negative-fixture fix) |
| RED run | `33181053911` — unresolved `Extra` / `extra_decode` / `extra_encode` / `vol_order_with_extra` |
| Intermediate | `33181644493` — plank green, 13/14; the negative test caught itself being vacuous |
| **GREEN run** | **`33182346548`** — 76 suites, **287 passed, 0 failed, 3 skipped (290)**, `compile-plank 39 ok` |
| Floor | `VolOrderToPanopticTokenId.t.sol` 10/10 ok, **0-byte diff** |
| Differential | 2× SKIP on `SKIP_REASON` + 2× PASS, 0-byte diff |
| ABI edge | selector set **IDENTICAL** (7); sha256 `e801b0e1…` → `3bca10fc…` |
| Type tests | 14/14 |

## What landed

- **`src/types/Extra.plk` (new).** `Extra(T) = struct T { flags, offset, len }` — a TAGGED SLICE
  DESCRIPTOR in one packed word (flags bits 248..255, offset 216..247, len 200..215) saying WHERE
  the operands live: poolId 48 bits + 4 × 7-bit optionRatios = **76 bits**, packed. It carries **no
  tokenId**. `struct T { … }` makes `Extra(memory)` and `Extra(calldata)` distinct types; a
  non-region `T` is rejected by an explicit `is_region` guard. `extra_decode` rejects reserved flag
  bits AND a len its flags do not imply. Not reinvented: `std::slice::Slice(R,T,arity)` is what
  Phase 3 will build over the ratios — std has no tagged descriptor, which is all this file adds.
- **`VolOrder.plk`**: `VolOrder(T)` with `extra: Option(Extra(T))` — absence is the std VALUE
  `None`, not a tag type, so there is ONE VolOrder per region. `vol_order_with_extra`; generic
  `tick_bucket_from_vol_order_in` plus the concrete wrapper its three callers keep. Everything
  pre-Phase-2 concrete on `VolOrder(calldata)`; `pack_vol_order` body unchanged.
- **`PanopticTokenIdSetterLib.plk`**: `vol_order_to_panoptic_token_id` is generic over `T` but
  **still returns `PanopticTokenId`**; Phase 2 walks the no-payload path only, so the id is
  bit-identical. Five consumers concrete; `vol_order_to_mint` unchanged in shape.
- **`VolOrderValidationLib.plk`**, **`VolOrderToPanopticTokenIdHarness.plk`**: concrete on
  `calldata`; the harness's dispatch surface untouched (+2/−1, no selector or offset moved).

## Process

Every code chunk was presented in an `AskUserQuestion` approve/modify block **before** commit, and
the tests were written and pushed RED **before** the implementation — the two rules the maintainer
set this session after 02-04's first attempt was committed unseen and untested.

## Findings

1. **The negative test was vacuous until `1dd1ce0`**: `bad()` was never called from `run{}` and
   plank does not type-check unreachable code, so `Extra`'s guard never fired. The test caught this
   itself. Second instance of the hazard `Makefile:compile-plank` documents.
2. **`@<digits>` in NatSpec is solc Error 6546** — hit twice in the same file.
3. **`std::slice::Slice(R, T, arity)` is new at plank `00c0a1a`** and is Phase 3's tool for the ratios.
4. Backticks inside `git commit -m` are executed by bash; use `-F`.
5. The design changed twice under review (§4 → §4a → §4a-as-corrected). The branch keeps the
   rejected commits and their reverts rather than a rewritten history; `02-04-GATE-EVIDENCE.md`
   lists the superseded runs explicitly so no one mistakes them for evidence of what merges.
