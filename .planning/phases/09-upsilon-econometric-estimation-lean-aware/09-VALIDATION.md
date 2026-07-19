---
phase: 9
slug: upsilon-econometric-estimation-lean-aware
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-07-19
---

# Phase 9 — Validation Strategy

> Per-phase validation contract. Two test surfaces: the Haskell suite (`stack test`) for the estimator/pipeline, and the Lean gate (`lake build` + `#print axioms`) for the bridging lemma; artifact greps for outputs; audit-econ as the post-estimation gate.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework (Haskell)** | hspec (or tasty, fixed at scaffold) via `stack test`; GHC 9.10.3 / Stack 3.11.1 confirmed installed; BLAS/LAPACK present, **NO GSL** — `hmatrix-gsl` forbidden |
| **Config file** | `econometrics/package.yaml` test stanza — created in Wave 0 |
| **Quick run command** | `stack test econometrics:test:unit` (sandwich-SE + gradient goldens) |
| **Full suite command** | `stack test` + `cd lean && lake build vol_markets` |
| **Estimated runtime** | Haskell unit goldens: seconds; full suite + Lean gate: minutes (Mathlib cached) |

---

## Sampling Rate

- **After every task commit:** `stack test econometrics:test:unit`; for Lean-touching tasks also `cd lean && lake build vol_markets`
- **After every plan wave:** full `stack test` + `lake build vol_markets`
- **Before `/gsd:verify-work`:** full suite green + Lean sorry-free/axiom-clean + **audit-econ PASS**
- **Max feedback latency:** ~300s (Lean gate; Haskell goldens are seconds) — same accepted exception as Phase 8

---

## Per-Task Verification Map

(CTX-* tags per the Phase-8 convention; task IDs firm up at planning.)

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| TBD | TBD | 0 | Stack scaffold builds, BLAS links, no hmatrix-gsl | build | `cd econometrics && stack build` exits 0; `! grep -r 'hmatrix-gsl' econometrics/` | ❌ W0 | ⬜ pending |
| TBD | TBD | 0 | Mainnet/L2 subgraph endpoint + auth confirmed | gate | scripted GraphQL probe returns entities (endpoint recorded, key in .env only) | ❌ W0 | ⬜ pending |
| TBD | TBD | 0 | BigQuery connectivity + Swap topic0 | gate | `mcp__bigquery__execute-query` dry-run returns rows | ❌ W0 | ⬜ pending |
| TBD | TBD | 0 | Corrected `ATMOTMNullHypothesis` (slope-centered conjunct 3) locked locally | build | `cd lean && lake build vol_markets` exit 0, no sorry in Upsilon.lean | partial | ⬜ pending |
| TBD | TBD | 1 | CTX-PANEL: tokenId×daily panel, π_it as delta of cumulative | integration | `stack test econometrics:test:panel` (fixture → expected rows) | ❌ W0 | ⬜ pending |
| TBD | TBD | 1 | CTX-VAR: σ̂²_t + EIV instrument match golden window | unit | `stack test econometrics:test:variance` | ❌ W0 | ⬜ pending |
| TBD | TBD | 2 | CTX-EST: LM recovers planted (β₀,υ₀,κ) on synthetic data | unit | `stack test econometrics:test:nls` | ❌ W0 | ⬜ pending |
| TBD | TBD | 2 | CTX-EST: cluster-robust sandwich SE matches hand-computed toy panel | unit | `stack test econometrics:test:sandwich` (golden, 1e-9) | ❌ W0 | ⬜ pending |
| TBD | TBD | 2 | CTX-TEST: Wald/t stats for υ₀>0, κ>0, κ⁺=κ⁻ | unit | `stack test econometrics:test:specification` | ❌ W0 | ⬜ pending |
| TBD | TBD | 3 | CTX-ALT: four alternative specs emit comparable estimates | integration | `stack test econometrics:test:alternatives` (smoke) | ❌ W0 | ⬜ pending |
| TBD | TBD | 3 | CTX-BRIDGE: bridging lemma sorry-free, axiom-clean (serial Aristotle) | build+proof | `cd lean && lake build vol_markets` + `#print axioms` scratch check | ❌ | ⬜ pending |
| TBD | TBD | 4 | CTX-AUDIT: audit-econ PASS on analysis output | gate | `audit-econ notes/structural-econometrcics/analysis/<file>` — no Critical/High spec-faithfulness findings | ❌ post-est | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `econometrics/` Stack project scaffold + LTS pin + `stack build` green (BLAS/LAPACK link confirmed; **no hmatrix-gsl**)
- [ ] Test suite skeleton (hspec/tasty) + the sandwich-SE golden fixture
- [ ] Mainnet/L2 Panoptic subgraph endpoint + auth confirmed (only Sepolia documented — blocking discovery; GRAPH_API_KEY to worktree `.env` if needed)
- [ ] BigQuery `mcp__bigquery__` connectivity from the exec session + Uniswap Swap topic0 computed
- [ ] Corrected `ATMOTMNullHypothesis` conjunct-3 (slope-centered envelope, c = κ·Δi) applied to `lean/vol_markets/Upsilon.lean` + local `lake build` green — BEFORE the single Aristotle submission

Framework installs: GHC/Stack present; no new system deps (GSL route forbidden).

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Aristotle round-trip (bridging lemma) | CTX-BRIDGE | Server-side; strictly serial, single in-flight | 08-05 recipe: bundle → submit → `aristotle tasks` watcher → download → integrate → rebuild |
| audit-econ verdict interpretation | CTX-AUDIT | Delphi consensus output needs human-relevant triage | Any Critical/High mapping to spec-faithfulness or estimator correctness ⇒ FAIL, fix, re-audit |
| Real-data estimate sanity | CTX-EST | The κ̂/υ̂₀ magnitudes have no golden truth | Compare premium-channel vs collateral-channel υ̂; inspect fit diagnostics in analysis output |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 300s (Lean-gate exception accepted, per Phase 8)
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending (set at plan-check)
