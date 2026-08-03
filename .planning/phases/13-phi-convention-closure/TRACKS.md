# Phase 13 — Capponi `F` → `φ` convention closure

**Requirement:** CTX-PHIDOC (sole).
**Status:** IN FLIGHT. **Registration corrected 2026-08-03** after the two-reviewer gate returned
NEEDS WORK on the first draft of this file — see §Gate record.
**Depends on:** Phase 12 (this phase is the *correction* of Phase 12's curvature layer).

## What the machine settled

The doc asserted "F is φ". Proven false, and the failure cascaded into the naming of every E-block.

**Landed, axiom-clean, in `lean/vol_markets/`:**

| Module | Decls | Load-bearing result |
|---|---|---|
| `PhiCES.lean` | 12 | the two-parameter CES family; ρ→0 Cobb–Douglas limit; `curvIndex_is_rho_zero_slice` |
| `CanonicalCurve.lean` | 16 | Angeris canonical form (arXiv:2308.08066 §1.3.2 eq. 6); `canon_Fcap_not_phiEps`; `curvIndex_orientation_inconsistent`; `cpmm_sits_at_curvIndex_zero` |
| `CurvatureTwo.lean` | 18 | `curvTwo ρ = (1−ρ)/(2−ρ)`; `rhoOfCurv`; `subElast`; **`curvOfTilde_not_curvature`** |
| `EtaTilde.lean` | 23 | `etaTilde`, **`curvOfTilde`** — the object `curvOfTilde_not_curvature` is *about*. Landed `1417958` (2026-08-02) **after Phase 12 closed at `0f44daf`**, so it was never registered anywhere. Registered here. |

**Doc consequence applied 2026-08-03** (`601e7ba`, `758e964`, `634ded6`, `838289f`): `ρ → ε_{X/M}`
(substitution); old `ε_{X/M} → χ_{X/M}` (share); `κ_{\varphi}` freed and REASSIGNED to the genuine
curvature `(1−ε)/(2−ε)`; old `κ_{\varphi} → ς_{X/M}` (share asymmetry); economic definitions added;
`σ_ES → \bar ε_{X/M}` under the ε/σ reservation.

## OPEN

- **(a) Embedding test `232c8ee4` — PARTIAL RETURN, 2/4.** *Both ENDPOINTS embed and are PROVEN:*
  `Fcap_zero_is_rho_one` (Capponi's linear endpoint IS the `ρ=1` CES slice, witnesses
  `ε = pA/(pA+pB)`, `c = A(pA+pB)/C`) and `Fcap_one_is_rho_zero_limit` (the constant-product endpoint
  IS the equal-share punctured `ρ→0` limit, stated as a `Tendsto` so the bracket is never evaluated
  at `ρ=0`). *The INTERIOR is open:* `canon_Fcap_not_CES` (verdict at the `κ=1/2` witness) and
  `kappa_not_reparam_of_rho` (no endpoint-matching reparametrisation) are **SORRIED** — the task hit
  **OUT_OF_BUDGET** after 1h26m. Owed: a scoped repair bundle on those two only, with the two proven
  endpoint theorems as the working base. **Do NOT integrate the partial** — it carries sorries.

  > CORRECTION: this item previously read "Aristotle API returning 500". That was a **CLI usage error
  > of mine**, not an API fault — `show`/`tasks` 500 on SHORT ids and require the full UUID; the
  > control project reproduced the same 500. The API was up throughout. Second CLI mis-read in this
  > program (the first was matching the status column against a task NAME).

  > **REPAIR BUNDLE SUBMITTED 2026-08-03: project `1f6da52a-f998-471c-84b6-9130d8adbd25`**
  > (`aristotle-embed2`), scoped to the two sorries only, with the two proven endpoint theorems and
  > all 24 other modules as the working base, a budget priority order, and an explicit
  > "prove the opposite under a different name if A1 is false" clause. Submitted to a NEW project,
  > never `continue` in parallel. NOTE: the CLI warned the bundle carries no `.lake` folder — the
  > download does not include dependencies; if this run also fails, restore `.lake` before retrying.
- **(b) E4 interior optimum on the ε_{X/M} axis.** *Both branches are pre-decided so completion is
  falsifiable:* if (a) shows the embedding holds → redo E4 on the ε axis and land it in a new module;
  if (a) refutes it → record E1–E7 as SHARE statements and close (b) as **MOOT**, with the
  disposition written into the summary either way.
- **(c) `eta-notation-gate.sh` (Phase 12) enforces the OLD κ_φ bindings** and will now FAIL on the
  corrected doc. **This is a blocking predecessor of every other doc insertion in the program** —
  Phases 12.1 and 14 both end in doc blocks and neither can be gated until this is refreshed.
- **(d) `VOLATILITY_INSTRUMENTS_ETA_ADDENDUM.md` has DESYNCED from the plank copy.** The in-repo twin
  still carries 155 `\kappa_{\varphi` sites (+7 `κ_φ`) and 0 `\varsigma`; the plank copy has 82
  `\varsigma`. This is the same drift 12-04 found and fixed, re-opened by the rename. Its
  `APPROVED-ETA-SHA256` disclosure block is itself now stale — it names `54d10b59…` as live, which
  the rename has moved again. Resync **and** extend the disclosure per the 12-04 pattern.
- **(e) FALSE LINE — REPAIRED 2026-08-03 (`838289f`).** The χ definition line asserted
  `χ_{X/M} = the substitution elasticity`, the exact conflation `curvOfTilde_not_curvature` and
  `canon_Fcap_not_phiEps` refute, contradicting the parameter block 34 lines above it inserted by the
  *same* commit. The rename had mechanically substituted `ε → χ` into an already-false sentence,
  upgrading a stale claim into a self-contradiction. Now reads "the SHARE parameter". **Kept in the
  OPEN list as a recorded defect, not deleted** — it is why this phase's status is "rename landed
  WITH a repaired falsehood", not "rename landed clean".
- **(f) `χ` SITS ON OPPOSITE LEGS in two displays.** The trading-function display puts `χ_{X/M}` on
  the `ΔQ_M` leg; the CES definition puts it on the `Q_X` leg (matching Lean `phiCES`). Theorem 1
  consumes the first. The choice flips the `χ/(1−χ) = λ^{ηΔ_i/2}` bridge and the doc reading of
  `curvIndex_is_rho_zero_slice`. **FLAGGED IN THE DOC 2026-08-03, author decision required** — not
  resolvable by rename.
- **(g) Signed-vs-magnitude `ΔQ`.** *Moved here from the Kristensen track* — it is an existing-doc
  defect, which is this phase's charter, not a precondition on new work. The dangling sentence
  *"Consider a exogenous tuple flow ΔQ = (ΔQ_M, ΔQ_X) **on the region:**"* is followed by nothing —
  the region is literally absent. Theorem 1 builds `u` from `φ_{1/2,0}(i_K;ΔQ,0;t)`, which at `L=0`
  is exactly `√(ΔQ_M·ΔQ_X)`. If the legs are signed that root is not real and `u` is ill-posed on
  exactly the swaps it measures. **BLOCKER-grade; the deliverable is the missing region line.**
- **(h) Bare `\epsilon` survives** as an unsubscripted tolerance in the lens-spec bound, against the
  binding rule inserted by `634ded6` ("ε is reserved for ELASTICITIES, always subscripted").
- **(i) The `PhiCES` glyph/name swap is recorded where it will not be read.** `phiCES ρ ε` has the
  share and exponent letters swapped relative to the doc's `φ_{χ,ε}`; the doc's `> LEAN` note covers
  `CurvatureTwo` and `EtaTilde` and is silent on `PhiCES`. Since Aristotle prompts are doc-derived,
  the trap sits precisely where a prompt author will miss it. Promote to a `<!-- notation-map -->`
  line in the doc (inherits the approval gate).
- **(k) THE E1 `DIAGNOSIS` LINE IS TRUE ONLY AT `pA = pB`.** The doc asserts *"Capponi's κ travels
  the `ε_{X/M}` axis of `φ_{χ_{X/M},ε_{X/M}}`"*. The endpoint theorems returned 2026-08-03 refute
  that as stated: `Fcap_zero_is_rho_one` gives the linear endpoint at **`χ = pA/(pA+pB)`, `ε = 1`**,
  while `Fcap_one_is_rho_zero_limit` gives the constant-product endpoint at **`χ = 1/2`, `ε → 0`**.
  So `χ` is constant along Capponi's path **only when `pA = pB`** — and E1's own numeraire
  specialization sets `pB = 1`, `pA = p²`, which gives `χ = p²/(p²+1) ≠ 1/2` for every `p ≠ 1`.
  **Under the document's own numeraire convention Capponi's κ travels a DIAGONAL, moving BOTH axes**,
  not the ε axis alone. Either add the `pA = pB` hypothesis to the DIAGNOSIS line or restate it as a
  two-axis path. Defect in an already-approved block; same class as (e).

- **(j) `u` is called "the utilization factor" in the doc** — an interpretive name against the
  binding rule (the 'utilization' → `sigmoidR` precedent). Needs an authorship ruling before it is
  either swept or grandfathered.

## Gate

**Gate for the next unit of work:** (c) landed, and `232c8ee4` has returned a verdict.
Not "none — running": the first draft of this file wrote that, which is not a condition a reviewer
can discharge, and it exempted this track from its own rule.

## Greeks — unregistered work this phase now owns

`.planning/greeks/GREEKS-RESEARCH.md` (43 KB, 2026-07-31) and `ETATILDE-SUBMISSION.md` exist; doc
§G0–G6 is inserted with G6 listing live OPEN items and the Greeks Aristotle bundle declared
UNFORMALIZED. None of it appeared in ROADMAP.md, REQUIREMENTS.md, or any phase directory.
`EtaTilde.lean` is registered in the table above; the **Greeks bundle remains UNFORMALIZED and
unscheduled** — recorded here so it is visible rather than silently carried.

## Gate record

First draft reviewed 2026-08-03 by the Reality Checker and a project-management specialist, blind and
in parallel. Verdict **NEEDS WORK**. Every commit and Lean identifier cited was real — the failure was
scope: three defects sitting in the already-committed document were absent from a file whose stated
purpose is honest status, one edit certified "shippable alone" would have introduced a symbol
collision this file's own invariants forbid, and a landed 23-declaration module plus a 43 KB research
track were registered nowhere. Items (d)–(j) and the Greeks section are the response.

One reviewer figure was wrong and is corrected here: the addendum desync was reported as 59 stale
sites; the actual count is 155 (+7 in glyph form). The finding stands; the number did not.
