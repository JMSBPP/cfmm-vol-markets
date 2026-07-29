---
phase: 18a-batch-input-state-effects
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - src/modules/pos_spec/VolOrderManagerMod.plk
  - test/pos_spec/VolOrderManagerBatch.t.sol
  - test/pos_spec/VolOrderManager.t.sol
  - Makefile
autonomous: true
requirements: [MCAL-01, MCAL-02, MCAL-03, MCAL-04, MCAL-06]

must_haves:
  truths:
    - "A mixed batch [valid_A, INVALID, valid_B] called through FFI-deployed bytecode stores exactly two orders at CONTIGUOUS ids C+1 and C+2, advances orderCount to C+2, and leaves slot C+3 zero (SC-1, MCAL-03)."
    - "Each of the three calldata guards REVERTS the whole tx independently, each with its own corpus: non-canonical offset, length!=count, truncated calldata (SC-2, MCAL-02)."
    - "count > MAX_BATCH (128) reverts with orderCount unchanged; N=128 total gas is MEASURED and <= 10,000,000 (SC-3, MCAL-01)."
    - "The post-validation store path is enumerated step-by-step with its revert status in the module, and a constructed fuzz records no batch-revert OBSERVED (SC-4, MCAL-04)."
    - "Batch-of-1 produces state and id byte-identical to a standalone create_order; N=0 completes without reverting and leaves every observable slot byte-identical (SC-5, MCAL-06)."
    - "Seven mutants each produce an OBSERVED RED naming a specific failing assertion; each restored sha256-identical and green (SC-6)."
  artifacts:
    - path: "src/modules/pos_spec/VolOrderManagerMod.plk"
      provides: "SELECTOR_CREATE_ORDERS dispatch branch: four guards, bounded runtime while, validate-then-skip, single trailing orderCount store, return_u256(ok)"
      contains: "SELECTOR_CREATE_ORDERS"
    - path: "test/pos_spec/VolOrderManagerBatch.t.sol"
      provides: "The batch surface: hand-rolled malformed-calldata builders + raw .call assertions"
      min_lines: 250
    - path: "Makefile"
      provides: "test-vol-order-batch focused target"
      contains: "test-vol-order-batch"
  key_links:
    - from: "src/modules/pos_spec/VolOrderManagerMod.plk"
      to: "lib::pos_spec::VolOrderValidationLib::validate_order"
      via: "the BOOL CORE imported and called inside the loop (never validate_order_strict)"
      pattern: "if validate_order\\(order\\)"
    - from: "src/modules/pos_spec/VolOrderManagerMod.plk"
      to: "pos_spec::VolOrder::pack_vol_order"
      via: "@evm_sstore(array_slot(SLOT_ORDERS_BASE, id), pack_vol_order(order))"
      pattern: "pack_vol_order\\(order\\)"
    - from: "test/pos_spec/VolOrderManagerBatch.t.sol"
      to: "address(mgr).call(malformedBytes)"
      via: "low-level .call — the typed interface cannot express a malformed encoding"
      pattern: "address\\(mgr\\)\\.call\\("
---

<objective>
Add the `create_orders(uint256,uint256[])` dispatch branch to `VolOrderManagerMod.plk` — standard-ABI decode behind FOUR guards, a bounded runtime `while`, per-tuple validate-then-skip with contiguous ids, and a ONE-WORD return (the success count).

Purpose: prove the batch's STATE EFFECTS without trusting any encoder. The `(bool,uint256)[]` encoder is Phase 18b and has no in-repo precedent; returning a single word means every 18a claim is asserted against raw `vm.load` slots and a scalar the test computes itself.

Output: a CALLED-green batch entrypoint, a new batch test surface, a measured N=128 gas number, and seven observed mutation REDs.
</objective>

<execution_context>
@/home/jmsbpp/.claude/get-shit-done/workflows/execute-plan.md
@/home/jmsbpp/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/phases/18a-batch-input-state-effects/18a-CONTEXT.md
@.planning/ROADMAP.md
@.planning/REQUIREMENTS.md
@.planning/STATE.md

@src/modules/pos_spec/VolOrderManagerMod.plk
@src/lib/pos_spec/VolOrderValidationLib.plk
@src/types/pos_spec/VolOrder.plk
@src/interfaces/pos_spec/VolOrderManagerInterface.plk
@test/pos_spec/VolOrderManager.t.sol

<pinned_facts>
<!-- Everything below is VERIFIED. Do not re-derive, do not re-research, do not copy offsets
     from any other file. These are the contracts the executor writes against. -->

## CALLDATA LAYOUT — verified by executing `cast calldata "create_orders(uint256,uint256[])"`

    byte   0   selector            0x81357911
    byte   4   count               N
    byte  36   array offset        0x40      <- GUARD 1 reads HERE
    byte  68   array length        N         <- GUARD 2 reads HERE
    byte 100 + 32*i   element i
    calldatasize == 100 + 32*N               (N=0/1/2 -> 100/132/164 bytes, confirmed)

### ⚠ THE TRANSCRIPTION TRAP — the single most likely bug in this phase
`merkle_airdrop.plk:45` reads its array offset at byte **68** because its signature
`(address,uint256,bytes32[])` has a **THREE-word head**. OURS IS TWO WORDS: our offset word is
at byte **36**, and byte 68 is our LENGTH word. The two constants appear in both files with
SWAPPED meanings. Copying `68` into guard 1 produces `require(@evm_calldataload(68) == 0x40)`,
which spuriously passes only when `count == 64` — a bug that survives most test corpora.
Read `merkle_airdrop.plk` lines ~52-64 for the `while` + computed-`@evm_calldataload` IDIOM ONLY,
and read it as PARTIAL: it has NO calldatasize guard and NO offset check, which is precisely the
gap MCAL-02 exists to close. Do not let its structure become this design.

## INPUT WORD BIT LAYOUT (pinned decision of record, REQUIREMENTS.md:107)

    bits   0..15    skew    (u16)
    bits  16..103   strike  (u88)
    bits 104..127   width   (u24)
    bits 128..255   MUST BE ZERO   -> dirty-high-bit rejection
    packed_input = skew | (strike << 16) | (width << 104)

Bits 0..103 are IDENTICAL to the STORED word, so Phase 16's tested masks/shifts apply unchanged.
Only `width` moves: 104 in the input, 128 in storage, because the module inserts
`TICK_SPACING = 20` at bits 104..127 en route to `pack_vol_order`.

STORED word (`pack_vol_order`, VolOrder.plk:35-40, unchanged):
    width@128 | tickSpacing@104 | strike@16 | skew@0

## HOW DIRTY-HIGH-BIT REJECTION IS ACHIEVED — read this before writing the extraction

`skew` and `strike` MUST be masked (a field sits above each of them).
`width` MUST NOT be masked — it is the TOP field, so leaving `@evm_shr(104, word)` unmasked makes
any bit >= 128 inflate `width` past `0xffffff`, where `vol_range_width_is_complete` REJECTS it.
Dirty high bits therefore become a per-tuple SKIP, requiring zero new arithmetic, and reusing
Phase 17's stated philosophy verbatim (`VolOrderManagerInterface.plk:6-10`: the module reads whole
words with no masking; dirty bits are rejected by VALIDATION, not truncated).
Masking width to `& 0xFFFFFF` here would silently accept two distinct calldata words as the same
order — a malleability seam for the Haskell peer's fixture and the Phase 19 differential.

## THE FOUR GUARDS — ordering is load-bearing

NAMING, used consistently in test messages and in the Task 4 mutant table: the MAX_BATCH bound is
NOT one of MCAL-02's three calldata guards, so it is named separately. "guard 1 / 2 / 3" ALWAYS
means offset / length / calldatasize.

    (MAX_BATCH)  require(count <= MAX_BATCH)                      CHECKED FIRST
    (guard 1)    require(@evm_calldataload(36) == 0x40)           canonical array offset
    (guard 2)    require(@evm_calldataload(68) == count)          length agrees with count
    (guard 3)    require(@evm_calldatasize() >= 100 + 32 * count) calldata is actually present

MAX_BATCH goes FIRST because Plank's `*` and `+` are CHECKED: with an adversarial `count` near
2^256, `32 * count` PANICS (0x11) before guard 3's comparison is ever evaluated. The tx still
reverts, so it is not a hole — but it reverts with panic data instead of the intended empty
revert, which muddies the MCAL-02 mutation evidence. With `count <= 128`, `32 * count <= 4096`
and overflow is structurally impossible.

All four REVERT the whole tx. Structural malformation is never a per-call skip.

## API CONTRACTS (call these; never reimplement, never modify src/types/pos_spec/*)

    build_vol_order(strike: u256, width: u256, skew: u256) -> VolOrder
        src/lib/pos_spec/VolOrderValidationLib.plk:51. Argument order is (strike, width, skew).
        Pins TICK_SPACING = 20. Cannot revert (three nested plain struct literals).

    validate_order(self: VolOrder) -> bool
        src/lib/pos_spec/VolOrderValidationLib.plk:67. THE BOOL CORE. Cannot revert.
        Accept sets (16-01 MEASURED): strike [1, 2^88-1], width [1, 0xffffff], skew [1, 65534].
        NOT validate_order_strict — that reverting wrapper is the SINGLE-CALL path's. Calling it
        here would destroy best-effort semantics.

    pack_vol_order(self: VolOrder) -> u256
        src/types/pos_spec/VolOrder.plk:35. Pure @evm_shl/&/| — CANNOT revert.

    array_slot(base_slot: u256, index: u256) -> u256
        lib/plankified-univ3/plank/lib/storage.plk:230. keccak256(base) + index, NO mask.
        Its `+` is CHECKED (17-01 MEASURED) — documented-unreachable for counter-assigned ids.

    return_u256(value: u256) -> never
        lib/plankified-univ3/plank/lib/util.plk:23. Already imported at VolOrderManagerMod.plk:28.
        Returns `never`, so it terminates the branch — no fallthrough to revert_empty().

    require(cond: bool) -> void        std::error::require. Empty revert data.
    @evm_calldatasize()                zero args, empty parens, returns u256.
                                       Form confirmed at plank-diff-tests/src/std/abi_dynamic.plk:7.
    @evm_shr(shift, value)             shift-amount FIRST (VolOrderManagerMod.plk:46).

## BASELINES (do not chase pre-existing reds)

    make compile-plank   ->  13 ok / 0 failed / 0 skipped. This plan adds NO new entrypoint,
                             so it must STAY 13. A 14 means a stray .plk was created.
    make test            ->  99 pass / 4 pre-existing pos_spec fails, PLUS the new batch tests.
                             A FIFTH failure, TickVolatilityLibTest
                             ::test__fuzz__tickVolatilitySqrtPriceX64x96AndTickSuccess, is a
                             KNOWN pre-existing flake firing ~1 cold run in 4 at counterexample
                             2^64-1, owned by another track. Re-run; do NOT chase it.

    EVERY forge invocation carries, without exception:
        --via-ir --optimize --skip 'src/modules/protocol_integrations/PriceSetterHook.sol'
</pinned_facts>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Add the create_orders dispatch branch to VolOrderManagerMod.plk</name>
  <files>src/modules/pos_spec/VolOrderManagerMod.plk</files>

  <read_first>
    - src/modules/pos_spec/VolOrderManagerMod.plk  (the file you modify; read ALL 85 lines — you are adding a branch, not rewriting)
    - src/lib/pos_spec/VolOrderValidationLib.plk   (build_vol_order:51, validate_order:67 — the bool core)
    - src/types/pos_spec/VolOrder.plk              (pack_vol_order:35 — CALL it, NEVER modify this file)
    - src/interfaces/pos_spec/VolOrderManagerInterface.plk (SELECTOR_CREATE_ORDERS already pinned at :20)
    - lib/plank-monorepo/plankc/plank-diff-tests/src/examples/merkle_airdrop.plk lines 52-64 ONLY
      (the `while` + computed-offset idiom. Its byte-68 offset read is the TRANSCRIPTION TRAP —
       see <pinned_facts>. Take the loop SHAPE, take NO constants.)
    - lib/plank-monorepo/plankc/plank-diff-tests/src/std/abi_dynamic.plk:7 (@evm_calldatasize() form)
  </read_first>

  <action>
Modify ONLY `src/modules/pos_spec/VolOrderManagerMod.plk`. Do not touch any file under
`src/types/pos_spec/`. Do not create any new `.plk` file.

**1. Extend the imports.** Two changes to the existing import block:
  - line 25 becomes:
    `import lib::pos_spec::VolOrderValidationLib::{build_vol_order, validate_order_strict, validate_order};`
  - add: `import std::error::require;`
    (path verified at VolOrderValidationLib.plk:23; `require` reverts EMPTY, matching
     validate_order_strict's revert shape so both paths are indistinguishable to a caller)

**2. Add the MAX_BATCH constant** next to the two slot constants:

```plank
// MAX_BATCH (MCAL-01). Plank enforces NO loop bound and NO gas guard -- the `while` lowerer has
// no loop_bound / max_iter / unroll machinery -- so this constant is LOAD-BEARING, not hygiene:
// it is the only thing standing between a caller-supplied count and an unbounded loop. 128 is the
// decision of record; the hard admissibility ceiling is 512, and a peer value above it is CAPPED
// and reported, never silently adopted. Pinned behaviourally by
// test__unit__maxBatchExactlyOneTwoEightSucceeds and test__unit__overMaxBatchRevertsNoStateChange.
const MAX_BATCH = 128;
```

**3. Add the dispatch branch.** Insert it as a new `else if` AFTER the
`SELECTOR_GET_ORDER_PACKED` branch (line 77-80) and BEFORE the closing `}` of the if-chain, so the
trailing `revert_empty()` still catches unknown selectors. Write it EXACTLY as follows — every
offset below is derived from OUR two-word head, never from merkle_airdrop:

```plank
    } else if selector == SELECTOR_CREATE_ORDERS {
        // create_orders(uint256 count, uint256[] packedOrders) -- THE BATCH (MCAL-01/02/03/04/06).
        //
        // CALLDATA LAYOUT, verified by executing `cast calldata "create_orders(uint256,uint256[])"`
        // (N=0/1/2 produce exactly 100/132/164 bytes):
        //
        //     byte   0   selector 0x81357911
        //     byte   4   count
        //     byte  36   array offset   (canonical 0x40)
        //     byte  68   array length
        //     byte 100 + 32*i   element i
        //     calldatasize == 100 + 32*count
        //
        // DO NOT TRANSCRIBE OFFSETS FROM merkle_airdrop.plk:45. Its signature has a THREE-word
        // head so its offset word sits at 68; ours has TWO words so ours sits at 36 and 68 is our
        // LENGTH word. The two constants appear in both files with swapped meanings. Reading the
        // offset at 68 here would spuriously pass only when count == 64.
        let count = @evm_calldataload(4);

        // FOUR GUARDS. Every one REVERTS the whole tx: a structurally malformed payload is not a
        // per-call skip. ORDER IS LOAD-BEARING -- MAX_BATCH is checked FIRST because Plank's `*`
        // and `+` are CHECKED, so with an adversarial count near 2^256 the `32 * count` below
        // would PANIC (0x11) before the size comparison was ever evaluated. Under count <= 128,
        // 32 * count <= 4096 and overflow is structurally impossible.
        require(count <= MAX_BATCH);
        require(@evm_calldataload(36) == 0x40);
        require(@evm_calldataload(68) == count);
        require(@evm_calldatasize() >= 100 + 32 * count);

        // WHY ELEMENTS ARE READ AT A FIXED 100 + 32*i RATHER THAN FROM THE OFFSET WORD: this is
        // sound ONLY because the second guard pins the offset to its canonical 0x40. Delete that
        // guard and a caller whose encoder places the array elsewhere has our loop read a fixed
        // region of zero-padded space instead of their tuples -- the PHANTOM-ORDER attack. That is
        // exactly why a non-canonical offset REVERTS instead of being followed.
        //
        // INPUT WORD:  skew@0..15 | strike@16..103 | width@104..127 | bits >=128 MUST BE ZERO.
        // Bits 0..103 are identical to the stored word, so Phase 16's masks apply unchanged; only
        // width moves (104 here, 128 in storage) because build_vol_order inserts TICK_SPACING = 20
        // at 104..127 on the way to pack_vol_order.
        //
        // width IS DELIBERATELY UNMASKED. It is the TOP field, so any bit >= 128 inflates it past
        // 0xffffff, where vol_range_width_is_complete rejects it -- that IS the dirty-high-bit
        // rejection, achieved with zero new arithmetic and matching the module's existing stance
        // (VolOrderManagerInterface.plk:6-10: whole-word reads, dirty bits rejected by validation).
        // Masking it to `& 0xFFFFFF` would map two distinct calldata words onto the same stored
        // order -- a malleability seam for the Haskell consumer and the Phase 19 differential.
        // skew and strike DO get masks because a field sits above each of them.
        let mut i = 0;
        let mut id = @evm_sload(SLOT_ORDER_COUNT);
        let mut ok = 0;
        while i < count {
            let word = @evm_calldataload(100 + i * 32);
            let order = build_vol_order(
                @evm_shr(16, word) & 0xFFFFFFFFFFFFFFFFFFFFFF,
                @evm_shr(104, word),
                word & 0xFFFF
            );

            // BEST-EFFORT = VALIDATE BEFORE WRITE (MCAL-03). A single Plank frame has no per-tuple
            // rollback, so an invalid tuple is skipped by never being written. This calls the BOOL
            // CORE; the single-call path above calls validate_order_strict. Both descend from the
            // same function, which is what makes MCAL-04's "strict and batch agree" true by
            // construction rather than tested into existence.
            //
            // Plank has NO `continue`, so the skip MUST be this `if` WRAPPING the store, never an
            // early jump -- a jump past the increment below is an infinite loop, i.e. out-of-gas
            // rather than a failed assertion.
            if validate_order(order) {
                id = id + 1;
                @evm_sstore(array_slot(SLOT_ORDERS_BASE, id), pack_vol_order(order));
                ok = ok + 1;
            }
            i = i + 1;
        }

        // ONCE, after the loop. The intermediate counter value is unobservable within one tx, and
        // hoisting the advance INTO the failure path is mutant M5: a skipped tuple would consume
        // an id, gapping the sequence so a later valid order lands at the wrong slot. That mutant
        // was EQUIVALENCE-MASKED in Phase 17 (the strict path's revert rolled the store back) and
        // is a REAL kill here.
        @evm_sstore(SLOT_ORDER_COUNT, id);

        // ONE WORD: the success count. Deliberate -- the typed (bool,uint256)[] encoder is Phase
        // 18b and has zero in-repo precedent, so 18a's state effects are proven against raw
        // vm.load slots and a scalar the test computes itself, with no untested encoder in
        // between. return_u256 returns `never`, terminating the branch.
        return_u256(ok);
```

**4. Update the module's header comment** (lines 13-15) — it currently says Phase 18a's batch
"will call" the bool core. Change to past/present tense stating that it DOES, and add the MCAL-04
structural enumeration below (see step 5).

**5. Add the MCAL-04 STRUCTURAL ENUMERATION** as a comment block immediately above the
`create_orders` branch. This is a REQUIRED ARTIFACT, not documentation — MCAL-04 makes the written
enumeration the PRIMARY containment argument and the fuzz mere corroboration. Every step must be
named with its revert status:

```plank
        // ---------------------------------------------------------------------------------
        // MCAL-04 CONTAINMENT -- STRUCTURAL ENUMERATION OF THE POST-VALIDATION STORE PATH.
        // The PRIMARY argument. The fuzz in VolOrderManagerBatch.t.sol is CORROBORATION
        // ("no batch-revert OBSERVED over N runs"), never "proven for all 2^256 values".
        //
        //  1. build_vol_order(strike, width, skew)      NO REVERT. Three nested plain struct
        //     literals (VolOrderValidationLib.plk:51-57). Plank struct literals have no smart
        //     constructors; the require-bearing functions on those types (type_check_vol_range_
        //     width, check_spread) are separate and are NOT invoked by literal construction.
        //  2. validate_order(order)                     NO REVERT. A conjunction of three pure
        //     predicates (VolOrderValidationLib.plk:67-70), each a chain of comparisons and `&`
        //     with no require, no division, no subtraction. Total on all of u256.
        //  3. id = id + 1                               CHECKED add, UNREACHABLE. id is bounded
        //     by orderCount_before + 128; overflow needs id ~ 2^256.
        //  4. pack_vol_order(order)                     NO REVERT. Pure @evm_shl / & / |
        //     (VolOrder.plk:35-40). No require, no smart constructor, no trapping arithmetic.
        //     THIS IS THE FACT THAT MAKES PRE-VALIDATION CONTAINMENT VIABLE AT ALL.
        //  5. array_slot(SLOT_ORDERS_BASE, id)          CHECKED add, DOCUMENTED-UNREACHABLE.
        //     keccak256(base) + index under Plank's checked `+` (17-01 MEASURED: it panics 0x11
        //     rather than wrapping). Panics only for id > 2^256-1 - keccak(base) ~ 6.5e74;
        //     counter-assigned ids advance by at most 128 per tx.
        //  6. @evm_sstore(slot, packed)                 NO REVERT. SSTORE cannot revert outside a
        //     staticcall context, and this branch is reached by a state-changing CALL.
        //     (Out-of-gas is orthogonal and bounded by MAX_BATCH; gas exhaustion is not a
        //     containment failure.)
        //
        // CONCLUSION: no step on the post-validation path can revert for any input that passed
        // validate_order. Containment holds STRUCTURALLY, not statistically.
        // ---------------------------------------------------------------------------------
```

**6. Copy the 88-bit mask literal, do not retype it.** `0xFFFFFFFFFFFFFFFFFFFFFF` is 22 hex
digits. Copy-paste it from `src/types/pos_spec/VolOrder.plk:38` and then PROVE the two are
byte-identical with the grep in acceptance_criteria. A retyped mask with 21 or 23 F's silently
truncates or admits strike values and would not revert.

**COMMENT CONSTRAINT (learned the hard way in Phases 16 and 17):** none of the comment text you
write may contain the literal substring `require(@evm_calldata`. Describe the guards in prose and
in the byte table above; never restate a guard line verbatim inside a comment. Acceptance greps
below count code lines and would double-count a commented copy, burning executor time on a false
failure.
  </action>

  <verify>
    <automated>make compile-plank 2>&1 | tail -3</automated>
  </verify>

  <acceptance_criteria>
    - `make compile-plank` final line reads exactly `compile-plank: 13 ok, 0 failed, 0 skipped`.
      This plan adds NO new entrypoint; 14 means a stray `.plk` was created and must be removed.
    - `grep -c 'require(@evm_calldata' src/modules/pos_spec/VolOrderManagerMod.plk` outputs `3`
      (guards 2, 3, 4 — exactly three CODE lines, zero comment copies).
    - `grep -n 'require(@evm_calldataload(36) == 0x40);' src/modules/pos_spec/VolOrderManagerMod.plk`
      returns exactly one line. `grep -c '@evm_calldataload(68) == 0x40' src/modules/pos_spec/VolOrderManagerMod.plk`
      outputs `0` — the transcription trap is absent.
    - `grep -c 'require(count <= MAX_BATCH);' src/modules/pos_spec/VolOrderManagerMod.plk` outputs `1`,
      and its line number is LOWER than every `require(@evm_calldata` line number (verify with
      `grep -n 'require(' src/modules/pos_spec/VolOrderManagerMod.plk`).
    - `grep -c 'if validate_order(order)' src/modules/pos_spec/VolOrderManagerMod.plk` outputs `1`
      and `grep -c 'validate_order_strict(order)' src/modules/pos_spec/VolOrderManagerMod.plk`
      outputs `1` (the single-call path only — the batch must NOT call the strict wrapper).
    - `grep -c '@evm_sstore(SLOT_ORDER_COUNT' src/modules/pos_spec/VolOrderManagerMod.plk` outputs
      `2` (one in create_order, one AFTER the batch loop). Zero occurrences inside the `while` body.
    - The 88-bit mask is byte-identical to the packer's:
      `test "$(grep -o '0xF\{22\}' src/modules/pos_spec/VolOrderManagerMod.plk | head -1)" = "$(grep -o '0xF\{22\}' src/types/pos_spec/VolOrder.plk | head -1)" && echo MASK_OK`
      prints `MASK_OK`, and `grep -c '0xF\{23\}' src/modules/pos_spec/VolOrderManagerMod.plk` outputs `0`.
    - `grep -c '@evm_shr(104, word) &' src/modules/pos_spec/VolOrderManagerMod.plk` outputs `0` —
      width is UNMASKED, which is what performs dirty-high-bit rejection.
    - The MCAL-04 enumeration is present with all six steps:
      `grep -c 'MCAL-04 CONTAINMENT' src/modules/pos_spec/VolOrderManagerMod.plk` outputs `1`, and
      `grep -c 'pack_vol_order(order)' src/modules/pos_spec/VolOrderManagerMod.plk` is >= 1.
    - `git diff --stat src/types/pos_spec/` is EMPTY — nothing under `src/types/pos_spec/` changed.
    - Record `sha256sum src/modules/pos_spec/VolOrderManagerMod.plk` in the summary; Task 4 restores
      to exactly this digest.
  </acceptance_criteria>

  <done>The module compiles at the 13-entrypoint baseline, the batch branch exists with four correctly-offset guards in the mandated order, the batch calls the BOOL core, the counter is stored once after the loop, and the MCAL-04 enumeration is written in-file.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: Author the batch test surface and update the Phase-17 boundary test</name>
  <files>test/pos_spec/VolOrderManagerBatch.t.sol, test/pos_spec/VolOrderManager.t.sol, Makefile</files>

  <read_first>
    - test/pos_spec/VolOrderManager.t.sol (ALL 369 lines — you reuse its `VolOrderManagerBase`
      abstract contract and you must UPDATE `test__unit__batchSelectorNotYetDispatched` at :303,
      which LOCKS the batch selector's fall-through and WILL go red the moment Task 1 lands.
      That red is EXPECTED and is not a regression.)
    - test/PlankTestBase.sol (deployPlank -> plankDeployFFI; the six module roots)
    - src/modules/pos_spec/VolOrderManagerMod.plk (as modified by Task 1 — the surface under test)
    - Makefile lines 144-160 (`test-vol-order-manager` is the target you mirror)
  </read_first>

  <behavior>
    - Mixed batch [valid_A, INVALID, valid_B] from orderCount = C: orderCount -> C+2; slot C+1 holds
      valid_A; slot C+2 holds valid_B (CONTIGUITY — the load-bearing assertion); slot C+3 == 0;
      the returned word == 2.
    - Non-canonical array offset (0x2000) -> whole tx REVERTS, orderCount unchanged.
    - Array length (1) != count (2) -> whole tx REVERTS, orderCount unchanged.
    - Calldata truncated 32 bytes short of 100 + 32*count -> whole tx REVERTS. Asserted as a REVERT,
      NOT as a state check (see the note in <action>).
    - count = 129 -> REVERTS, orderCount unchanged, slot C+1 == 0.
    - count = 128, all valid -> succeeds, orderCount == 128.
    - Batch-of-1 produces byte-identical state and id to a standalone create_order.
    - N = 0 -> succeeds, returns 0, every observable slot byte-identical.
    - A word with any bit >= 128 set is SKIPPED (not stored, not reverted).
    - Constructed mixed corpus of valid and invalid tuples -> the batch NEVER reverts and returns
      exactly the constructed valid count.
  </behavior>

  <action>
Create `test/pos_spec/VolOrderManagerBatch.t.sol`. Modify `test/pos_spec/VolOrderManager.t.sol`
(one test only). Add one Makefile target.

**WHY A NEW FILE (the discretion call, justified):** `VolOrderManager.t.sol` owns the SINGLE-CALL
surface and states the project's one-file-per-surface convention in its own header (lines 12-17).
The batch is a categorically distinct surface, and — decisively — it requires HAND-ROLLED
MALFORMED CALLDATA delivered by low-level `.call`, which a typed Solidity `interface` cannot
express at all. Keeping those builders out of the single-call file keeps `--match-path` targets
disjoint so a batch red can never be confused for a single-call red. Reuse, do not duplicate:
`import {VolOrderManagerBase} from "./VolOrderManager.t.sol";` inherits the slot preimages,
`orderSlot()`, `expectedPacked()` and the STRIKE/WIDTH/SKEW anchor tuple.

**A. Shared scaffold** — an `abstract contract VolOrderManagerBatchBase is VolOrderManagerBase`:

```solidity
bytes4 internal constant SEL_CREATE_ORDERS = bytes4(0x81357911);
uint256 internal constant MAX_BATCH = 128; // restated from the module; pinned behaviourally below

/// @dev The INPUT word layout: skew@0..15 | strike@16..103 | width@104..127; bits >=128 zero.
///      DISTINCT from expectedPacked() (the STORED layout, width@128 | tickSpacing@104 | ...).
///      Only `width` moves between them, because build_vol_order inserts TICK_SPACING = 20.
function packInput(uint256 strike, uint256 width, uint256 skew) internal pure returns (uint256) {
    return skew | (strike << 16) | (width << 104);
}

/// @dev The CANONICAL encoding. Solidity emits offset 0x40 at byte 36 and length at byte 68,
///      which is exactly the layout the module guards. Verified against `cast calldata`.
function encodeBatch(uint256[] memory words) internal pure returns (bytes memory) {
    return abi.encodeWithSelector(SEL_CREATE_ORDERS, words.length, words);
}

/// @dev Hand-rolled head so `offset` and `length` can be set INDEPENDENTLY of the real array.
///      abi.encodeWithSelector cannot produce a malformed encoding -- that is the whole reason
///      these builders exist and the whole reason the guards need low-level .call to test.
function encodeBatchRaw(uint256 count, uint256 offset, uint256 length, uint256[] memory words)
    internal pure returns (bytes memory out)
{
    out = abi.encodePacked(SEL_CREATE_ORDERS, count, offset, length);
    for (uint256 j = 0; j < words.length; j++) out = abi.encodePacked(out, words[j]);
}

function truncate(bytes memory b, uint256 dropBytes) internal pure returns (bytes memory out) {
    out = new bytes(b.length - dropBytes);
    for (uint256 j = 0; j < out.length; j++) out[j] = b[j];
}

function callBatch(bytes memory cd) internal returns (bool ok, uint256 ret) {
    bytes memory r;
    (ok, r) = address(mgr).call(cd);
    if (ok && r.length == 32) ret = abi.decode(r, (uint256));
}
```

Sanity-pin the builders themselves so a builder bug cannot be mistaken for a module bug — add
`test__unit__canonicalEncodingMatchesTheVerifiedLayout`: for N = 0, 1, 2 assert
`encodeBatch(words).length == 100 + 32 * N` and, for N = 2, assert via inline assembly / byte
slicing that word-at-36 == 0x40 and word-at-68 == 2.

**B. `VolOrderManagerBatchStateTest` (MCAL-03, MCAL-01, SC-1) — THE FLAGSHIP.**

`test__unit__mixedBatchFootprintAndContiguity`: seed `orderCount` to a nonzero C with
`vm.store(address(mgr), SLOT_ORDER_COUNT, bytes32(uint256(5)))` so a "starts at 1" bug cannot hide.
Build `[packInput(STRIKE, WIDTH, SKEW), packInput(STRIKE, WIDTH, 65535), packInput(999, 7, 3)]`
— the INVALID tuple is strictly in the MIDDLE (skew 65535 is one of the only two rejected skews;
strike and width are comfortably valid, so exactly ONE conjunct fails and the failure is named).
Assert, with these exact message strings:
  - `assertTrue(ok, "a mixed batch never reverts")`
  - `assertEq(ret, 2, "returns the success count")`
  - `assertEq(mgr.orderCount(), 7, "orderCount advances by the success count, not by N")`
  - `assertEq(uint256(vm.load(address(mgr), orderSlot(6))), expectedPacked(STRIKE, WIDTH, SKEW), "valid_A at C+1")`
  - `assertEq(uint256(vm.load(address(mgr), orderSlot(7))), expectedPacked(999, 7, 3), "id contiguity: third valid order at C+2")`
    **<- THE LOAD-BEARING ASSERTION.** Under the M5 counter-hoist mutant valid_B lands at C+3 and
    C+2 stays zero. A count-only assertion does NOT discriminate; this one does.
  - `assertEq(uint256(vm.load(address(mgr), orderSlot(8))), 0, "no order beyond orderCount")`

`test__unit__dirtyHighBitsAreSkippedNotStored`: `packInput(STRIKE, WIDTH, SKEW) | (1 << 200)`
alone in a batch. Assert `ok` is true, `ret == 0`, `orderCount()` unchanged, `orderSlot(1) == 0`.
(Dirty high bits inflate the unmasked `width` past 0xffffff, so validation rejects — a SKIP, not a
revert, matching the module's whole-word-read stance.)

**C. `VolOrderManagerBatchGuardTest` (MCAL-02, MCAL-01, SC-2, SC-3).** Every test here uses raw
`.call`. Guards 1, 2 and 4 additionally assert ON STATE.

  - `test__unit__nonCanonicalOffsetReverts`: `encodeBatchRaw(1, 0x2000, 1, [validWord])` — a
    hostile offset pointing far past the array, which is the PHANTOM-ORDER attack the guard exists
    to stop, not merely a wrong value. Assert `assertFalse(ok, "guard 1: non-canonical offset must revert the whole tx")`,
    `assertEq(mgr.orderCount(), 0, ...)`, `assertEq(uint256(vm.load(address(mgr), orderSlot(1))), 0, ...)`.
  - `test__unit__lengthCountMismatchReverts`: `encodeBatchRaw(2, 0x40, 1, [w0, w1])` — count 2,
    length 1, total 164 bytes so guard 4 is satisfied and guard 3 is ISOLATED. Assert
    `assertFalse(ok, "guard 2: array length must agree with count")` plus the two state assertions.
  - `test__unit__truncatedCalldataReverts` **(READ THIS BEFORE WRITING IT):** build the canonical
    N=1 encoding (132 bytes) and `truncate(cd, 32)` to 100 bytes. **THIS MUTANT IS INVISIBLE TO
    STATE ASSERTIONS.** Deleting guard 4 does NOT corrupt state: `@evm_calldataload` past the end
    returns zero-padded words, `build_vol_order(0,0,0)` fails validation, the tuple is SKIPPED, and
    state stays clean — a state assertion would stay GREEN under the mutant and record a fake kill.
    The ONLY discriminating assertion is `assertFalse(ok, "guard 3: calldatasize must cover 100 + 32*count")`.
    Write a comment saying exactly this above the test. You may still assert orderCount for
    completeness, but the REVERT assertion is the kill site and must be named as such.
  - `test__unit__overMaxBatchRevertsNoStateChange`: 129 valid words, canonical encoding. Assert
    `assertFalse(ok, "count > MAX_BATCH must revert before any sstore")`, `orderCount() == 0`,
    `vm.load(orderSlot(1)) == 0`.
  - `test__unit__maxBatchExactlyOneTwoEightSucceeds`: exactly 128 distinct valid words. Assert
    `ok`, `ret == 128`, `orderCount() == 128`, and spot-check slots 1, 64 and 128 against
    `expectedPacked`. Together with the previous test this pins MAX_BATCH == 128 BEHAVIOURALLY,
    which is stronger than restating the constant.

**D. `VolOrderManagerBatchEquivalenceTest` (MCAL-06, SC-5).**

  - `test__unit__batchOfOneEqualsSingleCall`: deploy a SECOND independent instance
    (`IVolOrderManager other = IVolOrderManager(deployPlank("src/modules/pos_spec/VolOrderManagerMod.plk"))`),
    drive `other.create_order(STRIKE, WIDTH, SKEW)` and `mgr` with a batch of one
    `packInput(STRIKE, WIDTH, SKEW)`. Assert the two `vm.load(orderSlot(1))` words are equal AND
    both equal `expectedPacked(STRIKE, WIDTH, SKEW)` (equality alone would be satisfied by two
    zeros), and that both `orderCount()` values are 1.
  - `test__unit__emptyBatchIsNoOp`: `encodeBatch(new uint256[](0))` (exactly 100 bytes). Assert
    `assertTrue(ok, "N=0 is semantically empty, not structurally impossible -- it must not revert")`,
    `ret == 0`, `orderCount() == 0`, `vm.load(SLOT_ORDER_COUNT) == 0`, `vm.load(orderSlot(1)) == 0`.
    Add a comment recording the honest nuance: the module writes `orderCount` back unconditionally
    after the loop, so at N=0 it re-writes the identical prior value; observable state is therefore
    byte-identical, which is what SC-5's assertion tests. Also run the N=0 case from a SEEDED
    counter (`vm.store` C=5) and assert it still reads 5 — that is what proves the write-back is
    value-preserving rather than zeroing.

**E. `VolOrderManagerBatchTotalityTest` (MCAL-04, SC-4).**

`test__fuzz__batchNeverReverts` with `/// forge-config: default.fuzz.runs = 256`. Corpus is
CONSTRUCTED with `bound` — **no `vm.assume` anywhere**. Draw N in [1, 16]; for each position draw
a shape selector in [0, 5] and build:
  - shape 0: VALID — strike `bound(r,1,type(uint88).max)`, width `bound(r,1,type(uint24).max)`, skew `bound(r,1,65534)`
  - shape 1: skew = 0            (rejected endpoint)
  - shape 2: skew = 65535        (the other rejected endpoint)
  - shape 3: strike = 0          (strike_fits_packed lower bound)
  - shape 4: width = 0           (vol_range_width_is_complete lower bound)
  - shape 5: a valid word OR'd with `(1 << 200)`  (dirty high bits)
Count the shape-0 positions test-side as `expectedOk`. Assert
`assertTrue(ok, "MCAL-04: no batch-revert observed")` and `assertEq(ret, expectedOk, ...)` and
`assertEq(mgr.orderCount(), expectedOk, ...)`.
Named non-fuzz anchor: `test__unit__mixedBatchFootprintAndContiguity`. State in the docstring that
this is CORROBORATION recorded as "no batch-revert OBSERVED over 256 runs", never "proven for all
2^256 values" — the structural enumeration in the module is the primary argument.

**F. Update `test/pos_spec/VolOrderManager.t.sol`.** `test__unit__batchSelectorNotYetDispatched`
(:303) asserts the batch selector FALLS THROUGH and will now be red. Rewrite it in place as
`test__unit__batchSelectorIsNowDispatched`: same N=0 call, but `assertTrue(ok, "create_orders is dispatched as of Phase 18a")`
and `assertEq(mgr.orderCount(), 0, "an empty batch touches no state")`. Update the
`VolOrderManagerBoundaryTest` docstring to record that this test flipped when 18a landed, and that
the flip was EXPECTED (flagged in STATE.md at 17-01) rather than a regression. Change nothing else
in this file.

**G. Makefile.** Add, mirroring `test-vol-order-manager` (Makefile:144-158) including its `--skip`
comment, and append `test-vol-order-batch` to the `.PHONY` line at Makefile:160:

```make
# test-vol-order-batch: the create_orders BATCH surface (MCAL-01/02/03/04/06) -- the three calldata
# guards, MAX_BATCH, per-tuple validate-then-skip with contiguous ids, batch-of-1 equivalence and
# the N=0 no-op. Distinct from test-vol-order-manager, which owns the SINGLE-CALL surface: this file
# needs hand-rolled MALFORMED calldata over low-level .call, which a typed interface cannot express.
# --skip routes around the untracked PriceSetterHook.sol (another track's broken file).
test-vol-order-batch:
	forge test --match-path 'test/pos_spec/VolOrderManagerBatch.t.sol' --skip 'src/modules/protocol_integrations/PriceSetterHook.sol' --via-ir --optimize
```

No new `make test` wiring is needed — `make test` runs the whole suite with no `--match-path`, so
the new file folds in automatically. Record the new pass count in the summary.
  </action>

  <verify>
    <automated>make test-vol-order-batch 2>&1 | tail -20 && make test-vol-order-manager 2>&1 | tail -10</automated>
  </verify>

  <acceptance_criteria>
    - `make test-vol-order-batch` reports ZERO failures, and the passing-test count is >= 11.
    - `make test-vol-order-manager` reports zero failures — including the rewritten boundary test.
      `grep -c 'batchSelectorNotYetDispatched' test/pos_spec/VolOrderManager.t.sol` outputs `0`;
      `grep -c 'batchSelectorIsNowDispatched' test/pos_spec/VolOrderManager.t.sol` outputs `1`.
    - Every named test is CALLED-green (list them from
      `forge test --match-path 'test/pos_spec/VolOrderManagerBatch.t.sol' --skip 'src/modules/protocol_integrations/PriceSetterHook.sol' --via-ir --optimize -vv`
      and paste the roster into the summary). All ten behaviors in <behavior> must map to a named test.
    - `grep -c 'vm.assume' test/pos_spec/VolOrderManagerBatch.t.sol` outputs `0`.
    - `grep -c 'address(mgr).call(' test/pos_spec/VolOrderManagerBatch.t.sol` is >= 5 — the guards
      are exercised through low-level calls, not the typed interface.
    - `grep -c 'forge-config: default.fuzz.runs' test/pos_spec/VolOrderManagerBatch.t.sol` is >= 1,
      and every fuzz test names its non-fuzz anchor in its docstring.
    - `grep -c 'id contiguity: third valid order at C+2' test/pos_spec/VolOrderManagerBatch.t.sol`
      outputs `1` — the M5 kill site exists verbatim and Task 4 references it by this string.
    - `make test 2>&1 | tail -5` shows the 4 known pre-existing pos_spec failures and NO new
      failures. If a 5th failure appears and it is
      `TickVolatilityLibTest::test__fuzz__tickVolatilitySqrtPriceX64x96AndTickSuccess`, re-run once
      — it is the KNOWN pre-existing flake and is NOT a regression. Record both counts.
    - `git diff --stat src/` shows ONLY `src/modules/pos_spec/VolOrderManagerMod.plk` (from Task 1);
      nothing under `src/types/pos_spec/`.
  </acceptance_criteria>

  <done>The batch surface is CALLED-green through FFI-deployed bytecode, all four guards are exercised via low-level malformed calldata, contiguity and zero-footprint are asserted on raw slots, and the Phase-17 boundary test is flipped rather than deleted.</done>
</task>

<task type="auto">
  <name>Task 3: MEASURE the N=MAX_BATCH gas cost against the 10,000,000 threshold</name>
  <files>test/pos_spec/VolOrderManagerBatch.t.sol</files>

  <read_first>
    - test/pos_spec/VolOrderManagerBatch.t.sol (from Task 2 — you extend it)
    - .planning/REQUIREMENTS.md line 121 (MCAL-01: "measured N = MAX_BATCH cost <= 10,000,000 gas
      — not 'under the block limit'")
  </read_first>

  <action>
Add `contract VolOrderManagerBatchGasTest is VolOrderManagerBatchBase` to
`test/pos_spec/VolOrderManagerBatch.t.sol`.

**DO NOT carry the research's ~2.94M estimate forward as fact.** That number sat beside fabricated
citations and is UNVERIFIED. MCAL-01 requires a MEASURED number. Measure it; then, separately,
report whether the measurement lands in the same order of magnitude as the estimate — a
measurement near 12M would signal the loop is doing something unintended and must be investigated,
not accepted.

`test__unit__maxBatchGasUnderBudget`:

```solidity
uint256[] memory words = new uint256[](MAX_BATCH);
for (uint256 j = 0; j < MAX_BATCH; j++) {
    // Distinct tuples so every SSTORE is a cold zero->nonzero write -- the honest worst case.
    // Identical tuples would still hit distinct slots (ids differ), but distinct values also
    // rule out any accidental value-dependent short-circuit.
    words[j] = packInput(1000 + j, 100 + j, 50 + j);
}
bytes memory cd = encodeBatch(words);

uint256 g0 = gasleft();
(bool ok, bytes memory r) = address(mgr).call(cd);
uint256 execGas = g0 - gasleft();

// A GAS NUMBER FOR A REVERTED CALL IS MEANINGLESS. Prove the work actually happened FIRST --
// this is what stops a passing gas assertion from silently certifying an early revert.
assertTrue(ok, "the N=128 batch must SUCCEED for its gas number to mean anything");
assertEq(abi.decode(r, (uint256)), MAX_BATCH, "all 128 tuples stored");
assertEq(mgr.orderCount(), MAX_BATCH, "orderCount advanced by 128");
assertEq(
    uint256(vm.load(address(mgr), orderSlot(MAX_BATCH))),
    expectedPacked(1000 + 127, 100 + 127, 50 + 127),
    "the 128th order really landed"
);

// MCAL-01's threshold is about what a REAL TRANSACTION costs, so the intrinsic cost that a
// .call does not incur is added back explicitly rather than quietly omitted:
//   21,000 base + EIP-2028 calldata (16 gas per nonzero byte, 4 per zero byte).
uint256 calldataGas = 0;
for (uint256 j = 0; j < cd.length; j++) calldataGas += (cd[j] == 0 ? 4 : 16);
uint256 totalGas = execGas + 21_000 + calldataGas;

emit log_named_uint("MCAL-01 execGas   (N=128)", execGas);
emit log_named_uint("MCAL-01 calldataGas", calldataGas);
emit log_named_uint("MCAL-01 TOTAL     (N=128)", totalGas);

assertLe(totalGas, 10_000_000, "MCAL-01: N=MAX_BATCH must cost <= 10,000,000 gas");
```

Add a docstring stating: this is a MEASURED threshold, not "under the block limit" — a transaction
consuming a whole block is not reliably includable, which is why the criterion is 10M and not 30M.
Record the three logged numbers verbatim in the SUMMARY.

Run with `-vv` so the `log_named_uint` values are actually printed; a threshold assertion that
passes without recording the number does not satisfy "MEASURED".
  </action>

  <verify>
    <automated>forge test --match-test test__unit__maxBatchGasUnderBudget --skip 'src/modules/protocol_integrations/PriceSetterHook.sol' --via-ir --optimize -vv 2>&1 | tail -20</automated>
  </verify>

  <acceptance_criteria>
    - The test PASSES and the `-vv` output prints all three `log_named_uint` lines. Copy the exact
      integers into the SUMMARY under a "MCAL-01 MEASURED" heading — a passing assertion without a
      recorded number does NOT discharge MCAL-01.
    - `assertTrue(ok, ...)`, `assertEq(..., MAX_BATCH, "all 128 tuples stored")` and the
      `orderSlot(MAX_BATCH)` assertion all appear BEFORE the `assertLe` in the source
      (`grep -n 'assertTrue(ok\|assertLe(totalGas' test/pos_spec/VolOrderManagerBatch.t.sol` — the
      `assertTrue` line number must be lower). A gas number from a reverted call is meaningless.
    - `grep -c '10_000_000' test/pos_spec/VolOrderManagerBatch.t.sol` is >= 1 and
      `grep -c '30_000_000\|block.gaslimit' test/pos_spec/VolOrderManagerBatch.t.sol` outputs `0` —
      the threshold is the stated 10M, never the block limit.
    - If `totalGas > 10,000,000`: STOP and report. Do NOT raise the threshold and do NOT lower
      MAX_BATCH without recording the measurement and escalating — MCAL-01 pins both numbers.
    - Sanity note for the summary: state whether the measurement is within ~2x of the research's
      UNVERIFIED ~2.94M estimate. A number near 12M means the loop is doing something unintended
      and must be investigated before the phase is called done.
  </acceptance_criteria>

  <done>N=128 total gas is measured, printed, recorded verbatim, and asserted <= 10,000,000, with the batch proven to have actually stored 128 orders before the threshold is evaluated.</done>
</task>

<task type="auto">
  <name>Task 4: Mutation gate — seven mutants, each an OBSERVED RED</name>
  <files>src/modules/pos_spec/VolOrderManagerMod.plk (mutated then restored sha256-identical; no net change)</files>

  <read_first>
    - src/modules/pos_spec/VolOrderManagerMod.plk (every mutant is a single edit to this file)
    - test/pos_spec/VolOrderManagerBatch.t.sol (the assertions that must redden)
    - .planning/STATE.md lines 58, 76 (the 17-01 M5 hand-off and the observed-RED discipline:
      applied -> cache cleared -> verbatim RED recorded -> restored sha256-identical -> green)
  </read_first>

  <action>
Run the battery. **Discipline, non-negotiable, carried from v3.0 and re-affirmed at 17-01:**

For EACH mutant, in order:
  1. `sha256sum src/modules/pos_spec/VolOrderManagerMod.plk` — record the PRISTINE digest ONCE
     before starting; it is the restore target for all seven.
  2. Apply the single edit.
  3. `rm -rf cache/fuzz` — a `runs: 0` kill is a replay, not proof.
  4. `make test-vol-order-batch` (and `make test-vol-order-manager` where the table says so).
  5. Record the RED **verbatim**: the failing test name AND the failing assertion's message string.
     "It went red" is not evidence; the NAMED assertion is.
  6. Restore the file. Re-run `sha256sum` and confirm it equals the pristine digest EXACTLY.
  7. Re-run the suite and confirm GREEN before applying the next mutant.

`deployPlank` recompiles the `.plk` fresh over FFI on every test run (carried v3.0 decision), so no
`make compile-plank` is needed between mutants — the mutant reaches the deployed bytecode.

| # | Mutant | Exact edit | Expected RED (test :: assertion message) |
|---|--------|-----------|------------------------------------------|
| M-G1 | guard 1 deleted | delete the line `require(@evm_calldataload(36) == 0x40);` | `test__unit__nonCanonicalOffsetReverts` :: `"guard 1: non-canonical offset must revert the whole tx"`. Mechanism: the 0x2000 offset is no longer rejected, the loop reads its elements from the fixed byte-100 region, the batch SUCCEEDS and `ok` becomes true. |
| M-G2 | guard 2 deleted | delete the line `require(@evm_calldataload(68) == count);` | `test__unit__lengthCountMismatchReverts` :: `"guard 2: array length must agree with count"`. Mechanism: count=2 / length=1 is no longer cross-checked, the loop runs twice, the batch succeeds. |
| M-G3 | guard 3 deleted | delete the line `require(@evm_calldatasize() >= 100 + 32 * count);` | `test__unit__truncatedCalldataReverts` :: `"guard 3: calldatasize must cover 100 + 32*count"`. **THIS MUTANT IS INVISIBLE TO EVERY STATE ASSERTION** — past-end `@evm_calldataload` returns zero-padded words, `build_vol_order(0,0,0)` fails validation, the tuple is SKIPPED and state stays CLEAN. If you record a state assertion as the kill here you have recorded a fake kill. The REVERT assertion is the sole kill site; confirm in the RED output that it is `assertFalse(ok, ...)` that failed. |
| M-MB | MAX_BATCH guard deleted | delete the line `require(count <= MAX_BATCH);` | `test__unit__overMaxBatchRevertsNoStateChange` :: `"count > MAX_BATCH must revert before any sstore"`. Mechanism: 129 tuples are stored, `orderCount` reaches 129. Justification for adding this beyond the six named mutants: MAX_BATCH is the ONLY bound on an otherwise unbounded loop (Plank's `while` lowerer has no loop bound), so its deletion is the highest-severity single-line defect in the branch. |
| M-OFF | THE TRANSCRIPTION TRAP | change guard 1's `36` to `68`, i.e. `require(@evm_calldataload(68) == 0x40);` | `test__unit__mixedBatchFootprintAndContiguity` :: `"a mixed batch never reverts"`. Mechanism: at count=3 the word at byte 68 is 3, not 0x40, so the whole tx reverts. **Killability check, and it is REAL:** this mutant is EQUIVALENT for any corpus point with `count == 64` and only there — verify the reddening corpus point has `count != 64` (the mixed batch has count=3). Record that check explicitly; if every corpus point had used count=64 this mutant would have survived silently. |
| M-M5 | THE PHASE-17 HAND-OFF | move `id = id + 1;` from inside the `if validate_order(order) {` block to the line ABOVE the `if`, so the id advances unconditionally | `test__unit__mixedBatchFootprintAndContiguity` :: `"id contiguity: third valid order at C+2"`. Mechanism: the skipped middle tuple CONSUMES id C+2, so valid_B lands at C+3 and slot C+2 stays zero. **`orderCount` also reddens (C+3 vs C+2), but the CONTIGUITY assertion is the load-bearing one** — record BOTH failing assertions, and state in the summary that a count-only corpus would NOT have discriminated. This mutant was an EQUIVALENCE-CHECKED NON-KILL in Phase 17 (the strict path's revert rolled the SSTORE back); STATE.md:58 requires it to be a REAL kill here. If it survives, the CORPUS is wrong (the invalid tuple is not strictly in the middle), not the code. |
| M-VAL | validation branch deleted | delete the `if validate_order(order) {` line and its matching closing `}`, so the three body statements run unconditionally | `test__unit__mixedBatchFootprintAndContiguity` :: `"orderCount advances by the success count, not by N"` AND `"id contiguity: third valid order at C+2"` (the invalid tuple now occupies C+2). Also `test__fuzz__batchNeverReverts` :: `"MCAL-04: no batch-revert observed"` — see the DIVERGENCE NOTE below. |

**DIVERGENCE NOTE — read before running M-VAL, and record it in the SUMMARY.** ROADMAP SC-6 says
deleting the validation branch "must redden the totality fuzz as a BATCH REVERT, not a wrong
value." That expectation is mechanically UNACHIEVABLE, and Task 1's own MCAL-04 enumeration is the
proof: `pack_vol_order` is pure `@evm_shl`/`&`/`|` with no `require` and no trapping arithmetic,
and `@evm_sstore` cannot revert here — so an unvalidated tuple is STORED WRONG, never reverted.
The honest kill is therefore a STATE red on the mixed-batch test, which is a strictly stronger
observation (it pins WHERE the wrong word landed, not merely that something failed).
Do NOT manufacture a revert to satisfy the wording. Run the mutant, record whichever assertions
actually redden verbatim, and record this divergence with its reason. If a revert IS observed,
record that too and investigate — it would mean a step in the enumeration is not total, which is an
MCAL-04 finding, not a formality.

**If any mutant SURVIVES:** do not record it as killed and do not delete it. Either (a) strengthen
the corpus until it reddens, or (b) prove it EQUIVALENT with a written mechanism and record it as
an equivalence-checked non-kill, explicitly NOT counted toward the gate — the 17-01 precedent for
(b) is M5 in the strict path, and it is exactly why M5 is back in this table.

Finally, after all seven are restored: `make test` full suite, confirm the module file's sha256
equals the pristine digest, and confirm `git diff --stat src/types/pos_spec/` is empty.
  </action>

  <verify>
    <automated>sha256sum src/modules/pos_spec/VolOrderManagerMod.plk && make test-vol-order-batch 2>&1 | tail -10 && make test 2>&1 | tail -5</automated>
  </verify>

  <acceptance_criteria>
    - SEVEN mutants applied and recorded. For EACH, the summary contains: the exact edit, the
      verbatim failing test name, the verbatim failing assertion MESSAGE STRING, and the post-restore
      sha256. A mutant with no named failing assertion is NOT recorded as killed.
    - M-G3's recorded kill is a REVERT assertion (`assertFalse(ok, "guard 3: ...")`) and explicitly
      NOT a state assertion. The summary states why: past-end calldata reads return zero-padded
      words that fail validation and are skipped, leaving state clean.
    - M-M5 is recorded as an OBSERVED RED (STATE.md:58 requires it), with BOTH failing assertions
      listed and `"id contiguity: third valid order at C+2"` named as the load-bearing one.
    - M-OFF's record includes the explicit killability check: the reddening corpus point has
      `count != 64`, stated as a number.
    - M-VAL's record includes the DIVERGENCE NOTE and the actual observed failure mode.
    - Final `sha256sum src/modules/pos_spec/VolOrderManagerMod.plk` EQUALS the pristine digest
      recorded at the start of Task 4 and the digest recorded at the end of Task 1.
    - `make test-vol-order-batch` and `make test-vol-order-manager` are GREEN after restoration.
    - `make test 2>&1 | tail -5` shows the 4 known pre-existing pos_spec failures and no new ones
      (re-run once if the known TickVolatilityLib flake appears as a 5th). Record the final count.
    - `make compile-plank` still reports `13 ok, 0 failed, 0 skipped`.
    - `rm -rf cache/fuzz` was run before EACH mutant — stated in the summary.
  </acceptance_criteria>

  <done>Seven mutants each produced an OBSERVED, NAMED RED; every one restored to the pristine sha256 and re-verified green; the guard-3 revert-only kill and the M5 contiguity kill are recorded with their mechanisms; the M-VAL divergence from SC-6's wording is documented with its reason.</done>
</task>

</tasks>

<verification>
Phase-level checks, run after all four tasks:

1. `make compile-plank` → `13 ok, 0 failed, 0 skipped` (no new entrypoint).
2. `make test-vol-order-batch` → zero failures, >= 12 tests (11 from Task 2 + the gas test).
3. `make test-vol-order-manager` → zero failures, boundary test flipped not deleted.
4. `make test` → 4 known pre-existing pos_spec failures, no new ones. The known
   `TickVolatilityLibTest` flake (~1 cold run in 4) is not a regression; re-run once.
5. `git diff --stat src/types/pos_spec/` → EMPTY.
6. `git diff --stat` touches exactly four files: `VolOrderManagerMod.plk`,
   `VolOrderManagerBatch.t.sol`, `VolOrderManager.t.sol`, `Makefile`.
7. The SUMMARY records: the MCAL-01 measured gas triple, the MCAL-04 enumeration location, all
   seven mutation records, the M-VAL divergence note, and the new `make test` pass count.
</verification>

<success_criteria>
Mapped one-to-one to ROADMAP Phase 18a SC 1-6:

- **SC-1 (MCAL-03, MCAL-01):** `test__unit__mixedBatchFootprintAndContiguity` green — valid tuples
  at CONTIGUOUS ids C+1/C+2, `orderCount` advanced by the success count, slot C+3 zero.
- **SC-2 (MCAL-02):** three guards each REVERT under their own corpus, each via low-level `.call`;
  guard 3 asserted as a REVERT, never as state.
- **SC-3 (MCAL-01):** `count = 129` reverts with `orderCount` unchanged; `count = 128` succeeds;
  N=128 total gas MEASURED, PRINTED and `<= 10,000,000`.
- **SC-4 (MCAL-04):** the six-step structural enumeration is written into
  `VolOrderManagerMod.plk` as the PRIMARY argument, plus `test__fuzz__batchNeverReverts` recording
  "no batch-revert OBSERVED over 256 runs" as corroboration; batch and strict demonstrably share
  `validate_order`.
- **SC-5 (MCAL-06):** batch-of-1 state and id byte-identical to a standalone `create_order`; N=0
  succeeds and leaves every observable slot byte-identical (from both a zero and a seeded counter).
- **SC-6:** seven mutants, each an OBSERVED RED with a NAMED failing assertion, each restored
  sha256-identical and re-verified green.
</success_criteria>

<output>
After completion, create
`.planning/phases/18a-batch-input-state-effects/18a-01-SUMMARY.md`.

It MUST carry forward, because Phases 18b and 19 and the Haskell peer `mv15a18k` depend on them:
- The MCAL-01 measured gas triple (execGas / calldataGas / total) as integers.
- The MCAL-04 structural enumeration's location, and any step whose totality was contradicted.
- All seven mutation records with verbatim failing assertions, plus the M-VAL divergence note.
- **A PEER NOTE for `mv15a18k`:** guard 1 requires the CANONICAL array offset `0x40`. Solidity,
  `cast`, ethers and web3.py all emit it, but a bespoke Haskell encoder that legally pads the head
  would be REJECTED with an empty revert. This is a HARD ENCODING REQUIREMENT, and it is
  deliberate — it is the phantom-order hole MCAL-02 exists to close. Also send the INPUT WORD
  layout (`skew@0..15 | strike@16..103 | width@104..127`, bits >= 128 MUST be zero) and note that
  it DIFFERS from the stored word only in `width`'s offset.
- The new `make test` pass count as the baseline for Phase 18b.
- The confirmation that 18a returns ONE WORD (the success count) — Phase 18b replaces this return
  with `(bool,uint256)[]` and inherits every state assertion in this file unchanged.
</output>
</content>
</invoke>
