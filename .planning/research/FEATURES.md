# Feature Research

**Domain:** Internal-accounting share-issuance vault (VegaAccountMod) — collateral→vega-exposure, exogenous risk price, non-transferable
**Researched:** 2026-07-16
**Confidence:** HIGH (design authority is machine-checked Lean; module conventions are established in the sibling oracle module)

## Scope Anchor

This is a **subsequent-milestone (v3.0)** feature added to an existing Plank/Foundry project. The
research covers ONLY `VegaAccountMod` — a vault where `deposit(collateralAmt)` issues vega-exposure
"shares" at `shares = deposit / p_risk` (floor), with `p_risk = oracle/(1−h)`, `h < 1`, and
`p_risk` **exogenous/settable** in v1.

Three facts constrain every feature call below and are treated as **non-negotiable design authority**
(all machine-checked, no `sorry`, in `../cfmm-wt/lean4-spec/lean/vol_markets/`):

1. **Issuance is the forward map only.** `Flow.deltaShares dQM prisk = dQM / prisk`, floor-rounded on
   the EVM (`RiskDesign.mulX96Down`). Haircut is embedded in the price: `RiskDesign.haircutRiskPrice
   oracle h = oracle/(1−h)`, proven equal to `deposit·(1−h)/oracle` (`issuance_haircut_equiv`) and
   proven `≥ oracle` (`haircutRiskPrice_ge_oracle`) — so it can only *reduce* issuance. The draft
   `price/haircut` formula in `spec/entities/types/risk.md` is **refuted** and must be corrected first.
2. **Admissibility is division-free.** `Flow.deltaShares_admissible_iff` collapses `ΔQ_v ≤ Q_M^Σ/p_risk`
   to the money-side ceiling `ΔQ_M ≤ Q_M^Σ`; `Main.admissible_iff_mul` gives the guard form
   `Δ·p_risk ≤ Q_M^Σ` (no division); `Main.admissible_state_bounds` bounds the state to
   `[Q_v^Σ, Q_v^Σ + Q_M^Σ/p_risk]`.
3. **Three accounting variables are distinct.** `totalDeposits`, `totalShares`, `riskWeightedShares`
   are separate; `Main.discounted_claim_counterexample` refutes conflating the risk-adjusted subtotal
   (`Σ Qvᵢ·dᵢ`) with `totalShares`. In v1 `d ≡ 1` (D2 distance deferred), so `riskWeightedShares`
   equals `totalShares` numerically but is **stored separately** so the layout survives D2 landing.

Every stored field being readable, and every Lean lemma becoming a tolerance-0 fuzz property against a
Solidity reference mock, are the **established conventions** of the sibling `RealizedVolatilityMod`
(see `RealizedVolatilityInterface.plk`, whose "State readers … Without these the module is a black box"
comment is load-bearing precedent, quoted below).

## Feature Landscape

### Table Stakes (Required for a Coherent v1)

Features without which the vault is either economically incoherent or untestable under the
differential-verification discipline.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| `deposit(collateralAmt) -> shares` selector dispatch | The one selector the skeleton declares; the vault's reason to exist | MEDIUM | `shares = mulX96Down(deposit, X96/p_risk)` i.e. floor `deposit/p_risk`. Must mutate the three state vars atomically. Module leaves `PLANK_SKIP` only when this dispatch is **called** green. |
| Floor-rounded issuance (`mulX96Down` / `mulDiv` down) | Never over-issue shares vs collateral | MEDIUM | Backed by `mulX96Down_le` / `mulX96Down_one`. Rounding direction is a correctness invariant, not a nicety — round **down** on issuance. |
| Division-free admissibility guard | Solvency: shares issued never exceed what deposits back | MEDIUM | Guard `Δ·p_risk ≤ Q_M^Σ` (`admissible_iff_mul`). Use 512-bit `mulDiv`/overflow-safe product per `RISK_ALTERNATIVES.md §4`; do **not** form a raw 256-bit product in the guard. |
| Three distinct state variables (`totalDeposits`, `totalShares`, `riskWeightedShares`) | Mandated by Lean; conflation is refuted | LOW (storage), the arithmetic is the deposit path | `d ≡ 1` in v1 ⇒ `riskWeightedShares == totalShares` numerically, but keep the slot so D2 needs no migration. Never derive one by overwriting another. |
| Settable, validated `p_risk` (admin) | `p_risk` is exogenous in v1; must be set before deposits are meaningful | LOW | `setRiskPrice(uint160 p_riskX96)` reverting on `0` (mirror the oracle's `require(dt != 0)` discipline: a silent-zero price would divide-issue garbage). Validated `> 0`. |
| Haircut risk-price pure lib (H1, `h < 1`) | Core economic content: `p_risk = oracle/(1−h)` | MEDIUM | Lives in the pure lib and is fuzz-tested (`issuance_haircut_equiv`, `haircutRiskPrice_ge_oracle`). **Reject `h = 1`** rather than divide by zero. See admin-surface note below for module vs lib placement. |
| State readers for **every** stored field | Differential test cannot pin a quotient down without them | LOW | Readers for `totalDeposits`, `totalShares`, `riskWeightedShares`, `p_risk`, `riskOracleId`, `underlyingMarketId` (and `haircut` if stored). This is the exact `RealizedVolatilityInterface.plk` pattern — see Anti-Feature "event-based observability". |
| `previewDeposit` / `convertToShares` pure view | The sharpest differential surface for the issuance arithmetic in isolation | LOW | Pure `(deposit, p_risk) -> shares` with **no state mutation**. Table stakes *as a differential reader* (analogous to the oracle exposing raw `getTickCumulative` beside the mutating `write`), **not** as ERC-4626 conformance. Lets the fuzz test diff floor-rounding/admissibility without dirtying state. |
| Zero-deposit guard | Degenerate call must match the reference, not silently no-op | LOW | `require(collateralAmt > 0)` and revert. `0/p_risk = 0`; accepting it dirties `totalDeposits += 0` and diverges from a reverting mock. |
| Zero-shares-minted guard | The classic vault value-leak / dust-donation edge | LOW–MEDIUM | With Q64.96 `p_risk`, `mulX96Down(deposit, …)` **floors to 0** for small deposits (`deposit < p_risk/X96`). `require(sharesMinted > 0)` and revert — otherwise collateral is accepted for nothing and `totalDeposits` drifts above `totalShares·p_risk`. This is the well-known ERC-4626 zero-share / first-depositor inflation pitfall; the `mulX96Down` floor lemma characterizes exactly when it triggers. |

### Differentiators (Why This Vault, Not a Generic 4626)

For this project a "differentiator" is what makes the vault worth building over an off-the-shelf pooled
vault — and what the milestone's core value actually is.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Exogenous risk-price issuance with proven conservatism | `p_risk ≥ oracle` ⇒ **provably** never over-issues; price is a governance/oracle input, not an endogenous pool ratio | MEDIUM | This is the core value. It is also *why* the pool-ratio share price is an anti-feature (below). |
| Machine-checked issuance arithmetic (Lean lemma → tolerance-0 fuzz property vs Solidity mock) | Correctness is not aspirational — each property is backed by a proof with no `sorry` | MEDIUM | The differential discipline itself is the deliverable, same as the vol-oracle track. One test file per module, mutation-verified. |
| Division-free admissibility guard (`Δ·p_risk ≤ Q_M^Σ`) | Gas + safety: no on-chain division in the solvency check | LOW–MEDIUM | `admissible_iff_mul`. Needs a 512-bit product helper. |
| Three-variable non-conflated accounting | Layout is D2-ready: `riskWeightedShares` can carry real `d ∈ [0,1]` with zero migration | LOW | The counterexample lemma is the reason; storing the slot now is cheap insurance. |
| Reader-based full observability | The whole state is diffable, so the harness need not mirror Plank's storage-slot derivation in Solidity (avoids a second unverified mirror) | LOW | Direct lift of the oracle interface's stated rationale. |

### Anti-Features (A Normal Vault Has These — This One Must NOT Get Them)

Called out explicitly because the vault's *shape* invites them and each one would break either the model
semantics or the verification discipline.

| Feature | Why Requested | Why Problematic (for THIS vault) | Alternative |
|---------|---------------|----------------------------------|-------------|
| **ERC-20 transferability of shares** | "Shares" look like a token | `exposure.md` is explicit: `VegaExposure` is an **internal accounting layer, not a separately traded token**. Transferability implies a market/price for the shares themselves — out of model. Also removes the only reason per-account balances would be needed. | Keep it internal accounting; no `transfer`/`approve`/`balanceOf`. |
| **ERC-4626 conformance** | The deposit→shares shape matches 4626 exactly | 4626 *mandates* withdraw/redeem (no Lean oracle, deferred), *mandates* ERC-20 shares (anti-feature above), assumes native events (not native here), and its `convertToShares` uses a `totalAssets/totalSupply` **pool ratio** — the **wrong** share-price semantics for an exogenous-`p_risk` vault. | Borrow only the *idea* of a pure `previewDeposit`/`convertToShares` view (table stakes above); reject the interface + events + ERC-20 dependency. |
| **Pro-rata pool-ratio share price** (`shares = deposit·totalSupply/totalAssets`) | It's how every pooled vault prices shares | Contradicts the Lean issuance map (`deposit/p_risk`) and reintroduces the first-depositor inflation attack that the exogenous price avoids. | Keep exogenous `p_risk`. The zero-share guard already handles the dust edge. |
| **Per-address share ledger / balances mapping** | Vaults usually track who owns what | No design-authority backing — every Lean quantity is an **aggregate Σ** (`Q_M^Σ`, `Q_v^Σ`). The skeleton's singular `SLOT_COLLATERAL`/`SLOT_VEGA_EXPOSURE` (pooled) is correct for v1. A mapping adds a storage-slot-derivation the Solidity harness must mirror — the exact unverified second mirror the oracle interface warns against — and there is no withdraw to *need* per-account claims. | Pooled totals suffice for the differential goal. Per-account becomes a **dependency of redemption** (v2), not v1. |
| **Event / log emission (`@evm_log`)** for observability | "A vault should emit Deposit events" | The codebase convention (oracle module) is **reader-based observability**; there are no events. Events add an untested surface and are not how this harness observes state. | State readers for every field + `deposit` returning `sharesMinted`. If log observability is ever needed, that's `@evm_log` opcodes — deferred. |
| **On-chain oracle wiring / `p_vol(σ̄)` computation** | The vault "should" read live volatility | Explicitly deferred: `tbd.md` states `p_risk` is exogenous; the vol→price coordinate needs pos_spec types that still have 5 red harness tests. | Store `riskOracleId` (identifier only) for future wiring; keep `p_risk` settable. |
| **D2 distance weighting / real `d ∈ [0,1]`** | `riskWeightedShares` "should" reflect price risk | Deferred; `d ≡ 1` in v1. Building D2 (clipped-linear, `p_vol` dependency) now is scope creep. | Keep the `riskWeightedShares` slot with `d ≡ 1`; land D2 later with no migration. |
| **Multi-collateral / multi-oracle routing** | The struct carries `collateralToken`/`underlyingToken`/`riskOracleId` | v1 is single-market pooled; routing logic is untested surface. | Store the IDs; add routing when a second market exists. |

### Admin Surface — Recommended Shape (design decision, MEDIUM confidence)

The milestone question asks about *"set p_risk, set haircut"*. Because `p_risk` is exogenous **and**
oracle wiring is deferred, the cleanest coherent v1 is:

- **`setRiskPrice(uint160 p_riskX96)`** — validated `> 0`, reverts on `0`. This is the module's live
  price source in v1 (exogenous). **Table stakes.**
- **`previewRiskPrice(oracle, hX96)` pure view** computing `oracle/(1−h)` with `h < 1` enforced —
  exposes the H1 lemma path so it is *reachable and diffable on-chain* against the Solidity mock,
  **without** the module needing a live oracle slot. Recommended so `haircutRiskPrice_ge_oracle` /
  `issuance_haircut_equiv` are exercised through a called selector, not only a lib unit test.
- **Defer** a stateful `setHaircut` that recomputes stored `p_risk = oracle/(1−h)`: with no live oracle
  a stored `h` is inert, and it adds a second setter to keep consistent. Fold the haircut into the
  exogenous `p_risk` off-chain in v1; wire `setHaircut` when the oracle lands.

Rationale: keeps exactly one authoritative on-chain price input (`setRiskPrice`), while the proven H1
arithmetic is still both tested (lib fuzz property) and callable (`previewRiskPrice`).

## Feature Dependencies

```
deposit(collateralAmt)
    ├──requires──> floor issuance lib (mulX96Down / mulDiv-down)
    ├──requires──> settable validated p_risk (setRiskPrice)
    ├──requires──> division-free admissibility guard (Δ·p_risk ≤ Q_M^Σ)
    │                  └──requires──> totalDeposits (Q_M^Σ) tracking
    ├──requires──> three state vars (totalDeposits, totalShares, riskWeightedShares)
    ├──requires──> zero-deposit guard
    └──requires──> zero-shares-minted guard  (consequence of floor rounding)

previewDeposit / convertToShares ──requires──> floor issuance lib + p_risk reader   (pure, no mutation)

previewRiskPrice (H1) ──requires──> h<1 enforcement                                  (pure)

state readers ──requires──> the fields they read already exist

--- deferred, shown for ordering ---
withdraw / redeem ──requires──> per-account ledger  AND  a redemption Lean lemma (does NOT exist yet)
per-account ledger ──enables──> withdraw/redeem
D2 distance (real d) ──requires──> p_vol(σ̄) from pos_spec (5 red tests)  AND  oracle wiring
endogenous p_risk ──requires──> RealizedVolatilityMod wiring  (conflicts with "exogenous p_risk" v1 decision)
```

### Dependency Notes

- **`deposit` requires the floor issuance lib and admissibility guard:** these ARE the deposit path;
  they cannot be stubbed and still call green.
- **Zero-shares-minted guard is a *consequence* of floor rounding, not an add-on:** it only exists
  because `mulX96Down` floors — so it must ship in the same phase as issuance.
- **`previewDeposit` is a pure sibling of `deposit`:** it depends on the same lib but must not touch
  state, which is precisely what makes it the clean differential surface.
- **Withdraw/redeem is correctly deferred because it has no design-authority oracle.** `Flow.lean` and
  `RiskDesign.lean` formalize ONLY the forward `(ΔQ_M, p_risk) → ΔQ_v` map and its admissibility;
  there is **no** redemption lemma. Building redeem now would be unverified against Lean, contradicting
  the "every lemma → a fuzz property" discipline. See the coherence assessment below.
- **Per-account ledger is a dependency of redemption, not of v1:** deposit-only + pooled + non-transferable
  means there is no per-account claim to resolve yet.

## Deposit-Only Coherence Assessment (honest)

**Verdict: deposit-only is coherent for the differential-testing goal, and withdraw/redeem is correctly
deferred.**

What **remains verifiable** deposit-only (all backed by Lean, all diffable vs the Solidity mock):
- Issuance floor: `sharesMinted ≤ exact deposit/p_risk` (`mulX96Down_le`), exactness at `d=1`/weight-one
  (`mulX96Down_one`).
- Monotonicity of issuance in deposit (`deltaShares_mono`) and non-negativity (`deltaShares_nonneg`).
- Admissibility equivalence `Δ·p_risk ≤ Q_M^Σ ⇔ ΔQ_M ≤ Q_M^Σ` (`admissible_iff_mul`,
  `deltaShares_admissible_iff`).
- **Solvency / no over-issuance**: state stays in `[Q_v^Σ, Q_v^Σ + Q_M^Σ/p_risk]`
  (`admissible_state_bounds`) — i.e. `totalShares·p_risk ≤ totalDeposits` never breaks. This is the
  invariant one would most fear losing, and it is fully testable on the deposit path.
- Haircut conservatism `p_risk ≥ oracle` (`haircutRiskPrice_ge_oracle`) and equivalence
  (`issuance_haircut_equiv`).
- The three-variable non-conflation (`discounted_claim_counterexample`) — a storage-layout invariant,
  independent of redemption.

What becomes **unverifiable without redemption** (and why it is acceptable to defer):
- **Round-trip conservation** ("deposit then redeem returns ≤ original collateral; no value created on
  the way out"). This genuinely cannot be exercised deposit-only. **But** there is no redemption lemma
  in the Lean corpus to diff it against, so it is not a regression — it is simply out of the proven
  scope this milestone. Adding redeem would *create* an untested surface, not close one.
- **Burn-side floor direction** (redeem should round *collateral out* down). No lemma; deferred with redeem.

**`previewDeposit`/`convertToShares` equivalent is table stakes** — but as a *differential reader*, not
as ERC-4626. A pure view that returns `shares` for `(deposit, p_risk)` with no side effects is the
sharpest way to diff the issuance arithmetic (floor + admissibility) in isolation, exactly as the oracle
module exposes raw `getTickCumulative` beside the mutating `write` path. Ship it; skip the rest of 4626.

## Zero / Edge Semantics (decision table)

| Case | Arithmetic | Recommended policy | Why |
|------|-----------|--------------------|-----|
| Zero deposit (`ΔQ_M = 0`) | `0/p_risk = 0`; guard `0 ≤ Q_M^Σ` trivially holds | **Revert** `require(collateralAmt > 0)` | Degenerate no-op; silently writing `totalDeposits += 0` diverges from a reverting mock and matches the oracle's `require(dt != 0)` discipline. |
| Nonzero deposit, shares floor to 0 (`deposit < p_risk/X96`) | `mulX96Down(deposit, …) = 0` | **Revert** `require(sharesMinted > 0)` | The ERC-4626 zero-share / dust-donation value-leak: collateral accepted for nothing, `totalDeposits` drifts above `totalShares·p_risk`. The floor lemma says exactly when this bites. |
| `p_risk` unset / `0` at deposit time | division by zero / garbage | **Revert** at `setRiskPrice` (never accept `0`) and at deposit if `p_risk == 0` | Same silent-zero hazard the oracle guards against for `WINDOW`/`dt`. |
| `h = 1` in `previewRiskPrice` | `oracle/(1−1)` = /0 | **Revert** `require(h < X96)` | `haircutRiskPrice` requires `h < 1`; reject rather than divide by zero. |
| Admissibility boundary hit (`Δ·p_risk == Q_M^Σ`) | equality is admissible | **Accept** (`≤`, not `<`) | `admissible_iff_mul` uses `≤`; the boundary is in-region. |

## MVP Definition

### Launch With (v3.0)

- [ ] `deposit(collateralAmt) -> sharesMinted` dispatch — floor issuance `deposit/p_risk`, mutates the
      three state vars, **called green** (the `PLANK_SKIP` exit criterion)
- [ ] Floor-rounded issuance lib (`mulX96Down`) + division-free admissibility guard (512-bit product)
- [ ] Three distinct state vars (`totalDeposits`, `totalShares`, `riskWeightedShares`, `d ≡ 1`)
- [ ] `setRiskPrice(p_riskX96)` validated `> 0`
- [ ] H1 haircut-risk-price pure lib (`h < 1`) + `previewRiskPrice` view exposing it on-chain
- [ ] `previewDeposit`/`convertToShares` pure differential view
- [ ] State readers for every stored field
- [ ] Zero-deposit and zero-shares-minted guards (both revert)
- [ ] Correct `spec/entities/types/risk.md` (kill `price/haircut`, adopt `oracle/(1−h)`) and complete
      the 5-field `VegaExposure` type — a documentation/type prerequisite of the above
- [ ] Each Lean lemma → one tolerance-0, mutation-verified fuzz property vs a Solidity reference mock

### Add After Validation (v3.x)

- [ ] `setHaircut` + settable oracle-placeholder recomputing stored `p_risk` — trigger: oracle wiring lands
- [ ] D2 clipped-linear distance so `riskWeightedShares` carries real `d ∈ [0,1]` — trigger: `p_vol(σ̄)`
      pos_spec types go green

### Future Consideration (v4+)

- [ ] `withdraw`/`redeem` — **defer until a redemption Lean lemma exists**; it also pulls in the
      per-account ledger and burn-side rounding
- [ ] Per-account share ledger — only once redemption needs it
- [ ] Endogenous `p_risk` from `RealizedVolatilityMod` (P0/P2 composition: `max(spot,TWAP)`, premium)
- [ ] External ERC-4626-style adapter — only if external composability is ever a requirement (keep the
      core internal-accounting module unchanged behind it)

## Feature Prioritization Matrix

| Feature | User (caller) Value | Implementation Cost | Priority |
|---------|---------------------|---------------------|----------|
| `deposit` + floor issuance + admissibility guard | HIGH | MEDIUM | P1 |
| Three distinct state vars | HIGH (correctness) | LOW | P1 |
| `setRiskPrice` validated | HIGH | LOW | P1 |
| H1 haircut lib + `previewRiskPrice` | HIGH | MEDIUM | P1 |
| State readers (every field) | HIGH (testability) | LOW | P1 |
| `previewDeposit`/`convertToShares` view | HIGH (differential surface) | LOW | P1 |
| Zero-deposit / zero-shares guards | HIGH (safety) | LOW | P1 |
| `setHaircut` + oracle-placeholder | MEDIUM | MEDIUM | P2 |
| D2 distance weighting | MEDIUM | HIGH | P2 |
| `withdraw`/`redeem` + per-account ledger | HIGH (eventually) | HIGH (needs new proofs) | P3 |
| Endogenous `p_risk` (P0/P2) | MEDIUM | HIGH | P3 |
| ERC-20 shares / ERC-4626 conformance | (anti-feature) | — | NONE |

**Priority key:** P1 = must have for v3.0; P2 = add when its dependency unblocks; P3 = future.

## Reference / Precedent Analysis

| Concern | Generic vault (ERC-4626) | THIS vault (VegaAccountMod) |
|---------|--------------------------|----------------------------|
| Share price | Endogenous `totalAssets/totalSupply` pool ratio | Exogenous `p_risk = oracle/(1−h)`, settable |
| Share token | ERC-20, transferable | Internal accounting, non-transferable |
| Withdraw/redeem | Mandatory | Deferred (no redemption lemma) |
| Accounting | `totalAssets`, `totalSupply` (two) | `totalDeposits`, `totalShares`, `riskWeightedShares` (three, non-conflated) |
| Observability | Events (`Deposit`/`Withdraw`) | State readers (no native events) |
| Ledger | Per-account `balanceOf` | Pooled totals |
| Zero-share deposit | Known inflation/dust pitfall (often mitigated with virtual shares) | **Revert** (guard); exogenous price sidesteps the ratio-inflation vector |

## Sources

- Design authority (machine-checked Lean, no `sorry`): `../cfmm-wt/lean4-spec/lean/vol_markets/RiskDesign.lean`,
  `Flow.lean`, `Main.lean` — `mulX96Down_le/one`, `haircutRiskPrice_ge_oracle`, `issuance_haircut_equiv`,
  `deltaShares_admissible_iff`, `admissible_iff_mul`, `admissible_state_bounds`,
  `discounted_claim_counterexample`, `discounted_eq_total_iff_pos` — **HIGH**
- EVM design notes: `../cfmm-wt/lean4-spec/model/vol_markets/RISK_ALTERNATIVES.md`, `risk.md`, `exposure.md`,
  `tbd.md` — **HIGH**
- Project spec: `spec/entities/types/exposure.md`, `spec/model/tbd.md`, `.planning/PROJECT.md` — **HIGH**
- Module/convention precedent: `src/modules/market_state_measurements/RealizedVolatilityMod.plk` and
  `src/interfaces/market_state_measurements/RealizedVolatilityInterface.plk` (reader-based observability;
  "state readers … Without these the module is a black box"; silent-zero guards) — **HIGH**
- Skeleton under study: `src/modules/exposure/VegaAccountMod.plk` (singular `SLOT_COLLATERAL`/
  `SLOT_VEGA_EXPOSURE`, `deposit` selector only) — **HIGH**
- ERC-4626 zero-share / first-depositor inflation pitfall: established EVM-security knowledge (training),
  used only to justify the zero-shares-minted guard — **MEDIUM** (not re-verified against a live source;
  the guard is independently mandated by the `mulX96Down` floor lemma)

---
*Feature research for: internal-accounting vega-exposure vault (VegaAccountMod, v3.0)*
*Researched: 2026-07-16*
