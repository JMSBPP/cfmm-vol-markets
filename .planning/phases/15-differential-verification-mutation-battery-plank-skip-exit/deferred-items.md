# Phase 15 — Deferred Items (out of scope, logged not fixed)

## OrderHelper.plk fails `compile-plank` — missing `src/types/Order.plk` (OrderType/pos_spec track)

**Discovered during:** 15-02 Task 2 (PLANK_SKIP exit — running `make compile-plank` after
removing VegaAccountMod from the skip list).

**Finding.** `test/types/OrderHelper.plk` (tracked; committed at `3bf788d "feat OrderType"`)
imports `types::Order::{Order, make, validate_order}` from `src/types/Order.plk`, but
`src/types/Order.plk` — though present in HEAD — is **deleted from the working tree**
(`git status` shows ` D src/types/Order.plk`, an unstaged working-tree deletion). So
`plank build test/types/OrderHelper.plk` fails with `could not open imported file
'src/types/Order.plk'` and three unresolved identifiers.

**Why it is out of scope for 15-02.**
- OrderHelper.plk / Order.plk belong to the **OrderType / pos_spec (vol-type-system) track**,
  not to VegaAccountMod. My change only removed `VegaAccountMod.plk` from `PLANK_SKIP`;
  OrderHelper was never in `PLANK_SKIP`, so its failure is independent of my edit.
- **Proven independent:** with my Makefile change reverted (VegaAccountMod re-skipped),
  `make compile-plank` still reports `10 ok, 1 failed, 1 skipped` — OrderHelper already fails.
  With my change it is `11 ok, 1 failed, 0 skipped`: VegaAccountMod compiles OK (the intended
  +1 ok), OrderHelper remains the sole failure.
- This is the **compile-side twin of the already-documented `OrderTest OrderMakeSucceed`**
  pos_spec harness failure (Makefile `test:` comment block, "5 pre-existing pos_spec failures").
  The presence of `src/types/pos_spec/VolOrder.plk` (green) suggests the OrderType track is
  mid-move (Order → pos_spec/VolOrder); OrderHelper.plk still imports the old `types::Order` path.

**Why NOT fixed here.**
- Restoring `src/types/Order.plk` from HEAD would **clobber another track's intentional
  working-tree deletion** (their in-progress refactor to pos_spec/VolOrder).
- Adding OrderHelper.plk to `PLANK_SKIP`, or filtering it, would be exactly the dishonest
  gate-greening the repo forbids ("a suite that lies about what passes is worth less than no
  suite"; the 5 pos_spec failures are "deliberately NOT skipped").

**Consequence for 15-02.** VegaAccountMod's PLANK_SKIP exit (VVER-02) SUCCEEDED — it compiles
standalone (`build/plank/src_modules_exposure_VegaAccountMod.hex`, no `.err`). But
`make compile-plank` reports `11 ok, 1 failed, 0 skipped` rather than the plan's expected
`12 ok, 0 failed, 0 skipped`, because the OrderType-track OrderHelper.plk occupies the failed
slot. This is a stale-baseline drift since 14-02 (which measured `11 ok / 0 failed / 1 skipped`
when `src/types/Order.plk` was still on disk).

**Owner / next action (OrderType / pos_spec track):** either restore `src/types/Order.plk`
(if the deletion was accidental) or update `test/types/OrderHelper.plk` to import the new
`types::pos_spec::VolOrder` path (if Order was renamed/moved), so `compile-plank` returns to
`12 ok, 0 failed, 0 skipped`.
