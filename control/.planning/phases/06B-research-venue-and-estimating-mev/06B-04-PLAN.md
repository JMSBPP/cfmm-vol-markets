---
phase: 06B-research-venue-and-estimating-mev
plan: 04
type: execute
wave: 5
depends_on: ["06B-03"]
files_modified:
  - control/spec/STAGE1-RESULT.md
  - control/analysis/gbar_stage1.py
  - control/spec/RESEARCH-REGISTER.md
autonomous: false
requirements: [EST-03]

must_haves:
  truths:
    - "This plan does not run on a terminal branch or an unfrozen phase — it reads the markers off disk and exits 0 reporting NOT RUN."
    - "The first-stage F and the validity test are computed and reported BEFORE any second-stage output is examined."
    - "The estimation ran on window B only, disjoint from the window A that ranked the candidates."
    - "The file carries EXACTLY ONE column-0 `VERDICT:` line — the admissible set is enumerated indented so that listing it cannot itself open the gate."
    - "`GATE OPENS` is unrecordable when the freeze says the split is INFEASIBLE, per the pre-registration's §5.1 decision rule."
    - "Every number is recomputable: the pinned script's sha256 is re-derived, and the recorded command is re-run and diffed against the recorded raw output."
  artifacts:
    - path: "control/spec/STAGE1-RESULT.md"
      provides: "The first-stage F reported first, the validity test result, and exactly one of three terminal verdicts"
      min_lines: 70
      contains: "FREEZE PIN:"
    - path: "control/analysis/gbar_stage1.py"
      provides: "The pinned, sha256-recorded Stage 1 analysis script — never mutated after the verdict is recorded"
      min_lines: 30
  key_links:
    - from: "control/spec/STAGE1-RESULT.md"
      to: "control/spec/PRE-REGISTRATION.md"
      via: "the freeze sha is quoted and each threshold is compared against the frozen file's own line via git show, not restated"
      pattern: "FREEZE PIN:"
    - from: "control/spec/STAGE1-RESULT.md"
      to: "control/spec/STAGE2-RESULT.md"
      via: "the single column-0 verdict line is the gate 06B-05 checks before running"
      pattern: "VERDICT:"
---

<objective>
Run Stage 1 — the sign test on `∂ν/∂λ_MEV` — on window B against the frozen specification,
reporting the first-stage F before any second-stage output is examined, and return **exactly one
of three terminal verdicts**.

Purpose: `EST-03`. This is the **hard gate**. `ROADMAP.md`, "Gates — explicit semantics": *gate
opens* ⟹ **`06B-05`** runs; *wrong sign* ⟹ `H2` REFUTED and it does not; *not identified* ⟹ it
does not. (The roadmap's Gates table still carries the pre-split plan numbering; under this
phase's numbering the plan that runs on `GATE OPENS` is **`06B-05`**.)

**A softening was proposed on 2026-08-09 and WITHDRAWN the same day** — the FOC residual is
affine in `Ḡ`, refuted-as-a-free-option by two independent reviewers and by the orchestrator's own
derivation, **PENDING `NEC-00`'s formal carrier**. This gate retains full force on every path.

Output: `control/spec/STAGE1-RESULT.md`, `control/analysis/gbar_stage1.py`.
</objective>

<execution_context>
@/home/jmsbpp/.claude/get-shit-done/workflows/execute-plan.md
@/home/jmsbpp/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@/home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller/control/.planning/ROADMAP.md
@/home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller/control/.planning/REQUIREMENTS.md
@/home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller/control/.planning/phases/06B-research-venue-and-estimating-mev/06B-CONTEXT.md
@/home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller/control/spec/PRE-REGISTRATION.md
@/home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller/control/spec/DISPERSION-WINDOW-A.md
@/home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller/control/spec/ECONOMETRICS-DESIGN.md

**Path glossary.** `WT` = `/home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller`. `PLANK` =
`/home/jmsbpp/cfmms-playground/cfmm-wt/plank` (**READ-ONLY**). `LEAN` =
`/home/jmsbpp/cfmms-playground/cfmm-wt/lean4-spec` (**READ-ONLY**).

**TERMINAL / FREEZE GUARD — the first thing every task does.**

```
cd /home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller
T1=$(grep -E '^PHASE-6B-TERMINAL:' control/spec/NU-CONSTRUCTIBILITY.md | head -1)
test -f control/spec/DISPERSION-WINDOW-A.md || { echo "06B-04 NOT RUN — no DISPERSION-WINDOW-A.md; no venue was ever picked"; exit 0; }
T2=$(grep -E '^PHASE-6B-TERMINAL:' control/spec/DISPERSION-WINDOW-A.md | head -1)
if [ "$T1" != "PHASE-6B-TERMINAL: NONE" ]; then echo "06B-04 NOT RUN — $T1"; exit 0; fi
if [ "$T2" != "PHASE-6B-TERMINAL: NONE" ]; then echo "06B-04 NOT RUN — $T2"; exit 0; fi
grep -qE '^\*\*Status:\*\* FROZEN$' control/spec/PRE-REGISTRATION.md || { echo "06B-04 NOT RUN — no freeze (PRE-REGISTRATION.md is not FROZEN)"; exit 0; }
```

Exit `0`, never `1`: `ROADMAP.md` requires the phase to reach `06B-06` on every branch.

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

**As the FIRST action of every task**, with `TAG` = `04-1`, `04-2`, `04-3`:

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
- **The frozen specification is not restated from memory.** Every threshold used here is read out
  of the frozen blob — `git show <FREEZE SHA>:control/spec/PRE-REGISTRATION.md` — and compared,
  not retyped.
- **No re-specification.** Not a covariate, lag, transform, sample filter, SE method or test
  geometry outside the lock, even "to check". That is `anti-fishing-replication`'s trigger and it
  fires as a **HALT**.
- **The analysis script is pinned at `control/analysis/gbar_stage1.py` and is NEVER MUTATED after
  the verdict is recorded.** `06B-05` writes a *separate* `gbar_stage2.py`; extending this file
  would silently break the reproduction guarantee for the gate-deciding result.

Estimation tooling (`python-panel-data` / `stata-regression` / `r-econometrics`) is admissible
from here onward. `structural-econometrics` is scoped *before* estimation code and has already
run; it is not re-run to reinterpret a result.
</context>

<inherited>
**Phases 1, 2, 3 and 6a are UNEXECUTED at plan time.** `STAGE1-RESULT.md` opens with an
`## Inherited, not assumed` section in which every item carries `PROVISIONAL — pending <req>` or
`SETTLED BY <artifact> §<n>`:

- **O4 — `σ` vs `σ²`.** `SETTLED BY POOL-ALGEBRA.md §3.1` for the estimating equation (the
  dimensional check returned PASS and the freeze was gated on it). `PROVISIONAL — pending NOT-05`
  only for notation outside the equation. **The `PRE-REGISTRATION.md` §7.1 void clause requires a
  user HALT, and invoking it after this file exists is a recorded protocol violation.**
- **The event-clock ruling** (Phase 2 `FRM-03`). `PROVISIONAL — pending FRM-03`. The exposure was
  put to the user at the freeze and its ruling is quoted here from `PRE-REGISTRATION.md` §7.
- **The hypothesis discipline** (Phase 3 `PRF-03`, `PRF-06`). `PROVISIONAL — pending PRF-06`.
  `H2` is a typed hypothesis; this result discharges or refutes it and is never sent to the
  proving pipeline.
- **`NEC-04`'s coupling verdict** (Phase 6a). `PROVISIONAL — pending NEC-04`. §3.4 states which
  branch this result is reported under; the exposure ruling is quoted from `PRE-REGISTRATION.md`
  §7.
- **`NEC-00`'s affine-in-`Ḡ` verdict** (Phase 6a). `PROVISIONAL — pending NEC-00`. Refuted-as-a-
  free-option by two independent reviewers and by the orchestrator's own derivation; **not** a
  machine-checked identity, and the Gates table lists `NEC-00` **NOT REACHED**.
- **O2** — the FOC root is not established to be the minimiser
  (`control/aristotle/tax2-result/project_aristotle/RequestProject/MevTaxProgram.lean:823`).
  `PROVISIONAL — pending O2`.
- **The review register** (Phase 1 `HND-05`) does not exist; this artifact carries its own
  `## Review`.
</inherited>

<tasks>

<task type="auto">
  <name>Task 1: The first stage ONLY — F reported before any second-stage output exists</name>
  <files>control/spec/STAGE1-RESULT.md, control/analysis/gbar_stage1.py</files>
  <read_first>
    - `/home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller/control/spec/PRE-REGISTRATION.md` — §3 the specification, §4 the thresholds, §2.1 the validity test, §5 and §5.1 the split status and the VOID decision rule, §6 the three verdict strings, §7 the exposure rulings
    - `/home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller/control/spec/DISPERSION-WINDOW-A.md` §8 — the picked venue, `G`, the window boundary
    - `/home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller/control/spec/ECONOMETRICS-DESIGN.md` §2 — "Report the **first-stage F before** examining the second stage. A weak first stage is a stop, not a caveat."
    - `~/.claude/skills/anti-fishing-replication/SKILL.md` — trigger conditions, and what HALT means strictly
    - `~/.claude/skills/python-panel-data/SKILL.md` — clustering and fixed-effects mechanics
  </read_first>
  <action>
**FIRST: terminal/freeze guard, THEN scope sentinel `TAG=04-1`.**

Write the analysis script at the pinned path `control/analysis/gbar_stage1.py`. It reads window B,
runs the frozen first stage, and writes its console output verbatim. Record
`sha256sum control/analysis/gbar_stage1.py`.

**This task computes and reports the FIRST STAGE ONLY.** Do not compute, print, inspect or store
any second-stage coefficient here. A first-stage F read after a second-stage sign is not a
pre-registered first-stage F, whatever the file says.

Create `control/spec/STAGE1-RESULT.md`:

```
# STAGE 1 — the sign test of `Ḡ = ∂ν/∂λ_MEV`

**Requirement:** EST-03 — the HARD GATE
**Run:** <YYYY-MM-DD>
**FREEZE PIN:** `control/spec/PRE-REGISTRATION.md @ <the FREEZE SHA from 06B-03, full 40-hex>`
**Analysis script:** `control/analysis/gbar_stage1.py`
**Script sha256:** <64-hex>
**Venue:** <picked chain(s) / pool set>  **Cluster count G:** <integer>
**Sample:** window B = [<start>, <end>), **disjoint from window A**, which is the selection window
and is not estimated on.
**Split status (copied from the freeze, single token, no alternation):** <FEASIBLE or INFEASIBLE —
copied byte-for-byte from `PRE-REGISTRATION.md` §5's `**Split status on the picked venue:**` line,
never re-derived. This plan's verification compares the two tokens; a leftover template, a typo or
a flipped token fails.>
**Ordering claim:** §2 (first stage) is written and committed-to before §3 (second stage) is
computed. §3 was not run at the time §2 was written.
```

Then `## Inherited, not assumed` — the seven items, each with `PROVISIONAL — pending` or
`SETTLED BY`, and quoting `PRE-REGISTRATION.md` §7's `FRM-03 exposure:` and `NEC-04 exposure:`
rulings.

**`## 1. The frozen specification, quoted from the frozen blob`**

Extract each frozen line **from git**, not from the working tree and not from memory:

```
FS=<FREEZE SHA>
for L in 'first-stage F floor:' 'minimum Δt dispersion:' 'minimum N:' 'target power:' 'clustering level: chain-time'; do
  echo "== $L"; git show $FS:control/spec/PRE-REGISTRATION.md | grep -F "$L"
done
```

Paste each command **and its output** verbatim into §1. **If any working-tree value differs from
the frozen blob's, STOP** — that is a re-specification and a HALT, not a correction.

**`## 2. The first stage — reported first`**

```
### 2.1 Regression
`λ_ARB = π₀ + π₁·√Δt + <the frozen controls> + ε`, on window B, SEs clustered at **chain-time**,
G = <integer>.

### 2.2 Result
| Quantity | Value | Frozen threshold | Pass? |
|---|---|---|---|
| effective N (chain-time periods carrying `Δt` variation) | | `minimum N:` <n> | |
| `π₁` (coefficient on `√Δt`) | | — | — |
| SE(`π₁`), clustered chain-time | | — | — |
| **first-stage F** (criterion: Montiel Olea–Pflueger effective F) | | `first-stage F floor:` <f> | |
| realized `Δt` dispersion on window B (same statistic as window A) | | `minimum Δt dispersion:` <d> | |
| realized power at the frozen MDES | | `target power:` <p> | |

**If the split status is INFEASIBLE**, the `first-stage F` row's `Pass?` cell reads
`DESCRIPTIVE — THRESHOLD RULE VOID`, per `PRE-REGISTRATION.md` §5.1, and it is **not** reported as
a pass.

Then `### 2.2a Numeric threshold comparison` — the `Pass?` cells above are prose until the numbers
are compared. Write one line per gated quantity, in exactly this form, and let the verify
recompute each verdict from the two numbers it carries:

```
THRESHOLD CHECK: first-stage F — realized <value> vs floor <value> — PASS | FAIL | DESCRIPTIVE
THRESHOLD CHECK: effective N — realized <value> vs floor <value> — PASS | FAIL
THRESHOLD CHECK: Δt dispersion — realized <value> vs floor <value> — PASS | FAIL
```

Every floor is read from the frozen blob (`git show <FREEZE SHA>:control/spec/PRE-REGISTRATION.md`),
never retyped. `DESCRIPTIVE` is admissible **only** on the F line and **only** when the split status
is INFEASIBLE.

### 2.3 The pre-committed validity test (`EST-08`)
<the frozen §2.1 test, its statistic, its value, its frozen threshold, PASS or FAIL>

### 2.4 Reproduction
**Command:** <the exact re-runnable command>
**Raw output file:** `control/data/stage1/first-stage.txt` (committed)
**Raw output:** <pasted verbatim, identical to the file>
```

**Anti-fabrication is enforced structurally, with one hole closed explicitly.** The verify
recomputes `sha256sum control/analysis/gbar_stage1.py` against the recorded value, **re-runs the
recorded command**, and diffs its output against the committed raw-output file.

**`**Command:**` MUST invoke `control/analysis/gbar_stage1.py`.** Without that constraint the
check is self-referential: `**Command:** cat control/data/stage1/first-stage.txt` would diff a file
against itself and pass, and "a number that survives this was computed" would be false. The verify
asserts the command string contains the script path, so the diff exercises the analysis, not a
`cat`.

**`## 2.5 HALT check — run before §3 is computed`**

Evaluate every `Pass?` cell in §2.2 and the PASS/FAIL in §2.3. If **any** fails:

```
**HALT.** <which target was missed, with the realized value and the frozen threshold>

Under the Iron Law — `NO POST-LOCK CHANGE WITHOUT A HALT, A DISPOSITION MEMO, AND A
USER-ENUMERATED PIVOT` — the second stage is **not run** and the verdict is `NOT IDENTIFIED`.
HALT is **not** run-with-corrections, run-and-footnote, run-and-label-exploratory, or "compromise:
I'll caveat". Write the disposition memo per `halt-procedure.md` and stop.
```

A missed F floor, a failed validity test, or N below the floor **each independently** yields
`NOT IDENTIFIED` without the second stage ever being computed. That is the exercise returning one
of its three designed outcomes.
  </action>
  <acceptance_criteria>
    - Guard: on a terminal branch or an unfrozen pre-registration the task reports `NOT RUN` and creates no file.
    - Otherwise `control/spec/STAGE1-RESULT.md` ≥ 70 lines and `control/analysis/gbar_stage1.py` exists.
    - `**FREEZE PIN:**` carries a sha that **equals** `git log --reverse --format=%H -- control/spec/PRE-REGISTRATION.md | head -1`.
    - The recorded `**Script sha256:**` equals `sha256sum control/analysis/gbar_stage1.py`.
    - `## Inherited, not assumed` contains `O4`, `FRM-03`, `PRF-03`, `NEC-04`, `NEC-00`, `O2`, and every inherited bullet carries `PROVISIONAL — pending` or `SETTLED BY`; the file quotes `FRM-03 exposure:` and `NEC-04 exposure:`.
    - §1 quotes all five threshold labels and contains `git show` at least once; for each label, the value in §1 matches the value in the frozen blob (`git show <FS>:...`).
    - §2.2's table has ≥ 6 data rows; the `first-stage F` row carries a numeral and a `Pass?` cell containing `YES`, `NO`, or `DESCRIPTIVE — THRESHOLD RULE VOID`.
    - §2.3 contains `PASS` or `FAIL`.
    - §2.4's `**Command:**` **contains `control/analysis/gbar_stage1.py`** — a `cat` of the raw-output file would diff against itself and pass — and re-runs with stdout matching the committed `control/data/stage1/first-stage.txt`.
    - `### 2.2a Numeric threshold comparison` exists with a `THRESHOLD CHECK:` line for the first-stage F, effective N and `Δt` dispersion. **Each verdict is recomputed** from its two numbers; each floor must equal the value in the frozen blob; `DESCRIPTIVE` appears only on the F line and only when the split status is `INFEASIBLE`.
    - `**Split status (copied from the freeze` carries exactly one of `FEASIBLE`/`INFEASIBLE`, contains no ` | ` and no `<`/`>`, and its token is **byte-equal** to the token on `PRE-REGISTRATION.md` §5's `**Split status on the picked venue:**` line.
    - §2.5 exists; if any `Pass?` is `NO` or §2.3 is `FAIL`, the file contains `**HALT.**`.
    - The **first-commit** `%ct` of `control/spec/PRE-REGISTRATION.md` is `-le` the first-commit `%ct` of `control/spec/STAGE1-RESULT.md` once committed (checked in Task 3; here the freeze file exists and this file is new).
    - **Scope sentinel:** the three `04-1.*.before` snapshots exist, are **newer than `.sentinel/.runstart`** (taken this run) and **not newer than the artifact** (taken before the edit), and each `diff -q` cleanly against the live value with `??` filtered on both sides — peer trees and the repo-root `.planning/` are **unchanged by this task**, which is not the same as clean.
  </acceptance_criteria>
  <verify>
    <automated>cd /home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller && T1=$(grep -E '^PHASE-6B-TERMINAL:' control/spec/NU-CONSTRUCTIBILITY.md | head -1) && if [ ! -f control/spec/DISPERSION-WINDOW-A.md ]; then echo "PASS (NOT RUN — no DISPERSION-WINDOW-A.md)"; exit 0; fi && T2=$(grep -E '^PHASE-6B-TERMINAL:' control/spec/DISPERSION-WINDOW-A.md | head -1) && if [ "$T1" != "PHASE-6B-TERMINAL: NONE" ]; then echo "PASS (NOT RUN — $T1)"; exit 0; fi && if [ "$T2" != "PHASE-6B-TERMINAL: NONE" ]; then echo "PASS (NOT RUN — $T2)"; exit 0; fi && if ! grep -qE '^\*\*Status:\*\* FROZEN$' control/spec/PRE-REGISTRATION.md; then echo "PASS (NOT RUN — no freeze)"; exit 0; fi && F=control/spec/STAGE1-RESULT.md && S=control/analysis/gbar_stage1.py && test -f $F && test -f $S && test $(wc -l < $F) -ge 70 && for s in '**FREEZE PIN:**' '**Script sha256:**' '## Inherited, not assumed' 'O4' 'FRM-03' 'PRF-03' 'NEC-04' 'NEC-00' 'O2' 'FRM-03 exposure:' 'NEC-04 exposure:' 'first-stage F floor:' 'minimum Δt dispersion:' 'minimum N:' 'target power:' 'clustering level: chain-time' 'git show' '**Command:**' '**Raw output:**' '**Raw output file:**'; do grep -qF "$s" $F || { echo "MISSING: $s"; exit 1; }; done && FS=$(git log --reverse --format=%H -- control/spec/PRE-REGISTRATION.md | head -1) && grep -qF "$FS" $F && H=$(grep -F '**Script sha256:**' $F | grep -oE '[0-9a-f]{64}' | head -1) && test "$H" = "$(sha256sum $S | cut -d' ' -f1)" && python3 -c "
import re,subprocess
t=open('$F').read()
sec=t.split('## 1.')[1].split('## 2.')[0]
blob=subprocess.run(['git','show','$FS:control/spec/PRE-REGISTRATION.md'],capture_output=True,text=True).stdout
for L in ['first-stage F floor:','minimum Δt dispersion:','minimum N:','target power:','clustering level: chain-time']:
    fro=[l.strip() for l in blob.splitlines() if L in l]
    her=[l.strip() for l in sec.splitlines() if L in l]
    assert fro, 'label absent from frozen blob: '+L
    assert any(f in ' '.join(her) or f==h for f in fro for h in her), 'quoted value differs from frozen blob for '+L
sec2=t.split('### 2.2')[1].split('### 2.3')[0]
rows=[l for l in sec2.splitlines() if l.strip().startswith('|') and not re.match(r'^\|[\s:\-|]+\|$',l.strip())]
data=[l for l in rows if 'Quantity' not in l]
assert len(data)>=6, 'stage-1 table rows %d'%len(data)
fr=[l for l in data if 'first-stage F' in l]
assert fr and re.search(r'[0-9]',fr[0]), 'no numeric F'
assert re.search(r'(YES|NO|DESCRIPTIVE — THRESHOLD RULE VOID)',fr[0]), 'no pass cell on F row'
print('frozen quotes and table ok')
" && grep -qE 'PASS|FAIL' $F && test -f control/data/stage1/first-stage.txt && CMD=$(grep -F '**Command:**' $F | head -1 | sed 's/.*\*\*Command:\*\* *//' | tr -d '`') && printf '%s' "$CMD" | grep -qF 'control/analysis/gbar_stage1.py' && diff <(eval "$CMD" 2>&1) control/data/stage1/first-stage.txt && python3 -c "
import re,subprocess
t=open('$F').read()
pre=subprocess.run(['git','show','$FS:control/spec/PRE-REGISTRATION.md'],capture_output=True,text=True).stdout
def tok(s):
    return 'INFEASIBLE' if 'INFEASIBLE' in s else ('FEASIBLE' if 'FEASIBLE' in s else None)
here=[l for l in t.splitlines() if l.startswith('**Split status (copied from the freeze')]
frz=[l for l in pre.splitlines() if '**Split status on the picked venue:**' in l]
assert here and frz, 'split status line missing on one side'
assert '|' not in here[0].split(':**',1)[1] and '<' not in here[0] and '>' not in here[0], 'split status line is still a template: '+here[0]
assert tok(here[0])==tok(frz[0]) and tok(here[0]) is not None, 'split token %r != frozen %r'%(here[0],frz[0])
split=tok(here[0])
sec=t.split('### 2.2a')[1].split('### 2.3')[0]
lines=[l.strip() for l in sec.splitlines() if l.strip().startswith('THRESHOLD CHECK:')]
assert len(lines)>=3, 'need three THRESHOLD CHECK lines, got %d'%len(lines)
def frozen(label):
    m=re.search(re.escape(label)+r'[^0-9\\n]*([0-9]+(?:\\.[0-9]+)?)',pre)
    assert m,'no frozen value for '+label
    return float(m.group(1))
floors={'first-stage F':frozen('first-stage F floor:'),'effective N':frozen('minimum N:'),'Δt dispersion':frozen('minimum Δt dispersion:')}
for l in lines:
    key=[k for k in floors if re.search(k,l)]
    assert key, 'unrecognised THRESHOLD CHECK line: '+l
    nums=re.findall(r'[0-9]+(?:\\.[0-9]+)?',l)
    assert len(nums)>=2, 'line lacks two numbers: '+l
    realized,floor=float(nums[-2]),float(nums[-1])
    assert abs(floor-floors[key[0]])<1e-9, 'quoted floor %g != frozen %g in: %s'%(floor,floors[key[0]],l)
    if 'DESCRIPTIVE' in l:
        assert key[0]=='first-stage F' and split=='INFEASIBLE', 'DESCRIPTIVE misused: '+l
    else:
        want='PASS' if realized>=floor else 'FAIL'
        assert re.search(r'— *'+want+r'\\b',l) or l.rstrip().endswith(want), 'verdict wrong (expected %s): %s'%(want,l)
print('threshold arithmetic + split token ok')
" && { ! grep -qE '\| *NO *\|' $F || grep -qF '**HALT.**' $F; } && SENT=control/.planning/phases/06B-research-venue-and-estimating-mev/.sentinel && test "$SENT/04-1.plank.before" -nt "$SENT/.runstart" && { test ! -e "${F:-/nonexistent}" || ! test "$SENT/04-1.plank.before" -nt "${F:-/nonexistent}"; } && diff -q "$SENT/04-1.plank.before" <(git -C ../plank status --porcelain | grep -v '^??') && diff -q "$SENT/04-1.lean4spec.before" <(git -C ../lean4-spec status --porcelain | grep -v '^??') && diff -q "$SENT/04-1.rootplanning.before" <(git status --porcelain .planning/) && echo PASS</automated>
  </verify>
  <done>The first stage ran on window B against thresholds read out of the frozen blob by `git show` rather than retyped; the F and the validity test are reported before any second-stage output exists; the pinned script's hash is re-derived and the recorded command is re-run and diffed against committed raw output; a missed target produced a HALT.</done>
</task>

<task type="auto">
  <name>Task 2: The second stage sign test, and exactly ONE column-0 terminal verdict</name>
  <files>control/spec/STAGE1-RESULT.md, control/spec/RESEARCH-REGISTER.md</files>
  <read_first>
    - `/home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller/control/spec/STAGE1-RESULT.md` §2 and §2.5 — **if §2.5 HALTed, this task writes only the verdict and the disposition memo**
    - `/home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller/control/spec/PRE-REGISTRATION.md` §3.5, §3.2 (the `NEC-04` branches), §5.1 (the VOID decision rule), §6 (the three strings, indented there)
    - `~/.claude/skills/anti-fishing-replication/SKILL.md` — `halt-procedure.md`'s three artifacts and `rationalizations.md`'s banned phrases
    - `/home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller/control/.planning/ROADMAP.md` — the `Stage gate — EST-03` row
  </read_first>
  <action>
**FIRST: terminal/freeze guard, THEN scope sentinel `TAG=04-2`.**

Append §3–§5 to `control/spec/STAGE1-RESULT.md`.

**`## 3. The second stage — run ONLY if §2.5 did not HALT`**

```
### 3.1 Regression
`ν = β₀ + β₁·λ̂_ARB + <the frozen controls> + u`, on window B, SEs clustered chain-time.
**Hypothesis:** `β₁ > 0` — this is `H2_dnu_dlamMEV_pos`.

### 3.2 Result
| Quantity | Value | Frozen threshold | Pass? |
| `β₁` | | sign > 0 | |
| SE(`β₁`), clustered chain-time | | — | — |
| t / p at the pre-registered level | | <the frozen level> | |

### 3.3 Reproduction
**Command:** <exact>  **Raw output file:** `control/data/stage1/second-stage.txt` (committed)
**Raw output:** <verbatim, identical to the file>

### 3.4 Which `NEC-04` branch this is reported under
<`independent` / `partially derivable` / `NEC-04 UNKNOWN`. Under `partially derivable`, `β₁` is a
**residual** and `sign(residual) ⇏ sign(total)` applies — a positive residual sign does **not**
discharge `H2`, and this section says so.>
```

If §2.5 HALTed, §3 is the single line `NOT RUN — §2.5 HALTed. The second stage was not computed.`
**Do not compute it "for information".**

**`## 4. THE VERDICT`**

Write **exactly one line at column 0**, copied from `PRE-REGISTRATION.md` §6's indented
enumeration:

```
VERDICT: GATE OPENS
VERDICT: WRONG SIGN — H2 REFUTED
VERDICT: NOT IDENTIFIED
```

**Only one of these appears at column 0 in this file, and nothing else in this file may begin a
line with `VERDICT:`.** `06B-05` gates on an anchored grep of exactly this line; a listing of the
admissible set at column 0 would itself open the gate. Where you need to refer to the other
verdicts — in `**Consequence:**` below — write them **indented by two spaces** or inline in prose.

**Under an INFEASIBLE split, `VERDICT: GATE OPENS` is UNRECORDABLE** (`PRE-REGISTRATION.md` §5.1):
the threshold rule is VOID, so the F floor cannot be cleared. The admissible outcomes are
`WRONG SIGN — H2 REFUTED` (a sign is not a threshold) or `NOT IDENTIFIED` with the reason
`SPLIT INFEASIBLE — THRESHOLD RULE VOID`.

Then:

```
**Basis:** <the specific cells in §2.2 / §2.3 / §3.2 that determine it>
**Consequence:**
  - GATE OPENS ⟹ `06B-05` (`EST-04`) runs. Nothing else changes.
  - WRONG SIGN — H2 REFUTED ⟹ `06B-05` does NOT run. `H2_dnu_dlamMEV_pos` is refuted;
    `Theorem34_opposed_signs` and the corrected law's sign both flip, and `06B-06` propagates
    that rather than absorbing it.
  - NOT IDENTIFIED ⟹ `06B-05` does NOT run. Terminal on the `υ` precedent.

**None of the three terminates the project.** Phase 7 runs in every case.
**The gate retains full force.** The softening proposed on 2026-08-09 was WITHDRAWN the same day
— the residual is affine in `Ḡ`, refuted-as-a-free-option by two independent reviewers and by the
orchestrator's own derivation, **PENDING `NEC-00`'s formal carrier** — and may not be cited here
or downstream.
```

**`## 5. Protocol record`**

```
**Re-specifications after seeing output:** NONE | <each one, described, and recorded as a protocol
violation in `RESEARCH-REGISTER.md` §6 IN THIS SAME COMMIT>
**HALTs raised:** <count; for each: the missed target, the disposition memo, and the pivot the
USER enumerated — an analyst-proposed list of alternatives is itself the fishing pattern and is
recorded as one if it happened>
**Banned rationalizations checked:** none of the four phrases enumerated at
`PRE-REGISTRATION.md` §7.2 appears in this file. They are referenced by section, never restated —
restating them here would trip the check they exist to enforce.
```

**This plan carries `control/spec/RESEARCH-REGISTER.md` in its commit paths** precisely so that a
disclosed violation lands in the same commit as the result. Disclosure must never be harder than
concealment. If a HALT occurred, the disposition memo goes here in full and the plan stops at
Task 3 until the **user** enumerates a pivot — **do not enumerate pivot options yourself.**
  </action>
  <acceptance_criteria>
    - Guard behaves as in Task 1.
    - `STAGE1-RESULT.md` contains `## 3.`, `## 4. THE VERDICT`, `## 5. Protocol record`.
    - `grep -c '^VERDICT:'` returns **exactly 1**, and that line matches one of the three frozen strings exactly.
    - If the split status is `INFEASIBLE`, that single line is **not** `VERDICT: GATE OPENS`.
    - `**Basis:**` and `**Consequence:**` present; the consequence block names all three branches **indented**.
    - It contains `None of the three terminates the project.`, `WITHDRAWN the same day`, and `PENDING` beside `NEC-00`.
    - If §3 ran: §3.3 carries a `**Raw output file:**` that exists, and its `**Command:**` re-runs matching that file; §3.4 names one of `independent`, `partially derivable`, `NEC-04 UNKNOWN`; if `partially derivable`, the file contains `sign(residual) ⇏ sign(total)`.
    - If §2.5 HALTed: §3 contains `NOT RUN — §2.5 HALTed.` and no numeric `β₁` value.
    - §5 contains `**Re-specifications after seeing output:**` and `**HALTs raised:**`.
    - The file contains none of `proceeding with caveats`, `exploratory framing`, `one more robustness`, `just to check`.
  </acceptance_criteria>
  <verify>
    <automated>cd /home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller && T1=$(grep -E '^PHASE-6B-TERMINAL:' control/spec/NU-CONSTRUCTIBILITY.md | head -1) && if [ "$T1" != "PHASE-6B-TERMINAL: NONE" ]; then echo "PASS (NOT RUN)"; exit 0; fi && if ! grep -qE '^\*\*Status:\*\* FROZEN$' control/spec/PRE-REGISTRATION.md; then echo "PASS (NOT RUN — no freeze)"; exit 0; fi && F=control/spec/STAGE1-RESULT.md && for s in '## 4. THE VERDICT' '## 5. Protocol record' '**Basis:**' '**Consequence:**' 'None of the three terminates the project.' 'WITHDRAWN the same day' 'PENDING' '**Re-specifications after seeing output:**' '**HALTs raised:**'; do grep -qF "$s" $F || { echo "MISSING: $s"; exit 1; }; done && test $(grep -c '^VERDICT:' $F) -eq 1 && test $(grep -cE '^VERDICT: (GATE OPENS|WRONG SIGN — H2 REFUTED|NOT IDENTIFIED)$' $F) -eq 1 && SS=$(grep -F '**Split status' $F | head -1) && { ! printf '%s' "$SS" | grep -qF 'INFEASIBLE' || ! grep -qxF 'VERDICT: GATE OPENS' $F; } && for b in 'proceeding with caveats' 'exploratory framing' 'one more robustness' 'just to check'; do ! grep -qiF "$b" $F || { echo "BANNED PHRASE: $b"; exit 1; }; done && { ! grep -qF 'partially derivable' $F || grep -qF 'sign(residual) ⇏ sign(total)' $F; } && { grep -qF 'NOT RUN — §2.5 HALTed.' $F || { test -f control/data/stage1/second-stage.txt && C2=$(awk '/^### 3\.3/,/^### 3\.4/' $F | grep -F '**Command:**' | head -1 | sed 's/.*\*\*Command:\*\* *//' | tr -d '`') && diff <(eval "$C2" 2>&1) control/data/stage1/second-stage.txt; }; } && { ! grep -qF 'NOT RUN — §2.5 HALTed.' $F || ! grep -qE '\| *.?β₁.? *\|[^|]*[0-9]' $F; } && SENT=control/.planning/phases/06B-research-venue-and-estimating-mev/.sentinel && test "$SENT/04-2.plank.before" -nt "$SENT/.runstart" && { test ! -e "${F:-/nonexistent}" || ! test "$SENT/04-2.plank.before" -nt "${F:-/nonexistent}"; } && diff -q "$SENT/04-2.plank.before" <(git -C ../plank status --porcelain | grep -v '^??') && diff -q "$SENT/04-2.lean4spec.before" <(git -C ../lean4-spec status --porcelain | grep -v '^??') && diff -q "$SENT/04-2.rootplanning.before" <(git status --porcelain .planning/) && echo PASS</automated>
  </verify>
  <done>The second stage ran only if the first stage passed every frozen target; the file carries exactly one column-0 verdict line drawn from the frozen list, and `GATE OPENS` is unrecordable under an infeasible split; the `NEC-04` branch is named and the recomposition rule applied where it binds; the protocol record shows zero re-specifications or records each in the register in the same commit.</done>
</task>

<task type="checkpoint:decision" gate="blocking">
  <name>Task 3: The gate — present the verdict and its branch consequence, review, commit</name>
  <files>control/spec/STAGE1-RESULT.md, control/spec/RESEARCH-REGISTER.md</files>
  <read_first>
    - `/home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller/control/spec/STAGE1-RESULT.md` §4 and §5
    - `/home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller/control/.planning/ROADMAP.md` — the `Stage gate — EST-03` row and Phase 6b SC4
    - `~/.claude/skills/anti-fishing-replication/SKILL.md` — if a HALT is open, the **user** enumerates the pivot
  </read_first>
  <decision>
**The gate.** The verdict is determined by the data. What the user decides is whether the recorded
verdict is accepted as Stage 1's outcome, and — if a HALT is open — which pivot, if any, is taken.

Only `VERDICT: GATE OPENS` permits `06B-05` (`EST-04`) to run. On the other two, `06B-05` does not
run and the phase proceeds directly to `06B-06`, which back-propagates whichever verdict returned.
  </decision>
  <context>
Three terminal outcomes; **none terminates the project** — Phase 7 runs in every case.

If a HALT is open, **the analyst does not propose the pivot menu.** An analyst-proposed list of
alternatives is itself the fishing pattern. Present the disposition memo and wait.

If the verdict is `WRONG SIGN — H2 REFUTED`, present it as a **result**, with its consequence
named: `Theorem34_opposed_signs` and the corrected law's sign both flip, and `06B-06` propagates
that rather than absorbing it.

If the verdict is `NOT IDENTIFIED`, present it as a **delivered result on the `υ` precedent`** —
that exercise terminated in "this market cannot identify `υ`" and was correctly never reopened.
`06B-06` will write the named alternative-data proposal **after** the verdict is recorded, under
`anti-fishing-replication`, and never as an alternative to recording it.
  </context>
  <options>
    <option id="accept-gate-opens">
      <name>Accept `VERDICT: GATE OPENS` — `06B-05` runs</name>
      <pros>The magnitude can be estimated with a covariance and an admissible band.</pros>
      <cons>If the split was infeasible this branch is unreachable by construction; where reachable, any DESCRIPTIVE label travels into Stage 2.</cons>
    </option>
    <option id="accept-refuted">
      <name>Accept `VERDICT: WRONG SIGN — H2 REFUTED` — `06B-05` does not run</name>
      <pros>A terminal result that settles `H2`, in the negative.</pros>
      <cons>`Theorem34_opposed_signs` and the corrected law's sign flip; propagation is real work for `06B-06` and Phase 7.</cons>
    </option>
    <option id="accept-not-identified">
      <name>Accept `VERDICT: NOT IDENTIFIED` — `06B-05` does not run</name>
      <pros>A delivered result on the `υ` precedent; the alternative-data proposal follows under guard.</pros>
      <cons>`Ḡ` unmeasured; `H2` undischarged, which `NEC-07` records as scaling the loop gain.</cons>
    </option>
    <option id="pivot-after-halt">
      <name>A HALT is open — the user enumerates a pivot</name>
      <pros>Any pivot is locked as a NEW pre-registration with new sha-pinned code, keeping the audit trail intact.</pros>
      <cons>It restarts the freeze: a new `PRE-REGISTRATION.md` commit, a new window if the old one is contaminated, and the old verdict recorded as superseded rather than deleted.</cons>
    </option>
  </options>
  <action>
**FIRST: terminal/freeze guard, THEN scope sentinel `TAG=04-3`.**

Present, in one message: the verdict verbatim, §2.2's first-stage table, §2.3's validity result,
§3.2 if it ran, and the branch consequence. If a HALT is open, present the disposition memo and
**stop** — no menu.

After the user rules, append:

```
## 6. Gate

**Put to the user:** <YYYY-MM-DD>
**Verdict presented:** <verbatim>
**RULING:** <the user's words, quoted, not paraphrased>
**Gate state:** OPEN
**Pivot (if any):** NONE
```

`**Gate state:**` carries exactly one token — `OPEN` or `CLOSED` — with no alternation and no
angle brackets, and it is `OPEN` **iff** §4's single verdict line is `VERDICT: GATE OPENS`.

**Two-step review, THEN commit.** Run **Reality Checker** and **one named specialist, IN
PARALLEL**. The specialist is an econometrics/identification reviewer. Both must verify
**anti-fabrication**: re-run `gbar_stage1.py`, **recompute** at least one figure from
`control/data/stage1/*.txt`, grep the script for hardcoded constants, and confirm the recorded
sha256. Record with **counts and dispositions**:

```
## Review
**Reviewer 1 (always):** Reality Checker — <date>. findings: <B> BLOCKER / <M> MAJOR / <m> MINOR.
  disposition: <resolved N, carried N — each carried item named>.
**Reviewer 2 (named specialist):** <name> — chosen because <reason>. <date>.
  findings: <B> BLOCKER / <M> MAJOR / <m> MINOR. disposition: <...>.
**Anti-fabrication check:** re-ran <command>; recomputed <statistic> = <value>; matches §2.2.
```

Then commit — the script, the raw outputs and any register disclosure travel with the document:

```
cd /home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller
git add control/spec/STAGE1-RESULT.md control/analysis/gbar_stage1.py control/data/stage1/ control/spec/RESEARCH-REGISTER.md
git commit -m "feat(06B): Stage 1 sign test on window B

Closes EST-03. First-stage F and the pre-committed validity test reported before
any second-stage output; estimation on window B, disjoint from the window A that
ranked candidates; thresholds read out of the frozen blob by git show rather than
retyped; exactly one terminal verdict recorded at column 0.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>" -- control/spec/STAGE1-RESULT.md control/analysis/gbar_stage1.py control/data/stage1/ control/spec/RESEARCH-REGISTER.md
git show --name-only --format="" HEAD
```

**Do not modify `control/analysis/gbar_stage1.py` after this commit.** `06B-05` writes a separate
`gbar_stage2.py`; mutating this one would break the reproduction guarantee for the gate-deciding
result.
  </action>
  <acceptance_criteria>
    - Guard behaves as in Task 1.
    - `STAGE1-RESULT.md` contains `## 6. Gate` with `**Put to the user:**`, `**Verdict presented:**`, `**RULING:**`, `**Gate state:**`, `**Pivot (if any):**`; none of those lines contains `<`, `>` or ` | `.
    - `**Gate state:**` matches `^\*\*Gate state:\*\* (OPEN|CLOSED)$` and is `OPEN` **iff** `grep -qxF 'VERDICT: GATE OPENS'` succeeds.
    - `## Review` names `Reality Checker` and a second reviewer, with two `findings:` count lines, two `disposition:` lines, and an `**Anti-fabrication check:**` line naming a re-run command and a recomputed value.
    - `git show --name-only --format="" HEAD` lists only paths under `control/`, including `control/spec/STAGE1-RESULT.md` and `control/analysis/gbar_stage1.py`.
    - The **first-commit** `%ct` of `control/spec/STAGE1-RESULT.md` is `-ge` the first-commit `%ct` of `control/spec/PRE-REGISTRATION.md`. (Ordering is **recorded**, not proven — `%ct` is settable and rebase-mutable; the Dune execution timestamps in `DISPERSION-WINDOW-A.md` §2 are the independent clock.)
    - `sha256sum control/analysis/gbar_stage1.py` still equals the value recorded in §Header — the script was not mutated between Task 1 and the commit.
    - **Scope sentinel:** the three `04-3.*.before` snapshots exist, are **newer than `.sentinel/.runstart`** (taken this run) and **not newer than the artifact** (taken before the edit), and each `diff -q` cleanly against the live value with `??` filtered on both sides — peer trees and the repo-root `.planning/` are **unchanged by this task**, which is not the same as clean.
  </acceptance_criteria>
  <resume-signal>Reply `accept` to record the verdict as presented, or — if a HALT is open — enumerate the pivot you want taken. Do not ask for a menu; the analyst is barred from proposing one.</resume-signal>
  <verify>
    <automated>cd /home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller && T1=$(grep -E '^PHASE-6B-TERMINAL:' control/spec/NU-CONSTRUCTIBILITY.md | head -1) && if [ "$T1" != "PHASE-6B-TERMINAL: NONE" ]; then echo "PASS (NOT RUN)"; exit 0; fi && if ! grep -qE '^\*\*Status:\*\* FROZEN$' control/spec/PRE-REGISTRATION.md; then echo "PASS (NOT RUN — no freeze)"; exit 0; fi && F=control/spec/STAGE1-RESULT.md && for s in '## 6. Gate' '**Put to the user:**' '**Verdict presented:**' '**RULING:**' '**Gate state:**' '**Pivot (if any):**' '## Review' 'Reality Checker' '**Anti-fabrication check:**'; do grep -qF "$s" $F || { echo "MISSING: $s"; exit 1; }; done && test $(awk '/^## 6\. Gate/,0' $F | grep -E '^\*\*(Put to the user|Verdict presented|RULING|Gate state|Pivot \(if any\)):\*\*' | grep -cE '<|>|\| ') -eq 0 && grep -qE '^\*\*Gate state:\*\* (OPEN|CLOSED)$' $F && if grep -qxF 'VERDICT: GATE OPENS' $F; then grep -qxF '**Gate state:** OPEN' $F || { echo "GATE STATE MISMATCH"; exit 1; }; else grep -qxF '**Gate state:** CLOSED' $F || { echo "GATE STATE MISMATCH"; exit 1; }; fi && test $(grep -cE '^ *findings: *[0-9]+ BLOCKER */ *[0-9]+ MAJOR */ *[0-9]+ MINOR' $F) -ge 2 && test $(grep -cE 'disposition:' $F) -ge 2 && H=$(grep -F '**Script sha256:**' $F | grep -oE '[0-9a-f]{64}' | head -1) && test "$H" = "$(sha256sum control/analysis/gbar_stage1.py | cut -d' ' -f1)" && git show --name-only --format="" HEAD | grep -qxF 'control/spec/STAGE1-RESULT.md' && git show --name-only --format="" HEAD | grep -qxF 'control/analysis/gbar_stage1.py' && test $(git show --name-only --format="" HEAD | grep -c .) -eq $(git show --name-only --format="" HEAD | grep -c '^control/') && A=$(git log --reverse --format=%ct -- control/spec/STAGE1-RESULT.md | head -1) && B=$(git log --reverse --format=%ct -- control/spec/PRE-REGISTRATION.md | head -1) && test "$A" -ge "$B" && SENT=control/.planning/phases/06B-research-venue-and-estimating-mev/.sentinel && test "$SENT/04-3.plank.before" -nt "$SENT/.runstart" && { test ! -e "${F:-/nonexistent}" || ! test "$SENT/04-3.plank.before" -nt "${F:-/nonexistent}"; } && diff -q "$SENT/04-3.plank.before" <(git -C ../plank status --porcelain | grep -v '^??') && diff -q "$SENT/04-3.lean4spec.before" <(git -C ../lean4-spec status --porcelain | grep -v '^??') && diff -q "$SENT/04-3.rootplanning.before" <(git status --porcelain .planning/) && echo PASS</automated>
  </verify>
  <done>The verdict and its branch consequence were ruled on by the user in their own words; the gate state is a single token and is `OPEN` if and only if the single column-0 verdict line reads `GATE OPENS`; the review recomputed at least one figure from raw artifacts and confirmed the script hash; the script, raw outputs and any register disclosure are committed together.</done>
</task>

</tasks>

<verification>
1. `grep -c '^VERDICT:'` on `STAGE1-RESULT.md` returns exactly 1 — the enumeration of admissible
   strings lives indented in `PRE-REGISTRATION.md` §6, where `grep -c '^VERDICT:'` returns 0.
2. `GATE OPENS` is unrecordable under an INFEASIBLE split.
3. Thresholds are read from the frozen blob via `git show`, never retyped.
4. Every number is recomputable: the script hash is re-derived and the recorded commands are
   re-run and diffed against committed raw output.
5. Ordering is **recorded** by first-commit `%ct`; the Dune execution timestamps are the
   independent clock. Peer trees and repo-root `.planning/` unchanged by this plan.
</verification>

<success_criteria>
- `EST-03` closed: Stage 1 run on window B against the frozen specification, F reported first,
  validity test alongside, exactly one terminal verdict returned.
- The gate state governs whether `06B-05` runs, and is mechanically tied to the verdict line.
- Any short result produced a HALT and a disposition memo; any pivot was enumerated by the user.
</success_criteria>

<output>
After completion, create
`/home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller/control/.planning/phases/06B-research-venue-and-estimating-mev/06B-04-SUMMARY.md`,
recording the verdict verbatim, the first-stage F and its criterion, the validity-test result, the
gate state, the script sha256, and the first-commit sha + `%ct`.
</output>
