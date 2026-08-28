---
phase: 02-volorder-t-minimal-instantiation
plan: 03
status: complete
completed: 2026-08-28
executor: superpowers inline (maintainer session) — per the phase EXECUTION GATE
requirements: [VORD-01, VORD-02, VORD-03]
duration: ~25 min wall-clock (census + document + one checkpoint)
---

# 02-03 — Regression assessment, APPROVED at the checkpoint

> ## ⚠️ STALE — describes the REJECTED design
>
> Everything below that names a local `none` tag, `VolOrder(none)`, `vol_order_base`, or
> `extra: bytes(T)` describes the design in `02-REGRESSION-ASSESSMENT.md` **§4**, which the
> maintainer rejected at the 02-04 code-chunk review on 2026-08-28. It was implemented as `c9844d1`,
> went green on gate `33171200236`, and was **reverted by `3af40fb`**. None of it is in the tree.
>
> **The design of record is `02-REGRESSION-ASSESSMENT.md` §4a**: absence is the std VALUE
> `Option`/`None` (not a tag type); `Extra(T)` is a tagged slice DESCRIPTOR (`flags | offset | len`)
> living in `src/types/Extra.plk`, carrying no tokenId; the builder still returns `PanopticTokenId`;
> every pre-Phase-2 caller is `VolOrder(calldata)`. Kept verbatim as the record of a design that was
> tried, measured and dropped — superseded, not deleted, by the maintainer's decision.

## Census as re-measured (tree `703e744`)
- `.plk`: **17** files (CONTEXT.md said 12 — that was a `src/`-only grep; the plan's context already listed all 17). 34 non-comment type/literal sites: `VolOrder.plk` 17, `PanopticTokenIdSetterLib.plk` 7, `VolOrderValidationLib.plk` 5, five single import-line hits.
- `.sol`: **19**, as predicted. Plus 2 masked.

## Classification counts
| Bucket | Rows |
|---|---|
| mechanical call-site update | **4** — `VolOrder.plk`, `PanopticTokenIdSetterLib.plk`, `VolOrderValidationLib.plk`, `VolOrderToPanopticTokenIdHarness.plk` (internal only; surface frozen) |
| survives untouched | **31** (12 `.plk` incl. 8 comment-only; 19 `.sol`) |
| OUT OF SCOPE | **1** — `src/modules/VolOrderManagerMod.plk` (its own unrelated `VolOrder` struct) |
| UNVERIFIED (masked, measured RED, #63) | **2** — `VolRangeWidth.t.sol`, `SpreadTickAssimetryHelper.t.sol` |
| elimination candidate | **NONE PREDICTED** |

## Design decisions (approved)
1. Local `none` tag — `VolOrder(none)` omits `extra`; `.extra` is a missing-field compile error. (`ctime` recorded as upstream synonym.)
2. Explicit `comptime T: type` threading, following `Shock(R)`; not `$T` inference.
3. `extra: bytes(T)` for `memory`/`calldata`; absent for `none`.
4. `vol_order_base(T, vo) → VolOrder(none)` — the single region-agnostic projection.
5. Only `vol_order_to_panoptic_token_id` takes `comptime T`; everything else `VolOrder(none)`.
6. The concept: a phantom type parameter as region index (Haskell `ST s`).

## Checkpoint
- Maintainer resume signal, verbatim: **`approve`** (2026-08-28).
- Question 3 outcome token: **MOOT (red)**.
- HARD STOP rule confirmed.

## Deviations
- `OUT OF SCOPE` literal appeared twice (table row + a §4 sentence referring to it); the sentence was reworded to satisfy the `= 1` criterion — content unchanged. Commit amended and force-with-lease pushed before the checkpoint was presented.
