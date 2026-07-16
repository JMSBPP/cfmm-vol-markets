# Pitfalls Research

**Domain:** Collateral→vega-exposure share-issuance vault (internal accounting, exogenous risk price, deposit-only) added to an existing Plank/Foundry system
**Researched:** 2026-07-16
**Confidence:** HIGH — grounded in the machine-checked Lean (`RiskDesign.lean`, `Flow.lean`, no `sorry`), the repo's own catalogued failure modes (`.planning/STATE.md` Accumulated Context), and `RISK_ALTERNATIVES.md`. MEDIUM only where a pitfall concerns the deferred v2 withdraw surface.

> Framing note for reviewers: several famous vault attacks **do not apply** to this design. Each is worked through below and marked **N/A (with reason)** so a future reviewer does not re-litigate it. The immunity is *structural* (exogenous rate, internal counters, no transfers, no withdraw) — the pitfalls that remain are (a) silently breaking that structure and (b) the Plank-specific arithmetic/testing traps this repo has already paid for once.

---

## Critical Pitfalls

### Pitfall 1: Implementing the REFUTED `price/haircut` formula from the stale spec

**What goes wrong:**
`spec/entities/types/risk.md` still encodes `factor = haircut/price` and `collateralAmt * (self.price/haircut)`. This formula is **refuted** by the Lean: it is singular at `h=0` and has *inverted monotonicity* (value grows as the haircut shrinks). Building from the spec instead of the Lean ships the wrong economics that still compiles and runs.

**Why it happens:**
The spec file is the natural starting point for a `.plk` implementer; the correct authority lives in a different worktree (`../cfmm-wt/lean4-spec`). PROJECT.md names correcting `risk.md` as the *first* deliverable precisely to close this gap.

**How to avoid:**
Correct `risk.md` FIRST (kill `price/haircut`; adopt `p_risk = oracle/(1-h)` per `haircutRiskPrice` and `issuance_haircut_equiv`) before any `.plk` arithmetic is written. Then encode the fuzz property `haircutRiskPrice_ge_oracle`: **`p_risk >= oracle`** for all `0 ≤ h < 1`. The refuted formula *fails* this property — it is the discriminating falsifier.

**Warning signs:**
Any code (or test reference mock) computing `price / haircut`, `collateralAmt * (price/haircut)`, or a `p_risk` that can fall *below* `oracle`.

**Phase to address:** Spec-correction phase (first phase of the milestone).

---

### Pitfall 2: Silent-zero division when `p_risk` is unset (default-0 storage slot)

**What goes wrong:**
`p_risk` is exogenous/settable and lives in storage. **Plank storage reads default to 0**, and on the EVM/Plank `x / 0 == 0` returns **silently** — this repo already catalogued exactly this class as the `dt=0` divergence and the "silent-zero FFI" concern. A vault deployed but never `set`-configured (or set to 0) computes `shares = mulDiv(deposit, 2^96, 0) = 0`: it **banks the collateral and mints zero shares**, with no revert.

**Why it happens:**
Developers assume the setter always runs before the first deposit and forget that the *uninitialized slot* is a reachable state, and that division-by-zero is not a trap on this stack.

**How to avoid:**
Defense in depth: (1) setter validates `p_risk > 0`; (2) `deposit` asserts `p_risk != 0` and **reverts** before dividing (an uninitialized slot precedes any setter call). The guard must be a CHECKED comparison that reverts, must be **reached from `run{}`** (see Pitfall 11), and must use `@evm_iszero`/`@evm_eq` — not `@evm_not` (see Pitfall 13).

**Warning signs:**
A deposit that increments `totalDeposits` but leaves `totalShares` unchanged; any test that only checks the *return value* and not the state.

**Concrete assertion:** Deploy a fresh module with the `p_risk` slot never written → `deposit` **reverts**. Assert the **state** (`totalDeposits` unchanged), not just that "nothing useful returned" — a silent-0 mint and a revert both look empty from the return alone (repo lesson: *assert the state, not the quotient*).

**Phase to address:** Risk-price/library phase (setter + deposit guard).

---

### Pitfall 3: `h→1` blowup — non-strict `hX96` validation admits division-by-zero

**What goes wrong:**
`p_risk = mulDiv(oracle, 2^96, 2^96 - hX96)`. At `hX96 = 2^96` (h=1) the denominator is 0 → `p_risk` silently computes to 0 → then `shares = mulDiv(deposit, 2^96, 0) = 0` (a *second* silent-zero). For `hX96` just below `2^96`, `p_risk` explodes and `shares` floors to 0 for ordinary deposits. Either way the depositor's collateral is captured for a zero claim. Lean requires `h < 1` **strictly** (`haircutRiskPrice` is undefined at `h=1`; "Reject `h=1` rather than dividing by zero").

**Why it happens:**
An off-by-one in the bound (`hX96 <= 2^96` instead of `< 2^96`) admits equality; or the check is written with the wrong operator / on a dead path.

**How to avoid:**
Enforce `hX96 < 2^96` **strictly** with a reverting checked comparison. Do NOT lean on the bare revert of the checked subtraction `2^96 - hX96` to catch `h>1` (that gives no reason and — repo lesson — a checked op reverting on an unintended path already bit the oracle); validate explicitly first, *then* the subtraction is provably safe.

**Warning signs:**
`hX96 <= 2^96` in the guard; a deposit returning 0 shares for a valid deposit amount.

**Concrete assertion / corpus:** Constructed corpus (NOT `vm.assume`, see Pitfall 14) with `hX96 ∈ {2^96, 2^96+1, 2^256-1}` → all **revert**; `hX96 = 2^96 - 1` with a large deposit → `shares > 0`. Mutation: relax `<` to `<=` must be **killed** by the `hX96 = 2^96` case.

**Phase to address:** Risk-price/library phase.

---

### Pitfall 4: Rounding direction reversed — over-issuance of unbacked shares

**What goes wrong:**
Two roundings compose and BOTH must push shares **down**:
- **Issuance floors:** `shares = mulDiv(deposit, 2^96, p_risk)` rounded **down**. Lean `mulX96Down` rounds down and `mulX96Down_le` proves `result ≤ amount` — the vault issues *no more* shares than the exact real value. Ceiling here would mint MORE shares than the deposit backs → dilution / unbacked claims.
- **Risk price rounds UP:** `p_risk = mulDiv(oracle, 2^96, 2^96 - hX96)` rounded **up**. `p_risk` is a *divisor* of the deposit, so a *larger* `p_risk` yields *fewer* shares (conservative). `RISK_ALTERNATIVES.md` §1/§4 is explicit: "Rounding the penalty upward makes the resulting weight conservative … `mulDiv(…, Up)`". Rounding `p_risk` down makes the divisor smaller → over-issuance.

Getting either backwards over-issues. In deposit-only v1 the over-issuance is latent (no withdraw to drain), but it corrupts `totalShares`/`riskWeightedShares` accounting integrity immediately and becomes a direct theft vector the moment withdraw ships.

**Why it happens:**
`mulDiv` default rounding is floor; the `p_risk` computation is the one place that must opt into ceiling, and it is easy to leave at the default. Attacker gains: shares whose backing (`shares * p_risk`) exceeds the deposit posted.

**How to avoid:**
Encode the floor invariant as a reconstruct-and-check property and the Lean monotonicity lemma as a fuzz property:
- **`shares * p_risk <= deposit * 2^96`** (issued shares are always backed; this is the `mulX96Down` floor guarantee). Compute the product with a 512-bit `mulDiv`/`fullMulDiv`, NOT a raw `*` (see Pitfall 7).
- **`p_risk >= oracle`** (`haircutRiskPrice_ge_oracle`) and the ceil invariant `p_risk * (2^96 - hX96) >= oracle * 2^96`.

**Warning signs:**
`mulDiv(oracle, 2^96, 2^96 - hX96)` without an explicit `Up`/round-up flag; any test asserting only `shares == mock(shares)` where the mock uses the same rounding (see Pitfall 15).

**Concrete assertion:** Differential vs a higher-precision (rational / 512-bit) reference asserting `shares == floor(exact)` AND `shares` never exceeds it, plus the two invariants above. Mutation: flip issuance to ceil, and flip `p_risk` to floor — each must be **killed**.

**Phase to address:** Issuance-library phase.

---

### Pitfall 5: Overflow in the admissibility guard — use the collapsed money-side ceiling, not a cross-product

**What goes wrong:**
The admissibility bound is `ΔQ_v ≤ Q_M^Σ / p_risk`. Implementing it as a cross-multiplication (`dQM * p_risk`, or reconstructing `shares * p_risk`) risks exceeding `2^256`: `deposit * 2^96` overflows for `deposit ≳ 2^160`. In Plank this splits into two failure modes:
- **Wrapping `*%`** → the product wraps below the bound → **guard bypassed** (attacker sizes `deposit` so the product wraps small) → admissibility check passes falsely.
- **Checked `*`** → **reverts on large-but-valid deposits** → denial of service. This is the same checked-vs-wrapping class that already reverted a valid downward path in the oracle.

**Why it happens:**
The "obvious" implementation of `ΔQ_v ≤ Q_M^Σ/p_risk` is a cross-multiply, and raw 256-bit products are assumed safe.

**How to avoid:**
Use the **collapsed, division-free guard** the Lean provides: `deltaShares_admissible_iff` proves `ΔQ_v ≤ Q_M^Σ/p_risk ↔ ΔQ_M ≤ Q_M^Σ`. Implement the money-side ceiling **`deposit ≤ totalMoney`** — no product at all. This is the entire point of the lemma. Where a reconstruct-and-check (Pitfall 4) is unavoidable, use a 512-bit `mulDiv` (`RISK_ALTERNATIVES.md` §4: "Avoid raw 256-bit products in guards: use a 512-bit `mulDiv` routine or a division-based overflow-safe equivalent").

**Warning signs:**
Any `dQM * p_risk` or `deposit * 2^96` computed with a bare `*` or `*%` in a guard; a guard expressed as a product rather than the `deposit ≤ totalMoney` comparison.

**Concrete assertion / corpus:** Constructed corpus placing `deposit` in the overflow regime (`deposit ≈ 2^200`); assert the guard equals `deposit ≤ totalMoney` and matches `deltaShares_admissible_iff` at the boundary `deposit == totalMoney`. Mutation: replace the collapsed guard with a raw cross-product → **killed** by the overflow-regime corpus (clear `cache/fuzz` first — Pitfall 16 — or the kill is a replay).

**Phase to address:** Admissibility-guard phase.

---

### Pitfall 6: Decimals / quote-direction / sqrt-price unit mismatch (compiles, runs, mis-issues by orders of magnitude)

**What goes wrong:**
`deposit` is in collateral-token units; `p_risk` is Q64.96. `shares = mulDiv(deposit, 2^96, p_risk)` is dimensionally correct ONLY if `p_risk` quotes *collateral per vega-unit* and the collateral decimals are what the encoding assumes. An inverted quote direction, a 6-dec vs 18-dec collateral mismatch, or feeding a `sqrtPriceX96` where a linear `priceX96` is expected all produce silently-wrong share counts. PROJECT.md's constraints flag "fixed-point rigor … to avoid dimensional bugs" as a first-class concern; `RISK_ALTERNATIVES.md` §2 requires "common decimals/base, common quote direction" and §1 D3/§2 warns "do not mix a spot price with a square-root price." The repo swims in `sqrtPriceX96` (Uniswap), so the sqrt confusion is live.

**Why it happens:**
Units are invisible to the compiler; a reference mock built from the same (wrong) unit assumption agrees with the contract while both are wrong (compensating error, Pitfall 15).

**How to avoid:**
Pin the quote convention and decimals normalization in the corrected `risk.md` (which token is base, which is quote, linear vs sqrt). Test with an **external anchor** — a hand-computed expected `shares` in explicit units (e.g. 6-dec collateral, a named `p_risk`), computed independently 3× (the 08-02 anchor pattern). A differential test ALONE cannot catch a shared unit assumption; the anchor pins a value neither implementation influences.

**Warning signs:**
`p_risk` typed/stored as `uint160 sqrtPriceX96`; share counts off by ~`10^12` (a 6↔18 decimal gap) or that look like a square root of the expected value.

**Phase to address:** Spec-correction phase (convention) + issuance-library phase (anchor test).

---

### Pitfall 7: Conflating the three state variables (`totalDeposits` / `totalShares` / `riskWeightedShares`)

**What goes wrong:**
Lean `discounted_claim_counterexample` refutes treating the risk-adjusted subtotal (`Σ Qvᵢ dᵢ`) as the accounting total (`Σ Qvᵢ`). Storing `riskWeightedShares` in the same slot as `totalShares`, or deriving one by overwriting the other, silently loses the accounting total the moment `d ≠ 1`. In v1 `d ≡ 1` so they coincide numerically — which is exactly why a slot-aliasing bug hides here and detonates when D2 lands.

**Why it happens:**
With `d ≡ 1` the three counters move in lockstep, so aliasing two of them looks harmless in every v1 test.

**How to avoid:**
Three **distinct storage slots**, updated independently: `totalDeposits` (collateral, from the accounted transfer), `totalShares` (`Σ Qvᵢ`), `riskWeightedShares` (`Σ Qvᵢ dᵢ`, `d ≡ 1` scaffold). `RISK_ALTERNATIVES.md` §5: "Keep both state variables or derive the former without overwriting the latter."

**Warning signs:**
Two of the three reading the same `SLOT_*` constant; `riskWeightedShares` computed as an alias of `totalShares`.

**Concrete assertion:** After a deposit, assert all three moved by the expected independent amounts (`totalDeposits += collateral`, `totalShares += shares`, `riskWeightedShares += shares` while `d≡1`), each read from its own slot. Mutation: alias `SLOT_RISK_WEIGHTED` to `SLOT_VEGA_EXPOSURE`/`totalShares` → **killed** by a test that writes one and reads the other independently.

**Phase to address:** Module state-layout phase.

---

## Famous vault attacks that DO NOT apply here (worked through — do not re-litigate)

### N/A-1: First-depositor / share-price inflation attack — **N/A (exogenous rate)**

**The classic attack:** For non-first deposits ERC-4626 mints `deposit * totalShares / totalAssets`. Attacker mints 1 wei-share (`totalShares=1, totalAssets=1`), then *donates* `X` assets directly (`totalAssets=1+X`), so a victim depositing `D ≤ X` gets `D*1/(1+X)` floored to **0 shares** and the attacker's single share absorbs the pool. **Root cause: the conversion rate is pool-derived (`totalAssets/totalShares`) and manipulable.**

**Why it does not apply here:** `shares = mulDiv(deposit, 2^96, p_risk)` and `p_risk` is **exogenous** (settable, validated `> 0`), NOT `totalAssets/totalShares`. The rate reads *no pool state*. A second depositor with the same `deposit` and same `p_risk` mints **identical** shares regardless of pool history or any donation. Two independent reasons defeat the attack: (1) exogenous rate; (2) accounting uses internal counters, not `balanceOf` (see N/A-2).

**The residual (real) risk — and it is forward-looking:** This immunity holds ONLY while issuance never reads `totalShares`/`totalDeposits`/`balanceOf`. If the deferred **v2 withdraw** pays out `totalDeposits * shares / totalShares`, the *withdraw* side becomes pool-derived and first-depositor/donation rounding re-enters. **Flag for the v2 withdraw phase.** In v1, lock the immunity with an invariant test.

**Concrete assertion:** Depositing amount `A` at `totalDeposits = 0` and at `totalDeposits = 2^128` (same `p_risk`) yields **identical** `shares`. Any mutant that makes issuance read a pool counter → **killed**.

---

### N/A-2: Donation / inflation via direct `transfer` — **N/A (internal counters, no `balanceOf`)**

**The classic attack:** Send tokens straight to the vault to inflate `totalAssets = balanceOf(this)` and skew the rate.

**Why it does not apply here:** `totalDeposits` is an **internal counter** incremented from the accounted deposit, not `balanceOf(collateralToken, this)`; and the mint math reads no balances at all. A raw transfer to the contract moves no accounting variable and cannot change any depositor's shares. Additionally, v1 is **deposit-only** — there is no withdraw payout path for a hypothetical desync to drain.

**The residual (real) risk:** This holds ONLY if `deposit` takes its amount from the accounted transfer (the passed `collateralAmt` reconciled against an actual `transferFrom`), and NEVER from `balanceOf` deltas. If a future refactor computes the deposit amount as `balanceOf(this) - lastBalance`, donation desync returns.

**Concrete assertion:** Raw-`transfer` collateral to the vault, THEN `deposit(A)` → `shares` unchanged vs the no-donation case and `totalDeposits` reflects only the accounted deposit.

---

### N/A-3: Share-transfer / approval / re-entrancy griefing — **N/A (non-transferable, not ERC-20/4626)**

**Why it does not apply here:** Shares are internal accounting, **not transferable**, not ERC-20/4626. There is no `transfer`/`approve`/`transferFrom` on shares, so no approval front-running, no ERC-777/4626 re-entrancy on share hooks, no share-market manipulation. Do not spend effort adding ERC-4626 `maxDeposit`/`previewDeposit` conformance or re-entrancy guards *on the share side* — there is no external share surface. (Ordinary re-entrancy discipline on the *collateral* `transferFrom` still applies as standard hygiene, but with deposit-only, single-slot accounting and no external calls after state writes, the surface is minimal.)

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Leave `p_risk` guard only in the setter, skip the `deposit`-time `!= 0` check | Less code | Default-0 slot precedes first setter call → silent-zero mint of a fresh deploy (Pitfall 2) | **Never** — the uninitialized state is reachable |
| `d ≡ 1` scaffold stored by aliasing `riskWeightedShares` onto `totalShares` | One fewer slot | Silent accounting loss when D2 lands; refuted by `discounted_claim_counterexample` (Pitfall 7) | **Never** — three distinct slots from day one |
| Cross-multiply admissibility (`dQM * p_risk`) instead of the collapsed `deposit ≤ totalMoney` | Mirrors the textbook inequality | Overflow → guard bypass or DoS (Pitfall 5); ignores `deltaShares_admissible_iff` | **Never** — the collapse is proven and cheaper |
| Trust `make compile` / `make compile-plank` green as "done" | Fast signal | Plank does not type-check code unreachable from `run{}`; dead module compiles green (Pitfall 11) | **Never** for the deposit path — it must be CALLED green |
| Reuse the stale `risk.md` `price/haircut` formula "for now" | No spec work upfront | Ships refuted economics (Pitfall 1) | **Never** — spec correction is the first deliverable |
| Reference mock built from the same unit assumptions as the contract, no external anchor | Differential test passes easily | Compensating unit errors cancel (Pitfalls 6, 15) | **Never** for the unit/decimals axis — anchor required |

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| Plank FFI deploy (`deployPlank` → `plankDeployFFI`) | Deploying the vault test from a prebuilt `build/plank/*.hex` artifact → a mutant never reaches deployed bytecode → kills are fiction (09-01 caveat) | Deploy via `deployPlank`, which shells `plank build … --backend sona` over FFI at test time and recompiles the `.plk` fresh each run; no `make compile-plank` needed between mutants |
| Exogenous `p_risk` vs the deferred oracle | Wiring `RealizedVolatilityMod` / `p_vol(σ̄)` now, pulling in the pos_spec vol-type layer that still has **5 red harness tests** | Keep `p_risk` exogenous/settable this milestone (PROJECT.md decision); oracle composition (P0/P2) is deferred |
| `VegaExposure` packed struct (`uint128 exposure, uint160 priceVolX96, …`) | Trusting field offsets from the doc; sign-extending a narrow field on unpack | Verify offsets by **reading** the type layout (the `Timepoint.plk` lesson: offsets verified by reading, not from a doc); all price/haircut fields are **unsigned** — no sign-extension |

## Performance Traps

Not a scale-driven domain (internal accounting, no external share market, single depositor path). The "traps" here are correctness cliffs at specific *input magnitudes*, not user counts.

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Raw 256-bit product in guard/reconstruct-check | Guard passes falsely (`*%` wraps) or valid deposit reverts (`*` checked) | Collapsed `deposit ≤ totalMoney` guard; 512-bit `mulDiv` for any product | `deposit ≳ 2^160` (so `deposit * 2^96 ≥ 2^256`) |
| `p_risk` near-blowup (`hX96 → 2^96`) | Ordinary deposits floor to 0 shares | Strict `hX96 < 2^96`; consider a governance upper bound on `hX96` | `hX96` within a few ULPs of `2^96` |

## Security Mistakes

| Mistake | Risk | Prevention |
|---------|------|------------|
| Silent-zero division on unset/zero `p_risk` | Collateral banked for zero claim (Pitfall 2) | Revert on `p_risk == 0` at deposit time; setter validates `> 0` |
| Non-strict `hX96` bound | Division-by-zero → silent-zero mint (Pitfall 3) | Strict `<` with reverting checked compare |
| Rounding favoring the depositor | Unbacked shares → theft vector once withdraw exists (Pitfall 4) | Floor issuance, ceil `p_risk`; assert `shares * p_risk ≤ deposit * 2^96` |
| Guard using `@evm_not` (bitwise) as logical-not | Guard never fires (repo-catalogued: "a guard that never fired") | `@evm_iszero` / explicit `@evm_lt`/`@evm_eq`; mutation-prove each guard fires |
| Wrong checked/wrapping operator variant | Valid path reverts (`-`/`+`/`*`) or overflow wraps silently (`-%`/`+%`/`*%`) — the oracle already lost a valid downward path to a bare checked `-` | Audit every op's variant against intended semantics; validate bounds *before* the subtraction so its safety is provable, not incidental |

## UX Pitfalls

(Internal accounting module — "user" here is the integrating contract / depositor, not an end-user UI.)

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| `deposit` silently mints 0 shares (unset `p_risk` or `h→1`) | Collateral taken, no claim, no error | Revert with a reason; never accept a deposit that mints 0 |
| Return value trusted over state | Integrator believes a deposit succeeded when state didn't move | Readers expose `totalDeposits`/`totalShares`/`riskWeightedShares`; tests assert state, not return |

## "Looks Done But Isn't" Checklist

- [ ] **`deposit` dispatch:** Often "done" on `make compile` green — verify it is **CALLED green** through deployed bytecode with an observed state change; `VegaAccountMod` leaves `PLANK_SKIP` only then.
- [ ] **`p_risk` guard:** Often present only in the setter — verify `deposit` itself reverts on `p_risk == 0` (uninitialized slot is reachable).
- [ ] **`hX96` bound:** Often `<=` — verify it is strict `<` and that `hX96 = 2^96` **reverts**, not returns 0.
- [ ] **Rounding:** Often defaulted to floor everywhere — verify `p_risk` rounds **up** while issuance floors; assert `shares * p_risk ≤ deposit * 2^96` and `p_risk ≥ oracle`.
- [ ] **Three state vars:** Often two aliased under `d ≡ 1` — verify three distinct slots by writing one and reading the others independently.
- [ ] **Admissibility guard:** Often a cross-product — verify it is the collapsed `deposit ≤ totalMoney` (or 512-bit if a product is unavoidable).
- [ ] **Mutation battery:** Often "green under deliberate bugs" (a prior smoke suite was 6/6 green while broken) — verify every guard/rounding mutant is **observed red**, with `cache/fuzz` cleared or a non-fuzz unit anchor alongside.
- [ ] **Corpora:** Often random+`vm.assume` — verify the h→1, unset-`p_risk`, overflow-boundary, and `deposit == totalMoney` regimes are **constructed**, not filtered.

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Refuted formula shipped (Pitfall 1) | LOW (v1, no withdraw) | Correct `risk.md`, re-derive `p_risk`, re-run `haircutRiskPrice_ge_oracle` property |
| Slot aliasing of the three vars (Pitfall 7) | MEDIUM | Re-layout storage, migrate counters; costly if any external reader cached slot ids |
| Rounding reversed (Pitfall 4) | LOW in v1 (latent), HIGH if discovered post-withdraw | Fix rounding flags, re-run floor/ceil invariants; if withdraw already shipped, audit for drained backing |
| Silent-zero mints already occurred (Pitfalls 2/3) | HIGH | Off-chain reconstruct affected deposits (collateral in, 0 shares out); no on-chain record distinguishes them from valid 0 — hence prevent, don't recover |

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| 1 — Refuted `price/haircut` formula | Spec correction (first) | `haircutRiskPrice_ge_oracle` fuzz property passes; no `price/haircut` in tree |
| 2 — Silent-zero on unset `p_risk` | Risk-price / setter | Fresh-deploy `deposit` reverts; `totalDeposits` unchanged |
| 3 — `h→1` non-strict bound | Risk-price library | Constructed `hX96 = 2^96` corpus reverts; `<`→`<=` mutant killed |
| 4 — Rounding direction | Issuance library | `shares*p_risk ≤ deposit*2^96`, `p_risk ≥ oracle`; ceil/floor mutants killed |
| 5 — Guard overflow | Admissibility guard | Collapsed `deposit ≤ totalMoney`; overflow-regime corpus kills cross-product mutant |
| 6 — Units / decimals / sqrt | Spec correction + issuance | External hand-computed anchor (explicit decimals) matches; differential + anchor |
| 7 — Three-var conflation | State layout | Three distinct slots; write-one-read-others; slot-alias mutant killed |
| N/A-1 — First-depositor (forward risk) | v2 withdraw phase (flag) | v1 invariant: shares independent of pool history |
| N/A-2 — Donation (forward risk) | State layout | Raw-transfer-then-deposit leaves shares unchanged |
| R11 — Dead-module green compile | Every test-producing phase | Deposit CALLED green via `deployPlank`; leaves `PLANK_SKIP` only then |
| R13 — `@evm_not` guard never fires | Every guard | Feed rejected input → revert observed (guard-fires mutation) |
| R14 — `vm.assume` exhaustion | Every fuzz phase | Regime corpora CONSTRUCTED and asserted non-vacuous |
| R16 — Cached-fuzz replay | Mutation battery | `cache/fuzz` cleared per kill, or non-fuzz unit anchor present |
| R15 — Quotient tests cancel errors | Every diff test | Assert the three state vars + external anchor, not just the ratio |

## Repo-catalogued failure modes carried into this milestone (must be success criteria)

These are lifted verbatim-in-spirit from `.planning/STATE.md` Accumulated Context — the repo has already paid for each once. They are testing/methodology invariants, not vault-specific, but they gate every phase.

- **R11 — Green compile ≠ evidence.** Plank does not type-check code unreachable from `run{}`. A module compiling green proves nothing; only a test that CALLS the deposit selector through deployed bytecode does. `VegaAccountMod` leaves `PLANK_SKIP` only when dispatch is called green.
- **R12 — Checked vs wrapping operators.** `-`/`+`/`*` emit revert paths; `-%`/`+%`/`*%` wrap. A checked subtraction on a valid downward path already reverted in the oracle. Choose the variant deliberately per operation; validate bounds before a subtraction so its safety is provable.
- **R13 — `@evm_not` is bitwise, not logical.** A guard built on `@evm_not` never fired once already. Use `@evm_iszero`/`@evm_eq`/`@evm_lt`; mutation-prove each guard fires by feeding the rejected input and asserting revert.
- **R14 — Corpora must be CONSTRUCTED, not `vm.assume`-filtered.** `vm.assume` exhausts before reaching the h→1, unset-`p_risk`, overflow, and boundary regimes. Build explicit corpora.
- **R15 — Quotient assertions let compensating errors cancel.** Assert the STATE (three vars, independently) plus an EXTERNAL anchor (a value neither implementation influences, derived ≥3×), not just `shares == mock`.
- **R16 — Cached-fuzz replay.** A `runs: 0` red replays a prior counterexample — a weaker claim than an independent kill. Clear `cache/fuzz` before proving a mutant kill, or keep a cache-independent non-fuzz unit anchor beside each fuzz (the strictly-stronger 09-02 pattern).
- **R17 — Mutants must reach DEPLOYED bytecode.** `deployPlank` recompiles the `.plk` fresh via FFI each run (no `make compile-plank` needed between mutants); but if a future test deploys from a prebuilt artifact, kills become fiction — re-check the deploy path.

## Sources

- `../cfmm-wt/lean4-spec/lean/vol_markets/RiskDesign.lean` — machine-checked (`mulX96Down`, `mulX96Down_le`, `mulX96Down_one`, `haircutRiskPrice`, `haircutRiskPrice_ge_oracle`, `issuance_haircut_equiv`) — **HIGH**
- `../cfmm-wt/lean4-spec/lean/vol_markets/Flow.lean` — `deltaShares`, `deltaShares_admissible_iff` (division-free guard collapse) — **HIGH**
- `../cfmm-wt/lean4-spec/model/vol_markets/RISK_ALTERNATIVES.md` — rounding direction (§1/§4), decimals/quote/sqrt conventions (§2), 512-bit guard (§4), three-var separation (§5) — **HIGH**
- `.planning/STATE.md` Accumulated Context — repo-catalogued failure modes R11–R17 (dead-module compile, checked/wrapping, `@evm_not`, constructed corpora, quotient-cancellation, cached-replay, FFI deploy) — **HIGH (first-party)**
- `.planning/PROJECT.md` Key Decisions — exogenous `p_risk`, three distinct state vars, H1-only, Lean-as-oracle — **HIGH (first-party)**
- `spec/entities/types/risk.md` — the refuted `price/haircut` draft (Pitfall 1 target) — **HIGH (first-party)**

---
*Pitfalls research for: collateral→vega-exposure share-issuance vault (Plank, exogenous risk price, deposit-only)*
*Researched: 2026-07-16*
