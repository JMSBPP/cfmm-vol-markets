# sys / observer AlignTick behavioral equivalence

Date: 2026-11-13  
Branch / track: `type/Premium` (Observer refactor)  
Gate: `just test-current` → `forge clean && forge test --match-contract Observer -vvvv`

## Problem

Refactor AlignTick’s tick-disturbance path into `sys` + `stateObserver` while remaining **behaviorally equivalent** for pool movement and call graph. Spec: `.spec/RefactorController.spec/root.md`. Implementation today has placeholders (dual Main paths, confused origin/dst, MarketKey-on-`this`, unfinished unlock/swap, Controller `afterSwap` duplicated with AlignTick TAKE/SETTLE).

## Goals

- Main → **sys** (external face) → **stateObserver** (`ObservedState(Tick)` + `UpdatedTick`).
- Sys XOR AlignTick on `set_tick` (whichever of `SYS_SLOT` / `ALIGNER_SLOT` has code).
- `just test-current` drives work: uncomment Observer expects → **RED → GREEN**.
- This milestone: **tick-only** `ObservedState` (Utilization later).

## Non-goals

- Utilization `ObservedState` live path.
- Rewiring Controller `afterSwap` for legacy AlignTick-only pools in the same slice beyond what the Observer test needs.
- `delegatecall` for MarketKey (rejected).

## Decisions (brainstorm lock)

| ID | Choice |
|----|--------|
| Call graph | Main → sys → stateObserver (two runtime addresses) |
| External face | **sys** exposes `updateTick` + `unlockCallback` |
| ObservedState scope | Tick only |
| ObservedState owner | **stateObserver** builds/holds carrier; `UpdatedTick(ObservedState(Tick)) → Tick` |
| Returned Tick | Observer bookkeeping only; Main `store_tick` unchanged |
| Dual path | XOR: sys if `SYS_SLOT` coded; else AlignTick if `ALIGNER` coded |
| Sequence | `updateTick` → ObservedState → `UpdatedTick` → unlock → `sys.unlockCallback` → swap |
| afterSwap | Fold unspecified settle/take into sys unlock path; Controller `AFTER_SWAP` no-op on sys path |
| MarketKey / PM | AlignTick-style: sys has `POOL_MANAGER` + `IO`→Main; **CALL** `getMarketKey` (no delegatecall) |
| Approach | Port AlignTick into sys; observer owns state carrier |
| TDD | Uncomment `test/sys/Observer.t.sol` expects + invariant; RED→GREEN |

## Architecture

```
Main.set_tick (ticks differ)
  ├─ SYS_SLOT has code ──► sys.updateTick(prev, new)
  │                         ├─ stateObserver: ObservedState(Tick)
  │                         ├─ UpdatedTick(observed) → Tick (observer storage)
  │                         ├─ unlock(shock calldata)
  │                         └─ PM → sys.unlockCallback
  │                               ├─ getMarketKey via IO (Main)
  │                               ├─ swap (direction/distance/exposure)
  │                               ├─ TAKE specified (ex-AlignTick)
  │                               └─ settle/take unspecified (ex-Controller afterSwap)
  └─ else ALIGNER_SLOT has code ──► requestTickAlignment (legacy AlignTick)
```

## Components

### Main

- On tick change: if `extcodesize(SYS_SLOT)` → external `sys.updateTick` (or agreed selector); **do not** also call AlignTick.
- Else if aligner coded → existing `requestTickAlignment`.
- Remove in-process `UpdatedObservedTick(...)` from the set_tick branch once external sys call exists.
- `store_tick` / averages / RV unchanged relative to today’s Main semantics.

### sys

- Slots: `POOL_MANAGER`, `IO` (Main), `STATE_OBSERVER`, plus existing setter surface used by tests (`setSys` on Main stores address; `setStateObserver` on sys).
- `updateTick(int24,int24)`: caller checks (Main/IO); drive observer ObservedState + `UpdatedTick`; `unlock`.
- `unlockCallback`: port AlignTick swap construction + specified TAKE; fold Controller afterSwap unspecified notify/sync/settle/take.
- Not responsible for long-term Controllers/ hook ownership beyond making sys-path swaps self-contained.

### stateObserver

- Storage for `ObservedState(Tick)`.
- API: construct from shock; `UpdatedTick(self: ObservedState(Tick)) → Tick`.
- Does **not** call `unlock` (sys is the unlock caller so callback returns to sys).

### Controller

- On sys-path: `AFTER_SWAP` becomes no-op (or deleted) once settle/take live in sys callback.
- AlignTick-only deployments keep prior afterSwap until migrated.

## Types

- Keep comptime `ObservedState(T)` with Tick + Utilization arms; only Tick is exercised.
- Migrate public observer update API to `UpdatedTick(ObservedState(Tick)) → Tick`.
- `AlignCalldata` / `TickShock` remain migration bridges inside sys/observer as needed; prefer ObservedState at the observer boundary.

## Testing

Harness: `test/sys/Observer.t.sol` via `just test-current`.

1. Uncomment:
   - `expectedStateObserverFirstCalls__InsideDoTickDisturbance` (sys `updateTick`, `unlockCallback`)
   - `expectedPoolManagerSecondCalls__InsideDoTickDisturbance` (PM `swap`)
   - `invariant__InsideDoTickDisturbance`
2. Push/fix RED on purpose.
3. Implement placeholders one failure at a time (chunk approve → commit discipline per repo rules).
4. GREEN when expectCalls + tick/slot0 invariant hold under fuzz window loop.

## Placeholder rewrite list

- Main: dual AlignTick + in-process UpdatedObservedTick → XOR + external sys call.
- observer: origin/dst unlock stubs; `MarketKeyMemoryOnExt(address(this))` without Main IO.
- sys: add PM + IO; implement updateTick/unlockCallback faces.
- Controller: afterSwap no-op on sys path after logic folded into sys.
- Test: uncomment expects/invariant.

## Success criteria

- `just test-current` passes.
- AlignTick-only tests remain valid when only `ALIGNER_SLOT` is set (no sys).
- No delegatecall used for MarketKey.
- Utilization ObservedState not required for green.
