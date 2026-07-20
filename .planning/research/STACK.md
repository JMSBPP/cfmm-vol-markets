# Stack Research — Plank Language Capability Audit (v4.0 Multicall)

**Domain:** On-chain EVM language capability audit for `VolOrderManagerMod` + best-effort Multicall
**Researched:** 2026-07-19
**Confidence:** HIGH (every claim cites plankc source, the language docs, a compiled diff-test, or existing project `.plk`)
**Compiler:** Plank `v0.1.1`, backend `sona`/SIR — `lib/plank-monorepo/plankc/`

> Supersedes the 2026-07-16 STACK.md (v3.0 VegaAccountMod vault). This milestone is a **language-capability audit** for the dynamic-array multicall surface, not a dependency-selection task.

---

## TL;DR Verdict

The milestone's load-bearing unknowns all resolve **in favor of feasibility**, with two hard constraints:

- **Loops:** runtime `while` EXISTS and is fully lowered. `inline while` (comptime unrolling) is parsed but **NOT implemented** — do not rely on it. → loop over N tuples is a plain runtime `while`.
- **Dynamic calldata:** `@evm_calldataload(computed_offset)` and `@evm_calldatasize()` both EXIST and are proven by a compiled Solidity-differential diff-test. → an unbounded batch length can be read from calldata.
- **Best-effort containment:** Plank has no try/catch, but `@evm_call`/`@evm_staticcall`/`@evm_address_this`/`@evm_returndatasize` all EXIST → the EVM self-call boundary is available. A **pure-validation pre-check path** (all `if`/`@evm_iszero`, zero checked-ops) is also available and is the cheaper mechanism.
- **N-result return:** there is **no native array type** and `std::abi` does **not** encode `T[]`. Multi-word return works via the proven manual pattern (`@mstore32` at computed offsets + `@evm_return(ptr, len)`), which you must hand-roll for the results array.

**Recommended shape: (A) unbounded dynamic batch is expressible**, but **(B) bounded max-N batch with an explicit `count` arg is recommended** — see Feasibility Verdict at the end for the rationale.

---

## Recommended Stack

### Core Technologies

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| Plank `while` loop | v0.1.1, lowered at `plankc/frontend/hir/src/lowerer/mod.rs:736` (`InstructionKind::While`) | Iterate over N calldata tuples at runtime | Only runtime loop construct that actually compiles; proven by the `merkle_airdrop` diff-test |
| `@evm_calldataload(offset)` w/ computed offset | Builtin `plankc/frontend/session/src/builtins.rs:213` | Read the i-th tuple at `base + i*stride` | Variable offset confirmed in a compiled+diff-tested example (see Dynamic Calldata below) |
| `@evm_calldatasize()` | Builtin `builtins.rs:214` | Derive/validate batch length from calldata size | Lets the loop bound be data-driven instead of a fixed word |
| Manual return encoding (`@mstore32` + `@evm_return(ptr,len)`) | `@mstore*` builtins `builtins.rs:266-289`; pattern in `VolOrder.plk:15-20`, `merkle_airdrop.plk:74` | Write the N-result array back to the caller | No native array type exists; this is the only path for `>1` dynamic-length return |

### Supporting Builtins (the containment + memory toolkit)

| Builtin | Registration | Purpose | When to Use |
|---------|-------------|---------|-------------|
| `@evm_call` | `builtins.rs:255` (`=> Call`) | Self-call to own address; the EVM call frame contains a callee revert (success flag returned, batch continues) | Best-effort path **if** per-call logic can revert for reasons pure validation can't pre-screen |
| `@evm_staticcall` | `builtins.rs:258` | Read-only self-call variant | Same containment, when the sub-call must not mutate |
| `@evm_address_this` | `builtins.rs:208` (`=> Address`) | Get own address as the self-call target | Required argument for the self-call mechanism |
| `@evm_returndatasize` / `@evm_returndatacopy` | `builtins.rs:221-222` | Read the sub-call's return payload (orderId on success, revert data on failure) | Collect per-call result after a self-`@evm_call` |
| `@evm_iszero` | `builtins.rs:192` | Branch without arithmetic (the zero-width guard idiom in `VegaAccountMod.plk:31`) | The pure-validation pre-check path — decision, not revert |
| `@evm_keccak256` + `std::storage::map_slot_hash` | `builtins.rs:205`; used in `VegaAccountMod.plk` / `merkle_airdrop.plk:93` | Derive the per-order storage slot | Store each `VolOrder` at a keccak-derived slot, `orderCount` accumulator |
| `@malloc_uninit` / `@malloc_zeroed` / `@mcopy` / `@mstore32` / `@mload32` | `builtins.rs:266-289` | Scratch memory for buffers and the results array | All return-encoding and hashing buffers |
| `@evm_sload` / `@evm_sstore` | `builtins.rs:240-241` | Registry persistence | Store order fields + count |
| `@evm_calldatacopy` | `builtins.rs:215` | Bulk-copy a calldata region to memory | Optional: copy a tuple block before decoding |

### Development Tools

| Tool | Purpose | Notes |
|------|---------|-------|
| `PlankDeployer` FFI (`lib/plank-foundry-deployer`) | Compile+deploy `.plk` at test time | Already the project's validated build/deploy bridge (v3.0) |
| `plankc` diff-tests (`plankc/plank-diff-tests/src/examples/`) | Reference for compilable patterns | `merkle_airdrop.plk` + `MerkleAirdrop.sol` is the canonical "loop over dynamic calldata" precedent |
| `v3::util` (`plankified-univ3/plank/lib/util.plk`) | `return_u256`, `revert_empty`, `revert_with_return_data` | Reuse; `revert_with_return_data` (util.plk:8-13) already forwards self-call revert data |

---

## Capability Findings (question-by-question, with evidence)

### 1. LOOPS — EXISTS (runtime `while` only)

- **`while` is the only loop keyword in the grammar.** `plankc/docs/Grammar.md:45`: `while = "inline"? "while" expr block`. There is **no `for`, no `loop`, no `break`/`continue`** rule (grep of `Grammar.md` for those returns only the `while` rule; the `for`/`loop`/`break` tokens seen in a repo-wide grep are Rust compiler source, not Plank grammar).
- **Runtime `while` is fully lowered:** `plankc/frontend/hir/src/lowerer/mod.rs:736` emits `InstructionKind::While { condition_block, condition, body }`.
- **Proven end-to-end:** `plankc/plank-diff-tests/src/examples/merkle_airdrop.plk:52-64` uses `let mut i = 0; while i < proof_length { ... i = i + 1; }`, and it ships with a paired `MerkleAirdrop.sol` reference in the diff-test suite — i.e. it compiles and passes a Solidity differential. The docs describe this exact use: `plank-doc/src/examples/merkle-airdrop.md:8` "Iterating over calldata using a `while` loop."
- **Bounded recursion:** functions are `const fn` values (`what-makes-plank-different.md:97-108`); `abi_helpers.plk` uses recursion but only at **comptime** (`fold` over `@field_count`). No evidence runtime recursion is needed — `while` covers the batch loop.
- **`inline while` (comptime unroll) is ABSENT in v0.1.1:** parsed (`plankc/frontend/parser/src/parser/mod.rs:740` → `NodeKind::InlineWhileStmt`) but the lowerer rejects it — `lowerer/mod.rs:728` `self.error_not_yet_implemented("inline while", span);`, with a locking test `frontend/hir/src/tests.rs:779 test_inline_while_not_yet_supported` ("error: inline while is not yet supported"). **Do not design around unrolled loops.**

→ **Mechanism for "loop over N tuples": runtime `while i < count { ... i = i + 1; }`.**

### 2. DYNAMIC CALLDATA — EXISTS

- **Computed offset into `@evm_calldataload`:** counterexample to "constants only" found in the diff-tested `merkle_airdrop.plk:54`: `let proof_element = @evm_calldataload(offset + 32 + i * 32);` where both `offset` (`merkle_airdrop.plk:45`, `4 + @evm_calldataload(68)`) and `i` are runtime values. The builtin accepts an arbitrary `u256` offset expression — `builtins.rs:213 CALLDATALOAD "@evm_calldataload" => CallDataLoad`.
- **`@evm_calldatasize()` is available:** `builtins.rs:214 CALLDATASIZE "@evm_calldatasize" => CallDataSize`. So the batch length can be derived from calldata size (defensive: reject malformed payloads) or trusted from an explicit ABI length word.
- **`@evm_calldatacopy` available** for bulk region copy: `builtins.rs:215`.

→ **Mechanism for reading the i-th `(uint88,uint24,uint16)` tuple: `@evm_calldataload(base + i*stride)` (constant stride, computed index), bounds-guarded with `@evm_calldatasize()`.**

### 3. INTERNAL ERROR HANDLING (best-effort) — TWO mechanisms, both EXIST

Confirmed: Plank checked ops (`+ - *`) revert (`what-makes-plank-different.md:32-39`), and there is no try/catch keyword in the grammar. Best-effort therefore needs one of:

**(a) Pure-validation pre-check path — EXISTS, RECOMMENDED.**
The language supports branch-only validation with **no checked-op on the validation path**: `@evm_iszero`, `<`, `>`, `and`/`or`, and `if`/`else` are all non-reverting. Precedent: `VegaAccountMod.plk:31` `if @evm_iszero(collateral) { revert_empty(); }` and `:37`, `:43` — guards expressed as decisions, not arithmetic. For `create_order` the failure conditions are exactly bounds checks (zero-width, field-fits-in-u88/u24/u16), all expressible as pure comparisons. So in the batch loop a "failed" tuple becomes a **skipped branch** (record `success=false`, don't touch storage), never a revert. This contains failure with **zero sub-call gas overhead** and guarantees "a failed call leaves NO partial state" because no state write is reached.

**(b) Self-`@evm_call` boundary — EXISTS, fallback.**
All required builtins are present: `@evm_call` (`builtins.rs:255`), `@evm_address_this` (`:208`), `@evm_returndatasize`/`@evm_returndatacopy` (`:221-222`), and `revert_with_return_data`/forwarding already implemented in `util.plk:8-13`. A self-call to `@evm_address_this()` with the single-order selector executes `create_order` in a child frame; a revert there rolls back only that frame and returns `success=0` to the loop, which continues. Use this **only if** some failure mode cannot be pre-screened by pure validation (e.g. a future dependency call that reverts for data-dependent reasons). Cost: a full CALL per tuple.

→ **Mechanism for "contain per-call failure": pure-validation pre-check (primary); self-`@evm_call` to `@evm_address_this()` (fallback for un-pre-screenable reverts).** Because v4.0 `create_order` is a pure registry with bounds-only failure, **(a) is sufficient and cheaper** — the self-call boundary is not required for the stated feature set.

### 4. RETURN ENCODING (N results) — EXISTS via manual encoding; NO native array

- **Existing single-word precedent:** `return_u256` (`util.plk:23-27`) = `@malloc_uninit(32); @mstore32(p,v); @evm_return(p,32)`. Used throughout `VegaAccountMod.plk` (e.g. `:74`, `:84`).
- **Existing multi-field manual pack + dynamic-length return:** `VolOrder.plk:15-20 return_vol_order_incomplete` packs fields and does `@evm_return(out_ptr, 32)`; `merkle_airdrop.plk:74` returns a computed length. Return length is a runtime value, so **>1 word with dynamic length is supported** by writing successive `@mstore32(p +% (i*WORD), val)` then `@evm_return(p, total_len)`.
- **NO native array/slice type:** grep of `Grammar.md` for `array|[]|slice|vec` returns nothing. `std::abi` (`abi.plk`, `abi_helpers.plk`) encodes only `void`, `u256`, `bool`, `membytes`, and `struct` (`abi_helpers.plk:7-33`) — **there is no `T[]` case.** A Solidity `(bool,uint256)[]` results array is therefore **not auto-encoded**; you must hand-write the ABI dynamic-array head/tail (offset word, length word, then the element words) into a `@malloc`'d buffer and `@evm_return(ptr, len)`. The `membytes` primitive + `abi_encode(membytes, ...)` (shown in `erc20.md:50-55`) can carry an opaque blob, but the canonical `tuple[]` layout must be built manually.
- No array-return precedent found in `plankified-univ3` or `plank-monorepo/std` (searched; all returns are single-word or struct-packed).

→ **Mechanism for "return N results": manually build the ABI dynamic array (`uint256[]` of packed results, or `(bool,uint256)[]`) in a `@malloc_uninit` buffer via `@mstore32` at computed offsets, then `@evm_return(buf, len)`. Encode results in the SAME `while` loop that processes inputs (write result word i alongside input i).**

### 5. MEMORY — EXISTS

- Scratch memory builtins: `@malloc_uninit`, `@malloc_zeroed` (`builtins.rs:266-267`), `@mcopy` (`:270`), and the full `@mstore1..@mstore32` / `@mload1..@mload32` families (`:271-289`). These are **not** `@evm_`-prefixed (they are IR memory primitives; the compiler controls layout — `what-makes-plank-different.md:54-69`). `@evm_mstore`/`@evm_mload` as literal names do **not** exist; use `@mstore32`/`@mload32`.

→ Full scratch-memory support for buffers, hashing preimages, and the results array.

---

## Complete Builtin Set Found

**Source:** exhaustive grep of `plankc/crates/`, `plankc/frontend/`, `std/`; registrations in `plankc/frontend/session/src/builtins.rs`.

**`@evm_*` (direct opcode exposure, `builtins.rs`):**
`@evm_add @evm_sub @evm_mul @evm_div @evm_sdiv @evm_mod @evm_smod @evm_addmod @evm_mulmod @evm_exp @evm_signextend` · `@evm_lt @evm_gt @evm_slt @evm_sgt @evm_eq @evm_iszero @evm_and @evm_or @evm_xor @evm_not @evm_byte @evm_shl @evm_shr @evm_sar` · `@evm_keccak256` · `@evm_address_this @evm_balance @evm_origin @evm_caller @evm_callvalue @evm_calldataload @evm_calldatasize @evm_calldatacopy @evm_codesize @evm_codecopy @evm_gasprice @evm_extcodesize @evm_extcodecopy @evm_returndatasize @evm_returndatacopy @evm_extcodehash @evm_gas` · `@evm_blockhash @evm_coinbase @evm_timestamp @evm_number @evm_difficulty @evm_gaslimit @evm_chainid @evm_selfbalance @evm_basefee @evm_blobhash @evm_blobbasefee` · `@evm_sload @evm_sstore @evm_tload @evm_tstore` · `@evm_log0..@evm_log4` · `@evm_create @evm_create2 @evm_call @evm_callcode @evm_delegatecall @evm_staticcall @evm_return @evm_stop @evm_revert @evm_invalid @evm_selfdestruct`

**Non-`@evm_` builtins (IR / comptime / memory):**
`@malloc_zeroed @malloc_uninit @mcopy @mstore1..@mstore32 @mload1..@mload32` · comptime/introspection: `@field_count @field_type @get_field @set_field @is_struct @uninit @in_comptime @identifier @name` · module/init: `@init_end_offset @runtime_start_offset @runtime_length`
(`@fn0..@fn9`, `@struct*`, `@foo/@bar/@skibidi` etc. are test fixtures, not real builtins.)

**ABSENT (searched, came up empty):** `@evm_mstore`/`@evm_mload` (use `@mstore32`/`@mload32`); `for`/`loop`/`break`/`continue` keywords (grammar has only `while`); native array/slice type; `T[]` ABI codec in `std::abi`; working `inline while` (parsed, lowering rejects it).

---

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| `inline while` (comptime-unrolled loop) | Lowering emits `error_not_yet_implemented` (`lowerer/mod.rs:728`, locked by `tests.rs:779`) — will not compile in v0.1.1 | Runtime `while` (`lowerer/mod.rs:736`) |
| `@evm_mstore` / `@evm_mload` literal names | Not registered builtins | `@mstore32` / `@mload32` (`builtins.rs:266-289`) |
| `std::abi::abi_encode` for a `tuple[]` / `uint256[]` result | No array case in the codec (`abi_helpers.plk:7-33`); silently unsupported | Hand-roll the dynamic-array ABI (offset+length+elements) with `@mstore32` + `@evm_return` |
| Checked arithmetic (`+ - *`) on the validation path | Reverts the whole batch on overflow — breaks best-effort | Pure comparisons (`<`, `@evm_iszero`) as in `VegaAccountMod.plk:31` |
| Assuming try/catch | No such construct | Pure-validation skip (primary) or self-`@evm_call` frame (fallback) |

## Alternatives Considered

| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|-------------------------|
| Pure-validation skip for best-effort | Self-`@evm_call` to `@evm_address_this()` | If a per-order failure mode can't be pre-screened by bounds checks (not the case for a pure registry; becomes relevant if `create_order` later calls a revert-prone dependency) |
| Explicit `count` arg + bounded loop (shape B) | Data-driven length from `@evm_calldatasize()` (shape A) | If you want a fully self-describing ABI `tuple[]` with no separate count; costs a divmod on calldatasize and a validity check |
| Manual `tuple[]` return encoding | `membytes` opaque blob via `abi_encode(membytes,...)` | If the Haskell consumer decodes a raw byte blob rather than a typed `(bool,uint256)[]` — confirm with the rpc_api peer |

## Stack Patterns by Variant

**If the rpc_api peer confirms a batch-size cap (expected — PROJECT.md:25 marks batch-size bound "to be confirmed"):**
- Use **shape (B): explicit `uint N` count + bounded `while i < N`**, reject `N > MAX_BATCH` up front with a pure guard.
- Because it bounds gas, makes the results-buffer size a simple `@malloc_uninit(head + N*stride)`, and gives a clean revert on oversized batches instead of an out-of-gas surprise.

**If the consumer wants a self-describing ABI `(uint88,uint24,uint16)[]`:**
- Use shape (A) reading the ABI length word at the array offset (`@evm_calldataload(base_offset)`), then loop.
- Still cap the decoded length against a `MAX_BATCH` constant before the loop.

## Version Compatibility

| Component | Constraint | Notes |
|-----------|------------|-------|
| Plank `v0.1.1` | Pin the binary (PROJECT.md:71) | `inline while` unimplemented at this version — re-check if the pin moves |
| `std::abi` | No `T[]` codec at this version | Array return is manual until/unless upstream adds it |
| `PlankDeployer` FFI | v3.0-validated | Same build/deploy path; no change needed |

## Sources

- `plankc/frontend/session/src/builtins.rs:180-289` — complete builtin registration table (HIGH; primary source)
- `plankc/frontend/hir/src/lowerer/mod.rs:725-736` — `while` lowered, `inline while` rejected (HIGH)
- `plankc/frontend/hir/src/tests.rs:779` — `test_inline_while_not_yet_supported` locking test (HIGH)
- `plankc/docs/Grammar.md:45` — `while` is the sole loop rule; no `for`/`loop`/array (HIGH)
- `plankc/plank-diff-tests/src/examples/merkle_airdrop.plk:45-74` + paired `MerkleAirdrop.sol` — compiled+diff-tested runtime `while` + computed `@evm_calldataload` offset (HIGH)
- `plank-doc/src/examples/merkle-airdrop.md`, `what-makes-plank-different.md`, `comptime.md`, `getting-started.md` — language semantics (HIGH)
- `std/abi.plk`, `std/abi_helpers.plk` — ABI codec type coverage (no arrays) (HIGH)
- `src/modules/exposure/VegaAccountMod.plk`, `src/types/pos_spec/VolOrder.plk`, `plankified-univ3/plank/lib/util.plk` — existing project conventions (`return_u256`, pure guards, manual pack+return) (HIGH)

---

## Feasibility Verdict

**Which multicall shapes are expressible:**

| Shape | Expressible? | Mechanism (all builtins confirmed present) |
|-------|-------------|--------------------------------------------|
| **(A) Unbounded dynamic batch** | **YES** | Loop length from `@evm_calldatasize()`/ABI length word; `while i < len`; `@evm_calldataload(base + i*stride)`. Risk: unbounded gas / results-buffer size. |
| **(B) Bounded max-N batch with `count` arg** | **YES — RECOMMENDED** | Explicit `count` word, pure guard `count <= MAX_BATCH`, `while i < count`, results buffer `@malloc_uninit(head + count*stride)`. |
| **(C) Fixed-arity only** | YES (trivial fallback) | Unrolled fixed selectors; only if a loop somehow regressed — not needed, `while` works. |

**The three required mechanisms, each with a concrete answer:**

1. **Loop over N tuples** → runtime `while i < count { let t = @evm_calldataload(base + i*STRIDE); ...; i = i + 1; }` (`lowerer/mod.rs:736`; proven in `merkle_airdrop.plk`).
2. **Contain per-call failure** → **pure-validation skip** (branch-only bounds checks, no checked-ops, no state write on failure — `VegaAccountMod.plk:31` precedent); self-`@evm_call` to `@evm_address_this()` available as fallback but **not required** for a bounds-only registry.
3. **Return N results** → hand-built ABI dynamic array (`@malloc_uninit` + `@mstore32` at `head + i*wordsize` + `@evm_return(buf, len)`), written inside the same loop; no native array type, so this is manual (`VolOrder.plk:15-20` + `merkle_airdrop.plk:74` precedent).

**Recommendation for Requirements:** specify **shape (B) — bounded max-N batch with an explicit `count` argument** and a `MAX_BATCH` constant. It is fully expressible today, bounds gas and buffer sizing, matches the pending peer contract (PROJECT.md:25 batch-size bound "to be confirmed"), and needs **no self-call** (best-effort is a pure-validation skip). Flag one open ABI decision for the rpc_api peer: typed `(bool,uint256)[]` return vs. opaque `membytes` blob — this determines how much manual array encoding the module must carry.
