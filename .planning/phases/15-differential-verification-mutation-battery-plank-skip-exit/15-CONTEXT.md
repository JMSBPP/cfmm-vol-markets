# Phase 15: Differential Verification & Mutation Battery, PLANK_SKIP Exit - Context

**Gathered:** 2026-07-18
**Status:** Ready for planning
**Source:** Derived from the review-hardened roadmap Phase 15 SCs and the proven Phase 13/14 artifacts. No open user decisions.

<domain>
## Phase Boundary

The milestone's acceptance bar — assembly and exit gates, no new arithmetic and no new module surface:

1. An END-TO-END differential test driving identical `(setRiskPrice, deposit)` SEQUENCES into `VegaAccountMod` (FFI-deployed) and `IssuanceRefMock.sol`, asserting all three accumulators (`totalDeposits`, `totalShares`, `riskWeightedShares`) equal at tolerance 0 **after EVERY write, with the assertion INSIDE the driver** (aborts at the earliest divergent write — the 09-02/14 pattern). Fixed hand-checkable anchor sequence + constructed fuzz sequences.
2. The Phase-15 observed-RED mutation battery over the END-TO-END surface.
3. `VegaAccountMod` leaves `PLANK_SKIP` — ONLY after `deposit` is CALLED green (already true since 14) and the compile gate stays green with the module now compiled (expect `12 ok, 0 failed, 0 skipped`).
4. The vega suites fold into `make test` (they already run under plain `forge test`, but the PriceSetterHook `--skip` complicates it — see decisions).

Requirements: VVER-01, VVER-02. Roadmap Phase 15 SCs (1–4) are the acceptance contract.
</domain>

<decisions>
## Implementation Decisions (locked upstream)

### The driver (SC-1, VVER-01)
- Two-way: module vs `IssuanceRefMock` extended-or-wrapped with STATE (the mock currently exposes pure functions; the driver either adds a thin stateful mirror in the test contract — three uint256 accumulators updated via the mock's pure composed() — or extends the mock; planner picks, but the mirror must be TRIVIALLY simple, since a complex mirror is a second implementation to distrust).
- Assertion INSIDE `_setPriceBoth`/`_depositBoth` helpers, after EVERY write (including after each setRiskPrice — accumulators unchanged there).
- Fixed anchor sequence (hand-checkable: at least two price levels, at least three deposits, at least one dust-revert expectation mid-sequence proving reverts leave state synced) + fuzz sequences (constructed, repair-not-reject, no vm.assume; price changes mid-sequence so later deposits price differently — the rate-shift semantics recorded in scope).
- Tolerance 0 everywhere. `riskWeightedShares == totalShares` in v1 (d≡1) — asserted as a consequence, never conflated in the driver's bookkeeping (two separate mirror accumulators).

### The battery (SC-3, VVER-02) — killable mutants only, end-to-end observed
- Rounding-direction flips (p_risk ceil→floor in the LIB, shares floor→ceil in the LIB) — must redden the END-TO-END differential (not just the Phase-13 kernel tests): proves the e2e corpus is rounding-sensitive (contains inexact-division sequence points — construct at least one).
- Accumulator conflation (SLOT-constant aliasing in the MODULE) — reddens driver + the Phase-14 vm.load (both run).
- Dust-guard deletion (MODULE) — the mid-sequence dust expectation reddens.
- Cross-product guard (MODULE) — killed as in 14 (checked-overflow revert at a 2^200 sequence point; baseline accepts).
- Equivalence-documented (never counted): h-bound relaxation (lib), unset-price guard deletion (module).
- Per-mutant: apply → rm -rf cache/fuzz → observe RED verbatim → restore → sha256 == recorded baselines (lib: 2ee071627e25f4fe07b6e78cb5e163435cdfb737b4dcf293939c5a8ae7bfc7e3; module: 555a7a100b97f41bcdf3604141065fc2fe3a1e2d63a5ec9ffcb12b9172818120) → green. Non-fuzz anchor sequence is the primary cache-independent kill site.

### PLANK_SKIP exit (SC-4, VVER-02)
- Delete the `src/modules/exposure/VegaAccountMod.plk` line from PLANK_SKIP (the Makefile comment says the list only ever shrinks — this is the moment it was written for). Update the rescue-queue comment.
- `make compile-plank` then expects `12 ok, 0 failed, 0 skipped`. If the module FAILS to compile standalone (e.g. an import quirk only surfacing via the entrypoint path), that is a REAL finding — fix the module, never re-add the skip.

### make test fold-in (SC-4)
- The vega suites already run under bare `forge test` — EXCEPT the untracked PriceSetterHook.sol breaks `forge build` of the whole tree, which also breaks `make test` TODAY for everyone. Decision: `make test` gains the same `--skip 'src/modules/protocol_integrations/PriceSetterHook.sol'` guard with a loud comment (untracked stray of PR #11's work; the skip is a no-op once the owning track removes it) — HONEST framing: this un-breaks make test for the local tree without touching another track's file. Expected `make test` outcome: previous 50 pass / 5 pre-existing pos_spec failures + the ~23 new vega tests + the new e2e tests all passing; the 5 pos_spec failures REMAIN visible (never skipped).
- The Makefile's "THIS TARGET IS CURRENTLY RED" comment block gets its counts updated to the new truth.

### Milestone-completion note
Phase 15 completes v3.0. After the phase verifier passes, the milestone audit/close (gsd:complete-milestone) is a SEPARATE user decision — do not run it inside the phase.

### Claude's Discretion
- E2E test file: extend test/exposure/VegaAccount.t.sol with a new contract, or a new file test/exposure/VegaAccount.e2e.t.sol — one surface, planner picks and justifies (the e2e differential is arguably its own surface; either is acceptable if justified).
- Sequence lengths/corpus construction details (≥3 deposits, ≥2 price levels, ≥1 dust point, ≥1 2^200 point across the corpus; fuzz n bounded to keep 256 runs tractable).
- Whether the stateful mirror lives in the test contract (recommended — visible in one file) or the mock.
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### The contract being implemented
- `.planning/ROADMAP.md` Phase 15 section — four review-hardened SCs.
- `.planning/REQUIREMENTS.md` — VVER-01/02 exact statements.

### The proven pieces being assembled (read before writing)
- `src/modules/exposure/VegaAccountMod.plk` + `src/interfaces/exposure/VegaAccountInterface.plk` (the live module + pinned selectors; sha256 baseline above).
- `src/lib/exposure/VegaIssuanceLib.plk` (sha256 baseline above).
- `test/mocks/IssuanceRefMock.sol` (pure reference — the driver's expected-value source).
- `test/exposure/VegaAccount.t.sol` (module suite incl. vm.load slots + the guard tests the battery reuses).
- `test/exposure/VegaIssuance.diff.t.sol` (kernel battery — do NOT duplicate its properties).
- `test/market_state_measurements/RealizedVolatility.diff.t.sol` — RealizedVolatilityTimepointDiffTest: THE after-every-write driver pattern (assertion inside _writeBoth; fixed anchor + constructed fuzz; abort-at-earliest-divergence rationale in its docblock).
- `Makefile` — PLANK_SKIP block + the `test:` target comment block being updated.

### Discipline
- STATE.md Accumulated Context — cached-replay rule, FFI-recompile fact, quotient-cancellation, constructed corpora.
</canonical_refs>

<specifics>
## Specific Ideas

- The fixed anchor sequence should include the Phase-12 anchor point (deposit=10 at oracle=10·2^92, h=3·2^92 via previewRiskPrice-computed price set exogenously) so the e2e anchor inherits the triple-derived expected values (shares=12) — hand-checkable without new derivation.
- A mid-sequence `setRiskPrice` change must be followed by a deposit whose expected shares are computed at the NEW price — the mirror recomputes per-write, catching a stale-price-caching mutant class for free.
- After the PLANK_SKIP exit, `make compile` and `make test` are the two commands of record again — the phase's last act should run BOTH and record the verbatim tails in the SUMMARY.
</specifics>

<deferred>
## Deferred Ideas

- Milestone close/audit (gsd:complete-milestone) — user decision after verification.
- v2.0 Phases 10–11, v1.0 plumbing, oracle wiring, withdraw — other tracks/milestones.
- The 5 pos_spec harness failures — vol-type-system track; stay visible in make test.
</deferred>

---

*Phase: 15-differential-verification-mutation-battery-plank-skip-exit*
*Context gathered: 2026-07-18, derived from review-hardened SCs + proven Phase 13/14 artifacts*
