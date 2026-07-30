# HANDOFF → rpc_api workstream: VolOrder V2 (targetVega) ABI re-pin

**From:** plank workstream (`feat/plank`, VolOrder v2 increment; spec
`.planning/vol-order-v2-target-vega-SPEC.md`, units `notes/UNITS_AND_SCALES.md`).
**Why you:** `rpc_api/offchain/lib/VolOrder/{Encoding,Decode}.hs` hardcode the v1 byte
layouts; the on-chain module's own comments name your consumer as a reason for its layout
decisions. Everything below changed under you.

## The V2 surface (all values verified with cast; layouts mutation-tested)

1. **`create_order` is now 4-arg:** `create_order(uint88,uint24,uint16,uint96)` =
   (strike, width, skew, **targetVega**), selector **`0x98d950ec`** (v1 `0x6501fe94` is
   RETIRED-NEVER-LIVE). `Encoding.hs::encode_create_order` re-pins.
2. **The batch input word** (`create_orders` keeps selector `0x81357911`, word semantics
   changed): `skew@0..15 | strike@16..103 | width@104..127 | targetVega@128..223`; bits
   ≥ 224 MUST be zero (a dirty word SKIPS batch-side, REVERTS strict). width is now
   INTERIOR (masked); targetVega is the unmasked TOP field.
   `Encoding.hs::pack_vol_order_input` re-pins.
3. **The STORAGE word** (248 bits): `skew@0 | strike@16 | tickSpacing@104 | width@128 |
   targetVega@152..247`. `Decode.hs::unpack_vol_order_storage` re-pins (note: storage and
   input offsets DIFFER — build_vol_order inserts TICK_SPACING=20 at 104).
4. **E1 event is V2:** `VolOrderCreated(uint256 indexed orderId, uint88 strike, uint24
   width, uint16 skew, uint96 targetVega)`, topic0
   **`0x18bd4d460f8957f6b903aec33a3229ee1bf02b6e303c5178c5aa49a70b9de4e6`**, data = 4
   words (strike, width, skew, targetVega). `Decode.hs::decode_order_created` re-pins.
5. **PRE-EXISTING DEFECT to fix in the same pass:** `Decode.hs` carries topic0
   `0xa8892769…` which was ALREADY stale (the live v1 topic0 was `0x6a5dc726…`). Proof
   that this surface rots when omitted from cascades — please add a topic0 pin test
   against the signature string on your side.
6. **The `(bool, uint256)[]` batch RETURN encoding is UNCHANGED** —
   `decode_create_orders_result` should not need edits; the Phase-19 golden fixture's
   expected bytes remain valid (the plank fixture test passes them against the v2 module
   with targetVega appended to the input words).

## Units (binding)

`targetVega` = ΔQ_v★ in **RAW LIQUIDITY units** (the Uniswap L dimension — dimension
decision (ii), `notes/UNITS_AND_SCALES.md` §2). Valid range [1, 2^96−1]. NOT X96, NOT
WAD, NOT collateral.

## Also affected on your side (check and re-pin as applicable)

`Rpc.hs` create_order senders; `StochasticOrderGen` (must now generate a targetVega per
order — any positive value ≤ 2^96−1 is valid; realistic pool-L magnitudes are 1e18–1e21);
the Phase-19 differential drivers.

Ping the plank workstream (this worktree) with questions; the spec + units table are the
source of truth.
