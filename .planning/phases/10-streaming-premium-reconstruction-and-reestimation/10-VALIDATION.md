---
phase: 10
slug: streaming-premium-reconstruction-and-reestimation
status: approved
nyquist_compliant: true
wave_0_complete: false
created: 2026-07-20
---

# Phase 10 — Validation Strategy

> Two surfaces: the offline hspec suite (deterministic, frozen fixtures — **no network in tests**) and the reconciliation CLI (network, the hard gate that blocks estimation). Route amended 2026-07-20: SFPM `getAccountPremium` archive reads, not V4 replay.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | hspec via `econometrics:test:unit` (`test/Spec.hs`); module list is **explicit** under `other-modules` in `package.yaml` — new spec modules must be added there or they silently never run |
| **Quick run command** | `cd econometrics && stack test econometrics:test:unit --fast` |
| **Full suite command** | `stack test` (currently **59/0**, must stay green) + `lake build vol_markets` if any Lean file is touched (none expected) |
| **Golden precision** | 1e-9 (the 09-08 sandwich-SE precedent) |
| **Fixtures** | `econometrics/test/fixtures/` — incl. **frozen raw `eth_call` returndata** so the suite stays offline and deterministic |
| **Estimated runtime** | unit goldens: seconds; reconciliation CLI: minutes (network) |

---

## Sampling Rate

- **After every task commit:** `stack test econometrics:test:unit --fast`
- **After every plan wave:** full `stack test`
- **Phase gate:** full suite green **AND** the reconciliation CLI passes (≤1% median rel. error, wei, stratified) **before the estimator is run at all**
- **Max feedback latency:** ~60s for the unit suite

---

## Per-Task Verification Map

(CTX-* tags minted at planning, per the Phase-8/9 convention.)

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| TBD | TBD | 0 | **BLOCKER: `width ≠ 0` leg count → achievable panel size** | gate | subgraph query + count; STOP if panel not materially > 61 obs | ❌ W0 | ⬜ pending |
| TBD | TBD | 0 | CTX-FEE: `feeGrowthInside` branch logic matches `Pool.sol` L488-511, all three tick regimes | unit | `stack test econometrics:test:unit --ta '-m "feeGrowthInside"'` | ❌ W0 | ⬜ pending |
| TBD | TBD | 0 | CTX-FEE: unchecked wraparound (`diffMod 256`, `diffMod 128`) matches Solidity | unit | `… --ta '-m "wraparound"'` | ❌ W0 | ⬜ pending |
| TBD | TBD | 0 | CTX-FEE: ABI decode int24/uint128/uint160 incl. sign extension | unit | `… --ta '-m "Chain.Abi"'` | ❌ W0 | ⬜ pending |
| TBD | TBD | 0 | CTX-FEE: **golden** — frozen accumulator triple (blocks 44.5M/47M/latest-at-freeze, chunk `tt0 [-199680,-197280]`) reproduces from recorded raw returndata | golden | `… --ta '-m "premium golden"'` | ❌ W0 | ⬜ pending |
| TBD | TBD | 0 | CTX-PREM: `premiumWei` sign convention — long negates, short does not | unit | `… --ta '-m "premium sign"'` | ❌ W0 | ⬜ pending |
| TBD | TBD | 0 | CTX-PANEL2: `getTicks(strike,width,tickSpacing)` reproduces `Chunk.tickLower/tickUpper` incl. odd-width floor/ceil asymmetry | unit | `… --ta '-m "getTicks"'` | ❌ W0 | ⬜ pending |
| TBD | TBD | 0 | CTX-PANEL2: epoch↔block monotone; boundary ts ≥ epoch×86400; **uses `Panel.Build.dailyEpoch`, not a redefinition** | unit | `… --ta '-m "BlockIndex"'` | ❌ W0 | ⬜ pending |
| TBD | TBD | 0 | CTX-GATE: telescoping identity Σ-over-epochs = endpoint difference, on synthetic accumulators | unit | `… --ta '-m "telescoping"'` | ❌ W0 | ⬜ pending |
| TBD | TBD | 1-2 | CTX-PANEL2: panel joins `variance.csv` with **zero** unmatched epochs | integration | `… --ta '-m "panel join"'` | ❌ W0 | ⬜ pending |
| TBD | TBD | 3 | **CTX-GATE: the hard gate** — median rel. error ≤1% on 61 spells, ETH wei, stratified short/long | integration (network) | `stack exec econometrics -- reconcile` (CLI, not the suite) | ❌ W3 | ⬜ pending |
| TBD | TBD | 4 | CTX-EST2: re-estimation; υ₀ CI half-width ≤ ~6.2e-5 (result-independent success) | integration | `stack exec econometrics -- estimate` + analysis output | ❌ | ⬜ pending |
| TBD | TBD | — | Phase-9 estimator/SEs/tests/alternatives still pass | regression | `stack test` (existing 59) | ✅ exists | ⬜ pending |
| TBD | TBD | opt | CTX-PREM: `_getPremiaDeltas` Haskell cross-check reproduces on-chain accumulator on frozen fixture | golden | `… --ta '-m "premia deltas"'` | ❌ optional | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] **BLOCKER: measure the `width ≠ 0` leg/position count and the achievable panel size.** `_getPremia` skips `width == 0` legs; the phase's ×100 sample-gain premise is unverified. If the usable panel is not materially larger than Phase 9's 61 observations, **stop and report** — do not proceed to estimation.
- [ ] `econometrics/test/Chain/AbiSpec.hs` — ABI decode + wraparound (CTX-FEE)
- [ ] `econometrics/test/Chain/BlockIndexSpec.hs` — epoch↔block, `dailyEpoch` reuse (CTX-PANEL2)
- [ ] `econometrics/test/Panoptic/PremiumSpec.hs` — sign, X64 scaling, telescoping (CTX-PREM, CTX-GATE)
- [ ] `econometrics/test/Panoptic/ChunkSpec.hs` — `getTicks` vs frozen `Chunk` fixture (CTX-PANEL2)
- [ ] `econometrics/test/fixtures/premium-acc-golden.json` — **frozen raw `eth_call` returndata** from the research probes (keeps the suite offline/deterministic)
- [ ] New spec modules registered in `package.yaml` `other-modules` (else they silently do not run)

No new system deps: GHC/Stack/GSL present; the keyless Base endpoint already serves archive state.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Archive-RPC availability over the full window | CTX-PREM | Depends on a third-party public endpoint's retention; can degrade between runs | Re-probe `extsload` at the window's earliest block before the bulk read; if it fails, report rather than silently narrowing the window |
| Gate verdict interpretation | CTX-GATE | Stratified distributions need judgement (long-premium capping is expected, not a defect) | Inspect short vs long strata separately; systematic sign bias in one stratum ⇒ diagnose, do NOT relax tolerance |
| Stopping-rule adjudication | CTX-EST2 | Pre-committed and result-independent by design | If υ₀ half-width > ~6.2e-5 after a passing gate: report "market cannot identify υ" and STOP — no respecification, no subsample hunting (`anti-fishing-replication`) |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] No network calls inside the hspec suite (frozen fixtures only)
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** approved 2026-07-20 (plan-checker: 0 blockers; 3 warnings resolved in-place, incl. the Wave-0 threshold reframing)
