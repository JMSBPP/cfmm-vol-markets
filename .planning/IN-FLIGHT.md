# In-flight and parked work — the resume ledger

**READ THIS FIRST on any session resume, context compaction, or instance restart.**

Why this file exists: the phase files track work that is *being done*. Nothing tracked work that was
**handed off and waiting**, or **parked as a leaf**. That gap is how `EtaTilde.lean` landed with 23
declarations and appeared in no roadmap, how a 43 KB Greeks research track stayed invisible, and how
the θ exponent-sign FLAG sat blocking a definition while nobody was counting it. A phase file answers
"what are we doing"; this file answers **"what are we owed, and what will make us pick it up again."**

Every row carries a **RESUME TRIGGER** — the observable event that reactivates the item. An item with
no trigger does not belong here; give it one or close it.

---

## A. External work in flight (Aristotle)

> **CLI GOTCHA — this has cost time twice.** `aristotle show|tasks` return **HTTP 500 on short
> project ids**. Always pass the **full UUID**. `aristotle list` works and prints full UUIDs. A 500
> is almost never an outage — check `list` before concluding the API is down.

| Project (full UUID) | Name | Submitted | Targets | RESUME TRIGGER | On return |
|---|---|---|---|---|---|
| `1f6da52a-f998-471c-84b6-9130d8adbd25` | `aristotle-embed2` | 2026-08-03 | the two sorries left by the OUT_OF_BUDGET run: `canon_Fcap_not_CES` (interior verdict at κ=1/2) and `kappa_not_reparam_of_rho` | status leaves `IDLE`/returns a verdict | **Do not integrate blind.** Verify 0 sorries + axiom-clean; check the two PROVEN endpoint theorems came back byte-identical; then take the pre-decided branch in Phase 13 (b): embedding holds → redo E4 on the ε axis; refuted → close (b) MOOT and record E1–E7 as SHARE statements. Either way write the disposition into the phase summary. |

**Superseded, keep for provenance:** `232c8ee4-f99f-4b3c-a65b-0a26de76f5b1` (`aristotle-embed`) —
OUT_OF_BUDGET after 1h26m, 2-of-4 partial, downloaded to `scratch/embed-return/`. Its two proven
endpoint theorems are the working base of `1f6da52a`. **Never integrate this partial** (2 sorries).

---

## B. Parked leaves — real work, deliberately not being done now

| Item | Where it lives | Why parked | RESUME TRIGGER |
|---|---|---|---|
| ~~PR-SYNC: ETA addendum resync~~ | Ph 13 (d) | — | **CLOSED 2026-08-03** — resynced 1:1, disclosure extended, no new pin (per the 12-04 rule) |
| **E4 redo on the ε axis** | Ph 13 (b) | branch not yet decided | `1f6da52a` returns |
| **Item (k): the E1 DIAGNOSIS defect** | Ph 13 (k) | needs a doc edit | `PR-GATE` passes |
| **Item (i): PhiCES notation-map line** | Ph 13 (i) | needs a doc edit | `PR-GATE` passes |
| **Kristensen V0–V9 blocks** | Ph 14 | gated | `PR-WSIGMA` ruled **and** `PR-GATE` passes |
| **Doc definitional re-ordering** | Ph 12.1 | gated | HEAVY USER APPROVAL **and** `PR-THETA` ruled **and** `PR-CSYM` chosen |
| **Greeks bundle (G1 ladders, θ split, G4 deficit lemmas)** | Ph 15 | gated | `PR-CARRY` **and** `PR-THETA` ruled |
| **G2 skew law** | Ph 15 | off-bundle | E8(6) `η_L = η` closes (`PR-ETAL`) |
| **Occupancy `T_ITM/T`** | `.planning/occupancy/` | **REOPENED, rescoped** — the close-out rested on a false distinction (ours is user-controlled too) | a ruling on whether occupancy over an **implied, never-held** maturity `T★` is meaningful; modifier reading stays refuted (R4) |
| **Bunni-v2 LDF port** | G4 future milestone | declared out of scope | user opens the milestone |

---

## C. Awaiting a USER DECISION — nothing proceeds on these without a ruling

These are the cheapest items on the whole board: no research, no compute, no proving.

| id | The question | What it unblocks if answered |
|---|---|---|
| **PR-EPSTOL** | a symbol for the numerical tolerance that is **not** ε (elasticities), **not** σ (volatilities), **not** δ (Greeks) | `PR-GATE` → and through it FIVE parked doc items |
| **PR-ORIENT** | the canonical **argument order** of `φ` — machine evidence says `(Q_X, Q_M)` with χ on `Q_X`; Theorem 1 currently consumes the other order | `CC-REPL`, `CC-CURV`, and Phase 14's `u` relation |
| **PR-REGION** | are the `ΔQ` legs **signed**? the admissibility region is absent from the page | `CC-REPL` (Theorem 1 is ill-posed without it), Phase 14 |
| **PR-WSIGMA** | does `W` depend on σ? decides closed form vs fixed point | `CC-IV` / Phase 14 |
| **PR-THETA** | the θ exponent sign | `CC-GREEK` / Phase 15, and Phase 12.1 |
| **PR-CARRY** | per-event (M6b) vs time-integrated (λ_FLAIR) | Phase 15 — decides *what gets proved* |
| **PR-CSYM** | a free symbol pair for the replication weights (`c₁`/`c₂` are taken) | Phase 12.1 |

---

## Maintenance rules

1. **Hand-off creates a row.** Submitting an Aristotle bundle, dispatching a research agent, or
   parking an item adds a row here in the same action — not afterwards.
2. **Every row has a resume trigger.** No trigger ⟹ it is not parked, it is forgotten.
3. **Closing a row is explicit.** Move it to the phase summary with its disposition; do not delete.
4. **This file is read on resume**, before the roadmap — the roadmap says what the plan is, this says
   what is owed.
