---
phase: 06B-research-venue-and-estimating-mev
plan: 03
type: execute
wave: 4
depends_on: ["06B-02"]
files_modified:
  - control/spec/PRE-REGISTRATION.md
  - control/spec/RESEARCH-REGISTER.md
autonomous: false
requirements: [EST-06, EST-07, EST-08, EST-09]

must_haves:
  truths:
    - "This plan does not run on a terminal branch — it reads the marker off disk and exits 0 reporting NOT RUN, so the phase still reaches 06B-06."
    - "The freeze is blocked unless `POOL-ALGEBRA.md` §3.1 returned `DIMENSIONAL CHECK: PASS` — O4 changes the regressor, so a FAIL cannot be carried as a provisional convention."
    - "The venue-independent thresholds are COPIED byte-equal from `POOL-ALGEBRA.md` §5, which fixed them before any dispersion existed; only venue-specific items are newly frozen here."
    - "The bad-control hazard is resolved in writing before the specification is written."
    - "The `Δt ⟂̸ σ` threat carries a pre-committed test with a numeric threshold and a terminal failure disposition."
    - "Under an INFEASIBLE split the decision rule is written HERE: `GATE OPENS` becomes unreachable, so the gate stays decidable."
    - "Disclosure is never harder than concealment — this plan can commit to `RESEARCH-REGISTER.md` §6 in the same commit as the freeze."
  artifacts:
    - path: "control/spec/PRE-REGISTRATION.md"
      provides: "The frozen Stage 1 specification, its numeric thresholds, the bad-control resolution, the Δt⟂̸σ pre-committed test, the split rule, and the decision rule under VOID"
      min_lines: 90
      contains: "first-stage F floor:"
  key_links:
    - from: "control/spec/PRE-REGISTRATION.md"
      to: "control/spec/POOL-ALGEBRA.md §5"
      via: "the venue-independent threshold lines are copied byte-equal and asserted identical"
      pattern: "first-stage F floor:"
    - from: "control/spec/PRE-REGISTRATION.md"
      to: "control/spec/STAGE1-RESULT.md"
      via: "this file's own commit sha is the freeze pin quoted in the Stage 1 result"
      pattern: "FREEZE"
---

<objective>
Freeze the Stage 1 specification: block on the dimensional check, copy the venue-independent
thresholds forward byte-equal, resolve the bad-control hazard, pre-commit the `Δt ⟂̸ σ` test,
write the decision rule under an infeasible split, and commit — so git history records that the
freeze predates the estimation data.

Purpose: `EST-06`, `EST-07`, `EST-08`, `EST-09`. These four **land with the pre-registration,
never after data is examined** (`ROADMAP.md` Phase 6b plan list).

Output: `control/spec/PRE-REGISTRATION.md`, plus any protocol note appended to
`control/spec/RESEARCH-REGISTER.md` §6.
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
@/home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller/control/spec/DISPERSION-WINDOW-A.md
@/home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller/control/spec/POOL-ALGEBRA.md
@/home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller/control/spec/NU-CONSTRUCTIBILITY.md
@/home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller/control/spec/RESEARCH-REGISTER.md

**Path glossary.** `WT` = `/home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller`. `PLANK` =
`/home/jmsbpp/cfmms-playground/cfmm-wt/plank` (**READ-ONLY**). `LEAN` =
`/home/jmsbpp/cfmms-playground/cfmm-wt/lean4-spec` (**READ-ONLY**). `DOC` =
`PLANK/notes/VOLATILITY_INSTRUMENTS.md`. `SRC` = `WT/notes/VOLATILITY_INTRUMENTS_MEV.md` @
`cf386de`.

**TERMINAL-BRANCH GUARD — the first thing every task does.**

```
cd /home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller
T1=$(grep -E '^PHASE-6B-TERMINAL:' control/spec/NU-CONSTRUCTIBILITY.md | head -1)
test -f control/spec/DISPERSION-WINDOW-A.md || { echo "06B-03 NOT RUN — 06B-02 produced no DISPERSION-WINDOW-A.md; there is no picked venue to freeze against"; exit 0; }
T2=$(grep -E '^PHASE-6B-TERMINAL:' control/spec/DISPERSION-WINDOW-A.md | head -1)
if [ "$T1" != "PHASE-6B-TERMINAL: NONE" ]; then echo "06B-03 NOT RUN — $T1"; exit 0; fi
if [ "$T2" != "PHASE-6B-TERMINAL: NONE" ]; then echo "06B-03 NOT RUN — $T2"; exit 0; fi
```

**DIMENSIONAL GATE — the second thing every task does.**

```
grep -qE '^DIMENSIONAL CHECK: PASS' control/spec/POOL-ALGEBRA.md || { echo "06B-03 BLOCKED — POOL-ALGEBRA.md section 3.1 did not return PASS; the freeze cannot be written"; exit 1; }
```

**This gate is not ceremonial.** `ROADMAP.md` says the Stage 1 specification cannot be fixed
without O4, and `ℙ_{Δ_ARB} = σ/(σ + φ√(2/Δt))` is a **Möbius function of `σ`**: substituting `σ²`
does not rescale the equation, it **changes the regressor**. A "provisional convention pending
`NOT-05`" would therefore not be a freeze at all — and because `NOT-05` is run by **this same
project**, it would also be an escape hatch: an unwelcome Stage 1 verdict could be voided by
ruling against the convention afterwards. Hence: `PASS` or no freeze.

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

**As the FIRST action of every task**, with `TAG` = `03-1`, `03-2`, `03-3`:

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
- **WINDOW B IS NOT TOUCHED.** Not queried, not summarized, not peeked at. A single window-B query
  here voids the pre-registration and is recorded in `RESEARCH-REGISTER.md` §6.
- **`DOC` citations carry a measured line and an 8-hex sha.** The `σ²(i(t))Δt < 8` guard is at
  **`DOC:958`**, not `:959`. Locate by content before citing.
</context>

<inherited>
**Phases 1, 2, 3 and 6a are UNEXECUTED at plan time.** `PRE-REGISTRATION.md` opens with an
`## Inherited, not assumed` section in which **every item carries exactly one of two markers** —
`PROVISIONAL — pending <requirement>` or `SETTLED BY <artifact> §<n>` — so that an artifact which
resolved its inheritances is not penalised for having done so:

- **O4 — `σ` versus `σ²`.** Its *dimensional* content for this estimating equation is
  **`SETTLED BY POOL-ALGEBRA.md §3.1`** — the gate above guarantees that check returned `PASS`,
  and §3.3 quotes the line. The broader `NOT-05` notation ledger is `PROVISIONAL — pending
  NOT-05` for anything **outside** the estimating equation. **The regressor's identity is not
  provisional.**
- **The event-clock ruling** (Phase 2 `FRM-03`). `Δt` is block-clock; `ν` and `λ_ARB` are
  swap-clock. `PROVISIONAL — pending FRM-03`. **Stating the dependence is not mitigation**, so
  Task 3 puts it to the user as an explicit HALT-or-accept decision before the freeze commits.
- **The hypothesis discipline** (Phase 3 `PRF-03`, `PRF-06`). `PROVISIONAL — pending PRF-06`.
  `H2_dnu_dlamMEV_pos` is a typed hypothesis, never submitted to the proving pipeline; `EST-03`
  discharges or refutes it.
- **`NEC-04`'s coupling verdict and recomposition rule** (Phase 6a). `PROVISIONAL — pending
  NEC-04`. `ECONOMETRICS-DESIGN.md:31` classifies `∂ν/∂λ_MEV` as **"Behavioural. Not derivable."**;
  `NEC-04` reopens it. **This plan assumes NEITHER verdict** and pre-writes all four branches in
  §3.2. `NEC-04` can **dissolve the estimand after window B is consumed**, so Task 3 puts that to
  the user as an explicit HALT-or-accept decision too.
- **`NEC-00`'s affine-in-`Ḡ` verdict** (Phase 6a). `PROVISIONAL — pending NEC-00`. Refuted-as-a-
  free-option by two independent reviewers and by the orchestrator's own derivation, but a
  two-reviewer consensus is **not** a machine-checked identity; the Gates table lists `NEC-00`
  **NOT REACHED**.
- **O2** — the FOC root is **not** established to be the minimiser
  (`Proposition15_level_reading_second_order_undetermined`,
  `control/aristotle/tax2-result/project_aristotle/RequestProject/MevTaxProgram.lean:823`).
  `PROVISIONAL — pending O2`. Restated, not resolved.
- **The review register** (Phase 1 `HND-05`) does not exist; the artifact carries its own
  `## Review`.
</inherited>

<tasks>

<task type="auto">
  <name>Task 1: EST-06 and EST-08 — the bad-control resolution and the pre-committed validity test</name>
  <files>control/spec/PRE-REGISTRATION.md</files>
  <read_first>
    - `/home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller/control/spec/NU-CONSTRUCTIBILITY.md` §4 and `control/spec/DISPERSION-WINDOW-A.md` §8 — the two terminal markers (the guard)
    - `/home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller/control/spec/POOL-ALGEBRA.md` §3.1 (the dimensional gate) and §5 (the venue-independent thresholds)
    - `/home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller/control/.planning/REQUIREMENTS.md` — `EST-06`, `EST-08`, and the `NEC-03` note that O3 has an implementation sense and an identification sense which must not displace each other
    - `/home/jmsbpp/cfmms-playground/cfmm-wt/plank/notes/VOLATILITY_INSTRUMENTS.md` — Definition 18, the fee schedule carrying **both** `σ` and `ν` (READ ONLY; locate by content, record measured line + blob sha)
    - `/home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller/control/spec/DISPERSION-WINDOW-A.md` §2 mechanism fields, §5 the Decision #10 ruling, §8 the pick
    - `/home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller/control/spec/ECONOMETRICS-DESIGN.md` §2 and §6 items 3 and 4
  </read_first>
  <action>
**FIRST: terminal guard, THEN dimensional gate, THEN scope sentinel `TAG=03-1`.**

Create `control/spec/PRE-REGISTRATION.md`.

Header:

```
# PRE-REGISTRATION — Stage 1 sign test of `Ḡ = ∂ν/∂λ_MEV`

**Requirements:** EST-06, EST-07, EST-08, EST-09
**Frozen:** <YYYY-MM-DD>
**Venue:** <the picked chain(s) / pool set>, per `control/spec/DISPERSION-WINDOW-A.md @ <sha>` §8
**Cluster count G:** <copied from DISPERSION-WINDOW-A.md §8>
**Upstream pins:** `RESEARCH-REGISTER.md @ <first-commit sha>`,
`POOL-ALGEBRA.md @ <first-commit sha>`, `NU-CONSTRUCTIBILITY.md @ <sha>`
**Dimensional gate:** <quote `POOL-ALGEBRA.md` §3.1's `DIMENSIONAL CHECK: PASS` line verbatim> —
the regressor's identity is SETTLED, not provisional.

**FREEZE.** This file's own commit sha is the freeze pin. Every downstream document quotes it.
**No window-B data has been examined at the time of writing.** Git history **records** the order;
neither clock is self-authenticating: the Dune execution timestamp in
`DISPERSION-WINDOW-A.md` §2 is transcribed by this session, as that file states. What this freeze
actually rests on is **structural**, not temporal — the terminal guards, the `DIMENSIONAL CHECK:
PASS` gate, §4.1's read of the locked blob, and §5a's lock.

**Any change to this file after its first commit is a re-specification.** Under
`anti-fishing-replication`'s Iron Law — `NO POST-LOCK CHANGE WITHOUT A HALT, A DISPOSITION MEMO,
AND A USER-ENUMERATED PIVOT` — a change requires a HALT, a disposition memo, and a pivot the
**user** enumerates. An analyst-proposed list of alternatives is itself the fishing pattern.
```

Then `## Inherited, not assumed` — the seven items, each carrying **exactly one** of
`PROVISIONAL — pending <requirement>` or `SETTLED BY <artifact> §<n>`.

**`## 1. EST-06 — the bad-control hazard, resolved before Stage 1 is specified`**

```
`φ_X` carries `ν` (`DOC` Definition 18 — the sigmoid gate takes both `σ` and `ν`). Therefore
`φ_X` is a **function of the outcome**, and conditioning on it is conditioning on a **descendant
of the dependent variable** — a bad control, inducing collider bias rather than removing
confounding.

This is open item **O3**'s *identification* content. `NEC-03` carries O3's *implementation*
content. **The implementation sense must not displace the identification sense** and neither
closes the other.

`Rule 13` at `SRC:69 @ cf386de` writes `φ_X(t) = Φ(Θ_φ; σ²(i(t)))` with **no `ν` argument**,
while `DOC` Definition 18's gate takes `ν` as well. Whether Rule 13's signature is incomplete or
the two objects differ is **O3**, routed to Phase 1 and **UNRESOLVED at freeze time**. The
resolution below must hold under *either* reading.
```

Then `### 1.1 RESOLUTION`, exactly one of:

```
EST-06 RESOLUTION: φ_X EXCLUDED — φ_X does not enter the Stage 1 specification in any form (not
as a level, not as a lag, not inside a constructed control). <Why exclusion does not reintroduce
the confounding it was meant to absorb.>

EST-06 RESOLUTION: φ_X ADMITTED UNDER <stated condition> — <the written argument that the
conditioning is not on a descendant of the outcome under this condition, and what falsifies it>.
```

The requirement's default is exclusion. Admitting it requires the argument, not an assertion.

`### 1.2 The full control set, enumerated` — table
`Variable | Role | Is it a descendant of ν? | Admitted?`. **Every admitted control gets a
descendant check**; a control whose descendant status is `UNKNOWN` is **excluded**.

**`## 2. EST-08 — `Δt ⟂̸ σ`, with a pre-committed test`**

```
The exclusion argument is that `Δt` does not appear in `φ = φ̄ + volSurcharge(σ)·gate(ν)` —
**structurally true**. But `Δt`'s realized variation comes from **missed slots, congestion and
reorgs**, which **cluster with volatility events**, and `σ` enters `φ` directly. So `Δt` can
correlate with the second-stage error **through the `σ` channel** without ever appearing in the
fee formula. This is plausibly **more fatal than the weak-instrument risk** the design names.

**Conditioning on `σ` is NOT a free fix**, because `σ` is itself a determinant of `φ` — the
control would sit on the causal path the instrument is supposed to identify.
```

`### 2.1 The pre-committed test`, with numbers:

```
**Test name:** <e.g. correlation of √Δt with realized σ at the clustering unit; or a reduced-form
placebo of σ on √Δt>
**Statistic:** <the exact statistic, its estimator and its clustering>
**Computed on:** window B, at the same time as the first stage, reported **alongside** the
first-stage F, before any second-stage output is examined.
**Threshold:** <NUMBER> — |ρ| ≤ <x>, or p ≥ <y>, or the reduced-form coefficient within
[<lo>, <hi>].
**Threshold provenance:** <the convention or calculation fixing it — not a bare judgement>
**Disposition on failure:** VERDICT: NOT IDENTIFIED. A validity failure is a validity failure.
```

`### 2.2 What failure does NOT license` — not "add a control", not "restrict the sample", not
"report with a caveat". Name `anti-fishing-replication` as the governing discipline.

`### 2.3 Selection-on-validity` — verbatim:

```
The user picked the venue knowing each candidate's σ-channel **mechanism** (`DISPERSION-WINDOW-A.md`
§4 deliberately withheld the statistic). If any σ-channel **statistic** had been computed on
window A before the pick, the §2.1 test would inherit the same argmax problem as the first-stage
F, one level up. Record which case holds:

**σ-channel statistic computed before the pick:** NO — the §2.1 test retains its nominal size. |
YES — the §2.1 statistic is labelled **DESCRIPTIVE** and its threshold rule **VOID**, exactly as
`EST-09` labels the F.
```
  </action>
  <acceptance_criteria>
    - Guard: on a terminal branch or a non-`PASS` dimensional check the task reports `NOT RUN` / `BLOCKED` and creates no file.
    - Otherwise `control/spec/PRE-REGISTRATION.md` ≥ 90 lines.
    - It contains `**FREEZE.**`, `No window-B data has been examined at the time of writing.`, and the Iron Law string.
    - It contains a `**Dimensional gate:**` line quoting `DIMENSIONAL CHECK: PASS`.
    - `## Inherited, not assumed` contains all seven names — `O4`, `FRM-03`, `PRF-03`, `NEC-04`, `NEC-00`, `O2`, `HND-05` — and **every** inherited bullet carries `PROVISIONAL — pending` or `SETTLED BY`; the O4 bullet carries `SETTLED BY POOL-ALGEBRA.md §3.1`.
    - It contains the four upstream pins with 7+ hex shas and a `**Cluster count G:**` line with an integer.
    - Exactly one line matches `^EST-06 RESOLUTION: (φ_X EXCLUDED|φ_X ADMITTED UNDER)`.
    - It contains `descendant of the dependent variable`, `O3`, `NEC-03`, `SRC:69 @ cf386de`.
    - §1.2's table: no row with `UNKNOWN` in the descendant column has `YES` in the admitted column.
    - §2 contains `cluster with volatility events`, `more fatal than the weak-instrument risk`, `is NOT a free fix`.
    - §2.1 contains `**Test name:**`, `**Statistic:**`, `**Computed on:**`, `**Threshold:**` with a numeral, `**Threshold provenance:**`, and `**Disposition on failure:** VERDICT: NOT IDENTIFIED`.
    - §2.2 contains `anti-fishing-replication`; §2.3 contains a `**σ-channel statistic computed before the pick:**` line resolved to `NO` or `YES` with no ` | ` alternation remaining.
    - **Scope sentinel:** the three `03-1.*.before` snapshots exist, are **newer than `.sentinel/.runstart`** (taken this run) and **not newer than the artifact** (taken before the edit), and each `diff -q` cleanly against the live value with `??` filtered on both sides — peer trees and the repo-root `.planning/` are **unchanged by this task**, which is not the same as clean.
  </acceptance_criteria>
  <verify>
    <automated>cd /home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller && T1=$(grep -E '^PHASE-6B-TERMINAL:' control/spec/NU-CONSTRUCTIBILITY.md | head -1) && if [ ! -f control/spec/DISPERSION-WINDOW-A.md ]; then echo "PASS (NOT RUN — no DISPERSION-WINDOW-A.md)"; exit 0; fi && T2=$(grep -E '^PHASE-6B-TERMINAL:' control/spec/DISPERSION-WINDOW-A.md | head -1) && if [ "$T1" != "PHASE-6B-TERMINAL: NONE" ]; then echo "PASS (NOT RUN — $T1)"; exit 0; fi && if [ "$T2" != "PHASE-6B-TERMINAL: NONE" ]; then echo "PASS (NOT RUN — $T2)"; exit 0; fi && grep -qE '^DIMENSIONAL CHECK: PASS' control/spec/POOL-ALGEBRA.md && F=control/spec/PRE-REGISTRATION.md && test -f $F && test $(wc -l < $F) -ge 90 && for s in '**FREEZE.**' 'No window-B data has been examined at the time of writing.' 'NO POST-LOCK CHANGE WITHOUT A HALT, A DISPOSITION MEMO, AND A USER-ENUMERATED PIVOT' '**Dimensional gate:**' 'DIMENSIONAL CHECK: PASS' '## Inherited, not assumed' 'O4' 'FRM-03' 'PRF-03' 'NEC-04' 'NEC-00' 'O2' 'HND-05' 'SETTLED BY POOL-ALGEBRA.md §3.1' '**Cluster count G:**' 'descendant of the dependent variable' 'O3' 'NEC-03' 'SRC:69 @ cf386de' 'cluster with volatility events' 'more fatal than the weak-instrument risk' 'is NOT a free fix' '**Test name:**' '**Statistic:**' '**Computed on:**' '**Threshold:**' '**Threshold provenance:**' '**Disposition on failure:** VERDICT: NOT IDENTIFIED' 'anti-fishing-replication'; do grep -qF "$s" $F || { echo "MISSING: $s"; exit 1; }; done && python3 -c "
import re
t=open('$F').read()
sec=t.split('## Inherited, not assumed')[1].split('## 1.')[0]
b=[l for l in sec.splitlines() if l.lstrip().startswith('- **')]
assert b, 'no inherited bullets'
for l in b:
    assert ('PROVISIONAL — pending' in l) or ('SETTLED BY' in l), 'unmarked inherited item: '+l[:80]
print('inheritance markers ok')
" && for p in 'RESEARCH-REGISTER\.md @ [0-9a-f]{7,}' 'POOL-ALGEBRA\.md @ [0-9a-f]{7,}' 'NU-CONSTRUCTIBILITY\.md @ [0-9a-f]{7,}' 'DISPERSION-WINDOW-A\.md @ [0-9a-f]{7,}'; do grep -qE "$p" $F || { echo "MISSING PIN: $p"; exit 1; }; done && grep -F '**Cluster count G:**' $F | grep -qE '[0-9]' && test $(grep -cE '^EST-06 RESOLUTION: (φ_X EXCLUDED|φ_X ADMITTED UNDER)' $F) -eq 1 && grep -F '**Threshold:**' $F | grep -qE '[0-9]' && test $(grep -E '^\|' $F | grep -cE 'UNKNOWN.*\| *YES *\|') -eq 0 && grep -F '**σ-channel statistic computed before the pick:**' $F | grep -qE '(NO|YES)' && test $(grep -F '**σ-channel statistic computed before the pick:**' $F | grep -c ' | ') -eq 0 && SENT=control/.planning/phases/06B-research-venue-and-estimating-mev/.sentinel && test "$SENT/03-1.plank.before" -nt "$SENT/.runstart" && { test ! -e "${F:-/nonexistent}" || ! test "$SENT/03-1.plank.before" -nt "${F:-/nonexistent}"; } && diff -q "$SENT/03-1.plank.before" <(git -C ../plank status --porcelain | grep -v '^??') && diff -q "$SENT/03-1.lean4spec.before" <(git -C ../lean4-spec status --porcelain | grep -v '^??') && diff -q "$SENT/03-1.rootplanning.before" <(git status --porcelain .planning/) && echo PASS</automated>
  </verify>
  <done>The freeze is blocked unless the dimensional check passed; every inherited item carries a PROVISIONAL or SETTLED marker so resolving an inheritance is not penalised; the bad-control hazard has exactly one recorded resolution holding under either O3 reading; every admitted control carries a descendant check; the `Δt ⟂̸ σ` test is named with a numeric threshold, a provenance, and a terminal failure disposition that does not license adding `σ`.</done>
</task>

<task type="auto">
  <name>Task 2: EST-07 and EST-09 — thresholds copied byte-equal, and the decision rule under VOID</name>
  <files>control/spec/PRE-REGISTRATION.md, control/spec/RESEARCH-REGISTER.md</files>
  <read_first>
    - `/home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller/control/spec/PRE-REGISTRATION.md` §1–§2
    - `/home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller/control/spec/POOL-ALGEBRA.md` §5 — the venue-independent thresholds, fixed in wave 2 **before any dispersion existed** — and §4.4, §4.5
    - `/home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller/control/.planning/REQUIREMENTS.md` — `EST-07` (effective-N and chain-time clustering) and `EST-09`
    - `/home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller/control/spec/DISPERSION-WINDOW-A.md` §6 and §8 — the picked venue, its dispersion, its `Split feasible` cell, its `Cluster count G`
    - `~/.claude/skills/structural-econometrics/SKILL.md` — the specification below is its Stage-3 output
    - `/home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller/control/spec/ECONOMETRICS-DESIGN.md` §3
  </read_first>
  <action>
**FIRST: terminal guard, dimensional gate, scope sentinel `TAG=03-2`.**

Append §3–§6 to `control/spec/PRE-REGISTRATION.md`.

**`## 3. The frozen Stage 1 specification`** — complete enough for a different analyst to run.

```
### 3.1 Estimand
`Ḡ = ∂ν/∂λ_MEV`. **Sign only.** One endogenous regressor, one instrument, **no functional-form
freedom**.

### 3.2 Under `NEC-04`'s branches (written BEFORE the verdict is known)
- **Independent** ⟹ Stage 1 tests the whole estimand.
- **Partially derivable** ⟹ Stage 1 tests a **residual**, and the recomposition rule
  `sign(residual) ⇏ sign(total)` governs what may be recorded against `H2`. A positive residual
  sign does **not** discharge `H2`.
- **Fully derivable, positive** ⟹ `H2` discharged algebraically; Stage 1 is confirmatory only.
- **Fully derivable, negative** ⟹ `H2` **refuted with no data at all**; Stage 1 does not run.

### 3.3 Variables, with units pinned
| Symbol | Definition | Units — `σ` or `σ²`, and which clock | Construction (read path) | Source pin |
<one row per variable; every Units cell states which of σ / σ² AND block-clock / swap-clock,
citing `POOL-ALGEBRA.md` §3.1's PASS. The regressor's dimension is SETTLED; the clock is
PROVISIONAL — pending FRM-03.>

### 3.4 First stage
`λ_ARB = π₀ + π₁·√Δt + <controls from §1.2> + ε` — on `√Δt`, **not raw `Δt`**.

### 3.5 Second stage
`ν = β₀ + β₁·λ̂_ARB + <controls from §1.2> + u`. **Hypothesis:** `β₁ > 0` = `H2_dnu_dlamMEV_pos`.

### 3.6 Aggregation and the unit of observation
<state it; PROVISIONAL — pending FRM-03>

### 3.7 Sample
Window B = [<start>, <end>), **disjoint from window A**. Venue: <picked>. Inclusion and exclusion
filters, enumerated and final.

### 3.8 Estimator and standard errors
<2SLS / GMM>, SEs clustered at **chain-time**, G = <the integer from §8>. If G = 1, record here
that cluster-robust inference at chain-time is **invalid** and name the inference actually used
(HAC time series, wild bootstrap, or the claim withdrawn).
```

**`## 4. EST-07 — the thresholds`**

`### 4.1 Venue-independent thresholds — COPIED, not re-chosen`

These were fixed at `POOL-ALGEBRA.md` §5 in **wave 2, before any dispersion existed**, and §5a
locked that section at its first commit. Choosing a dispersion floor now — with wave 3's numbers
in hand — is not a disclosable exception; it is choosing the bar to clear the jump.

**Copy the block byte-exactly from the LOCKED BLOB, not from the working tree:**

```
POOL-ALGEBRA §5 BLOB: <the sha recorded at `POOL-ALGEBRA.md` §7 `**POOL-ALGEBRA §5 BLOB:**`>
git cat-file blob <that sha>
```

**`git show <blob>:<path>` does NOT work** — `git rev-parse "<commit>:<path>"` yields a **blob**
sha, and `git show <blob>:control/spec/POOL-ALGEBRA.md` exits 128
(`fatal: path ... exists on disk, but not in <blob>`). Use `git cat-file blob <sha>`, or
`git show <sha>` with no path suffix.

and state:

```
**Copied verbatim from `POOL-ALGEBRA.md` §5 at locked blob `<sha>`. Equality asserted by this
plan's verification AGAINST THAT BLOB, not against the working tree. Not re-chosen here.**
```

**Why the blob and not the file.** Editing `POOL-ALGEBRA.md` §5 and this §4.1 identically at wave
4 would satisfy any file-to-file comparison while no HALT fired on either — the exact laundering
route §5a's lock exists to close. Reading the locked blob makes that edit fail here.

The copied lines are **every** line of §5, including its provenance lines — `criterion:`,
`published critical value:`, `bias tolerance tau:`, `nominal size:`, `MDES ceiling:`,
`MDES arithmetic (SHOWN, not asserted):`, `minimum N arithmetic (SHOWN, not asserted):` and
`dispersion inversion arithmetic (SHOWN, not asserted):`. **The arithmetic lines ARE the
provenance**; copying the numbers without them would let a fabricated derivation pass an equality
check that never looked at it.

`### 4.2 Venue-specific items — newly frozen here` (these genuinely depend on the pick).
**`minimum N` is NOT here**: window B's dates are declared at `POOL-ALGEBRA.md` §4.4 and cadence is
a chain-level fact, so realized N is computable in wave 2 — it is frozen there with its arithmetic
and copied in §4.1 like the rest.

```
- clustering level: chain-time
- window B boundary: [<start>, <end>) — copied from `POOL-ALGEBRA.md` §4.4
- sample filters: <enumerated, final>
```

Then verbatim:

```
**Clustering is not a detail.** With a **chain-level** instrument and **pool-level** outcomes,
effective N is the number of periods carrying `Δt` variation, **not** the number of swaps.
Reporting a swap-count N would overstate precision by orders of magnitude. The `υ` precedent
exists to remove exactly this discretion.
```

`### 4.3 Threshold provenance ledger` — one entry per threshold, each naming a **convention with a
citation**, a **published critical value**, or **shown arithmetic**. "Stated judgement" is
admissible only for the sample filters. If any threshold differs from `POOL-ALGEBRA.md` §5's,
that is a re-specification: HALT, and record it in `RESEARCH-REGISTER.md` §6 **in this same
commit** — this plan carries that file in its commit paths precisely so disclosure is never
harder than concealment.

**`## 5. EST-09 — selection separated from estimation`**

```
Selecting venue and pool set on measured dispersion and then reporting the first-stage F on that
same selection makes the reported F conditional on an **argmax**, upward-biased, and destroys the
nominal size of the pre-registered threshold.

**The split-sample is MANDATORY, not optional** (user ruling, 2026-08-09):
1. Dispersion measured and candidates ranked on **window A** — `DISPERSION-WINDOW-A.md`.
2. The user picked; specification, thresholds and clustering frozen and sha-pinned — this file.
3. Estimation on **window B**, disjoint from A — `06B-04`.

**Split status on the picked venue:** <copied verbatim from `DISPERSION-WINDOW-A.md` §8's
`**Split-sample status:**` line — FEASIBLE or INFEASIBLE, not re-derived>
```

`### 5.1 Decision rule when the split is INFEASIBLE` — **written here, before Stage 1 runs**,
because the three verdicts are defined in terms of a threshold rule that INFEASIBLE voids, and an
undefined gate is not a gate:

```
Under INFEASIBLE the first-stage F is labelled **DESCRIPTIVE** and §4's threshold rule is
**VOID**. Consequently:

- **`VERDICT: GATE OPENS` is UNREACHABLE.** It is defined by clearing the F floor, and a void
  threshold rule cannot be cleared. `06B-04` may not record it, and `06B-05` does not run.
- **`VERDICT: WRONG SIGN — H2 REFUTED` remains reachable — and here is WHY, because "a sign is
  not a threshold" is syntax carrying semantic load.** Candidates were ranked on measured `Δt`
  dispersion, which is selection on **first-stage strength**. That biases the realized F upward
  and is exactly what voids the F threshold. It is **approximately orthogonal to the second-stage
  sign**: nothing in the ranking criterion is a function of `ν`, of `β₁`, or of anything
  correlated with the outcome, so the sign test does not inherit the selection bias that the
  strength test does. **The limit of this argument, stated:** it fails the moment candidates are
  ranked on anything correlated with the outcome — a realized `ν` response, a fee-elasticity
  estimate, a second-stage pilot. `POOL-ALGEBRA.md` §4.1's threat column is mechanism-only and
  `06B-02` §4 forbids computing a σ-channel statistic before the pick precisely to keep this
  orthogonality true. If either is ever violated, this branch loses its justification and
  `WRONG SIGN` must be labelled DESCRIPTIVE alongside the F.
- **Otherwise `VERDICT: NOT IDENTIFIED`**, with the reason recorded as
  `SPLIT INFEASIBLE — THRESHOLD RULE VOID`.

Every downstream document repeats the DESCRIPTIVE label with the number it labels.
```

**`## 6. The three terminal verdicts, fixed here`**

These are the only three strings `06B-04` may record. **`06B-04` writes exactly ONE of them at
column 0**; the enumeration below is deliberately indented so that this listing cannot itself
satisfy a downstream anchored grep:

```
  VERDICT: GATE OPENS
      positive, significant at the pre-registered level, first stage at or above §4's floor, and
      the §2.1 validity test passed. Only this verdict permits `EST-04` (`06B-05`) to run.
      UNREACHABLE under an INFEASIBLE split — see §5.1.

  VERDICT: WRONG SIGN — H2 REFUTED
      `H2_dnu_dlamMEV_pos` refuted. `06B-05` does NOT run. The refutation back-propagates into
      both Lean bundles; `Theorem34_opposed_signs` and the corrected law's sign both flip.

  VERDICT: NOT IDENTIFIED
      first stage below the floor, or the §2.1 validity test failed, or N below §4.2's floor, or
      the split was infeasible. Terminal on the `υ` precedent — a delivered result, never a
      prompt to re-specify. `06B-05` does NOT run.

**None of the three terminates the project.** Phase 7 runs in every case.

**A re-specification after seeing Stage 1's output is a protocol violation** recorded in
`RESEARCH-REGISTER.md` §6. A softening of this gate was proposed on 2026-08-09 and **WITHDRAWN
the same day**: the FOC residual is affine in `Ḡ` — refuted-as-a-free-option by two independent
reviewers and by the orchestrator's own derivation, **PENDING `NEC-00`'s formal carrier**. This
gate retains full force on every path and the withdrawn reading may not be cited anywhere.
```
  </action>
  <acceptance_criteria>
    - Guard/gate behave as in Task 1.
    - `PRE-REGISTRATION.md` contains `### 3.1` … `### 3.8`; §3.2 names all four `NEC-04` branches and contains `sign(residual) ⇏ sign(total)`; §3.4 contains `√Δt` and `not raw`.
    - §3.3's table: every data row's units cell contains `σ` or `σ²` **and** `block` or `swap`.
    - §3.8 contains `G = ` with an integer; if G is 1, it also contains `invalid`.
    - §4.1 contains `Copied verbatim from` and a `POOL-ALGEBRA §5 BLOB:` line carrying a 40-hex sha **equal to the sha recorded at `POOL-ALGEBRA.md` §7 `**POOL-ALGEBRA §5 BLOB:**`** — and **both are re-derived from git**: `git rev-parse "$(git log --reverse --format=%H -- control/spec/POOL-ALGEBRA.md | head -1):control/spec/POOL-ALGEBRA.md"` must equal them. Comparing two working-tree copies would let a rewritten §7 plus a matching §4.1 pass without amending anything.
    - **Equality is asserted against that blob, not the working tree**, over the whole §5 label set including the provenance lines: `first-stage F floor:`, `criterion: Montiel Olea–Pflueger effective F`, `published critical value:`, `bias tolerance tau:`, `nominal size:`, `target power:`, `MDES:`, `MDES ceiling:`, `MDES arithmetic (SHOWN, not asserted):`, `minimum N:`, `N unit: chain-time periods carrying Δt variation`, `minimum N arithmetic (SHOWN, not asserted):`, `minimum Δt dispersion:`, `dispersion inversion arithmetic (SHOWN, not asserted):`. Each line is located inside the §5 slice of both texts, not by first substring match anywhere in the file.
    - §4.2 contains `clustering level: chain-time` and does **NOT** contain `minimum N:` — that threshold is frozen in wave 2 and reaches this file only through §4.1's copy.
    - §5.1 contains `approximately orthogonal to the second-stage sign` and `The limit of this argument, stated:` — the asymmetry is justified, with its failure condition named.
    - `### 7.2 Banned rationalizations` exists and lists the four phrases numbered 1–4.
    - §4 contains `effective N is the number of periods carrying` and `the number of swaps`.
    - `### 4.3 Threshold provenance ledger` has ≥ 5 entries and contains `RESEARCH-REGISTER.md`.
    - §5 contains `MANDATORY, not optional`, and a `**Split status on the picked venue:**` line that is byte-identical to the FEASIBLE/INFEASIBLE token on `DISPERSION-WINDOW-A.md` §8's `**Split-sample status:**` line.
    - `### 5.1` exists and contains `UNREACHABLE`, `WRONG SIGN — H2 REFUTED remains reachable` (matched on `remains reachable`), and `SPLIT INFEASIBLE — THRESHOLD RULE VOID`.
    - §6 contains all three verdict strings, **each indented** — `grep -c '^VERDICT:'` on this file returns **0**, so the enumeration cannot satisfy an anchored downstream grep.
    - §6 contains `None of the three terminates the project.`, `WITHDRAWN the same day`, and `PENDING` next to `NEC-00`.
    - No window-B statistic: `grep -inE 'window B.*(mean|sd|N *=|F *=)'` returns nothing.
  </acceptance_criteria>
  <verify>
    <automated>cd /home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller && T1=$(grep -E '^PHASE-6B-TERMINAL:' control/spec/NU-CONSTRUCTIBILITY.md | head -1) && if [ "$T1" != "PHASE-6B-TERMINAL: NONE" ]; then echo "PASS (NOT RUN)"; exit 0; fi && grep -qE '^DIMENSIONAL CHECK: PASS' control/spec/POOL-ALGEBRA.md && F=control/spec/PRE-REGISTRATION.md && P=control/spec/POOL-ALGEBRA.md && D=control/spec/DISPERSION-WINDOW-A.md && for s in '### 3.1' '### 3.2' '### 3.3' '### 3.4' '### 3.5' '### 3.6' '### 3.7' '### 3.8' 'sign(residual) ⇏ sign(total)' '√Δt' 'not raw' 'Copied verbatim from' 'first-stage F floor:' 'criterion: Montiel Olea–Pflueger effective F' 'published critical value:' 'target power:' 'MDES:' 'minimum Δt dispersion:' 'minimum N:' 'N unit: chain-time periods carrying Δt variation' 'clustering level: chain-time' 'effective N is the number of periods carrying' 'the number of swaps' '### 4.3 Threshold provenance ledger' 'RESEARCH-REGISTER.md' 'MANDATORY, not optional' '### 5.1' 'UNREACHABLE' 'remains reachable' 'SPLIT INFEASIBLE — THRESHOLD RULE VOID' 'approximately orthogonal to the second-stage sign' 'The limit of this argument, stated:' 'POOL-ALGEBRA §5 BLOB:' 'VERDICT: GATE OPENS' 'VERDICT: WRONG SIGN — H2 REFUTED' 'VERDICT: NOT IDENTIFIED' 'None of the three terminates the project.' 'WITHDRAWN the same day' 'PENDING'; do grep -qF "$s" $F || { echo "MISSING: $s"; exit 1; }; done && test $(grep -c '^VERDICT:' $F) -eq 0 && python3 -c "
import re,subprocess
pre=open('$F').read()
m=re.search(r'POOL-ALGEBRA §5 BLOB: *\`?([0-9a-f]{40})',pre)
assert m, 'no POOL-ALGEBRA section-5 blob sha recorded in the pre-registration'
blob=m.group(1)
locked=subprocess.run(['git','cat-file','blob',blob],capture_output=True,text=True)
assert locked.returncode==0, 'recorded blob sha does not resolve as a blob: '+blob
poolsrc=open('$P').read()
mrec=re.search(r'\*\*POOL-ALGEBRA §5 BLOB:\*\* *\`?([0-9a-f]{40})',poolsrc)
assert mrec and mrec.group(1)==blob, 'blob sha here does not match the one ratified at POOL-ALGEBRA section 7'
first=subprocess.run(['git','log','--reverse','--format=%H','--','control/spec/POOL-ALGEBRA.md'],capture_output=True,text=True).stdout.split()
assert first, 'POOL-ALGEBRA.md has no commit'
truth=subprocess.run(['git','rev-parse',first[0]+':control/spec/POOL-ALGEBRA.md'],capture_output=True,text=True).stdout.strip()
assert truth==blob, 'RECOMPUTED lock does not match the recorded sha: git says %s, the documents say %s -- rewriting section 7 and matching section 4.1 to it is exactly the laundering route this check closes'%(truth,blob)
def sec5(txt):
    i=txt.find('## 5. Venue-INDEPENDENT thresholds')
    assert i>0,'no section 5'
    j=txt.find('## 5a.',i)
    return txt[i:(j if j>0 else len(txt))]
def sec41(txt):
    i=txt.find('### 4.1')
    assert i>0,'no section 4.1'
    j=txt.find('### 4.2',i)
    return txt[i:(j if j>0 else len(txt))]
P5=sec5(locked.stdout).splitlines(); A41=sec41(pre).splitlines()
labels=['first-stage F floor:','criterion: Montiel Olea–Pflueger effective F','published critical value:','bias tolerance tau:','nominal size:','target power:','MDES:','MDES ceiling:','MDES arithmetic (SHOWN, not asserted):','minimum N:','N unit: chain-time periods carrying Δt variation','minimum N arithmetic (SHOWN, not asserted):','minimum Δt dispersion:','dispersion inversion arithmetic (SHOWN, not asserted):']
for L in labels:
    b=[l.strip() for l in P5 if L in l]
    a=[l.strip() for l in A41 if L in l]
    assert b, 'label missing from the LOCKED section 5: '+L
    assert a, 'label missing from section 4.1: '+L
    assert a[0]==b[0], 'NOT BYTE-EQUAL vs locked blob for %r:\n  pre : %s\n  pool: %s'%(L,a[0],b[0])
assert 'minimum N:' not in sec5(pre).replace(sec41(pre),'') or True
sec42=pre.split('### 4.2')[1].split('### 4.3')[0]
assert 'minimum N:' not in sec42, 'minimum N re-frozen in wave 4; it is locked in wave 2'
d=open('$D').read()
tok=lambda s:'INFEASIBLE' if 'INFEASIBLE' in s else ('FEASIBLE' if 'FEASIBLE' in s else None)
ds=[l for l in d.splitlines() if '**Split-sample status:**' in l]
ps=[l for l in pre.splitlines() if '**Split status on the picked venue:**' in l]
assert ds and ps, 'split status line missing'
assert tok(ds[0])==tok(ps[0]), 'split status not copied: %s vs %s'%(ds[0],ps[0])
rows=[l for l in open('$F').read().split('### 3.3')[1].split('### 3.4')[0].splitlines() if l.strip().startswith('|')]
data=[l for l in rows if not re.match(r'^\|[\s:\-|]+\|$',l.strip()) and 'Symbol' not in l]
for l in data:
    c=[x.strip() for x in l.strip().strip('|').split('|')]
    assert len(c)>=3, l
    assert ('σ' in c[2]), 'units cell lacks sigma: '+l
    assert ('block' in c[2] or 'swap' in c[2]), 'units cell lacks clock: '+l
print('copies and tables ok')
" && grep -F '### 3.8' -A6 $F | grep -qE 'G = *[0-9]+' && G=$(grep -oE 'G = *[0-9]+' $F | grep -oE '[0-9]+' | head -1) && { test "$G" -ge 2 || grep -qF 'invalid' $F; } && grep -F 'minimum N:' $F | grep -qE '[0-9]' && test $(awk '/^### 4\.3/,/^## 5\./' $F | grep -cE '^[-*|] ') -ge 5 && test -z "$(grep -inE 'window B.*(mean|sd|N *=|F *=)' $F)" && SENT=control/.planning/phases/06B-research-venue-and-estimating-mev/.sentinel && test "$SENT/03-2.plank.before" -nt "$SENT/.runstart" && { test ! -e "${F:-/nonexistent}" || ! test "$SENT/03-2.plank.before" -nt "${F:-/nonexistent}"; } && diff -q "$SENT/03-2.plank.before" <(git -C ../plank status --porcelain | grep -v '^??') && diff -q "$SENT/03-2.lean4spec.before" <(git -C ../lean4-spec status --porcelain | grep -v '^??') && diff -q "$SENT/03-2.rootplanning.before" <(git status --porcelain .planning/) && echo PASS</automated>
  </verify>
  <done>The specification is complete enough to hand to another analyst; the venue-independent thresholds are copied byte-equal from the wave-2 pre-registration rather than re-chosen against wave-3's numbers; the venue-specific items carry shown arithmetic; the split status is copied not re-derived; §5.1 makes the gate decidable under an infeasible split by making `GATE OPENS` unreachable; the verdict enumeration is indented so it cannot itself open a gate.</done>
</task>

<task type="checkpoint:decision" gate="blocking">
  <name>Task 3: Ratify the freeze, accept or halt on the unexecuted dependencies, review, commit</name>
  <files>control/spec/PRE-REGISTRATION.md, control/spec/RESEARCH-REGISTER.md</files>
  <read_first>
    - `/home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller/control/spec/PRE-REGISTRATION.md` (the whole file — the last moment it can change)
    - `/home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller/control/spec/DISPERSION-WINDOW-A.md` §8
    - `~/.claude/skills/anti-fishing-replication/SKILL.md`
    - `/home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller/control/.planning/ROADMAP.md` — "Gates — explicit semantics", `Stage gate — EST-03`
  </read_first>
  <decision>
Three things:

**(a) The frozen numbers.** After the commit, changing any of them is a re-specification
requiring a HALT, a disposition memo, and a pivot the **user** enumerates.

**(b) `FRM-03` — the event clock is UNRULED and can void the estimate after window B is burned.**
Stating the dependence is **not** mitigation. Decide explicitly: proceed and accept that a Phase 2
ruling against a block-clock instrument on swap-clock outcomes retrospectively invalidates Stage
1, or HALT 6b until Phase 2 executes.

**(c) `NEC-04` — the coupling verdict is UNRULED and can dissolve or narrow the estimand after
window B is consumed.** Same choice: proceed under §3.2's pre-written branches, or HALT until
Phase 6a executes.

(b) and (c) are put to the user **before** the freeze commits, because after it they are no
longer decisions — they are outcomes.
  </decision>
  <context>
The pre-registration's value is entirely in its ordering: it must predate the window-B data. Git
history **records** that; it does not prove it — `%ct` is settable via `GIT_COMMITTER_DATE`,
rewritten by `amend`/`rebase`, and this branch is destined for a PR→`develop` rebase. The
Dune execution timestamp in `DISPERSION-WINDOW-A.md` §2 is a better clock but is
   **transcribed, not self-authenticating**. The freeze's real guarantees are structural: the
   terminal guards, the dimensional gate, and §4.1's read of `POOL-ALGEBRA.md` §5 at its locked
   blob.

**The user picked the venue on measured dispersion** — the winner's curse `EST-09` registers. The
split-sample neutralizes it for the F. If the split is infeasible, the honest outcome is a
**DESCRIPTIVE** F and a **VOID** threshold rule, and §5.1's decision rule makes `GATE OPENS`
unreachable.

**Present the numbers, not a recommendation to accept them.** A threshold the user has not seen
is a threshold the analyst chose.
  </context>
  <options>
    <option id="ratify-freeze">
      <name>Ratify and commit the freeze; accept the FRM-03 and NEC-04 exposure</name>
      <pros>The ordering becomes auditable; the gate becomes adjudicable; `06B-04` can run.</pros>
      <cons>Irreversible. If Phase 2 rules against a time-axis instrument, or Phase 6a dissolves the estimand, window B is already burned and Stage 1's result is retrospectively void.</cons>
    </option>
    <option id="amend-freeze">
      <name>Amend a venue-specific threshold, then commit</name>
      <pros>Still pre-commit and pre-data.</pros>
      <cons>Must be justified on a convention, a published value, or shown arithmetic — never on window A's numbers. The venue-independent three may not be amended here at all; they were fixed in wave 2.</cons>
    </option>
    <option id="halt-dependencies">
      <name>HALT 6b until Phase 2 (`FRM-03`) and/or Phase 6a (`NEC-04`) execute</name>
      <pros>Removes the two ways this estimate can be voided after the data is spent.</pros>
      <cons>6b blocks on two unexecuted phases; the estimation slips indefinitely.</cons>
    </option>
    <option id="accept-descriptive">
      <name>The split is infeasible — accept a DESCRIPTIVE F and a VOID threshold rule</name>
      <pros>Honest; §5.1 keeps the gate decidable and the label travels with every number.</pros>
      <cons>`GATE OPENS` becomes unreachable, so `06B-05` cannot run on this path.</cons>
    </option>
  </options>
  <action>
**FIRST: terminal guard, dimensional gate, scope sentinel `TAG=03-3`.**

Present in one message: the §4.1 copied thresholds (marked as already fixed in wave 2), the §4.2
venue-specific numbers with their arithmetic, the `EST-06` resolution, the `EST-08` test and
threshold, the split status, and the two exposure decisions (b) and (c). Do **not** recommend
acceptance and do **not** attach an expected outcome to any threshold.

After the user rules, append:

```
## 7. Ratification of the freeze

**Put to the user:** <YYYY-MM-DD>
**Numbers presented:** <verbatim as presented>
**RULING:** <the user's words, quoted, not paraphrased>
**FRM-03 exposure:** ACCEPTED — a Phase 2 ruling against a block-clock instrument retrospectively
voids Stage 1 and that is accepted in advance. | HALTED — 6b waits for Phase 2.
**NEC-04 exposure:** ACCEPTED — §3.2's branches govern and a later verdict may narrow or dissolve
the estimand. | HALTED — 6b waits for Phase 6a.
**Amendments made and why:** <each, with its convention / published value / shown arithmetic — or
NONE>
**Status:** FROZEN
```

**Each of those fields must have its placeholders replaced and its ` | ` alternation resolved to
a single branch.** `**Status:**` carries exactly one word: `FROZEN` or `HALTED`.

`### 7.1 The void clause`, verbatim:

```
If Phase 1's `NOT-05` later rules against the unit convention recorded here, that does **not**
silently re-scale this freeze. Invoking a void requires a **user HALT** and a disposition memo.
**Invoking it after `control/spec/STAGE1-RESULT.md` exists is a recorded protocol violation** and
is written into `RESEARCH-REGISTER.md` §6 — because a convention that can be overturned after an
unwelcome verdict, by the same project that wrote it, is an escape hatch and not a freeze. The
dimensional gate at `POOL-ALGEBRA.md` §3.1 returned PASS precisely so this clause should never
need to fire.
```

`### 7.2 Banned rationalizations (the list `06B-04` references by name)`, verbatim:

```
The following phrases may not appear in `control/spec/STAGE1-RESULT.md`, because each is a
recorded rationalization from `anti-fishing-replication`'s `rationalizations.md`:

  1. proceeding with caveats
  2. exploratory framing
  3. one more robustness
  4. just to check

`06B-04` §5 records compliance by REFERENCE to this section, never by restating the phrases —
restating them in the file being checked would trip the check.
```

**Two-step review, THEN commit.** Run **Reality Checker** and **one named specialist, IN
PARALLEL**. The specialist is an econometrics/identification reviewer. Both must check: (i) no
threshold was reverse-engineered from window A's numbers — verify the byte-equality of §4.1
against `POOL-ALGEBRA.md` §5 themselves; (ii) no window-B statistic appears; (iii) the
recomposition rule is present **before** any Stage 1 output exists; (iv) §6's verdict enumeration
is indented and `grep -c '^VERDICT:'` returns 0. Record in `## Review` with **counts and
dispositions**:

```
## Review
**Reviewer 1 (always):** Reality Checker — <date>. findings: <B> BLOCKER / <M> MAJOR / <m> MINOR.
  disposition: <resolved N, carried N — each carried item named>.
**Reviewer 2 (named specialist):** <name> — chosen because <reason>. <date>.
  findings: <B> BLOCKER / <M> MAJOR / <m> MINOR. disposition: <...>.
**Byte-equality of §4.1 independently verified:** <command run> → <result>.
```

Resolve every BLOCKER and MAJOR **before** the commit — a post-commit fix to this file is itself
the thing the file exists to prevent.

Then commit. **Both paths are staged** so that a protocol note in `RESEARCH-REGISTER.md` §6 can
land in the same commit as the freeze — disclosure must never be harder than concealment:

```
cd /home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller
git add control/spec/PRE-REGISTRATION.md control/spec/RESEARCH-REGISTER.md
git commit -m "docs(06B): FREEZE - Stage 1 pre-registration, thresholds copied forward, split-sample mandatory

Closes EST-06, EST-07, EST-08, EST-09. Blocked on POOL-ALGEBRA section 3.1
returning DIMENSIONAL CHECK: PASS. Bad-control hazard resolved before the
specification is written; venue-independent thresholds copied byte-equal from the
wave-2 pre-registration; venue-specific N and clustering frozen with shown
arithmetic; the Delta-t-not-orthogonal-to-sigma threat carries a pre-committed
test with a terminal failure disposition; the decision rule under an infeasible
split is written before Stage 1 runs.

This commit IS the freeze. Its sha is quoted in every downstream document.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>" -- control/spec/PRE-REGISTRATION.md control/spec/RESEARCH-REGISTER.md
git show --name-only --format="" HEAD
git log --reverse --format='FREEZE SHA %H %ct %cI' -- control/spec/PRE-REGISTRATION.md | head -1
```

Record the `FREEZE SHA` line in the SUMMARY verbatim.
  </action>
  <acceptance_criteria>
    - Guard/gate behave as in Task 1.
    - `PRE-REGISTRATION.md` contains `## 7. Ratification of the freeze` with `**Put to the user:**`, `**Numbers presented:**`, `**RULING:**`, `**FRM-03 exposure:**`, `**NEC-04 exposure:**`, `**Amendments made and why:**`, and `**Status:**`.
    - `**Status:**` matches `^\*\*Status:\*\* (FROZEN|HALTED)$` exactly.
    - `**FRM-03 exposure:**` and `**NEC-04 exposure:**` each contain `ACCEPTED` or `HALTED` and **no** ` | ` alternation; none of the seven §7 field lines contains `<` or `>`.
    - `### 7.1 The void clause` contains `user HALT`, `STAGE1-RESULT.md`, `recorded protocol violation`, and `escape hatch`.
    - `### 7.2 Banned rationalizations` is present and lists the four phrases numbered `1.`–`4.`
    - `## Review` names `Reality Checker` and a second reviewer, with two `findings:` count lines, two `disposition:` lines, and a `**Byte-equality of §4.1 independently verified:**` line.
    - `git show --name-only --format="" HEAD` lists **at most 2** paths, all under `control/spec/`, and includes `control/spec/PRE-REGISTRATION.md`.
    - `git log --reverse --format=%H -- control/spec/PRE-REGISTRATION.md | head -1` returns a non-empty sha, and its `%ct` is `-ge` the first-commit `%ct` of `control/spec/DISPERSION-WINDOW-A.md`. This **records** ordering; the Dune execution timestamp is the independent clock.
    - `control/spec/STAGE1-RESULT.md` does **not** exist — the freeze precedes the result by construction.
    - **Scope sentinel:** the three `03-3.*.before` snapshots exist, are **newer than `.sentinel/.runstart`** (taken this run) and **not newer than the artifact** (taken before the edit), and each `diff -q` cleanly against the live value with `??` filtered on both sides — peer trees and the repo-root `.planning/` are **unchanged by this task**, which is not the same as clean.
  </acceptance_criteria>
  <resume-signal>Reply `ratify` (and state `accept` or `halt` for each of FRM-03 and NEC-04), `amend: <threshold> = <value> because <convention / published value / arithmetic>`, or `halt`.</resume-signal>
  <verify>
    <automated>cd /home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller && T1=$(grep -E '^PHASE-6B-TERMINAL:' control/spec/NU-CONSTRUCTIBILITY.md | head -1) && if [ "$T1" != "PHASE-6B-TERMINAL: NONE" ]; then echo "PASS (NOT RUN)"; exit 0; fi && grep -qE '^DIMENSIONAL CHECK: PASS' control/spec/POOL-ALGEBRA.md && F=control/spec/PRE-REGISTRATION.md && for s in '### 7.2 Banned rationalizations' '## 7. Ratification of the freeze' '**Put to the user:**' '**Numbers presented:**' '**RULING:**' '**FRM-03 exposure:**' '**NEC-04 exposure:**' '**Amendments made and why:**' '### 7.1 The void clause' 'user HALT' 'STAGE1-RESULT.md' 'recorded protocol violation' 'escape hatch' '## Review' 'Reality Checker' '**Byte-equality of §4.1 independently verified:**'; do grep -qF "$s" $F || { echo "MISSING: $s"; exit 1; }; done && grep -qE '^\*\*Status:\*\* (FROZEN|HALTED)$' $F && grep -F '**FRM-03 exposure:**' $F | grep -qE 'ACCEPTED|HALTED' && grep -F '**NEC-04 exposure:**' $F | grep -qE 'ACCEPTED|HALTED' && test $(awk '/^## 7\. Ratification/,0' $F | grep -E '^\*\*(Put to the user|Numbers presented|RULING|FRM-03 exposure|NEC-04 exposure|Amendments made and why|Status):\*\*' | grep -cE '<|>|\| ') -eq 0 && test $(grep -cE '^ *findings: *[0-9]+ BLOCKER */ *[0-9]+ MAJOR */ *[0-9]+ MINOR' $F) -ge 2 && test $(grep -cE 'disposition:' $F) -ge 2 && test $(git show --name-only --format="" HEAD | grep -c .) -le 2 && test $(git show --name-only --format="" HEAD | grep -vc '^control/spec/') -eq 0 && git show --name-only --format="" HEAD | grep -qxF 'control/spec/PRE-REGISTRATION.md' && S=$(git log --reverse --format=%H -- control/spec/PRE-REGISTRATION.md | head -1) && test -n "$S" && A=$(git log --reverse --format=%ct -- control/spec/PRE-REGISTRATION.md | head -1) && B=$(git log --reverse --format=%ct -- control/spec/DISPERSION-WINDOW-A.md | head -1) && test "$A" -ge "$B" && test ! -f control/spec/STAGE1-RESULT.md && SENT=control/.planning/phases/06B-research-venue-and-estimating-mev/.sentinel && test "$SENT/03-3.plank.before" -nt "$SENT/.runstart" && { test ! -e "${F:-/nonexistent}" || ! test "$SENT/03-3.plank.before" -nt "${F:-/nonexistent}"; } && diff -q "$SENT/03-3.plank.before" <(git -C ../plank status --porcelain | grep -v '^??') && diff -q "$SENT/03-3.lean4spec.before" <(git -C ../lean4-spec status --porcelain | grep -v '^??') && diff -q "$SENT/03-3.rootplanning.before" <(git status --porcelain .planning/) && echo "PASS freeze=$S"</automated>
  </verify>
  <done>The user ratified the frozen numbers and made the `FRM-03` and `NEC-04` exposures explicit decisions rather than stated dependencies; the void clause requires a user HALT and makes post-`STAGE1-RESULT` invocation a recorded violation; the review independently verified the §4.1 byte-equality; the commit carries the freeze and any protocol note together so disclosure is not penalised.</done>
</task>

</tasks>

<verification>
1. The freeze cannot be written unless `DIMENSIONAL CHECK: PASS` — O4 changes the regressor, so a
   provisional convention is not a freeze and would double as an escape hatch.
2. The venue-independent thresholds are byte-equal to `POOL-ALGEBRA.md` §5, fixed in wave 2 before
   any dispersion existed.
3. `grep -c '^VERDICT:'` on `PRE-REGISTRATION.md` returns 0 — the enumeration is indented and
   cannot open a downstream gate.
4. §5.1 makes the gate decidable under an infeasible split.
5. Ordering is **recorded** by first-commit `%ct`; the Dune execution timestamp is the independent
   clock. Peer trees and repo-root `.planning/` unchanged by this plan.
</verification>

<success_criteria>
- `EST-06` closed: the bad-control hazard resolved in writing before the specification.
- `EST-07` closed: every threshold numeric, the venue-independent three copied byte-equal from
  wave 2, the venue-specific ones with shown arithmetic, clustering at chain-time with effective N
  in periods.
- `EST-08` closed: a pre-committed test with a numeric threshold and a terminal failure
  disposition.
- `EST-09` closed: selection separated from estimation, with a written decision rule for the
  infeasible case.
- The freeze is a committed file whose first-commit sha is the downstream pin.
</success_criteria>

<output>
After completion, create
`/home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller/control/.planning/phases/06B-research-venue-and-estimating-mev/06B-03-SUMMARY.md`,
recording the `FREEZE SHA` line verbatim, all thresholds, the `EST-06` resolution, the `EST-08`
threshold, the split status, and the `FRM-03` / `NEC-04` exposure rulings.
</output>
