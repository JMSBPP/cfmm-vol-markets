# VolOrder v2 — targetVega (ΔQ_v★) as first-class + the coupled #14 sizing map

**Status: v2 — two-step review round 1 done (Reality Checker + Solidity Smart Contract
Engineer, both NEEDS WORK); all BLOCKERs/MAJORs resolved below. The packing layout,
0-sentinel argument, forward chain, lemma citations and optionRatio reasoning all
survived verification; the findings concentrated on (i) a missing units table, (ii) the
REAL ξ⋆ realization mechanism in Panoptic's chunk derivation, (iii) the omitted Haskell
off-chain consumer surface, and (iv) under-pinned deleverage semantics.**

## Decision record (user, 2026-07-30)

1. **Option A:** the order stores the target vega ΔQ_v★ — canonical, settled-against.
   The wrapper layer owns user vocabulary; the protocol's ledger speaks ΔQ_v.
2. **Auto-deleverage enforcement:** on admissibility violation the exposure contracts to
   the funded level; the implied maturity t★ = 2·ΔQ_v/N_σ contracts with it. No hard
   liquidation except degenerate Q_M → 0.
3. **The mint map codomain is the PAIR** `(PanopticTokenId, positionSize)`.

Math basis: the VOL ORDER COMPLETION — ENDOGENOUS MATURITY block in
`notes/VOLATILITY_INSTRUMENTS.md` (staged). Formalization delegated:
cfmm-lean4-spec issue #1 (maturity bridge, deleverage-law properties, the open
recalibration law). All cited lemmas verified real: `variancePortfolio_upsilon` (= t/2),
`variancePortfolio_unit_upsilon`, `admissible_iff_mul` (NOTE: carries hypothesis
`0 < p_risk` — see D5).

## D0 — THE UNITS TABLE (entry condition for EVERYTHING; review F-SE1, BLOCKER)

Written and reviewed BEFORE V2-01. Without it the u96 packing decision is undecidable:
under a 1e18 fixed-point convention 2^96 ≈ 7.9e10 whole vega units (ample headroom);
under any X96 binary-point convention u96 max = 1.0 unit (unusable). The codebase's live
volStrike ambiguity (consumed as a Q64.96 sqrt-price coordinate in `TickVolatilityLib`
vs the σ²-join's tick²·s expectation) is standing proof this defect class is real. The
table pins, minimum:
- the vega-notional unit of ΔQ_v★ and its fixed-point convention (explicitly NOT X96);
- the worst-case plausible notional and the 2^96 headroom arithmetic;
- `VegaExposure.exposure`'s true state: DECLARED u256, DOCUMENTED u128, UNENFORCED
  (review F-RC6) — the table decides the enforced bound;
- the volStrike unit resolution (shared row with the lens spec's L2 entry condition);
- the p_vol(σ̄) quote convention (Q64.96 per exposure.md §2) and the ΔM chain scales.

## D1 — the type change

`VolOrder` gains `targetVega` (new `VegaTarget` type under `types/pos_spec/`, carried
u256, packed u96 per D2). **Predicate placement is explicit (review F-RC5, the volStrike
lesson):** the type-level completeness predicate carries `targetVega > 0`; the RANGE
bound `targetVega ≤ 2^96 − 1` lives in the VALIDATION LIB as a `strike_fits_packed`
analog (`target_vega_fits_packed`), with the strict path REVERTING and the batch bool
core SKIPPING. `pack_vol_order` masks only AFTER validation has excluded out-of-range
words — the silent-mask-without-validation class is banned.

## D2 — packing

`targetVega` u96 at storage bits 152..247 (152 used today: skew@0 u16, strike@16 u88,
tickSpacing@104 u24, width@128 u24; 104 free — verified). The 0-sentinel argument
survives (strike ≥ 1 and skew ≥ 1 occupy nonzero positions independently). Two-word
storage is rejected unless D0 shows u96 range insufficient. Mutant note (review F-SE7):
the discriminating packing mutant is an offset shift colliding with **width** (128..151,
the adjacent field), not tickSpacing.

## D3 — blast radius inventory (the cascade — now including the off-chain consumer)

| Surface | Change |
|---|---|
| `types/pos_spec/VolOrder.plk` (+ new VegaTarget) | field + pack/unpack at 152; predicate split per D1 |
| `lib/pos_spec/VolOrderValidationLib.plk` | `build_vol_order` arity 3→4; `target_vega_fits_packed`; strict/bool split |
| `VolOrderManagerMod` | `create_order(uint88,uint24,uint16,uint96)` — NEW selector. **Batch INPUT word (offsets differ from storage — review F-SE3/F-RC4):** calldata layout becomes skew@0..15 \| strike@16..103 \| width@104..127 \| targetVega@128..223 (224 bits, fits one word, 32 spare). Width is NO LONGER the top field: width gains a mask and the documented dirty-high-bit rejection stance MOVES to targetVega (bits ≥224 must be zero; enforced by `target_vega_fits_packed` on the loaded top field — a dirty word SKIPS in batch, REVERTS strict; the malleability seam stays closed: two words differing only above bit 223 must not both store). `create_orders` keeps selector 0x81357911 with changed word semantics — ACCEPTED as a clean cutover because nothing is deployed (a v1 encoder's words carry targetVega=0 → all-skip, fail-safe); recorded here as the decision. MAX_BATCH math unchanged; the MCAL gas budget is RE-MEASURED, not assumed |
| Tests | VolOrderManager{,Batch,Fixture,.diff} re-pin layouts + fixtures; NEW: dirty-bits-≥224 batch skip test; the malleability pair test; gas re-measure |
| **E1 event** | new canonical signature `VolOrderCreated(uint256,uint88,uint24,uint16,uint96)` → new topic0. **The versioning discipline is hereby WRITTEN (review F-RC3):** event signatures never mutate in place; a type change mints a NEW signature + topic0; the old signature is marked RETIRED in DATA_CONTRACT.md — here specifically **retired-NEVER-LIVE** (nothing deployed; no dual-topic0 indexing needed, and the contract doc says so). This policy paragraph is copied into DATA_CONTRACT.md as part of V2-02 |
| **`rpc_api/offchain` (Haskell consumer — review F-RC1, BLOCKER omission)** | `lib/VolOrder/Encoding.hs` (`encode_create_order` 3-arg ABI + `pack_vol_order_input` batch word), `Decode.hs` (`unpack_vol_order_storage` 152-bit layout, `decode_create_orders_result`, `decode_order_created` E1 parse), `Rpc.hs`, StochasticOrderGen — ALL re-pin to the v2 layouts/selector/topic0. **Pre-existing defect to fix in the same pass: `Decode.hs` carries the STALE topic0 `0xa8892769` while the live E1 topic0 is `0x6a5dc726…` — proof the off-chain surface rots when omitted from cascades.** Delegated to the rpc_api workstream by issue/handoff with the exact new layouts |
| `PanopticTokenIdSetterLib` (+ task #14) | codomain widens: `(VolOrder) → (PanopticTokenId, positionSize)`; realization per D4 |
| Lens spec (#10) | identity test at ΔQ_v★; `implied_maturity` service; floor-maximality property test (D5) |
| Risk/account layer (#13) | consumes the D5 law + pinned predicate |

## D4 — the ξ⋆ realization (REWRITTEN; review F-SE2, BLOCKER — the mechanism, verified against Panoptic code)

Panoptic **derives** chunk liquidity — there is no per-leg liquidity input:
`getLiquidityChunk` computes `amount = positionSize × optionRatio(leg)` then
`getLiquidityForAmount{0,1}(tickLower, tickUpper, amount)`. Therefore "weights live in
the chunks" was wrong as v1 stated it. The actual mechanism:

**With `optionRatio ≡ 1`, EQUAL leg widths, and `asset = 1`, a single `positionSize`
induces the geometric liquidity ladder EXACTLY:** for asset = 1,
`L = amount1/(√u − √l)` and with equal widths centered at strike ticks t_k,
`√u − √l ∝ 1.0001^(t_k/2)`, so constant per-leg amount gives
`L_{k+1}/L_k = 1.0001^(−Δ/2) = ξ⋆`. **The asset bit flips the exponent's sign**
(asset = 0 → `1.0001^(+t/2)`, the inverse weighting) — so:
- `asset = 1` is a SPEC-LEVEL CONSTANT of the replication mint (token1 = the vega
  numeraire), pinned by a test;
- the tokenId-builder asserts `ratio == 1` explicitly rather than passing values through
  Panoptic's silently-masking `addOptionRatio` (`% 128` — the banned defect class;
  review F-SE9); `validate()`'s `optionRatio(0) > 0` is satisfied;
- **leg-count bound:** a tokenId carries ≤ 4 legs. This increment declares the DOMAIN
  RESTRICTION ι ≤ 4 strikes per order (matching CR-I2 Layer 1's single 4-leg tokenId);
  the general form — a LIST of (tokenId, positionSize) pairs — is recorded as the
  extension and out of scope.

**The sizing rule reconciliation (review F-RC2):** the `#14` spec FILE on disk
(`cr-i2-layer2-mint-sizing-SPEC.md`) still locks the PRE-review mass-share rule
(`size_k = mulDiv(L̄, w_k, Q96)`); the decision OF RECORD is the user-confirmed
POST-review **average density `size_k = L̄·w_k/n_k`** (chosen at the #14 review
checkpoint; the file was never updated before #14 was paused — it is STALE, and updating
it is part of V2-03). The two rules differ per leg by n_k and conserve different
quantities. v2 resolves the roles:
- the **Panoptic-native path** (this spec's mint): ξ⋆ is realized by the INDUCED
  mechanism above — no explicit per-leg sizing enters the tokenId at all; `positionSize`
  is the single scalar from the ΔQ_v★ chain (`ΔM = ΔQ_v★·p_vol(σ̄)` →
  `liquidity_for_vega` → L̄ → positionSize, round DOWN, uint128-guarded with an explicit
  overflow test);
- the **explicit-chunk path** (the lens's ΔQ_v computation, and any non-Panoptic venue):
  uses the average-density rule.
- **The coupling test that makes this one spec:** the induced Panoptic ladder and the
  explicit average-density chunks must agree within pinned rounding — if they do not,
  one of the two realizations is wrong, and the test says which (vary ι holding ΔQ_v★:
  induced-path errors scale with leg count, chain errors scale with scale).

**Mint-time p_vol(σ̄) quote (review F-SE5):** exact-output pattern —
`mint(order, maxCollateral)` REVERTS if `ΔM_req > maxCollateral`; no partial fill.
Validity conditions even at research scope: REVERT on `p_vol = 0`; a staleness/deviation
bound on the quote is part of the mint contract (stub values pinned in the test);
`maxCollateral` is the ONLY user-side bound — quote manipulation is one-sided against
the minter, so tight defaults are the mitigation. The oracle implementation stays a
research-scope stub with the production blocker declared.

## D5 — auto-deleverage (defined here, enforced in #13; semantics PINNED — review F-SE4/F-RC7)

- The law: `ΔQ_v_enforced = min(ΔQ_v★, floor(Q_M/p_risk))`, checked ONLY in the
  division-free form `ΔQ_v·p_risk ≤ Q_M` (`admissible_iff_mul`; its `0 < p_risk`
  hypothesis is now explicit — `p_risk = 0` makes every ΔQ_v admissible and the enforcer
  MUST NOT divide; the division-free predicate is total and MANDATED).
- **Ratchet direction: BURN-ONLY.** Deleveraging never auto-re-levers; restoring ΔQ_v★
  after recovery requires explicit user top-up/re-mint. Rationale: bidirectional
  auto-adjustment invites oscillation churn, keeper griefing, and rounding bleed per
  cycle. (User-visible consequence documented: transient p_risk spikes permanently
  reduce exposure absent a top-up.)
- **Hysteresis:** deleverage triggers only when the shortfall exceeds `ε_h·ΔQ_v` (the
  dust/flicker guard); ε_h is a named parameter whose VALUE is fixed in #13's
  enforcement spec — the law here is parameterized, not silent.
- **Rounding: the burn rounds EXPOSURE DOWN (burns UP)** so the post-action invariant
  holds by construction, consistent with the lens's one-sided ≤ discipline.
- **Interim window (review F-SE6):** until #13 ships the enforcer, positions can sit in
  violation with no enforcement path — DISCLOSED as a known research-scope risk. The
  invariant is made observable NOW: V2-04's lens readout ships with the floor-maximality
  property test `ΔQ_v_e·p_risk ≤ Q_M ∧ ((ΔQ_v_e+1)·p_risk > Q_M ∨ ΔQ_v_e = ΔQ_v★)`, so
  #13 inherits a pinned predicate, not prose.
- Implied maturity readout `t★ = 2·ΔQ_v_enforced/N_σ`: lens service, read-only.

## Increments (TDD; reordered per review)

0. **V2-00 units table (D0)** — written + reviewed first; blocks everything.
1. **V2-01 type + packing**: RED pack/unpack round-trip at 152 + range-check revert;
   mutants: offset collision with WIDTH, mask-not-revert.
2. **V2-02 validation + manager + events**: new selector, 4-word ABI, batch layout with
   the new top-field stance; dirty-≥224 skip + malleability pair tests; MCAL gas
   re-measure; E1 v2 (solc-oracle, new topic0) + the versioning policy paragraph into
   DATA_CONTRACT.md; the rpc_api handoff issue (incl. the stale-topic0 fix).
3. **V2-03 sizing map** (couples #14; updates the stale #14 spec file to the
   average-density decision): the induced-ξ⋆ mechanism (asset=1 pinned, ratios asserted
   1, ι ≤ 4 domain restriction) + the ΔQ_v★→positionSize chain (round-down,
   uint128-guarded, overflow test) + THE COUPLING TEST (induced ladder ≡ explicit
   average-density chunks within pinned rounding) + the one-sided identity
   `lens ΔQ_v ≤ ΔQ_v★`.
4. **V2-04 lens amendments**: `implied_maturity` + the deleverage readout + the
   floor-maximality property test; #10 spec L1/L3 re-pointed at ΔQ_v★.
5. **V2-05 data contract + GAMS issue amendment** (E1 v2 row, ΔQ_v★ scale from D0).

## Non-goals

- The enforcement ACTOR (#13; ε_h value fixed there).
- The p_vol(σ̄) oracle implementation (research stub + declared invariant).
- The recalibration law's σ²-accrual component (cfmm-lean4-spec issue #1).
- The >4-strike list-of-pairs generalization.
- UX wrapper layer.
