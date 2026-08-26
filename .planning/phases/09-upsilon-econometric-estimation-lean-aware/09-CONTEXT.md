# Phase 9: upsilon econometric estimation lean-aware - Context

**Gathered:** 2026-07-19
**Status:** Ready for planning

<domain>
## Phase Boundary

Execute the approved υ-identification econometric spec (`notes/structural-econometrcics/specs/2026-07-19-panoptic-upsilon-identification.md`): build the position-epoch panel from Panoptic on-chain data, estimate π_it = β₀ + υ₀·exp(−κ|i_K − i_t|)·σ̂²_t + v_it by NLS/GMM with robust tokenId-clustered SEs, run the committed tests (υ₀ > 0, κ > 0, κ⁺ = κ⁻) and the four scheduled alternative specifications — **Lean-aware**: estimated objects mirror the Lean definitions, with a bridging lemma making κ̂ > 0 a witness to `Upsilon.ATMOTMNullHypothesis`. Estimation is implemented **exclusively in Haskell**. Post-estimation passes the audit-econ gate. Lean4-track phase, independent of Phases 2–7.

</domain>

<decisions>
## Implementation Decisions

### Data access route
- **Hybrid**: Panoptic subgraph for positions/premia/strikes (tokenId-level); **BigQuery MCP** (`mcp__bigquery__`, connected in this session) for the underlying Uniswap pool's swap ticks — used to construct σ̂²_t AND the second, independently-windowed variance estimator that instruments σ̂² (the EIV two-noisy-measures remedy).
- **Docs-first discovery**: start from `https://panoptic.xyz/docs/subgraph/schema` (user-directed) — fetch it FIRST; endpoint(s), chain coverage, auth requirements, and entity names all follow from what the official docs declare. Do not guess subgraph IDs.
- No Dune MCP exists in this session — the structural-econometrics skill's Dune mandate is explicitly overridden by this hybrid route (documented deviation).

### Estimation stack (Haskell ONLY — user directive)
- **All estimation code in Haskell.** No Python/R anywhere in the pipeline.
- **Stack project at `econometrics/`** (Stackage LTS pin for reproducibility); outputs still land in `notes/structural-econometrcics/{data,analysis}/` per the skill's layout.
- **Numeric packages: researcher decides** — survey the Haskell ecosystem (hmatrix, hmatrix-gsl, ad, statistics, math-functions, nonlinear-optimization, massiv, …) for: nonlinear least squares / Gauss-Newton-LM, automatic differentiation, and the linear algebra for hand-rolled cluster-robust sandwich SEs (no Haskell package ships clustered NLS SEs — that code is written and unit-tested in-phase regardless). Recommendation with build implications (system BLAS/GSL deps vs pure Haskell) lands in RESEARCH.md.
- **audit-econ gate: YES** — after estimation, an independent audit-econ dispatch (different-agent rule) checks math/estimator/data faithfulness against the 08-03 spec. FAIL blocks phase completion.

### Market & sample
- **Deepest ETH/USDC Panoptic market** — the highest-activity market on the largest ETH/USDC Uniswap pool the subgraph covers; the exact pool/chain/address is confirmed from the subgraph during research (not assumed).
- **Full history, daily epochs** — everything the subgraph has for that market, 1-day buckets; σ̂²_t from within-day swap ticks; the EIV instrument from a second daily windowing. Epoch length is a one-shot choice (deliberately not in the sensitivity set).

### Lean-awareness mechanism (Claude's Discretion — area not selected for discussion)
- **Bridging lemma** in `lean/vol_markets/Upsilon.lean`: the exponential-moneyness family υfun(i) = υ₀·exp(−κ·Δi·|i − i_K|)-style profile with κ > 0 (and υ₀ ≠ 0 as needed) satisfies `ATMOTMNullHypothesis` — so the estimated κ̂ > 0 makes the fitted profile a literal witness of the Lean conjecture. Statement drafted locally, **proof via ONE serial Aristotle task** (Aristotle-heavy rule; single in-flight submission; new project).
- **Cross-reference discipline**: the Haskell estimator encodes υ, the moneyness distance, and the tick grid EXACTLY as the Lean definitions state them (same formulas, same units); a short cross-walk table (Lean name ↔ Haskell name ↔ spec §) lives in the analysis output.

### Claude's Discretion
- Exact Haskell module layout, GHC/LTS version choice (subject to what's installable on this machine), subgraph pagination strategy, BigQuery SQL shape, and the bridging-lemma statement details.
- Whether results feed back to the plank session's `spec/protocol/protocol_integrations/panoptic.md` copy — coordination note for peer `ul2inqpl`, not a deliverable.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### The approved econometric spec (the phase's contract)
- `notes/structural-econometrcics/specs/2026-07-19-panoptic-upsilon-identification.md` — every estimation choice is already locked there (equation, error structure, EIV remedy, tests, alternatives); this phase implements it, it does not re-derive it.

### Data sources
- `https://panoptic.xyz/docs/subgraph/schema` — THE starting point for subgraph discovery (user-directed); endpoints/auth/entities follow from it.
- BigQuery public Ethereum datasets via `mcp__bigquery__` (list-tables/describe-table first; exact dataset confirmed in research).

### Lean twins (the definitions the Haskell code must mirror)
- `lean/vol_markets/Upsilon.lean` — `upsilon`, `upsilonTickSlope`, `ATMOTMNullHypothesis` (the bridging lemma lands here)
- `lean/vol_markets/Panoptic.lean` — `volOptionPayoff`, `streamingPremium`, `thetaAtm`, `theta_atm_closed_form`
- `lean/vol_markets/PosSpec.lean` — `lam` = 1.0001, `tickPrice` (the tick grid the moneyness distance is defined on)
- `spec/protocol/panoptic.md` — the pinned protocol spec (ECONOMETRIC section is the seed)

### Workflow rules
- Memory: lean-aristotle-heavy-workflow — statements local, proofs via serial Aristotle, integrate from returned archive
- `.planning/phases/08-panoptic-vol-claim-lean4-formalization/08-05-SUMMARY.md` — the working Aristotle submission recipe (bundle layout, CLI invocations, watcher pattern)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- Aristotle bundle recipe from 08-05 (`scratch/aristotle-panoptic-upsilon/` layout, import-rewrite sed, `aristotle tasks`-based watcher) — reuse verbatim for the bridging lemma
- `lean/vol_markets/*` — all four υ/θ theorems proved, axiom-clean; the bridging lemma appends to Upsilon.lean and re-wires nothing
- Worktree `.env` — ARISTOTLE_API_KEY established; GRAPH_API_KEY may be added the same way if the docs demand gateway auth

### Established Patterns
- GSD CTX-* requirement tags minted at planning (Phase-8 convention, documented in ROADMAP)
- `lake build vol_markets` as the Lean gate; `#print axioms` scratch-file check for axiom cleanliness
- No `/home/`, `$HOME`, `~/` paths in any tracked file (Phase-1 rule) — applies to Haskell sources, SQL, and analysis outputs too

### Integration Points
- `econometrics/` — new top-level Stack project (new directory, no collisions)
- `notes/structural-econometrcics/{data,analysis}/` — skill-layout output dirs (specs/ already exists)
- `lean/vol_markets/Upsilon.lean` — bridging lemma target
- BigQuery via `mcp__bigquery__*` tools (ToolSearch to load schemas at execution)

</code_context>

<specifics>
## Specific Ideas

- "ONLY haskell" — the estimation implementation language is a hard user directive, not a preference; do not fall back to Python for "just the data munging".
- Subgraph discovery starts at the official docs URL the user gave — fetch it before any endpoint guessing.
- The Lean-aware coupling should make κ̂ > 0 a *formal witness*: estimate lands → plug the fitted profile parameters into the bridging lemma's hypotheses → the Lean conjecture is witnessed by data. This is the phase's headline artifact.

</specifics>

<deferred>
## Deferred Ideas

- Feeding estimation results back into the plank session's `spec/protocol/protocol_integrations/panoptic.md` — coordination with peer `ul2inqpl`, separate step
- Epoch-length sensitivity (deliberately one-shot at daily)
- Multi-market extension (spec's environment is single-market by locked decision)
- On-chain Lens read of υ (contract-level identification) — plank/solidity tracks

</deferred>

---

*Phase: 09-upsilon-econometric-estimation-lean-aware*
*Context gathered: 2026-07-19*
