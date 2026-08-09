---
phase: 06B-research-venue-and-estimating-mev
plan: 06
type: execute
wave: 7
depends_on: ["06B-05"]
files_modified:
  - control/spec/GBAR-VERDICT.md
  - control/aristotle/tax-result/project_aristotle/RequestProject/MevTaxControl.lean
  - control/aristotle/tax2-result/project_aristotle/RequestProject/MevTaxProgram.lean
autonomous: false
requirements: [EST-05]

must_haves:
  truths:
    - "The output contract is delivered on WHICHEVER branch returned — including the branches where no estimation ran at all."
    - "Stage 1's verdict is recorded against `H2_dnu_dlamMEV_pos` in BOTH Lean bundles as `--` comments, with no declaration changed and no `sorry`/`axiom`/declaration count altered."
    - "Comment banners never land between a docstring and its declaration, nor inside a theorem signature — they go above the `/--` opener, or above the `theorem`/`def` keyword where there is none."
    - "A refutation propagates rather than being absorbed: `Theorem34_opposed_signs` and the corrected law's sign both flip, recorded where those declarations live."
    - "On a terminal branch the alternative-data proposal is written AFTER the verdict, names data without instructing action, and does not reopen the frozen instrument menu."
  artifacts:
    - path: "control/spec/GBAR-VERDICT.md"
      provides: "The phase's delivered result: the output contract, the verdict, the back-propagation record, and (on a terminal branch) the alternative-data proposal"
      min_lines: 90
      contains: "PHASE 6b DELIVERED RESULT:"
  key_links:
    - from: "control/spec/GBAR-VERDICT.md"
      to: "control/aristotle/tax-result/project_aristotle/RequestProject/MevTaxControl.lean"
      via: "the verdict recorded as a comment banner above H2_dnu_dlamMEV_pos's docstring"
      pattern: "H2_dnu_dlamMEV_pos"
    - from: "control/spec/GBAR-VERDICT.md"
      to: "control/aristotle/tax2-result/project_aristotle/RequestProject/MevTaxProgram.lean"
      via: "banner 2a above Theorem34_signs_from_H1_H2 (binds hH2); banner 2b above Theorem34_opposed_signs and Proposition16_corrected_law (bind neither)"
      pattern: "Theorem34_opposed_signs"
---

<objective>
Deliver the phase's result — whichever branch returned — and **back-propagate it into the Lean
corpus** against `H2_dnu_dlamMEV_pos` in both bundles.

Purpose: `EST-05`. `ROADMAP.md` Phase 6b SC5: the output contract is delivered **and
back-propagated**; a refutation flips `Theorem34_opposed_signs` and the corrected law's sign, and
"that consequence is propagated rather than absorbed". `06B-CONTEXT.md`: it back-propagates **per
`EST-05`, rather than waiting for Phase 7's gap register**.

**This plan runs on every branch**, including those where `06B-03`, `06B-04` and `06B-05` never
ran — an `EST-01: NOT CONSTRUCTIBLE` verdict or a `NONE — TERMINAL NON-IDENTIFICATION` pick still
has to be recorded against `H2` and delivered.

Output: `control/spec/GBAR-VERDICT.md`, plus comment-only edits to two Lean files.
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

**Path glossary.** `WT` = `/home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller`. `PLANK` =
`/home/jmsbpp/cfmms-playground/cfmm-wt/plank` (**READ-ONLY**). `LEAN` =
`/home/jmsbpp/cfmms-playground/cfmm-wt/lean4-spec` (**PEER-OWNED, READ-ONLY** — a **different
tree** from `control/aristotle/`, which is this project's own). `CONTROL_LEAN` =
`WT/control/aristotle/tax-result/project_aristotle/RequestProject/MevTaxControl.lean`.
`PROGRAM_LEAN` = `WT/control/aristotle/tax2-result/project_aristotle/RequestProject/MevTaxProgram.lean`.

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

**As the FIRST action of every task**, with `TAG` = `06-1`, `06-2`, `06-3`:

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
- Never write under `PLANK/`, `LEAN/`, or `WT/.planning/` (repo-root). The two Lean files edited
  here are under `control/aristotle/` — **this project's own tree**. Do not confuse them with the
  peer `lean4-spec` worktree.
- **COMMENT-ONLY edits to the Lean files.** No declaration, statement, proof body, import or `def`
  may change. Use `--` line comments **only** — never block comments, and never `/-- -/`
  docstrings, which attach to the following declaration and are **not inert**. Zero `sorry`, zero
  `axiom` introduced; `sorry`, `axiom` and declaration counts identical before and after.
- **Behavioral gains are never sent to the proving pipeline.** `H1` and `H2` stay typed
  hypotheses; data discharges or refutes them. This plan records a data verdict as a comment; it
  does not add, weaken or delete a Lean statement.
- `grep` dispatches to `ugrep`: literal patterns need `-F`. **Never write `grep -v '^\+\+\+'`** —
  under this grep that is not a valid BRE and matches everything, making a diff check vacuous.
  Write `grep -v '^+++'`. **Never use `grep <(...)` process substitution** — the shell `grep`
  function does not read the substituted FD; pipe instead.
- **Diff against `HEAD`, not the index.** Use `git diff HEAD -- "$C" "$P"`. A bare `git diff` goes
  vacuous the moment Task 3 stages the files.
- Every `<verify>` is one unbroken `&&` chain ending in `echo PASS`. Never `done;`.
- `gsd-tools commit --files` commits the entire staged index. Use `git commit -- <paths>`; assert
  paths with `git show --name-only --format="" HEAD`, **never `--stat`** — it elides long paths as
  `.../MevTaxControl.lean`.
- Nothing in this document may assert that the estimation is not load-bearing.
</context>

<inherited>
**Phases 1, 2, 3 and 6a are UNEXECUTED at plan time.** `GBAR-VERDICT.md` opens with an
`## Inherited, not assumed` section in which every item carries `PROVISIONAL — pending <req>` or
`SETTLED BY <artifact> §<n>`:

- **O4 — `σ` vs `σ²`.** `SETTLED BY POOL-ALGEBRA.md §3.1` for the estimating equation (where that
  branch ran); `PROVISIONAL — pending NOT-05` for notation outside it. `PRE-REGISTRATION.md`
  §7.1's void clause requires a **user HALT** and invoking it after `STAGE1-RESULT.md` exists is a
  recorded protocol violation.
- **The event-clock ruling** (Phase 2 `FRM-03`). `PROVISIONAL — pending FRM-03`; the exposure
  ruling is quoted from `PRE-REGISTRATION.md` §7 where it exists.
- **The hypothesis discipline** (Phase 3 `PRF-03`, `PRF-06`). `PROVISIONAL — pending PRF-06`.
  `PRF-06` will require `H2` and `∂L̄/∂π^φ` to appear as named typed hypotheses with estimand, sign
  convention and observation channel, naming `EST-03` as what discharges them. **This plan supplies
  the verdict that requirement points at, ahead of the protocol being written** — and says so
  rather than pretending the protocol existed.
- **`NEC-04`'s coupling verdict and recomposition rule** (Phase 6a). `PROVISIONAL — pending
  NEC-04`. Under `partially derivable`, `sign(residual) ⇏ sign(total)` and the Lean comment must
  say **residual**, not **total**. A later `fully derivable, negative` verdict refutes `H2`
  algebraically and **supersedes** this record rather than contradicting it.
- **`NEC-00`'s affine-in-`Ḡ` verdict** (Phase 6a). `PROVISIONAL — pending NEC-00` —
  refuted-as-a-free-option by two independent reviewers and by the orchestrator's own derivation,
  but not machine-checked; the Gates table lists it **NOT REACHED**.
- **O2** — the FOC root is not established to be the minimiser (`PROGRAM_LEAN:823`);
  `Proposition15_single_crossing_gives_minimum` (:890) rests on an unproved single-crossing
  property. `PROVISIONAL — pending O2`.
- **O8** — the carrier is `mevMulti_nonneg`
  (`control/aristotle/tax-result/project_aristotle/RequestProject/MevOptimization.lean:250`) and
  **its conclusion is `0 ≤ mevMulti …`, the TOTAL**. Per-summand nonnegativity is a
  **proof-internal step** (`Finset.sum_nonneg`), not what the declaration states. From it,
  **monotone NON-DECREASING** follows as a **derived reading with NO CARRIER** — no declaration
  states monotonicity. Divergence is a further claim again, needing **non-summable** summands,
  which nothing shows. Whether `λ_ARB` diverges — and hence whether `Ḡ → 0` and the loop stalls —
  is `PROVISIONAL — pending O8`.
- **O1** — `#print axioms` is unverified on both bundles, owed by Phase 3. `PROVISIONAL — pending
  PRF-08`. **No Lean build is claimed anywhere in this plan.**
- **The review register** (Phase 1 `HND-05`) does not exist; each artifact carries its own
  `## Review`.
</inherited>

<tasks>

<task type="auto">
  <name>Task 1: The delivered result — the output contract on whichever branch returned</name>
  <files>control/spec/GBAR-VERDICT.md</files>
  <read_first>
    - `/home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller/control/spec/NU-CONSTRUCTIBILITY.md` §3–§4 — the `EST-01` verdict and the `PHASE-6B-TERMINAL:` marker
    - `/home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller/control/spec/DISPERSION-WINDOW-A.md` §8 — the pick and its `PHASE-6B-TERMINAL:` marker (if that plan ran)
    - `/home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller/control/spec/STAGE1-RESULT.md` §4 — the single column-0 verdict line (if it exists)
    - `/home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller/control/spec/STAGE2-RESULT.md` §5 — the output contract's numbers (if it exists)
    - `/home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller/control/spec/ECONOMETRICS-DESIGN.md` §5 and `control/.planning/ROADMAP.md` Phase 6b SC5
  </read_first>
  <action>
**FIRST: scope sentinel `TAG=06-1`.**

Create `control/spec/GBAR-VERDICT.md`.

**Determine the branch by reading disk, first match wins. Quote the deciding line.**

1. `control/spec/NU-CONSTRUCTIBILITY.md` contains `EST-01 VERDICT: NOT CONSTRUCTIBLE`
   → branch **`EST-01 TERMINAL`**.
2. `control/spec/DISPERSION-WINDOW-A.md` §8 `**Picked venue:**` reads
   `NONE — TERMINAL NON-IDENTIFICATION` → branch **`VENUE TERMINAL`**.
3. `control/spec/STAGE1-RESULT.md` carries exactly one column-0 `VERDICT:` line → that verdict is
   the branch.
4. None of the above → branch **`STAGE 1 NEVER RAN`**, with the blocking reason named (a terminal
   marker, or `PRE-REGISTRATION.md` not `FROZEN`).

**Do not infer the branch from a file's existence or absence alone** — record which check fired.

Header:

```
# `Ḡ = ∂ν/∂λ_MEV` — PHASE 6b DELIVERED RESULT

**Requirement:** EST-05
**Delivered:** <YYYY-MM-DD>
**PHASE 6b DELIVERED RESULT:** <the branch token>
**Branch determined by:** check <N> — <the quoted deciding line>
**Pins:** `RESEARCH-REGISTER.md @ <sha>`, `POOL-ALGEBRA.md @ <sha>`,
`NU-CONSTRUCTIBILITY.md @ <sha>` <plus DISPERSION-WINDOW-A.md, PRE-REGISTRATION.md,
STAGE1-RESULT.md, STAGE2-RESULT.md — whichever exist, each with its FIRST-commit sha>

**None of the terminal outcomes terminates the project.** Phase 7 runs in every case and the
document reports whichever verdict returned. **The gate retained full force**; the softening
proposed on 2026-08-09 was withdrawn the same day and is not cited here.
```

Then `## Inherited, not assumed` — the nine items, each with `PROVISIONAL — pending` or
`SETTLED BY`.

**`## 1. The output contract`** — write **all five** fields. Where the branch means a field has no
value, write `NOT ESTIMATED — <branch>` rather than omitting it, so a reader sees the shape of what
was and was not delivered:

```
**(a, b, c, d):** <values with SEs> | NOT ESTIMATED — <branch>
**Covariance:** <pointer to STAGE2-RESULT.md §2.2> | NOT ESTIMATED — <branch>
**First-stage F:** <value, criterion named; carry any DESCRIPTIVE / VOID label with it> |
NOT COMPUTED — <branch>
**Admissible band (∩ `Theorem36`'s responsive band):** <interval> | NOT ESTABLISHED — <branch>
**What the controller can be built from:** <one paragraph, honest about the branch>
```

**`## 2. The consequence for `H2_dnu_dlamMEV_pos``** — exactly one heading:

```
### H2 DISCHARGED — <under which NEC-04 branch, with what caveat>
### H2 REFUTED — the sign is wrong
### H2 UNDISCHARGED — not identified; `H2` remains a typed hypothesis
```

**On `H2 REFUTED`, write the propagation out; do not absorb it:**

```
`Theorem34_opposed_signs` (`PROGRAM_LEAN:434`) and `Theorem34_signs_from_H1_H2` (:487) derive their
sign structure FROM `H1`/`H2` **by name**. With `H2` refuted, the opposed-signs reading and the
corrected law's sign **both flip**. `Proposition16_corrected_law` (:1054) is stated with a
**signed denominator** and remains true as a conditional identity; what changes is the SIGN of
`(∂φ/∂ν)(∂ν/∂τ_MEV)` and therefore the domain reading — `τ* < 1` always, `τ* > 0` iff the gate
dominates. **The absolute-value form `1 − (1−φ_X)/|·|` is conditional on the M21 signs and must
never be quoted as the theorem**; under a refuted `H2` it is not even the equivalent form.
**This consequence is propagated into the roadmap and the Phase 7 document, not absorbed here.**
```

**`## 3. What this verdict does NOT establish`**

- **`H1` (`∂L̄/∂π^φ`) is undischarged on every branch.** `EST-03` tested `H2` only. `H1` scales and
  signs the on-chain loop gain through the residual's prefactor (`Proposition 12`), which
  `NEC-07` records. A second estimation exercise, explicitly deferred.
- **O2 restated** (`ROADMAP.md` Phase 6b SC5): if the estimation calibrates toward a `τ` assumed to
  minimise exposure, **that assumption is load-bearing and unproved**.
- **O8 is OPEN, and the attribution matters.** `mevMulti_nonneg`
  (`control/aristotle/tax-result/project_aristotle/RequestProject/MevOptimization.lean:250`)
  concludes `0 ≤ mevMulti …` — **the TOTAL**. Per-summand nonnegativity is a **proof-internal
  step**; **monotone non-decreasing** is a derived reading with **NO CARRIER**. **Divergence is not
  established** — it would need non-summable summands — so `Ḡ → 0` and the loop stalling are open,
  not settled.
- **O1**: `#print axioms` is unverified on both bundles and **no Lean build is claimed here**.
- **O4 and the event clock** carry their markers from `## Inherited, not assumed`.
- **`NEC-04`** may still narrow or dissolve the estimand; a `fully derivable, negative` verdict
  would refute `H2` algebraically and **supersede** this record.

**`## 4. Routing`** — each item Phase 7's gap register must carry, by name: the branch verdict,
`O1`, `O2`, `O4`, `O8`, the event-clock question if OPEN, `H1` undischarged, and — on a terminal
branch — the non-identification verdict with severity and disposition.
  </action>
  <acceptance_criteria>
    - `control/spec/GBAR-VERDICT.md` ≥ 90 lines.
    - `**PHASE 6b DELIVERED RESULT:**` carries one of `GATE OPENS`, `WRONG SIGN — H2 REFUTED`, `NOT IDENTIFIED`, `EST-01 TERMINAL`, `VENUE TERMINAL`, `STAGE 1 NEVER RAN`.
    - `**Branch determined by:** check ` is present and quotes the deciding line.
    - **The branch token is RECOMPUTED from the three on-disk markers** — `NU-CONSTRUCTIBILITY.md`'s `EST-01 VERDICT:`, `DISPERSION-WINDOW-A.md`'s `**Picked venue:**`, and `STAGE1-RESULT.md`'s single column-0 `VERDICT:` line — and must equal the declared token. This token gates the refutation propagation, the SIGN CONSEQUENCE banners and whether §5 carries the anti-fishing guard, so it may not be self-declared.
    - `## Inherited, not assumed` contains `O1`, `O2`, `O4`, `O8`, `FRM-03`, `PRF-03`, `PRF-06`, `NEC-04`, `NEC-00`, and **every** inherited bullet carries `PROVISIONAL — pending` or `SETTLED BY`.
    - §1 contains all five contract labels — none omitted.
    - §2 contains exactly one heading matching `^### H2 (DISCHARGED|REFUTED|UNDISCHARGED)`.
    - If `H2 REFUTED`: the file contains `Theorem34_opposed_signs`, `Theorem34_signs_from_H1_H2`, `both flip`, `signed denominator`, `must never be quoted as the theorem`, `propagated into the roadmap`.
    - §3 contains `undischarged on every branch`, `Proposition 12`, `NEC-07`, `load-bearing and unproved`, `monotone non-decreasing`, `the TOTAL`, `proof-internal step`, `NO CARRIER`, `Divergence is not established`, `MevOptimization.lean:250`, and `no Lean build is claimed`.
    - §3 contains **no** claim of divergence: `grep -icF 'divergent accumulator'` returns 0.
    - §4 names `O1`, `O2`, `O4`, `O8`, `H1` and the branch verdict.
    - The file does not contain `no longer load-bearing`.
    - `git status --porcelain control/aristotle/` is still empty — Task 2 owns the Lean writes.
    - **Scope sentinel:** the three `06-1.*.before` snapshots exist, are **newer than `.sentinel/.runstart`** (taken this run) and **not newer than the artifact** (taken before the edit), and each `diff -q` cleanly against the live value with `??` filtered on both sides — peer trees and the repo-root `.planning/` are **unchanged by this task**, which is not the same as clean.
  </acceptance_criteria>
  <verify>
    <automated>cd /home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller && F=control/spec/GBAR-VERDICT.md && test -f $F && test $(wc -l < $F) -ge 90 && for s in '**PHASE 6b DELIVERED RESULT:**' '**Branch determined by:** check ' '## Inherited, not assumed' 'O1' 'O2' 'O4' 'O8' 'FRM-03' 'PRF-03' 'PRF-06' 'NEC-04' 'NEC-00' '**(a, b, c, d):**' '**Covariance:**' '**First-stage F:**' '**Admissible band' '**What the controller can be built from:**' 'undischarged on every branch' 'Proposition 12' 'NEC-07' 'load-bearing and unproved' 'monotone non-decreasing' 'the TOTAL' 'proof-internal step' 'NO CARRIER' 'Divergence is not established' 'MevOptimization.lean:250' 'no Lean build is claimed'; do grep -qF "$s" $F || { echo "MISSING: $s"; exit 1; }; done && grep -F '**PHASE 6b DELIVERED RESULT:**' $F | grep -qE 'GATE OPENS|WRONG SIGN|NOT IDENTIFIED|EST-01 TERMINAL|VENUE TERMINAL|STAGE 1 NEVER RAN' && python3 -c "
import re,os
decl=[l for l in open('$F').read().splitlines() if l.startswith('**PHASE 6b DELIVERED RESULT:**')][0]
def read(p):
    return open(p).read() if os.path.isfile(p) else ''
nu=read('control/spec/NU-CONSTRUCTIBILITY.md')
dw=read('control/spec/DISPERSION-WINDOW-A.md')
s1=read('control/spec/STAGE1-RESULT.md')
if 'EST-01 VERDICT: NOT CONSTRUCTIBLE' in nu:
    want='EST-01 TERMINAL'
elif re.search(r'^\\*\\*Picked venue:\\*\\*.*NONE — TERMINAL NON-IDENTIFICATION',dw,re.M):
    want='VENUE TERMINAL'
else:
    v=[l for l in s1.splitlines() if l.startswith('VERDICT:')]
    want=v[0][len('VERDICT: '):].strip() if len(v)==1 else 'STAGE 1 NEVER RAN'
got=decl.split(':**',1)[1].strip().strip('*').strip()
assert got==want, 'declared branch token %r != the token recomputed from the on-disk markers %r (substring matching would let a prose mention pass)'%(got,want)
print('branch token recomputed from disk: '+want)
" && test $(grep -cE '^### H2 (DISCHARGED|REFUTED|UNDISCHARGED)' $F) -eq 1 && test $(grep -icF 'divergent accumulator' $F) -eq 0 && ! grep -qF 'no longer load-bearing' $F && python3 -c "
t=open('$F').read()
sec=t.split('## Inherited, not assumed')[1].split('## 1.')[0]
b=[l for l in sec.splitlines() if l.lstrip().startswith('- **')]
assert b, 'no inherited bullets'
for l in b:
    assert ('PROVISIONAL — pending' in l) or ('SETTLED BY' in l), 'unmarked: '+l[:80]
print('markers ok')
" && { ! grep -qE '^### H2 REFUTED' $F || { for s in 'Theorem34_opposed_signs' 'Theorem34_signs_from_H1_H2' 'both flip' 'signed denominator' 'must never be quoted as the theorem' 'propagated into the roadmap'; do grep -qF "$s" $F || { echo "REFUTED BRANCH MISSING: $s"; exit 1; }; done; }; } && test -z "$(git status --porcelain control/aristotle/ 2>/dev/null)" && SENT=control/.planning/phases/06B-research-venue-and-estimating-mev/.sentinel && test "$SENT/06-1.plank.before" -nt "$SENT/.runstart" && { test ! -e "${F:-/nonexistent}" || ! test "$SENT/06-1.plank.before" -nt "${F:-/nonexistent}"; } && diff -q "$SENT/06-1.plank.before" <(git -C ../plank status --porcelain | grep -v '^??') && diff -q "$SENT/06-1.lean4spec.before" <(git -C ../lean4-spec status --porcelain | grep -v '^??') && diff -q "$SENT/06-1.rootplanning.before" <(git status --porcelain .planning/) && echo PASS</automated>
  </verify>
  <done>The branch was determined by reading disk and quoting the deciding line; the output contract has every field with `NOT ESTIMATED` where the branch precludes a value; `H2`'s consequence is stated once and, on a refutation, propagated rather than absorbed; O8 is stated as non-decreasing with divergence open, and no Lean build is claimed.</done>
</task>

<task type="auto">
  <name>Task 2: Back-propagate into both Lean bundles — comment-only, anchored where comments are inert</name>
  <files>control/aristotle/tax-result/project_aristotle/RequestProject/MevTaxControl.lean, control/aristotle/tax2-result/project_aristotle/RequestProject/MevTaxProgram.lean</files>
  <read_first>
    - `/home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller/control/spec/GBAR-VERDICT.md` §2 (the exact consequence being recorded)
    - `/home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller/control/aristotle/tax-result/project_aristotle/RequestProject/MevTaxControl.lean` — **`H2_dnu_dlamMEV_pos` is preceded by a `/-- **(H2) [M18].** ... -/` docstring**. Locate both the `def` and the `/--` that opens its docstring: `grep -n 'def H2_dnu_dlamMEV_pos'` then scan upward for the nearest `/--`.
    - `/home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller/control/aristotle/tax2-result/project_aristotle/RequestProject/MevTaxProgram.lean` — **the first `hH2` binder is INSIDE `Theorem34_signs_from_H1_H2`'s parameter list**; the `theorem` keyword opens the declaration and the binder is a continuation line. Locate the `theorem` keyword and the `/--` opening its docstring.
    - `/home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller/control/.planning/REQUIREMENTS.md` — `EST-05`'s back-propagation clause and `PRF-03`'s rule that behavioral gains are never sent to the proving pipeline
  </read_first>
  <action>
**FIRST: scope sentinel `TAG=06-2`.**

Record the baseline **before** editing and paste it into the SUMMARY:

```
cd /home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller
C=control/aristotle/tax-result/project_aristotle/RequestProject/MevTaxControl.lean
P=control/aristotle/tax2-result/project_aristotle/RequestProject/MevTaxProgram.lean
for f in $C $P; do echo "$f sorry=$(grep -cF 'sorry' $f) axiom=$(grep -c '^axiom ' $f) decls=$(grep -cE '^(theorem|lemma|def|noncomputable def|abbrev|instance) ' $f)"; done
```

**ANCHORING — this is where "comments are inert" is weakest, so it is specified exactly.**

- **Never insert between a `/--` docstring and the declaration it documents.** A docstring binds
  forward; splitting the pair changes what is documented and can change elaboration.
- **Never insert inside a declaration's signature** — not between the `theorem` keyword and its
  binders, not between binders, not before `:=`.
- **Insert above the `/--` that OPENS the preceding docstring block.** If a declaration has no
  docstring, insert immediately above its `theorem` / `def` keyword line.
- Use `--` line comments only. A `/--` banner would itself become a docstring.

Concretely: in `MevTaxControl.lean`, `H2_dnu_dlamMEV_pos` carries a `/-- **(H2) [M18].** … -/`
docstring; the banner goes **above that `/--` line**, not between it and the `def`. In
`MevTaxProgram.lean`, the `hH2` binder sits inside `Theorem34_signs_from_H1_H2`'s parameter list;
the banner goes **above the `/--` that opens that theorem's docstring**, or above the `theorem`
keyword if there is none — never at the binder line.

**Banner 1 — both files, above the anchor for the `H2` site:**

```
-- ═══ EST-05 BACK-PROPAGATION (Phase 6b, <YYYY-MM-DD>) ═══
-- H2_dnu_dlamMEV_pos is a TYPED HYPOTHESIS, never submitted to the proving pipeline
-- (PRF-03). Data discharges or refutes it. Phase 6b's EST-03 sign test returned:
--
--   VERDICT: <verbatim from STAGE1-RESULT.md section 4, or the terminal branch token
--             from GBAR-VERDICT.md's header>
--
-- Status of H2: DISCHARGED | REFUTED | UNDISCHARGED (not identified)
-- Reported under NEC-04 branch: <independent | partially derivable | NEC-04 UNKNOWN>
--   Under `partially derivable`, EST-03 tested a RESIDUAL and sign(residual) does not
--   imply sign(total): this record is about the residual, not the total.
-- Evidence: control/spec/GBAR-VERDICT.md @ <sha>, control/spec/STAGE1-RESULT.md @ <sha>,
--           frozen at control/spec/PRE-REGISTRATION.md @ <FREEZE SHA>
-- Caveats inherited and NOT resolved: O4 (sigma vs sigma^2 units outside the estimating
--   equation), the Phase 2 event-clock ruling, O2 (the FOC root is not established to be
--   the minimiser), O8 (lambda_ARB is monotone non-decreasing; divergence is NOT
--   established), O1 (#print axioms unverified; no build is claimed here).
-- H1_dLbar_dpiPhi_pos is UNDISCHARGED on every branch: EST-03 tested H2 only.
-- ═══════════════════════════════════════════════════════
```

**Banner 2 — `MevTaxProgram.lean` ONLY, and only if the verdict is `WRONG SIGN — H2 REFUTED`.**

**Read the binders before writing anything.** `Theorem34_opposed_signs` (:434) takes
`(hdphi : 0 < dphidnu) (hdnu : dnudtau < 0)` — **there is no `hH1` and no `hH2` in its
signature**. Only `Theorem34_signs_from_H1_H2` (:487) binds `hH2` (:489). Confirm on disk before
writing:

```
sed -n '/^theorem Theorem34_opposed_signs/,/:= by/p' "$P" | grep -n 'hH1\|hH2\|hdnu'
```

Therefore **two different banners**, because the two declarations stand in different relations to
`H2`, and collapsing them is the `arb_add_fee_eq_lvr` failure class this project already ruled
against — presenting a weaker relation as a stronger one.

**Banner 2a — above the anchor for `Theorem34_signs_from_H1_H2` ONLY** (the declaration that
really does derive its sign structure from `H1`/`H2` by name):

```
-- ═══ EST-05 SIGN CONSEQUENCE (Phase 6b, <YYYY-MM-DD>) ═══
-- H2 is REFUTED by data (EST-03). This declaration binds hH2 in its signature and derives
-- its sign structure FROM H1/H2 by name, so its conclusion is no longer available in the
-- estimated regime: the hypothesis it is conditional on is now known to be false there.
-- The declaration itself is UNCHANGED and remains true as stated -- it is an implication,
-- and refuting its antecedent does not falsify it. Nothing here weakens, deletes or
-- re-states the theorem.
-- Propagated to: control/spec/GBAR-VERDICT.md section 2, the roadmap, and the Phase 7
--   gap register. NOT absorbed here.
-- ═══════════════════════════════════════════════════════
```

**Banner 2b — above the anchors for `Theorem34_opposed_signs` and `Proposition16_corrected_law`**
(the declarations that do NOT bind `H2`):

```
-- ═══ EST-05 SIGN CONSEQUENCE (Phase 6b, <YYYY-MM-DD>) ═══
-- H2 is REFUTED by data (EST-03). This declaration does NOT bind hH1 or hH2: its sign
-- hypotheses are hdphi : 0 < dphidnu and hdnu : dnudtau < 0, taken as free hypotheses.
-- H2 entered only as the MOTIVATION for hdnu, via
-- MevTaxControl.Theorem32_hazard_strictAntiOn_tau (see this declaration's own docstring).
-- CONSEQUENCE, stated at its true strength: refuting H2 does NOT make this theorem "flip".
-- It removes the justification for hdnu, so the theorem becomes INAPPLICABLE in the
-- estimated regime -- its hypothesis is no longer established. That is a weaker and
-- different consequence than a sign reversal, and it is the correct one.
-- The declaration is UNCHANGED and remains true as stated.
-- The corrected law is quoted with a SIGNED DENOMINATOR. The absolute-value form
--   tau* = 1 - (1-phi_X)/|(dphi/dnu)(dnu/dtau)|
-- is conditional on the M21 signs and must never be quoted as the theorem.
-- Propagated to: control/spec/GBAR-VERDICT.md section 2, the roadmap, and the Phase 7
--   gap register. NOT absorbed here.
-- ═══════════════════════════════════════════════════════
```

**Then verify the diff is comment-only, against `HEAD`:**

```
git diff HEAD -- "$C" "$P" | grep -E '^\+' | grep -v '^+++' | grep -vcE '^\+ *(--|$)'
```

must print `0`. Note `grep -v '^+++'` — **no backslashes**; the escaped form is not a valid BRE
under this repo's grep and makes the check vacuous. Also:

```
git diff HEAD -- "$C" "$P" | grep -cE '^-[^-]'      # must be 0 — nothing deleted
git diff HEAD -- "$C" | grep -F 'def H2_dnu_dlamMEV_pos'   # must print nothing
```

Re-run the baseline command and confirm `sorry`, `axiom` and declaration counts are **identical**.

**Do not attempt a Lean build.** `#print axioms` is open item **O1**, owed by Phase 3. Comment-only
edits cannot change elaboration, and claiming a successful build would assert what O1 says is
unverified.
  </action>
  <acceptance_criteria>
    - Both Lean files contain `EST-05 BACK-PROPAGATION (Phase 6b`.
    - **Anchoring, checked positionally over the WHOLE gap:** in `MevTaxControl.lean` the banner's last line precedes the nearest `/--` above `def H2_dnu_dlamMEV_pos`, and **no `--` comment line whatsoever falls between that `/--` and the `def`** — the check inspects every line in the gap, not just the banner header.
    - **The declaration scan covers `theorem|lemma|def|noncomputable def|abbrev|instance`,** not `theorem` alone: `MevTaxProgram.lean` has 18 column-0 `lemma`s, and a `theorem`-only scan would let a banner sit inside a lemma signature directly above the `hH2` binder. The check asserts it found ≥ 50 declarations before trusting its own result. In `MevTaxProgram.lean` no banner line falls between a `theorem` keyword and its `:=`, and none falls on or after the `hH2` binder line within `Theorem34_signs_from_H1_H2`.
    - Both banners contain `Status of H2:` with one of `DISCHARGED`/`REFUTED`/`UNDISCHARGED`, a `Reported under NEC-04 branch:` line, `H1_dLbar_dpiPhi_pos is UNDISCHARGED on every branch`, and pins for `GBAR-VERDICT.md @` and `PRE-REGISTRATION.md @`.
    - `git diff HEAD -- <both> | grep -E '^\+' | grep -v '^+++' | grep -vcE '^\+ *(--|$)'` returns `0`.
    - `git diff HEAD -- <both> | grep -cE '^-[^-]'` returns `0`.
    - `git diff HEAD -- MevTaxControl.lean | grep -F 'def H2_dnu_dlamMEV_pos'` returns nothing.
    - `sorry` count, **`axiom` count** and declaration count on each file equal the `git show HEAD:` values.
    - Neither file gained a `/--` docstring: `git diff HEAD -- <both> | grep -cE '^\+ *\/--'` returns `0`.
    - If the verdict is `WRONG SIGN — H2 REFUTED`, `MevTaxProgram.lean` contains `EST-05 SIGN CONSEQUENCE` ≥ 3 times (one 2a, two 2b) and contains `INAPPLICABLE in the` — the true consequence for the declarations that do not bind `H2`.
    - **The overclaim is barred, not merely unrequired:** the file must NOT contain `BOTH FLIP`, and no banner line within 40 lines above `theorem Theorem34_opposed_signs` may contain `derives its sign structure FROM H1/H2` — that phrase belongs only above `Theorem34_signs_from_H1_H2`, whose signature actually binds `hH2`.
    - `git -C ../lean4-spec status --porcelain` is unchanged from the sentinel — the peer Lean tree was not touched.
    - **Scope sentinel:** the three `06-2.*.before` snapshots exist, are **newer than `.sentinel/.runstart`** (taken this run) and **not newer than the artifact** (taken before the edit), and each `diff -q` cleanly against the live value with `??` filtered on both sides — peer trees and the repo-root `.planning/` are **unchanged by this task**, which is not the same as clean.
  </acceptance_criteria>
  <verify>
    <automated>cd /home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller && C=control/aristotle/tax-result/project_aristotle/RequestProject/MevTaxControl.lean && P=control/aristotle/tax2-result/project_aristotle/RequestProject/MevTaxProgram.lean && for f in $C $P; do for s in 'EST-05 BACK-PROPAGATION (Phase 6b' 'Status of H2:' 'Reported under NEC-04 branch:' 'H1_dLbar_dpiPhi_pos is UNDISCHARGED on every branch'; do grep -qF "$s" $f || { echo "MISSING in $f: $s"; exit 1; }; done && grep -qE 'GBAR-VERDICT\.md @ [0-9a-f]{7,}' $f && grep -qE 'PRE-REGISTRATION\.md @ [0-9a-f]{7,}' $f && grep -F 'Status of H2:' $f | grep -qE 'DISCHARGED|REFUTED|UNDISCHARGED'; done && test $(git diff HEAD -- "$C" "$P" | grep -E '^\+' | grep -v '^+++' | grep -vcE '^\+ *(--|$)') -eq 0 && test $(git diff HEAD -- "$C" "$P" | grep -cE '^-[^-]') -eq 0 && test $(git diff HEAD -- "$C" "$P" | grep -cE '^\+ *\/--') -eq 0 && test -z "$(git diff HEAD -- "$C" | grep -F 'def H2_dnu_dlamMEV_pos')" && for f in $C $P; do test $(grep -cF 'sorry' $f) -eq $(git show HEAD:$f | grep -cF 'sorry') && test $(grep -c '^axiom ' $f) -eq $(git show HEAD:$f | grep -c '^axiom ') && test $(grep -cE '^(theorem|lemma|def|noncomputable def|abbrev|instance) ' $f) -eq $(git show HEAD:$f | grep -cE '^(theorem|lemma|def|noncomputable def|abbrev|instance) ') || { echo "COUNT DRIFT in $f"; exit 1; }; done && python3 -c "
import re,sys
C='$C'; P='$P'
DECL=re.compile(r'^(theorem|lemma|def|noncomputable def|abbrev|instance) ')
c=open(C).read().splitlines()
di=[i for i,l in enumerate(c) if l.startswith('def H2_dnu_dlamMEV_pos')][0]
doc=max(i for i,l in enumerate(c[:di]) if l.strip().startswith('/--'))
banner=[i for i,l in enumerate(c) if 'EST-05 BACK-PROPAGATION' in l]
assert banner, 'no banner in MevTaxControl'
b=[i for i in banner if i<di]
assert b, 'banner not above the def'
assert max(b)<doc, 'banner sits BETWEEN the docstring opener (line %d) and the def (line %d)'%(doc+1,di+1)
gap=[l for l in c[doc:di] if l.strip().startswith('--') and not l.strip().startswith('/--')]
assert not gap, 'a -- comment line sits between the docstring and its declaration: %r'%gap[0]
p=open(P).read().splitlines()
decls=[i for i,l in enumerate(p) if DECL.match(l)]
assert len(decls)>=50, 'declaration scan found only %d column-0 declarations; the keyword set is too narrow'%len(decls)
hh=[i for i,l in enumerate(p) if 'hH2' in l and 'MevTaxControl.H2_dnu_dlamMEV_pos' in l]
for i,l in enumerate(p):
    if l.strip().startswith('-- ═══ EST-05'):
        prev=[d for d in decls if d<i]
        if prev:
            d=prev[-1]
            closed=[j for j in range(d,i) if ':=' in p[j]]
            assert closed, 'banner at line %d is INSIDE the signature of the declaration opened at line %d (%s)'%(i+1,d+1,p[d][:60])
        assert i not in hh, 'banner lands on the hH2 binder line %d'%(i+1)
print('anchors ok')
" && { ! grep -qF 'WRONG SIGN — H2 REFUTED' control/spec/GBAR-VERDICT.md || { test $(grep -cF 'EST-05 SIGN CONSEQUENCE' $P) -ge 3 && grep -qF 'INAPPLICABLE in the' $P && grep -qF 'SIGN-FREE' $P && ! grep -qF 'BOTH FLIP' $P && python3 -c "
import sys
p=open('$P').read().splitlines()
def above(name,n=40):
    i=[k for k,l in enumerate(p) if l.startswith(name)]
    assert i, name+' not found'
    return p[max(0,i[0]-n):i[0]]
w=above('theorem Theorem34_opposed_signs')
bad=[l for l in w if 'derives its sign structure FROM H1/H2' in l]
assert not bad, 'H1/H2-derivation claim placed above Theorem34_opposed_signs, which binds neither: '+bad[0]
assert any('INAPPLICABLE in the' in l for l in w), 'banner 2b (INAPPLICABLE) missing above Theorem34_opposed_signs'
v=above('theorem Proposition16_corrected_law')
assert not any('INAPPLICABLE in the' in l for l in v), 'banner 2b reused above Proposition16_corrected_law: its FIRST conjunct is sign-free, so blanket inapplicability is false there'
assert not any('derives its sign structure FROM H1/H2' in l for l in v), 'H1/H2 claim placed above Proposition16_corrected_law, whose docstring never cites H2'
assert any('SCOPE OF THE CONSEQUENCE' in l for l in v), 'banner 2c missing above Proposition16_corrected_law'
assert any('SIGN-FREE' in l for l in v), 'banner 2c does not record that the first conjunct is sign-free'
print('attribution ok: 2b on Theorem34_opposed_signs, 2c on Proposition16_corrected_law')
"; }; } && SENT=control/.planning/phases/06B-research-venue-and-estimating-mev/.sentinel && test "$SENT/06-2.plank.before" -nt "$SENT/.runstart" && { test ! -e "$C" || ! test "$SENT/06-2.plank.before" -nt "$C"; } && diff -q "$SENT/06-2.plank.before" <(git -C ../plank status --porcelain | grep -v '^??') && diff -q "$SENT/06-2.lean4spec.before" <(git -C ../lean4-spec status --porcelain | grep -v '^??') && diff -q "$SENT/06-2.rootplanning.before" <(git status --porcelain .planning/) && echo PASS</automated>
  </verify>
  <done>The verdict is recorded against `H2_dnu_dlamMEV_pos` in both bundles as `--` banners anchored above the docstring opener and above the `theorem` keyword — never between a docstring and its declaration and never inside a signature; the diff against `HEAD` is provably comment-only with a working `^+++` filter; `sorry`, `axiom` and declaration counts are unchanged; no docstring was introduced and no Lean build was claimed.</done>
</task>

<task type="checkpoint:decision" gate="blocking">
  <name>Task 3: On a terminal branch, the guarded alternative-data proposal — then review and commit</name>
  <files>control/spec/GBAR-VERDICT.md</files>
  <read_first>
    - `/home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller/control/spec/GBAR-VERDICT.md` §1–§4 — the verdict must already be recorded before anything below is written
    - `/home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller/control/.planning/phases/06B-research-venue-and-estimating-mev/06B-CONTEXT.md` — "Estimation scope and freeze": the proposal is a user decision made **with the risk stated**, and the guard is **binding**
    - `~/.claude/skills/anti-fishing-replication/SKILL.md` — invoked at this boundary by name
    - `/home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller/control/spec/RESEARCH-REGISTER.md` §5.1 — the closed instrument menu the proposal may not reopen
  </read_first>
  <decision>
**(a) Whether the delivered result and the Lean back-propagation are accepted** as the phase's
output. The user sees the verdict, the contract, and the two comment diffs.

**(b) On a terminal branch only (`NOT IDENTIFIED`, `VENUE TERMINAL`, `EST-01 TERMINAL`, or
`STAGE 1 NEVER RAN`) — whether the named alternative-data proposal is written**, and its scope. It
was a user decision made **with the risk stated**: a proposal can read as a re-specification
invitation.
  </decision>
  <context>
`06B-CONTEXT.md`, verbatim: "**Terminal 'not identified' ships a verdict document AND a named
alternative-data proposal.** User decision, made with the risk stated… **Guard, binding:** the
proposal names what data *could* identify `Ḡ` and does **not** act on it, does **not** re-open the
frozen instrument menu, and is written only **after** the verdict is recorded — never as an
alternative to recording it. `anti-fishing-replication` is invoked at that boundary."

The `υ` precedent is the template: that exercise terminated in "this market cannot identify `υ`"
and was correctly never reopened. A proposal is not a reopening; acting on one would be.
  </context>
  <options>
    <option id="accept-and-propose">
      <name>Accept the result and write the guarded alternative-data proposal</name>
      <pros>The phase ships a verdict plus a concrete statement of what data would identify `Ḡ`, which Phase 7's hand-off can route.</pros>
      <cons>A proposal read as an invitation is exactly the failure mode; the guard must hold in the writing, not only in the header.</cons>
    </option>
    <option id="accept-no-proposal">
      <name>Accept the result and write no proposal</name>
      <pros>Zero re-specification surface; the `υ` precedent at its strictest.</pros>
      <cons>Departs from the recorded user decision, so the change of decision must itself be recorded.</cons>
    </option>
    <option id="not-terminal">
      <name>The branch is `GATE OPENS` — no proposal is owed</name>
      <pros>Nothing to guard; the phase ships the estimate.</pros>
      <cons>None.</cons>
    </option>
  </options>
  <action>
**FIRST: scope sentinel `TAG=06-3`.**

Present: the `**PHASE 6b DELIVERED RESULT:**` line, §1's contract, §2's `H2` consequence, and
`git diff HEAD --stat` on the two Lean files **for counts only**, with the comment-only property
demonstrated by the pipeline from Task 2 returning `0`. Use `git show --name-only` for any path
listing — `--stat` elides long paths.

**Only on a terminal branch, and only after §2 already records the verdict**, append:

```
## 5. Alternative-data proposal (terminal branches only)

**Written after the verdict was recorded.** Verdict recorded in §2 at <time>; this section written
at <later time>. It is **not** an alternative to recording the verdict.

**GUARD (binding):**
- This section **names what data could identify `Ḡ`**. It **does not act on it.**
- It **does not reopen** the frozen instrument menu at `RESEARCH-REGISTER.md` §5.1.
- It **does not propose a re-specification** of the frozen Stage 1 specification. Stage 1 is
  closed.
- `anti-fishing-replication` governs this boundary: `NO POST-LOCK CHANGE WITHOUT A HALT, A
  DISPOSITION MEMO, AND A USER-ENUMERATED PIVOT`. **The user enumerates any pivot; the analyst
  never does.**

**What data could identify `Ḡ`:**
| Data | What it would supply | Why it is not available now | Who would own acquiring it |

**Explicitly NOT proposed:** <name what a reader might mistake this for — a new instrument, a
re-run on window A, a different venue under the same frozen spec — and say each is excluded>
```

**Every sentence in §5 is descriptive.** No line may begin with an imperative
(`run`, `re-run`, `estimate`, `fit`, `query`, `collect`, `acquire`) — the criteria grep for that,
because a proposal that reads as an instruction is the failure mode the guard exists to prevent.

**On a `GATE OPENS` branch, §5 is the single line** `NOT APPLICABLE — the gate opened; no
alternative-data proposal is owed.`

Then `## 6. Ratification`:

```
**Put to the user:** <YYYY-MM-DD>
**RULING:** <the user's words, quoted, not paraphrased>
**Proposal written:** YES
**Status:** PHASE 6b DELIVERED
```

`**Proposal written:**` carries `YES` or `NO — <the user's reason>`; `**Status:**` carries exactly
`PHASE 6b DELIVERED`. No angle brackets, no ` | ` alternation on either line.

**Two-step review, THEN commit.** Run **Reality Checker** and **one named specialist, IN
PARALLEL** over `GBAR-VERDICT.md` **and both Lean diffs**. The specialist is a formal-methods /
Lean reviewer for the diffs; where the branch delivered numbers, dispatch the econometrics
reviewer as well and record all three. Reviewers must verify: (i) the Lean diffs are comment-only
and change no declaration, **re-running the `^+++` pipeline themselves**; (ii) `sorry`, `axiom` and
declaration counts are unchanged; (iii) banners are anchored above docstring openers and outside
signatures; (iv) §5's guard holds **in the writing** — no sentence could be executed as an
instruction; (v) the file asserts nothing about the estimation not being load-bearing. Record with
**counts and dispositions**:

```
## Review
**Reviewer 1 (always):** Reality Checker — <date>. findings: <B> BLOCKER / <M> MAJOR / <m> MINOR.
  disposition: <resolved N, carried N — each carried item named>.
**Reviewer 2 (named specialist):** <name> — chosen because <reason>. <date>.
  findings: <B> BLOCKER / <M> MAJOR / <m> MINOR. disposition: <...>.
**Comment-only re-verified independently:** <the pipeline run> → 0.
```

Then commit scoped by path:

```
cd /home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller
git add control/spec/GBAR-VERDICT.md \
  control/aristotle/tax-result/project_aristotle/RequestProject/MevTaxControl.lean \
  control/aristotle/tax2-result/project_aristotle/RequestProject/MevTaxProgram.lean
git commit -m "feat(06B): Gbar verdict delivered and back-propagated into both Lean bundles

Closes EST-05. The output contract is delivered on whichever branch returned;
Stage 1's verdict is recorded against H2_dnu_dlamMEV_pos in MevTaxControl.lean and
MevTaxProgram.lean as comment-only annotations anchored above docstring openers -
no declaration, proof, import or statement changed, sorry/axiom/declaration counts
identical. A refutation propagates the sign consequence at Theorem34_opposed_signs
and Proposition16_corrected_law rather than absorbing it. O1, O2, O4, O8, the event
clock and the undischarged H1 are routed to the Phase 7 gap register.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>" -- control/spec/GBAR-VERDICT.md \
  control/aristotle/tax-result/project_aristotle/RequestProject/MevTaxControl.lean \
  control/aristotle/tax2-result/project_aristotle/RequestProject/MevTaxProgram.lean
git show --name-only --format="" HEAD
```

`git show --name-only` must list exactly three paths, all under `control/`.
  </action>
  <acceptance_criteria>
    - `GBAR-VERDICT.md` contains `## 5.` and `## 6. Ratification` with `**Put to the user:**`, `**RULING:**`, `**Proposal written:**`, and `**Status:** PHASE 6b DELIVERED`.
    - Neither the `**Proposal written:**` nor the `**Status:**` line contains `<`, `>` or ` | `.
    - On a terminal branch, §5 contains `**GUARD (binding):**`, `does not reopen`, `RESEARCH-REGISTER.md` §5.1, `anti-fishing-replication`, `The user enumerates any pivot; the analyst never does.`, a `What data could identify` table with ≥ 1 data row, and `**Explicitly NOT proposed:**`.
    - On `GATE OPENS`, §5 is the single line `NOT APPLICABLE — the gate opened; no alternative-data proposal is owed.`
    - **No imperative in §5:** no line inside §5 matches `^(- )?(run|re-?run|estimate|fit|query|collect|acquire) ` (case-insensitive).
    - `## Review` names `Reality Checker` and a second reviewer, with ≥ 2 `findings:` count lines, ≥ 2 `disposition:` lines, and a `**Comment-only re-verified independently:**` line.
    - `git show --name-only --format="" HEAD` lists exactly three paths, all beginning `control/`.
    - The comment-only pipeline still returns `0` against the commit, and `sorry`/`axiom`/declaration counts match `HEAD~1`.
    - The **first-commit** `%ct` of `control/spec/GBAR-VERDICT.md` is `-ge` that of `control/spec/RESEARCH-REGISTER.md`.
    - **Scope sentinel:** the three `06-3.*.before` snapshots exist, are **newer than `.sentinel/.runstart`** (taken this run) and **not newer than the artifact** (taken before the edit), and each `diff -q` cleanly against the live value with `??` filtered on both sides — peer trees and the repo-root `.planning/` are **unchanged by this task**, which is not the same as clean.
  </acceptance_criteria>
  <resume-signal>Reply `accept` (and, on a terminal branch, `proposal: yes` or `proposal: no — <reason>`). Do not ask for a menu of next estimations; the analyst is barred from proposing one.</resume-signal>
  <verify>
    <automated>cd /home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller && F=control/spec/GBAR-VERDICT.md && C=control/aristotle/tax-result/project_aristotle/RequestProject/MevTaxControl.lean && P=control/aristotle/tax2-result/project_aristotle/RequestProject/MevTaxProgram.lean && for s in '## 5.' '## 6. Ratification' '**Put to the user:**' '**RULING:**' '**Proposal written:**' '**Status:** PHASE 6b DELIVERED' '## Review' 'Reality Checker' '**Comment-only re-verified independently:**'; do grep -qF "$s" $F || { echo "MISSING: $s"; exit 1; }; done && test $(grep -E '^\*\*(Proposal written|Status):\*\*' $F | grep -cE '<|>|\| ') -eq 0 && if grep -F '**PHASE 6b DELIVERED RESULT:**' $F | grep -qF 'GATE OPENS'; then grep -qF 'NOT APPLICABLE — the gate opened; no alternative-data proposal is owed.' $F || { echo "GATE-OPEN SECTION 5 WRONG"; exit 1; }; else for s in '**GUARD (binding):**' 'does not reopen' 'anti-fishing-replication' 'The user enumerates any pivot; the analyst never does.' '**Explicitly NOT proposed:**'; do grep -qF "$s" $F || { echo "GUARD MISSING: $s"; exit 1; }; done; fi && test $(awk '/^## 5\./,/^## 6\./' $F | grep -icE '^(- )?(run|re-?run|estimate|fit|query|collect|acquire) ') -eq 0 && test $(grep -cE '^ *findings: *[0-9]+ BLOCKER */ *[0-9]+ MAJOR */ *[0-9]+ MINOR' $F) -ge 2 && test $(grep -cE 'disposition:' $F) -ge 2 && test $(git show --name-only --format="" HEAD | grep -c .) -eq 3 && test $(git show --name-only --format="" HEAD | grep -vc '^control/') -eq 0 && test $(git diff HEAD~1 HEAD -- "$C" "$P" | grep -E '^\+' | grep -v '^+++' | grep -vcE '^\+ *(--|$)') -eq 0 && test $(git diff HEAD~1 HEAD -- "$C" "$P" | grep -cE '^-[^-]') -eq 0 && for f in $C $P; do test $(grep -cF 'sorry' $f) -eq $(git show HEAD~1:$f | grep -cF 'sorry') && test $(grep -c '^axiom ' $f) -eq $(git show HEAD~1:$f | grep -c '^axiom ') && test $(grep -cE '^(theorem|lemma|def|noncomputable def|abbrev|instance) ' $f) -eq $(git show HEAD~1:$f | grep -cE '^(theorem|lemma|def|noncomputable def|abbrev|instance) ') || { echo "COUNT DRIFT in $f"; exit 1; }; done && A=$(git log --reverse --format=%ct -- control/spec/GBAR-VERDICT.md | head -1) && B=$(git log --reverse --format=%ct -- control/spec/RESEARCH-REGISTER.md | head -1) && test "$A" -ge "$B" && SENT=control/.planning/phases/06B-research-venue-and-estimating-mev/.sentinel && test "$SENT/06-3.plank.before" -nt "$SENT/.runstart" && { test ! -e "${F:-/nonexistent}" || ! test "$SENT/06-3.plank.before" -nt "${F:-/nonexistent}"; } && diff -q "$SENT/06-3.plank.before" <(git -C ../plank status --porcelain | grep -v '^??') && diff -q "$SENT/06-3.lean4spec.before" <(git -C ../lean4-spec status --porcelain | grep -v '^??') && diff -q "$SENT/06-3.rootplanning.before" <(git status --porcelain .planning/) && echo PASS</automated>
  </verify>
  <done>The delivered result and the two comment-only Lean diffs were accepted by the user in their own words; on a terminal branch the alternative-data proposal exists with a guard that holds in the writing — descriptive throughout, no imperative lines, and no reopening of the closed menu; the three artifacts are committed in one scoped commit whose diff is provably comment-only against the previous commit; both peer trees are untouched.</done>
</task>

</tasks>

<verification>
1. The branch is read off disk with the deciding line quoted, and `STAGE 1 NEVER RAN` is a
   distinct branch from a verdict-closed gate.
2. The output contract has all five fields, `NOT ESTIMATED` where the branch precludes a value.
3. The Lean diffs are comment-only **against `HEAD`** with a working `^+++` filter, zero
   deletions, no new docstrings, and `sorry`/`axiom`/declaration counts equal to `git show HEAD:`.
4. Banners are anchored above docstring openers and outside signatures — verified positionally,
   not by string presence.
5. On refutation the sign consequence is recorded at `Theorem34_opposed_signs` and
   `Proposition16_corrected_law` and routed onward — propagated, not absorbed.
6. §5 names data without instructing action and does not reopen `RESEARCH-REGISTER.md` §5.1.
7. Peer trees and repo-root `.planning/` **unchanged by this plan**; no Lean build claimed (O1
   stands).
</verification>

<success_criteria>
- `EST-05` closed: the output contract delivered, the verdict recorded against
  `H2_dnu_dlamMEV_pos` in both bundles, and the sign consequence propagated where it applies.
- The phase ships a delivered result on **every** branch, including those where no estimation ran.
- O1, O2, O4, O8, the event-clock question and the undischarged `H1` are routed to Phase 7's gap
  register by name.
</success_criteria>

<output>
After completion, create
`/home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller/control/.planning/phases/06B-research-venue-and-estimating-mev/06B-06-SUMMARY.md`,
recording the delivered result verbatim, the pre-edit and post-edit `sorry` / `axiom` /
declaration counts for both Lean files, the banner anchor line numbers, and the commit sha.
</output>
