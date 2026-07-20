# Pitfalls Research

**Domain:** Plank/EVM best-effort batched registry — `VolOrderManagerMod.plk` (`create_order` store + best-effort multicall) for the rpc_api Haskell `StochasticOrderGen` consumer
**Researched:** 2026-07-19
**Confidence:** HIGH on repo-specific + EVM semantics (grounded in `.planning/STATE.md` catalogued kills and standard `calldataload`/checked-add behaviour); MEDIUM on Plank loop-construct specifics (v0.1.1 loop/recursion semantics unverified — flagged as a gap)

---

## Framing: what "best-effort" actually means on the EVM

There are exactly two ways to make a per-call failure *skippable* inside one transaction, and they have opposite proof obligations:

1. **Call-boundary containment** — the batch `CALL`s (or self-`CALL`s) each order in its own frame and inspects the success flag. A revert in the callee unwinds *only that frame's* storage writes (EVM revert semantics); the batch keeps going. Containment is **structural**; you do not have to enumerate revert paths, but you pay ~2600+ gas/call, inherit the 63/64 gas rule, and open a reentrancy surface you must then close.
2. **Inline pre-validation** — the batch runs `validate → store` in a single frame with no sub-call. "Skipping" is an `if/else`: validated-bad tuples set a fail flag and are not stored. There is **no frame to unwind**, so *any* revert the store logic can still throw (a checked-add panic, a KEPT-type smart-constructor revert, a masking/packing panic) is **uncontained and aborts the whole batch.**

The design (`PROJECT.md`: "validate bounds … construct the KEPT pos_spec `VolOrder` type … store … `orderCount` accumulator", "failed orders are skipped without reverting the batch") reads as **inline pre-validation** — the cheaper, more likely, and *more dangerous* choice. Every pitfall below is written for that reading, with the call-boundary variant noted where it changes the obligation. **The single most important consequence: under inline validation, "best-effort" is a lie unless validation is provably COMPLETE with respect to every revert path in the store logic.** That is Pitfall 1, and it is a first-class provable property, not a hope.

---

## Critical Pitfalls

### Pitfall 1: Incomplete validation silently converts best-effort into all-or-nothing (containment leak)

**What goes wrong:**
`create_order`'s pre-validation checks the *bounds it thought of* (strike/width/skew field widths, zero-width). But the store path has revert sites the author did not enumerate: the checked add `orderCount + 1` (Plank `+` panics `0x11` on overflow — proven live in 14-02), and — the real trap — the **KEPT `VolOrder` pos_spec type may have a smart constructor that reverts on its own invariant**, exactly like the `Haircut`/`RiskPriceX96` newtypes do (12-01: "its reverts come free"). If a tuple passes `create_order`'s bounds but trips a store-path revert, that revert is uncontained (no sub-call frame) and **nukes every order in the batch, including already-validated successes.** The consumer sent N orders, expected N per-call results, and got a full-tx revert.

**Why it happens:**
Developers test the validation branches they wrote and conclude the guard is complete. Completeness w.r.t. *the callee's* revert set is a different, stronger claim than "my bounds checks pass." The `VolOrder` constructor's revert conditions live in a different file (`types/pos_spec`), so they are easy to miss — and pos_spec pricing has 4 red harness tests, so the type is *known* to be sharp-edged.

**How to avoid — the honest invariant and its test:**
State the property as **totality of the batch entrypoint over its input domain**: *for all inputs, the multicall NEVER reverts at the batch level; every per-call outcome is a flag.* Prove it two ways, both CALLED-green through FFI:

- **Totality fuzz:** `forall (strike, width, skew)` drawn as **full-width `uint256`** (not pre-clamped to field widths — dirty high bits are part of the domain), single-element `multicall([tuple])` **never reverts**; it returns `(success, id)` or `(fail)`. A batch-level revert on *any* single-tuple input is a counterexample = a missed validation case. Constructed corpus (NOT `vm.assume` — see Pitfall 8), plus edges: `width=0`, `strike=2^88`, `strike=2^88-1`, `2^256-1` in every field.
- **Soundness+completeness differential:** a helper calls `create_order(tuple)` **standalone** and `try/catch`es the revert; assert `multicall_flag(tuple) == fail  ⟺  standalone create_order reverts`. Forward direction (soundness): no false accepts. Reverse direction (**completeness — the load-bearing one**): every tuple that makes standalone `create_order` revert is flagged-and-skipped by multicall, never batch-reverting.

**Mutation that must die:** delete one validation branch (e.g. the `VolOrder`-constructor precondition mirror, or the field-width bound). If deletion makes a previously-flagged tuple reach an uncontained store revert, the totality fuzz reddens with a *batch revert* (not a wrong value) — a distinctive signature. Keep a **non-fuzz unit anchor** (a hand-picked constructor-tripping tuple) alongside the fuzz so the kill is cache-independent (09-02 lesson).

**If call-boundary containment is chosen instead:** completeness is no longer required for reverts (the frame unwinds them), and the totality property still holds — but you MUST assert the success flag is actually read (a mutant that ignores the `CALL` return value and treats every call as success must die), and Pitfall N/A-1 (reentrancy) turns ON.

**Warning signs:** any store-path op that can revert and is not mirrored by a validation branch; a `VolOrder` constructor with a body that isn't a plain field-copy; a test suite that only feeds *bounded* (already-valid) tuples to the batch.

**Phase to address:** the multicall/best-effort phase — this is its acceptance property, not hygiene. Success criterion: "batch entrypoint proven total over full-width fuzz; multicall-fail ⟺ standalone-revert differential green; validation-deletion mutant reddens with a batch revert."

---

### Pitfall 2: Partial state on a skipped call (orderCount / slots mutated before failure detected)

**What goes wrong:**
A skipped order leaves a footprint: `orderCount` was incremented, or the order slot was written, *before* the failing check ran. Under inline validation there is no frame to unwind, so any write that precedes the failure decision **persists.** Result: `orderCount` counts failures, ids develop gaps, or a phantom half-written `VolOrder` sits at a slot.

**Why it happens:**
Natural imperative ordering — "allocate id, write slot, then sanity-check" — writes before it validates. The `d==1` conflation lesson (14-02: read-conflation is invisible to reader assertions, only raw `vm.load` catches it) applies: a reader-based check can miss a stray write that a neighbour-slot `vm.load` would expose.

**How to avoid:** enforce **validate-completely-before-any-write** ordering in the source, and prove no-footprint with a raw-storage battery, not readers:
- Batch `[valid, INVALID, valid]`; assert `orderCount == prev+2` (not +3); assert the *invalid* order's would-be slot `vm.load == 0`; assert the two valid orders sit at dense ids `prev, prev+1` (Pitfall 6).
- **Aliasing/mutation shape:** snapshot the full touched-slot set (`orderCount` slot, each keccak-derived order slot, and the two *neighbour* slots of the invalid order's would-be location) before and after; assert every non-success slot is byte-identical. Reading via getters is insufficient — use `vm.load` (14-02: readers cannot see slot aliasing).

**Mutation that must die:** move `orderCount++` (or the slot write) *above* the zero-width/bounds guard. Then `batch([width=0])` leaves `orderCount==prev+1` and/or a written slot → battery reddens.

**If call-boundary containment is chosen:** partial state is structurally impossible (the frame reverts its writes) — but still run the battery, and additionally assert the batch does **not** persist writes from a *sub-call that OOG'd its 1/64 retained gas* (see Pitfall 4).

**Warning signs:** any `sstore` textually above the last validation branch; tests that assert only via getters after a mixed batch; `orderCount` read equalling N after a batch with known-bad entries.

**Phase to address:** the `create_order` store phase (write-ordering) verified again in the multicall phase (cross-batch footprint).

---

### Pitfall 3: Calldata-length lies — `calldataload` past end returns zeros, and a phantom tuple can validate

**What goes wrong:**
The batch header says `N` tuples but the calldata carries fewer. On the EVM `calldataload(offset)` past `calldatasize` returns a **zero-padded word, silently** (no revert). So the module reads a phantom tuple `(0, 0, 0)`. If any zero-tuple *validates*, a fabricated order is stored — the consumer is told it created an order it never sent. The "make zero-width invalid" backstop catches this **only when truncation zeroes the width field**: a payload truncated such that `strike`/`width` survive but only `skew` is zeroed reads as `(strike, width, 0)`, `skew=0` is plausibly valid, and the phantom passes.

**Why it happens:**
Plank has no ABI auto-decoder (unlike Solidity, whose decoder reverts on short calldata). The module hand-reads words with `@evm_calldataload`; nothing forces `calldatasize` to match the claimed `N`. Trusting the zero-width guard as the *primary* truncation defence is the specific error.

**How to avoid:** the **primary** guard is an explicit calldatasize check — `require(calldatasize >= HEADER + N * TUPLE_STRIDE)` — and a truncated/over-claimed batch is a **malformed batch that REVERTS the whole tx**, not a per-call skip. Best-effort contains *logical* per-call failures (bad bounds); it must NOT silently drop a *structurally* claimed order, or the consumer's "N sent → N results" contract breaks. Keep zero-width-invalid as a *backstop*, and state it as a backstop.

**Test/assertion:** construct calldata with `count=N` but bytes for `N-1` tuples (and the half-tuple case: `N` tuples' worth minus a few bytes); assert `multicall` **reverts with the calldatasize reason** (`vm.expectRevert`), and `orderCount` unchanged. Separately assert a genuine `(strike>0, width=0, skew=0)` tuple is flagged failed (zero-width backstop) and stores nothing. Corpus includes the pathological "truncation zeroes only skew" alignment to *prove* zero-width alone would have missed it — that test should still pass because calldatasize caught it first.

**Warning signs:** `@evm_calldataload` offsets computed from `N` with no `calldatasize` comparison; a batch that returns `N` results for calldata shorter than `N` tuples; treating a short batch as "just skip the missing ones."

**Phase to address:** the multicall calldata-decode phase (this is the dynamic-array-ABI-in-Plank surface, the milestone's stated main technical risk).

---

### Pitfall 4: Unbounded N — OOG cannot be best-effort'd; MAX_BATCH is load-bearing, not hygiene

**What goes wrong:**
With no cap on `N`, a large batch runs out of gas mid-loop. **Out-of-gas is not a revert that best-effort can skip** — it aborts the entire transaction and unwinds *everything*, including every order successfully processed before the OOG. The consumer pays for the whole batch and gets nothing. This is also a griefing/DoS vector (block-gas-limit exhaustion).

**Why it happens:**
"Best-effort" gives false confidence that failures are always contained — but containment (validation or call-boundary) only catches *reverts*, never resource exhaustion. OOG is categorically outside the containment mechanism.

**How to avoid:** a `MAX_BATCH` constant, checked *before any work*, is load-bearing: it converts "unbounded, unpredictable OOG that eats valid orders" into "explicit early revert; caller resubmits a smaller batch." Pick `MAX_BATCH` so `MAX_BATCH * worst_case_per_order_gas` sits comfortably under the block gas limit with margin (and, if call-boundary containment is used, accounts for the 63/64 rule — deep self-`CALL` batches retain 1/64 gas per frame).

**Test/assertion — corpus `N ∈ {0, 1, MAX_BATCH, MAX_BATCH+1}`:**
- `N=0`: decide and pin the degenerate case — empty batch returns an empty results array, `orderCount` unchanged, no revert (friendlier to the Poisson consumer, whose arrival count can be 0). Assert it.
- `N=1`: minimal non-empty; assert one result, dense id.
- `N=MAX_BATCH`: **measure gas** (`gasleft` deltas) and assert it completes under a fixed budget < block gas limit.
- `N=MAX_BATCH+1`: assert revert with the bound reason **before** any `sstore` (assert `orderCount` unchanged).

**Warning signs:** no `MAX_BATCH` constant; loop bound derived solely from calldata `N`; no gas-measurement test; a review comment saying "best-effort handles big batches gracefully" (it does not — it handles reverts, not OOG).

**Phase to address:** the multicall phase; `MAX_BATCH` is a named requirement with the `MAX_BATCH+1` early-revert as a success criterion.

---

### Pitfall 5: Return-data encoding bugs — dynamic `results[]` length/offset off-by-one (new ABI ground)

**What goes wrong:**
Encoding a dynamic `results[]` return is genuinely new for this codebase — `PROJECT.md`: "every existing module selector takes fixed words; this is the milestone's main technical risk." Bugs: `results.length != N`; wrong dynamic-array head/tail layout (the ABI needs an offset word → length word → elements); per-call result written at index `i` but the length claims `i±1`; the empty-array (`N=0`) encoding (length 0 with a *valid* offset) mis-encoded. A consumer `abi.decode` then either reverts or silently returns misaligned `(success, id)` pairs.

**Why it happens:**
Plank hand-builds the return memory; there is no compiler-checked encoder. Off-by-one in head/tail offsets and length is the classic dynamic-ABI footgun, and this module encodes its first-ever dynamic return.

**How to avoid — differential vs a Solidity reference mock (the v3.0 discipline, 15-01):** define `IVolOrderManager` in Solidity; write a trivially-simple Solidity mock implementing the *same* best-effort multicall semantics; drive **identical** batches into the FFI-deployed Plank module and the mock; `abi.decode(plankReturn, (Result[]))` must succeed (a decode revert is itself a failure signal) and equal the mock's return **element-by-element at tolerance 0**. The mock must be independently simple (not an echo of Plank) so agreement is real (08-02 lesson: a mock that merely echoes satisfies the differential vacuously — anchor at least one fixed batch to a hand-computed expected blob).

**Corpus:** mixed success/failure batches (results array carries both shapes); `N=1` (minimal dynamic array); `N=0` (empty-array encoding — the trickiest edge); `N=MAX_BATCH` (largest offset arithmetic).

**Mutation that must die:** encode `results.length` as `N` when successes `< N` (or vice-versa); shift a per-call result by one slot. Differential reddens.

**Warning signs:** hand-written memory offsets with literal magic numbers; no `abi.decode` round-trip test; the mock reusing Plank's output.

**Phase to address:** the multicall return-encoding phase, co-owned with the consumer-contract phase (Pitfall 7).

---

### Pitfall 6: Id-sequence properties break under mixed success/failure (dense-over-successes, count == successes)

**What goes wrong:**
Ids must be **dense over the successful subset** and `orderCount` must advance by **exactly the number of successes**, not by `N`. Bugs: incrementing `orderCount` on a failed call (count counts failures); assigning an id before validation (gaps at failure positions); reusing ids across batches.

**Why it happens:**
Id allocation and the count accumulator are easy to place on the wrong side of the validation branch (couples to Pitfall 2's write-ordering).

**How to avoid / test:** batch `[valid, invalid, valid, invalid, valid]` from `orderCount = c`; assert `orderCount == c+3`; assert stored ids are exactly `c, c+1, c+2` carrying the three valid payloads (read each slot — module-not-a-black-box); assert the results array maps each success to its id **in order** and the ids are precisely the success subsequence (failures carry a sentinel/no id). Add a **stateful/invariant fuzz** across many batches: `orderCount == total successes ever`, all ids distinct and globally dense, monotonic.

**Mutations that must die:** (a) `orderCount++` on the failure branch → `count == c+5` → dies; (b) id assigned pre-validation → stored ids `c, c+2, c+4` (gaps) → dies; (c) id counter reset per batch → collision across batches → stateful invariant dies.

**Warning signs:** `orderCount` equal to `N` after a mixed batch; non-consecutive stored ids; id derived from loop index `i` rather than a success counter.

**Phase to address:** `create_order` store phase (single-order id/count) and multicall phase (mixed-batch density + cross-batch invariant).

---

### Pitfall 7: Selector / ABI drift silently breaks the Haskell consumer (they hold `0x6501fe94`)

**What goes wrong:**
The rpc_api track's `StochasticOrderGen` has hardcoded `create_order` selector `0x6501fe94` and ABI-encodes batches / decodes `Result[]` against a fixed layout (PR #9 already shipped offchain). Any signature change — `uint88 → uint96`, arg reorder, a tweak to the `Result` tuple — **silently** changes the selector and/or the decode layout. On-chain the tx then hits the module's terminal `revert_empty` (unknown selector) or, worse, mis-decodes; the failure surfaces on the *consumer's* side with no local signal.

**Why it happens:**
The selector is a derived value nobody re-checks after an "innocent" type edit; the contract boundary spans two languages and two repos.

**How to avoid — cast-sig guard + golden vector (v3.0 discipline: cast-keccak slots, cast-sig selectors):** an `interfaces/` file pinning the canonical signature strings, plus a test asserting `cast sig "create_order(uint88,uint24,uint16)" == 0x6501fe94`, the multicall entrypoint selector, and the `Result` tuple ABI string. Add a **recorded golden vector**: a fixed batch → the exact calldata blob the Haskell side produces (captured from PR #9) → assert the module decodes it; and a fixed expected return blob. Cross-checked against the peer per `PROJECT.md` ("selector 0x6501fe94 confirmed both sides; batch-size bound and per-call return shape to be confirmed").

**Warning signs:** a field-type change with no accompanying cast-sig test update; the interface file and the `.plk` selectors diverging; no captured consumer fixture; the "per-call return shape" still unconfirmed with the peer at implementation time (blocker — resolve the open semantics message first).

**Phase to address:** an interface/consumer-contract phase early (pin the ABI before implementing against it), re-verified in the return-encoding phase.

---

### Pitfall 8: Repo-catalogued failure modes that specifically bite the loop

**What goes wrong / how to avoid — carry the STATE.md Accumulated Context forward, each mapped to the loop:**

- **Bounded-loop off-by-one** — constructed boundary corpus `N ∈ {0, 1, MAX_BATCH, MAX_BATCH+1}` (Pitfall 4). Off-by-one manifests as a dropped last order (`N-1` processed) or an extra phantom read past the array (couples to Pitfall 3). Assert `results.length == N` (for the well-formed case) and every index 0..N-1 present.
- **`vm.assume` exhaustion** (STATE Blockers, VDIFF-05/06 lesson) — do **NOT** filter batch calldata with `vm.assume`; random calldata is almost never a well-formed batch, so the fuzzer would exhaust. **Construct** batches with `bound()` and explicit mixed valid/invalid tuples (09-02 discipline).
- **Cached-fuzz replay** (09-01/09-02) — when killing a loop mutant, clear `cache/fuzz` or the kill may replay a prior counterexample; keep a **non-fuzz unit anchor** beside every fuzz (cache-independent by construction).
- **Checked-vs-wrapping** (14-02, `0x11` panic) — `orderCount + 1` and any id arithmetic MUST use Plank checked `+`, never `@evm_add`; a wrapping mutant (`+` → `@evm_add`) at the count/id must die. Note the interaction with Pitfall 1: the checked add is itself a store-path revert site validation must account for (unreachable at 2^256 in practice, but it is in the revert set).
- **`@evm_not` bitwise trap** (VegaAccountMod deposit(0) guard) — any "is this tuple invalid" / "is width zero" guard must use `@evm_iszero`, never the bitwise-NOT builtin (`NOT(0)` and `NOT(1)` both truthy → the guard can never fire). Mutant `@evm_iszero` → `@evm_not` on the zero-width guard must die.
- **Dead-module green compile** (v2.0 core lesson) — the multicall entrypoint and its loop body must be **CALLED green through FFI**; `make compile-plank` passing proves nothing (Plank doesn't type-check code unreachable from `run{}`). Every claim = a CALLED test or an OBSERVED-red mutation kill. `PLANK_SKIP` leaves only when dispatch is CALLED green.
- **Sign-extension / quotient-cancellation** — fields are **unsigned** (`u88`/`u24`/`u16`); reading a 32-byte word and narrowing must mask/`shr`, never `sdiv` (no sign-extension). Quotient-cancellation is **N/A for the registry** (no division in store logic) — it applies only to the deferred pos_spec pricing, which is explicitly out of scope.

**Warning signs:** `vm.assume` anywhere in the batch corpus; a mutant kill with `runs: 0` and no unit anchor (possible replay); `@evm_add`/`@evm_not` in the loop; a "compiles" claim used as evidence.

**Phase to address:** every test-producing phase inherits these as gates; the mutation battery / PLANK_SKIP-exit phase owns the falsifiability proof.

---

## N/A pitfalls (stated with reasoning)

- **Reentrancy via external calls — N/A for the specified design.** This multicall dispatches **only the internal `create_order`**; it takes no user-supplied target address or arbitrary calldata. `create_order` writes only its own keccak slots + `orderCount`, transfers no value, and invokes no callback. There is no attacker-controlled re-entry surface. **Becomes real ONLY if** the implementation switches to call-boundary containment via a generic `aggregate(address,bytes)` (Multicall3-style) — which would open delegatecall/selfdestruct/arbitrary-call risk for zero benefit here. **Anti-feature: do not build a generic aggregator; the multicall dispatches a fixed internal opcode path.** If the self-`CALL` containment variant is chosen, the callee is the module's own trusted code at its own address, so reentrancy is still N/A, but assert the success-flag is read (Pitfall 1 note).
- **Value/custody/redemption bugs — N/A.** The registry holds no funds and mints nothing transferable (same posture as the v3.0 vault's `setRiskPrice` being deliberately unauthenticated). No approval/transfer race exists.
- **Oracle/price manipulation — N/A.** Registry only: "no tick/price computation" (`PROJECT.md`); pos_spec pricing (4 red harness tests) stays out.

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Inline validation instead of call-boundary containment | Cheaper gas, simpler, no reentrancy surface | Requires **provable** validation completeness (Pitfall 1); a future added store-path revert silently re-breaks best-effort | Acceptable *iff* the totality fuzz + completeness differential are in the suite as a permanent regression gate |
| Trust zero-width as the truncation defence | One fewer check | Misses truncation that spares the width field (Pitfall 3); phantom orders | **Never** — calldatasize check is mandatory; zero-width is a backstop only |
| Skip `MAX_BATCH`, rely on "best-effort" | Less code | OOG eats valid orders, un-skippable, griefing vector (Pitfall 4) | **Never** — `MAX_BATCH` is load-bearing |
| Getter-based partial-state assertions | Reuses readers | Misses slot aliasing / stray writes (Pitfall 2, 14-02) | Only as a *supplement* to raw `vm.load` |
| Reuse the Plank output in the Solidity mock | Fast to write | Vacuous differential (08-02) | **Never** — mock must be independently simple + one hand-computed anchor |

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| Haskell `StochasticOrderGen` (rpc_api) | Changing a field type / return shape without re-deriving the selector → silent consumer break | `cast sig` guard on `0x6501fe94` + multicall selector + `Result` ABI, plus a captured golden calldata/return fixture from PR #9 |
| Plank dynamic-array ABI (new ground) | Hand-rolled head/tail offsets, wrong `length`, `N=0` empty-array | Differential vs Solidity mock, `abi.decode` round-trip, corpus incl. `N∈{0,1,MAX}` |
| FFI deploy path | Believing `make compile-plank` = tested | CALLED-green only; FFI recompiles `.plk` every `deployPlank` |

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Unbounded batch loop | Tx OOG-reverts, valid orders lost, gas wasted | `MAX_BATCH` + gas-measured `N=MAX_BATCH` test | At the N where `N * per_order_gas` ≥ block gas limit |
| Self-`CALL` per order (if containment variant) | Deep batches starve on 1/64 retained gas | Size `MAX_BATCH` against the 63/64 rule, or prefer inline | Deep batches near gas ceiling |

## Security Mistakes

| Mistake | Risk | Prevention |
|---------|------|------------|
| Generic `aggregate(address,bytes)` multicall | delegatecall/selfdestruct/arbitrary-call, reentrancy | Dispatch only internal `create_order`; no user target/calldata (anti-feature) |
| Unmasked/unvalidated dirty high bits on `u88/u24/u16` fields | Corrupted packing or silent truncation → stored order ≠ requested (Solidity decoder would revert; Plank won't) | Validate `field < 2^width`, reject dirty bits (couples Pitfall 1 + 3); differential vs Solidity mock exposes it |
| No calldatasize guard | Phantom fabricated orders from zero-padded reads | Mandatory `calldatasize >= HEADER + N*STRIDE`, revert on short batch |

## "Looks Done But Isn't" Checklist

- [ ] **Best-effort multicall:** compiles and skips *known-bad-bounds* tuples — but is validation **complete** w.r.t. the `VolOrder` constructor + checked-add revert set? Verify the totality fuzz + completeness differential exist and a validation-deletion mutant reddens with a *batch revert*.
- [ ] **Skipped call:** returns a fail flag — but does it leave **zero** footprint? Verify via raw `vm.load` on the would-be slot AND `orderCount`, not getters.
- [ ] **Dynamic `results[]`:** decodes for the happy path — but does `N=0` and mixed-success decode round-trip against the Solidity mock at tolerance 0?
- [ ] **`MAX_BATCH`:** exists — but is `N=MAX_BATCH+1` an *early* revert (before any `sstore`) and is `N=MAX_BATCH` gas-measured under the block limit?
- [ ] **Selector:** `create_order` works — but is `0x6501fe94` cast-sig-asserted AND a captured consumer fixture decoded?
- [ ] **Truncated calldata:** happy-path batch works — but does a `count=N`/`bytes=N-1` payload REVERT (not silently skip a phantom)?
- [ ] **PLANK_SKIP:** module removed from skip only when the multicall entrypoint is CALLED green (not merely compiling).

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Incomplete validation found post-ship (batch reverts in the wild) | HIGH | Enumerate `VolOrder` constructor + checked-op revert set; mirror each as a validation branch OR switch to call-boundary containment; add totality fuzz as permanent gate |
| Selector drift already shipped to consumer | MEDIUM | Restore the pinned signature or coordinate a versioned selector with the peer; add the cast-sig gate to prevent recurrence |
| Phantom orders from missing calldatasize check | MEDIUM | Add the calldatasize revert; audit stored orders for zero-padded artifacts; the id-density invariant (Pitfall 6) helps locate them |
| Partial state from write-before-validate | MEDIUM | Reorder to validate-before-write; migrate/scrub any stray slots; add the raw-`vm.load` footprint battery |

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| 1. Validation completeness / containment leak | Multicall best-effort phase (acceptance property) | Totality fuzz green over full-width domain; multicall-fail ⟺ standalone-revert; validation-deletion mutant reddens with batch revert |
| 2. Partial state on skip | create_order store phase + multicall phase | Raw `vm.load` footprint battery; write-before-validate mutant dies |
| 3. Calldata-length lies | Multicall calldata-decode phase | `count=N`/`bytes<N` reverts; zero-width backstop; skew-only-truncation corpus |
| 4. Unbounded N / OOG | Multicall phase (`MAX_BATCH` requirement) | `N∈{0,1,MAX,MAX+1}` corpus; gas-measured MAX; MAX+1 early revert |
| 5. Return-encoding off-by-one | Return-encoding phase | Differential vs Solidity mock, `abi.decode` round-trip, `N=0` edge |
| 6. Id-sequence under mixed outcomes | store + multicall phases | Dense-ids/count==successes assertions; count-on-failure & pre-validation-id mutants die; cross-batch stateful invariant |
| 7. Selector/ABI drift | Interface/consumer-contract phase (early) | cast-sig on `0x6501fe94` + return ABI; captured consumer fixture decodes |
| 8. Repo-catalogued loop modes | Every test phase; mutation-battery/PLANK_SKIP-exit phase | Constructed (not `vm.assume`) corpus; cache cleared + unit anchor; `@evm_add`/`@evm_not`/wrapping mutants die; CALLED-green |

## Sources

- `.planning/STATE.md` Accumulated Context — catalogued kills: dead-module green compile (v2.0), checked-vs-wrapping `0x11` panic (14-02), `@evm_not` bitwise trap (VegaAccountMod), `vm.assume`/constructed-corpus (VDIFF-05/06), cached-fuzz replay + unit anchor (09-01/09-02), slot-aliasing invisible to readers (14-02), vacuous-mock/anchor discipline (08-02), FFI-recompiles-so-CALLED-green (v2.0). HIGH confidence.
- `src/modules/exposure/VegaAccountMod.plk` — the guard/battery precedent (`@evm_iszero` deliberate, checked `+`, keccak scalar slots, lib-routed math, terminal `revert_empty`). HIGH confidence.
- `.planning/PROJECT.md` v4.0 milestone — `create_order(uint88,uint24,uint16)` `0x6501fe94`, best-effort per-call semantics, dynamic-array-ABI-in-Plank as the stated main technical risk, peer consumer contract. HIGH confidence.
- EVM semantics — `calldataload` past `calldatasize` returns zero-padded words; OOG unwinds the whole tx; revert unwinds one call frame; 63/64 gas rule. HIGH confidence (standard).
- **Gap (MEDIUM/LOW):** Plank v0.1.1 loop/recursion constructs are unverified. Whether the multicall is a bounded loop, unrolled to `MAX_BATCH`, or recursive changes the off-by-one and OOG profile. Resolve by reading the plank compiler / an existing loop `.plk` before the multicall phase. Also unconfirmed at research time: the peer's per-call return shape (`PROJECT.md` open semantics message).

---
*Pitfalls research for: Plank/EVM best-effort batched vol-order registry (`VolOrderManagerMod` + multicall)*
*Researched: 2026-07-19*
