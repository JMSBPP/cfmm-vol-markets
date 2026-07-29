---
phase: 18b-typed-return-encoding
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - src/modules/pos_spec/VolOrderManagerMod.plk
  - test/pos_spec/VolOrderManagerBatch.t.sol
  - .planning/REQUIREMENTS.md
  - .planning/ROADMAP.md
  - .planning/STATE.md
autonomous: true
requirements: [MCAL-05]
gap_closure: false

must_haves:
  truths:
    - "create_orders returns (bool,uint256)[] with head 0x40, stride 0x40, total exactly 64 + 64*N bytes"
    - "keccak256(plank returndata) == keccak256(abi.encode(expectedResults)) where the expected side uses Solidity's STANDARD abi.encode"
    - "N=0 returns exactly 64 bytes (offset 0x20, length 0), never reverts, and abi.decode succeeds on it"
    - "Results are positionally aligned to input; success words are canonically 0 or 1; a failed tuple is (false, 0)"
    - "The results buffer is allocated BEFORE the loop and N=128 (8256 bytes) returns uncorrupted"
    - "Every 18a state/guard assertion stays green through the return-type change"
  artifacts:
    - path: "src/modules/pos_spec/VolOrderManagerMod.plk"
      provides: "hand-rolled (bool,uint256)[] encoder in the create_orders branch"
      contains: "@evm_return"
    - path: "test/pos_spec/VolOrderManagerBatch.t.sol"
      provides: "byte-level differential vs abi.encode, returndatasize pins, N=0/1/2/128 corpus, migrated callBatch"
      contains: "abi.encode"
  key_links:
    - from: "src/modules/pos_spec/VolOrderManagerMod.plk"
      to: "@evm_return(out, 64 + 64 * count)"
      via: "buffer allocated before the loop, written per-iteration at 64 + 64*i"
      pattern: "@evm_return\\(out"
    - from: "test/pos_spec/VolOrderManagerBatch.t.sol"
      to: "solc's standard encoder as an independent oracle"
      via: "keccak256(raw returndata) == keccak256(abi.encode(BatchResult[]))"
      pattern: "keccak256\\(abi\\.encode\\("
---

<objective>
Replace 18a's one-word `create_orders` return with the hand-rolled `(bool success, uint256 orderId)[]`
dynamic-array encoding, and prove it byte-exact against solc's standard `abi.encode`.

Purpose: this is the ONLY surface in milestone v4.0 with zero in-repo precedent. Every other
`@evm_return` in `src/` is a fixed 32/64/96/0 bytes. The Haskell `StochasticOrderGen` consumer
(rpc_api PR #9) decodes these bytes, and the N=0 failure mode is INVISIBLE on-chain — it surfaces as
an `abi.decode` revert in the client, not as a red test here. Byte equality against an independent
encoder is what closes that gap.

Output: `create_orders` returning `64 + 64*N` bytes; a differential test contract asserting keccak
equality against `abi.encode`; an observed-RED mutation gate; MCAL-05 and MCAL-06's carried
return-bytes clause both discharged.
</objective>

<execution_context>
@/home/jmsbpp/.claude/get-shit-done/workflows/execute-plan.md
@/home/jmsbpp/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/ROADMAP.md
@.planning/STATE.md
@.planning/phases/18b-typed-return-encoding/18b-CONTEXT.md
@src/modules/pos_spec/VolOrderManagerMod.plk
@test/pos_spec/VolOrderManagerBatch.t.sol
@test/pos_spec/VolOrderManager.t.sol

<interfaces>
<!-- Extracted from the codebase. Use these directly — do NOT go exploring for them. -->

MEMORY BUILTINS (the only ones this plan needs), verified at source:

  @malloc_zeroed(size: u256) -> memptr      // abi_dynamic.plk:12
  @malloc_uninit(size: u256) -> memptr      // storage.plk:232
  @mstore32(ptr: memptr, value: u256)       // storage.plk:233
  @evm_return(ptr: memptr, len: u256)       // abi_dynamic.plk:14  (terminates execution)

POINTER ARITHMETIC IS `+%` (WRAPPING), NOT `+`. Plank's `+` is CHECKED and is not the operator
used for memptr offsets anywhere in the tree. The verified idiom:

  lib/plank-monorepo/std/precompile.plk:15-18
      @mstore32(buf +% 0,  hash);
      @mstore32(buf +% 32, v);
      @mstore32(buf +% 64, r);
      @mstore32(buf +% 96, s);

  lib/plank-monorepo/std/storage.plk:43   (the LOOP-INDEXED form this plan needs)
      @mstore32(data.ptr +% 32 * i, chunk);

THE MECHANISM PRECEDENT — shape only. Its TYPE handling does NOT apply to us.
  lib/plank-monorepo/plankc/plank-diff-tests/src/std/abi_dynamic.plk:11-14
      let out_size = abi_encoded_size(WithBytes, decoded);
      let out = @malloc_zeroed(out_size);
      let written = unsafe_abi_encode(WithBytes, out, decoded);
      @evm_return(out, written);
  i.e. malloc -> write -> @evm_return with a COMPUTED length. We supply the array semantics by hand.

WHY std::abi CANNOT DO THIS — verified at lib/plank-monorepo/std/abi.plk:22-58. `abi_encoded_size`
branches on exactly `void | u256 | bool | membytes | @is_struct(T)` and every other type falls to
`let _sizeof_unsupported_type: u256 = true;`, a deliberate compile-time type error. There is NO
array case, and Plank has no array type to pass it. A `membytes` workaround also fails: `bytes`
encodes its length in BYTES while `T[]` encodes it in ELEMENTS, so at N=2 the length word must read
`2`, not `128`. The layouts diverge at exactly the word that matters.

THE ALLOCATION HAZARD — lib/plankified-univ3/plank/lib/storage.plk:230-235
      const array_slot = fn (base_slot: u256, index: u256) u256 {
          let buf = @malloc_uninit(32);      // <-- EVERY CALL. Once per loop iteration.
          @mstore32(buf, base_slot);
          @evm_keccak256(buf, 32) + index
      };

EXISTING TEST SURFACE — test/pos_spec/VolOrderManagerBatch.t.sol
      function packInput(uint256 strike, uint256 width, uint256 skew) internal pure returns (uint256)
          // INPUT layout: skew@0..15 | strike@16..103 | width@104..127
      function encodeBatch(uint256[] memory words) internal pure returns (bytes memory)
      function encodeBatchRaw(uint256 count, uint256 offset, uint256 length, uint256[] memory words)
      function truncate(bytes memory b, uint256 dropBytes) internal pure returns (bytes memory)
      function wordAt(bytes memory b, uint256 off) internal pure returns (uint256 w)
      function callBatch(bytes memory cd) internal returns (bool ok, uint256 ret)   // <-- MIGRATED IN TASK 1

EXISTING BASE — test/pos_spec/VolOrderManager.t.sol :: VolOrderManagerBase
      SLOT_ORDER_COUNT, SLOT_ORDERS_BASE, STRIKE=12345, WIDTH=600, SKEW=77, TICK_SPACING=20
      function orderSlot(uint256 id) internal pure returns (bytes32)
      function expectedPacked(uint256 strike, uint256 width, uint256 skew) internal pure returns (uint256)
          // STORED layout: width@128 | tickSpacing@104 | strike@16 | skew@0
</interfaces>

<pinned_byte_layout>
Pinned during the roadmap review. DO NOT RE-DERIVE.

    offset 0x00   0x20         <- outer offset word pointing at the array
    offset 0x20   N            <- element count (ELEMENTS, not bytes)
    offset 0x40   success[0]   <- canonically 0 or 1
    offset 0x60   orderId[0]
    offset 0x80   success[1]
    offset 0xA0   orderId[1]
    ...
    head = 0x40, stride = 0x40, TOTAL = 64 + 64*N

`(bool,uint256)` is a STATIC tuple, so elements are inlined in the tail with NO per-element offsets.
Byte totals: N=0 -> 64, N=1 -> 128, N=2 -> 192, N=3 -> 256, N=128 -> 8256.
</pinned_byte_layout>

<constraints>
- NEVER modify `src/types/pos_spec/*`. Not one byte.
- No `vm.assume` anywhere. Corpora are CONSTRUCTED with `bound`.
- Every fuzz names a non-fuzz anchor in its docstring.
- Every forge invocation carries `--via-ir --optimize --skip 'src/modules/protocol_integrations/PriceSetterHook.sol'`.
- Baselines that must hold at the end: `make compile-plank` = 13 ok / 0 failed / 0 skipped;
  `make test` = 112 pass / 4 pre-existing fails. A FIFTH failure named
  `TickVolatilityLibTest::test__fuzz__tickVolatilitySqrtPriceX64x96AndTickSuccess` at counterexample
  `2^64-1` is a KNOWN pre-existing flake (~1 cold run in 4, proven pre-existing at 17-01). Re-run
  before treating it as a regression; do NOT chase it.
- Every 18a state/guard behaviour must stay green. Changing the return type must not disturb any
  state behaviour — that is the whole point of 18a having shipped a one-word return.
- `forge clean && rm -rf cache/fuzz` before recording any mutation RED.
</constraints>
</context>

<tasks>

<task type="auto" tdd="false">
  <name>Task 1: Hand-roll the (bool,uint256)[] encoder and migrate 18a's decode path in lockstep</name>
  <files>src/modules/pos_spec/VolOrderManagerMod.plk, test/pos_spec/VolOrderManagerBatch.t.sol</files>

  <read_first>
    - `src/modules/pos_spec/VolOrderManagerMod.plk` — the whole file, but especially lines 94-211
      (the `SELECTOR_CREATE_ORDERS` branch). You are replacing ONE line (`return_u256(ok)`) and
      adding writes around the existing loop. The six-step MCAL-04 structural enumeration comment
      and all four guards stay VERBATIM.
    - `lib/plank-monorepo/plankc/plank-diff-tests/src/std/abi_dynamic.plk` lines 6-15 — the
      malloc -> write -> `@evm_return(ptr, computedLen)` shape.
    - `lib/plank-monorepo/std/precompile.plk` lines 15-18 — the `buf +% N` write idiom.
    - `lib/plank-monorepo/std/storage.plk` line 43 — `@mstore32(data.ptr +% 32 * i, chunk)`, the
      loop-indexed write.
    - `lib/plankified-univ3/plank/lib/storage.plk` lines 230-235 — `array_slot`'s per-call malloc.
    - `test/pos_spec/VolOrderManagerBatch.t.sol` lines 99-103 — `callBatch`, and note its
      `if (ok && r.length == 32)` guard.
    - `test/pos_spec/VolOrderManagerBatch.t.sol` line 407 — `abi.decode(r, (uint256))` in the gas test.
  </read_first>

  <action>
STEP A — the Plank encoder.

In `src/modules/pos_spec/VolOrderManagerMod.plk`, inside the `SELECTOR_CREATE_ORDERS` branch ONLY.

A1. Immediately AFTER the four `require(...)` guards and BEFORE `let mut i = 0;`, allocate the
results buffer and write the two head words:

```plank
        // ------------------------------------------------------------------------------------
        // THE (bool success, uint256 orderId)[] RETURN BUFFER (MCAL-05).
        //
        // ALLOCATED HERE, BEFORE THE LOOP, AND THIS ORDERING IS LOAD-BEARING. `array_slot` calls
        // @malloc_uninit(32) on EVERY invocation (v3 storage.plk:232), i.e. once per iteration.
        // A buffer whose size is not reserved up front, or which is under-sized, has those
        // per-iteration allocations land inside the region this branch writes -- the results and
        // array_slot's keccak scratch then alias. Reserving the exact final size in one call
        // before any iteration runs makes that structurally impossible.
        //
        // SIZE ARITHMETIC CANNOT PANIC HERE. Plank's `*` and `+` are CHECKED, but the MAX_BATCH
        // guard above already ran, so count <= 128 and 64 + 64*count <= 8256.
        //
        // LAYOUT (a STATIC tuple, so elements are inlined in the tail with no per-element
        // offsets -- head 0x40, stride 0x40):
        //     0x00  0x20        outer offset word to the array
        //     0x20  count       length in ELEMENTS (not bytes -- this is where a membytes-shaped
        //                       workaround would have gone wrong: bytes counts BYTES)
        //     0x40  success[0] / 0x60 orderId[0] / 0x80 success[1] / ...
        // TOTAL = 64 + 64*count. N=0 is exactly 64 bytes, NOT zero and NOT 32.
        //
        // std::abi CANNOT produce this. abi_encoded_size (std/abi.plk:22-58) branches on exactly
        // void | u256 | bool | membytes | @is_struct(T) and type-errors on everything else; there
        // is no array case and Plank has no array type. Only the MECHANISM is borrowed, from
        // plank-diff-tests/src/std/abi_dynamic.plk:11-14.
        let out = @malloc_zeroed(64 + 64 * count);
        @mstore32(out +% 0, 0x20);
        @mstore32(out +% 32, count);
```

A2. Inside the existing `while i < count { ... }` loop, replace the current
`if validate_order(order) { ... }` block with an if/else that writes a result slot on BOTH paths.
Keep the existing `BEST-EFFORT = VALIDATE BEFORE WRITE` comment block above it verbatim; keep the
existing "Plank has NO `continue`" comment verbatim. The new body:

```plank
            // POSITIONAL ALIGNMENT: result i is written at head + 64*i on BOTH paths, so the
            // results array is index-parallel to the input array by construction rather than by
            // accumulation. A failing tuple does not shift its successors.
            let base = 64 + 64 * i;

            if validate_order(order) {
                id = id + 1;
                @evm_sstore(array_slot(SLOT_ORDERS_BASE, id), pack_vol_order(order));
                // CANONICAL BOOL. Exactly 1, never a truthy nonzero: Solidity's abi.decode REJECTS
                // a non-canonical bool while a lenient Haskell decoder may accept it, so a
                // non-canonical word makes the two consumers silently disagree about the same
                // bytes. Named mutant.
                @mstore32(out +% base, 1);
                @mstore32(out +% (base + 32), id);
            } else {
                // A FAILED TUPLE IS EXACTLY (false, 0). Not (false, id), not a skipped slot.
                @mstore32(out +% base, 0);
                @mstore32(out +% (base + 32), 0);
            }
            i = i + 1;
```

A3. DELETE the `let mut ok = 0;` declaration and the `ok = ok + 1;` increment. The success count is
no longer returned — it is recoverable from the results array and from `orderCount`. Leaving a dead
mutable counter in the loop invites a future reader to re-wire the return to it.

A4. Replace the trailing `return_u256(ok);` and its "ONE WORD" comment block with:

```plank
        // THE TYPED RETURN (MCAL-05, and MCAL-06's carried return-bytes clause). Replaces 18a's
        // deliberate one-word success count: return_u256 emits exactly 32 bytes and structurally
        // CANNOT satisfy the N=0 64-byte encoding.
        //
        // N=0 RETURNS 64 BYTES AND NEVER REVERTS. Governing principle: structurally impossible ->
        // revert; semantically empty -> well-formed empty result. A zero-arrival Poisson tick is an
        // in-distribution sample, not a client error. Returning 0 or 32 bytes here would make the
        // consumer's abi.decode revert -- a failure INVISIBLE on-chain that lands in the Haskell
        // client. Pinned by test__unit__emptyReturnIsExactlySixtyFourBytes.
        @evm_return(out, 64 + 64 * count);
```

A5. Keep the `return_u256` import — the `orderCount()` and `getOrderPacked()` branches still use it.
Do NOT remove it.

Update the file's header comment: the create_orders paragraph currently says the batch branch returns
a one-word success count. Correct it to describe the typed return.

STEP B — migrate the Solidity decode path so 18a's assertions keep their meaning.

This MUST land in the same task as Step A. `callBatch`'s `if (ok && r.length == 32)` guard means the
new 64+64N-byte return leaves `ret` at its default 0, which would silently zero SEVEN existing
assertions — and two of them (`assertEq(ret, 0, ...)` in `test__unit__dirtyHighBitsAreSkippedNotStored`
and `test__unit__emptyBatchIsNoOp`) would pass VACUOUSLY. Splitting these steps leaves the suite
either red or, worse, falsely green.

B1. At file scope in `test/pos_spec/VolOrderManagerBatch.t.sol`, above
`abstract contract VolOrderManagerBatchBase`, declare the result struct:

```solidity
/// @dev The Solidity mirror of the module's hand-rolled return element. As a struct with fields
///      (bool, uint256), `abi.encode(BatchResult[])` emits EXACTLY the layout the module
///      hand-rolls: outer offset 0x20, length in ELEMENTS, then static tuples inlined at stride
///      0x40 with no per-element offsets. That is what makes solc usable as an INDEPENDENT oracle.
struct BatchResult {
    bool success;
    uint256 orderId;
}
```

B2. Replace `callBatch`'s body so it decodes the real return and reports the success count, keeping
its `(bool ok, uint256 ret)` SIGNATURE unchanged. Every 18a test body then stays byte-identical and
its `ret` assertion means what it always meant — while now flowing through the real encoder:

```solidity
    /// @dev THE ONLY PATH INTO THE MODULE IN THIS FILE. Signature deliberately unchanged across
    ///      Phase 18b: `ret` still means "how many tuples succeeded", so every 18a assertion is
    ///      preserved verbatim while now being routed through the typed encoder. The 18a
    ///      assertions therefore got STRICTLY STRONGER for free -- they previously read one raw
    ///      word, and now they only hold if abi.decode accepts the hand-rolled bytes.
    ///      Tests that need the RAW bytes use callBatchRaw below.
    function callBatch(bytes memory cd) internal returns (bool ok, uint256 ret) {
        bytes memory r;
        (ok, r) = address(mgr).call(cd);
        if (ok) {
            BatchResult[] memory rs = abi.decode(r, (BatchResult[]));
            for (uint256 j = 0; j < rs.length; j++) {
                if (rs[j].success) ret++;
            }
        }
    }

    /// @dev Raw returndata, undecoded. The byte-level differential and every returndatasize
    ///      assertion go through THIS -- decoding first would discard exactly the evidence those
    ///      tests exist to produce.
    function callBatchRaw(bytes memory cd) internal returns (bool ok, bytes memory ret) {
        (ok, ret) = address(mgr).call(cd);
    }
```

B3. In `test__unit__maxBatchGasUnderBudget`, `abi.decode(r, (uint256))` now decodes the OUTER OFFSET
WORD and yields 32, not 128. Replace that single assertion:

```solidity
        BatchResult[] memory rs = abi.decode(r, (BatchResult[]));
        assertEq(rs.length, MAX_BATCH, "all 128 results returned");
        assertEq(r.length, 64 + 64 * MAX_BATCH, "N=128 returns exactly 8256 bytes");
```
Keep it in the same position — it must stay BEFORE the `assertLe` threshold check, per 18a's rule
that a gas number for a reverted or short-circuited call is meaningless.

B4. RE-MEASURE the gas. The 18a number (execGas 3,203,452 + 21,000 + 23,000 calldata = 3,247,452
TOTAL) will shift: the encoder adds ~2*count mstores plus memory expansion for an 8256-byte buffer.
The 10,000,000 `assertLe` ceiling is UNCHANGED and still the only hard assertion. Record the new
measured TOTAL in the summary. Sanity band, NOT an assertion: the new total should land under
3,400,000. If it exceeds that, STOP and investigate before continuing — a jump of that size means
the buffer is being reallocated or the loop is doing unintended work.

B5. Do NOT otherwise edit any 18a test body. The state assertions, the guard assertions, the
contiguity ordering (`orderSlot(7)` before `orderCount`) and the fuzz all stay exactly as they are.
  </action>

  <verify>
    <automated>make compile-plank 2>&amp;1 | tail -3 &amp;&amp; forge test --match-path 'test/pos_spec/VolOrderManagerBatch.t.sol' --skip 'src/modules/protocol_integrations/PriceSetterHook.sol' --via-ir --optimize</automated>
  </verify>

  <acceptance_criteria>
    - `make compile-plank` final line reads `compile-plank: 13 ok, 0 failed, 0 skipped`.
    - `make test-vol-order-batch` is fully green: all 18a tests pass unchanged
      (`test__unit__mixedBatchFootprintAndContiguity`, `test__unit__dirtyHighBitsAreSkippedNotStored`,
      `test__unit__nonCanonicalOffsetReverts`, `test__unit__lengthCountMismatchReverts`,
      `test__unit__truncatedCalldataReverts`, `test__unit__overMaxBatchRevertsNoStateChange`,
      `test__unit__maxBatchExactlyOneTwoEightSucceeds`, `test__unit__batchOfOneEqualsSingleCall`,
      `test__unit__emptyBatchIsNoOp`, `test__unit__maxBatchGasUnderBudget`,
      `test__fuzz__batchNeverReverts`, plus both encoding sanity tests).
    - `make test-vol-order-manager` still green (the single-call surface is untouched).
    - The buffer is allocated before the loop — this ONE-LINE ordering check must report the malloc
      line number as strictly LESS than the `while` line number:
      `awk '/@malloc_zeroed\(64 \+ 64 \* count\)/{m=NR} /while i < count/{w=NR} END{print "malloc="m" while="w; exit !(m>0 && w>0 && m<w)}' src/modules/pos_spec/VolOrderManagerMod.plk`
      exits 0.
    - `grep -c 'return_u256(ok)' src/modules/pos_spec/VolOrderManagerMod.plk` returns 0.
    - `grep -c 'let mut ok = 0' src/modules/pos_spec/VolOrderManagerMod.plk` returns 0.
    - `grep -n '@evm_return(out, 64 + 64 \* count)' src/modules/pos_spec/VolOrderManagerMod.plk`
      matches exactly one line.
    - `grep -c 'r.length == 32' test/pos_spec/VolOrderManagerBatch.t.sol` returns 0 (the old
      32-byte decode guard is gone).
    - `grep -c 'abi.decode(r, (uint256))' test/pos_spec/VolOrderManagerBatch.t.sol` returns 0.
    - `git diff --stat src/types/pos_spec/` produces NO output.
    - The measured N=128 TOTAL gas is recorded in the summary with all three
      `emit log_named_uint` values, and is under 3,400,000.
  </acceptance_criteria>

  <done>
    `create_orders` returns `64 + 64*N` bytes of hand-rolled `(bool,uint256)[]`; the results buffer
    is allocated in one call before the loop; every 18a state and guard assertion is green with its
    body unedited and its `ret` value now flowing through `abi.decode`; `src/types/pos_spec/` is
    byte-untouched.
  </done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: Byte-level differential against solc's abi.encode, plus the N=0 / alignment / N=128 pins</name>
  <files>test/pos_spec/VolOrderManagerBatch.t.sol, Makefile</files>

  <read_first>
    - `test/pos_spec/VolOrderManagerBatch.t.sol` as Task 1 left it — especially the new
      `BatchResult` struct, `callBatchRaw`, and the existing `packInput` / `encodeBatch` builders.
    - `test/pos_spec/VolOrderManager.t.sol` lines 39-78 — `VolOrderManagerBase`: `orderSlot`,
      `expectedPacked`, `STRIKE`/`WIDTH`/`SKEW`, `SLOT_ORDER_COUNT`.
    - `test/pos_spec/VolOrderManagerBatch.t.sol` lines 106-141 — the
      `VolOrderManagerBatchEncodingTest` pattern: pin the TEST BUILDERS before pinning the module,
      so a builder bug can never be mistaken for a module bug. Mirror that discipline here.
    - The `<pinned_byte_layout>` block above — the byte totals 64 / 128 / 192 / 256 / 8256.
    - `src/modules/pos_spec/VolOrderManagerMod.plk` — the encoder Task 1 wrote.
  </read_first>

  <behavior>
    - N=0: `returndatasize == 64`; bytes == `abi.encode(new BatchResult[](0))`; `abi.decode` succeeds
      and yields a zero-length array; the call does not revert.
    - N=1 all-valid: `returndatasize == 128`; bytes == `abi.encode([(true, C+1)])`.
    - N=2 all-valid: `returndatasize == 192`; bytes == `abi.encode([(true, C+1), (true, C+2)])`.
    - N=3 mixed (valid, INVALID, valid): `returndatasize == 256`; bytes ==
      `abi.encode([(true, C+1), (false, 0), (true, C+2)])` — positional alignment AND `(false, 0)`
      in ONE assertion.
    - N=3 all-invalid: bytes == `abi.encode([(false,0),(false,0),(false,0)])`.
    - N=128: `returndatasize == 8256`; bytes == `abi.encode` of the 128 constructed results.
    - Head/stride read back RAW from the returndata: word@0 == 0x20, word@32 == N,
      word@(64 + 64*i) == 0 or 1, word@(64 + 64*i + 32) == the expected id.
    - Every `success` word is EXACTLY 0 or 1 — asserted as a word-value check, not via `bool`.
  </behavior>

  <action>
Append a new contract to `test/pos_spec/VolOrderManagerBatch.t.sol`. Add helpers to
`VolOrderManagerBatchBase` first.

STEP A — helpers on `VolOrderManagerBatchBase`.

```solidity
    /// @dev THE ORACLE SIDE. Deliberately the STANDARD encoder and nothing else: no manual word
    ///      writes, no mirroring of the module's arithmetic. If this function ever grows an
    ///      mstore or a hand-computed offset, the differential becomes VACUOUS -- it would then be
    ///      comparing the module against a restatement of the module. solc is the independent
    ///      oracle precisely because it was written by someone else.
    function expectedReturn(BatchResult[] memory rs) internal pure returns (bytes memory) {
        return abi.encode(rs);
    }

    /// @dev Builds a BatchResult[] from parallel arrays, so a test states its expectation as data.
    function results(bool[] memory oks, uint256[] memory ids)
        internal
        pure
        returns (BatchResult[] memory rs)
    {
        require(oks.length == ids.length, "test bug: ragged expectation");
        rs = new BatchResult[](oks.length);
        for (uint256 j = 0; j < oks.length; j++) {
            rs[j] = BatchResult({success: oks[j], orderId: ids[j]});
        }
    }
```

STEP B — the differential contract.

```solidity
/// @title VolOrderManagerReturnEncodingTest
/// @notice MCAL-05 (SC-1..SC-4) + MCAL-06's carried return-bytes clause. The hand-rolled
///         (bool,uint256)[] encoder, compared BYTE FOR BYTE against solc's standard abi.encode.
///
///         WHY BYTES AND NOT DECODED VALUES. A decoded comparison compares SEMANTICS and leaves
///         the encoder unconstrained: a consistent head or stride error can round-trip through
///         abi.decode and never surface. Byte equality makes solc an independent oracle for the
///         one surface in this milestone with zero in-repo precedent. The expected side is built
///         ONLY with abi.encode -- never by mirroring the module's manual writes, which would make
///         the whole differential vacuous.
contract VolOrderManagerReturnEncodingTest is VolOrderManagerBatchBase {
```

Write these tests. In every one, put the KECCAK BYTE-EQUALITY assertion FIRST among the
discriminating assertions — forge reports only the FIRST failing assertion per test, and at 18a a
coarser assertion masked a real kill until the executor caught it. Length and word-level assertions
follow as localisation aids, not as the kill site.

B1. `test__unit__returnBuildersMatchTheStandardEncoder` (pure) — pin the ORACLE before pinning the
module, mirroring `VolOrderManagerBatchEncodingTest`'s discipline. Assert
`abi.encode(new BatchResult[](0)).length == 64`, `== 128` for one element, `== 192` for two, and
that for a two-element array `wordAt(enc,0) == 0x20`, `wordAt(enc,32) == 2`,
`wordAt(enc,64) == 1`, `wordAt(enc,96) == firstId`, `wordAt(enc,128) == 0`, `wordAt(enc,160) == 0`.
This is what proves the pinned layout IS what solc emits, independently of the module.

B2. `test__unit__emptyReturnIsExactlySixtyFourBytes` — THE N=0 EDGE. Its failure mode is invisible
on-chain, so it gets its own named test.
```solidity
        (bool ok, bytes memory ret) = callBatchRaw(encodeBatch(new uint256[](0)));

        assertTrue(ok, "N=0 is semantically empty, not structurally impossible -- it must not revert");
        assertEq(
            keccak256(ret),
            keccak256(expectedReturn(new BatchResult[](0))),
            "N=0 bytes must equal abi.encode of an empty BatchResult[]"
        );
        assertEq(ret.length, 64, "N=0 returns EXACTLY 64 bytes -- not 0, not 32");
        assertEq(wordAt(ret, 0), 0x20, "N=0: outer offset word");
        assertEq(wordAt(ret, 32), 0, "N=0: length word is zero ELEMENTS");

        // THE CONSUMER-SIDE CHECK. This is the failure that lands in the Haskell client rather
        // than here: a 0- or 32-byte return decodes to a revert, not to an empty list.
        BatchResult[] memory decoded = abi.decode(ret, (BatchResult[]));
        assertEq(decoded.length, 0, "abi.decode succeeds and yields an empty array");

        // And from a SEEDED counter, so "N=0 works" cannot hide behind a fresh registry.
        vm.store(address(mgr), SLOT_ORDER_COUNT, bytes32(uint256(5)));
        (bool ok2, bytes memory ret2) = callBatchRaw(encodeBatch(new uint256[](0)));
        assertTrue(ok2, "N=0 from a seeded counter also succeeds");
        assertEq(keccak256(ret2), keccak256(ret), "the seeded counter does not change the N=0 bytes");
```

B3. `test__unit__mixedBatchReturnIsByteExact` — THE FLAGSHIP, and the named non-fuzz anchor for the
fuzz below. Reuse 18a's mixed corpus: seed the counter to C=5, then
`[packInput(STRIKE,WIDTH,SKEW), packInput(STRIKE,WIDTH,65535), packInput(999,7,3)]` — skew 65535 is
one of only TWO rejected skews, so EXACTLY ONE conjunct fails and the failure is named. Expectation:
`[(true,6), (false,0), (true,7)]`. Assert keccak equality FIRST, then `ret.length == 256`, then the
raw word reads at 0/32/64/96/128/160/192/224 to localise. State in the docstring that this single
assertion covers positional alignment, the `(false,0)` failure shape and the stride simultaneously.

B4. `test__unit__allInvalidBatchReturnsAllFalseZero` — three invalid tuples; expectation is three
`(false, 0)` elements; `ret.length == 256`; `mgr.orderCount() == 0`. Guards against an encoder that
only writes the success path and leaves failures as unwritten (accidentally-correct) zeros — the
mutation gate's M-FAIL is what actually kills that, and this is its kill site.

B5. `test__unit__successWordsAreCanonicallyZeroOrOne` — read the raw `success` words and assert
`w == 0 || w == 1` with `assertTrue(w < 2, ...)`, per element, over the mixed corpus. This must NOT
go through `bool` — decoding to `bool` is exactly what would hide a non-canonical word, and solc's
own decoder reverting on it is a DIFFERENT failure than the one being pinned. Use `wordAt`.

B6. `test__unit__maxBatchReturnIsByteExactAndUncorrupted` — THE ALLOCATION-ORDERING PROBE at
N=MAX_BATCH=128, where `array_slot` performs 128 interleaved `@malloc_uninit(32)` calls against an
8256-byte results buffer. Build 128 distinct valid tuples `packInput(1000+j, 100+j, 50+j)`,
expectation `[(true, 1) .. (true, 128)]`. Assert keccak equality FIRST, then `ret.length == 8256`,
then spot-check `wordAt(ret, 64 + 64*127 + 32) == 128` (the LAST orderId — the word most likely to
be clobbered) and `wordAt(ret, 32) == 128` (the length word — the word that a mid-loop allocation
would step on). Also re-assert `vm.load(orderSlot(128)) == expectedPacked(1127, 227, 177)` so
storage corruption and return corruption are distinguished from each other.

B7. `test__fuzz__returnBytesMatchStandardEncoder` — `forge-config: default.fuzz.runs = 256`.
Docstring names `test__unit__mixedBatchReturnIsByteExact` as the non-fuzz anchor. Corpus CONSTRUCTED
with `bound`, no `vm.assume`:
```solidity
        uint256 n = bound(nSeed, 0, 16);   // 0 INCLUDED -- N=0 must be in the corpus
        uint256 c = bound(seedSeed, 0, 1000);
        vm.store(address(mgr), SLOT_ORDER_COUNT, bytes32(c));
```
For each j, draw `shape = bound(keccak256(shapeSeed,j), 0, 3)`: shape 0 VALID
(`packInput(strike,width,skew)` with `strike = bound(.,1,type(uint88).max)`,
`width = bound(.,1,type(uint24).max)`, `skew = bound(.,1,65534)`); shape 1 skew 0; shape 2 skew
65535; shape 3 dirty high bit `| (1 << 200)`. Track `nextId = c` and push
`BatchResult(true, ++nextId)` for valid draws, `BatchResult(false, 0)` otherwise — the expectation
is computed TEST-SIDE from the constructed shapes and is NEVER read back from the module. Then:
```solidity
        (bool ok, bytes memory ret) = callBatchRaw(encodeBatch(words));
        assertTrue(ok, "the batch never reverts");
        assertEq(keccak256(ret), keccak256(expectedReturn(expected)), "returndata must be byte-exact");
        assertEq(ret.length, 64 + 64 * n, "total is exactly 64 + 64N");
```

STEP C — a dedicated make target.

Add to the Makefile beside `test-vol-order-batch`, and to `.PHONY`:
```make
# test-vol-order-return: the hand-rolled (bool,uint256)[] RETURN ENCODER (MCAL-05) -- head 0x40,
# stride 0x40, total 64+64N, the N=0 64-byte edge, canonical bools, (false,0) failures and the
# N=128 allocation probe, all compared BYTE FOR BYTE against solc's standard abi.encode. Distinct
# from test-vol-order-batch, which owns the INPUT half (guards, MAX_BATCH, state effects).
test-vol-order-return:
	forge test --match-contract VolOrderManagerReturnEncodingTest --skip 'src/modules/protocol_integrations/PriceSetterHook.sol' --via-ir --optimize
```
  </action>

  <verify>
    <automated>make test-vol-order-return &amp;&amp; make test-vol-order-batch</automated>
  </verify>

  <acceptance_criteria>
    - `make test-vol-order-return` green with all 7 tests present and passing:
      `test__unit__returnBuildersMatchTheStandardEncoder`,
      `test__unit__emptyReturnIsExactlySixtyFourBytes`,
      `test__unit__mixedBatchReturnIsByteExact`,
      `test__unit__allInvalidBatchReturnsAllFalseZero`,
      `test__unit__successWordsAreCanonicallyZeroOrOne`,
      `test__unit__maxBatchReturnIsByteExactAndUncorrupted`,
      `test__fuzz__returnBytesMatchStandardEncoder`.
      Confirm the count: `forge test --match-contract VolOrderManagerReturnEncodingTest --skip 'src/modules/protocol_integrations/PriceSetterHook.sol' --via-ir --optimize 2>&amp;1 | grep -E '7 passed|[0-9]+ passed'` shows 7 passed, 0 failed.
    - `make test-vol-order-batch` still green (18a untouched).
    - THE ORACLE IS NOT MIRRORED — `expectedReturn` must contain `abi.encode` and no manual byte
      construction: `awk '/function expectedReturn/,/^    }/' test/pos_spec/VolOrderManagerBatch.t.sol | grep -cE 'mstore|assembly|encodePacked|<<'` returns 0.
    - The byte totals are asserted as literals somewhere in the new contract — each of
      `64`, `128`, `192`, `256`, `8256` appears in a `ret.length` assertion. Check the 8256 case
      specifically: `grep -c 'ret.length, 64 + 64 \* MAX_BATCH\|ret.length, 8256' test/pos_spec/VolOrderManagerBatch.t.sol` is >= 1.
    - The fuzz corpus includes N=0: `grep -c 'bound(nSeed, 0, 16)' test/pos_spec/VolOrderManagerBatch.t.sol` returns 1.
    - No `vm.assume` in the file: `grep -c 'vm.assume' test/pos_spec/VolOrderManagerBatch.t.sol` returns 0.
    - `git diff --stat src/types/pos_spec/` produces NO output.
  </acceptance_criteria>

  <done>
    The encoder is byte-exact against solc's standard `abi.encode` across N = 0, 1, 2, 3-mixed,
    3-all-invalid, 128 and a 256-run constructed fuzz that includes N=0; `returndatasize` is pinned
    at 64/128/192/256/8256; success words are proven canonical by raw word read; the N=128
    allocation probe is green; the expected side is built exclusively by `abi.encode`.
  </done>
</task>

<task type="auto" tdd="false">
  <name>Task 3: Mutation gate — six mutants, each applied, observed RED, restored sha256-identical</name>
  <files>src/modules/pos_spec/VolOrderManagerMod.plk (mutated then restored), .planning/REQUIREMENTS.md, .planning/ROADMAP.md, .planning/STATE.md</files>

  <read_first>
    - `src/modules/pos_spec/VolOrderManagerMod.plk` as Tasks 1-2 left it — you will be editing and
      restoring exactly the encoder lines.
    - `test/pos_spec/VolOrderManagerBatch.t.sol` — the assertion ORDER in each new test, so you can
      predict and then confirm which assertion reddens.
    - `.planning/STATE.md` "Decisions" — the 18a-01 FINDING: **forge reports only the FIRST failing
      assertion per test**, which is why this task records the NAMED failing assertion per mutant
      rather than just "test X failed".
    - `.planning/STATE.md` "carried, v3.0" — the observed-RED protocol: applied -> `cache/fuzz`
      cleared -> verbatim RED recorded -> restored sha256-identical -> green.
    - `.planning/REQUIREMENTS.md` lines 125-127 (MCAL-05, MCAL-06's carried clause) and line 244-245
      (the traceability rows to update).
  </read_first>

  <action>
PROTOCOL, per mutant, no exceptions:
```bash
sha256sum src/modules/pos_spec/VolOrderManagerMod.plk    # BEFORE — record it
# apply the single-line mutation
forge clean && rm -rf cache/fuzz
make test-vol-order-return                                # record VERBATIM output
# revert the mutation
sha256sum src/modules/pos_spec/VolOrderManagerMod.plk    # MUST equal the BEFORE hash
make test-vol-order-return && make test-vol-order-batch  # green again
```
The restored hash MUST match byte-for-byte. A restore that only "looks right" is not a restore.

THE MUTANTS.

M1 — HEAD BASE 0x40 -> 0x20 (the likeliest real bug).
Change `let base = 64 + 64 * i;` to `let base = 32 + 64 * i;`, leaving the offset word, the length
word and the size arithmetic INTACT. This is the transcription error where the elements are laid
down one word too low and clobber the length word.
**KILLABILITY NOTE — STATE THIS IN THE SUMMARY:** at N=0 this mutant is INDISTINGUISHABLE. There are
no elements to misplace, the total is 64 bytes either way, and the bytes are identical. It is
killable ONLY at N >= 1, which is why the corpus is not allowed to be N=0-only.
Expected RED: `test__unit__mixedBatchReturnIsByteExact` at
`"N=3 mixed: returndata must be byte-exact"` (the keccak assertion). Confirm
`test__unit__emptyReturnIsExactlySixtyFourBytes` stays GREEN and record that as the empirical
demonstration of the N=0 blindness.

M2 — OUTER OFFSET WORD DROPPED ENTIRELY (the roadmap's literal head-0x20 wording).
Change the allocation to `@malloc_zeroed(32 + 64 * count)`, the head writes to a single
`@mstore32(out +% 0, count);`, `base` to `32 + 64 * i`, and the return to
`@evm_return(out, 32 + 64 * count);`. This emits the length but forgets the outer offset.
Expected RED: this one IS killable at N=0 — `test__unit__emptyReturnIsExactlySixtyFourBytes` reddens
at the keccak assertion (32 bytes vs 64). Record the RED there AND at
`test__unit__mixedBatchReturnIsByteExact`. M1 and M2 are complementary, which is why both are run.

M3 — STRIDE OFF BY ONE WORD.
Change `let base = 64 + 64 * i;` to `let base = 64 + 32 * i;`.
**KILLABILITY NOTE:** indistinguishable at N=0 AND at N=1 (i=0 makes the stride irrelevant). Killable
from N >= 2. Expected RED: `test__unit__mixedBatchReturnIsByteExact` at the keccak assertion.
Also run the `64 + 96 * i` variant and record whichever RED you observe; note that this variant may
also write past the allocated buffer, so record whether the observed failure is the keccak mismatch
or a revert, and say which.

M4 — NON-CANONICAL SUCCESS WORD.
Change `@mstore32(out +% base, 1);` to `@mstore32(out +% base, 2);`.
Expected RED: `test__unit__successWordsAreCanonicallyZeroOrOne` at the `w < 2` assertion, AND
`test__unit__mixedBatchReturnIsByteExact` at the keccak assertion. **This mutant also reddens
`make test-vol-order-batch` broadly**, because `callBatch`'s `abi.decode` reverts on a non-canonical
bool — record that as CORROBORATION of the silent-disagreement thesis: solc's decoder rejects these
bytes outright while a lenient Haskell decoder would accept them, so the two consumers disagree
about the same bytes. That divergence IS the requirement.

M5 — A FAILED TUPLE RETURNS SOMETHING OTHER THAN (false, 0).
In the `else` branch change `@mstore32(out +% (base + 32), 0);` to
`@mstore32(out +% (base + 32), id);` — a failed tuple leaks the running counter as its orderId.
Expected RED: `test__unit__mixedBatchReturnIsByteExact` at the keccak assertion (the middle element's
orderId reads 6 instead of 0). Confirm `test__unit__allInvalidBatchReturnsAllFalseZero` also reddens
— on a fresh registry `id` is 0 there, so check whether it does; **if it stays GREEN, that is the
expected and interesting result and must be recorded**: it proves an all-invalid-on-fresh-registry
corpus alone cannot kill this mutant, and that the SEEDED mixed corpus is the sole kill site. Do not
paper over it either way.

M6 — UNDER-ALLOCATED BUFFER (the allocation hazard, at N=128).
Change `let out = @malloc_zeroed(64 + 64 * count);` to `let out = @malloc_zeroed(64);` while leaving
every write and the `@evm_return(out, 64 + 64 * count)` length unchanged. The region the loop writes
now overlaps the 32-byte scratch buffers `array_slot` mallocs on every iteration, which is exactly
the aliasing the before-the-loop ordering rule exists to prevent.
Expected RED: `test__unit__maxBatchReturnIsByteExactAndUncorrupted` at the keccak assertion.
Record whether the storage assertion (`vm.load(orderSlot(128))`) ALSO reddens — that distinguishes
"the results were corrupted" from "the slot derivation was corrupted", and both are informative.

M7 — THE PURE ORDERING MUTANT (equivalence check, NOT a counted kill).
Attempt to move the buffer allocation so it no longer precedes every `array_slot` call. Under a bump
allocator a correctly-SIZED buffer reserved up front cannot be encroached upon by later allocations,
so this may well be UNKILLABLE as a pure reordering. **Document the outcome honestly**: if you cannot
construct a compilable reordering that changes observable behaviour, record it as
EQUIVALENCE-CHECKED, state the bump-allocator reason, and DO NOT count it among the kills. M6 is the
mutant that carries the allocation-hazard evidence. Never inflate a kill count with an equivalent
mutant.

DOCUMENTATION UPDATES (all by hand — see the tooling note).

D1. `.planning/REQUIREMENTS.md`:
    - Line ~125, MCAL-05: `- [ ]` -> `- [x]`.
    - Line ~126, MCAL-06: already `[x]`; append a `**[18b-01 DISCHARGED]**` sub-bullet under the
      existing 18a-01 PARTIAL note recording that the "exactly 64 bytes: offset 0x20, length 0"
      clause is now byte-verified by `test__unit__emptyReturnIsExactlySixtyFourBytes`.
    - Traceability table line ~244: `| MCAL-05 | Phase 18b | Pending |` -> `Complete`.
    - Traceability table line ~245: MCAL-06's
      `Complete (state half; return-bytes clause carried to 18b)` -> `Complete` (drop the caveat —
      the carried clause is discharged).

D2. `.planning/ROADMAP.md`: mark `Phase 18b` `- [x]` in the phase list, and replace
    `Plans:\n- [ ] 18b-01: TBD` with `- [x] 18b-01-PLAN.md — hand-rolled (bool,uint256)[] return
    encoder, byte-exact vs abi.encode`.

D3. `.planning/STATE.md`: update `stopped_at`, `last_activity`, Current Position, the progress bar
    (4/5 phases, 4 plans), the Performance Metrics table (add an 18b row), and append the new
    decisions to Accumulated Context — at minimum the re-measured N=128 gas TOTAL, the M1 N=0
    blindness, the M3 N<=1 blindness, and the M7 equivalence outcome.

TOOLING NOTE — READ BEFORE RUNNING ANY gsd-tools COMMAND. `gsd-tools` cannot parse the `18b` phase
suffix: both `phase complete` and `roadmap update-plan-progress` FAIL on it, and `update-progress`
CLOBBERS STATE.md's frontmatter back to milestone `v2.0`. Make D1-D3 by hand with Edit. After
committing, VERIFY what actually landed:
```bash
git show --stat HEAD
grep -n 'milestone:' .planning/STATE.md          # MUST still read v4.0
grep -n 'MCAL-05' .planning/REQUIREMENTS.md
```
If the frontmatter reads `v2.0`, restore it before finishing.
  </action>

  <verify>
    <automated>make test-vol-order-return &amp;&amp; make test-vol-order-batch &amp;&amp; make test-vol-order-manager &amp;&amp; make compile-plank 2>&amp;1 | tail -3</automated>
  </verify>

  <acceptance_criteria>
    - For EACH of M1, M2, M3, M4, M5, M6 the summary records: the exact one-line diff applied; the
      VERBATIM forge RED including the NAMED failing assertion string; the BEFORE and AFTER
      `sha256sum` of `src/modules/pos_spec/VolOrderManagerMod.plk` shown to be IDENTICAL; and a
      green re-run after restore. Six mutants, six observed REDs.
    - M1's record explicitly states that `test__unit__emptyReturnIsExactlySixtyFourBytes` stayed
      GREEN under M1, and that the mutant is therefore killable only at N >= 1.
    - M3's record explicitly states the N <= 1 blindness.
    - M5's record states whether `test__unit__allInvalidBatchReturnsAllFalseZero` reddened, and if
      not, why the seeded mixed corpus is the sole kill site.
    - M7 is recorded as EQUIVALENCE-CHECKED with its reason and is NOT counted among the kills. The
      summary's kill count reads 6, not 7.
    - Final state, all green: `make test-vol-order-return`, `make test-vol-order-batch`,
      `make test-vol-order-manager`; `make compile-plank` = `13 ok, 0 failed, 0 skipped`;
      `make test` = 112 passed / 4 pre-existing failures (a 5th `TickVolatilityLibTest` failure is
      the known flake — re-run once and note it, do not chase it).
    - `grep -n '^- \[x\] \*\*MCAL-05\*\*' .planning/REQUIREMENTS.md` matches.
    - `grep -n '| MCAL-05 | Phase 18b | Complete |' .planning/REQUIREMENTS.md` matches.
    - `grep -c 'return-bytes clause carried to 18b' .planning/REQUIREMENTS.md` returns 1 — the
      historical 18a-01 PARTIAL note is PRESERVED (it is the audit trail); only the traceability
      TABLE row loses the caveat.
    - `grep -n 'milestone: v4.0' .planning/STATE.md` matches after the commit.
    - `git show --stat HEAD` lists `src/modules/pos_spec/VolOrderManagerMod.plk` (restored, so it
      may show only Task 1-2 content), `test/pos_spec/VolOrderManagerBatch.t.sol`, `Makefile`,
      `.planning/REQUIREMENTS.md`, `.planning/ROADMAP.md`, `.planning/STATE.md`.
    - `git diff --stat src/types/pos_spec/` produces NO output.
  </acceptance_criteria>

  <done>
    Six mutants each observed RED against a NAMED assertion and restored sha256-identical, with the
    N=0 and N<=1 blind spots documented as measured facts rather than asserted ones; the pure
    ordering mutant documented as equivalence-checked and excluded from the count; MCAL-05 and
    MCAL-06's carried return-bytes clause both marked Complete by hand with the commit verified.
  </done>
</task>

</tasks>

<verification>
Phase-level checks, all must hold simultaneously at the end:

1. `make compile-plank` -> `compile-plank: 13 ok, 0 failed, 0 skipped`.
2. `make test` -> 112 passed / 4 pre-existing failures (the 5th `TickVolatilityLibTest` red is the
   known ~1-in-4 cold-run flake; re-run once before calling it a regression).
3. `make test-vol-order-return` -> 7 tests, all green.
4. `make test-vol-order-batch` -> every 18a test green with its body unedited.
5. `make test-vol-order-manager` -> green (single-call surface untouched).
6. `git diff --stat src/types/pos_spec/` -> empty.
7. `grep -rn 'vm.assume' test/pos_spec/` -> no matches.
8. Six observed mutation REDs recorded with verbatim output and matching before/after sha256sums.
9. The re-measured N=128 gas TOTAL is recorded and is <= 10,000,000 (and under 3,400,000, or the
   excess is explained).
</verification>

<success_criteria>
- `create_orders` returns `(bool,uint256)[]` at head `0x40`, stride `0x40`, total exactly `64 + 64N`
  bytes, verified by `returndatasize` at N = 0/1/2/3/128 (64/128/192/256/8256) and by
  `keccak256(plankReturndata) == keccak256(abi.encode(expectedResults))` where the expected side is
  built EXCLUSIVELY by solc's standard `abi.encode` (SC-1).
- `N = 0` returns exactly 64 bytes (offset `0x20`, length `0`), never reverts, and
  `abi.decode(ret, (BatchResult[]))` succeeds yielding a zero-length array — verified from both a
  zero and a seeded counter (SC-2, and MCAL-06's carried clause).
- Results are positionally aligned to input; `success` words are proven canonically 0 or 1 by RAW
  WORD READ rather than through `bool`; a failed tuple is exactly `(false, 0)` (SC-3).
- The results buffer is allocated in a single call BEFORE the loop, with the ordering machine-checked
  by line number, and N=128 returns uncorrupted alongside an uncorrupted `orderSlot(128)` (SC-4).
- Mutation gate: head `0x40`->`0x20` (both the base-shift and the dropped-offset-word variants),
  stride off-by-one-word, non-canonical success word, a failed tuple returning other than
  `(false,0)`, and an under-allocated buffer at N=128 EACH produce an OBSERVED RED against a NAMED
  assertion; each restored sha256-identical -> green. The pure ordering mutant is equivalence-checked
  and excluded from the count. The N=0 blindness of the base-shift mutant and the N<=1 blindness of
  the stride mutant are recorded as measured facts (SC-5).
- Every 18a state and guard assertion is green with its test body unedited.
- MCAL-05 marked Complete; MCAL-06's traceability row loses its carried-clause caveat while the
  historical 18a-01 PARTIAL note is preserved as audit trail.
</success_criteria>

<output>
After completion, create `.planning/phases/18b-typed-return-encoding/18b-01-SUMMARY.md`.

It MUST contain, beyond the template:
- The re-measured N=128 gas: execGas, calldataGas, TOTAL, and the delta from 18a's 3,247,452.
- The mutation table: mutant | one-line diff | named failing assertion | before/after sha256 | kill?
- The three honest negatives, stated plainly rather than buried: M1's N=0 blindness, M3's N<=1
  blindness, and M7's equivalence-checked non-kill.
- A CARRY-FORWARD section for Phase 19 and for the rpc_api peer `mv15a18k`: the exact byte layout
  with the N=0 64-byte requirement called out as the clause most likely to break a Haskell decoder,
  and the canonical-bool divergence (solc rejects a non-canonical success word, a lenient Haskell
  decoder may not) flagged as a consumer-side contract, not a test detail.
</output>
