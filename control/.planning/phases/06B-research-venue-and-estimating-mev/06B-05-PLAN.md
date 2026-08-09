---
phase: 06B-research-venue-and-estimating-mev
plan: 05
type: execute
wave: 6
depends_on: ["06B-04"]
files_modified:
  - control/spec/STAGE2-RESULT.md
  - control/analysis/gbar_stage2.py
autonomous: false
requirements: [EST-04]

must_haves:
  truths:
    - "This plan produces NO file unless `06B-04` recorded a single column-0 `VERDICT: GATE OPENS`; it distinguishes 'gate closed by verdict' from 'Stage 1 never ran'."
    - "`ν = a + b·σ_ℓ(c(λ − d))` is fitted by nonlinear IV/GMM and `(a,b,c,d)` reported with a full covariance matrix."
    - "`Ḡ = b·c·σ_ℓ'(c(λ−d))` is reported as a function with delta-method errors, vanishing on the saturation bands."
    - "The admissible band is intersected with `Theorem36_no_interior_root_off_the_band`'s responsive band, quoted verbatim from the Lean source."
    - "Stage 2 uses its OWN script; `gbar_stage1.py` is asserted byte-unchanged so the gate-deciding result stays reproducible."
    - "`EST-04` remains fully load-bearing — the 2026-08-09 demotion was withdrawn and may not be cited."
  artifacts:
    - path: "control/spec/STAGE2-RESULT.md"
      provides: "The fitted (a,b,c,d) with covariance, Ḡ as a logistic bump, and the admissible band intersected with Theorem36's responsive band"
      min_lines: 110
      contains: "GATE CHECK:"
    - path: "control/analysis/gbar_stage2.py"
      provides: "The pinned, sha256-recorded Stage 2 script — separate from Stage 1's, which must not be mutated"
      min_lines: 30
  key_links:
    - from: "control/spec/STAGE2-RESULT.md"
      to: "control/spec/STAGE1-RESULT.md"
      via: "the gate check quotes the single column-0 verdict line verbatim before anything is fitted"
      pattern: "VERDICT: GATE OPENS"
    - from: "control/spec/STAGE2-RESULT.md"
      to: "control/aristotle/tax2-result/project_aristotle/RequestProject/MevTaxProgram.lean"
      via: "the admissible band is intersected with Theorem36_no_interior_root_off_the_band's responsive band"
      pattern: "Theorem36_no_interior_root_off_the_band"
---

<objective>
Fit the magnitude — `ν = a + b·σ_ℓ(c(λ − d))` — behind the hard gate, and report `Ḡ` as a logistic
bump with its admissible band.

Purpose: `EST-04`. **`EST-04` produces no output unless Stage 1's verdict is "gate opens"**
(`ROADMAP.md` Phase 6b SC4). On either other verdict, Stage 2 is not run and the phase closes with
Stage 1's verdict as its deliverable.

**`EST-04` is FULLY LOAD-BEARING.** A demotion was proposed on 2026-08-09 and **withdrawn the same
day**: composing `Theorem 30` + `Theorem 29` + `∂ν/∂τ = Ḡ·(∂λ/∂τ)` gives a FOC residual that is
**affine in `Ḡ`**, so evaluating the residual *is* evaluating `Ḡ`. That composition was refuted-as-
a-free-option by two independent reviewers and by the orchestrator's own derivation, and is
**PENDING `NEC-00`'s formal carrier** — `REQUIREMENTS.md` `NEC-00` requires it "verified, not
inherited", and the Gates table lists it **NOT REACHED**. The withdrawn demotion may not be cited.

Output: `control/spec/STAGE2-RESULT.md`, `control/analysis/gbar_stage2.py`.
</objective>

<execution_context>
@/home/jmsbpp/.claude/get-shit-done/workflows/execute-plan.md
@/home/jmsbpp/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@/home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller/control/.planning/ROADMAP.md
@/home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller/control/.planning/REQUIREMENTS.md
@/home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller/control/spec/ECONOMETRICS-DESIGN.md
@/home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller/control/spec/PRE-REGISTRATION.md
@/home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller/control/spec/STAGE1-RESULT.md

**Path glossary.** `WT` = `/home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller`. `PLANK` =
`/home/jmsbpp/cfmms-playground/cfmm-wt/plank` (**READ-ONLY**). `LEAN` =
`/home/jmsbpp/cfmms-playground/cfmm-wt/lean4-spec` (**PEER-OWNED, READ-ONLY** — a different tree
from `control/aristotle/`, which is this project's own). `PROGRAM_LEAN` =
`WT/control/aristotle/tax2-result/project_aristotle/RequestProject/MevTaxProgram.lean` — read here,
**not modified in this plan** (`06B-06` writes to it).

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

**As the FIRST action of every task**, with `TAG` = `05-1`, `05-2`, `05-3`:

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
- Every `<verify>` is one unbroken `&&` chain ending in `echo PASS`. Never `done;`.
- `gsd-tools commit --files` commits the entire staged index. Use `git commit -- <paths>`; assert
  paths with `git show --name-only --format="" HEAD`, never `--stat`.
- **`control/analysis/gbar_stage1.py` is READ-ONLY here.** Stage 2 writes its own
  `control/analysis/gbar_stage2.py`. Extending Stage 1's script would silently break the
  reproduction guarantee for the gate-deciding result; the verify asserts Stage 1's file is
  byte-unchanged against `git show HEAD:`.
- **The withdrawn-demotion phrase is banned as a CLAIM, not as a string.** Nothing in this
  document may assert that the estimation is not load-bearing. The `<action>` templates below are
  written so that the banned phrase never appears in the artifact at all — write
  `EST-04 is FULLY LOAD-BEARING` and cite the withdrawal by date, never by quoting the retracted
  sentence.
- **No re-specification of Stage 1.** Stage 1 is closed.
- **Sample:** window B, the same window Stage 1 estimated on. Window A is not re-entered.
</context>

<inherited>
**Phases 1, 2, 3 and 6a are UNEXECUTED at plan time.** `STAGE2-RESULT.md` opens with an
`## Inherited, not assumed` section in which every item carries `PROVISIONAL — pending <req>` or
`SETTLED BY <artifact> §<n>`:

- **O4 — `σ` vs `σ²`.** `SETTLED BY POOL-ALGEBRA.md §3.1` for the estimating equation. `b` and `c`
  are unit-bearing and a σ/σ² confusion would mis-scale `Ḡ`; every parameter row states its units
  against that settled convention.
- **The event-clock ruling** (Phase 2 `FRM-03`). `PROVISIONAL — pending FRM-03`; the exposure
  ruling is quoted from `PRE-REGISTRATION.md` §7.
- **The hypothesis discipline** (Phase 3 `PRF-03`, `PRF-06`). `PROVISIONAL — pending PRF-06`.
  **`H1` (`∂L̄/∂π^φ`) is undischarged on every branch** — `EST-03` tested `H2` only. `H1` scales
  and signs the on-chain loop gain through the residual's prefactor (`Proposition 12`), which
  Phase 6a's `NEC-07` records. A fitted `Ḡ` does not discharge it.
- **`NEC-04`'s coupling verdict and recomposition rule** (Phase 6a). `PROVISIONAL — pending
  NEC-04`. If Stage 1 reported under `partially derivable`, `Ḡ` here is a **residual** gain and
  `sign(residual) ⇏ sign(total)`; the caveat is stated **on the reported number**, not in a
  footnote.
- **`NEC-00`'s affine-in-`Ḡ` verdict** (Phase 6a). `PROVISIONAL — pending NEC-00`.
- **O2** — the FOC root is not established to be the minimiser
  (`Proposition15_level_reading_second_order_undetermined`, `PROGRAM_LEAN:823`);
  `Proposition15_single_crossing_gives_minimum` (:890) is conditional on a single-crossing property
  **nothing proves**. `PROVISIONAL — pending O2`.
- **O8 — `λ_ARB`'s asymptotics.** `PROVISIONAL — pending O8`. **State the attribution precisely,
  because the obvious phrasing is self-contradicting.** The carrier is `mevMulti_nonneg`
  (`control/aristotle/tax-result/project_aristotle/RequestProject/MevOptimization.lean:250`), and
  its **conclusion is `0 ≤ mevMulti …` — the TOTAL**, not the summands. Per-summand nonnegativity
  is a **proof-internal step** (`Finset.sum_nonneg`), true under the same hypotheses but **not what
  the declaration states**. Monotone non-decreasing follows from that step, so it is a **derived
  reading with no carrier**: no declaration in this corpus states monotonicity. And divergence
  needs the summands to be **non-summable**, which nothing shows. So: `λ_ARB ≥ 0` is carried;
  monotone non-decreasing is derived; **divergence is OPEN (O8)**, and with it whether `Ḡ → 0` and
  the loop stalls.
- **The review register** (Phase 1 `HND-05`) does not exist; the artifact carries its own
  `## Review`.
</inherited>

<tasks>

<task type="checkpoint:human-verify" gate="blocking">
  <name>Task 1: THE GATE CHECK — confirm a single column-0 `VERDICT: GATE OPENS` before anything is fitted</name>
  <files>control/spec/STAGE2-RESULT.md</files>
  <read_first>
    - `/home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller/control/spec/STAGE1-RESULT.md` §4 (the single verdict line) and §6 (the gate state the user already ruled on)
    - `/home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller/control/.planning/ROADMAP.md` — the `Stage gate — EST-03` row and Phase 6b's "Hard gate semantics"
    - `/home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller/control/spec/PRE-REGISTRATION.md` §5.1 and §6 — which verdict permits `EST-04`, and why `GATE OPENS` is unreachable under an infeasible split
  </read_first>
  <what-built>
Nothing yet. This checkpoint exists **before** any fitting and is what makes `EST-04`'s hard gate
real rather than declared. Run and report verbatim:

```
cd /home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller
test -f control/spec/STAGE1-RESULT.md && echo "STAGE1 EXISTS" || echo "STAGE1 ABSENT — Stage 1 never ran"
grep -c '^VERDICT:' control/spec/STAGE1-RESULT.md 2>/dev/null || true
grep -E '^VERDICT:' control/spec/STAGE1-RESULT.md 2>/dev/null
grep -F '**Gate state:**' control/spec/STAGE1-RESULT.md 2>/dev/null
```
  </what-built>
  <how-to-verify>
Four distinguishable states — report which one, by name:

1. **`GATE OPEN`** — `STAGE1-RESULT.md` exists, `grep -c '^VERDICT:'` returns exactly `1`, that
   line is `VERDICT: GATE OPENS`, and the gate state is `OPEN`. Confirm and proceed to Task 2.
2. **`GATE CLOSED BY VERDICT`** — the single verdict line is `WRONG SIGN — H2 REFUTED` or
   `NOT IDENTIFIED`, or the gate state is `CLOSED`. **This plan does not run.** Write **nothing**:
   no file, no stub, no partial fit "for information". Report `06B-05: NOT RUN — GATE CLOSED BY
   VERDICT: <verdict>` and stop. The phase proceeds to `06B-06`.
3. **`STAGE 1 NEVER RAN`** — `STAGE1-RESULT.md` does not exist, because a terminal marker or a
   missing freeze stopped `06B-04`. **This plan does not run.** Report
   `06B-05: NOT RUN — STAGE 1 NEVER RAN (<the marker or the missing freeze>)` and stop. This is a
   **different** outcome from state 2 and must not be reported as the same thing — one means the
   test was run and closed the gate, the other means the test never happened.
4. **`INCONSISTENT`** — `grep -c '^VERDICT:'` returns anything other than `1`, or the verdict and
   the gate state disagree. That is a defect in `06B-04`; stop until it is reconciled. Do **not**
   resolve it by picking the friendlier reading.
  </how-to-verify>
  <action>
**FIRST: the scope sentinel with `TAG=05-1`.**

Run the four commands. Report the state by name with the outputs verbatim.

**Only in state 1**, create `control/spec/STAGE2-RESULT.md` with this header and nothing else yet:

```
# STAGE 2 — magnitude of `Ḡ = ∂ν/∂λ_MEV`

**Requirement:** EST-04 — runs ONLY behind the `EST-03` gate
**Run:** <YYYY-MM-DD>
**GATE CHECK:** `control/spec/STAGE1-RESULT.md @ <sha>` carries exactly one column-0 verdict line,
and it reads `VERDICT: GATE OPENS`.
**Gate state (as ruled by the user at `STAGE1-RESULT.md` §6):** OPEN
**FREEZE PIN:** `control/spec/PRE-REGISTRATION.md @ <FREEZE SHA>`
**Stage 1 script (READ-ONLY here):** `control/analysis/gbar_stage1.py` @ sha256 <64-hex, copied
from `STAGE1-RESULT.md`> — asserted byte-unchanged by this plan.
**Sample:** window B = [<start>, <end>) — the same window Stage 1 estimated on.

**EST-04 is FULLY LOAD-BEARING.** The demotion proposed on 2026-08-09 was **withdrawn the same
day**: the FOC residual is affine in `Ḡ`, so evaluating it is evaluating `Ḡ`. That composition is
**PENDING `NEC-00`'s formal carrier** and the withdrawn reading is not cited in this document.
```

Then `## Inherited, not assumed` — the eight items from this plan's `<inherited>` block, each
carrying `PROVISIONAL — pending` or `SETTLED BY`.

**In states 2, 3 and 4, create no file at all.** An empty or stub `STAGE2-RESULT.md` is itself a
gate violation, because a later reader cannot distinguish a stub from a suppressed result.
  </action>
  <acceptance_criteria>
    - **State 1:** `STAGE1-RESULT.md` has exactly one `^VERDICT:` line reading `VERDICT: GATE OPENS` **and** `STAGE2-RESULT.md` exists containing `**GATE CHECK:**`, `**Gate state (as ruled by the user at \`STAGE1-RESULT.md\` §6):** OPEN`, `**FREEZE PIN:**`, `**Stage 1 script (READ-ONLY here):**`, `## Inherited, not assumed`, and the names `O4`, `FRM-03`, `PRF-03`, `NEC-04`, `NEC-00`, `O2`, `O8`.
    - **States 2–4:** `control/spec/STAGE2-RESULT.md` does **not exist**.
    - No third possibility: a `STAGE2-RESULT.md` existing without a single `VERDICT: GATE OPENS` in Stage 1 fails.
    - Where the file exists it contains `EST-04 is FULLY LOAD-BEARING` and does **not** contain the string `no longer load-bearing` — the header is written so that phrase never appears.
    - The recorded Stage 1 script sha256 equals `sha256sum control/analysis/gbar_stage1.py`.
    - **Scope sentinel:** the three `05-1.*.before` snapshots exist, are **newer than `.sentinel/.runstart`** (taken this run) and **not newer than the artifact** (taken before the edit), and each `diff -q` cleanly against the live value with `??` filtered on both sides — peer trees and the repo-root `.planning/` are **unchanged by this task**, which is not the same as clean.
  </acceptance_criteria>
  <resume-signal>Name the state (`GATE OPEN`, `GATE CLOSED BY VERDICT`, `STAGE 1 NEVER RAN`, `INCONSISTENT`). Reply `proceed` only for `GATE OPEN`.</resume-signal>
  <verify>
    <automated>cd /home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller && if [ ! -f control/spec/STAGE1-RESULT.md ]; then test ! -f control/spec/STAGE2-RESULT.md && SENT=control/.planning/phases/06B-research-venue-and-estimating-mev/.sentinel && test "$SENT/05-1.plank.before" -nt "$SENT/.runstart" && diff -q "$SENT/05-1.plank.before" <(git -C ../plank status --porcelain | grep -v '^??') && diff -q "$SENT/05-1.lean4spec.before" <(git -C ../lean4-spec status --porcelain | grep -v '^??') && diff -q "$SENT/05-1.rootplanning.before" <(git status --porcelain .planning/) && echo "PASS (NOT RUN — STAGE 1 NEVER RAN)" && exit 0; echo "STAGE 1 NEVER RAN BUT STAGE2 FILE EXISTS OR SENTINEL FAILED"; exit 1; fi && N=$(grep -c '^VERDICT:' control/spec/STAGE1-RESULT.md || true) && { test "$N" -eq 1 || { echo "PASS (NOT RUN — INCONSISTENT: $N column-0 verdict lines in STAGE1-RESULT.md)"; exit 0; }; } && if grep -qxF 'VERDICT: GATE OPENS' control/spec/STAGE1-RESULT.md; then F=control/spec/STAGE2-RESULT.md && test -f $F && for s in '**GATE CHECK:**' 'VERDICT: GATE OPENS' '**FREEZE PIN:**' '**Stage 1 script (READ-ONLY here):**' '## Inherited, not assumed' 'O4' 'FRM-03' 'PRF-03' 'NEC-04' 'NEC-00' 'O2' 'O8' 'EST-04 is FULLY LOAD-BEARING'; do grep -qF "$s" $F || { echo "MISSING: $s"; exit 1; }; done && ! grep -qF 'no longer load-bearing' $F && grep -F '**Gate state' $F | grep -qF 'OPEN' && H=$(grep -F 'gbar_stage1.py' $F | grep -oE '[0-9a-f]{64}' | head -1) && test "$H" = "$(sha256sum control/analysis/gbar_stage1.py | cut -d' ' -f1)" && SENT=control/.planning/phases/06B-research-venue-and-estimating-mev/.sentinel && test "$SENT/05-1.plank.before" -nt "$SENT/.runstart" && { test ! -e "${F:-/nonexistent}" || ! test "$SENT/05-1.plank.before" -nt "${F:-/nonexistent}"; } && diff -q "$SENT/05-1.plank.before" <(git -C ../plank status --porcelain | grep -v '^??') && diff -q "$SENT/05-1.lean4spec.before" <(git -C ../lean4-spec status --porcelain | grep -v '^??') && diff -q "$SENT/05-1.rootplanning.before" <(git status --porcelain .planning/) && echo "PASS gate=open"; else test ! -f control/spec/STAGE2-RESULT.md && SENT=control/.planning/phases/06B-research-venue-and-estimating-mev/.sentinel && test "$SENT/05-1.plank.before" -nt "$SENT/.runstart" && diff -q "$SENT/05-1.plank.before" <(git -C ../plank status --porcelain | grep -v '^??') && diff -q "$SENT/05-1.lean4spec.before" <(git -C ../lean4-spec status --porcelain | grep -v '^??') && diff -q "$SENT/05-1.rootplanning.before" <(git status --porcelain .planning/) && echo "PASS (NOT RUN — GATE CLOSED BY VERDICT)"; fi</automated>
  </verify>
  <done>The gate was checked against Stage 1's single column-0 verdict line and the user's recorded gate state before anything was fitted; the four states are distinguished by name, so "gate closed by verdict" is never reported as "Stage 1 never ran"; on `GATE OPEN` the file exists with its pins and the load-bearing statement, and on every other state no file was created.</done>
</task>

<task type="auto">
  <name>Task 2: Fit ν = a + b·σ_ℓ(c(λ − d)) by nonlinear IV/GMM, with a full covariance</name>
  <files>control/spec/STAGE2-RESULT.md, control/analysis/gbar_stage2.py</files>
  <read_first>
    - `/home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller/control/spec/STAGE2-RESULT.md` (the header from Task 1)
    - `/home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller/control/spec/ECONOMETRICS-DESIGN.md` §3 and §4 — `(c, d)` placement is **the main remaining researcher degree of freedom**
    - `/home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller/control/spec/PRE-REGISTRATION.md` §3.3 (units), §3.7 (sample), §3.8 (estimator, clustering, G)
    - `/home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller/control/spec/STAGE1-RESULT.md` §2.4 and §3.3 — the Stage 1 script and raw outputs, **read but never modified**
    - `~/.claude/skills/python-panel-data/SKILL.md`
    - `~/.claude/skills/anti-fishing-replication/SKILL.md`
  </read_first>
  <action>
**FIRST: scope sentinel `TAG=05-2`.**

Write a **new** script at `control/analysis/gbar_stage2.py`. **Do not edit
`control/analysis/gbar_stage1.py`** — it is the reproduction anchor for the gate-deciding result
and the verify asserts it is byte-identical to `git show HEAD:control/analysis/gbar_stage1.py`.
Record `sha256sum control/analysis/gbar_stage2.py`.

Append §1–§3 to `control/spec/STAGE2-RESULT.md`.

**`## 1. The specification`**

```
ν = a + b·σ_ℓ(c(λ − d)) + <the frozen controls from PRE-REGISTRATION §1.2> + u
```

`σ_ℓ` is the logistic. Estimated by **nonlinear IV / GMM** with `√Δt` as the excluded instrument,
SEs clustered at **chain-time**, G = <integer>, on window B. If G = 1, repeat the freeze's record
that cluster-robust inference at chain-time is invalid and name the inference actually used.

State in a bolded line: **`(c, d)` placement is the main remaining researcher degree of freedom**
(`ECONOMETRICS-DESIGN.md` §4). It is entered **only** because Stage 1 already passed on a
pre-fixed specification. `### 1.1 Degrees of freedom exercised` records:

- the starting values tried;
- the optimizer and convergence criterion;
- every alternative `(c, d)` parameterization considered and why it was rejected;
- whether any was chosen because it improved the fit — if so, that is recorded as a
  researcher-degree-of-freedom exercise, **not hidden**.

**`## 2. The fit`**

```
### 2.1 Point estimates
| Parameter | Estimate | SE (clustered chain-time) | Units | Provisional on |
| `a` | | | | |
| `b` | | | | |
| `c` | | | | |
| `d` | | | | |

### 2.2 Covariance matrix
<the full 4×4 covariance of (a, b, c, d), printed — a diagonal of standard errors is NOT a
covariance matrix, and `Ḡ`'s delta-method SE needs the off-diagonals>

### 2.3 Fit diagnostics
<J statistic / overidentification if applicable, convergence status, N, effective N in chain-time
periods>

### 2.4 Reproduction
**Script:** `control/analysis/gbar_stage2.py`  **Script sha256:** <64-hex>
**Stage 1 script unchanged:** `sha256sum control/analysis/gbar_stage1.py` = <the value recorded in
STAGE1-RESULT.md> — asserted, not assumed.
**Command:** <the exact re-runnable command>
**Raw output file:** `control/data/stage2/fit.txt` (committed)
**Raw output:** <verbatim, identical to the file>
```

**Anti-fabrication is enforced structurally**: the verify recomputes both script hashes, re-runs
the recorded command, and diffs against the committed raw-output file. **`**Command:**` must invoke
`control/analysis/gbar_stage2.py`** — `cat control/data/stage2/fit.txt` would diff a file against
itself and pass, which would make the reproduction guarantee vacuous.

**`## 3. `Ḡ` as a logistic bump`**

```
Ḡ(λ) = b·c·σ_ℓ'(c(λ − d))
```

Report it as a **function**, not a scalar: a table of `Ḡ(λ)` across the realized `λ` support on
window B, with delta-method standard errors using §2.2's **full** covariance. Then, verbatim:

```
`Ḡ` **vanishes on the saturation bands** — `Ḡ → 0` in the tails of the logistic. This is
consistent with `Theorem36_no_interior_root_off_the_band`
(`control/aristotle/tax2-result/project_aristotle/RequestProject/MevTaxProgram.lean:703`): where
the gate saturates there is no interior root anyway.
```

And, from **O8**, stated **precisely** — the earlier phrasing overclaimed and is corrected here:

```
**O8, stated correctly, with the attribution kept straight.** The carrier is `mevMulti_nonneg`
(`control/aristotle/tax-result/project_aristotle/RequestProject/MevOptimization.lean:250`) and
**its conclusion is `0 ≤ mevMulti …` — the TOTAL is nonnegative.** Per-summand nonnegativity is a
**proof-internal step** (`Finset.sum_nonneg`); it holds under the same hypotheses but is **not what
the declaration states**. From that step `λ_ARB` is **monotone NON-DECREASING** — a **derived
reading with NO CARRIER**, since no declaration in this corpus states monotonicity. **Divergence
is a further claim again**, requiring the summands to be **non-summable**, which nothing shows.
Therefore whether `λ_ARB` diverges — and hence whether `Ḡ → 0` asymptotically and the loop stalls
— is **OPEN (O8)**. Any use of the fitted `Ḡ` at large `λ` inherits that open question rather than
a settled asymptotic.
```

**If any fit target is missed** — non-convergence, a covariance that is not positive definite, a
`b` or `c` indistinguishable from zero at the frozen level — `anti-fishing-replication` fires:
HALT, disposition memo, wait for the **user** to enumerate a pivot. Do not re-parameterize, drop
observations, or switch the SE method.
  </action>
  <acceptance_criteria>
    - Guard: if `STAGE2-RESULT.md` does not exist (gate closed / Stage 1 never ran), the verify passes trivially.
    - Otherwise the file contains `## 1.`, `### 1.1 Degrees of freedom exercised`, `### 2.1`, `### 2.2 Covariance matrix`, `### 2.4 Reproduction`, `## 3.`, and `main remaining researcher degree of freedom`.
    - §2.1's table has exactly 4 parameter rows `a`, `b`, `c`, `d`, each with a numeric estimate, a numeric SE and a non-empty Units cell.
    - §2.2 contains ≥ 16 numeric entries (a full 4×4), not a 4-element diagonal.
    - §2.4 records both script hashes; `sha256sum control/analysis/gbar_stage2.py` matches the recorded value, and `control/analysis/gbar_stage1.py` is **byte-identical to `git show HEAD:`** — Stage 2 did not mutate Stage 1's anchor.
    - §2.4's `**Command:**` **contains `control/analysis/gbar_stage2.py`** and re-runs with stdout matching `control/data/stage2/fit.txt`.
    - §3 contains `σ_ℓ'`, `vanishes on the saturation bands`, `Theorem36_no_interior_root_off_the_band`, `MevTaxProgram.lean:703`.
    - §3's O8 block contains `monotone NON-DECREASING`, `the TOTAL is nonnegative`, `proof-internal step`, `NO CARRIER`, `non-summable`, `OPEN (O8)`, and cites `mevMulti_nonneg` **with its file**: `control/aristotle/tax-result/project_aristotle/RequestProject/MevOptimization.lean:250`. The file contains **no** claim that `λ_ARB` is divergent — `grep -icF 'divergent accumulator'` returns 0.
    - The file does not contain `no longer load-bearing`.
    - `git status --porcelain control/aristotle/` is empty — `06B-06` owns that write.
    - **Scope sentinel:** the three `05-2.*.before` snapshots exist, are **newer than `.sentinel/.runstart`** (taken this run) and **not newer than the artifact** (taken before the edit), and each `diff -q` cleanly against the live value with `??` filtered on both sides — peer trees and the repo-root `.planning/` are **unchanged by this task**, which is not the same as clean.
  </acceptance_criteria>
  <verify>
    <automated>cd /home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller && F=control/spec/STAGE2-RESULT.md && if [ ! -f $F ]; then echo "PASS (NOT RUN)"; exit 0; fi && S2=control/analysis/gbar_stage2.py && test -f $S2 && for s in '### 1.1 Degrees of freedom exercised' 'main remaining researcher degree of freedom' '### 2.1' '### 2.2 Covariance matrix' '### 2.4 Reproduction' '**Command:**' '**Raw output:**' "σ_ℓ'" 'vanishes on the saturation bands' 'Theorem36_no_interior_root_off_the_band' 'MevTaxProgram.lean:703' 'monotone NON-DECREASING' 'the TOTAL is nonnegative' 'proof-internal step' 'NO CARRIER' 'non-summable' 'OPEN (O8)' 'control/aristotle/tax-result/project_aristotle/RequestProject/MevOptimization.lean:250' 'mevMulti_nonneg'; do grep -qF "$s" $F || { echo "MISSING: $s"; exit 1; }; done && test $(grep -icF 'divergent accumulator' $F) -eq 0 && ! grep -qF 'no longer load-bearing' $F && H2=$(grep -A2 -F '**Script:**' $F | grep -oE '[0-9a-f]{64}' | head -1) && test "$H2" = "$(sha256sum $S2 | cut -d' ' -f1)" && diff <(git show HEAD:control/analysis/gbar_stage1.py) control/analysis/gbar_stage1.py && test -f control/data/stage2/fit.txt && CMD=$(awk '/^### 2\.4/,0' $F | grep -F '**Command:**' | head -1 | sed 's/.*\*\*Command:\*\* *//' | tr -d '`') && printf '%s' "$CMD" | grep -qF 'control/analysis/gbar_stage2.py' && diff <(eval "$CMD" 2>&1) control/data/stage2/fit.txt && python3 -c "
import re
t=open('$F').read()
sec=t.split('### 2.1')[1].split('### 2.2')[0]
rows=[l for l in sec.splitlines() if l.strip().startswith('|') and not re.match(r'^\|[\s:\-|]+\|$',l.strip()) and 'Parameter' not in l]
names=[]
for l in rows:
    c=[x.strip().strip('\`') for x in l.strip().strip('|').split('|')]
    assert len(c)>=4, l
    names.append(c[0])
    assert re.search(r'[-0-9]',c[1]) and re.search(r'[0-9]',c[2]), 'non-numeric estimate/SE: '+l
    assert c[3], 'empty units: '+l
assert names==['a','b','c','d'], names
cov=t.split('### 2.2')[1].split('### 2.3')[0]
nums=re.findall(r'[-+]?[0-9]*\.?[0-9]+(?:[eE][-+]?[0-9]+)?',cov)
assert len(nums)>=16, 'covariance has %d numbers, need a full 4x4'%len(nums)
print('fit tables ok')
" && test -z "$(git status --porcelain control/aristotle/ 2>/dev/null)" && SENT=control/.planning/phases/06B-research-venue-and-estimating-mev/.sentinel && test "$SENT/05-2.plank.before" -nt "$SENT/.runstart" && { test ! -e "${F:-/nonexistent}" || ! test "$SENT/05-2.plank.before" -nt "${F:-/nonexistent}"; } && diff -q "$SENT/05-2.plank.before" <(git -C ../plank status --porcelain | grep -v '^??') && diff -q "$SENT/05-2.lean4spec.before" <(git -C ../lean4-spec status --porcelain | grep -v '^??') && diff -q "$SENT/05-2.rootplanning.before" <(git status --porcelain .planning/) && echo PASS</automated>
  </verify>
  <done>`(a,b,c,d)` are fitted with a full 4×4 covariance, every number reproducible from a re-run command and a recomputed script hash; Stage 1's script is proven byte-unchanged so the gate-deciding result stays reproducible; the `(c,d)` degrees of freedom are disclosed; `Ḡ` is a function with delta-method errors vanishing on the saturation bands, and O8 is stated as monotone non-decreasing with divergence OPEN rather than asserted.</done>
</task>

<task type="auto">
  <name>Task 3: The admissible band, intersected with Theorem36 — then review and commit</name>
  <files>control/spec/STAGE2-RESULT.md</files>
  <read_first>
    - `/home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller/control/spec/STAGE2-RESULT.md` §2–§3
    - `/home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller/control/aristotle/tax2-result/project_aristotle/RequestProject/MevTaxProgram.lean` — `Theorem36_no_interior_root_off_the_band` at :703 and `Proposition16_corrected_law` at :1054 (READ ONLY here)
    - `/home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller/control/.planning/ROADMAP.md` — Phase 6b SC5 and its restatement of **O2**
    - `/home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller/control/spec/ECONOMETRICS-DESIGN.md` §5
  </read_first>
  <action>
**FIRST: scope sentinel `TAG=05-3`.**

Append §4–§5 to `control/spec/STAGE2-RESULT.md`, then review and commit.

**`## 4. The admissible band`**

```
### 4.1 Where `Ḡ` is bounded away from zero
<the interval(s) of `λ` on which |Ḡ(λ)| exceeds a STATED numeric bound, with delta-method
confidence bands. "Bounded away from zero" without a number is not a band.>

### 4.2 Theorem36's responsive band
<quote `Theorem36_no_interior_root_off_the_band`'s statement VERBATIM in a fenced block, read from
MevTaxProgram.lean:703, then restate its band in this document's variables. Do not paraphrase a
Lean statement.>

### 4.3 The intersection — the controller's domain
**These two bands live in DIFFERENT VARIABLES and cannot be intersected as written.** §4.1's band
is an interval in **`λ`**; `Theorem36`'s `responsiveBand gammaR betaR W` is an interval in **`ν`**
(`MevTaxProgram.lean:703-717`, binder `nu t ∉ responsiveBand …`). Write the intersection in three
explicit steps and name the variable at each:

```
- 4.3a Pushforward. The fitted `ν(λ) = a + b·σ_ℓ(c(λ − d))` is the map. State whether it is
  monotone on §4.1's λ-interval (it is, for `b·c > 0`), so the image is an interval; give the
  image `ν(§4.1) = [ν(λ_lo), ν(λ_hi)]` with both endpoints evaluated.
- 4.3b Intersection IN ν. `[ν(λ_lo), ν(λ_hi)] ∩ responsiveBand(γ_R, β_R, W)`, with
  `responsiveBand`'s endpoints written out in this document's variables.
- 4.3c Pull back to λ. Apply `ν⁻¹` (well defined on the monotone branch) to 4.3b's result and
  report the controller's domain as an interval in **λ**, which is the variable the loop indexes.
  If `ν` is not monotone on the interval, say so and report the domain as the preimage, which may
  be a union — do not silently take the convex hull.
```

Then what happens outside it: `τ*` has no interior root there, so the set-point law does not
apply.

### 4.4 What the band does NOT establish
- **O2 (restated, ROADMAP Phase 6b SC5):** the FOC root is **not** established to be the
  minimiser. `Proposition15_level_reading_second_order_undetermined` (:823) exhibits the
  undetermination; `Proposition15_single_crossing_gives_minimum` (:890) is conditional on a
  single-crossing property **nothing proves**. **If this estimation calibrates toward a `τ` assumed
  to minimise exposure, that assumption is load-bearing and unproved.**
- **`H1` is undischarged on every branch.** `EST-03` tested `H2` only. `H1` (`∂L̄/∂π^φ`) scales and
  signs the loop gain through the residual's prefactor (`Proposition 12`). A fitted `Ḡ` does not
  discharge it.
- **`NEC-04` branch caveat**, if Stage 1 reported under `partially derivable`:
  `sign(residual) ⇏ sign(total)`, and the magnitude inherits it.
- **O8 is OPEN.** `λ_ARB` is monotone non-decreasing; **divergence is not established**, so the
  band's behaviour at large `λ` is an open question, not a settled stall.
```

**`## 5. Output contract`**

```
**(a, b, c, d):** <values with SEs>
**Covariance:** <pointer to §2.2>
**First-stage F:** <copied from STAGE1-RESULT.md §2.2 with its criterion; if the split was
infeasible, carry the DESCRIPTIVE label and the VOID threshold rule with it>
**Admissible band:** <the §4.3 intersection>
**On-chain form (STATED AS THEORY ONLY — no cost claim):** four stored parameters plus one sigmoid
evaluation, reusing the existing `AdaptiveFee` fixed-point sigmoid machinery. **No gas, storage or
cost claim is attached** — the EVM track is v2.
```

**Two-step review, THEN commit.** Run **Reality Checker** and **one named specialist, IN
PARALLEL**. The specialist is an econometrics/identification reviewer. Both must verify
**anti-fabrication**: **recompute** at least one element of §2.1 and one point of §3's `Ḡ(λ)` from
`control/data/stage2/fit.txt`, grep `gbar_stage2.py` for hardcoded constants, re-run the recorded
command, and confirm `gbar_stage1.py` is byte-unchanged. Both must also confirm no on-chain cost
claim was attached and that §3's O8 block does not assert divergence. Record with **counts and
dispositions**:

```
## Review
**Reviewer 1 (always):** Reality Checker — <date>. findings: <B> BLOCKER / <M> MAJOR / <m> MINOR.
  disposition: <resolved N, carried N — each carried item named>.
**Reviewer 2 (named specialist):** <name> — chosen because <reason>. <date>.
  findings: <B> BLOCKER / <M> MAJOR / <m> MINOR. disposition: <...>.
**Anti-fabrication check:** re-ran <command>; recomputed <parameter> = <value> and Ḡ(<λ>) =
<value> from control/data/stage2/fit.txt; both match.
```

Then commit scoped by path:

```
cd /home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller
git add control/spec/STAGE2-RESULT.md control/analysis/gbar_stage2.py control/data/stage2/
git commit -m "feat(06B): Stage 2 magnitude - Gbar as a logistic bump with admissible band

Closes EST-04, behind the EST-03 gate. nu = a + b*sigma_l(c(lambda-d)) fitted by
nonlinear IV/GMM on window B with a full 4x4 covariance; Gbar = b*c*sigma_l'
reported as a function vanishing on the saturation bands; admissible band
intersected with Theorem36_no_interior_root_off_the_band's responsive band. O2,
the undischarged H1 and the OPEN O8 asymptotics restated. Stage 1's script is
byte-unchanged. No on-chain cost claim attached.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>" -- control/spec/STAGE2-RESULT.md control/analysis/gbar_stage2.py control/data/stage2/
git show --name-only --format="" HEAD
```
  </action>
  <acceptance_criteria>
    - Guard: passes trivially if `STAGE2-RESULT.md` does not exist.
    - The file contains `### 4.1`, `### 4.2`, `### 4.3`, `### 4.4`, `## 5. Output contract`.
    - §4.1 states a numeric bound; §4.3 contains `4.3a`, `4.3b`, `4.3c`, the literal string `DIFFERENT VARIABLES`, and both variable names `ν` and `λ` in its intersection steps; the reported domain is an interval **in λ** with ≥ 2 numerals.
    - §4.2 contains a fenced block quoting `Theorem36_no_interior_root_off_the_band` and the citation `MevTaxProgram.lean:703`.
    - §4.4 contains `O2`, `Proposition15_single_crossing_gives_minimum`, `load-bearing and unproved`, `H1` with `undischarged`, and `O8 is OPEN`.
    - §5 contains `**(a, b, c, d):**`, `**First-stage F:**`, `**Admissible band:**`, `No gas, storage or cost claim is attached`.
    - No on-chain cost claim: `grep -icE '(gas cost|costs? [0-9]+ gas|storage slots? cost)'` returns 0.
    - `## Review` names `Reality Checker` and a second reviewer, with two `findings:` count lines, two `disposition:` lines, and an `**Anti-fabrication check:**` line naming a re-run command and **two** recomputed values.
    - `git show --name-only --format="" HEAD` lists only paths under `control/`, including `control/spec/STAGE2-RESULT.md` and `control/analysis/gbar_stage2.py`; `git status --porcelain control/aristotle/` is empty.
    - `control/analysis/gbar_stage1.py` is byte-identical to its committed form.
    - The **first-commit** `%ct` of `control/spec/STAGE2-RESULT.md` is `-ge` that of `control/spec/STAGE1-RESULT.md`.
    - **Scope sentinel:** the three `05-3.*.before` snapshots exist, are **newer than `.sentinel/.runstart`** (taken this run) and **not newer than the artifact** (taken before the edit), and each `diff -q` cleanly against the live value with `??` filtered on both sides — peer trees and the repo-root `.planning/` are **unchanged by this task**, which is not the same as clean.
  </acceptance_criteria>
  <verify>
    <automated>cd /home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller && F=control/spec/STAGE2-RESULT.md && if [ ! -f $F ]; then echo "PASS (NOT RUN)"; exit 0; fi && for s in '### 4.1' '### 4.2' '### 4.3' '4.3a' '4.3b' '4.3c' 'DIFFERENT VARIABLES' '### 4.4' '## 5. Output contract' 'MevTaxProgram.lean:703' 'Theorem36_no_interior_root_off_the_band' 'O2' 'Proposition15_single_crossing_gives_minimum' 'load-bearing and unproved' 'undischarged' 'O8 is OPEN' '**(a, b, c, d):**' '**First-stage F:**' '**Admissible band:**' 'No gas, storage or cost claim is attached' '## Review' 'Reality Checker' '**Anti-fabrication check:**'; do grep -qF "$s" $F || { echo "MISSING: $s"; exit 1; }; done && awk '/^### 4\.1/,/^### 4\.2/' $F | grep -qE '[0-9]' && python3 -c "
import re
t=open('$F').read()
sec=t.split('### 4.3')[1].split('### 4.4')[0]
body=re.sub(r'(?m)^[ \\t]*(?:#{1,6}[ \\t]*)?[-*]?[ \\t]*4\\.3[abc]?\\b[.:]?','',sec)
for lbl in ['4.3a','4.3b','4.3c']:
    assert lbl in sec, 'missing '+lbl
mlam=re.search(r'(?:in|IN) *.?λ.?[^\\n]*?\\[\\s*([-+0-9.eE]+)\\s*,\\s*([-+0-9.eE]+)\\s*\\]',body) or re.search(r'\\[\\s*([-+0-9.eE]+)\\s*,\\s*([-+0-9.eE]+)\\s*\\][^\\n]*λ',body)
assert mlam, 'no numeric lambda-interval [lo, hi] in the 4.3 body -- headings and bullet labels do not count'
lo,hi=float(mlam.group(1)),float(mlam.group(2))
assert lo<hi, 'lambda interval is not ordered: [%g, %g]'%(lo,hi)
nums=re.findall(r'[-+]?[0-9]*\\.?[0-9]+(?:[eE][-+]?[0-9]+)?',body)
assert len(nums)>=6, 'section 4.3 body carries only %d numbers; the pushforward, the intersection and the pullback each need endpoints'%len(nums)
assert 'ν' in body and 'λ' in body, 'the 4.3 body must name both variables'
print('4.3 pushforward arithmetic ok')
" && test $(grep -icE '(gas cost|costs? [0-9]+ gas|storage slots? cost)' $F) -eq 0 && test $(grep -cE '^ *findings: *[0-9]+ BLOCKER */ *[0-9]+ MAJOR */ *[0-9]+ MINOR' $F) -ge 2 && test $(grep -cE 'disposition:' $F) -ge 2 && git show --name-only --format="" HEAD | grep -qxF 'control/spec/STAGE2-RESULT.md' && git show --name-only --format="" HEAD | grep -qxF 'control/analysis/gbar_stage2.py' && test $(git show --name-only --format="" HEAD | grep -c .) -eq $(git show --name-only --format="" HEAD | grep -c '^control/') && test -z "$(git status --porcelain control/aristotle/ 2>/dev/null)" && diff <(git show HEAD:control/analysis/gbar_stage1.py) control/analysis/gbar_stage1.py && A=$(git log --reverse --format=%ct -- control/spec/STAGE2-RESULT.md | head -1) && B=$(git log --reverse --format=%ct -- control/spec/STAGE1-RESULT.md | head -1) && test "$A" -ge "$B" && SENT=control/.planning/phases/06B-research-venue-and-estimating-mev/.sentinel && test "$SENT/05-3.plank.before" -nt "$SENT/.runstart" && { test ! -e "${F:-/nonexistent}" || ! test "$SENT/05-3.plank.before" -nt "${F:-/nonexistent}"; } && diff -q "$SENT/05-3.plank.before" <(git -C ../plank status --porcelain | grep -v '^??') && diff -q "$SENT/05-3.lean4spec.before" <(git -C ../lean4-spec status --porcelain | grep -v '^??') && diff -q "$SENT/05-3.rootplanning.before" <(git status --porcelain .planning/) && echo PASS</automated>
  </verify>
  <done>The admissible band carries a numeric bound and is intersected with `Theorem36`'s band quoted verbatim from the Lean source; O2, the undischarged `H1`, the `NEC-04` residual caveat and the OPEN O8 asymptotics are attached to the reported number; no on-chain cost claim; the review recomputed two figures from raw artifacts and confirmed Stage 1's script is untouched.</done>
</task>

</tasks>

<verification>
1. The gate is real and four-valued: `STAGE2-RESULT.md` exists **iff** `STAGE1-RESULT.md` carries
   exactly one column-0 `VERDICT: GATE OPENS`. "Gate closed by verdict" and "Stage 1 never ran"
   are reported distinctly.
2. Stage 2 has its own script; `gbar_stage1.py` is proven byte-unchanged.
3. Every number is recomputable from a re-run command, a committed raw output, and a recomputed
   sha256; the review recomputes two of them independently.
4. O8 is stated as monotone non-decreasing with divergence **OPEN**; `mevMulti_nonneg` is cited
   with its file (`.../tax-result/.../MevOptimization.lean:250`) and no divergence claim appears.
5. `NEC-00` is cited as **PENDING** its formal carrier, never as established.
6. No on-chain cost claim; `control/aristotle/**` untouched; peer trees and repo-root `.planning/`
   unchanged by this plan.
</verification>

<success_criteria>
- `EST-04` closed, **or** explicitly NOT RUN with the state named (`GATE CLOSED BY VERDICT` or
  `STAGE 1 NEVER RAN`).
- Where it ran: `(a,b,c,d)` with a full covariance, `Ḡ` as a logistic bump vanishing on the
  saturation bands, and an admissible band intersected with `Theorem36`'s responsive band.
- O2, the undischarged `H1`, O8's open asymptotics, and any `NEC-04` residual caveat are attached
  to the reported number rather than footnoted.
</success_criteria>

<output>
After completion, create
`/home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller/control/.planning/phases/06B-research-venue-and-estimating-mev/06B-05-SUMMARY.md`.
If the gate was closed or Stage 1 never ran, the SUMMARY records `06B-05: NOT RUN — <state>` and
that nothing else was written.
</output>
