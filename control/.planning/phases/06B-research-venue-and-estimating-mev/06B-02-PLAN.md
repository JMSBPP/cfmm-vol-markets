---
phase: 06B-research-venue-and-estimating-mev
plan: 02
type: execute
wave: 3
depends_on: ["06B-01"]
files_modified:
  - control/spec/DISPERSION-WINDOW-A.md
  - control/analysis/dune_window_a.py
  - control/data/window-a/
autonomous: false
requirements: [EST-02]

must_haves:
  truths:
    - "This plan does not run if `NU-CONSTRUCTIBILITY.md` carries a non-NONE `PHASE-6B-TERMINAL:` line — it exits 0 reporting NOT RUN so the phase still reaches 06B-06."
    - "`Δt` dispersion is a reported NUMBER for every pre-declared candidate, measured on window A only, and every number is recomputable from committed raw output."
    - "Each Dune query carries an execution id AND an execution timestamp, asserted to postdate the research register's first commit — and the document states plainly that both are transcribed by this session, so the re-fetch that authenticates them is a reviewer obligation, not an automated check."
    - "Decision #10 is adjudicated by the structural-econometrics discipline and its ruling recorded."
    - "3–5 candidates are ranked with a NUMERIC dispersion cell; the user picks; the pick line carries no template placeholder."
    - "Insufficient dispersion everywhere is terminal non-identification — no instrument is substituted."
  artifacts:
    - path: "control/spec/DISPERSION-WINDOW-A.md"
      provides: "Measured Δt dispersion per candidate on window A, the Decision #10 ruling, the ranked candidate table, and the user's venue pick"
      min_lines: 100
      contains: "measured on window A"
    - path: "control/analysis/dune_window_a.py"
      provides: "The pinned, sha256-recorded extraction script that produced every number in this plan"
      min_lines: 20
  key_links:
    - from: "control/spec/DISPERSION-WINDOW-A.md"
      to: "control/data/window-a/*.csv"
      via: "every reported statistic reconciles against a committed raw result set with an asserted row count"
      pattern: "control/data/window-a/"
    - from: "control/spec/DISPERSION-WINDOW-A.md"
      to: "control/spec/RESEARCH-REGISTER.md"
      via: "the Dune execution timestamp is asserted to postdate the register's first commit — the independent measurement clock"
      pattern: "Execution timestamp:"
---

<objective>
Measure `Δt` dispersion **as a reproducible number** on window A over the ratified candidate set,
adjudicate Decision #10, rank the candidates, and take the user's venue pick.

Purpose: `EST-02`. `ROADMAP.md` Phase 6b SC2: the identification lever is **validated before use,
on measured dispersion, not asserted**. `06B-CONTEXT.md`: "**The user picks. The freeze follows
the pick.** This is a checkpoint inside the phase, not a research deliverable that proceeds
automatically."

Output: `control/spec/DISPERSION-WINDOW-A.md`, `control/analysis/dune_window_a.py`,
`control/data/window-a/*.csv`.
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
@/home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller/control/spec/POOL-ALGEBRA.md
@/home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller/control/spec/NU-CONSTRUCTIBILITY.md
@/home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller/control/spec/RESEARCH-REGISTER.md

**Path glossary.** `WT` = `/home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller`. `PLANK` =
`/home/jmsbpp/cfmms-playground/cfmm-wt/plank` (**READ-ONLY**). `LEAN` =
`/home/jmsbpp/cfmms-playground/cfmm-wt/lean4-spec` (**READ-ONLY**).

**TERMINAL-BRANCH GUARD — the first thing every task does, before the sentinel.**

```
cd /home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller
T=$(grep -E '^PHASE-6B-TERMINAL:' control/spec/NU-CONSTRUCTIBILITY.md | head -1)
if [ "$T" != "PHASE-6B-TERMINAL: NONE" ]; then echo "06B-02 NOT RUN — $T"; exit 0; fi
```

`ROADMAP.md` requires the phase to reach `06B-06` on **every** branch. A hard failure at wave 3
on the branch the phase was designed to deliver would defeat that. Exit `0` and report `NOT RUN`.

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

**As the FIRST action of every task**, with `TAG` = `02-1`, `02-2`, `02-3`:

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
- `gsd-tools commit --files` commits the entire staged index. Use `git commit -- <paths>`; assert
  paths with `git show --name-only --format="" HEAD`, never `--stat`.
- **WINDOW A ONLY.** Window B is not queried, not summarized, not peeked at.
- **No pruning.** The ratified sets are measured **in full**.

**Data route: Dune MCP** (`06B-CONTEXT.md`). The plank events→subgraph layer is **not** the route.
</context>

<inherited>
**Phases 1, 2, 3 and 6a are UNEXECUTED at plan time.** `DISPERSION-WINDOW-A.md` opens with an
`## Inherited, not assumed` section naming:

- **O4 — `σ` versus `σ²`.** Its *dimensional* content is **SETTLED BY `POOL-ALGEBRA.md` §3.1**
  where that check returned `PASS`; quote the check's line. The broader `NOT-05` notation ledger
  remains **UNRESOLVED at plan time**. Any statistic on a volatility series states which object it
  carries.
- **The event-clock ruling** (Phase 2 `FRM-03`). **UNRESOLVED.** `Δt` is **block**-clock; `ν` and
  `λ_ARB` are **swap**-clock. Every statistic states its clock. Phase 2 SC3 names this phase's
  identification as a result at risk, and that warning is reproduced here.
- **The hypothesis discipline** (Phase 3 `PRF-03`, `PRF-06`). **UNWRITTEN.**
- **`NEC-04`'s coupling verdict** (Phase 6a). **UNRESOLVED.** It changes what is being identified,
  not what `Δt` dispersion is; the dependence is stated, not assumed away.
- **`NEC-00`'s affine-in-`Ḡ` verdict** (Phase 6a). **PENDING `NEC-00`'s formal carrier** —
  refuted-as-a-free-option by two independent reviewers and by the orchestrator's own derivation,
  but not machine-checked; the Gates table lists it **NOT REACHED**.
- **The review register** (Phase 1 `HND-05`) does not exist; the artifact carries its own
  `## Review`.
</inherited>

<tasks>

<task type="auto">
  <name>Task 1: Measure Δt dispersion on window A — raw output committed, execution ids recorded</name>
  <files>control/spec/DISPERSION-WINDOW-A.md, control/analysis/dune_window_a.py, control/data/window-a/</files>
  <read_first>
    - `/home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller/control/spec/NU-CONSTRUCTIBILITY.md` §4 — the `PHASE-6B-TERMINAL:` line (the guard)
    - `/home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller/control/spec/POOL-ALGEBRA.md` §3.1, §4.1, §4.2, §4.4, §5, §7 — the dimensional check, the **ratified** sets, the window boundary, the venue-independent thresholds
    - `/home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller/control/spec/ECONOMETRICS-DESIGN.md` lines 65–98 — the first stage regresses `λ_ARB` on **`√Δt`**, not raw `Δt`
    - `/home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller/control/.planning/REQUIREMENTS.md` — `EST-02`, `EST-07`, `EST-09`
    - `/home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller/control/spec/RESEARCH-REGISTER.md` §5 — the instrument-selection rule
  </read_first>
  <action>
**FIRST: the terminal-branch guard. THEN the scope sentinel with `TAG=02-1`.**

Write the extraction script at the pinned path
`control/analysis/dune_window_a.py`. It takes the ratified chain list and the window A boundary,
runs the Dune queries through the Dune MCP, writes one raw result set per chain to
`control/data/window-a/<chain>.csv`, and computes the statistics from those CSVs — **never from a
transcription**. Record its hash: `sha256sum control/analysis/dune_window_a.py`.

Create `control/spec/DISPERSION-WINDOW-A.md`.

Header:

```
# Δt DISPERSION — WINDOW A

**Requirement:** EST-02
**Measured:** <YYYY-MM-DD>
**Pins:** `control/spec/RESEARCH-REGISTER.md @ <first-commit sha>`,
`control/spec/POOL-ALGEBRA.md @ <first-commit sha>`
**Extraction script:** `control/analysis/dune_window_a.py`
**Script sha256:** <the 64-hex output of sha256sum>
**Window:** window A only, as ratified at `POOL-ALGEBRA.md` §4.4 — `[<start>, <end>)`.
**Window B was not queried.**
**Candidate set measured IN FULL.** No candidate was dropped before §3's ranking.
**O4 dimensional content:** <quote `POOL-ALGEBRA.md` §3.1's `DIMENSIONAL CHECK:` line verbatim>
```

Then `## Inherited, not assumed` (the six items).

**`## 1. What is measured, and on which clock`** — the instrument is **`√Δt`**, not raw `Δt`.
Report both, labelled. State in a bolded line that `Δt` is **block**-clock, and reproduce Phase 2
SC3's warning verbatim.

**`## 2. Per-candidate dispersion (window A)`** — one `### 2.N — <chain>` block per ratified
candidate:

```
**Query id:** <the Dune query id>
**Execution id:** <the Dune execution id returned by the run>
**Execution timestamp:** <the execution timestamp returned by Dune, ISO-8601 UTC>
**Query text:**
```sql
<the exact SQL executed — verbatim>
```
**Raw result set:** `control/data/window-a/<chain>.csv`
**Rows returned:** <N>
**Row-count reconciliation:** `wc -l < control/data/window-a/<chain>.csv` minus the header = <N>
— matches `**Rows returned:**`.
**Window A coverage:** <first block, last block, calendar dates>

| Series | N | mean | sd | CV = sd/mean | IQR | p05 | p50 | p95 | share ≠ modal |
|---|---|---|---|---|---|---|---|---|---|
| `Δt` (s) | | | | | | | | | |
| `√Δt` (s^½) | | | | | | | | | |

**Source of the variation:** <missed slots / congestion / reorgs / sequencer cadence — the
MECHANISM, with evidence. Do NOT compute a σ-channel correlation here; see §3.>
**Algebra Integral deployment depth:** <live Integral pools, TVL, swap count on window A, each
with its query id and execution id>
```

**Anti-fabrication is a hard requirement and it is enforced structurally, not by exhortation.**
Every number in the table must be computed by `dune_window_a.py` from the committed CSV. The
CSV is committed. The row count is reconciled against `wc -l`. The **execution id** and
**execution timestamp** come from Dune and are not writable by this session. A reviewer will
re-run the script against the CSVs and diff.

**The execution timestamp is a BETTER clock than `git %ct`, and it is NOT non-forgeable.** State
that honestly in the document. `git %ct` is settable via `GIT_COMMITTER_DATE`, rewritten by
`amend`/`rebase`, and this branch is destined for a PR→`develop` rebase; it orders *file commits*,
not *measurements*. The execution timestamp at least orders the measurement. But **everything this
plan's automated verify can check is internal** — row count against `wc -l`, sha against disk,
timestamp against a git date — so a typed timestamp beside a hand-written CSV would pass. Write,
verbatim:

```
**Forgeability, stated plainly.** The execution id and execution timestamp are transcribed from
Dune by this session. No automated check in this plan re-fetches them, so they are **not
self-authenticating**. What makes them meaningful is the two-step review: the reviewer re-fetches
each `**Execution id:**` through `mcp__dune__getExecutionResults` and confirms the returned rows
and timestamp against §2. Until that review runs, treat every number here as **transcribed, not
verified**.
```

Assert the ordering anyway, and record the comparison: **every execution timestamp postdates the
research register's FIRST commit**
(`git log --reverse --format=%cI -- control/spec/RESEARCH-REGISTER.md | head -1`). That records
that the instrument menu was closed before anything was measured.

**`## 3. Pool-axis measurement (φ dispersion)`** — per chain, over the ratified pool set, realized
`φ` dispersion on window A, same provenance requirements. Prefix verbatim:

```
This is the POOL axis and it buys **exactly zero instrument variation** — every pool on a chain
sees the same cadence. `φ` dispersion decides whether the fee schedule has anything to move
against, not whether the instrument is strong.
```

**`## 4. What was NOT measured, and why`**

- **Window B** — untouched by construction.
- **The σ-channel correlation (`EST-08`'s statistic)** — deliberately **NOT** computed on window
  A. The user picks partly on the identification-threat column, so computing the threat statistic
  before the pick would make the pick an argmax over the very quantity `EST-08` later tests —
  the same winner's-curse mechanism as the F, one level up. §2's `Source of the variation` field
  therefore carries a **mechanism**, not a number. `EST-08`'s statistic is computed on window B
  under the frozen specification, and if any σ-channel statistic is computed before the pick, the
  `EST-08` statistic inherits the **DESCRIPTIVE / VOID** labelling that `EST-09` applies to the F.
- Any candidate whose query failed is reported `NOT MEASURED — <reason>` and **stays in the
  ranking with that cell**; it is not silently dropped.
  </action>
  <acceptance_criteria>
    - If `NU-CONSTRUCTIBILITY.md`'s `PHASE-6B-TERMINAL:` line is not `NONE`, the verify passes trivially with `NOT RUN` and no file is created.
    - Otherwise: `control/spec/DISPERSION-WINDOW-A.md` ≥ 100 lines; `control/analysis/dune_window_a.py` exists; `control/data/window-a/` contains ≥ 1 `.csv`.
    - The recorded `**Script sha256:**` **equals** `sha256sum control/analysis/dune_window_a.py`.
    - It contains `## Inherited, not assumed`, the names `O4`, `FRM-03`, `PRF-03`, `NEC-04`, `NEC-00`, and `SETTLED BY` or the quoted `DIMENSIONAL CHECK:` line.
    - It contains `Window B was not queried.`, `Candidate set measured IN FULL.`, and pins for both upstream files with 7+ hex shas.
    - The number of `### 2.` blocks equals the ratified chain count (3–5).
    - `**Query id:**`, `**Execution id:**`, `**Execution timestamp:**`, `**Query text:**`, `**Raw result set:**`, `**Rows returned:**`, `**Row-count reconciliation:**` each appear ≥ once per `### 2.` block.
    - Every `**Raw result set:**` path exists on disk, and for each, `wc -l` minus 1 equals the `**Rows returned:**` value in the same block.
    - Every `**Execution timestamp:**` parses as ISO-8601 and is **later** than `git log --reverse --format=%cI -- control/spec/RESEARCH-REGISTER.md | head -1`.
    - The file contains `**Forgeability, stated plainly.**`, `not self-authenticating`, `mcp__dune__getExecutionResults`, and `transcribed, not verified` — the non-forgeability claim is withdrawn in writing, and the re-fetch obligation is placed on the reviewer, where it can actually be discharged.
    - Every `### 2.` block has a `| \`Δt\` (s) |` row and a `| \`√Δt\`` row, each with ≥ 5 numeric cells.
    - `**Source of the variation:**` appears once per block and contains **no** numeric correlation: no match for `(corr|rho|ρ|r) *[:=] *[-0-9.]`.
    - §3 contains `exactly zero instrument variation`; §4 contains `window B` and the literal string `argmax over the very quantity`.
    - **Scope sentinel:** the three `02-1.*.before` snapshots exist, are **newer than `.sentinel/.runstart`** (taken this run) and **not newer than the artifact** (taken before the edit), and each `diff -q` cleanly against the live value with `??` filtered on both sides — peer trees and the repo-root `.planning/` are **unchanged by this task**, which is not the same as clean.
  </acceptance_criteria>
  <verify>
    <automated>cd /home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller && T=$(grep -E '^PHASE-6B-TERMINAL:' control/spec/NU-CONSTRUCTIBILITY.md | head -1) && if [ "$T" != "PHASE-6B-TERMINAL: NONE" ]; then echo "PASS (NOT RUN — $T)"; exit 0; fi && F=control/spec/DISPERSION-WINDOW-A.md && S=control/analysis/dune_window_a.py && test -f $F && test -f $S && test $(wc -l < $F) -ge 100 && test $(ls control/data/window-a/*.csv 2>/dev/null | wc -l) -ge 1 && H=$(grep -F '**Script sha256:**' $F | grep -oE '[0-9a-f]{64}' | head -1) && test "$H" = "$(sha256sum $S | cut -d' ' -f1)" && for s in '## Inherited, not assumed' 'O4' 'FRM-03' 'PRF-03' 'NEC-04' 'NEC-00' 'Window B was not queried.' 'Candidate set measured IN FULL.' '**Forgeability, stated plainly.**' 'not self-authenticating' 'mcp__dune__getExecutionResults' 'transcribed, not verified' '**Query id:**' '**Execution id:**' '**Execution timestamp:**' '**Query text:**' '**Raw result set:**' '**Rows returned:**' '**Row-count reconciliation:**' '**Source of the variation:**' 'exactly zero instrument variation' 'DIMENSIONAL CHECK:' 'argmax over the very quantity'; do grep -qF "$s" $F || { echo "MISSING: $s"; exit 1; }; done && grep -qE 'RESEARCH-REGISTER\.md @ [0-9a-f]{7,}' $F && grep -qE 'POOL-ALGEBRA\.md @ [0-9a-f]{7,}' $F && C=$(grep -c '^### 2\.' $F) && test $C -ge 3 && test $C -le 5 && for L in '**Query id:**' '**Execution id:**' '**Execution timestamp:**' '**Raw result set:**' '**Rows returned:**' '**Row-count reconciliation:**'; do test $(grep -cF "$L" $F) -ge $C || { echo "PROVENANCE SHORT: $L"; exit 1; }; done && REG=$(git log --reverse --format=%cI -- control/spec/RESEARCH-REGISTER.md | head -1) && python3 -c "
import re,sys,os,datetime
t=open('$F').read()
reg=datetime.datetime.fromisoformat('$REG'.replace('Z','+00:00'))
ts=re.findall(r'\*\*Execution timestamp:\*\* *([0-9T:+\-\.Z ]+)',t)
assert len(ts)>=$C, 'timestamps short'
for x in ts:
    d=datetime.datetime.fromisoformat(x.strip().replace('Z','+00:00'))
    assert d>reg, 'execution %s not after register commit %s'%(x,reg)
rows=re.findall(r'\*\*Raw result set:\*\* *\`([^\`]+)\`[\s\S]*?\*\*Rows returned:\*\* *([0-9]+)',t)
assert len(rows)>=$C, 'row pairs short'
for p,n in rows:
    assert os.path.isfile(p), 'missing csv '+p
    assert sum(1 for _ in open(p))-1==int(n), 'row mismatch '+p
print('provenance ok')
" && test $(grep -cF '| `Δt` (s) |' $F) -ge $C && test $(grep -cF '| `√Δt`' $F) -ge $C && test $(grep -F '| `Δt` (s) |' $F | grep -cE '([0-9]+\.?[0-9]*[^|]*\|){5}') -ge $C && test $(grep -F '**Source of the variation:**' $F | grep -cE '(corr|rho|ρ|r) *[:=] *[-0-9.]') -eq 0 && SENT=control/.planning/phases/06B-research-venue-and-estimating-mev/.sentinel && test "$SENT/02-1.plank.before" -nt "$SENT/.runstart" && { test ! -e "${F:-/nonexistent}" || ! test "$SENT/02-1.plank.before" -nt "${F:-/nonexistent}"; } && diff -q "$SENT/02-1.plank.before" <(git -C ../plank status --porcelain | grep -v '^??') && diff -q "$SENT/02-1.lean4spec.before" <(git -C ../lean4-spec status --porcelain | grep -v '^??') && diff -q "$SENT/02-1.rootplanning.before" <(git status --porcelain .planning/) && echo PASS</automated>
  </verify>
  <done>Every candidate carries `Δt` and `√Δt` statistics on window A computed by a pinned, hash-recorded script from committed raw result sets whose row counts reconcile; each query carries a Dune execution id and an execution timestamp asserted to postdate the research register's first commit; the identification-threat field is a mechanism, not a statistic; nothing was dropped and window B was not touched.</done>
</task>

<task type="auto">
  <name>Task 2: Adjudicate Decision #10 under the structural-econometrics discipline, and rank</name>
  <files>control/spec/DISPERSION-WINDOW-A.md</files>
  <read_first>
    - `/home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller/control/spec/DISPERSION-WINDOW-A.md` §§1–4
    - `~/.claude/skills/structural-econometrics/SKILL.md` — the Reiss & Wolak three-stage framework and its mandatory-questioning rule
    - `/home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller/control/.planning/REQUIREMENTS.md` — `EST-02` (Decision #10 deferred here, NOT closed in the doc layer) and `EST-08`
    - `/home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller/control/spec/POOL-ALGEBRA.md` §4.5 (single-chain vs set) and §5 (the venue-independent thresholds already fixed)
    - `/home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller/control/spec/RESEARCH-REGISTER.md` §2.4
  </read_first>
  <action>
**FIRST: terminal guard; THEN scope sentinel `TAG=02-2`.**

Append §5–§7 to `control/spec/DISPERSION-WINDOW-A.md`.

**`## 5. Decision #10 — `Δt` exogenous or endogenous`** — deferred to this phase and never closed
in the doc layer. Adjudicated by the **`structural-econometrics` discipline**:

```
### 5.1 The economic model
<agents, environment, primitives, equilibrium; is `Δt` a choice variable of any agent? Cite the
source for each concept per the skill's learning-plugin rule.>

### 5.2 The stochastic model
<unobserved heterogeneity / agent uncertainty / measurement error — which would make `Δt`
correlate with the second-stage error.>

### 5.3 Steps to estimation
<the exclusion restriction written out formally; the rank condition; what falsifies each.>

### 5.4 RULING
Decision #10 RULING: EXOGENOUS | ENDOGENOUS | CONDITIONALLY EXOGENOUS — <the condition>
**Basis:** <the stage that decides it>
**What this does NOT close:** <name it>
```

**Three things the ruling must confront by name:**

1. **The clean-exclusion argument is structural but not sufficient.** `Δt` does not appear in
   `φ = φ̄ + volSurcharge(σ)·gate(ν)` — true. But `Δt`'s realized variation comes from missed
   slots, congestion and reorgs, which **cluster with volatility events**, and `σ` enters `φ`
   directly, so `Δt` can correlate with the second-stage error **through the `σ` channel**
   (`EST-08`). Per §2's mechanism fields, say for each candidate whether the channel is live.
   **State it as a mechanism; the statistic is computed on window B under the freeze** (§4).
2. **Conditioning on `σ` is not a free fix**, because `σ` is itself a determinant of `φ`.
3. **The two-clock problem.** `Δt` is block-clock; `ν` and `λ_ARB` are swap-clock. Whether a
   block-clock instrument is admissible against swap-clock outcomes is Phase 2 `FRM-03`'s ruling,
   **UNEXECUTED**. State the dependence; do not assume it resolves favourably.

**`## 6. Ranked candidates`** — 3–5 rows, **every cell filled**:

| Rank | Chain | `Δt` dispersion (window A) — the NUMBER | `√Δt` dispersion | Algebra Integral deployment depth | Specific identification threat (mechanism) | Split feasible on window B? |

- The `Δt dispersion — the NUMBER` cell is **numeric**: it carries the statistic named in
  `POOL-ALGEBRA.md` §5's `minimum Δt dispersion` line, as a number with units. Words like
  `moderate`, `low`, `high` or `TBD` are **not** admissible — the criterion greps for a digit.
- `Specific identification threat` is chain-specific and mechanistic; "weak instrument" alone is
  a category, not a threat statement.
- `Split feasible on window B?` is `YES` or `NO — <reason>`. A `NO` triggers `EST-09`'s fallback:
  the first-stage F is labelled **DESCRIPTIVE** and the threshold rule **VOID**.

Below the table: the ranking criterion written out, and — **as a numeric comparison, not prose** —
a `### 6.1 Floor comparison` block with one line per candidate in exactly this form:

```
FLOOR CHECK: <chain> — dispersion <value> vs minimum Δt dispersion <floor> — CLEARS | BELOW FLOOR
```

The floor is read from `POOL-ALGEBRA.md` §5 **at its locked blob** (see §5a), not from the working
tree. Close with `CANDIDATES CLEARING THE FLOOR: <k> of <n>` and the confirmation that **no
candidate was removed**. If `<k>` is 0, §7's terminal branch is the outcome and the checkpoint
presents it as such.

**`## 7. The terminal branch, stated before the user sees the ranking`** — verbatim:

```
**If no candidate clears the pre-registered `minimum Δt dispersion` floor, that is terminal
non-identification** (`06B-CONTEXT.md`; `ROADMAP.md` Phase 6b SC2). The `υ` precedent applies: a
delivered result, never a prompt to re-specify. **No instrument substitution is permitted** — the
menu was closed at `RESEARCH-REGISTER.md` §5.1 before any of these numbers existed.

"Sufficient" is **not** defined here and **not** redefined against these numbers. The floor was
pre-registered at `POOL-ALGEBRA.md` §5 in wave 2, before any dispersion existed. Changing it now
is a re-specification: it requires a HALT, a disposition memo, and a pivot the **user**
enumerates, and it is recorded in `RESEARCH-REGISTER.md` §6.
```

**If any result is short of its target, `anti-fishing-replication` fires**: HALT, disposition
memo, wait for the user to enumerate a pivot. No caveats, no extra robustness, no swapped
statistic.
  </action>
  <acceptance_criteria>
    - Guard: trivially passes on a terminal branch.
    - `DISPERSION-WINDOW-A.md` contains `## 5. Decision #10` with `### 5.1` … `### 5.4`.
    - Exactly one line matches `^Decision #10 RULING: (EXOGENOUS|ENDOGENOUS|CONDITIONALLY EXOGENOUS)`.
    - §5 contains `cluster with volatility events`, `not a free fix`, `two-clock`, `**What this does NOT close:**`.
    - §6's table has 3–5 data rows and **7 columns in EVERY row** (not only the header); no cell is empty.
    - **Every** §6 row's `Δt dispersion` cell contains a digit.
    - Every §6 row's `Split feasible on window B?` cell contains `YES` or `NO —`.
    - `### 6.1 Floor comparison` exists with one `FLOOR CHECK:` line per §6 row, each ending `CLEARS` or `BELOW FLOOR`, and a `CANDIDATES CLEARING THE FLOOR: <k> of <n>` line whose `<n>` equals the §6 row count.
    - **The comparison is arithmetic, not prose:** each `FLOOR CHECK:` line is parsed and its `CLEARS`/`BELOW FLOOR` verdict recomputed from the two numbers it carries; the floor is read from `POOL-ALGEBRA.md` at its **locked blob sha** recorded in `06B-01` §7, and must equal the floor quoted here.
    - §6 states the ranking criterion and contains `no candidate was removed`.
    - §7 contains `terminal non-identification`, `No instrument substitution is permitted`, `not redefined against these numbers`, and `RESEARCH-REGISTER.md` §6.
  </acceptance_criteria>
  <verify>
    <automated>cd /home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller && T=$(grep -E '^PHASE-6B-TERMINAL:' control/spec/NU-CONSTRUCTIBILITY.md | head -1) && if [ "$T" != "PHASE-6B-TERMINAL: NONE" ]; then echo "PASS (NOT RUN — $T)"; exit 0; fi && F=control/spec/DISPERSION-WINDOW-A.md && for s in '## 5. Decision #10' '### 5.1' '### 5.2' '### 5.3' '### 5.4' '**What this does NOT close:**' 'cluster with volatility events' 'not a free fix' 'two-clock' '## 6. Ranked candidates' 'no candidate was removed' 'terminal non-identification' 'No instrument substitution is permitted' 'not redefined against these numbers'; do grep -qF "$s" $F || { echo "MISSING: $s"; exit 1; }; done && test $(grep -cE '^Decision #10 RULING: (EXOGENOUS|ENDOGENOUS|CONDITIONALLY EXOGENOUS)' $F) -eq 1 && python3 -c "
import re,sys
t=open('$F').read()
sec=t.split('## 6. Ranked candidates')[1].split('## 7.')[0]
rows=[l for l in sec.splitlines() if l.strip().startswith('|')]
data=[l for l in rows if not re.match(r'^\|[\s:\-|]+\|$', l.strip()) and not l.strip().lower().startswith('| rank')]
assert 3<=len(data)<=5, 'row count %d'%len(data)
for l in data:
    cells=[c.strip() for c in l.strip().strip('|').split('|')]
    assert len(cells)==7, 'columns %d in: %s'%(len(cells),l)
    assert all(c and c!='—' for c in cells), 'empty cell in: %s'%l
    assert re.search(r'[0-9]', cells[2]), 'non-numeric dispersion cell: %s'%cells[2]
    assert re.match(r'^(YES|NO)\\b', cells[6]) and (cells[6].startswith('YES') or re.match(r'^NO *[—-]', cells[6])), 'split cell: %s'%cells[6]
sec61=t.split('### 6.1 Floor comparison')[1] if '### 6.1 Floor comparison' in t else ''
assert sec61, 'no floor comparison block'
import subprocess
blob=subprocess.run(['git','log','--reverse','--format=%H','--','control/spec/POOL-ALGEBRA.md'],capture_output=True,text=True).stdout.split()[0]
pool=subprocess.run(['git','show',blob+':control/spec/POOL-ALGEBRA.md'],capture_output=True,text=True).stdout
mf=re.search(r'minimum .t dispersion:[^0-9\\n]*([0-9]+(?:\\.[0-9]+)?)',pool)
assert mf, 'no floor in the locked POOL-ALGEBRA blob'
floor=float(mf.group(1))
lines=[l for l in sec61.splitlines() if l.strip().startswith('FLOOR CHECK:')]
assert len(lines)==len(data), 'floor lines %d != candidate rows %d'%(len(lines),len(data))
k=0
for l in lines:
    nums=re.findall(r'[0-9]+(?:\\.[0-9]+)?',l)
    assert len(nums)>=2, 'floor line lacks two numbers: '+l
    d,f2=float(nums[-2]),float(nums[-1])
    assert abs(f2-floor)<1e-9, 'quoted floor %g != locked floor %g'%(f2,floor)
    verdict='CLEARS' if d>=floor else 'BELOW FLOOR'
    assert verdict in l, 'floor verdict wrong for: '+l
    k+= (verdict=='CLEARS')
mk=re.search(r'CANDIDATES CLEARING THE FLOOR: *([0-9]+) of ([0-9]+)',sec61)
assert mk and int(mk.group(1))==k and int(mk.group(2))==len(data), 'floor tally mismatch'
print('ranking table + floor arithmetic ok')
" && SENT=control/.planning/phases/06B-research-venue-and-estimating-mev/.sentinel && test "$SENT/02-2.plank.before" -nt "$SENT/.runstart" && { test ! -e "${F:-/nonexistent}" || ! test "$SENT/02-2.plank.before" -nt "${F:-/nonexistent}"; } && diff -q "$SENT/02-2.plank.before" <(git -C ../plank status --porcelain | grep -v '^??') && diff -q "$SENT/02-2.lean4spec.before" <(git -C ../lean4-spec status --porcelain | grep -v '^??') && diff -q "$SENT/02-2.rootplanning.before" <(git status --porcelain .planning/) && echo PASS</automated>
  </verify>
  <done>Decision #10 carries one recorded ruling from the structural-econometrics three-stage discipline, confronting the σ channel as a mechanism, the non-fix of conditioning on σ, and the two-clock dependence on an unexecuted Phase 2; the ranking table is 3–5 rows × 7 columns with a numeric dispersion cell in every row, compared against a floor that was pre-registered before the numbers existed, with nothing removed.</done>
</task>

<task type="checkpoint:decision" gate="blocking">
  <name>Task 3: THE VENUE PICK — the user chooses from the ranked candidates, or the phase closes</name>
  <files>control/spec/DISPERSION-WINDOW-A.md</files>
  <read_first>
    - `/home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller/control/spec/DISPERSION-WINDOW-A.md` §6 and §7
    - `/home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller/control/spec/POOL-ALGEBRA.md` §4.4 (window boundary), §4.5 (single-chain vs set), §5 (the pre-registered floor)
    - `/home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller/control/.planning/phases/06B-research-venue-and-estimating-mev/06B-CONTEXT.md` — "Venue and chain selection" and "Winner's-curse resolution"
    - `~/.claude/skills/anti-fishing-replication/SKILL.md`
  </read_first>
  <decision>
**Which venue (chain or chain SET, plus pool set) this phase estimates on — or that no candidate
clears the pre-registered floor and the phase closes on terminal non-identification.**

The pick is the input to the freeze: `06B-03` writes the pre-registration against it.
  </decision>
  <context>
`06B-CONTEXT.md`: 3–5 ranked candidates, each carrying measured `Δt` dispersion as a number,
Algebra deployment depth, and its specific identification threat. **The user picks. The freeze
follows the pick.**

**Why the pick creates an obligation.** Ranking by measured dispersion means dispersion was
measured **before** the freeze — `EST-09`'s selection-then-test problem. An F reported on an
argmax-selected sample is upward-biased. The split-sample is therefore **MANDATORY**: window A
ranked, the user picks, the freeze happens, estimation runs on window B. Where the split is
infeasible, the F is labelled **DESCRIPTIVE** and the threshold rule **VOID**.

**Cluster count matters to the pick.** Per `POOL-ALGEBRA.md` §4.5: with a **single chain**,
`√Δt` has no cross-sectional variation, the chain-time cluster reduces to **G = 1**, and
cluster-robust inference at chain-time is invalid. A pick of ≥ 2 chains preserves it. If the user
picks one, the design is recorded as a **single-cluster time series** with the cost stated.

**No instrument substitution.** "None of these has enough dispersion" is terminal
non-identification, not a new instrument.
  </context>
  <options>
    <option id="pick-set">
      <name>Pick a SET of ≥ 2 chains</name>
      <pros>Preserves cross-sectional variation in `√Δt`; chain-time clustering with G ≥ 2 remains meaningful.</pros>
      <cons>Heterogeneous venues; the pooled specification must justify combining them, and `EST-08`'s threat may differ across members.</cons>
    </option>
    <option id="pick-single">
      <name>Pick a single chain</name>
      <pros>Homogeneous venue; the fee machinery and the threat mechanism are one story.</pros>
      <cons>G = 1: cluster-robust inference at chain-time is invalid and the design is a single-cluster time series. The cost must be recorded and carried into the freeze.</cons>
    </option>
    <option id="terminal-non-identification">
      <name>No candidate clears the pre-registered floor — terminal non-identification</name>
      <pros>A delivered result on the `υ` precedent; `06B-06` still back-propagates it.</pros>
      <cons>`Ḡ` unmeasured; `H2` undischarged, which `NEC-07` records as scaling the on-chain loop gain.</cons>
    </option>
  </options>
  <action>
**FIRST: terminal guard; THEN scope sentinel `TAG=02-3`.**

Present §6's ranked table **as measured**, with §7's terminal branch and §4.5's cluster-count
consequence in the same message. Do **not** recommend a candidate. Do **not** attach an expected
first-stage F to any row.

After the user rules, append:

```
## 8. The pick

**Put to the user:** <YYYY-MM-DD>
**Options presented:** <the ranked list, verbatim as presented>
**RULING:** <the user's words, quoted, not paraphrased>
**Picked venue:** <actual chain name(s)> / <actual pool identifiers>
**Cluster count G:** <integer>
**Cluster consequence:** <"G >= 2, chain-time clustering retained" or "G = 1, single-cluster time
series; cluster-robust inference at chain-time is invalid and the freeze records what that
costs">
**Split-sample status:** window A = [<actual dates>) ranked; window B = [<actual dates>)
reserved and untouched. FEASIBLE
**Consequence:** <what runs next>
```

**Every field must have its angle-bracket placeholders replaced and carry no ` | ` alternation.**
A line still reading `<chain> / <pool set>` or `FEASIBLE | INFEASIBLE` is an unedited template and
fails the criteria.

If the outcome is terminal, `**Picked venue:**` reads exactly
`NONE — TERMINAL NON-IDENTIFICATION`, and additionally write the line

```
PHASE-6B-TERMINAL: VENUE NONE — TERMINAL NON-IDENTIFICATION
```

so `06B-03`, `06B-04` and `06B-05` can read the terminal condition off this file the same way they
read `NU-CONSTRUCTIBILITY.md`'s. If the outcome is not terminal, write
`PHASE-6B-TERMINAL: NONE`.

If the split is infeasible, `**Split-sample status:**` ends `INFEASIBLE — first-stage F labelled
DESCRIPTIVE and the threshold rule VOID`, and `06B-03` §5.1's decision rule under VOID governs
what Stage 1 may return.

**Two-step review, THEN commit.** Run **Reality Checker** and **one named specialist, IN
PARALLEL**. The specialist is an econometrics/identification reviewer. Both must verify
**anti-fabrication**: re-run `dune_window_a.py` against the committed CSVs and diff at least one
statistic; **re-fetch every `**Execution id:**` through `mcp__dune__getExecutionResults` and
confirm the returned row count and timestamp against §2** — this is the only step in the whole
phase that checks a number against something outside this repository, and it is why the
non-forgeability claim was withdrawn rather than left standing; confirm the row-count
reconciliations. Record in `## Review` with **counts and dispositions**:

```
## Review
**Reviewer 1 (always):** Reality Checker — <date>. findings: <B> BLOCKER / <M> MAJOR / <m> MINOR.
  disposition: <resolved N, carried N — each carried item named>.
**Reviewer 2 (named specialist):** <name> — chosen because <reason>. <date>.
  findings: <B> BLOCKER / <M> MAJOR / <m> MINOR. disposition: <...>.
**Anti-fabrication check:** re-ran <command>; recomputed <statistic> = <value>; matches §2.
```

Then commit scoped by path — the raw data and the script are committed with the document, because
a number whose inputs are not in the tree is not reproducible:

```
cd /home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller
git add control/spec/DISPERSION-WINDOW-A.md control/analysis/dune_window_a.py control/data/window-a/
git commit -m "feat(06B): Delta-t dispersion measured on window A, Decision #10 ruled, venue picked

Closes EST-02. Dispersion reported as a number per ratified candidate, computed
by a pinned sha256-recorded script from committed raw result sets with reconciled
row counts; Dune execution ids and execution timestamps recorded as the
measurement clock, with their transcribed status stated; Decision #10 adjudicated under the
structural-econometrics discipline; the user picked the venue. Window B untouched.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>" -- control/spec/DISPERSION-WINDOW-A.md control/analysis/dune_window_a.py control/data/window-a/
git show --name-only --format="" HEAD
```
  </action>
  <acceptance_criteria>
    - Guard: trivially passes on a terminal branch.
    - `DISPERSION-WINDOW-A.md` contains `## 8. The pick` with `**Put to the user:**`, `**Options presented:**`, `**RULING:**`, `**Picked venue:**`, `**Cluster count G:**`, `**Cluster consequence:**`, `**Split-sample status:**`, `**Consequence:**`.
    - **No template placeholders:** none of those eight field lines contains `<`, `>` or ` | `.
    - `**Picked venue:**` names a chain or reads exactly `NONE — TERMINAL NON-IDENTIFICATION`.
    - `**Cluster count G:**` carries an integer; if it is `1`, `**Cluster consequence:**` contains `G = 1` and `invalid`.
    - Exactly one line matches `^PHASE-6B-TERMINAL:`, and it is non-`NONE` **iff** `**Picked venue:**` is `NONE — TERMINAL NON-IDENTIFICATION`.
    - `**Split-sample status:**` contains `window A = [`, `window B = [`, and `FEASIBLE` or `INFEASIBLE`; if `INFEASIBLE`, it also contains `DESCRIPTIVE` and `VOID`.
    - `## Review` names `Reality Checker` and a second reviewer with two `findings:` count lines and two `disposition:` lines, plus an `**Anti-fabrication check:**` line naming a re-run command and a recomputed value.
    - `git show --name-only --format="" HEAD` lists only paths under `control/`, including `control/spec/DISPERSION-WINDOW-A.md` and `control/analysis/dune_window_a.py`.
    - **Scope sentinel:** the three `02-3.*.before` snapshots exist, are **newer than `.sentinel/.runstart`** (taken this run) and **not newer than the artifact** (taken before the edit), and each `diff -q` cleanly against the live value with `??` filtered on both sides — peer trees and the repo-root `.planning/` are **unchanged by this task**, which is not the same as clean.
  </acceptance_criteria>
  <resume-signal>Pick a chain or a set of chains by name from the ranked table, or reply `none` to close the phase on terminal non-identification. If you pick a single chain, confirm you accept G = 1.</resume-signal>
  <verify>
    <automated>cd /home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller && T=$(grep -E '^PHASE-6B-TERMINAL:' control/spec/NU-CONSTRUCTIBILITY.md | head -1) && if [ "$T" != "PHASE-6B-TERMINAL: NONE" ]; then echo "PASS (NOT RUN — $T)"; exit 0; fi && F=control/spec/DISPERSION-WINDOW-A.md && for s in '## 8. The pick' '**Put to the user:**' '**Options presented:**' '**RULING:**' '**Picked venue:**' '**Cluster count G:**' '**Cluster consequence:**' '**Split-sample status:**' '**Consequence:**' '## Review' 'Reality Checker' '**Anti-fabrication check:**' 'window A = [' 'window B = ['; do grep -qF "$s" $F || { echo "MISSING: $s"; exit 1; }; done && test $(awk '/^## 8\. The pick/,0' $F | grep -E '^\*\*(Put to the user|Options presented|RULING|Picked venue|Cluster count G|Cluster consequence|Split-sample status|Consequence):\*\*' | grep -cE '<|>|\| ') -eq 0 && grep -F '**Cluster count G:**' $F | grep -qE '[0-9]' && G=$(grep -F '**Cluster count G:**' $F | grep -oE '[0-9]+' | head -1) && { test "$G" -ge 2 || { grep -F '**Cluster consequence:**' $F | grep -qF 'G = 1' && grep -F '**Cluster consequence:**' $F | grep -qF 'invalid'; }; } && test $(grep -cE '^PHASE-6B-TERMINAL:' $F) -eq 1 && if grep -F '**Picked venue:**' $F | grep -qF 'NONE — TERMINAL NON-IDENTIFICATION'; then grep -qE '^PHASE-6B-TERMINAL: VENUE ' $F; else grep -qxF 'PHASE-6B-TERMINAL: NONE' $F; fi && grep -F '**Split-sample status:**' $F | grep -qE 'FEASIBLE|INFEASIBLE' && { ! grep -F '**Split-sample status:**' $F | grep -qF 'INFEASIBLE' || { grep -qF 'DESCRIPTIVE' $F && grep -qF 'VOID' $F; }; } && test $(grep -cE '^ *findings: *[0-9]+ BLOCKER */ *[0-9]+ MAJOR */ *[0-9]+ MINOR' $F) -ge 2 && test $(grep -cE 'disposition:' $F) -ge 2 && git show --name-only --format="" HEAD | grep -qxF 'control/spec/DISPERSION-WINDOW-A.md' && git show --name-only --format="" HEAD | grep -qxF 'control/analysis/dune_window_a.py' && test $(git show --name-only --format="" HEAD | grep -c .) -eq $(git show --name-only --format="" HEAD | grep -c '^control/') && SENT=control/.planning/phases/06B-research-venue-and-estimating-mev/.sentinel && test "$SENT/02-3.plank.before" -nt "$SENT/.runstart" && { test ! -e "${F:-/nonexistent}" || ! test "$SENT/02-3.plank.before" -nt "${F:-/nonexistent}"; } && diff -q "$SENT/02-3.plank.before" <(git -C ../plank status --porcelain | grep -v '^??') && diff -q "$SENT/02-3.lean4spec.before" <(git -C ../lean4-spec status --porcelain | grep -v '^??') && diff -q "$SENT/02-3.rootplanning.before" <(git status --porcelain .planning/) && echo PASS</automated>
  </verify>
  <done>The user picked the venue from the ranked table in their own words with the cluster-count consequence stated, or closed the phase on terminal non-identification with a machine-readable marker; the pick line carries no template placeholder; the document, the extraction script and the raw result sets are committed together so every number is reproducible; the two-step review re-ran the script and recomputed a statistic.</done>
</task>

</tasks>

<verification>
1. Every reported number traces to a committed CSV, a reconciled row count, a pinned script whose
   recorded sha256 matches on disk, and a Dune execution id.
2. Execution timestamps postdate the research register's FIRST commit. **Neither clock is
   self-authenticating**: `%ct` is settable and rebase-mutable, and the execution timestamp is
   transcribed by this session — §2's `**Forgeability, stated plainly.**` block says so, and the
   reviewer's `mcp__dune__getExecutionResults` re-fetch is what actually authenticates it. Both
   checks **record** ordering; neither proves it.
3. The ranking table is 3–5 rows × 7 columns with a numeric dispersion cell in every row.
4. No σ-channel statistic is computed before the pick; the threat column is mechanism-only.
5. Window B never queried; the pre-registered floor never redefined against the numbers.
6. Peer trees and repo-root `.planning/` **unchanged by this plan**, measured BEFORE vs AFTER.
</verification>

<success_criteria>
- `EST-02` closed: dispersion measured and reported as a reproducible number on window A over the
  ratified set in full.
- Decision #10 adjudicated and recorded.
- The user picked the venue with the cluster-count consequence on the record, or the phase closed
  on terminal non-identification with no instrument substituted.
</success_criteria>

<output>
After completion, create
`/home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller/control/.planning/phases/06B-research-venue-and-estimating-mev/06B-02-SUMMARY.md`,
recording the picked venue, `G`, the Decision #10 ruling verbatim, the split-sample status, the
`PHASE-6B-TERMINAL:` line, the script sha256, and every Dune execution id + timestamp.
</output>
