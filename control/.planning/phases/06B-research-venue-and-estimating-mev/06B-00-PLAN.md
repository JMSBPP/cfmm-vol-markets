---
phase: 06B-research-venue-and-estimating-mev
plan: 00
type: execute
wave: 1
depends_on: []
files_modified:
  - control/spec/RESEARCH-REGISTER.md
autonomous: true
requirements: [LIT-01, LIT-02, LIT-03]

must_haves:
  truths:
    - "Every one of the 14 internal PDFs carries a six-field block, a locating evidence anchor with a quoted sentence, and an explicit transfer verdict — a label alone cannot satisfy the criteria."
    - "Every arXiv id is resolved through the arxiv MCP and its returned title recorded, so an invented identifier cannot pass."
    - "Non-arXiv material is tagged lower-rigor as a class, is never the sole justification, and never supplies a dispersion number."
    - "The instrument-selection rule is on the record with a commit sha, and that commit provably predates every dispersion measurement in this phase."
    - "Peer trees and the repo-root `.planning/` are UNCHANGED BY THIS PLAN — measured as BEFORE == AFTER, never as absolute cleanliness."
  artifacts:
    - path: "control/spec/RESEARCH-REGISTER.md"
      provides: "One block per source across all three research classes, plus the instrument-selection rule written before any dispersion is measured"
      min_lines: 120
      contains: "Instrument-selection rule"
  key_links:
    - from: "control/spec/RESEARCH-REGISTER.md"
      to: "PLANK/refs/mev + PLANK/refs/flair"
      via: "one ### S-NN block per PDF basename, all fourteen, each with an evidence anchor"
      pattern: "MilionisMoallemiRoughgardenArbProfitsFees.pdf"
    - from: "control/spec/RESEARCH-REGISTER.md"
      to: "control/spec/POOL-ALGEBRA.md and control/spec/PRE-REGISTRATION.md"
      via: "the register's FIRST commit sha is quoted downstream as the pin"
      pattern: "Instrument-selection rule"
---

<objective>
Run the three-source research sweep that this phase never had, and close it with the
instrument-selection rule **written before any dispersion is measured anywhere**.

Purpose: `LIT-01`, `LIT-02`, `LIT-03`. This plan runs first and **nothing downstream in Phase
6b is specified before it returns** (`ROADMAP.md` Phase 6b, plan list, `06b-00`). The register
it produces is the evidence base for `LIT-04`'s venue derivation, `EST-01`'s constructibility
verdict, and the frozen pre-registration.

Output: `control/spec/RESEARCH-REGISTER.md`, committed, its **first** commit sha quoted
downstream.
</objective>

<execution_context>
@/home/jmsbpp/.claude/get-shit-done/workflows/execute-plan.md
@/home/jmsbpp/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@/home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller/control/.planning/PROJECT.md
@/home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller/control/.planning/ROADMAP.md
@/home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller/control/.planning/REQUIREMENTS.md
@/home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller/control/.planning/phases/06B-research-venue-and-estimating-mev/06B-CONTEXT.md
@/home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller/control/spec/ECONOMETRICS-DESIGN.md

**Path glossary.** `WT` = `/home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller` — this
worktree root, and **every `files_modified` path is relative to it**. `CTRL` = `WT/control` —
this GSD project's root; every `gsd` command runs `--cwd control`. `PLANK` =
`/home/jmsbpp/cfmms-playground/cfmm-wt/plank` (**PEER-OWNED, READ-ONLY**). `LEAN` =
`/home/jmsbpp/cfmms-playground/cfmm-wt/lean4-spec` (**PEER-OWNED, READ-ONLY**). `SRC` =
`WT/notes/VOLATILITY_INTRUMENTS_MEV.md` — **this project's own file**, pinned at commit
`cf386de`. `DOC` = `PLANK/notes/VOLATILITY_INSTRUMENTS.md`.

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

**As the FIRST action of every task**, with `TAG` = `00-1`, `00-2`, `00-3` respectively:

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
- Never write under `PLANK/`, `LEAN/`, or `WT/.planning/` — the repo-root `.planning/` belongs
  to a **different, unrelated GSD project**. Findings against peer trees are routed as a
  `claude-peers` message plus a gap-register entry, never as an edit.
- `grep` is a shell function dispatching to `ugrep`: literal LaTeX/backslash patterns need `-F`
  (`grep -qF`, `grep -cF`). A bare `grep -c '\widehat\pi'` errors rather than returning 0. Never
  write `grep -v '^\+\+\+'` — under this grep that is not a valid BRE and silently matches
  everything; write `grep -v '^+++'`.
- **Shell chains must be unbroken.** Every `<verify>` is a single `&&` chain terminating in
  `echo PASS`. Never write `done;` — write `done &&`. A `;` before the tail makes everything
  preceding it non-blocking.
- `gsd-tools commit --files` commits the **entire staged index**. Use plain
  `git add <paths> && git commit -m ... -- <paths>` and verify with
  `git show --name-only --format="" HEAD`. Do **not** use `git show --stat` for path assertions:
  it elides long paths as `.../MevTaxControl.lean`.
- No `.plk` or `.sol` artifact is produced; no on-chain cost claim is attached to any result.
- **Notation is binding.** No symbol is minted without a user ruling.
</context>

<inherited>
**Phases 1, 2, 3 and 6a are UNEXECUTED at plan time.** Nothing below may presume they landed.
`RESEARCH-REGISTER.md` opens with an `## Inherited, not assumed` section naming these **five**
items:

- **O4 — `σ` versus `σ²` units** (Phase 1 `NOT-05`). `DOC` Definition 18's sigmoid argument is
  `σ(i(t))`; the plant's `u_ex` carries `σ²(i(t))`. **UNRESOLVED at plan time.** A register row
  reporting an effect size in volatility units states which of the two it is, or says it cannot
  tell. **This plan does not answer O4** — `06B-01` runs the dimensional check that bears on it.
- **The event-clock ruling** (Phase 2 `FRM-03`). Whether `t` indexes swaps or blocks, and
  whether event-averaged `ΔQ_M, ΔQ_X` may be combined with time-averaged `π^LVR·Δt, σ², λ`.
  Phase 2 SC3 names this phase's identification as one of the results at risk if it stays OPEN.
  **UNRESOLVED at plan time.**
- **The hypothesis discipline** (Phase 3 `PRF-03`, `PRF-06`). `H1_dLbar_dpiPhi_pos` and
  `H2_dnu_dlamMEV_pos` are typed hypotheses, never submitted to the proving pipeline.
  **The written protocol does not exist at plan time.**
- **`NEC-04`'s coupling verdict and its recomposition rule** (Phase 6a).
  `ECONOMETRICS-DESIGN.md:31` classifies `∂ν/∂λ_MEV` as **"Behavioural. Not derivable."** and
  `NEC-04` reopens that ruling. **This phase assumes NEITHER verdict.**
- **`NEC-00`'s affine-in-`Ḡ` verdict** (Phase 6a). The composition
  `∂π̂^σ/∂τ = (∂π̂^σ/∂φ)·[(1−φ_M)(1−φ_X) + (∂φ/∂ν)·Ḡ·(∂λ/∂τ)]` was **refuted-as-a-free-option by
  two independent reviewers and by the orchestrator's own derivation**, but `NEC-00` exists
  precisely because a two-reviewer consensus is **not** a machine-checked identity
  (`REQUIREMENTS.md` `NEC-00`: "verified, not inherited"; the Gates table lists it **NOT
  REACHED**). Everywhere this register or any downstream artifact relies on it, it is stated as
  **PENDING `NEC-00`'s formal carrier**, never as established.
- **The review register** (Phase 1 `HND-05`) does not exist at plan time, so each artifact
  carries its own `## Review` section instead of an entry in it.
</inherited>

<tasks>

<task type="auto">
  <name>Task 1: LIT-01 — all fourteen internal PDFs, six fields plus a locating evidence anchor</name>
  <files>control/spec/RESEARCH-REGISTER.md</files>
  <read_first>
    - `/home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller/control/.planning/REQUIREMENTS.md` — the `LIT-01` definition (the roster is exact and enumerated there)
    - `/home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller/control/.planning/phases/06B-research-venue-and-estimating-mev/06B-CONTEXT.md` — `<decisions>` "Research output shape" (the six-field schema is a user ruling)
    - `/home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller/control/spec/ECONOMETRICS-DESIGN.md` — §1 the estimand, §2 the `Δt` instrument, §3 the staged gate (what each paper is screened *against*)
    - `~/.claude/skills/read-paper/SKILL.md` — the targeted-extraction workflow
  </read_first>
  <action>
**FIRST: capture the scope sentinel with `TAG=00-1`** (see `<context>`).

Create `/home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller/control/spec/RESEARCH-REGISTER.md`.

**Header, verbatim except the date (`date -I`):**

```
# RESEARCH REGISTER — Phase 6b, three-source sweep

**Requirements:** LIT-01, LIT-02, LIT-03
**Swept:** <YYYY-MM-DD>
**Screened against:** `control/spec/ECONOMETRICS-DESIGN.md` — the estimand `Ḡ = ∂ν/∂λ_MEV`,
the `Δt` exclusion restriction, and the staged gate.

**This register is the input everything downstream rests on.** Adding a source after `EST-03`
returns is a **protocol violation** on the same footing as re-specification — "we found a paper
suggesting a better instrument" is the standard laundering route around a re-specification ban
(`LIT-02`). Any such addition is recorded in §6 as a violation, not appended silently.
```

Then `## Inherited, not assumed` — write the **five** items from this plan's `<inherited>` block
verbatim, each ending in **UNRESOLVED at plan time**, **does not exist at plan time**, or
**PENDING `NEC-00`'s formal carrier**.

Then `## 1. Class A — the internal corpus (LIT-01)`.

**The roster is exactly these fourteen basenames. Enumerate them; an omission fails the task.**

Under `PLANK/refs/mev/` (twelve):
`CapponiCarteaDrissiDiscreteClearing.pdf`, `CapponiJiaAdoptionDEX.pdf`,
`CapponiJiaWangLitToDark.pdf`, `CapponiJiaZhuJITLiquidity.pdf`, `CapponiZhuTimeboost.pdf`,
`ChitraTheoryMEV2Uncertainty.pdf`, `DaianEtAlFlashBoys2.pdf`, `GuoInvarianceMEV.pdf`,
`KulkarniDiamandisChitraTheoryMEV1.pdf`, `MazorraDellaPennaCFMMWelfareMEV.pdf`,
`MilionisMoallemiRoughgardenArbProfitsFees.pdf`, `ObadiaEtAlCrossDomainMEV.pdf`

Under `PLANK/refs/flair/` (two):
`CampbellBergaultMilionisNutzOptimalFees.pdf`, `MilionisWanAdamsFLAIR.pdf`

Confirm the roster on disk before extracting:
`ls -1 /home/jmsbpp/cfmms-playground/cfmm-wt/plank/refs/mev/ /home/jmsbpp/cfmms-playground/cfmm-wt/plank/refs/flair/`
must list exactly these fourteen. If the tree has drifted, record the drift in §6 and extract
against what is actually there, naming every missing file.

**Method — targeted extraction, NOT full reads** (user ruling). Dispatch **four sub-agents in
parallel** via the Task tool, each assigned 3–4 of the fourteen basenames and given the schema
below verbatim. Each sub-agent reads only the abstract, the data/empirics section, and the
results tables of its assigned PDFs, and returns **only** the seven-line blocks — no prose
summary, no theory recap. The executor concatenates the returned blocks in roster order.

**The schema. Copy these labels byte-exactly — the acceptance criteria grep them:**

```
### S-NN — <basename>
**Class:** INTERNAL-PDF
**Identification strategy:** <structural model / RCT / DiD / IV / event study / RD /
calibration / NONE — THEORY ONLY>
**Data source:** <the actual dataset, chain, venue and period; `NONE` if the paper uses no data>
**Unit of observation:** <block / swap / pool-day / trader / pair / NONE>
**Instrument used:** <the exclusion restriction and the excluded variable; `NONE` if none>
**Estimated effect size:** <the number(s) with units and sign; `NO EMPIRICAL CONTENT` if the
paper reports none>
**Evidence anchor:** <§ / Section / Table / Figure / p. — the LOCATOR inside the paper> — "<a
verbatim quoted sentence of at least 40 characters from that locator>"
**Transfer verdict:** TRANSFERS | TRANSFERS WITH MODIFICATION | DOES NOT TRANSFER — <the reason,
stated against THIS project's estimand `Ḡ = ∂ν/∂λ_MEV` and the `Δt` instrument>
```

**`**Evidence anchor:**` is mandatory on ALL FOURTEEN blocks and is what distinguishes an
extraction from a label.** A six-field block whose every field reads `NONE` /
`NO EMPIRICAL CONTENT` / `DOES NOT TRANSFER` is satisfiable without opening a PDF; the anchor is
not. Therefore:

- A paper **with** empirical content anchors on the table or section reporting the effect size,
  and quotes a sentence from it.
- A paper with **no** empirical content still anchors — on the section where its contribution is
  stated (typically the abstract or the model section) — and quotes the sentence that shows it is
  theory. **"No empirical content" is a claim that needs locating evidence like any other.**

**Four papers carry specific things this project already knows and must not lose:**
- `MilionisMoallemiRoughgardenArbProfitsFees.pdf` — **the anchor paper**. §7.3 eq. (27) is the
  missing demand-elasticity term the `[M8]` caveats name. Its `Instrument used` and
  `Estimated effect size` fields decide whether the anchor is empirical at all.
- `CapponiJiaZhuJITLiquidity.pdf` — the JIT welfare-loss convex tradeoff.
- `CapponiZhuTimeboost.pdf` — a live auction mechanism on a chain with non-Ethereum block
  cadence; its `Data source` field is directly relevant to `LIT-04`'s chain candidates.
- `MilionisWanAdamsFLAIR.pdf` — `λ_FLAIR` versus `λ_MEV` monotonicity is a known carry-forward
  and the transfer verdict must not conflate them.

Close §1 with `### 1.x Roster check`: fourteen blocks written, fourteen basenames enumerated,
fourteen evidence anchors, and the count of each transfer verdict class summing to fourteen.
  </action>
  <acceptance_criteria>
    - `control/spec/RESEARCH-REGISTER.md` exists and is ≥ 120 lines after this task.
    - It contains `## Inherited, not assumed` and all **five** inherited item names: `O4`, `FRM-03`, `PRF-03`, `NEC-04`, `NEC-00`; and contains `PENDING` next to the `NEC-00` item.
    - All **fourteen** basenames appear literally (the twelve `refs/mev/` names and the two `refs/flair/` names listed in the action).
    - `grep -c '^### S-'` returns ≥ 14, and `grep -cF '**Class:** INTERNAL-PDF'` returns exactly 14.
    - Each of the six labels `**Identification strategy:**`, `**Data source:**`, `**Unit of observation:**`, `**Instrument used:**`, `**Estimated effect size:**`, `**Transfer verdict:**` appears ≥ 14 times.
    - `grep -cF '**Evidence anchor:**'` returns ≥ 14; **every** such line matches a locator token (`§`, `Section`, `Table`, `Figure`, `Fig.`, `p. N`, `pp.`, `eq.`, `Appendix`, `Abstract`) **and** contains a double-quoted span of ≥ 40 characters.
    - Every `**Transfer verdict:**` line contains one of `TRANSFERS WITH MODIFICATION`, `DOES NOT TRANSFER`, `TRANSFERS`.
    - A `Roster check` heading is present containing the literal string `fourteen`.
    - **Scope sentinel:** the three `00-1.*.before` snapshots exist, are **newer than `.sentinel/.runstart`** (taken this run) and **not newer than the artifact** (taken before the edit), and each `diff -q` cleanly against the live value with `??` filtered on both sides — peer trees and the repo-root `.planning/` are **unchanged by this task**, which is not the same as clean.
  </acceptance_criteria>
  <verify>
    <automated>cd /home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller && F=control/spec/RESEARCH-REGISTER.md && test -f $F && test $(wc -l < $F) -ge 120 && for s in "## Inherited, not assumed" "O4" "FRM-03" "PRF-03" "NEC-04" "NEC-00" "PENDING" CapponiCarteaDrissiDiscreteClearing.pdf CapponiJiaAdoptionDEX.pdf CapponiJiaWangLitToDark.pdf CapponiJiaZhuJITLiquidity.pdf CapponiZhuTimeboost.pdf ChitraTheoryMEV2Uncertainty.pdf DaianEtAlFlashBoys2.pdf GuoInvarianceMEV.pdf KulkarniDiamandisChitraTheoryMEV1.pdf MazorraDellaPennaCFMMWelfareMEV.pdf MilionisMoallemiRoughgardenArbProfitsFees.pdf ObadiaEtAlCrossDomainMEV.pdf CampbellBergaultMilionisNutzOptimalFees.pdf MilionisWanAdamsFLAIR.pdf "Roster check" "fourteen"; do grep -qF "$s" $F || { echo "MISSING: $s"; exit 1; }; done && test $(grep -c '^### S-' $F) -ge 14 && test $(grep -cF '**Class:** INTERNAL-PDF' $F) -eq 14 && for L in '**Identification strategy:**' '**Data source:**' '**Unit of observation:**' '**Instrument used:**' '**Estimated effect size:**' '**Transfer verdict:**' '**Evidence anchor:**'; do test $(grep -cF "$L" $F) -ge 14 || { echo "LABEL SHORT: $L"; exit 1; }; done && A=$(grep -cF '**Evidence anchor:**' $F) && test $(grep -F '**Evidence anchor:**' $F | grep -cE '(§|Section|Table|Figure|Fig\.|pp?\. ?[0-9]|eq\.|Appendix|Abstract)') -eq $A && test $(grep -F '**Evidence anchor:**' $F | grep -cE '"[^"]{40,}"') -eq $A && test $(grep -F '**Transfer verdict:**' $F | grep -vcE 'TRANSFERS WITH MODIFICATION|DOES NOT TRANSFER|TRANSFERS') -eq 0 && SENT=control/.planning/phases/06B-research-venue-and-estimating-mev/.sentinel && test "$SENT/00-1.plank.before" -nt "$SENT/.runstart" && { test ! -e "${F:-/nonexistent}" || ! test "$SENT/00-1.plank.before" -nt "${F:-/nonexistent}"; } && diff -q "$SENT/00-1.plank.before" <(git -C ../plank status --porcelain | grep -v '^??') && diff -q "$SENT/00-1.lean4spec.before" <(git -C ../lean4-spec status --porcelain | grep -v '^??') && diff -q "$SENT/00-1.rootplanning.before" <(git status --porcelain .planning/) && echo PASS</automated>
  </verify>
  <done>All fourteen internal PDFs carry a six-field block, a locating evidence anchor with a verbatim quoted sentence, and one of three transfer verdicts; the anchors make an unopened-PDF pass impossible; peer trees and repo-root `.planning/` are unchanged by this task.</done>
</task>

<task type="auto">
  <name>Task 2: LIT-02 — the arXiv sweep, every id resolved through the arxiv MCP</name>
  <files>control/spec/RESEARCH-REGISTER.md</files>
  <read_first>
    - `/home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller/control/spec/RESEARCH-REGISTER.md` (the file you are appending to — §1's transfer verdicts tell you which gaps the sweep must close)
    - `/home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller/control/.planning/REQUIREMENTS.md` — the `LIT-02` definition, including the ban on post-`EST-03` additions
    - `/home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller/control/spec/ECONOMETRICS-DESIGN.md` §2 — "Named risk — weak instrument" (the sweep exists to price this risk)
    - `~/.claude/skills/lit-review/SKILL.md` — the three-dimension dispatch and the adversarial-referee convergence loop
  </read_first>
  <action>
**FIRST: capture the scope sentinel with `TAG=00-2`.**

Append `## 2. Class B — arXiv (LIT-02)` to `control/spec/RESEARCH-REGISTER.md`.

**Route: the `lit-review` skill, and the arxiv MCP for retrieval and verification.** The standing
rule is arXiv over web search for academic work. Run `lit-review` at `--depth deep`.

**Four target classes, each its own `### 2.N` subsection:**

1. **Empirical AMM / LVR studies** — papers that *measure* an AMM quantity rather than deriving it.
2. **Fee-versus-flow elasticity** — the closest analogue to `H1` (`∂L̄/∂π^φ`) and to the
   behavioural content of `Ḡ`.
3. **Pool-level panel regressions** — for the clustering and effective-N questions `EST-07` must
   answer with numbers.
4. **THE CRITICAL ONE — what prior work has used as an instrument on block time or realized
   volatility.** `Δt` is our proposed lever and its weakness is the named risk. This subsection
   returns either (a) prior instruments on block time / interblock interval / slot cadence, with
   their first-stage strengths, or (b) an explicit **`no prior instrument found`** finding. A
   silent absence is not acceptable — an absence is a finding and is written as one.

Every hit gets the **same block shape as §1** with `**Class:** ARXIV` and **two** extra lines
immediately after the class line:

```
**arXiv id:** arXiv:NNNN.NNNNN
**Resolved title:** <the title returned by `mcp__arxiv__get_abstract` for that id, verbatim>
```

**Every identifier is RESOLVED, not merely formatted.** A well-formed invented id satisfies a
regex; it does not survive a lookup. Call `mcp__arxiv__get_abstract` (or the arxiv MCP's
equivalent retrieval tool) on each id and paste the returned title. An id that does not resolve
is written with `**arXiv id:** UNVERIFIED — <the tool's error>` and
`**Resolved title:** UNVERIFIED`, and its transfer verdict is
`DOES NOT TRANSFER — not primary-verified`. The `**Resolved title:**` line is never blank.

Then `### 2.5 Adversarial referee`:

```
### 2.5 Adversarial referee

**Rounds run:** <N>
**Challenges raised:** <numbered list of the referee's "what did you miss" challenges>
**Resolution per challenge:** <the search that answered it, or ACCEPTED AS A GAP>
**Status:** CONVERGED | NOT CONVERGED — <reason>
```

**If the referee does not converge, write `NOT CONVERGED` and state what is unresolved.** A
forced `CONVERGED` is the failure this pass exists to prevent.

Then `### 2.6 Candidate instrument menu (RAW — not yet ruled on)` — a numbered list of every
instrument the sweep surfaced, including `Δt` / `√Δt` itself, each with: the excluded variable,
the exclusion argument in one sentence, and the reported first-stage strength if the source
reports one. **This is a menu, not a selection.** The rule that selects among them is written in
Task 3 and nowhere else — do not rank, do not recommend, do not measure anything here.

Close with `### 2.7 Sweep boundary` recording the date, the query set, and the literal sentence:
`The menu in §2.6 is closed as of this date. Additions after EST-03 returns are a protocol
violation recorded in §6.`
  </action>
  <acceptance_criteria>
    - `RESEARCH-REGISTER.md` contains `## 2. Class B — arXiv (LIT-02)` and `### 2.1` … `### 2.4`.
    - `### 2.4`'s body contains either at least one `**arXiv id:**` line or the literal string `no prior instrument found`.
    - `grep -cF '**Class:** ARXIV'` ≥ 6; the counts of `**Class:** ARXIV`, `**arXiv id:**` and `**Resolved title:**` are all **equal**.
    - Every `**arXiv id:**` line matches `arXiv:[0-9]{4}\.[0-9]{4,5}` or contains `UNVERIFIED`.
    - **No `**Resolved title:**` line is blank** — `grep -cE '\*\*Resolved title:\*\* *$'` returns 0.
    - `### 2.5 Adversarial referee` contains `**Rounds run:**`, `**Challenges raised:**`, and a `**Status:**` line matching `CONVERGED` or `NOT CONVERGED`.
    - `### 2.6 Candidate instrument menu` contains `RAW — not yet ruled on` and ≥ 3 numbered entries.
    - The file contains none of `recommended instrument`, `best instrument`, `we select` — selection is Task 3's.
    - `### 2.7 Sweep boundary` contains `The menu in §2.6 is closed as of this date.`
    - **Scope sentinel:** the three `00-2.*.before` snapshots exist, are **newer than `.sentinel/.runstart`** (taken this run) and **not newer than the artifact** (taken before the edit), and each `diff -q` cleanly against the live value with `??` filtered on both sides — peer trees and the repo-root `.planning/` are **unchanged by this task**, which is not the same as clean.
  </acceptance_criteria>
  <verify>
    <automated>cd /home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller && F=control/spec/RESEARCH-REGISTER.md && for s in '## 2. Class B — arXiv (LIT-02)' '### 2.1' '### 2.2' '### 2.3' '### 2.4' '### 2.5 Adversarial referee' '**Rounds run:**' '**Challenges raised:**' '### 2.6 Candidate instrument menu' 'RAW — not yet ruled on' '### 2.7 Sweep boundary' 'The menu in §2.6 is closed as of this date.'; do grep -qF "$s" $F || { echo "MISSING: $s"; exit 1; }; done && N=$(grep -cF '**Class:** ARXIV' $F) && test $N -ge 6 && test $(grep -cF '**arXiv id:**' $F) -eq $N && test $(grep -cF '**Resolved title:**' $F) -eq $N && test $(grep -cE '\*\*Resolved title:\*\* *$' $F) -eq 0 && test $(grep -F '**arXiv id:**' $F | grep -vcE 'arXiv:[0-9]{4}\.[0-9]{4,5}|UNVERIFIED') -eq 0 && grep -qE '^\*\*Status:\*\* (CONVERGED|NOT CONVERGED)' $F && { grep -qF '**arXiv id:**' $F || grep -qF 'no prior instrument found' $F; } && for bad in 'recommended instrument' 'best instrument' 'we select'; do ! grep -qF "$bad" $F || { echo "SELECTION LEAKED INTO SWEEP: $bad"; exit 1; }; done && SENT=control/.planning/phases/06B-research-venue-and-estimating-mev/.sentinel && test "$SENT/00-2.plank.before" -nt "$SENT/.runstart" && { test ! -e "${F:-/nonexistent}" || ! test "$SENT/00-2.plank.before" -nt "${F:-/nonexistent}"; } && diff -q "$SENT/00-2.plank.before" <(git -C ../plank status --porcelain | grep -v '^??') && diff -q "$SENT/00-2.lean4spec.before" <(git -C ../lean4-spec status --porcelain | grep -v '^??') && diff -q "$SENT/00-2.rootplanning.before" <(git status --porcelain .planning/) && echo PASS</automated>
  </verify>
  <done>The arXiv sweep ran through `lit-review` with the arxiv MCP; every identifier was resolved through the MCP and its returned title recorded, so a fabricated id cannot pass; the block-time/realized-volatility instrument question is answered with hits or an explicit no-prior-instrument finding; the referee pass carries its true convergence status; the candidate menu is raw and unranked.</done>
</task>

<task type="auto">
  <name>Task 3: LIT-03 — non-arXiv material, the conflict log, and the instrument-selection rule that freezes the register</name>
  <files>control/spec/RESEARCH-REGISTER.md</files>
  <read_first>
    - `/home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller/control/spec/RESEARCH-REGISTER.md` (§1 and §2 — the conflict log is built by diffing their findings)
    - `/home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller/control/.planning/REQUIREMENTS.md` — the `LIT-03` definition and `EST-09` (why the selection rule must predate measurement)
    - `/home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller/control/.planning/phases/06B-research-venue-and-estimating-mev/06B-CONTEXT.md` — `<deferred>`: dynamic-fee natural experiments were **declined by the user** (Decision #14)
    - `~/.claude/skills/anti-fishing-replication/SKILL.md` — the Iron Law, which governs §6
  </read_first>
  <action>
**FIRST: capture the scope sentinel with `TAG=00-3`.**

Append §3–§6 to `control/spec/RESEARCH-REGISTER.md`, then review and commit.

**`## 3. Class C — non-arXiv on-chain material (LIT-03)`**

Hand-run, **not** routed through `lit-review`. Sources: Dune-published studies, protocol research
posts, foundation reports on realized fee-versus-volume and live dynamic-fee experiments.
Dispatch two sub-agents in parallel over disjoint source lists if the set exceeds six items.

Open §3 with this standing block, **verbatim**:

```
**LOWER-RIGOR AS A CLASS.** Everything in §3 may motivate a specification and may screen
candidate chains. It may **never** be the sole justification for a specification, and it may
**never supply the reported dispersion number** — dispersion is a measurement, made by `EST-02`
on window A, not a motivation. Where §3 conflicts with §1 or §2, the peer-reviewed source
governs and the conflict is recorded in §4.
```

Each source gets the §1 block shape with `**Class:** NON-ARXIV (LOWER-RIGOR)` and a `**URL:**`
line. `**Identification strategy:**` for a dashboard or blog post is normally
`NONE — DESCRIPTIVE`; write that rather than inventing a design. The `**Evidence anchor:**` line
is required here too, anchoring on the chart, table or paragraph relied on.

**A minimum of three Class C sources, or an explicit null.** If fewer than three exist, write
the literal line `NO CLASS C SOURCES FOUND` followed by a `**Search record:**` block naming every
query run, every venue searched, and the date — an empty class closed with no search record is
not a search.

**Recorded exclusion, verbatim:**

```
**Dynamic-fee natural experiments are EXCLUDED by user decision (Decision #14, 2026-08-09).**
Algebra `AdaptiveFee` rollouts and Uniswap fee-tier migrations were offered as a fourth source
class and declined. Reopening this is a **scope change**, not a research decision.
```

**`## 4. Conflict log`**

Table `# | Claim | Class C source | Governing source (§1/§2) | Resolution`. Where a §3 source
asserts something a peer-reviewed source contradicts, the peer-reviewed source governs. If there
are no conflicts, write `No conflicts found.` **and** list which §3 claims were checked against
which §1/§2 findings — an empty log with no check list is not a check.

**`## 5. Instrument-selection rule — WRITTEN BEFORE ANY DISPERSION IS MEASURED`**

```
## 5. Instrument-selection rule

**Written:** <YYYY-MM-DD>. **No dispersion has been measured at the time of writing.**
`EST-02` measures dispersion on window A; `06B-01` pre-declares the candidate set. Both are
downstream of this section by construction, and the git history records the order.

**5.1 The menu is closed.** The admissible instrument set is exactly §2.6's numbered menu.
Nothing may be added later. **If no member of the closed menu identifies `Ḡ`, that is terminal
non-identification** — the `υ` precedent — and **no instrument substitution is permitted**,
before or after any measurement.

**5.2 The rule that selects among the menu.** <State it. It must be decidable from information
available BEFORE any dispersion is measured — the exclusion argument, the class of the supporting
evidence, and the availability of the excluded variable on candidate chains. It may NOT reference
a realized first-stage F, a realized dispersion number, or an argmax over candidates.>

**5.3 The primary instrument under 5.2, and why.** <Name it. `ECONOMETRICS-DESIGN.md` §2
proposes `√Δt` — the transform the hazard actually carries, not raw `Δt`. If the sweep did not
displace that, say so and cite §2.6's entry. If it DID surface a better candidate under 5.2's
rule, name it and record that `ECONOMETRICS-DESIGN.md` §2 is superseded on this point.>

**5.4 What would void this rule.** <Enumerate. At minimum: the excluded variable is unavailable
on every candidate chain; the exclusion argument is refuted by a §1/§2 source; Phase 2's
event-clock ruling makes a time-axis instrument inadmissible against event-indexed outcomes.>

**5.5 The ban.** Adding a source or an instrument to this register after `EST-03` returns is a
protocol violation recorded in §6, **not** an amendment.
```

**`## 6. Protocol-violation log`**

Open it with the header row and the literal line `No violations recorded as of <date>.` **This
section is APPEND-ONLY and downstream plans are authorised to write to it** — `06B-03` and
`06B-04` both carry `control/spec/RESEARCH-REGISTER.md` in their `files_modified` and commit
paths precisely so that disclosing a protocol note is not blocked by a single-path commit
assertion. **Disclosure must never be harder than concealment.**

**`## Review`** — the review register (`HND-05`, Phase 1) does not exist, so record the review
here, with **counts and dispositions**, not just names:

```
## Review

**Reviewer 1 (always):** Reality Checker — <YYYY-MM-DD>.
  findings: <B> BLOCKER / <M> MAJOR / <m> MINOR. disposition: <resolved N, carried N — each
  carried item named>.
**Reviewer 2 (named specialist):** <name> — chosen because <reason>. <YYYY-MM-DD>.
  findings: <B> BLOCKER / <M> MAJOR / <m> MINOR. disposition: <...>.
**Review date precedes commit date:** yes — the commit follows this block being written.
```

**Two-step review, THEN commit.** Run **Reality Checker** and **one named specialist from the
AI-agency catalog, IN PARALLEL** over `RESEARCH-REGISTER.md`. For this artifact the specialist is
a research/analysis reviewer — name whichever you dispatch. Neither reviewer edits the file.
Resolve every BLOCKER and MAJOR before committing.

Then commit **with plain git, scoped by path**:

```
cd /home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller
git add control/spec/RESEARCH-REGISTER.md
git commit -m "docs(06B): three-source research register, instrument-selection rule frozen

Closes LIT-01, LIT-02, LIT-03. Fourteen internal PDFs re-read for empirical
design against a six-field schema with locating evidence anchors; arXiv sweep via
lit-review with every identifier resolved through the arxiv MCP; non-arXiv
material tagged lower-rigor as a class. Section 5 fixes the instrument-selection
rule BEFORE any dispersion is measured, and closes the candidate menu.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>" -- control/spec/RESEARCH-REGISTER.md
git show --name-only --format="" HEAD
git log --reverse --format='REGISTER FIRST COMMIT %H %ct %cI' -- control/spec/RESEARCH-REGISTER.md | head -1
```

**Record the `REGISTER FIRST COMMIT` line in the SUMMARY.** Downstream plans pin the **first**
commit of this file, not the last: §6 is append-only, so a later disclosure would otherwise
invert the ordering chain.

**Ordering is RECORDED, not PROVEN.** `%ct` is settable via `GIT_COMMITTER_DATE`, is rewritten by
`amend`/`rebase`, and this branch is destined for a PR→`develop` rebase. It orders *file commits*,
not *measurements*. `06B-02` captures the Dune **execution timestamp** and asserts it against this
commit, which orders the *measurement* rather than the file — but that timestamp is **transcribed
by this session and is not self-authenticating either** (`06B-02` §2 says so in writing). Neither
clock defeats an adversary; both catch an accident. The ordering guarantees that do survive are
**structural** — the terminal markers, the dimensional gate, the frozen-blob reads and the §5a
lock.
  </action>
  <acceptance_criteria>
    - `RESEARCH-REGISTER.md` contains `## 3. Class C`, `## 4. Conflict log`, `## 5. Instrument-selection rule`, `## 6. Protocol-violation log`, `## Review`.
    - §3 contains `LOWER-RIGOR AS A CLASS`, `never supply the reported dispersion number`, `Decision #14`.
    - Either `grep -cF '**Class:** NON-ARXIV (LOWER-RIGOR)'` ≥ 3, **or** the file contains `NO CLASS C SOURCES FOUND` and `**Search record:**`.
    - Every `**Class:** NON-ARXIV (LOWER-RIGOR)` block is matched by a `**URL:**` line (counts equal).
    - §5 contains `No dispersion has been measured at the time of writing.`, `5.1`…`5.5`, and `no instrument substitution is permitted`.
    - §6 contains `No violations recorded as of` and the literal string `APPEND-ONLY`.
    - `## Review` contains `Reality Checker`, a second named reviewer, **two** lines matching `findings:` each carrying at least three digits' worth of counts, and **two** `disposition:` lines.
    - `git log --reverse --format=%H -- control/spec/RESEARCH-REGISTER.md | head -1` returns a non-empty sha.
    - `git show --name-only --format="" HEAD` lists exactly one path, and it is `control/spec/RESEARCH-REGISTER.md`.
    - **Scope sentinel:** the three `00-3.*.before` snapshots exist, are **newer than `.sentinel/.runstart`** (taken this run) and **not newer than the artifact** (taken before the edit), and each `diff -q` cleanly against the live value with `??` filtered on both sides — peer trees and the repo-root `.planning/` are **unchanged by this task**, which is not the same as clean.
  </acceptance_criteria>
  <verify>
    <automated>cd /home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller && F=control/spec/RESEARCH-REGISTER.md && for s in '## 3. Class C' '## 4. Conflict log' '## 5. Instrument-selection rule' '## 6. Protocol-violation log' '## Review' 'LOWER-RIGOR AS A CLASS' 'never supply the reported dispersion number' 'Decision #14' 'No dispersion has been measured at the time of writing.' 'no instrument substitution is permitted' 'No violations recorded as of' 'APPEND-ONLY' 'Reality Checker' '5.1' '5.2' '5.3' '5.4' '5.5'; do grep -qF "$s" $F || { echo "MISSING: $s"; exit 1; }; done && { test $(grep -cF '**Class:** NON-ARXIV (LOWER-RIGOR)' $F) -ge 3 || { grep -qF 'NO CLASS C SOURCES FOUND' $F && grep -qF '**Search record:**' $F; }; } && test $(grep -cF '**Class:** NON-ARXIV (LOWER-RIGOR)' $F) -eq $(grep -cF '**URL:**' $F) && test $(grep -cE '^ *findings: *[0-9]+ BLOCKER */ *[0-9]+ MAJOR */ *[0-9]+ MINOR' $F) -ge 2 && test $(grep -cE 'disposition:' $F) -ge 2 && S=$(git log --reverse --format=%H -- control/spec/RESEARCH-REGISTER.md | head -1) && test -n "$S" && test $(git show --name-only --format="" HEAD | grep -c .) -eq 1 && git show --name-only --format="" HEAD | grep -qxF 'control/spec/RESEARCH-REGISTER.md' && SENT=control/.planning/phases/06B-research-venue-and-estimating-mev/.sentinel && test "$SENT/00-3.plank.before" -nt "$SENT/.runstart" && { test ! -e "${F:-/nonexistent}" || ! test "$SENT/00-3.plank.before" -nt "${F:-/nonexistent}"; } && diff -q "$SENT/00-3.plank.before" <(git -C ../plank status --porcelain | grep -v '^??') && diff -q "$SENT/00-3.lean4spec.before" <(git -C ../lean4-spec status --porcelain | grep -v '^??') && diff -q "$SENT/00-3.rootplanning.before" <(git status --porcelain .planning/) && echo "PASS first_sha=$S"</automated>
  </verify>
  <done>All three source classes are on the register with one block each; the lower-rigor class carries its restrictions and a source floor or an explicit null with a search record; §5 fixes the instrument-selection rule and closes the menu; §6 is append-only so downstream disclosure is never blocked; the review carries severity counts and dispositions; the first-commit sha is the downstream pin.</done>
</task>

</tasks>

<verification>
1. Roster: fourteen `INTERNAL-PDF` blocks with six fields, a locating anchor and a quoted
   sentence each — a label-only pass is impossible.
2. Every arXiv id resolved through the MCP with its returned title recorded.
3. No selection language in §2; the rule lives only in §5, written before any number exists.
4. Ordering is **recorded** by the register's FIRST commit `%ct` (`git log --reverse ... | head -1`),
   which downstream plans pin. `%ct` is not a proof — the Dune execution timestamp captured in
   `06B-02` is the independent measurement clock.
5. Peer trees and repo-root `.planning/` are **unchanged by this plan**, measured BEFORE vs AFTER.
</verification>

<success_criteria>
- `LIT-01` closed: fourteen PDFs, six fields plus an evidence anchor each, explicit transfer
  verdicts, no omissions.
- `LIT-02` closed: arXiv sweep with MCP-resolved identifiers, the block-time/realized-volatility
  instrument question answered, adversarial referee recorded with its true status.
- `LIT-03` closed: non-arXiv material tagged lower-rigor with a source floor or an explicit null;
  conflicts resolved toward peer review.
- The instrument-selection rule exists, is committed, and its first commit predates every
  dispersion measurement in this phase.
</success_criteria>

<output>
After completion, create
`/home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller/control/.planning/phases/06B-research-venue-and-estimating-mev/06B-00-SUMMARY.md`,
recording the `REGISTER FIRST COMMIT` line verbatim — downstream plans quote that sha and that
`%ct`.
</output>
