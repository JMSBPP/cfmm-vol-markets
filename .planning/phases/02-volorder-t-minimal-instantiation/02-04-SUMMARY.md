---
phase: 02-volorder-t-minimal-instantiation
plan: 04
status: complete
completed: 2026-08-28
executor: superpowers inline (maintainer session) — per the phase EXECUTION GATE
requirements: [VORD-01, VORD-02, VORD-03]
duration: ~35 min wall-clock (one gate cycle; no fix commits)
---

# 02-04 — VolOrder(T) minimal instantiation: green on the first push

| | |
|---|---|
| Refactor commit | `c9844d1a7a18739812fab09eebcfb712aac40ee0` — 4 files, +94/−38, ONE commit |
| GATE_REF | **`33171200236`** success (approve/forge/plank/gate) |
| PUSH_REF | `33171197208` success (stamp step, forge build, forge test) |
| Suite | `Ran 75 test suites … 273 tests passed, 0 failed, 3 skipped (276 total tests)` — equal to 02-01 |
| compile-plank | `38 ok, 0 failed, 0 skipped`, entry set identical |
| Regression floor | `VolOrderToPanopticTokenId.t.sol` 10/10 `[PASS]`, **0-byte diff** → VORD-02 bit-identity |
| VORD-03 callers | `VolOrderMintSizing.t.sol` 8/8 via `VolOrderMintSizingHarness.plk` (0-byte diff) |
| Differential | 2× `[SKIP: spec oracle not wired…]` + 2× `[PASS]`, 0-byte diff (Phase 1 state preserved) |
| ABI edge | **selector set IDENTICAL** (7); sha256 `e801b0e1…` → `eb063608…` (internals moved, surface did not) |
| Fix commits | none |
| Assessment mispredictions | **none** — committed diff vs `develop` is exactly the 8 std-move + 4 refactor files |
| Evidence | `02-04-GATE-EVIDENCE.md` |

## What landed (per the approved edit list)
- `VolOrder.plk`: `const none = struct {};`, `VolOrder = fn (comptime T: type) type` (4 fields for `none`; `+ extra: bytes(T)` for `memory`/`calldata`; `@compile_error` otherwise), `vol_order_base(T, vo)`, all 16 sites → `VolOrder(none)`; `pack_vol_order` body byte-identical, `unpack` identical modulo the literal.
- `PanopticTokenIdSetterLib.plk`: the ONE generic signature `vol_order_to_panoptic_token_id(comptime T, vo: VolOrder(T), pool_id)` reading geometry through `base = vol_order_base(T, vo)`; five concrete `VolOrder(none)` signatures; `vol_order_to_mint` passes `none`.
- `VolOrderValidationLib.plk`: 4 sites → `VolOrder(none)`.
- Harness: `+2/−2`, import `none` + the single call; no selector, offset or return moved.

## Deviations
1. Plan sed missed 2 sites (`self: VolOrder ,skew` — space before comma); reconciled by hand, sed not loosened.
2. Plan-inserted comments contain `VolOrder(none)`, inflating its own `grep -c` (20/18, 6/5); comment-stripped counts exact. The `@compile_error("VolOrder: …")` string literal also matches the "bare VolOrder" regex.
3. `set -e` did not abort the executor shell on the failed count; Task 2 edits ran before Task 1 reconciliation. Nothing wrong committed.
4. sha256 moved with the selector set fixed — allowed by the plan, recorded rather than hidden.
