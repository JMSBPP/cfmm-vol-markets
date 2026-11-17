# sys/observer AlignTick equivalence Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `just test-current` (Observer differential) green with Main→sys→stateObserver behaviorally equivalent to AlignTick for tick disturbance.

**Architecture:** sys is the only PM face (`updateTick`, `unlockCallback`) with `POOL_MANAGER` + `IO`→Main and CALL `getMarketKey`. stateObserver owns `ObservedState(Tick)` and `UpdatedTick(ObservedState(Tick)) → Tick`. Main XOR-dispatches sys vs AlignTick by extcodesize. Controller afterSwap settle/take folds into sys unlockCallback on the sys path.

**Tech Stack:** Plank (`src/sys/*.plk`, `src/Main.plk`), Foundry (`test/sys/Observer.t.sol`), Uniswap v4 PoolManager, existing AlignTick / Controller as port sources.

**Spec:** `docs/superpowers/specs/2026-11-13-sys-observer-align-tick-equivalence-design.md`

## Global Constraints

- Gate command: `just test-current` (= `forge clean && forge test --match-contract Observer -vvvv`).
- Repo: chunk approve/modify before each source commit; agents must not treat local forge as merge proof — push and read CI when shipping; local `just test-current` is the TDD loop the maintainer uses.
- No `delegatecall` for MarketKey.
- Tick-only `ObservedState` this milestone (Utilization arm may exist but unused).
- Selectors: `updateTick(int24,int24)` = `0x697c7250`; `unlockCallback(bytes)` = `0x91dd7346`; `setStateObserver(address)` = `0x689eb85e`; `setSys(address)` = `0x38396dae`; `setIO(address)` = `0x5340463b`; `setPoolManager(address)` = `0x7aef6715`; `getMarketKey()` = `0xe6b12e1e`.

---

## File map

| File | Responsibility |
|------|----------------|
| `test/sys/Observer.t.sol` | RED driver: uncomment expects + invariant; harness wires IO/PM onto **sys** |
| `test/BaseTest.t.sol` | FullContext may need sys-aware wiring or Observer overrides it |
| `src/sys/observer.plk` | `ObservedState(Tick)`, `UpdatedTick(self) → Tick`, storage; no unlock |
| `src/sys/sys.plk` | Face: `updateTick`, `unlockCallback`, PM+IO+STATE_OBSERVER; port AlignTick + afterSwap settle |
| `src/Main.plk` | XOR: `SYS_SLOT` → CALL sys.updateTick; else ALIGNER → requestTickAlignment; drop in-process UpdatedObservedTick |
| `src/Controllers/Controller.plk` | afterSwap no-op when sys-path sufficient (or always no-op settle if folded into sys for Observer pools) |
| `src/ProtocolSync/AlignTick.plk` | Reference only for port; keep for AlignTick-only tests |

---

### Task 1: Uncomment Observer test → RED

**Files:**
- Modify: `test/sys/Observer.t.sol`
- Possibly Modify: `test/BaseTest.t.sol` or Observer `setUp` / test preamble for sys IO/PM

**Interfaces:**
- Consumes: existing `IStateObserver.updateTick`, `IUnlockCallback.unlockCallback`, DiffTest helpers
- Produces: failing `test_WhenTheCallerIsMain` as the RED baseline

- [ ] **Step 1: Uncomment the three call sites in the loop**

In `test_WhenTheCallerIsMain`, replace the commented block with:

```solidity
	    expectedPoolManagerFirstCalls__InsideDoTickDisturbance(ctx, windowIdx, tickDisturbance);
	    expectedStateObserverFirstCalls__InsideDoTickDisturbance(ctx, windowIdx, tickDisturbance);
	    expectedPoolManagerSecondCalls__InsideDoTickDisturbance(ctx, windowIdx, tickDisturbance.prevTick, tickDisturbance.newTick);

	    ITick(main).set_tick(tickOnRun);
	    invariant__InsideDoTickDisturbance(ctx);
```

- [ ] **Step 2: Wire env onto `sys` (not only `target`)**

`FullContext` currently calls `setIO` / `setPoolManager` / `setPositionManager` on `target`. Main’s `SYS_SLOT` points at `sys`. Before the loop (after `setSys` / `setStateObserver`), add:

```solidity
	IEnv(sys).setIO(main);
	IEnv(sys).setPoolManager(poolManager);
	IEnv(sys).setPositionManager(positionManager);
```

(If `IEnv` is only on BaseTest, use that interface. Do **not** rely on `target` for the sys path.)

- [ ] **Step 3: Run RED**

Run: `just test-current`  
Expected: FAIL (missing `updateTick` call on sys, and/or unlock/swap/invariant). Record the **first** failure message for Task 2+.

- [ ] **Step 4: Commit test harness RED**

```bash
git add test/sys/Observer.t.sol test/BaseTest.t.sol
git commit -m "$(cat <<'EOF'
test(Observer): uncomment disturbance expects for RED

Drive sys/observer AlignTick equivalence from just test-current.
EOF
)"
```

---

### Task 2: Main XOR dispatch — CALL sys.updateTick

**Files:**
- Modify: `src/Main.plk` (set_tick branch ~181–197)
- Test: `just test-current` (still RED until sys implements updateTick, but expectCall target becomes reachable)

**Interfaces:**
- Consumes: `SYS_SLOT`, `ALIGNER_SLOT`, `completeAlignTickCalldata` / tick words for calldata
- Produces: external call `sys.updateTick(prev, new)` when sys coded; no in-process `UpdatedObservedTick`

- [ ] **Step 1: Replace dual path with XOR**

Where ticks differ after store, use (Plank-shaped):

```plank
	      let alignTickCalldata: AlignCalldata = completeAlignTickCalldata(partialAlignTickCalldata(prevTick), tick);
	      if @evm_extcodesize(@evm_sload(SYS_SLOT)) > 0 {
	      	 // cast sig "updateTick(int24,int24)" → 0x697c7250
	      	 let buff: u256 = @malloc_uninit(68);
	      	 @mstore4(buff, 0x697c7250);
	      	 @mstore32(buff +% 4, TickWord(prevTick));
	      	 @mstore32(buff +% 36, TickWord(tick));
	      	 if !@evm_call(@evm_gas(), @evm_sload(SYS_SLOT), NO_VALUE, buff, 68, 0, 0) {
	      	    // cast sig "FailedToUpdateTickOnSys()" — pick unused selector via cast sig
	      	    @mstore4(buff, /* FailedToUpdateTickOnSys selector */);
	      	    @evm_revert(buff, 4);
	      	 }
	      } else if @evm_extcodesize(@evm_sload(ALIGNER_SLOT)) > 0 {
	      	 requestTickAlignment(alignTickCalldata);
	      }
```

Remove the in-process `UpdatedObservedTick(uniswap, observer, alignTickCalldata)` call and unused imports once nothing else needs them.

- [ ] **Step 2: `just plank src/Main.plk`**

Expected: compile success.

- [ ] **Step 3: `just test-current`**

Expected: still FAIL, but ideally on sys missing `updateTick` / unlock behavior (or revert from empty sys handler) — not on Main skipping the call entirely. Confirm with `-vvvv` that Main CALLs `sys` with `updateTick`.

- [ ] **Step 4: Commit**

```bash
git add src/Main.plk
git commit -m "$(cat <<'EOF'
feat(Main): XOR sys.updateTick vs AlignTick on set_tick

Call sys when SYS_SLOT has code; keep AlignTick only as fallback.
EOF
)"
```

---

### Task 3: stateObserver — ObservedState(Tick) + UpdatedTick(self) → Tick

**Files:**
- Modify: `src/sys/observer.plk`
- Test: compile via `just plank src/sys/sys.plk` / Main; Observer test still RED on unlock/swap

**Interfaces:**
- Consumes: `Tick`, `TickShock` / shock from int24 pair, `ObservedState`
- Produces:
  - `ObservedStateFromTickShock(shock: TickShock) → ObservedState(Tick)` (name may vary; one clear constructor)
  - `UpdatedTick(self: ObservedState(Tick)) → Tick` — stores observed tick; returns tick for bookkeeping
  - Runtime entry if sys CALLs observer (selector TBD in implementation; minimum: store + return afterTick word). If sys uses Plank in-process imports only, document that sys deployed bytecode must still CALL observer address for the test’s separation — prefer **external CALL** from sys to `STATE_OBSERVER_SLOT` so the address is real.

- [ ] **Step 1: Define `UpdatedTick` on the carrier**

```plank
const UpdatedTick = fn (self: ObservedState(Tick)) Tick {
      let tick: Tick = /* read value field from self */;
      // persist ObservedState(Tick) at a dedicated slot if not already stored
      tick
};
```

Remove / stop exporting the old `UpdatedObservedTick(origin, dst, AlignCalldata)` as Main’s API (sys may keep a thin adapter internally).

- [ ] **Step 2: Constructor from shock**

```plank
const ObservedStateFromTickShock = fn (shock: TickShock) ObservedState(Tick) {
      ObservedState(Tick) { value: AfterTick(shock) }
};
```

(Adjust struct fields to match existing `ObservedState` definition.)

- [ ] **Step 3: Ensure observer `run` does not claim unlock**

Observer must not be the unlock caller. `run` may expose a setter-only/debug surface or a `recordObservedTick` selector if sys CALLs it; keep unlock out.

- [ ] **Step 4: Compile**

Run: `just plank src/sys/observer.plk` (or via `just plank src/sys/sys.plk` / Main)  
Expected: success.

- [ ] **Step 5: Commit**

```bash
git add src/sys/observer.plk
git commit -m "$(cat <<'EOF'
feat(observer): ObservedState(Tick) and UpdatedTick(self)

Carrier API for sys-driven tick observation; no unlock face.
EOF
)"
```

---

### Task 4: sys face — updateTick → observer → unlock

**Files:**
- Modify: `src/sys/sys.plk`
- Reference: `src/ProtocolSync/AlignTick.plk` (`align` → unlock packing)
- Test: `just test-current`

**Interfaces:**
- Consumes: `STATE_OBSERVER_SLOT`, `POOL_MANAGER_SLOT`, `IO_SLOT`, observer UpdatedTick/constructor (via CALL or shared module as implemented in Task 3)
- Produces: runtime `updateTick(int24,int24)` that unlocks PM with `(prev,new)` bytes matching test expectCall

- [ ] **Step 1: Add PM + IO setters on sys** (mirror AlignTick selectors `0x7aef6715`, `0x5340463b`) storing `POOL_MANAGER_SLOT` / `IO_SLOT`.

- [ ] **Step 2: Implement `updateTick` in `run`**

```plank
    // selector == UPDATE_TICK_SELECTOR (0x697c7250)
    // 1) require caller == IO (Main) or policy agreed in review
    // 2) build TickShock / ObservedState via stateObserver CALL
    // 3) UpdatedTick on observer
    // 4) unlock(poolManager) with abi.encode(prev,new) — same packing as AlignTick align():
    //    unlock selector 0x48c89491, offset 0x20, len 64, two int24 words
```

Must match test:

```solidity
vm.expectCall(sys, abi.encodeCall(IStateObserver.updateTick,(prev, new)));
vm.expectCall(sys, abi.encodeCall(IUnlockCallback.unlockCallback,(abi.encode(prev, new))));
```

So unlock calldata encoding must be `abi.encode(int24,int24)` as two 32-byte words (AlignTick style).

- [ ] **Step 3: `just test-current`**

Expected: FAIL moved to unlockCallback missing swap / invariant (updateTick + unlockCallback expectCalls may pass).

- [ ] **Step 4: Commit**

```bash
git add src/sys/sys.plk
git commit -m "$(cat <<'EOF'
feat(sys): updateTick drives observer then unlock

Sys is the PoolManager unlock caller for the Observer path.
EOF
)"
```

---

### Task 5: sys.unlockCallback — port AlignTick swap + specified TAKE

**Files:**
- Modify: `src/sys/sys.plk`
- Reference: `src/ProtocolSync/AlignTick.plk` unlockCallback; `src/ProtocolSync/AlignTickTransition.plk`
- Test: `just test-current`

**Interfaces:**
- Consumes: IO→Main `getMarketKey`, TickDirection/Distance/Exposure helpers, `POOL_MANAGER`
- Produces: PM `swap` matching `expectedPoolManagerSecondCalls__InsideDoTickDisturbance`

- [ ] **Step 1: Port swap construction**

Follow AlignTickTransition: CALL Main `getMarketKey` into buffer; build direction via `precedesTick` / TickDirection; distance via `ExposureAndDirectionAwareTickDistance` with AlignCalldata tuple from shock words; `sqrtPriceLimit` from after tick; swap selector `0xf3cd914c`.

Do **not** use `MarketKeyMemoryOnExt(@evm_address_this())` unless `this` is Main.

- [ ] **Step 2: Port specified-leg TAKE** from AlignTick after swap (credit to sys).

- [ ] **Step 3: `just test-current`**

Expected: swap expectCall closer to PASS; may still fail invariant or CurrencyNotSettled / afterSwap unspecified leg.

- [ ] **Step 4: Commit**

```bash
git add src/sys/sys.plk
git commit -m "$(cat <<'EOF'
feat(sys): unlockCallback swap and specified TAKE

Port AlignTick pool move onto sys for Observer equivalence.
EOF
)"
```

---

### Task 6: Fold Controller afterSwap unspecified settle/take into sys; no-op hook branch

**Files:**
- Modify: `src/sys/sys.plk` (after swap in unlockCallback)
- Modify: `src/Controllers/Controller.plk` (`AFTER_SWAP` → no-op return delta `0` or existing empty path)
- Test: `just test-current`

**Interfaces:**
- Consumes: Controller afterSwap logic (notifyDebt / sync / settleFor / take unspecified)
- Produces: self-contained unlockCallback; Controller afterSwap does not double-settle on sys-path swaps

- [ ] **Step 1: Copy unspecified-leg handling from Controller afterSwap into sys unlockCallback** after swap+specified TAKE, using the swap delta / currencies already in scope.

- [ ] **Step 2: Make Controller `AFTER_SWAP` a no-op success return** (return zero unspecified delta buffer as today empty paths do), so hook permission bit does not double-apply settle.

```plank
    else if selector == AFTER_SWAP_SELECTOR {
       // settle/take owned by sys.unlockCallback on Observer path
       @evm_return(@malloc_zeroed(64), 64); // or match prior ABI return layout with 0 delta
    }
```

Confirm return layout against existing Controller return (`AFTER_SWAP_SELECTOR` + unspecified at offset 32) — keep ABI shape, zero delta.

- [ ] **Step 3: `just test-current`**

Expected: PASS (expectCalls + invariant), or only residual fuzz edges — fix those before declaring green.

- [ ] **Step 4: Commit**

```bash
git add src/sys/sys.plk src/Controllers/Controller.plk
git commit -m "$(cat <<'EOF'
feat(sys): fold afterSwap settle into unlockCallback

Controller afterSwap no-ops; sys owns take/settle for Observer path.
EOF
)"
```

---

### Task 7: GREEN harden + AlignTick regression sanity

**Files:**
- Modify: only if failures remain in Observer or AlignTick suites
- Test: `just test-current`; optionally `forge test --match-contract AlignTick` (maintainer/CI)

- [ ] **Step 1: Re-run `just test-current` until stable green** (fuzz 1000 if default).

- [ ] **Step 2: Sanity — AlignTick-only path**

Run: `forge test --match-contract AlignTick` (or CI push-build).  
Expected: still green when tests set aligner and not sys.

- [ ] **Step 3: Final commit if nits**

```bash
git add -u
git commit -m "$(cat <<'EOF'
fix(Observer): harden sys path after GREEN

EOF
)"
```

- [ ] **Step 4: Push and read CI** per repo rules when shipping the branch.

---

## Spec coverage check

| Spec requirement | Task |
|------------------|------|
| Main→sys→stateObserver | 2, 3, 4 |
| sys face updateTick + unlockCallback | 4, 5 |
| ObservedState(Tick) + UpdatedTick(self)→Tick | 3 |
| XOR sys vs AlignTick | 2 |
| PM + IO + CALL getMarketKey | 4, 5 |
| Fold afterSwap into sys | 6 |
| Uncomment test RED→GREEN | 1 → 6 |
| No MarketKey delegatecall | 5 (explicit) |
| AlignTick-only still works | 7 |

## Placeholder scan

Plan avoids TBD steps; FailedToUpdateTickOnSys selector must be chosen with `cast sig` at implementation time (one concrete 4-byte constant in Task 2).
