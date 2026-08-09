---
phase: 06B-research-venue-and-estimating-mev
plan: 01
type: execute
wave: 2
depends_on: ["06B-00"]
files_modified:
  - control/spec/POOL-ALGEBRA.md
  - control/spec/NU-CONSTRUCTIBILITY.md
autonomous: false
requirements: [LIT-04, EST-01]

must_haves:
  truths:
    - "`ν` and `λ_ARB` are written in Algebra Integral's own state variables, not in analogy to them."
    - "The dimensional check on `ℙ_{Δ_ARB}` is DERIVED by the executor and returns PASS or FAIL; a FAIL is terminal for the freeze and is escalated, not marked provisional."
    - "The `Δt` chain-level / `φ` pool-level axis distinction is stated, with the consequence that pool selection buys exactly zero instrument variation."
    - "The venue-INDEPENDENT thresholds (first-stage F floor, target power, MDES, minimum Δt dispersion) are pre-registered HERE, before any dispersion exists — not in wave 4 after ranking."
    - "The candidate sets and the window A / window B boundary are pre-declared and ratified with the template placeholders removed."
    - "`EST-01` carries exactly one of three verdicts, and NOT CONSTRUCTIBLE writes a machine-readable terminal marker that `06B-02`…`06B-05` read and honour."
  artifacts:
    - path: "control/spec/POOL-ALGEBRA.md"
      provides: "ν and λ_ARB in Algebra Integral state variables; the dimensional check; the two-axis distinction; the venue-independent thresholds; the pre-declared candidate set and window A/B boundary"
      min_lines: 160
      contains: "exactly zero instrument variation"
    - path: "control/spec/NU-CONSTRUCTIBILITY.md"
      provides: "EST-01's terminal verdict with the read path named down to the event and the field"
      min_lines: 80
      contains: "EST-01 VERDICT:"
  key_links:
    - from: "control/spec/POOL-ALGEBRA.md"
      to: "PLANK/src/lib/premium/AdaptiveFee.plk"
      via: "get_fee's uint88 volatility and packed u144 config mapped to Θ_φ"
      pattern: "AdaptiveFee"
    - from: "control/spec/POOL-ALGEBRA.md"
      to: "control/spec/PRE-REGISTRATION.md"
      via: "§5's venue-independent thresholds are copied verbatim into the freeze and asserted byte-equal"
      pattern: "first-stage F floor:"
    - from: "control/spec/NU-CONSTRUCTIBILITY.md"
      to: "control/spec/RESEARCH-REGISTER.md"
      via: "the register's first-commit sha quoted, and the §1/§2 findings on reconstructing ν cited by S-NN"
      pattern: "RESEARCH-REGISTER.md @"
---

<objective>
Derive `ν` and `λ_ARB` in **Algebra Integral's own state variables**, run the dimensional check,
pre-register the venue-independent thresholds, pre-declare the candidate sets and the window A/B
boundary, and return `EST-01`'s terminal verdict.

Purpose: `LIT-04`, `EST-01`. `EST-01` **blocks every other requirement in this phase** — and if
`ν` is not constructible the phase terminates here with that as its delivered result
(`ROADMAP.md` Phase 6b SC1).

Output: `control/spec/POOL-ALGEBRA.md`, `control/spec/NU-CONSTRUCTIBILITY.md`.
</objective>

<execution_context>
@/home/jmsbpp/.claude/get-shit-done/workflows/execute-plan.md
@/home/jmsbpp/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@/home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller/control/.planning/ROADMAP.md
@/home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller/control/.planning/REQUIREMENTS.md
@/home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller/control/.planning/phases/06B-research-venue-and-estimating-mev/06B-CONTEXT.md
@/home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller/control/spec/ECONOMETRICS-DESIGN.md
@/home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller/control/spec/RESEARCH-REGISTER.md

**Path glossary.** `WT` = `/home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller` (worktree root;
`files_modified` relative to it). `PLANK` = `/home/jmsbpp/cfmms-playground/cfmm-wt/plank`
(**PEER-OWNED, READ-ONLY**). `LEAN` = `/home/jmsbpp/cfmms-playground/cfmm-wt/lean4-spec`
(**PEER-OWNED, READ-ONLY**). `SRC` = `WT/notes/VOLATILITY_INTRUMENTS_MEV.md` @ `cf386de`.
`DOC` = `PLANK/notes/VOLATILITY_INSTRUMENTS.md`.

**SCOPE SENTINEL — capture BEFORE, assert BEFORE == AFTER, and prove the snapshot is FRESH and
PRE-EDIT.** Peer trees and the repo-root `.planning/` are **not clean** and are **not this
session's to clean**: at plan time `git -C ../plank status --porcelain` shows three ` M lib/...`
submodule lines and `git status --porcelain .planning/` shows `?? .planning/milestones/` and
`?? .planning/research/`. The invariant is **unchanged by this task**, never "clean".

Snapshots live **under the phase directory, not `/tmp`** — every plan in this phase blocks on a
human, and `/tmp` does not survive the reboot that invites. `.sentinel/` is untracked and is
**never staged**; every commit below lists its paths explicitly.

**ONCE, before Task 1**, clear stale snapshots and drop a run marker, so a previous run's
`.before` cannot be silently reused:

```
cd /home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller
SENT=control/.planning/phases/06B-research-venue-and-estimating-mev/.sentinel
rm -rf "$SENT" && mkdir -p "$SENT" && touch "$SENT/.runstart"
```

**As the FIRST action of every task**, with `TAG` = `01-1`, `01-2`, `01-3`:

```
cd /home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller
SENT=control/.planning/phases/06B-research-venue-and-estimating-mev/.sentinel
git -C ../plank status --porcelain      | grep -v '^??' > "$SENT/<TAG>.plank.before" || true
git -C ../lean4-spec status --porcelain | grep -v '^??' > "$SENT/<TAG>.lean4spec.before" || true
git status --porcelain .planning/                       > "$SENT/<TAG>.rootplanning.before"
```

The `cd` is **load-bearing**: `git -C ../plank` and `.planning/` are both relative to the worktree
root. Run from `control/`, `git -C ../plank` **fatals** and writes an EMPTY baseline, and
`.planning/` resolves to *this* project's planning tree instead of the repo-root one. Untracked
`??` entries are filtered on **both** sides: `plank` is owned by agent `ul2inqpl` and is worked
concurrently, so a stray untracked artifact there must not fail a gate for a change this project
did not make.

Every `<verify>` closes with two freshness tests before the three diffs. **Neither uses
`find -newermt`** — on this machine `find` is `bfs`, which rejects relative timestamps and errors
out:

- `-nt "$SENT/.runstart"` — the snapshot was taken **during this run**, not carried over.
- `! -nt "$F"` — the snapshot is **not newer than the artifact**, i.e. it was taken **before** the
  edit. A snapshot taken after a violation — which would launder that violation into the baseline
  and let it pass as the next task's legitimate BEFORE — fails here.

**Hard prohibitions.**
- Never write under `PLANK/`, `LEAN/`, or `WT/.planning/` (repo-root).
- `grep` dispatches to `ugrep`: literal patterns need `-F`; never `grep -v '^\+\+\+'`.
- Every `<verify>` is one unbroken `&&` chain ending in `echo PASS`. Never `done;` — always
  `done &&`.
- `gsd-tools commit --files` commits the entire staged index. Use `git commit -- <paths>` and
  assert paths with `git show --name-only --format="" HEAD`, never `--stat` (it elides long
  paths).
- **`DOC` line citations carry a sha and are located by content, not by memory.** `DOC` is an
  actively-edited peer document. Before citing, run `grep -nF '<the numbered item>' DOC` and use
  the measured line. Every `DOC:NNN` citation is written `DOC:NNN @ <8-hex sha of DOC's blob>`.
  **The `σ²(i(t))Δt < 8` guard is at `DOC:958`, not `DOC:959` — :959 is blank.** Verify on disk.
- **Glyph guard.** The trading function is `\varphi`; the fee is `φ`. `DOC:920` fixes the split.
  Write `\varphi_{(1/2,\,0)}` in newly-authored prose. The ban on `φ_{(1/2,0)}` applies **only to
  newly-authored prose** — that exact glyph appears in the approved `ECONOMETRICS-DESIGN.md` §6
  and in `REQUIREMENTS.md:150`, so a verbatim quotation of either is exempt and must carry its
  source name on the same line.
- **No symbol is minted without a user ruling.**

**No dispersion is measured in this plan.** Reading a dispersion number here inverts the ordering
`EST-09` exists to protect.
</context>

<inherited>
**Phases 1, 2, 3 and 6a are UNEXECUTED at plan time.** Both artifacts open with an
`## Inherited, not assumed` section naming:

- **O4 — `σ` versus `σ²` units** (Phase 1 `NOT-05`). `DOC` Definition 18's sigmoid argument is
  `σ(i(t))`; the plant's `u_ex` carries `σ²(i(t))`; `Θ_φ`'s centers live in σ-units. **UNRESOLVED
  at plan time as a general notation question.** §3 of `POOL-ALGEBRA.md` **derives and records**
  the *dimensional* sub-question for `ℙ_{Δ_ARB}` specifically. Where that check returns `PASS`,
  O4's dimensional content is **SETTLED for this estimating equation** and is recorded as
  `SETTLED BY §3` — not `PROVISIONAL`. Phase 1's `NOT-05` then **ratifies a derivation, not a
  guess**, and the derivation is on the record here for it to check.
- **The event-clock ruling** (Phase 2 `FRM-03`). `λ_ARB`'s `Σ_{s<t}` indexes swaps while `Δt`
  indexes blocks — **two clocks in one summand**. **UNRESOLVED at plan time**; the derivation
  states which clock each Algebra state variable is emitted on and does not merge them.
- **The hypothesis discipline** (Phase 3 `PRF-03`, `PRF-06`). **UNWRITTEN at plan time.**
- **`NEC-04`'s coupling verdict and recomposition rule** (Phase 6a).
  `ECONOMETRICS-DESIGN.md:31` classifies `∂ν/∂λ_MEV` as **"Behavioural. Not derivable."** and
  `NEC-04` reopens it. **This plan assumes NEITHER verdict.**
- **`NEC-00`'s affine-in-`Ḡ` verdict** (Phase 6a). Refuted-as-a-free-option by two independent
  reviewers and by the orchestrator's own derivation, but **PENDING `NEC-00`'s formal carrier** —
  a two-reviewer consensus is not a machine-checked identity and the Gates table lists `NEC-00`
  **NOT REACHED**.
- **The review register** (Phase 1 `HND-05`) does not exist; each artifact carries its own
  `## Review`.
</inherited>

<tasks>

<task type="auto">
  <name>Task 1: LIT-04 — ν and λ_ARB in Algebra Integral's state variables, the dimensional check, the two axes</name>
  <files>control/spec/POOL-ALGEBRA.md</files>
  <read_first>
    - `/home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller/control/.planning/REQUIREMENTS.md` — the `LIT-04` definition in full (the chain-vs-pool axis distinction is load-bearing there)
    - `/home/jmsbpp/cfmms-playground/cfmm-wt/plank/src/lib/premium/AdaptiveFee.plk` — `get_fee` at :72, its `uint88` volatility argument and packed `u144` config (READ ONLY)
    - `/home/jmsbpp/cfmms-playground/cfmm-wt/plank/src/types/premium/AlgebraFeeConfiguration.plk` — the `Θ_φ` parameter block (READ ONLY)
    - `/home/jmsbpp/cfmms-playground/cfmm-wt/plank/notes/VOLATILITY_INSTRUMENTS.md` — Definition 18 (the fee schedule carrying **both** `σ` and `ν`), Definition 22 (the discrete `λ_ARB`), Definition 23 (`λ_MEV = λ_ARB ⊕ λ_sandwich` and the Angstrom-regime scoping), the `π^LVR` alignment, the `[M8]` caveats, and the `σ²(i(t))Δt < 8` guard. **Locate every one of these by content** (`grep -nF 'Definition 22'`, `grep -nF 'sigma^2(i(t))\,\Delta t < 8'`) and record the measured line plus DOC's blob sha. Do not carry a line number from this plan.
    - `/home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller/control/spec/RESEARCH-REGISTER.md` — §2.6 the candidate instrument menu, §5 the instrument-selection rule
    - `/home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller/control/spec/ECONOMETRICS-DESIGN.md` lines 65–98 — the `Δt` instrument and its named weak-instrument risk
    - `~/.claude/skills/dimensional-analysis/SKILL.md` — the discipline §3's check runs under
  </read_first>
  <action>
**FIRST: capture the scope sentinel with `TAG=01-1`.**

Create `/home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller/control/spec/POOL-ALGEBRA.md`.

Header:

```
# POOL ALGEBRA — ν and λ_ARB in Algebra Integral state variables

**Requirement:** LIT-04
**Derived:** <YYYY-MM-DD>
**Research pin:** `control/spec/RESEARCH-REGISTER.md @ <FIRST commit sha from 06B-00>`
**DOC pin:** `plank/notes/VOLATILITY_INSTRUMENTS.md` blob `<8-hex>` — every `DOC:NNN` below was
measured against this blob, not remembered.
**No dispersion has been measured at the time of writing.** The candidate sets in §4 and the
thresholds in §5 are pre-declared; `EST-02` measures on window A afterwards.
```

Then `## Inherited, not assumed` — the six items from this plan's `<inherited>` block.

**`## 1. Why Algebra Integral is structurally comparable, and what that does NOT buy`**

Our `φ` is a **port** of Algebra's `AdaptiveFee` (`get_fee` at
`PLANK/src/lib/premium/AdaptiveFee.plk:72`) — same functional form, same volatility-oracle object.
State what that establishes: `Θ_φ` maps across without reinterpretation.

Then, in its own bolded paragraph, what it does **not**:

```
**Decision #13 settles the CODEBASE, not the CHAIN.** The `AdaptiveFee`-port argument justifies
structural similarity of `φ` and says **nothing about the instrument**. `Δt` is **chain-level,
not pool-level** (`ECONOMETRICS-DESIGN.md:74-76`): every pool on a chain sees the same cadence,
so **pool selection buys exactly zero instrument variation.** The chain is chosen on `Δt`
dispersion, the pool set on `φ` dispersion.
```

**`## 2. `ν` in the venue's state`**

`ν = \varphi_{(1/2,\,0)}(i_K; \Delta Q, 0; t) / \varphi_{(1/2,\,0)}(i_K; 0, L; t)`. For each
symbol, name the Algebra Integral state variable, storage slot or event field that carries it, or
write `NOT CARRIED`:

| Symbol | Meaning | Algebra Integral carrier | Clock (`block` or `swap`) | Units | Carried? |

**Every row's Clock cell is `block` or `swap`** — this is where the two-clock defect becomes
visible, and it must be visible rather than merged.

**`## 3. `λ_ARB` in the venue's state, and the dimensional check`**

`λ_ARB(t) = Σ_{s<t}(·)` per `DOC` Definition 22 (measured line + sha), built from
`ℙ_{Δ_ARB} = σ/(σ + φ√(2/Δt))`. Same table shape with a Clock column. Record three things:

- the `π^LVR/π^linear` factor whose `π^{\varphi}` carrier is **UNFORMALIZED** (cite the measured
  `DOC:NNN @ sha`), and whose exact tier's `σ²(i(t))Δt < 8` guard has **no carrier** — that guard
  sits at **`DOC:958`** on the current blob; **measure it and record what you measured**;
- `Δt` being the **mean** interblock time (measured `DOC:NNN @ sha`), which makes the **window
  length an undeclared observer parameter** — declare it in §4 and give it a value;
- the accumulator indexing **swaps** while `Δt` indexes **blocks** — two clocks in one summand.

Then `### 3.1 DIMENSIONAL CHECK — derive it, do not copy an answer`:

**Run the check under the `dimensional-analysis` discipline and record what you derive.** The
method: assign dimensions to every factor of `ℙ_{Δ_ARB} = σ/(σ + φ√(2/Δt))`; `ℙ` is a
probability, hence dimensionless; a sum is only defined between like dimensions; determine from
those two facts what dimension `σ` must carry, given `φ`'s dimension read off `AdaptiveFee.plk`
and `Δt`'s read off the block clock. **Then** read what Algebra's `uint88` volatility quantity
actually carries, citing the line in `AdaptiveFee.plk` that shows it, and compare.

Record the outcome on a line of exactly this form:

```
DIMENSIONAL CHECK: PASS — <the derived dimension of σ, and the AdaptiveFee line agreeing with it>
DIMENSIONAL CHECK: FAIL — <the derived dimension, the oracle's dimension, and how they disagree>
```

`TBD`, `PENDING` and blank are **not admissible outcomes**; the check either runs or the task is
incomplete.

**A `FAIL` is TERMINAL for the freeze, not a provisional convention.** O4 changes the
**regressor** — `ℙ_{Δ_ARB}` is a Möbius function of `σ`, and `σ²` is a *different variable*, not a
rescaling. Under `FAIL`, `06B-03` may not write a specification at all; escalate at Task 3's
checkpoint.

**Under `PASS`, state the claim NARROWLY.** This check settles the dimension of `σ` **in
`ℙ_{Δ_ARB}` only**. Every downstream artifact records it as
`SETTLED BY POOL-ALGEBRA.md §3.1 — for ℙ_{Δ_ARB} only`, never as "O4 is settled". The
actually-contested site — `DOC` Definition 18's gate argument `σ(i(t))` versus `Rule 13`'s
`φ_X(t) = Φ(Θ_φ; σ²(i(t)))` at `SRC:69 @ cf386de` — is **NOT** checked here and remains open item
**O3**/**O4** for Phase 1. Add a sentence in §3.1 saying so by name, so no reader upgrades this
result.

**`## 4. Pre-declared candidate sets, and the window boundary`**

`### 4.1 Candidate chains (PRE-DECLARED AS A SET)` — 3–5 chains, chosen on Algebra Integral
deployment depth (live Integral pools, TVL, swap counts — **inventory facts, not dispersion**),
plausible cadence behaviour from §3 of the research register (Class C **may screen chains** and
**may not supply a dispersion number**), and Dune data availability. Table:
`Chain | Algebra Integral deployment depth (with source) | Why plausible on cadence (LOWER-RIGOR screening, cited) | Named identification threat (STRUCTURAL MECHANISM ONLY)`.

**The threat column names a MECHANISM, never a measured statistic.** For every chain the
`EST-08` mechanism is at minimum: `Δt`'s realized variation comes from missed slots, congestion
and reorgs, which **cluster with volatility events**, and `σ` enters `φ` directly — so `Δt` can
correlate with the second-stage error **through the `σ` channel** without appearing in the fee
formula. Add whatever is chain-specific. **Do not compute a σ-channel correlation here**: the
user picks partly on this column, and a measured statistic in it would make the pick an argmax
over the very quantity `EST-08` later tests.

`### 4.2 Candidate pool set (PRE-DECLARED AS A SET)` — chosen on `φ` dispersion potential, not
`Δt`. State verbatim: `Pool selection buys exactly zero instrument variation; the pool set exists
to give the fee schedule something to move against, and is not part of instrument selection.`

`### 4.3 The pruning ban` — verbatim:

```
Neither the chain set nor the pool set may be pruned on a realized first-stage F. That is
instrument-strength selection and produces a winner's curse on the reported F (`EST-09`,
`LIT-04`). The sets declared in §4.1 and §4.2 are the sets `EST-02` measures over, in full.
```

`### 4.4 Window A / window B boundary (DECLARED BEFORE ANY MEASUREMENT)` — concrete dates or
block ranges, `window A = [<start>, <end>)` for selection and `window B = [<start>, <end>)` for
estimation, **disjoint**, with the reason for the cut. Also declare the observer window length
for the mean-`Δt` parameter from §3. Then verbatim:

```
**The split-sample rule (`EST-09`, MANDATORY — user ruling 2026-08-09):**
1. Measure dispersion and rank candidates on **window A**.
2. The user picks; specification, thresholds and clustering are frozen and sha-pinned.
3. Estimate on **window B**, disjoint from A.

If a split is infeasible on the chosen venue, the first-stage F is labelled **DESCRIPTIVE** and
the threshold rule is stated to be **VOID**. It is never quietly reported as if pre-registered.
```

`### 4.4a What makes a split FEASIBLE — the numeric predicate`

**This predicate now controls reachability of the only positive verdict.** Under
`PRE-REGISTRATION.md` §5.1, `INFEASIBLE` makes `VERDICT: GATE OPENS` **unreachable** and
`FEASIBLE` restores it. An undefined predicate there would hand the executor a switch on the
study's only positive outcome. It is therefore fixed **here**, numerically, where window B's dates
are already declared and **no dispersion exists**, and it is ratified at Task 3 with the
thresholds. Write it with these labels byte-exactly:

```
- split feasibility predicate: FEASIBLE iff ALL of the following hold on window B, else INFEASIBLE
  - minimum window B length: <NUMBER> <calendar units>
  - minimum window B chain-time periods: <NUMBER>  (same unit as `minimum N`, and it MUST be
    >= §5's `minimum N` — a window that provably cannot supply the minimum N may not be declared
    FEASIBLE. Asserted numerically, not merely stated.)
  - window A and window B disjoint: required, no overlap of any length
  - feasibility is evaluated on window B's DECLARED EXTENT, not on realized dispersion — it is a
    property of the calendar and the cadence, never of the outcome
```

**Feasibility is not a judgement call and is not re-evaluated after the pick.** `06B-02` §6's
`Split feasible on window B?` cell is the evaluation of *this* predicate against the picked
venue's declared window B, and `06B-03` §5 copies the resulting token rather than re-deriving it.

`### 4.5 May the pick be a SET of chains?` — state it. **If the pick is a single chain, `√Δt`
has no cross-sectional variation, the chain-time cluster reduces to G = 1, and cluster-robust
inference at chain-time is invalid.** Either the pick is permitted to be a set of ≥ 2 chains, or
this section records that the design is a **single-cluster time series** and states what that
costs — which inference remains valid, and which does not.

**`## 5. Venue-INDEPENDENT thresholds, pre-registered before any dispersion exists`**

These do **not** depend on which chain is picked, and pre-registering them in wave 4 — after wave
3 ranked candidates on dispersion — would mean choosing a dispersion floor with the dispersion
numbers already in hand. That is not a disclosable exception; it is the guaranteed state of the
wave graph. They are fixed **here**, before any number exists. Use these labels byte-exactly;
`06B-03` copies them and asserts equality **against this file's committed blob**, not against its
working tree:

```
- first-stage F floor: <NUMBER>
  criterion: Montiel Olea–Pflueger effective F
  published critical value: <the tabulated value> from Montiel Olea & Pflueger (2013), Table <N>
  bias tolerance tau: <NUMBER ≤ 0.10>
  nominal size: <NUMBER ≤ 0.05>
  The floor MUST be >= the published critical value; a citation beside a laxer number is
  decoration. The conventional `F >= 10` rule is recorded as REJECTED for this design because
  there is a single weak instrument, which is exactly the case it mis-sizes (`EST-07`).
- target power: <NUMBER ≥ 0.80, written as a decimal — `80%` parses as 80 and is rejected>
  MDES: <NUMBER> in units of `Ḡ` (per unit `λ_ARB`)
  MDES ceiling: <NUMBER> in units of `Ḡ` — the largest effect the study is allowed to call its
  minimum detectable one. Without a ceiling the power floor is vacuous: any MDES passes 0.80.
  The ceiling is set at or below the smallest `Ḡ` that `EST-04`'s logistic form could plausibly
  produce on the responsive band, and that reasoning is written out here.
  MDES arithmetic (SHOWN, not asserted): N = <n>, assumed residual variance = <v>, instrument
  strength assumption = <s>, formula = <the expression>, evaluated = <the arithmetic>.
- minimum N: <NUMBER>
  N unit: chain-time periods carrying Δt variation
  minimum N arithmetic (SHOWN, not asserted): window B length = <l>, mean Δt = <m>, periods =
  <l/m>, required by the MDES arithmetic above = <n>, formula = <the expression>.
- minimum Δt dispersion: <NUMBER> <units>, statistic: <CV | sd in seconds | share ≠ modal>
  dispersion inversion arithmetic (SHOWN, not asserted): the power calculation above, inverted
  for dispersion — <the F floor, N and MDES substituted, the inversion written out, evaluated>.
```

**Why `minimum N` and the dispersion floor belong HERE and not in wave 4.** Window B's dates are
declared at §4.4 and the cadence is a chain-level fact, so realized N is computable before any
outcome is seen. And the dispersion floor is **not a judgement**: inverting the power calculation
makes it a function of `(F floor, N, MDES)` — an identification requirement. That is what stops
the candidate-selection leak: §4.1 selects chains partly on *predicted* cadence behaviour, and a
floor derived from the power calculation cannot be tuned to whatever that prediction produced.

**A threshold with no provenance is asserted, not pre-registered.** "Stated judgement" is not
provenance for any line above: the F floor is bound to a published critical value **and must meet
it numerically**, `tau` is capped, the power floor is ≥ 0.80 with the MDES arithmetic shown and
the MDES itself capped, `minimum N` carries its arithmetic, and the dispersion floor carries its
inversion.

**`## 5a. THE §5 LOCK — the Iron Law applies to this section too`**

Moving these thresholds up split the freeze across **two** commits. The Iron Law must follow both,
or the earlier one becomes the amendment channel: after a `NOT IDENTIFIED`, editing §5's floor and
editing `PRE-REGISTRATION.md` §4.1 to match would leave byte-equality intact while no HALT fires.
Write, verbatim:

```
**§5 IS LOCKED AT ITS FIRST COMMIT.** From that commit onward, every line of §5 is under
`anti-fishing-replication`'s Iron Law exactly as `PRE-REGISTRATION.md` is:
`NO POST-LOCK CHANGE WITHOUT A HALT, A DISPOSITION MEMO, AND A USER-ENUMERATED PIVOT`.

The lock is enforced by **blob sha**, not by file-to-file comparison. Task 3 records
`POOL-ALGEBRA §5 BLOB: <sha>` — the sha of this file's blob at its first commit — and `06B-03`
and `06B-04` re-read §5 from **that blob** via `git cat-file blob <sha>`. (**Not**
`git show <sha>:control/spec/POOL-ALGEBRA.md` — a blob sha carries no path and that form exits
128.)
Editing both files identically at wave 4 therefore fails, because the wave-4 working tree no
longer matches the locked blob.

Amending §5 after `control/spec/STAGE1-RESULT.md` exists is a **recorded protocol violation**,
written into `RESEARCH-REGISTER.md` §6.
```

**`## 6. If `ν` is not expressible in the venue's state`** — verbatim:

```
If §2 shows `ν` is not expressible in Algebra Integral's state variables, that is recorded as
**terminal for the external route** (`LIT-04`), and `NEC-02`'s own-protocol route becomes the
only one. That is a Phase 6a object and is **not** re-decided here.
```
  </action>
  <acceptance_criteria>
    - `control/spec/POOL-ALGEBRA.md` exists and is ≥ 160 lines.
    - It contains `## Inherited, not assumed` and the names `O4`, `FRM-03`, `PRF-03`, `NEC-04`, `NEC-00`.
    - It contains `RESEARCH-REGISTER.md @` followed by a 7+ hex sha, and a `**DOC pin:**` line carrying an 8-hex blob sha.
    - Every `DOC:NNN` citation in the file is followed on the same line by ` @ ` and an 8-hex sha. The file contains **no** occurrence of `DOC:959`.
    - It contains `exactly zero instrument variation`, `Decision #13 settles the CODEBASE, not the CHAIN`, `chain-level, not pool-level`, `two clocks in one summand`, `UNFORMALIZED`.
    - It contains exactly one line matching `^DIMENSIONAL CHECK: (PASS|FAIL) — .` — and the file contains **no** `DIMENSIONAL CHECK: TBD`/`PENDING`/bare form.
    - §2's and §3's tables: every data row's Clock cell contains `block` or `swap`.
    - §4.1's table has 3–5 data rows; every row's threat cell is non-empty; and **no row contains a numeric dispersion or correlation statistic** — the file contains no match for `(std|sd|stdev|standard deviation|IQR|coefficient of variation|corr|rho|ρ) *[:=] *[0-9]`.
    - `### 4.3` contains `may be pruned on a realized first-stage F`; `### 4.4` contains `window A = [`, `window B = [`, `DESCRIPTIVE`, `VOID`; `### 4.5` contains `G = 1` and either `set of` or `single-cluster time series`.
    - `### 4.4a` exists and contains `split feasibility predicate: FEASIBLE iff`, `minimum window B length:`, `minimum window B chain-time periods:`, each carrying a numeral, plus `never of the outcome`.
    - **`minimum window B chain-time periods:` ≥ `minimum N:`**, asserted numerically — a window that cannot reach the N floor may not be declared FEASIBLE.
    - §5 contains, byte-exactly: `first-stage F floor:`, `criterion: Montiel Olea–Pflueger effective F`, `published critical value:`, `bias tolerance tau:`, `nominal size:`, `target power:`, `MDES:`, `MDES ceiling:`, `MDES arithmetic (SHOWN, not asserted):`, `minimum N:`, `N unit: chain-time periods carrying Δt variation`, `minimum N arithmetic (SHOWN, not asserted):`, `minimum Δt dispersion:`, `dispersion inversion arithmetic (SHOWN, not asserted):`.
    - **Numeric relations, not presence:** `first-stage F floor:` ≥ `published critical value:`; `bias tolerance tau:` ≤ 0.10; **`nominal size:` ≤ 0.05**; `target power:` ≥ 0.80; `MDES:` ≤ `MDES ceiling:`; **`minimum window B chain-time periods:` ≥ `minimum N:`**. Each is parsed and compared, not greped. **The number must follow its label immediately** — otherwise prose-first (`… Table 4 is 23.1`) yields `4` and `80%` yields `80`.
    - §5a exists and contains `§5 IS LOCKED AT ITS FIRST COMMIT.`, the Iron Law string, `enforced by **blob sha**`, and `recorded protocol violation`.
    - §3.1 states the narrow reading: the file contains `for ℙ_{Δ_ARB} only` and names `SRC:69 @ cf386de` as the site this check does **not** settle.
    - It contains `No dispersion has been measured at the time of writing.`
    - Newly-authored prose does not use the fee glyph for the trading function: every line containing `φ_{(1/2,0)}` or `\phi_{(1/2,0)}` also names its source (`ECONOMETRICS-DESIGN` or `REQUIREMENTS.md`) on the same line.
    - **Scope sentinel:** the three `01-1.*.before` snapshots exist, are **newer than `.sentinel/.runstart`** (taken this run) and **not newer than the artifact** (taken before the edit), and each `diff -q` cleanly against the live value with `??` filtered on both sides — peer trees and the repo-root `.planning/` are **unchanged by this task**, which is not the same as clean.
  </acceptance_criteria>
  <verify>
    <automated>cd /home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller && F=control/spec/POOL-ALGEBRA.md && test -f $F && test $(wc -l < $F) -ge 160 && for s in '## Inherited, not assumed' 'O4' 'FRM-03' 'PRF-03' 'NEC-04' 'NEC-00' 'exactly zero instrument variation' 'Decision #13 settles the CODEBASE, not the CHAIN' 'chain-level, not pool-level' 'two clocks in one summand' 'UNFORMALIZED' '### 4.3' 'may be pruned on a realized first-stage F' '### 4.4' 'window A = [' 'window B = [' 'DESCRIPTIVE' 'VOID' '### 4.5' 'G = 1' 'first-stage F floor:' 'criterion: Montiel Olea–Pflueger effective F' 'published critical value:' 'target power:' 'MDES:' 'MDES arithmetic (SHOWN, not asserted):' 'minimum Δt dispersion:' 'No dispersion has been measured at the time of writing.' 'AdaptiveFee' '**DOC pin:**'; do grep -qF "$s" $F || { echo "MISSING: $s"; exit 1; }; done && grep -qE 'RESEARCH-REGISTER\.md @ [0-9a-f]{7,}' $F && grep -qE '\*\*DOC pin:\*\*.*[0-9a-f]{8}' $F && ! grep -qF 'DOC:959' $F && test $(grep -oE 'DOC:[0-9]+(-[0-9]+)?( @ [0-9a-f]{8})?' $F | grep -vc ' @ ') -eq 0 && test $(grep -cE '^DIMENSIONAL CHECK: (PASS|FAIL) — .' $F) -eq 1 && test $(grep -cE '^DIMENSIONAL CHECK:' $F) -eq 1 && test -z "$(grep -inE '(std|sd|stdev|standard deviation|IQR|coefficient of variation|corr|rho|ρ)[^|]{0,20}[:=|] *[-+]?[0-9]' $F)" && R=$(awk '/^### 4\.1/,/^### 4\.2/' $F | grep -E '^\|' | grep -viE '^\| *(chain|-|:?-)') && test $(printf '%s\n' "$R" | grep -c '^|') -ge 3 && test $(printf '%s\n' "$R" | grep -c '^|') -le 5 && test $(printf '%s\n' "$R" | grep -cE '\| *(—)? *\| *$') -eq 0 && for L in 'split feasibility predicate: FEASIBLE iff' 'minimum window B length:' 'minimum window B chain-time periods:' 'never of the outcome' 'bias tolerance tau:' 'nominal size:' 'MDES ceiling:' 'minimum N:' 'N unit: chain-time periods carrying Δt variation' 'minimum N arithmetic (SHOWN, not asserted):' 'dispersion inversion arithmetic (SHOWN, not asserted):' '§5 IS LOCKED AT ITS FIRST COMMIT.' 'enforced by **blob sha**' 'recorded protocol violation' 'for ℙ_{Δ_ARB} only' 'SRC:69 @ cf386de'; do grep -qF "$L" $F || { echo "MISSING: $L"; exit 1; }; done && python3 -c "
import re,sys
t=open('$F').read()
def num(lbl):
    m=re.search(re.escape(lbl)+r'[ \\t]*([0-9]+(?:\\.[0-9]+)?)',t)
    assert m, 'no number IMMEDIATELY after '+repr(lbl)+' (prose before the number, or a bare percent, is rejected)'
    return float(m.group(1))
floor=num('first-stage F floor:'); crit=num('published critical value:')
tau=num('bias tolerance tau:'); size=num('nominal size:'); power=num('target power:')
mdes=num('MDES:'); ceil=num('MDES ceiling:')
assert floor>=crit, 'F floor %g < published critical value %g'%(floor,crit)
assert tau<=0.10, 'bias tolerance tau %g > 0.10'%tau
assert size<=0.05, 'nominal size %g > 0.05 -- a laxer size buys a lower tabulated MOP value with no fabrication'%size
assert 0<power<=1, 'target power must be a DECIMAL in (0,1]; %g looks like a percentage'%power
assert power>=0.80, 'target power %g < 0.80'%power
assert mdes<=ceil, 'MDES %g exceeds its ceiling %g'%(mdes,ceil)
minN=num('minimum N:'); wper=num('minimum window B chain-time periods:')
assert wper>=minN, 'feasibility floor of %g chain-time periods is below minimum N = %g; such a window cannot supply the required N and may not be called FEASIBLE'%(wper,minN)
print('threshold relations ok')
" && test $(grep -nF 'φ_{(1/2,0)}' $F | grep -vcE 'ECONOMETRICS-DESIGN|REQUIREMENTS\.md') -eq 0 && test $(grep -nF '\phi_{(1/2,0)}' $F | grep -vcE 'ECONOMETRICS-DESIGN|REQUIREMENTS\.md') -eq 0 && SENT=control/.planning/phases/06B-research-venue-and-estimating-mev/.sentinel && test "$SENT/01-1.plank.before" -nt "$SENT/.runstart" && { test ! -e "${F:-/nonexistent}" || ! test "$SENT/01-1.plank.before" -nt "${F:-/nonexistent}"; } && diff -q "$SENT/01-1.plank.before" <(git -C ../plank status --porcelain | grep -v '^??') && diff -q "$SENT/01-1.lean4spec.before" <(git -C ../lean4-spec status --porcelain | grep -v '^??') && diff -q "$SENT/01-1.rootplanning.before" <(git status --porcelain .planning/) && echo PASS</automated>
  </verify>
  <done>`ν` and `λ_ARB` are written in the venue's own state variables with a carrier and a clock per symbol against a pinned DOC blob and measured line numbers; the dimensional check is DERIVED by the executor and returns exactly one of PASS or FAIL; 3–5 chains and a pool set are pre-declared with mechanism-only threat statements and no measured statistic; the venue-independent thresholds are fixed with a named published critical value and shown MDES arithmetic before any dispersion exists.</done>
</task>

<task type="auto">
  <name>Task 2: EST-01 — ν's read path, and the terminal constructibility verdict</name>
  <files>control/spec/NU-CONSTRUCTIBILITY.md</files>
  <read_first>
    - `/home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller/control/spec/POOL-ALGEBRA.md` §2 (the carrier table this verdict is read off) and §3.1 (the dimensional check outcome)
    - `/home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller/control/spec/RESEARCH-REGISTER.md` §1 and §2 — **the literature answers whether prior work reconstructed `ν` or a defensible analogue** (user ruling); cite the `S-NN` blocks that bear on it
    - `/home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller/control/.planning/REQUIREMENTS.md` — `EST-01`, and the `NEC-03` note distinguishing the own-protocol question from this external one
    - `/home/jmsbpp/cfmms-playground/cfmm-wt/plank/notes/VOLATILITY_INSTRUMENTS.md` — Theorem 1 (the utilization gate) and Definition 12's signature note (READ ONLY; locate by content, record the measured line and blob sha)
    - `/home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller/control/spec/ECONOMETRICS-DESIGN.md` §6 item 2 — the open statement of exactly this question
  </read_first>
  <action>
**FIRST: capture the scope sentinel with `TAG=01-2`.**

Create `/home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller/control/spec/NU-CONSTRUCTIBILITY.md`.

**Scope guard, first paragraph, verbatim:**

```
**This is the EXTERNAL question, not `NEC-03`'s.** `EST-01` asks whether an *external* venue's
public state and swap events permit reconstruction of `ν`. `NEC-03` asks whether our own protocol
can compute it from state it owns. They have different answers and neither settles the other.
```

Then `## Inherited, not assumed` (the six items).

**`## 1. What the literature says`** — per the user ruling, whether `ν` is externally
reconstructible is what the research must show. Cite the `S-NN` blocks from
`RESEARCH-REGISTER.md` §1/§2 that constructed `ν`, a utilization ratio, or a defensible analogue
from venue events, and state the read path each used. If none did, write
`NO PRIOR RECONSTRUCTION FOUND` and list which S-blocks were checked.

**`## 2. The read path, field by field`**

Numerator `\varphi_{(1/2,\,0)}(i_K; \Delta Q, 0; t)` and denominator
`\varphi_{(1/2,\,0)}(i_K; 0, L; t)`. For each:

| Argument | What it is | Source (contract call / event / log field) | Available externally? | Reconstruction needed |

`Source` is named **down to the event and the field**. `Available externally?` is `YES` / `NO` /
`PARTIAL — <what is missing>`. **No hedging**: the words `presumably`, `probably` and `likely`
(as whole words) and the phrase `should be available` may not appear.

Record the **strike-versus-spot** distinction: the numerator is evaluated at `i_K` with a `t`
argument extending `Definition 12`'s `(i_K; ΔQ, L)` signature. If `i_K` is not observable on an
external venue because no vol instrument exists there, say so plainly — that is the crux.

**`## 3. The verdict`** — exactly one line, matching one of:

```
EST-01 VERDICT: DIRECTLY COMPUTABLE — <the read path, one line>
EST-01 VERDICT: RECONSTRUCTIBLE — <the reconstruction, its inputs, and what it assumes>
EST-01 VERDICT: NOT CONSTRUCTIBLE — <what is missing, and why no reconstruction closes it>
```

Followed by `**Consequence:**`:

- `DIRECTLY COMPUTABLE` / `RECONSTRUCTIBLE` → the phase proceeds to `06B-02`.
- `NOT CONSTRUCTIBLE` → **the phase terminates here** with this verdict as its delivered result.
  `06B-02` … `06B-05` do **not** run; `06B-06` runs in reduced form to back-propagate the
  verdict. **A delivered result, not a failure to re-specify around** — the `υ` precedent. Do
  **not** propose an alternative read path here; that boundary belongs to `06B-06`, under
  `anti-fishing-replication`.

A `RECONSTRUCTIBLE` verdict additionally lists, under `**Reconstruction assumptions:**`, every
assumption marked `BENIGN` or `LOAD-BEARING`.

**`## 4. TERMINAL MARKER (machine-readable — downstream plans read this file)`**

Write exactly one line of this form, and nothing else in the section:

```
PHASE-6B-TERMINAL: NONE
PHASE-6B-TERMINAL: EST-01 NOT CONSTRUCTIBLE
```

`06B-02`, `06B-03`, `06B-04` and `06B-05` each begin by grepping this line; anything other than
`NONE` makes them exit `0` reporting `NOT RUN`, so the phase reaches `06B-06` on every branch as
`ROADMAP.md` requires.

**`## 5. What this verdict does NOT decide`** — verbatim:

```
It does not decide whether `∂ν/∂λ_MEV` exists as assumed. `ECONOMETRICS-DESIGN.md:31` classifies
it as "Behavioural. Not derivable."; Phase 6a's `NEC-04` reopens that ruling. **This document
assumes neither verdict.** Constructing `ν` from events and `ν` being a function of `λ_MEV` are
different claims.
```
  </action>
  <acceptance_criteria>
    - `control/spec/NU-CONSTRUCTIBILITY.md` exists and is ≥ 80 lines.
    - It contains `This is the EXTERNAL question, not `NEC-03`'s.` and `## Inherited, not assumed`.
    - It contains at least one `S-` citation into `RESEARCH-REGISTER.md`, or `NO PRIOR RECONSTRUCTION FOUND`.
    - Exactly one line matches `^EST-01 VERDICT: (DIRECTLY COMPUTABLE|RECONSTRUCTIBLE|NOT CONSTRUCTIBLE)` and `**Consequence:**` is present.
    - Exactly one line matches `^PHASE-6B-TERMINAL: (NONE|EST-01 NOT CONSTRUCTIBLE)`, and it reads `NONE` **iff** the verdict is not `NOT CONSTRUCTIBLE`.
    - If `RECONSTRUCTIBLE`: `**Reconstruction assumptions:**` present and every listed assumption line carries `BENIGN` or `LOAD-BEARING`.
    - If `NOT CONSTRUCTIBLE`: the file contains `the phase terminates here`.
    - No hedging: `grep -icwE 'presumably|probably|likely'` returns 0 (word-boundary — "unlikely"/"likelihood" are not matches) and `grep -icF 'should be available'` returns 0.
    - Every line containing `φ_{(1/2,0)}` or `\phi_{(1/2,0)}` names `ECONOMETRICS-DESIGN` or `REQUIREMENTS.md` on the same line.
    - It contains `Behavioural. Not derivable.` and `assumes neither verdict`.
    - **Scope sentinel:** the three `01-2.*.before` snapshots exist, are **newer than `.sentinel/.runstart`** (taken this run) and **not newer than the artifact** (taken before the edit), and each `diff -q` cleanly against the live value with `??` filtered on both sides — peer trees and the repo-root `.planning/` are **unchanged by this task**, which is not the same as clean.
  </acceptance_criteria>
  <verify>
    <automated>cd /home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller && F=control/spec/NU-CONSTRUCTIBILITY.md && test -f $F && test $(wc -l < $F) -ge 80 && for s in 'This is the EXTERNAL question' '## Inherited, not assumed' '**Consequence:**' 'Behavioural. Not derivable.' 'assumes neither verdict'; do grep -qF "$s" $F || { echo "MISSING: $s"; exit 1; }; done && test $(grep -cE '^EST-01 VERDICT: (DIRECTLY COMPUTABLE|RECONSTRUCTIBLE|NOT CONSTRUCTIBLE)' $F) -eq 1 && test $(grep -cE '^PHASE-6B-TERMINAL: (NONE|EST-01 NOT CONSTRUCTIBLE)' $F) -eq 1 && { grep -qE 'S-[0-9]+' $F || grep -qF 'NO PRIOR RECONSTRUCTION FOUND' $F; } && test $(grep -icwE 'presumably|probably|likely' $F) -eq 0 && test $(grep -icF 'should be available' $F) -eq 0 && test $(grep -nF 'φ_{(1/2,0)}' $F | grep -vcE 'ECONOMETRICS-DESIGN|REQUIREMENTS\.md') -eq 0 && if grep -qF 'EST-01 VERDICT: NOT CONSTRUCTIBLE' $F; then grep -qF 'the phase terminates here' $F && grep -qxF 'PHASE-6B-TERMINAL: EST-01 NOT CONSTRUCTIBLE' $F; else grep -qxF 'PHASE-6B-TERMINAL: NONE' $F; fi && if grep -qF 'EST-01 VERDICT: RECONSTRUCTIBLE' $F; then grep -qF '**Reconstruction assumptions:**' $F && test $(awk '/\*\*Reconstruction assumptions:\*\*/,/^## /' $F | grep -cE '^[-*] ') -eq $(awk '/\*\*Reconstruction assumptions:\*\*/,/^## /' $F | grep -E '^[-*] ' | grep -cE 'BENIGN|LOAD-BEARING'); else true; fi && SENT=control/.planning/phases/06B-research-venue-and-estimating-mev/.sentinel && test "$SENT/01-2.plank.before" -nt "$SENT/.runstart" && { test ! -e "${F:-/nonexistent}" || ! test "$SENT/01-2.plank.before" -nt "${F:-/nonexistent}"; } && diff -q "$SENT/01-2.plank.before" <(git -C ../plank status --porcelain | grep -v '^??') && diff -q "$SENT/01-2.lean4spec.before" <(git -C ../lean4-spec status --porcelain | grep -v '^??') && diff -q "$SENT/01-2.rootplanning.before" <(git status --porcelain .planning/) && echo PASS</automated>
  </verify>
  <done>`EST-01` carries exactly one of three verdicts read off a field-by-field external read path with no hedging; the literature's answer on prior reconstruction is cited or its absence recorded with a check list; a machine-readable `PHASE-6B-TERMINAL:` line makes the terminal branch executable by every downstream plan.</done>
</task>

<task type="checkpoint:decision" gate="blocking">
  <name>Task 3: Ratify the thresholds, the candidate set and the EST-01 verdict — or close the phase</name>
  <files>control/spec/POOL-ALGEBRA.md, control/spec/NU-CONSTRUCTIBILITY.md</files>
  <read_first>
    - `/home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller/control/spec/POOL-ALGEBRA.md` §3.1 (the dimensional check), §4 (the sets and window boundary), §5 (the venue-independent thresholds)
    - `/home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller/control/spec/NU-CONSTRUCTIBILITY.md` §3 and §4
    - `/home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller/control/.planning/phases/06B-research-venue-and-estimating-mev/06B-CONTEXT.md` — "Venue and chain selection": the chain and pool set are OUTPUTS of the research, not priors
  </read_first>
  <decision>
Four things, in one message, in this order:

**(a) `EST-01`'s verdict.** If `NOT CONSTRUCTIBLE`, the phase closes here and (b)–(d) are moot.

**(b) §3.1's `DIMENSIONAL CHECK`.** If it returned **FAIL**, the freeze cannot be written: O4
changes the regressor, not its interpretation, and `06B-03` must not proceed on a provisional
convention. The user decides whether to close the phase on the dimensional defect or to route it
to Phase 1 `NOT-05` as a blocking prerequisite and pause 6b.

**(c) The venue-independent thresholds (§5).** F floor and its published critical value, target
power and MDES with the arithmetic shown, minimum `Δt` dispersion. **This is the last moment they
can be set without dispersion numbers in hand.**

**(d) The candidate sets and the window A/B boundary (§4).** Once ratified they are the sets
`EST-02` measures over **in full**, unprunable on a realized first-stage F.

The user is **not** picking the venue here. That happens in `06B-02`, after dispersion is
measured on window A.
  </decision>
  <context>
The research has returned; the candidate sets are outputs of it, not priors.

Ratifying the set **and the venue-independent thresholds** before measurement is what makes
`EST-09`'s split meaningful: the menu and the bar are fixed, then window A ranks, then the user
picks. Ratifying a dispersion floor *after* seeing the dispersion numbers is not a disclosable
exception — it is choosing the bar to clear the jump.

**On the dimensional check:** `ℙ_{Δ_ARB} = σ/(σ + φ√(2/Δt))` is a **Möbius function of `σ`**.
Substituting `σ²` does not rescale it; it changes the regressor. A `FAIL` therefore cannot be
carried as `PROVISIONAL` into a freeze.
  </context>
  <options>
    <option id="ratify">
      <name>Ratify thresholds, sets and window boundary as written</name>
      <pros>The bar and the menu are fixed before any number exists; `EST-02` measures in full; the pruning ban is enforceable.</pros>
      <cons>A chain that turns out uninteresting still consumes a measurement.</cons>
    </option>
    <option id="amend">
      <name>Amend a threshold or a set, then ratify</name>
      <pros>Still pre-measurement, so no winner's curse is incurred.</pros>
      <cons>Every amendment must cite a convention, a published critical value, or shown arithmetic — never an expected dispersion, which would be selection on an unmeasured outcome.</cons>
    </option>
    <option id="halt-dimensional">
      <name>`DIMENSIONAL CHECK: FAIL` — halt 6b and route O4 to Phase 1 `NOT-05`</name>
      <pros>Refuses to write a specification on a regressor whose identity is unsettled.</pros>
      <cons>6b blocks on an unexecuted phase; the estimation slips.</cons>
    </option>
    <option id="close-est01">
      <name>Close the phase on `EST-01: NOT CONSTRUCTIBLE`</name>
      <pros>A delivered result on the `υ` precedent; `06B-06` still runs to back-propagate it.</pros>
      <cons>No estimate of `Ḡ`; the corrected law's only empirical factor stays open.</cons>
    </option>
  </options>
  <action>
Present (a)–(d) in one message. Show §4.1's table **without any dispersion column** — it does not
exist yet, and a placeholder invites a pick on it.

After the user rules, append to `POOL-ALGEBRA.md`:

```
## 7. Ratification

**Put to the user:** <YYYY-MM-DD>
**RULING:** <the user's words, quoted, not paraphrased>
**Dimensional check outcome ratified:** PASS | FAIL
**Ratified chain set:** <the final list — actual chain names>
**Ratified pool set:** <the final list — actual pool identifiers>
**Ratified window boundary:** window A = [<actual dates>), window B = [<actual dates>)
**Ratified thresholds:** F floor <n> (MOP effective F, published crit <v>, floor >= crit)
**MOP CRIT VERIFIED:** <value> at τ=<value>, size=<value>, K=1 — <the reviewer who looked it up> —
<the source consulted, table and page>
**Ratified bias tolerance tau:** <value, <= 0.10>
**Ratified power and MDES:** target power <p>, MDES <m> in units of Ḡ, MDES ceiling <mc>
**Ratified minimum N:** <n> chain-time periods carrying Δt variation
**Ratified minimum Δt dispersion:** <d> (<statistic>), by the §5 inversion
**Ratified split feasibility predicate:** window B length >= <l>, chain-time periods >= <k>
**Amendments made and why:** <each, with the convention / published value / shown arithmetic that
justified it — or NONE>
**Status:** RATIFIED
**POOL-ALGEBRA §5 BLOB:** <the sha printed by the command below — §5's lock pin>
```

Immediately after the commit, print and record the lock pin, then paste it into the
`**POOL-ALGEBRA §5 BLOB:**` line and amend **that line only**:

```
git rev-parse "$(git log --reverse --format=%H -- control/spec/POOL-ALGEBRA.md | head -1):control/spec/POOL-ALGEBRA.md"
```

**This blob sha is §5's lock.** `06B-03` and `06B-04` read §5 from it via `git cat-file blob <sha>`
rather than from the working tree, so a wave-4 edit to both files cannot pass by matching itself.

**The `**Status:**` line carries exactly one word: `RATIFIED`, or `PHASE-CLOSED-EST01`, or
`HALTED-DIMENSIONAL`.** Every field above must have its angle-bracket placeholders **replaced**;
a line still containing `<`, `>` or a ` | ` alternation is an unedited template and fails.

And append to `NU-CONSTRUCTIBILITY.md`:

```
## 6. Verdict acknowledged

**Put to the user:** <YYYY-MM-DD>
**RULING:** <the user's words>
```

**Two-step review, THEN commit.** Run **Reality Checker** and **one named specialist, IN
PARALLEL** over both files. For these artifacts the specialist is an econometrics/identification
reviewer. Record in a `## Review` section on each file, with **counts and dispositions**:

```
## Review
**Reviewer 1 (always):** Reality Checker — <date>. findings: <B> BLOCKER / <M> MAJOR / <m> MINOR.
  disposition: <resolved N, carried N — each carried item named>.
**Reviewer 2 (named specialist):** <name> — chosen because <reason>. <date>.
  findings: <B> BLOCKER / <M> MAJOR / <m> MINOR. disposition: <...>.
```

**The `**MOP CRIT VERIFIED:**` line is the reviewers' job, and this is the only place it can be
discharged.** No automated check here can tell a correctly tabulated Montiel Olea–Pflueger value
from a plausible invention: `published critical value: 5.0` with `first-stage F floor: 5.0`
satisfies every numeric relation in §5, while the true entry at τ=10%, size 5%, K=1 is ≈23.1. One
of the two reviewers must look the value up and sign that line with the source consulted. The
review runs **before** §5's blob is locked, so a wrong value is cheap to fix here and needs a HALT
afterwards.

Then commit scoped by path:

```
cd /home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller
git add control/spec/POOL-ALGEBRA.md control/spec/NU-CONSTRUCTIBILITY.md
git commit -m "docs(06B): pool algebra in Algebra Integral state, EST-01 verdict, thresholds and sets ratified

Closes LIT-04 and EST-01. nu and lambda_ARB derived in the venue's own state
variables with a carrier and a clock per symbol; the dimensional check on
P_{Delta_ARB} derived and recorded; the chain/pool axis distinction recorded;
venue-independent thresholds (MOP effective-F floor with its published critical
value, power >= 0.80 with shown MDES arithmetic, minimum Delta-t dispersion)
pre-registered BEFORE any dispersion exists; candidate sets and the window A/B
boundary pre-declared and ratified.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>" -- control/spec/POOL-ALGEBRA.md control/spec/NU-CONSTRUCTIBILITY.md
git show --name-only --format="" HEAD
git log --reverse --format='POOL-ALGEBRA FIRST COMMIT %H %ct' -- control/spec/POOL-ALGEBRA.md | head -1
```
  </action>
  <acceptance_criteria>
    - `POOL-ALGEBRA.md` contains `## 7. Ratification` with `**Put to the user:**`, `**RULING:**`, `**Dimensional check outcome ratified:**`, `**Ratified chain set:**`, `**Ratified pool set:**`, `**Ratified window boundary:**`, `**Ratified thresholds:**`, `**Amendments made and why:**`, and a `**Status:**` line.
    - The `**Status:**` line matches `^\*\*Status:\*\* (RATIFIED|PHASE-CLOSED-EST01|HALTED-DIMENSIONAL)$` **exactly** — no alternation, no trailing template text.
    - A `**MOP CRIT VERIFIED:**` line is present, carries `K=1`, names a reviewer and a source, and its leading value equals §5's `published critical value:`.
    - **Template placeholders are gone:** none of the eight `## 7.` field lines contains `<`, `>`, or ` | `.
    - `**Dimensional check outcome ratified:**` agrees with §3.1's `DIMENSIONAL CHECK:` line; if it is `FAIL`, `**Status:**` is `HALTED-DIMENSIONAL` or `PHASE-CLOSED-EST01`.
    - `NU-CONSTRUCTIBILITY.md` contains `## 6. Verdict acknowledged` with `**Put to the user:**` and `**RULING:**`, and its `**RULING:**` line contains no `<` or `>`.
    - Both files carry a `## Review` section with `Reality Checker`, a second named reviewer, two `findings:` lines carrying BLOCKER/MAJOR/MINOR counts, and two `disposition:` lines.
    - `POOL-ALGEBRA.md` still contains `No dispersion has been measured at the time of writing.` and still contains no dispersion statistic.
    - `git show --name-only --format="" HEAD` lists exactly two paths, both under `control/spec/`.
    - The **first** commit `%ct` of `control/spec/POOL-ALGEBRA.md` is `-ge` the **first** commit `%ct` of `control/spec/RESEARCH-REGISTER.md` — this **records** (does not prove) that the register predates the candidate set.
    - **What that check is worth, on its own terms — it does not borrow an anchor from elsewhere.** `%ct` is settable via `GIT_COMMITTER_DATE` and is rewritten by `amend`/`rebase`, and **nothing in this phase anchors it**: the Dune execution timestamp is transcribed by this session and is not an independent anchor either (`06B-02` §2 withdraws that claim in writing). So this comparison **detects an accident, not an adversary** — it catches a plan run out of order and does not detect deliberate back-dating. The ordering guarantees that survive an adversary are **structural**, not temporal: `06B-03` cannot write a freeze while a `PHASE-6B-TERMINAL:` marker is set or the dimensional check is not `PASS`; `06B-04` reads every threshold out of the frozen blob rather than the working tree; `06B-05` cannot create a file without a single column-0 `VERDICT: GATE OPENS`; and §5a's lock is enforced by blob sha. Those are what the phase rests on.
    - **Scope sentinel:** the three `01-3.*.before` snapshots exist, are **newer than `.sentinel/.runstart`** (taken this run) and **not newer than the artifact** (taken before the edit), and each `diff -q` cleanly against the live value with `??` filtered on both sides — peer trees and the repo-root `.planning/` are **unchanged by this task**, which is not the same as clean.
  </acceptance_criteria>
  <resume-signal>Rule on (a) the `EST-01` verdict, (b) the dimensional check, (c) the thresholds, (d) the sets and window boundary. Reply `ratify`, `amend: <changes>`, `halt-dimensional`, or `close`.</resume-signal>
  <verify>
    <automated>cd /home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller && P=control/spec/POOL-ALGEBRA.md && N=control/spec/NU-CONSTRUCTIBILITY.md && F="$P" && for s in '## 7. Ratification' '**MOP CRIT VERIFIED:**' 'K=1' '**Put to the user:**' '**RULING:**' '**Dimensional check outcome ratified:**' '**Ratified chain set:**' '**Ratified pool set:**' '**Ratified window boundary:**' '**Ratified thresholds:**' '**Amendments made and why:**' '## Review' 'Reality Checker' 'No dispersion has been measured at the time of writing.'; do grep -qF "$s" $P || { echo "MISSING in POOL-ALGEBRA: $s"; exit 1; }; done && grep -qE '^\*\*Status:\*\* (RATIFIED|PHASE-CLOSED-EST01|HALTED-DIMENSIONAL)$' $P && test $(awk '/^## 7\. Ratification/,0' $P | grep -E '^\*\*(Put to the user|RULING|Dimensional check outcome ratified|Ratified chain set|Ratified pool set|Ratified window boundary|Ratified thresholds|Amendments made and why|Status):\*\*' | grep -cE '<|>|\| ') -eq 0 && D=$(grep -oE '^DIMENSIONAL CHECK: (PASS|FAIL)' $P | awk '{print $3}') && R=$(grep -F '**Dimensional check outcome ratified:**' $P | grep -oE 'PASS|FAIL' | head -1) && test "$D" = "$R" && { test "$D" = PASS || grep -qE '^\*\*Status:\*\* (HALTED-DIMENSIONAL|PHASE-CLOSED-EST01)$' $P; } && for s in '## 6. Verdict acknowledged' '**Put to the user:**' '**RULING:**' '## Review' 'Reality Checker'; do grep -qF "$s" $N || { echo "MISSING in NU-CONSTRUCTIBILITY: $s"; exit 1; }; done && test $(grep -F '**RULING:**' $N | grep -cE '<|>') -eq 0 && for f in $P $N; do test $(grep -cE '^ *findings: *[0-9]+ BLOCKER */ *[0-9]+ MAJOR */ *[0-9]+ MINOR' $f) -ge 2 || { echo "REVIEW COUNTS MISSING: $f"; exit 1; }; done && test -z "$(grep -inE '(std|sd|stdev|standard deviation|IQR|coefficient of variation|corr|rho) *[:=] *[0-9]' $P)" && test $(git show --name-only --format="" HEAD | grep -c .) -eq 2 && test $(git show --name-only --format="" HEAD | grep -vc '^control/spec/') -eq 0 && A=$(git log --reverse --format=%ct -- control/spec/POOL-ALGEBRA.md | head -1) && B=$(git log --reverse --format=%ct -- control/spec/RESEARCH-REGISTER.md | head -1) && test "$A" -ge "$B" && SENT=control/.planning/phases/06B-research-venue-and-estimating-mev/.sentinel && test "$SENT/01-3.plank.before" -nt "$SENT/.runstart" && { test ! -e "${F:-/nonexistent}" || ! test "$SENT/01-3.plank.before" -nt "${F:-/nonexistent}"; } && diff -q "$SENT/01-3.plank.before" <(git -C ../plank status --porcelain | grep -v '^??') && diff -q "$SENT/01-3.lean4spec.before" <(git -C ../lean4-spec status --porcelain | grep -v '^??') && diff -q "$SENT/01-3.rootplanning.before" <(git status --porcelain .planning/) && echo PASS</automated>
  </verify>
  <done>The user ruled on the `EST-01` verdict, the dimensional check, the venue-independent thresholds and the candidate sets; every ratification field has its template placeholders replaced and the status line carries a single unambiguous token; a dimensional FAIL halts rather than becoming a provisional convention; both artifacts passed a two-step review recorded with severity counts before the commit.</done>
</task>

</tasks>

<verification>
1. `DIMENSIONAL CHECK` is derived by the executor, returns exactly one of PASS/FAIL, and a FAIL
   cannot pass Task 3 as `RATIFIED`.
2. No dispersion statistic and no σ-channel correlation appears anywhere — measurement is
   `06B-02`'s, and a measured threat statistic would make the pick an argmax over what `EST-08`
   later tests.
3. Venue-independent thresholds are fixed here, with a named published critical value, power
   ≥ 0.80, and shown MDES arithmetic.
4. `EST-01` returns one of three verdicts plus a machine-readable `PHASE-6B-TERMINAL:` line that
   makes the terminal branch executable downstream.
5. Ratification lines carry no template placeholders; `**Status:**` is a single token.
6. Peer trees and repo-root `.planning/` **unchanged by this plan**, measured BEFORE vs AFTER.
</verification>

<success_criteria>
- `LIT-04` closed: venue state variables, the two-axis distinction, the dimensional check
  returned, the candidate sets, the window boundary and the venue-independent thresholds all on
  the record before any measurement.
- `EST-01` closed: one terminal verdict with a field-level read path, or the phase closed on
  `NOT CONSTRUCTIBLE` with a marker downstream plans honour.
</success_criteria>

<output>
After completion, create
`/home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller/control/.planning/phases/06B-research-venue-and-estimating-mev/06B-01-SUMMARY.md`,
recording the `EST-01 VERDICT`, the `PHASE-6B-TERMINAL` line, the `DIMENSIONAL CHECK` line, the
ratified thresholds, sets and window boundary, and the `POOL-ALGEBRA FIRST COMMIT` line.
</output>
