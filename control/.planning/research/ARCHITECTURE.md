# Architecture Research

**Domain:** Verified control-design specification (document + machine-proof artifact, no implementation)
**Researched:** 2026-08-08
**Confidence:** HIGH on the Aristotle pipeline and peer/worktree ownership (read from on-disk evidence and run records); MEDIUM on the recommended document decomposition (an argued adaptation of one prior instance, not a validated pattern); MEDIUM-LOW on the EVM-feasibility content (the primitive inventory it must rest on is 6 weeks stale and this worktree's `src/` is a confirmed stale mirror).

---

## Standard Architecture

### System Overview

This project is not a software system. Its "architecture" is a **four-layer artifact
pipeline spanning three git worktrees**, only one of which this project owns.

```
┌───────────────────────────────────────────────────────────────────────────────┐
│  L0  SOURCE MATH               worktree: evm-controller  (THIS PROJECT OWNS)  │
├───────────────────────────────────────────────────────────────────────────────┤
│   notes/VOLATILITY_INTRUMENTS_MEV.md   — the event-time plant + boxed τ*_MEV   │
│   control/.planning/**                 — planning root (isolated by --cwd)     │
└───────────────────────────────┬───────────────────────────────────────────────┘
                                │  transcription + notation resolution
                                ▼
┌───────────────────────────────────────────────────────────────────────────────┐
│  L1  SPEC LAYER                worktree: evm-controller  (THIS PROJECT OWNS)  │
├───────────────────────────────────────────────────────────────────────────────┤
│  ┌────────────────┐ ┌───────────────────┐ ┌──────────────┐ ┌───────────────┐ │
│  │ CONTROL-FRAME  │ │ PROOF-OBLIGATIONS │ │ PROOF-LEDGER │ │ EVM-FEASIB.   │ │
│  │ (the math)     │ │ (what we ASK)     │ │ (what we GOT)│ │ (the law on   │ │
│  │                │ │  frozen at submit │ │  written at  │ │  the EVM)     │ │
│  │                │ │  + sha-pinned     │ │  landing     │ │               │ │
│  └────────────────┘ └─────────┬─────────┘ └──────▲───────┘ └───────────────┘ │
│                    ┌──────────┴──────────────────┴────────┐                   │
│                    │  TAU-MEV-SETPOINT-SPEC (consolidated) │                   │
│                    │  + GAP-REGISTER / HANDOFF             │                   │
│                    └───────────────────────────────────────┘                   │
└───────────────────────────────┬───────────────────────────────────────────────┘
                     PROOF-REQUEST │ hand-off (peer message)      ▲ ledger facts
                                ▼                                 │
┌───────────────────────────────────────────────────────────────────────────────┐
│  L2  PROOF LAYER               worktree: lean4-spec   (PEER PID 253818)       │
├───────────────────────────────────────────────────────────────────────────────┤
│   scratch/aristotle-<name>/RequestProject/  ──submit──►  Aristotle (external)  │
│                                             ◄─download──                       │
│   lean/vol_markets/<New>.lean  +  lean/lakefile.toml root                      │
│   .planning/IN-FLIGHT.md  §A row      model/vol_markets/LEAN_TRACEABILITY.md   │
└───────────────────────────────┬───────────────────────────────────────────────┘
                                │  summarization pass (LEAN notes + lemma cites)
                                ▼
┌───────────────────────────────────────────────────────────────────────────────┐
│  L3  HUMAN ENTRY POINT         worktree: plank        (PEER `ul2inqpl`)       │
├───────────────────────────────────────────────────────────────────────────────┤
│   notes/VOLATILITY_INSTRUMENTS.md   — new tagged blocks, minimal prose         │
│   notes/VOLATILITY_INSTRUMENTS_MEV.{tex,pdf}  — derived typeset twin           │
└───────────────────────────────────────────────────────────────────────────────┘
```

**The single most important structural fact:** this project owns L0 and L1 only.
Every step of L2 and L3 lands in another session's worktree. See §Integration Points.

### Component Responsibilities

| Component | Responsibility (owns, exclusively) | Does NOT own |
|-----------|------------------------------------|--------------|
| `CONTROL-FRAME.md` | The control-theoretic derivation. Frame selection (set-point optimization on a MIMO event-time plant with disturbance input). The transcribed plant `x, u_ex, u_en, y, Θ_σ`. The notation map incl. every collision resolution. The 5-factor channel as a *stated* claim. The replication relation and the algebra that produces the boxed `τ*_MEV`. | Proof status; any Lean name; any EVM statement |
| `PROOF-OBLIGATIONS.md` | P1–P4 as precise formal claims with **required declaration names**, the reuse map against landed Lean, the binding-notation section, hypothesis discipline, the anti-narrowing scoring rules, the fidelity checklist. This is the artifact the Aristotle prompt is generated from. **Frozen and sha-pinned at submit time.** | What came back; any verdict |
| `PROOF-LEDGER.md` | Verdicts only: per-obligation `PROVEN / CORRECTED / REFUTED / OPEN`, the landed declaration names, every added hypothesis, every narrowing, counterexample witnesses, the axiom sweep, build evidence, project/task UUIDs. **Written at landing time.** | What we asked for (that is frozen upstream); the math prose |
| `EVM-FEASIBILITY.md` | The on-chain object for `τ*_MEV`: term-by-term realizability, required fixed-point primitives (signatures only), saturation semantics, bounds/rounding, cost envelope, and an explicit statement of what is *unproven* here. | The derivation; the proofs; any Plank/Solidity code |
| `GAP-REGISTER.md` | G-numbered gaps, OPEN rows carried from the ledger, and the hand-off contract to the implementation milestone. | Anything already closed |
| `TAU-MEV-SETPOINT-SPEC.md` | Thin consolidation. Scope/layering, the frame in one paragraph, and `> Authoritative detail: [...]` pointers into the five docs above. Written LAST. | Any content that duplicates a detail doc |

**Non-overlap test applied:** the pair most at risk of overlap is
`PROOF-OBLIGATIONS` / `PROOF-LEDGER`. They are deliberately split because they have
different *lifetimes*, and the prior instance shows why: `12-02-RUN-RECORD.md`'s
"POST-SUBMIT: THE AMENDMENT LANDED EARLY — A TRAP" section records the live document
being edited 35 minutes after submission, so the bytes proved against no longer
existed anywhere on disk. Only a frozen, sha-pinned "what was sent" artifact makes the
landing check well-defined. Merging the two would reproduce exactly the error class
that record diagnoses.

---

## Assessment: what transfers from the v2-controller (spatial-axis) decomposition

The sibling project shipped 13 documents, of which 4 are the spec proper
(`STATIC-CONTROL-KERNEL-SPEC.md` = SPEC-01, `ON-CHAIN-REALIZATION.md` = SPEC-02,
`C2-PROOF-CASE.md` = SPEC-03, plus a deferred SPEC-04 review) and 9 are research
surveys (`LIT-*`, `*-MAP`, `CONTROLLERS.md`, `TOOLING-CONTROL-DSL.md`,
`MAPPING-SYNTHESIS.md`).

### TRANSFERS

| What | Evidence it worked | How it applies here |
|------|--------------------|---------------------|
| **Thin consolidated doc + authoritative detail siblings** | `STATIC-CONTROL-KERNEL-SPEC.md` §4 and §7 are explicit stubs carrying `> **Authoritative detail: [ON-CHAIN-REALIZATION.md] (SPEC-02)**` and `[C2-PROOF-CASE.md] (SPEC-03)`; each detail doc closes with a `## Traceability` section citing back by `file §section`. The header records the set as CONTENT-COMPLETE. | Adopt verbatim as the L1 shape. `TAU-MEV-SETPOINT-SPEC.md` delegates; the five detail docs are authoritative. |
| **`ON-CHAIN-REALIZATION.md`'s internal skeleton** | Six sections in a fixed order: name the on-chain object → per-entry closed-form table (formula / primitives used / source theorem) → required primitives that do not exist, *signatures only* → the hard rule with concrete consequences → bounds + rounding table → traceability. | Adopt the skeleton for `EVM-FEASIBILITY.md`. The *content* is completely different (see §EVM-feasibility below) but the skeleton is the right shape for "design that stops before code." |
| **Saturate-never-revert as a stated hard rule, not a footnote** | Stated three times across `CONTROLLERS.md` framing, `EVM-CONTROL-PRIMITIVES-MAP.md` §4, and `ON-CHAIN-REALIZATION.md` with a real precedent (`CESLongPayoff.plk:42`, `*%` overflow at ~2^192). | Transfers directly and is *more* load-bearing here: `τ*` has two poles and can go negative (below). |
| **"The controller is defined only where its proof holds"** | `C2-PROOF-CASE.md` §Feasibility preconditions: Aristotle *narrowed* `d² ≤ σ_target` to strict `σ_target > d²` because the non-strict form lets the root collapse to `Δi = 0`, and the narrowed form is what the controller is defined on. | Transfers as a *discipline*, and it is the expected outcome class for P1 and P4. It needs a home — that home is `PROOF-LEDGER.md`, not a proof-case doc. |
| **Signatures-only discipline for missing primitives** | SPEC-02 §"Required fixed-point primitives to build (gap G5)" gives three signatures and zero implementations, explicitly labelled "this is design, not implementation." | Transfers directly. |

### DOES NOT TRANSFER

| What | Why not — specifically |
|------|------------------------|
| **`C2-PROOF-CASE.md` as a document type** | Its purpose was to run ONE **already-proven** inversion across FOUR **tool** stages (SymPy → Lean → Plank → gamsDiff). Three of the four premises fail here. (a) The Lean theorem already existed — `sigma_xs_poly_target_exists` at `eta.lean:560`; here proving *is* the project. (b) It is one case; here there are four obligations with a halt gate between them. (c) Stages 3 and 4 are out of scope by PROJECT.md (no implementation) and stage 4 additionally has no GAMS reference — there is no GAMS model of the event-time plant, and GAMS is peer-owned. **Replace it with `PROOF-LEDGER.md`,** whose real ancestor is not SPEC-03 but lean4-spec's `12-03-FIDELITY.md` + `model/vol_markets/LEAN_TRACEABILITY.md` (which already defines the four statuses PROVEN/CORRECTED/REFUTED/OPEN). |
| **`CONTROLLERS.md` (the 10-controller catalog + readiness ranking)** | v2 had a *menu* of static target→actuator maps over a 241-node lattice, so a catalog with a readiness column was the right object. This project has exactly **one** law, `τ*_MEV`. There is nothing to rank. The structural analogue is not a catalog but a **channel decomposition** — the five factors of `∂π̂^σ/∂τ_MEV` — which belongs inside `CONTROL-FRAME.md`. |
| **The GAMS leg entirely** (`GAMS-MAP.md`, the `gamsDiff` stage, EPS ≈ 1e-15 tolerances) | No GAMS model of the event-time plant exists, and `model/*.gms` is owned by PID 175812. Importing this leg would manufacture a cross-boundary dependency for no deliverable. |
| **The 9 research surveys as spec components** | They are research-phase outputs (this document's siblings), not deliverables. The event-time analogues are being produced now. |
| **`LEAN-MAP.md` as a reusable inventory** | It is **stale and would mislead**. It states "There is exactly **one** Lean source file in the entire repo" and "No other `*.lean` anywhere." As of today `lean/vol_markets/` alone holds **23** `.lean` files (`lakefile.toml` registers 23 `vol_markets` roots plus 14 `exp` and 8 `tao`), including every module this project must reuse (`TauMevAlgebra`, `MevOptimization`, `MevJointProgram`, `VolInstrument`, `FlairOptimization`, `JitLiquidity`, `TauJit`). Re-derive the reuse map from `lean/lakefile.toml` at bundle-assembly time; do not import v2's. |
| **`EVM-CONTROL-PRIMITIVES-MAP.md` as a current inventory** | Two independent staleness signals. (a) Its own worktree note already warns "this `evm-controller` worktree's `src/` is a *stale mirror*"; verified today — this worktree has `src/{exp,ldf,MarketState.plk,ReferenceMarket.plk,lib/{BinomialProxy,SwapAmtGen,TickUtils}}` while `cfmm-wt/plank/src/` has `{interfaces,lib,modules,types}` — a different tree, not a superset. (b) It is dated 2026-06-28. The *primitive classes* it names (u256-only substrate, `mulDiv`, `tick_math`, no signed mul/div, no clamp, no WAD `exp`/`ln`/`pow`) are still the right questions, but every citation must be re-verified against `cfmm-wt/plank` before it enters `EVM-FEASIBILITY.md`. |
| **Deferring the two-step review** | SPEC-01's header still reads "The **single remaining gate is the mandatory two-step review (SPEC-04)** … **DEFERRED by user choice** … and owed before any execution commit." That debt is still open six weeks later. PROJECT.md already rules this out; the roadmap must place the gate *before* execution, per plan, not after. |

---

## Recommended Project Structure

```
control/.planning/                          # planning root — GSD runs with --cwd control
├── PROJECT.md
├── research/                               # THIS phase (SUMMARY/STACK/FEATURES/ARCHITECTURE/PITFALLS)
├── ROADMAP.md
├── phases/<n>-<slug>/                      # per-phase plans, reviews, run records
└── spec/                                   # THE DELIVERABLE
    ├── TAU-MEV-SETPOINT-SPEC.md            # consolidated; written LAST; delegates
    ├── CONTROL-FRAME.md                    # the derivation (math prose owner)
    ├── PROOF-OBLIGATIONS.md                # P1–P4 formal statements; frozen + sha-pinned
    ├── PROOF-LEDGER.md                     # verdicts; written at landing
    ├── EVM-FEASIBILITY.md                  # the on-chain object
    └── GAP-REGISTER.md                     # gaps + implementation-milestone hand-off
```

Two artifacts live *outside* `spec/` because they are process records, not deliverables:

```
control/.planning/phases/<n>/<n>-<m>-RUN-RECORD.md   # PROMPT-SHA256, BUNDLED-*-SHA256,
                                                     # the exact submit command, queue evidence,
                                                     # UUIDs, the module-origin map
control/.planning/phases/<n>/<n>-<m>-PROMPT-REVIEW.md # the two-step reviewer gate output
```

Both are copied from lean4-spec's phase-12 shape, which is the only worked instance
of this pipeline on record (`12-02-RUN-RECORD.md`, `12-02-PROMPT-REVIEW.md`,
`12-03-PARTIAL-RETURN.md`, `12-03-FIDELITY.md`, `12-03-SUMMARY.md`).

### Structure Rationale

- **`spec/` separate from `research/`:** v2 mixed 4 spec docs and 9 research docs in one
  flat `research/v2-controller/` directory, which is why its own consolidated doc has to
  spend a paragraph listing which of its siblings are authoritative. Separating them
  makes "what is the deliverable" answerable by `ls`.
- **`PROOF-OBLIGATIONS` and `PROOF-LEDGER` as siblings, not sections:** see the
  lifetime argument above.
- **`RUN-RECORD` outside `spec/`:** the sha pins and UUIDs are provenance for a *process*,
  and `scratch/` (where the bundle actually lives) is gitignored in lean4-spec
  (`.gitignore:59`), so the run record is the only durable evidence of what was sent.

---

## The Aristotle Pipeline

> **Evidence basis.** Everything in this section was read off disk, not assumed. Directories
> and files inspected:
> `cfmm-wt/lean4-spec/scratch/` (36 entries; 20 `aristotle-*` submission dirs, 8 `*-result/`
> return dirs, 8 `*-result.tar.gz` archives, 20 `*-PROMPT.txt` files);
> `scratch/aristotle-tau-mev/` and `scratch/aristotle-mev-joint/` (submission layout);
> `scratch/aristotle-tau-mev-PROMPT.txt` (prompt format, quoted below);
> `scratch/mev-joint-result/aristotle-mev-joint_aristotle/` (return layout) and its
> `ARISTOTLE_SUMMARY.md`;
> `.planning/IN-FLIGHT.md`;
> `.planning/phases/12-eta-tradeoff-optimum/{12-02-RUN-RECORD.md, 12-03-PARTIAL-RETURN.md, 12-03-SUMMARY.md}`;
> `lean/lakefile.toml`; `lean/vol_markets/`; `lean/vol_markets/Main.lean`;
> `model/vol_markets/LEAN_TRACEABILITY.md`;
> plus `aristotle {submit,continue,download} --help` from the installed CLI
> (`/home/jmsbpp/.local/bin/aristotle`).
> Anything the evidence does not show is marked **NOT EVIDENCED**.

### Bundle layout (verified on two submission dirs)

```
scratch/aristotle-<name>/
├── lean-toolchain          # leanprover/lean4:v4.28.0
├── lakefile.toml           # globs RequestProject.+ → a NEW module needs no root entry
├── lake-manifest.json      # pins mathlib at the toolchain rev; the server resolves it
└── RequestProject/         # FLAT — no subdirectories
    ├── <every module in the import closure>.lean   # imports rewritten to RequestProject.X
    ├── VOLATILITY_INSTRUMENTS.md                   # frozen copy of the entry-point doc
    └── <TOPIC>_ADDENDUM.md                         # the block-scoped spec being formalized
```

`aristotle-tau-mev/RequestProject/` holds 13 `.lean` + `VOLATILITY_INSTRUMENTS.md` +
`TAU_ADDENDUM.md`. `aristotle-mev-joint/RequestProject/` holds 12 `.lean` +
`VOLATILITY_INSTRUMENTS.md`. The bundle is **flat**: `vol_markets/X.lean` becomes
`RequestProject/X.lean`, so on return the inverse rewrite is **non-uniform** —
`RequestProject.eta → exp.eta` but `RequestProject.VolInstrument → vol_markets.VolInstrument`.
`12-02-RUN-RECORD.md` records the module-origin map for exactly this reason and warns
that a blanket `s/RequestProject\./vol_markets./` yields `import vol_markets.eta`, which
does not exist.

### Prompt format (from `scratch/aristotle-tau-mev-PROMPT.txt`)

One plain-text file, five parts, in this order:

1. **Target imperative.** "FORMALIZE the … specified in `RequestProject/<X>_ADDENDUM.md`
   … into a NEW file `RequestProject/<Name>.lean`. You author both statements AND complete
   proofs: no `sorry`, no `admit`, axiom-clean (only `propext`, `Classical.choice`,
   `Quot.sound`). Do NOT modify any of the N existing .lean files. Whole project must
   `lake build`."
2. `== Reuse map (do NOT redefine) ==` — names the existing declarations to build on.
3. `== Binding notation ==` — "Doc symbols only … No interpretive names."
4. `== The theorem set (prove EXACTLY these claims …) ==` — each claim gets a **required
   declaration name** (`tau_monoid_mem`, `tau_no_targeting`, …) and a one-line statement.
5. **Hypothesis discipline** — "every added hypothesis … goes in the docstring AND the
   final summary. Final summary lists every theorem name with a one-line claim."

### Return layout (verified on `mev-joint-result/`)

```
scratch/<name>-result/aristotle-<name>_aristotle/
├── ARISTOTLE_SUMMARY.md    # what was completed + an explicit verification statement
├── README.md
├── lean-toolchain, lakefile.toml, lake-manifest.json
└── RequestProject/         # all inputs (expected byte-identical) + the NEW module
```

`ARISTOTLE_SUMMARY.md` for `MevJointProgram` ends with a verification block:
"builds successfully / No `sorry`, `admit`, new axioms, or `implemented_by` remain / Key
results were checked to use only `propext`, `Classical.choice`, and `Quot.sound`."
Note the double nesting `<name>-result/aristotle-<name>_aristotle/` — this is the
"extracts one directory deeper than expected" gotcha recorded in `12-02-RUN-RECORD.md`.

### The sequence (11 steps)

| # | Step | Evidence |
|---|------|----------|
| 1 | **Freeze the spec block** and compute a **section-scoped** sha256 (delimited by end markers), never a whole-file hash. | `12-02-RUN-RECORD.md` "Doc-fidelity gate": the live whole-file hash moved twice during the run while the section hash never moved. "**A WHOLE-FILE MISMATCH IS EXPECTED AND IRRELEVANT — the section diff is the gate.**" |
| 2 | **Two-step reviewer gate on the PROMPT** (Reality Checker + one specialist, independent OS processes, in parallel, blind). Fix every BLOCKER/MAJOR before submitting. | `12-02-RUN-RECORD.md` "Reviewer gate": both NEEDS WORK, 2 BLOCKER / 1 MAJOR / 11 MINOR, all BLOCKER+MAJOR fixed pre-submit; the recorded `PROMPT-SHA256` is the post-fix artifact. |
| 3 | **Assemble the bundle** — toolchain + lakefile + manifest + **every module in the import closure**, flattened, imports rewritten. Prove the closure; do not estimate it. | `12-02`: "12-RESEARCH F7.3 proposed 15 modules and missed [`CESLongVolPayoff`], and without it `EtaReplication` does not elaborate." |
| 4 | **Record the module-origin map** (module → `exp` \| `vol_markets`) for the return rewrite. | `12-02-MODULE-MAP.txt`, reproduced inline in the run record. |
| 5 | **Write the RUN-RECORD before submitting**: `PROMPT-SHA256`, `BUNDLED-*-SHA256`, the exact command. | `12-02-RUN-RECORD.md` header block. |
| 6 | **Check the queue** with `aristotle list --limit N` — it prints full UUIDs and shows whether the target project is IDLE. **Never `aristotle show`.** | `12-02`: "`aristotle show` STREAMS AND BLOCKS — 11-02 hung a two-minute call on it." |
| 7 | **Submit exactly once**: `aristotle submit --project-dir scratch/aristotle-<name> --api-key "$(grep -m1 '^ARISTOTLE_API_KEY=' .env \| cut -d= -f2-)" "$(cat scratch/aristotle-<name>-PROMPT.txt)"` → prints `Project created: <UUID>`. | Verbatim from `12-02-RUN-RECORD.md`; `.env` is present in `cfmm-wt/lean4-spec/` and contains `ARISTOTLE_API_KEY`. |
| 8 | **Add an IN-FLIGHT row in the same action** — project full UUID, name, date, targets, RESUME TRIGGER, on-return instruction. | `IN-FLIGHT.md` maintenance rule 1: "Hand-off creates a row … in the same action — not afterwards." |
| 9 | **Poll** with `aristotle tasks <FULL-UUID>`. Terminal states observed on record: `COMPLETE`, `COMPLETE_WITH_ERRORS` (cosmetic), `OUT_OF_BUDGET`. | `IN-FLIGHT.md` §A rows; `12-03-PARTIAL-RETURN.md`. |
| 10 | **Download and gate before integrating.** Six gates, all on record: (a) input integrity — every bundled module byte-identical, proving the prover touched nothing outside its target; (b) the returned bundled doc vs `BUNDLED-*-SHA256`, **never** vs the live file; (c) zero `sorry`/`admit`; (d) `#print axioms` sweep → only `propext`/`Classical.choice`/`Quot.sound`; (e) the returned **declaration LIST** (not count) vs the fidelity checklist; (f) full `lake build` against the current tree. | (a) `12-03-SUMMARY.md` "all 18 bundled modules byte-identical"; (b) `12-02` post-submit trap section; (c)–(f) `12-03-SUMMARY.md` verification table (`lake build` exit 0, 8067 jobs) and `12-03-PARTIAL-RETURN.md`. |
| 11 | **Integrate**: inverse import rewrite *by map*, drop into `lean/vol_markets/`, **append** the root to `lean/lakefile.toml`, build, commit, push `origin` + the `cfmm-lean4-spec` mirror, then write `LEAN_TRACEABILITY.md` rows and close the IN-FLIGHT row. | `12-03-SUMMARY.md` task commits + "Remotes" paragraph; `LEAN_TRACEABILITY.md` §13. |

### Operational constraints (all evidenced; violating these has already cost time)

- **Full UUIDs are mandatory.** `aristotle show|tasks` return **HTTP 500 on short project
  ids**. `aristotle list` works and prints full UUIDs. *"A 500 is almost never an outage —
  check `list` before concluding the API is down."* (`IN-FLIGHT.md` §A, flagged as having
  "cost time twice".)
- **Never run parallel `aristotle continue` on the SAME project.** The mechanism is visible
  in the CLI: `continue` takes `--files [FILES ...]` which upload into the project, so
  concurrent continues overwrite each other. **Parallel `submit` to NEW projects is
  explicitly sanctioned** — `12-02-RUN-RECORD.md` records two other live projects
  (`aristotle-jit` `610bb259`, `aristotle-tau-mev` `7ffb3a29`) at submit time and states
  "the serial-queue rule is per-project, and parallel submits to new projects are
  user-sanctioned."
- **On `OUT_OF_BUDGET`, run a single `continue` on the SAME project** — not a fresh scoped
  submit. `IN-FLIGHT.md` §A states this as the standing on-return rule ("OUT_OF_BUDGET ⟹
  `continue` on the SAME project"), and `12-03-PARTIAL-RETURN.md` confirms "the standing ban
  is on PARALLEL `continue`, not a single one." *Recorded deviation:* 12-03 instead submitted
  a **scoped repair bundle as a new project** (`c3a617f3…`) on explicit user instruction
  (`submit eta -b`), carrying the partial as the working base and a prompt scoped to the 15
  sorried declarations only. Both routes are on record; the single `continue` is the default,
  the repair bundle is a user-authorized alternative.
- **Never integrate a sorry-carrying partial, and never hand-prove the gap.**
  `lean/vol_markets/` requires sorry-free, axiom-clean modules; `12-03-PARTIAL-RETURN.md`:
  "Hand-proving locally is barred (workflow rule: Aristotle authors statements AND proofs)."
  The 36/51 partial was preserved in gitignored `scratch/` and *not* integrated.
- **`aristotle show` streams and blocks.** Use `tasks` and `list`.
- **`aristotle download --destination` writes an ARCHIVE FILE, not a directory**, and
  extracts one directory deeper than expected. Confirmed on disk by the
  `<name>-result/aristotle-<name>_aristotle/` nesting.
- **A returned theorem carrying a requested NAME while proving something weaker is a
  NARROWING and scores as a MISS**, not a hit. Added *disclosed* hypotheses are expected
  behaviour and score as hits. (`12-02-RUN-RECORD.md` "Scoring rules for 12-03".)
- **The "no `.lake` folder" warning is expected and benign** — record it, do not suppress
  it. Bundles carrying it have returned building, axiom-clean modules.
- **Toolchain pin:** `leanprover/lean4:v4.28.0`, mathlib `v4.28.0` (`lean/lakefile.toml`).
  **LeanEVM was removed 2026-07-16** with the comment "Restore both together when on-chain
  proofs begin." Consequence for this project: **no fixed-point / `UInt256` reasoning is
  available in-tree**, so nothing in `EVM-FEASIBILITY.md` can be proof-backed.
- **`scratch/` is gitignored** (`.gitignore:59`). Bundles and returns are not versioned; the
  RUN-RECORD hashes are the only durable provenance.
- **NOT EVIDENCED:** wall-clock turnaround is not instrumented anywhere. `12-03-SUMMARY.md`
  explicitly says "the two Aristotle runs' own wall time is not included and was not
  instrumented." Observable spans in `IN-FLIGHT.md` range from ~2h (`aristotle-tol-slip`,
  "COMPLETE in 2h4m") to `OUT_OF_BUDGET` after 1h26m. Do not plan against a promised SLA.

---

## Data Flow

### A claim's full path, source math → entry-point doc block

```
[1] SOURCE MATH               notes/VOLATILITY_INTRUMENTS_MEV.md          (evm-controller)
        │  transcription: preserve notation exactly; resolve every collision
        │  ⚠ GATE: user ruling on any new/colliding symbol before proceeding
        ▼
[2] FRAMED CLAIM              spec/CONTROL-FRAME.md                        (evm-controller)
        │  formalization: assign required declaration names, reuse map, hypothesis list
        ▼
[3] FORMAL OBLIGATION         spec/PROOF-OBLIGATIONS.md  ──► frozen, sha-pinned
        │  ⚠ GATE: two-step reviewer gate (Reality Checker + specialist, parallel)
        │  prompt generation + bundle assembly            (→ lean4-spec, peer-owned)
        ▼
[4] SUBMISSION                scratch/aristotle-<n>/RequestProject/        (lean4-spec)
        │  aristotle submit  ──────────────►  Aristotle (external service)
        │                    ◄──────────────  COMPLETE | COMPLETE_WITH_ERRORS | OUT_OF_BUDGET
        ▼
[5] RETURN + GATES            6 gates (input integrity, sha, 0 sorry, axioms, decl list, build)
        │  ⚠ HALT if OUT_OF_BUDGET → single `continue`, do NOT integrate the partial
        ▼
[6] INTEGRATED PROOF          lean/vol_markets/<New>.lean + lakefile root  (lean4-spec)
        │                     model/vol_markets/LEAN_TRACEABILITY.md rows
        ▼
[7] SPEC CITATION             spec/PROOF-LEDGER.md  ──► verdict + declaration names
        │                     spec/CONTROL-FRAME.md gains LEAN footers          (evm-controller)
        │  ⚠ GATE: user-approved summarization pass
        ▼
[8] ENTRY-POINT BLOCK         notes/VOLATILITY_INSTRUMENTS.md new tagged blocks   (plank)
                              notes/VOLATILITY_INSTRUMENTS_MEV.{tex,pdf} regenerated
```

**The loop closes at [8] and feeds back to [2]:** a REFUTED or CORRECTED verdict changes the
math, so `CONTROL-FRAME.md` is edited, not just annotated. Precedent: `LEAN_TRACEABILITY.md`
defines `CORRECTED` as "doc claim was wrong; the true statement is proven," and
`IN-FLIGHT.md` carries "doc block M6b must change OPEN → FALSE" as an owed edit.

### Where new blocks land in the entry-point doc

Read from `cfmm-wt/plank/notes/VOLATILITY_INSTRUMENTS.md` (157 KB, 1636+ lines) as it
stands today:

- **Section/tag pattern.** Each new topic opens its own `##` section with its own tag
  family, and the first block of every family is a `[x0] NOTATION-MAP`:
  `## JIT` → `[J0]…[J9]`; `## GREEKS` → `[G0]…[G6]`; `### MEV` → `[M0]…[M10]`;
  `# BEHAVIOR_WELFARE_UTILIZATION` → `[E0]…[E8]`.
- **Recommendation:** this project's output is a *distinct object* (an event-time state-space
  plant plus a set-point law), not a further identification of `λ_MEV`. Follow the doc's own
  growth pattern — **open a new `##` section with a new tag family** (e.g. `[C0]` NOTATION-MAP,
  `[C1]` plant, `[C2]` channel, `[C3]` sign, `[C4]` set-point law) rather than extending
  `[M11]+`. Extending `[M#]` is the fallback if the user prefers it; either way the choice is
  a user ruling, not a researcher's.
- **Statement numbering is GLOBAL across the whole document**, not per-section. As observed
  today the high-water marks are Definition 31, Theorem 27, Rule 12, Convention 6,
  Proposition 10. The document is **live and under concurrent edit** (its whole-file hash
  moved twice mid-run in the 12-02 record), so numbers must be re-read at write time, never
  cached from research.
- **Block anatomy** (observed): bold `**Class N (Title) [TAG].**` → the display math →
  `GUARD:` / `REQUIRES:` line → a `*Status:*` or provenance footer naming the Lean carriers
  and the Aristotle project UUIDs. Example footer on record: "Provenance: `EtaCurvature`
  51/51 axiom-clean (projects `4878ca32` + repair `c3a617f3`)".
- **Derived artifact:** `notes/VOLATILITY_INSTRUMENTS_MEV.tex` (97 KB) is a *faithful
  typesetting of the markdown source* ("content, notation, and statement numbering are
  verbatim") with a `.pdf` twin. It is plank-owned and must be regenerated after any block
  lands. It does **not** contain this project's state-space derivation — verified by grep;
  there is no source-of-truth conflict, only a regeneration obligation.

---

## Architectural Patterns

### Pattern 1: Freeze-and-pin before any external spend

**What:** Every artifact that crosses a boundary (to Aristotle, to a reviewer, to a peer) is
byte-frozen and hashed *before* it crosses, and the hash is recorded in a run record.
**When to use:** every Aristotle submission; every peer hand-off.
**Trade-offs:** costs a step and a file; buys the ability to answer "what did we actually
send" after the live source has moved on — which it will, because three sessions edit
concurrently.
**Precedent:** `12-02-RUN-RECORD.md` records `PROMPT-SHA256`, `BUNDLED-ETA-SHA256`,
`BUNDLED-DOC-SHA256`, and then documents the live doc moving 35 minutes after submit while
the pinned copy stayed valid.

### Pattern 2: Section-scoped fidelity gate, never whole-file

**What:** Compare an end-marker-delimited *section* hash, not the file hash.
**Why:** the entry-point doc is under concurrent multi-session edit. A whole-file mismatch is
the normal state of the world and carries no information.
**Anti-pattern it replaces:** treating a legitimate downstream edit as payload corruption —
diagnosed once already (11-04) and re-diagnosed in 12-02.

### Pattern 3: Ask-artifact and got-artifact are separate documents

**What:** `PROOF-OBLIGATIONS.md` (frozen at submit) and `PROOF-LEDGER.md` (written at
landing) never merge.
**When:** whenever an external prover authors both statements and proofs, so the returned
statements may legitimately differ from the requested ones (added hypotheses = hit;
narrowing = miss).
**Trade-offs:** two documents to maintain; but merging destroys the only basis on which
"narrowing vs. disclosed hypothesis" can be adjudicated.

### Pattern 4: A refutation is a deliverable, not a failure

**What:** `PROOF-LEDGER.md` carries `REFUTED` as a first-class terminal status with the
counterexample witness recorded inline.
**Precedent:** the repo has three machine-refutations on record with witnesses —
T24 (`mev_ge_flat_under_flair_budget_false`, "flat 31/22 > tilted 4/3"),
`canon_Fcap_not_CES` (the Capponi–CES interior embedding), and
`sandwich_fee_hurdle_false` (30bp witness). PROJECT.md's Core Value says the same thing:
"A refutation is a successful outcome; an unverified restatement is not."

### Pattern 5: The design spec stops at signatures

**What:** required-but-missing on-chain primitives are specified by *signature + scale
convention + rounding mode + why it's needed*, with zero implementation.
**Precedent:** SPEC-02 §"Required fixed-point primitives to build (gap G5)" — three
signatures, explicitly "this is design, not implementation."

---

## EVM-Feasibility Analysis: what it structurally contains

Skeleton inherited from `ON-CHAIN-REALIZATION.md`; content derived from the boxed law itself.

**The law** (`notes/VOLATILITY_INTRUMENTS_MEV.md`):

```
τ*_MEV = 1 − (1/ΔQ_v*) · [ Σ_{i_K} π^l(σ(i_K;·)) · ∂L(i_K)/∂π^φ ]
                        · [ ΔQ_M/(1−φ_X) + p_(η,Δ_i)·ΔQ_X/(1−φ_M) ]
                        · (∂φ/∂ν) · (∂ν/∂τ_MEV)
```

### §1 — The on-chain object

Not a matvec. `τ*_MEV` is a **single scalar in [0,1]** written to a fee/tax parameter. The
evaluation is one bounded accumulation over the strike-tick set `i_K`, one two-term bracket
with two guarded divisions, and two constant gain multiplies. State this explicitly, because
the v2 anchor's object (a 241-node banded Toeplitz matvec) is *not* the analogue and importing
its cost model would be wrong.

### §2 — Term-by-term realizability table

| Term | On-chain status | The concrete issue |
|------|-----------------|--------------------|
| `Σ_{i_K} π^l(·)·∂L(i_K)/∂π^φ` | **The biggest open question** | An unbounded loop inside `beforeSwap` is a gas-DoS surface. Two exits: (a) collapse to a closed form — the C9 precedent, "Lattice recursion collapsed to closed form (no binomial rollback needed)", so the operator never iterates on-chain; (b) hard-cap `#_σ` and state the cap in the spec. Must be decided in the spec, not left to the implementer. |
| `1/(1−φ_X)`, `1/(1−φ_M)` | **Two poles** | `mulDiv` reverts on `denom == 0` — and a reverting hook DoSes the swap. Requires a bound `φ ≤ φ̄ < 1` sourced from `Θ_φ`'s own constraints, plus a pre-call guard. Note `φ_X(t) = Φ(Θ_φ; σ²(i(t)))` is the sigmoid `multiFee` family, so the bound is a property of `Θ_φ`, not a free choice. |
| `p_(η,Δ_i)` | Available via tick basis | `getSqrtRatioAtTick` / `getTickAtSqrtRatio` are the only `exp`/`log` analogues in the tree (base 1.0001). There is **no WAD `exp`/`ln`/general `pow`** in Plank — no PRBMath/solady equivalent. Any formulation needing one is infeasible as stated. |
| `∂φ/∂ν`, `∂ν/∂τ_MEV` | **Design decision required** | These are derivatives of behavioural relations, not observables. The v2 doctrine — "treat the EVM as an *evaluator of a precompiled constant-gain* controller, not a solver" — says: ship them as off-chain-quantized constants. The source already assumes `Ḡ_(ν,λ_MEV)` constant. This is also *why a sign result (P3) suffices*: a constant gain only needs its sign and magnitude pinned off-chain. |
| `1/ΔQ_v*` | User input | Guard against 0 before `mulDiv`. |
| `1 − (…)` | **Signedness + range** | `∂L/∂π^φ` may be negative and Plank is u256-only with signed ops as explicit builtins; `mulDiv` is unsigned. The product can exceed 1, so **`τ*` can come out negative**. Saturation to `[0,1]` is mandatory, and its *semantics* (`τ* < 0` ⟹ the replication target is unreachable by taxing) is a spec decision, not an implementation detail. |

### §3 — Required primitives (signatures only)

Inherits gap **G5** unchanged from SPEC-02 — `signedMulDiv(a,b,denom)` (the "#1 correctness
hazard"), `clamp(x,lo,hi)`, `satAdd(x,y)`; none exist in Plank. Worth stating as a positive
finding: unlike C2, **`τ*_MEV` needs no fixed-point `sqrt`** — the whole `sqrt`/`disc` branch
of the v2 primitive gap does not apply.

### §4 — Saturate-never-revert, restated for this law

Same hard rule, sharper here because the law has two poles, a possible negative output, and a
loop. Concretely: clamp `τ*` into `[0,1]`; guard both `(1−φ)` denominators and `ΔQ_v*` before
any `mulDiv`; one consistent WAD scale with a `/WAD` per multiply; clamp accumulators before
they can reach ~2^192 (`CESLongPayoff.plk:42` precedent).

### §5 — Bounds, rounding, cost envelope

Round-toward-zero for `</` and `mulDiv`; keep intermediate scale high and downcast once. Cost
stated as a **function of `#_σ`**: roughly `|i_K|` multiply-accumulates + ~4 `mulDiv` + 2
guarded divisions. Anchor for comparison: the v2 `n=3` matvec is ~9 `mulDiv`, "low thousands
of gas, trivially affordable inside `beforeSwap`" — so the loop is the only term that can
leave that envelope.

### §6 — Honesty section (mandatory)

Two disclosures, both evidenced:
1. **Nothing here is proof-backed.** LeanEVM is removed from `lean/lakefile.toml`; v2's own
   Lean map says of fixed-point numeric bounds "NOTHING. All math is over exact ℝ." Every
   EVM claim in this document is an engineering judgement.
2. **The primitive inventory must be re-verified against `cfmm-wt/plank`**, not against this
   worktree's `src/` (confirmed stale mirror) and not against the 2026-06-28 map.

---

## Build Order

### Dependency graph (acyclic)

```
        ┌──────────────────────────────────────────────┐
        │ A. FRAME + TRANSCRIPTION + NOTATION RULINGS  │  no external spend
        │    exit: USER APPROVAL + sha-pin             │
        └───────┬──────────────────────────────┬───────┘
                │                              │
                ▼                              ▼
   ┌────────────────────────┐      ┌───────────────────────────┐
   │ B. P1 well-posedness   │      │ E0. primitive-inventory   │
   │    + P2 5-factor       │      │     refresh (read-only,   │
   │    ONE bundle          │      │     vs cfmm-wt/plank)     │
   └───────┬────────────┬───┘      └─────────────┬─────────────┘
           │            │                        │
     P2 REFUTED         │ P2 holds               │
           │            ▼                        │
           │   ┌──────────────────────┐          │
           │   │ C. P3 sign + the     │          │
           │   │    τ ↔ λ bridge      │          │
           │   └──────────┬───────────┘          │
           │              ▼                      │
           │   ┌──────────────────────┐          │
           │   │ D. P4 boxed form     │          │
           │   │    (statement only   │          │
           │   │     writable after   │          │
           │   │     B and C return)  │          │
           │   └──────────┬───────────┘          │
           │              ▼                      │
           │   ┌──────────────────────┐          │
           │   │ E1. EVM feasibility  │◄─────────┘
           │   │     of the VERIFIED  │
           │   │     form             │
           │   └──────────┬───────────┘
           │              ▼
           │   ┌──────────────────────────────────┐
           └──►│ F. CONSOLIDATE + GAPS + HAND-OFF │
               │    + doc block summarization pass│
               └──────────────────────────────────┘
```

### Why this order

**A first, and it is not optional.** Two hard transcription blockers exist in the source and
neither can be resolved by a researcher:

1. **`π^{\varphi}` is a symbol collision.** The source derivation writes
   `π^{\varphi} ≡ π^{\phi} − π^{LVR}`. But the entry-point doc already binds
   `π^{\varphi}(p_{\varphi}) ≡ p_{\varphi}·Q_X^L + Q_M^L` — the portfolio value function, the
   conic dual of the trading function (Angeris et al.), status UNFORMALIZED — and its MEV
   section explicitly warns the fee-income payoff `π^{\phi}` is "DISTINCT from `π^{\varphi}`,
   the trading-function glyph, per the standing `\phi`/`\varphi` split." The doc further binds
   "bare `\varphi` is NOT used." So the source uses a reserved glyph for a different object.
   Under the binding notation rule (external symbol conflicts get NEW symbols, recorded in a
   notation-map paragraph, and **no new symbol is minted without discussing it first**), this
   is a user ruling and it gates everything downstream.
2. **`τ` vs `λ`.** P3 as stated in PROJECT.md is a claim about `∂ν/∂λ_MEV`, but the 5-factor
   channel consumes `∂ν/∂τ_MEV`. These are different objects: `λ` is a hazard, `λ̃` is the
   incidence operator, and `τ_MEV` enters the trader-paid fee through the proven Abelian
   monoid (`TauMevAlgebra`: `tau_monoid_ge`, `tau_intensity_effect`, `tau_hazard_exact`
   — hazard-ADDITIVE; `tau_no_targeting`). A **bridge lemma** `τ → λ` must be an explicit
   obligation, not an implicit substitution.

**B before everything.** P1 establishes that the four partitions
`(∂_(t+1,t), ∂_(x,u), ∂_(y,x), ∂_(y,u))` are well-defined over event time and that optimizing
a *set-point* is legitimate given `φ_M ≡ φ̄_M ∀t` and `(β_j,γ_j)` frozen. If P1 fails, P2–P4
are statements about an ill-posed object.

**P1 and P2 in ONE bundle.** They share the entire plant definitional payload. Splitting them
means paying for the same definitions twice against a service that terminates on
`OUT_OF_BUDGET` — a failure mode already hit once (36/51 declarations, 15 sorries).

**P2 is the highest-risk refutation and must gate C and D.** The source's own additive
expansion of `∂π^σ` contains a *direct* `∂π^σ/∂τ_MEV` term alongside `∂π^σ/∂φ_M` and
`∂π^σ/∂φ_X`, and the same document then gives
`(∂π^σ/∂φ_M, ∂π^σ/∂φ_X) = (p_(η Δ_i)·ΔQ_X, ΔQ_M)` — both nonzero. Meanwhile `TauMevAlgebra`
proves `τ_MEV` composes into *both* fee legs with the aggregate invariant to which leg carries
it. So there is a prima-facie path from `τ_MEV` to the output that is **not** routed through
`ν`, which is exactly what P2 denies. If P2 falls, the boxed `τ*` — which is derived *by* that
factorization — falls with it. **This is the concrete justification for the user's sequential
choice:** a refuted P2 must halt C, D, and E1 before they are spent.

**C after B.** P3 is not logically downstream of P2, but its target factor is only meaningful
inside the channel P2 establishes. Under sequential execution, run it second.

**D last, and its statement is not writable until B and C return.** Three reasons, each a
concrete defect in the boxed form that P4 must settle first:
- **The `(1−τ_MEV)` factor.** The derivation's own intermediate has
  `∂π^φ/∂φ = ΔQ_M/((1−τ)(1−φ_X)) + p·ΔQ_X/((1−τ)(1−φ_M))`, but the boxed `τ*` bracket carries
  no `(1−τ)`. It was evidently factored to the left-hand side. That step must be shown, not
  assumed — and it means `τ` appears on both sides, so **the "closed form" may in fact be an
  implicit/fixed-point equation** unless `∂ν/∂τ_MEV` is constant.
- **The missing `(σ²(i(t)) − σ_K²)⁺`.** `π^σ = ΔQ_v*·(σ² − σ_K²)⁺`, yet only `1/ΔQ_v*` survives
  into the boxed form. Either the factor was absorbed or it was dropped; the ledger must say
  which.
- **Level vs derivative.** `π^σ ≡^R π̂^σ` is a *level* equation, but the right-hand side is
  built from `∂π̂^σ/∂τ_MEV`. Solving a level relation with a derivative expression needs
  either a linearity assumption or an integration. This is an open question for P4's
  statement, flagged — not a claim that the derivation is wrong.
- Additionally, **Aristotle narrows preconditions** (the `σ_target > d²` precedent). P4's
  admissible domain is therefore only knowable after B and C return their added hypotheses.

**E0 is the one thing safely parallel to A.** Refreshing the Plank primitive inventory is
read-only and depends on the *form* of the law, not its truth. **E1 must wait for D** —
analysing the EVM realizability of a refuted law is pure waste, and the whole point of the
sequential choice is to not spend on downstream work an early refutation would void.

### Natural phase boundaries

| Phase | Content | Exit criterion | Halt semantics |
|-------|---------|----------------|----------------|
| **A** | Frame selection; plant transcription; notation map; the two blocker rulings; `CONTROL-FRAME.md` v1 | **USER APPROVAL** of the notation map + plant, then sha-pin. Precedent: 12-01 approved-and-pinned before 12-02 submitted. | Blocked on user rulings — the `IN-FLIGHT.md` §C class, "the cheapest items on the whole board." |
| **B** | `PROOF-OBLIGATIONS.md` for P1+P2; two-step reviewer gate; bundle; submit; land; ledger rows | Verdict on P1 **and** P2 | **HALT GATE.** P2 REFUTED ⟹ skip C/D/E1, go to F with a refutation deliverable. |
| **C** | P3 + the τ↔λ bridge; small bundle | Verdict on P3 incl. its sign and whether constancy survives | Sign refuted or indeterminate ⟹ D's inversion is undefined; escalate rather than proceed. |
| **D** | P4 statement (built from B+C hypotheses); bundle; land | Verdict on the boxed form + the three defects above resolved | Any outcome is shippable; `REFUTED` with a witness satisfies Core Value. |
| **E** | E0 (Phase A, read-only inventory) / E1 (post-D, the law-specific analysis) | `EVM-FEASIBILITY.md` complete with its honesty section | — |
| **F** | Consolidated spec; gap register; hand-off; the doc summarization pass | User-approved block(s) landed in the entry-point doc via the plank owner | — |

Each of B, C, D internally follows the 11-step Aristotle sequence, so each phase naturally
splits into three plans: **prepare + gate** → **submit + record** → **land + ledger**. That is
exactly the 12-01 / 12-02 / 12-03 shape.

---

## Integration Points

### Cross-worktree / peer coordination

Worktree↔branch map verified via `git worktree list` and
`cfmm-wt/lean4-spec/scripts/peers.tsv`. Owners from the ownership map in
`evm-controller/CLAUDE.md`. **PIDs are not stable across restarts — run `list_peers` (scope
`repo`) before acting on any row.**

| # | Touch point | Path | Worktree / branch | Owning session | Mechanism |
|---|-------------|------|-------------------|----------------|-----------|
| 1 | Lean modules for P1–P4 | `lean/vol_markets/<New>.lean` | `cfmm-wt/lean4-spec` / `feat/lean4-spec` | **Lean4 + Math (PID 253818)** | `claude-peers` `send_message`; hand off `PROOF-OBLIGATIONS.md` + the prompt text + the module-closure list |
| 2 | Lake root registration | `lean/lakefile.toml` | same | same | same request as #1 (append-only, after `vol_markets.*` roots) |
| 3 | Bundle assembly + submit | `scratch/aristotle-*/`, `.env` (`ARISTOTLE_API_KEY`) | same | same | same — **the API key lives in `lean4-spec/.env`**; this project has no independent access path |
| 4 | In-flight ledger row | `.planning/IN-FLIGHT.md` §A | same | same | same; row created in the same action as the submit (maintenance rule 1) |
| 5 | Traceability rows | `model/vol_markets/LEAN_TRACEABILITY.md` | same | same | same; statuses PROVEN/CORRECTED/REFUTED/OPEN |
| 6 | Bundled addendum copy | `model/vol_markets/VOLATILITY_INSTRUMENTS_*_ADDENDUM.md` | same | same | same; the bundle ships the addendum, not the whole doc section |
| 7 | New tagged blocks | `notes/VOLATILITY_INSTRUMENTS.md` | `cfmm-wt/plank` / `feat/plank` | **Plank dev — agent id `ul2inqpl`** | `send_message` to `ul2inqpl` (a stable agent id, unlike the PIDs) |
| 8 | Typeset twin regeneration | `notes/VOLATILITY_INSTRUMENTS_MEV.{tex,pdf}` | same | same | same; derived artifact, must follow any block landing |
| 9 | Plank primitive inventory (E0) | `src/`, `lib/plankified-univ3/` | same | same | **READ-ONLY** — no coordination needed to read, but cite the plank tree, never `evm-controller/src/` (stale mirror) |
| 10 | Any Plank/Solidity implementation | `src/`, `script/`, `foundry.toml` | `cfmm-wt/plank` | `ul2inqpl` | **OUT OF SCOPE** (PROJECT.md); hand-off only |
| 11 | Foundry tests | `test/` | `cfmm-wt/sol-tests` / `feat/sol-tests` | **Solidity testing (PID 284909)** | **OUT OF SCOPE**; hand-off only |
| 12 | GAMS reference values | `model/*.gms` | `cfmm-wt/gams` | **GAMS dev (PID 175812)** | **NOT NEEDED** — no GAMS model of the event-time plant; do not open this edge |
| 13 | Differential fixtures | gamsdiff harness | `cfmm-wt/gamsdiff` / `feat/gamsdiff` | **GAMS↔Solidity difftest (PID 299098)** | **NOT NEEDED** at design stage |
| 14 | Repo-root planning | `evm-controller/.planning/` | `cfmm-wt/evm-controller` | shared v1, in flight across peers | **READ-ONLY** (PROJECT.md constraint); all GSD commands run `--cwd control` |
| 15 | Notation rulings; the section/tag choice; any new symbol | — | — | **USER** | direct; **blocks Phase A exit** |
| 16 | Delivery | PR `feat/evm-controller` → `develop` (gate-green) | `cfmm-wt/evm-controller` | this project | standard PR flow |

**The structural consequence, stated plainly:** of the eight steps in the proof pipeline, this
project can execute **zero** in its own worktree. Rows 1–6 are all one owner (Lean4+Math), so
the right shape is a **single PROOF-REQUEST hand-off artifact** — obligations + prompt +
closure list + the sha pins — delivered once per bundle, with the ledger facts returned. That
matches the observed convention: `12-03-SUMMARY.md` notes "the plank-side doc marker for this
landing was committed in the plank worktree at `08039da` **by its owner, not by this tree**."

**If the Lean4+Math session is unavailable**, do not assume the boundary. Request an explicit,
time-boxed ownership delegation from the user for the specific paths (the new `.lean` module,
the one lakefile root line, the `scratch/` bundle dir, the IN-FLIGHT row). Silence is not
consent.

### External services

| Service | Integration pattern | Gotchas |
|---------|---------------------|---------|
| **Aristotle** (`aristotle` CLI, `/home/jmsbpp/.local/bin/aristotle`) | `submit --project-dir <bundle> --api-key ... "<prompt>"` → poll `tasks <FULL-UUID>` → `download` → gate → integrate | Full UUIDs only (500 on short ids); `show` streams and blocks; `download --destination` writes an archive and extracts one level deeper; never parallel `continue` on one project; `OUT_OF_BUDGET` ⟹ single `continue`; no SLA is evidenced |
| **`claude-peers` MCP** | `list_peers` (scope `repo`) → `send_message` by agent id | PIDs in `CLAUDE.md` are not stable across restarts; `ul2inqpl` is a stable agent id. Incoming peer messages are answered immediately, mid-task |

### Internal boundaries

| Boundary | Communication | Notes |
|----------|---------------|-------|
| `CONTROL-FRAME` ↔ `PROOF-OBLIGATIONS` | one-way: frame → obligations | Obligations never restate math; they cite frame section numbers |
| `PROOF-OBLIGATIONS` ↔ `PROOF-LEDGER` | one-way: obligations frozen, ledger written after | The sha pin is the join key |
| `PROOF-LEDGER` → `CONTROL-FRAME` | feedback edge (the only cycle in the doc set, and it is deliberate) | A `REFUTED`/`CORRECTED` verdict **edits** the frame; the frame then re-freezes |
| `EVM-FEASIBILITY` ↔ everything | consumes the *form* of the law only | Must not restate the derivation or the proof status; cites both |
| `spec/` ↔ `phases/` | run records and reviews stay in `phases/` | `spec/` is the deliverable; `phases/` is process |

---

## Anti-Patterns

### Anti-Pattern 1: Whole-file hashing the entry-point doc

**What people do:** pin `VOLATILITY_INSTRUMENTS.md`'s file hash as the fidelity gate.
**Why it's wrong:** the file is under concurrent multi-session edit; its hash moved twice
inside a single 12-02 run while the relevant section never moved. Diagnosed twice (11-04, then
again in 12-02).
**Do this instead:** end-marker-delimited **section** hash, plus a byte diff against the
lean4-spec-side addendum copy.

### Anti-Pattern 2: Blanket `sed` on the return import rewrite

**What people do:** `s/RequestProject\./vol_markets./` across the returned bundle.
**Why it's wrong:** the bundle is flat but the origins are not — `RequestProject.eta` belongs
to `exp`, not `vol_markets`. A blanket rewrite emits `import vol_markets.eta`, which does not
exist.
**Do this instead:** record a module-origin map at assembly time and rewrite from it.

### Anti-Pattern 3: Integrating a partial return

**What people do:** land the `OUT_OF_BUDGET` module and hand-prove the remaining `sorry`s.
**Why it's wrong:** `lean/vol_markets/` requires sorry-free, axiom-clean modules, and the
standing workflow rule is that Aristotle authors statements **and** proofs. Hand-proving is
barred.
**Do this instead:** record the partial (gitignored `scratch/`), enumerate proven vs sorried,
and run a single `continue` — or, with explicit user approval, a scoped repair bundle carrying
the partial as its working base.

### Anti-Pattern 4: Reusing v2's Lean and primitive maps as current fact

**What people do:** cite `LEAN-MAP.md` / `EVM-CONTROL-PRIMITIVES-MAP.md` as the inventory.
**Why it's wrong:** `LEAN-MAP.md` asserts a single `.lean` file exists in the repo; there are
23 in `lean/vol_markets/` alone. `EVM-CONTROL-PRIMITIVES-MAP.md` is dated 2026-06-28 and its
own header warns this worktree's `src/` is a stale mirror — verified true today.
**Do this instead:** re-derive the reuse map from `lean/lakefile.toml`, and re-verify every
primitive citation against `cfmm-wt/plank`.

### Anti-Pattern 5: Renaming a source symbol to resolve a collision

**What people do:** rewrite the source's `π^{\varphi}` to something convenient and move on.
**Why it's wrong:** notation is binding — the user's and the source's notation is preserved
exactly, conflicting *external* symbols get **new** symbols recorded in a notation-map
paragraph, and **no new symbol is minted without discussing it first**. The rule applies to
Aristotle prompts too.
**Do this instead:** surface the collision as a Phase-A user ruling and record the resolution
in the `[x0] NOTATION-MAP` block.

### Anti-Pattern 6: Deferring the two-step review

**What people do:** write the spec, ship it, schedule the review after.
**Why it's wrong:** v2 did exactly this (SPEC-04, deferred 2026-06-28) and the debt is still
open in the doc header six weeks later — with two BLOCKERs found by the *one* gate that did
run on a prompt in phase 12.
**Do this instead:** gate before submit and before commit, per plan, as PROJECT.md already
requires.

---

## Scaling Considerations

Not a user-scaling question. The analogous axis is **proof-bundle size vs. Aristotle budget**,
which is the resource that has actually failed.

| Bundle scale | Observed behaviour | Adjustment |
|--------------|--------------------|------------|
| ~14–25 requested declarations | Returns COMPLETE. `MevOptimization` 25 decls; `MevJointProgram` 27 decls / 481 lines; `TauMevAlgebra` 14 decls | Default target. Aim for one coherent theorem family per bundle |
| ~30–51 requested declarations | `OUT_OF_BUDGET` at 36/51 with 15 sorries (`aristotle-eta-curvature`, 18 bundled modules) | State a **priority order** over the requested items in the prompt so truncation loses the least valuable item, not the headline. This is an explicitly recorded pattern from 12-03 |
| Definitional payload | Every bundle re-ships the full import closure (12–18 modules) | Do not split a shared-definition family across bundles — you pay the payload twice. This is why P1+P2 go together |

**First bottleneck:** budget exhaustion mid-bundle. **Mitigation:** priority ordering + smaller
families. **Second bottleneck:** the serial per-project queue — only one task in flight per
project, so a `continue` cycle serializes. **Mitigation:** independent obligations go to
*new projects* (parallel `submit` is sanctioned), which is available for C if and only if it is
genuinely independent of B — under the sequential execution choice, it is deliberately not used.

---

## Sources

Local evidence (read directly, 2026-08-08):

- `/home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller/control/.planning/PROJECT.md`
- `/home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller/CLAUDE.md`
- `/home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller/notes/VOLATILITY_INTRUMENTS_MEV.md`
- `/home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller/.planning/research/v2-controller/{STATIC-CONTROL-KERNEL-SPEC,ON-CHAIN-REALIZATION,C2-PROOF-CASE,LEAN-MAP,EVM-CONTROL-PRIMITIVES-MAP}.md`
- `/home/jmsbpp/cfmms-playground/cfmm-wt/lean4-spec/scratch/` — `aristotle-tau-mev/`, `aristotle-mev-joint/`, `mev-joint-result/aristotle-mev-joint_aristotle/`, `aristotle-tau-mev-PROMPT.txt`
- `/home/jmsbpp/cfmms-playground/cfmm-wt/lean4-spec/.planning/IN-FLIGHT.md`
- `/home/jmsbpp/cfmms-playground/cfmm-wt/lean4-spec/.planning/phases/12-eta-tradeoff-optimum/{12-02-RUN-RECORD,12-03-PARTIAL-RETURN,12-03-SUMMARY}.md`
- `/home/jmsbpp/cfmms-playground/cfmm-wt/lean4-spec/lean/{lakefile.toml,vol_markets/Main.lean,vol_markets/}`
- `/home/jmsbpp/cfmms-playground/cfmm-wt/lean4-spec/model/vol_markets/LEAN_TRACEABILITY.md`
- `/home/jmsbpp/cfmms-playground/cfmm-wt/lean4-spec/scripts/peers.tsv`
- `/home/jmsbpp/cfmms-playground/cfmm-wt/plank/notes/VOLATILITY_INSTRUMENTS.md`, `VOLATILITY_INSTRUMENTS_MEV.tex`
- `aristotle {submit,continue,download} --help`; `git worktree list`

**Not consulted (deliberately):** no web sources. Every claim here is about this repository's
own conventions and this project's own inputs, for which the repository is the authority.

---
*Architecture research for: verified control-design specification (event-time MEV-tax set-point controller)*
*Researched: 2026-08-08*
