# Design Spec — PortafolioDelta (CR-T2, todo.md:121)

Status: REVIEWED (Reality Checker + Solidity Smart Contract Engineer, both NEEDS WORK) → RESOLVED. Executable.

## RESOLUTION (post-review)
Both confirmed the packing core is EVM-correct (negative-amount0 shift fine; `sar`/`signextend` accessors and the
`signextend(15,res)==res` fit-check are exactly `SafeCast.toInt128`; citations accurate). Corrections:
- **Real differential oracle (B1/MAJOR-2):** `BalanceDelta.sol` DOES import cleanly — its closure is
  `BalanceDelta → SafeCast → CustomRevert` (zero OZ; `CustomRevert` already used in the suite). My earlier probe
  "failed" only because the pre-existing `PriceSetterHook.t.sol:19` breakage poisons the global compile — build with
  `--skip '*PriceSetterHook*'`. So the test uses the **real BalanceDelta** as oracle (pack/amount0/amount1/add/sub +
  the exact overflow revert boundary), stronger than local-canonical. Keep 2-3 golden vectors as docs.
- **Wrapping component sums (MAJOR-1):** `add`/`sub` use `+%`/`-%` (EVM `ADD`/`SUB`, mod 2^256). Operands are
  sign-extended negatives; a *checked* add would spuriously revert on ordinary negative deltas. Since |a0+b0| ≤ 2^128
  no int256 overflow occurs, so wrapping == signed add; the ONLY revert is the downstream int128 fit-check.
- **Defer `apply_delta` (MAJOR-3/M1):** a signed delta belongs on the (not-yet-existing) `net*` accumulators, not the
  unsigned gross fields. Ship only `PortafolioDelta` {to_portafolio_delta, amount0, amount1, add, sub}.
- **Computed mask (m1):** `let mask128 = @evm_shl(128, 1) -% 1;` (mirrors `sub(shl(128,1),1)`), not a hand-typed literal.
- **Revert primitive:** `revert_empty()` on fit-check failure; the differential test asserts the call reverts (ok==false),
  not the selector (avoids coupling to SafeCastOverflow's selector).
- **OPEN 2 CLOSED (m1-RC):** confirmed invariant — `amount0 ↔ gross_input (Q_M/token0)`, `amount1 ↔ gross_output
  (Q_X/token1)`. Getters return sign-extended values (documented; feed back into add's signed math).
- **Golden vectors (M4):** (0,-1), (-1,0), (-1,-1), (INT128_MIN, INT128_MIN/MAX) + overflow reverts
  (add((MAX,0),(1,0)), sub((MIN,0),(1,0))) + non-revert negative (add((0,-5),(0,3))==(0,-2)).

This partially addresses todo:121 (PortafolioDelta is one component; the ExchangeRate/Accumulator accounting is a
separate follow-up).

---
### Original draft (superseded by RESOLUTION)

## Purpose
todo.md:121: "The Portafolio accounting logic goes on the type lib. This includes a PortafolioDelta type
which mimics the role of BalanceDelta for v4-core/src/types/BalanceDelta.sol." Build `PortafolioDelta` — a
packed **signed** (Δtoken0, Δtoken1) delta — as a faithful Plank port of v4-core `BalanceDelta`, on the
`types::Portafolio` lib. It is the signed counterpart to the (unsigned, gross) `Portafolio {gross_output_amt,
gross_input_amt}` type already shipped: applying a `PortafolioDelta` mutates a position's token amounts.

## `PortafolioDelta` (port of v4-core BalanceDelta.sol)
Two `int128` packed into one `int256` (held in a `u256`): amount0 in the upper 128 bits, amount1 in the lower.
- `to_portafolio_delta(amount0, amount1) u256` = `@evm_shl(128, amount0) | (amount1 & 0xff…ff[128-bit])`
  (BalanceDelta.sol:14-18). amount0/amount1 are int128 values (sign-extended in u256).
- `portafolio_delta_amount0(d) u256` = `@evm_sar(128, d)`  (signed upper 128 — BalanceDelta.sol:61-65).
- `portafolio_delta_amount1(d) u256` = `@evm_signextend(15, d)`  (signed lower 128 — BalanceDelta.sol:67-71).
- `portafolio_delta_add(a, b) u256` = `to_portafolio_delta(amt0(a)+amt0(b), amt1(a)+amt1(b))` with each sum
  checked to fit int128 (BalanceDelta.sol:20-32, via SafeCast.toInt128 — revert on overflow).
- `portafolio_delta_sub(a, b) u256` = same, component-wise subtraction (BalanceDelta.sol:34-46).

Location: `src/types/Portafolio.plk` (the type lib), alongside `Portafolio`.

## int128 fit check (the SafeCast.toInt128 semantics)
`res` (an int256 sum) fits int128 iff `signextend(15, res) == res`. Revert otherwise. Port faithfully — the add
of two valid deltas can overflow int128 (e.g. two near-max amount0s), and BalanceDelta reverts there.

## Reference / falsifiability
v4-core `BalanceDelta.sol` does NOT import cleanly here (pulls SafeCast + the same OZ/v4 dep wall that blocked
Panoptic's TokenIdLibrary). So the oracle is a **local canonical decoder** — BalanceDelta's exact shift/mask
formulas inlined in the test (cited to BalanceDelta.sol:14-71) — plus hand-computed golden vectors. Tests:
- **round-trip**: `amount0(pack(a0,a1)) == a0` and `amount1(pack(a0,a1)) == a1` for fuzzed int128 a0,a1.
- **pack layout (golden)**: `pack(a0,a1) == (a0 << 128) | (a1 & mask128)` exact for concrete values incl. negatives.
- **add/sub**: `amount0(add(a,b)) == amount0(a)+amount0(b)` (and amount1), within int128; **overflow reverts**.
- **sign handling**: negative amount0/amount1 round-trip (the `sar`/`signextend` are the whole subtlety).

## OUT OF SCOPE (follow-up, flagged for review)
The fuller `Portafolio` accounting from `spec/protocol/REQUIREMENTS.md:32` — `netOutputAmt`/`netInputAmt`
(`Accumulator<TickGrid, step>`), `exchangeRate: ExchangeRate<Cash:Numeraire, Asset:Underlying>`,
`add(...)` (cross-asset via exchangeRate), `weight(...)` — depends on `ExchangeRate` and `Accumulator` types
that do not exist yet. Those are separate designs; this spec ships only `PortafolioDelta` + a stated `apply_delta`
(below) if the reviewers deem it in scope.

## OPEN issues for review
1. **`apply_delta(Portafolio, PortafolioDelta) -> Portafolio`?** The unsigned gross `Portafolio` + a signed delta:
   is `gross_input' = gross_input + Δtoken0` (with underflow guard when Δ<0)? Or is the delta applied to the
   *net* amounts (which don't exist yet)? Include a minimal `apply_delta` now, or defer with the rest of accounting?
2. **Units alignment.** `Portafolio.gross_input_amt = Q_M (token0)`, `gross_output_amt = Q_X (token1)`.
   `BalanceDelta.amount0 = token0`, `amount1 = token1`. So `Δamount0 ↔ gross_input`, `Δamount1 ↔ gross_output`.
   Confirm this token0/token1 ↔ input/output mapping is right (it must match the Portafolio field semantics).
3. **Signed values in `u256`.** Plank has no int type; amount0/amount1 are int128 held in u256 (two's-complement,
   sign-extended). The harness/test passes them as Solidity `int128`. Confirm `@evm_sar`/`@evm_signextend`
   semantics match (proven pattern: PanopticTokenId strike used `@evm_signextend(2, …)` for int24).
