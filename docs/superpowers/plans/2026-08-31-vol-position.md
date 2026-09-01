# `VolPosition` Implementation Plan

> **For agentic workers:** TDD RED first per chunk approval. Verification = push → `push-build.yml` / PR `develop-gate` — not local sign-off.

**Goal:** Introduce `VolPosition(V)` — `VolMarketKey × VolOrder × Ladder × LegBook(BaseNotional)` — as the protocol positioned product; project to `PanopticTokenId` + `position_size` (legacy `MintPlan` adapter).

**Architecture:** Binning output collapses Haskell `((Integer×4), TargetVega)` into `LegBook(BaseNotional)`. `VolPosition` stores the ladder (quad option 2) for payoff/re-bin. `PanopticTokenId` is a Panoptic projection, not the root type.

**Spec:** `docs/superpowers/specs/2026-08-31-vol-position-design.md`

**Depends on:** `develop` @ merge of PR #92 (`type/ldf`)

## Global constraints

- **Worktree:** `../vol-markets-type-volposition`, branch `type/VolPosition`.
- **Chunk approval before commit.**
- **TDD RED first** for each behaviour slice.
- **Scoped `git add`** — docs-only commits on this PR until implementation tasks start.

---

## File structure

| File | Responsibility |
|------|----------------|
| `src/types/pos_spec/VolPosition.plk` | `VolPosition(V)` struct + accessors |
| `src/lib/.../Binning.plk` | `vol_position_from_ladder` |
| `src/lib/.../panoptic_v2/VolPositionId.plk` | token-id encode (`vol_position_panoptic_*`, `vol_order_to_panoptic_token_id*`) |
| `src/lib/.../panoptic_v2/VolPositionMint.plk` | `vol_position_to_mint_plan` (Task 3) |
| `test/types/pos_spec/VolPositionHarness.plk` | FFI entrypoints |
| `test/types/pos_spec/VolPosition.t.sol` | Foundry tests |

---

### Task 1 — `VolPosition` type + constructor (RED → GREEN)

**RED:** harness `volPositionFromLadder(...)` → market tag smoke + `(w0..w3, base, ladder.lo, ladder.hi)` on wide fixture.

**GREEN:** `VolPosition.plk` + `vol_position_from_ladder` wrapping `bin_to_legs`.

**Tests:**

- Wide fixture (`WIDE_WIDTH=4000`) — weights/base match existing `Binning.t.sol` oracle.
- `or_min` too high → revert (inherited from `bin_to_legs`).

---

### Task 2 — `vol_position_panoptic_token_id` (RED → GREEN)

**RED:** harness returns tokenId word; assert per-leg `optionRatio` ≠ 1 on wide fixture (ratios from book).

**GREEN:** Extend `vol_order_to_panoptic_token_id` with ratio tuple param **or** new `vol_order_to_panoptic_token_id_with_ratios`; wire from `vol_position_panoptic_token_id`.

**Out:** `Extra` dereference (Phase 3).

---

### Task 3 — `vol_position_to_mint_plan` adapter (RED → GREEN)

**RED:** harness `volPositionToMintPlan` → `(tokenId, position_size)`; `position_size == base`; ratios on tokenId match book.

**GREEN:** Thin adapter in `panoptic_v2/VolPositionMint.plk`. Mark legacy `vol_order_to_mint` deprecated for binning path in comment only.

---

### Task 4 — CI + PR merge

- Push `type/VolPosition` → read `push-build` + `develop-gate`.
- Merge PR to `develop`.
- Delete branch local + origin (`git branch -d`).

---

## Implementation order

```
Task 1 (VolPosition + from_ladder)
    → Task 2 (panoptic_token_id projection)
    → Task 3 (mint_plan adapter)
    → Task 4 (merge)
```

**Not in this plan:** `Extra` pack, `mintPlanFromLadder` Haskell name alias, payoff replica tests using stored `ladder`.
