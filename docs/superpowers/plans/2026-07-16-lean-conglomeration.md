# Lean4 Conglomeration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Conglomerate all Lean4 Aristotle work into one buildable Lake project under `lean/` (three libs: `exp`, `vol_markets`, `tao`), with design docs on the `model/` layer and tarballs archived, per the approved spec `docs/superpowers/specs/2026-07-16-lean-conglomeration-design.md`.

**Architecture:** Two commits. Commit 1 moves all 24 tarballs to `lean/archive/` (3 canonical ones stay tracked, rest un-tracked/ignored). Commit 2 copies the canonical Lean modules and docs into place, replaces the Lake configuration (toolchain v4.28.0, mathlib v4.28.0, LeanEVM removed), rewrites `lean/README.md`, and lands only after a four-part verification gate (build, sorry census, axiom audit, clean-clone build) passes.

**Tech Stack:** Lean 4 (v4.28.0), Lake, mathlib4 tag `v4.28.0` (rev `8f9d9cff6bd728b17a24e163c9402775d9e6a365`), git.

## Global Constraints

- Working directory: `/home/jmsbpp/cfmms-playground/cfmm-wt/lean4-spec`, branch `feat/lean4-spec`. Never edit the main checkout or other worktrees.
- Toolchain pin: `leanprover/lean4:v4.28.0`. Mathlib requirement: `rev = "v4.28.0"`.
- **No new proofs, no theorem or namespace renames, no edits to `.lean` content** except the 3 specified `import RequestProject.X → import vol_markets.X` lines.
- From family-1 tarballs, take **`exp/`-path** `.lean` files only — top-level `eta.lean`/`CESLongVolPayoff.lean` are pre-proof input copies (FOCThree's top-level CES still contains a `sorry`).
- `lean/exp/eta.lean` and `lean/exp/CESLongVolPayoff.lean` in the repo are the source of truth — do not overwrite them.
- Scratch space: `/tmp/claude-1000/-home-jmsbpp-cfmms-playground-cfmm-wt-lean4-spec/c66bd6ec-5a5f-4ab9-98e8-661e1c88a3b5/scratchpad/` (referred to below as `$SCRATCH`).
- Network is required in Tasks 6 AND 7 (elan toolchain download + multi-GB mathlib olean cache in Task 6; the clean clone in Task 7 still fetches the mathlib *source* repo from GitHub before the shared olean cache applies).
- `$SCRATCH` does not persist between shell invocations — every command block that uses it re-defines it on its first line.
- Do not touch: `model/exp/eta.md`, `model/exp/eta_pi_trader_delta_control.md`, the stray file `bpp@hotmail.es>` (trailing `>` is part of the name), anything outside this worktree.

---

### Task 1: Archive all tarballs (Commit 1)

**Files:**
- Create: `lean/archive/` (24 tarballs moved in)
- Modify: `.gitignore` (append 4 lines)
- Delete from index (not disk): 11 superseded tracked tarballs

**Interfaces:**
- Produces: `lean/archive/aristotleFOCThree.tar.gz`, `lean/archive/9804c2b5-a6a5-4a7f-a67b-89119b4b7bfb-aristotle.tar.gz`, `lean/archive/arsitotleTaoCFMM.tar.gz` (tracked; Tasks 2–3 extract from these), plus 21 un-tracked archived tarballs.

- [ ] **Step 1: Append gitignore rules**

Append to `.gitignore` (repo root — keep the existing `lean/.aristotle-*.tar.gz` rule; it still covers future Aristotle downloads landing in `lean/`):

```gitignore

# Aristotle archive: only the canonical latest tarball per proof family is tracked
lean/archive/*
!lean/archive/aristotleFOCThree.tar.gz
!lean/archive/9804c2b5-a6a5-4a7f-a67b-89119b4b7bfb-aristotle.tar.gz
!lean/archive/arsitotleTaoCFMM.tar.gz
```

- [ ] **Step 2: Move all 24 tarballs into lean/archive/**

```bash
cd /home/jmsbpp/cfmms-playground/cfmm-wt/lean4-spec/lean
mkdir -p archive
# 13 tracked: git mv (11 in lean/ + 2 in vol_markets/)
git mv 88d393e7-ec4e-438f-a5fd-9f34aab1c2e5-aristotle.tar.gz \
       aristotleFOCLongVar1.tar.gz aristotleFOCLongVol2.tar.gz \
       aristotleFOCThree.tar.gz aristotleLiquPayoffs.tar.gz \
       aristotleMeanVariance.tar.gz aristotleMeanVarianceCompStatics.tar.gz \
       aristotleMeanVarianceOptimizationRaw.tar.gz \
       aristotleSequencesInit.tar.gz aristotleSocialChoice.tar.gz \
       arsitotleTaoCFMM.tar.gz archive/
git mv vol_markets/aristotle_collateral_schedule_raw.tar.gz \
       vol_markets/aristotle_tbd.tar.gz archive/
# 11 untracked/ignored: plain mv (1 visible + 10 hidden)
mv 9804c2b5-a6a5-4a7f-a67b-89119b4b7bfb-aristotle.tar.gz archive/
mv .aristotle-final.tar.gz .aristotle-out.tar.gz .aristotle-out2.tar.gz \
   .aristotle-out3.tar.gz .aristotle-out4.tar.gz .aristotle-out5.tar.gz \
   .aristotle-out8.tar.gz .aristotle-out10.tar.gz .aristotle-out12.tar.gz \
   .aristotle-out13.tar.gz archive/
```

- [ ] **Step 3: Un-track the 11 superseded tracked tarballs; track the canonical untracked one**

```bash
cd /home/jmsbpp/cfmms-playground/cfmm-wt/lean4-spec
git rm --cached \
  lean/archive/88d393e7-ec4e-438f-a5fd-9f34aab1c2e5-aristotle.tar.gz \
  lean/archive/aristotleFOCLongVar1.tar.gz \
  lean/archive/aristotleFOCLongVol2.tar.gz \
  lean/archive/aristotleLiquPayoffs.tar.gz \
  lean/archive/aristotleMeanVariance.tar.gz \
  lean/archive/aristotleMeanVarianceCompStatics.tar.gz \
  lean/archive/aristotleMeanVarianceOptimizationRaw.tar.gz \
  lean/archive/aristotleSequencesInit.tar.gz \
  lean/archive/aristotleSocialChoice.tar.gz \
  lean/archive/aristotle_collateral_schedule_raw.tar.gz \
  lean/archive/aristotle_tbd.tar.gz
git add .gitignore
git add lean/archive/9804c2b5-a6a5-4a7f-a67b-89119b4b7bfb-aristotle.tar.gz
```
(Two separate `git add`s: if the tarball pathspec fails to match — e.g. Step 2
didn't run — the `.gitignore` staging must not be lost with it.)

- [ ] **Step 4: Verify index state**

```bash
git ls-files lean/archive/
```
Expected: exactly 3 lines — `aristotleFOCThree.tar.gz`, `9804c2b5-a6a5-4a7f-a67b-89119b4b7bfb-aristotle.tar.gz`, `arsitotleTaoCFMM.tar.gz` (with `lean/archive/` prefix).

```bash
git status --porcelain | grep -c 'tar.gz'
ls lean/archive/ | wc -l; ls -A lean/archive/ | wc -l
```
Expected: `ls -A` counts 24 files (14 visible + 10 hidden); `git status` shows renames/deletes staged, no untracked tarballs anywhere outside `lean/archive/`.

- [ ] **Step 5: Commit 1**

```bash
git commit -m "chore(lean): archive all 24 aristotle tarballs; track canonical 3 only

Superseded run tarballs leave the index (history retains them);
lean/archive/ is gitignored except the canonical latest per family.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 2: Copy Lean modules from the 3 canonical tarballs

**Files:**
- Create: `lean/exp/{EtaReplication,EtaPartitionChange,EtaLiquidityPayoff,SocialChoiceParameters,MeanVarianceEta,EtaIndexConsistency,MeanVarianceOptimization,ComparativeStatics,EnvelopeTheorem,DynamicsOptimization,BondingCurveCurvature,InventoryObserverDynamics}.lean` (12)
- Create: `lean/vol_markets/{Main,PosSpec,Flow,RiskDesign}.lean` (4)
- Create: `lean/tao/{AMM,Injection,Halving,Rewards,GBM,APY,Model,Main}.lean` (8)

**Interfaces:**
- Consumes: the 3 tracked tarballs in `lean/archive/` (Task 1).
- Produces: 24 module files whose module names (`exp.X`, `vol_markets.X`, `tao.X`) Task 4's lakefile roots reference verbatim. Extraction dir `$SCRATCH/canon/{foc,vm,tao}` reused by Task 3.

- [ ] **Step 1: Extract the 3 canonical tarballs to scratch**

```bash
SCRATCH=/tmp/claude-1000/-home-jmsbpp-cfmms-playground-cfmm-wt-lean4-spec/c66bd6ec-5a5f-4ab9-98e8-661e1c88a3b5/scratchpad
cd /home/jmsbpp/cfmms-playground/cfmm-wt/lean4-spec/lean/archive
mkdir -p "$SCRATCH/canon/foc" "$SCRATCH/canon/vm" "$SCRATCH/canon/tao"
tar -xzf aristotleFOCThree.tar.gz -C "$SCRATCH/canon/foc" --strip-components=1
tar -xzf 9804c2b5-a6a5-4a7f-a67b-89119b4b7bfb-aristotle.tar.gz -C "$SCRATCH/canon/vm" --strip-components=1
tar -xzf arsitotleTaoCFMM.tar.gz -C "$SCRATCH/canon/tao" --strip-components=1
ls "$SCRATCH/canon/foc/exp/" "$SCRATCH/canon/vm/RequestProject/" "$SCRATCH/canon/tao/RequestProject/"
```
Expected: `foc/exp/` shows 14 `.lean` (12 new modules + `eta.lean` + `CESLongVolPayoff.lean`) + 9 `.md`; `vm/RequestProject/` shows `Main.lean PosSpec.lean Flow.lean RiskDesign.lean`; `tao/RequestProject/` shows the 8 tao `.lean` files.

- [ ] **Step 2: Copy the 12 new exp modules (exp/ paths only; do NOT overwrite eta.lean / CESLongVolPayoff.lean)**

```bash
SCRATCH=/tmp/claude-1000/-home-jmsbpp-cfmms-playground-cfmm-wt-lean4-spec/c66bd6ec-5a5f-4ab9-98e8-661e1c88a3b5/scratchpad
cd /home/jmsbpp/cfmms-playground/cfmm-wt/lean4-spec/lean
for m in EtaReplication EtaPartitionChange EtaLiquidityPayoff \
         SocialChoiceParameters MeanVarianceEta EtaIndexConsistency \
         MeanVarianceOptimization ComparativeStatics EnvelopeTheorem \
         DynamicsOptimization BondingCurveCurvature InventoryObserverDynamics; do
  cp "$SCRATCH/canon/foc/exp/$m.lean" exp/
done
```

- [ ] **Step 3: Copy vol_markets modules and rewrite the 3 import lines**

```bash
SCRATCH=/tmp/claude-1000/-home-jmsbpp-cfmms-playground-cfmm-wt-lean4-spec/c66bd6ec-5a5f-4ab9-98e8-661e1c88a3b5/scratchpad
cd /home/jmsbpp/cfmms-playground/cfmm-wt/lean4-spec/lean
mkdir -p vol_markets tao
cp "$SCRATCH/canon/vm/RequestProject/"{Main,PosSpec,Flow,RiskDesign}.lean vol_markets/
sed -i 's/^import RequestProject\./import vol_markets./' vol_markets/Flow.lean vol_markets/RiskDesign.lean
```
(The 3 rewritten lines: `PosSpec` in `Flow.lean`; `Main` and `Flow` in `RiskDesign.lean`. `Main.lean` and `PosSpec.lean` import only Mathlib — sed on them would be a no-op and is not run.)

- [ ] **Step 4: Copy tao modules (no edits — they import only Mathlib)**

```bash
SCRATCH=/tmp/claude-1000/-home-jmsbpp-cfmms-playground-cfmm-wt-lean4-spec/c66bd6ec-5a5f-4ab9-98e8-661e1c88a3b5/scratchpad
cd /home/jmsbpp/cfmms-playground/cfmm-wt/lean4-spec/lean
cp "$SCRATCH/canon/tao/RequestProject/"{AMM,Injection,Halving,Rewards,GBM,APY,Model,Main}.lean tao/
```

- [ ] **Step 5: Verify copies**

```bash
SCRATCH=/tmp/claude-1000/-home-jmsbpp-cfmms-playground-cfmm-wt-lean4-spec/c66bd6ec-5a5f-4ab9-98e8-661e1c88a3b5/scratchpad
cd /home/jmsbpp/cfmms-playground/cfmm-wt/lean4-spec/lean
ls exp/*.lean | wc -l; ls vol_markets/*.lean | wc -l; ls tao/*.lean | wc -l
grep -rn 'import RequestProject' exp vol_markets tao; echo "grep-exit=$?"
git diff --stat -- exp/eta.lean exp/CESLongVolPayoff.lean
diff <(sed 's/^import RequestProject\./import vol_markets./' "$SCRATCH/canon/vm/RequestProject/Flow.lean") vol_markets/Flow.lean && echo FLOW-OK
```
Expected: counts `14 4 8`; the `import RequestProject` grep finds nothing (`grep-exit=1`); `git diff` empty for the two protected files; `FLOW-OK` printed (proves the rewrite touched only import lines).

*(No commit yet — commit 2 lands after the verification gate in Task 6.)*

---

### Task 3: Place design docs on the model/ layer

**Files:**
- Create: `model/exp/aristotle/` — 9 module docs + `ARISTOTLE_SUMMARY.md` + `monotoneCompStatics.pdf` + `monotoneCompStaticsTwo.pdf` (12 files)
- Create: `model/vol_markets/` — `SCHEDULE.md pos_spec.md tbd.md tbd2.md RISK_ALTERNATIVES.md DESIGN_SPACE.md risk.md exposure.md ARISTOTLE_SUMMARY.md` (9 files)
- Create: `model/tao/` — `CONSISTENCY_REPORT.md ARISTOTLE_SUMMARY.md` (2 files)

**Interfaces:**
- Consumes: `$SCRATCH/canon/{foc,vm,tao}` from Task 2 Step 1.
- Produces: `model/vol_markets/` paths that Task 7 announces to the plank session.

- [ ] **Step 1: Copy family-1 docs**

```bash
SCRATCH=/tmp/claude-1000/-home-jmsbpp-cfmms-playground-cfmm-wt-lean4-spec/c66bd6ec-5a5f-4ab9-98e8-661e1c88a3b5/scratchpad
cd /home/jmsbpp/cfmms-playground/cfmm-wt/lean4-spec
mkdir -p model/exp/aristotle model/vol_markets model/tao
cp "$SCRATCH/canon/foc/exp/"*.md model/exp/aristotle/
cp "$SCRATCH/canon/foc/ARISTOTLE_SUMMARY.md" \
   "$SCRATCH/canon/foc/monotoneCompStatics.pdf" \
   "$SCRATCH/canon/foc/monotoneCompStaticsTwo.pdf" model/exp/aristotle/
```

- [ ] **Step 2: Copy family-2 docs (from 9804c2b5 ONLY — collateral_schedule_raw copies of tbd.md/pos_spec.md are stale)**

```bash
SCRATCH=/tmp/claude-1000/-home-jmsbpp-cfmms-playground-cfmm-wt-lean4-spec/c66bd6ec-5a5f-4ab9-98e8-661e1c88a3b5/scratchpad
cd /home/jmsbpp/cfmms-playground/cfmm-wt/lean4-spec
cp "$SCRATCH/canon/vm/"{SCHEDULE.md,pos_spec.md,tbd.md,tbd2.md,RISK_ALTERNATIVES.md,DESIGN_SPACE.md,risk.md,exposure.md,ARISTOTLE_SUMMARY.md} model/vol_markets/
```

- [ ] **Step 3: Copy family-3 docs**

```bash
SCRATCH=/tmp/claude-1000/-home-jmsbpp-cfmms-playground-cfmm-wt-lean4-spec/c66bd6ec-5a5f-4ab9-98e8-661e1c88a3b5/scratchpad
cd /home/jmsbpp/cfmms-playground/cfmm-wt/lean4-spec
cp "$SCRATCH/canon/tao/"{CONSISTENCY_REPORT.md,ARISTOTLE_SUMMARY.md} model/tao/
```

- [ ] **Step 4: Verify**

```bash
ls model/exp/aristotle/ | wc -l; ls model/vol_markets/ | wc -l; ls model/tao/ | wc -l
```
Expected: `12 9 2`. (The tarballs' `README.md`/`lakefile.toml`/`lake-manifest.json`/`lean-toolchain` are Aristotle project boilerplate — deliberately not copied.)

---

### Task 4: Replace Lake configuration

**Files:**
- Modify: `lean/lakefile.toml` (full replacement)
- Modify: `lean/lean-toolchain` (full replacement)
- Modify: `lean/lake-manifest.json` (copied from tarball + 1-line name edit)
- Delete (disk, gitignored): `lean/.lake/`

**Interfaces:**
- Consumes: module files from Task 2 (root names must match exactly).
- Produces: buildable Lake config for Task 6's gate; lib targets `exp`, `vol_markets`, `tao`.

- [ ] **Step 1: Write `lean/lean-toolchain`**

```
leanprover/lean4:v4.28.0
```

- [ ] **Step 2: Write `lean/lakefile.toml` (full content)**

```toml
name = "cfmmReplicationPlank"
defaultTargets = ["exp", "vol_markets", "tao"]

[[require]]
name = "mathlib"
git = "https://github.com/leanprover-community/mathlib4.git"
rev = "v4.28.0"

# LeanEVM (Philogy/LeanEVM @ ab5e33949f9053a494b05ab0143f9ca92567eb4a) removed
# 2026-07-16: nothing imports it and its pinned rev requires toolchain v4.30.0.
# Restore both together when on-chain proofs begin.

[[lean_lib]]
name = "exp"
srcDir = "."
roots = ["exp.eta", "exp.CESLongVolPayoff", "exp.EtaReplication",
  "exp.EtaPartitionChange", "exp.EtaLiquidityPayoff",
  "exp.SocialChoiceParameters", "exp.MeanVarianceEta",
  "exp.EtaIndexConsistency", "exp.MeanVarianceOptimization",
  "exp.ComparativeStatics", "exp.EnvelopeTheorem",
  "exp.DynamicsOptimization", "exp.BondingCurveCurvature",
  "exp.InventoryObserverDynamics"]

[[lean_lib]]
name = "vol_markets"
srcDir = "."
roots = ["vol_markets.Main", "vol_markets.PosSpec", "vol_markets.Flow",
  "vol_markets.RiskDesign"]

[[lean_lib]]
name = "tao"
srcDir = "."
roots = ["tao.AMM", "tao.Injection", "tao.Halving", "tao.Rewards",
  "tao.GBM", "tao.APY", "tao.Model", "tao.Main"]
```

- [ ] **Step 3: Copy the manifest and fix its root-package name**

```bash
SCRATCH=/tmp/claude-1000/-home-jmsbpp-cfmms-playground-cfmm-wt-lean4-spec/c66bd6ec-5a5f-4ab9-98e8-661e1c88a3b5/scratchpad
cd /home/jmsbpp/cfmms-playground/cfmm-wt/lean4-spec/lean
cp "$SCRATCH/canon/vm/lake-manifest.json" lake-manifest.json
sed -i 's/"name": "RequestProject"/"name": "cfmmReplicationPlank"/' lake-manifest.json
grep -c '"rev": "8f9d9cff6bd728b17a24e163c9402775d9e6a365"' lake-manifest.json
```
Expected: grep prints `1` (mathlib pinned to the v4.28.0 tag commit).
Fallback if Task 6's build rejects the manifest: `rm lake-manifest.json && lake update mathlib` — deterministic, since the requirement pins tag `v4.28.0`.

- [ ] **Step 4: Purge stale build state (v4.30/LeanEVM artifacts)**

```bash
rm -rf /home/jmsbpp/cfmms-playground/cfmm-wt/lean4-spec/lean/.lake
```

---

### Task 5: Rewrite `lean/README.md`

**Files:**
- Modify: `lean/README.md` (full replacement)

**Interfaces:**
- Consumes: sha256 table generated by the command in Step 1.
- Produces: the documented policies (naming deviation, cross-family imports, archive durability) the spec requires.

- [ ] **Step 1: Generate the archive provenance rows**

```bash
cd /home/jmsbpp/cfmms-playground/cfmm-wt/lean4-spec/lean/archive
for f in *.tar.gz .*.tar.gz; do
  printf '| `%s` | %s | %s | %s |\n' "$f" "$(sha256sum "$f" | cut -c1-16)…" \
    "$(stat -c %y "$f" | cut -d' ' -f1)" "$(stat -c %s "$f")"
done
```
Paste the 24 output rows into the `<!-- PROVENANCE ROWS -->` slot in Step 2's content.

- [ ] **Step 2: Write `lean/README.md` (full content; one generated-table insertion)**

````markdown
# `lean/` — Lean4 formalization layer

Formal (machine-checked) counterpart of the `model/` markdown layer.
Convention: markdown math/design specs live under `model/`; their Lean
formalizations live here under the same family name.

## Build

```bash
cd lean
lake exe cache get   # multi-GB mathlib cache; network required
lake build           # builds all three libs: exp, vol_markets, tao
```

Toolchain: `leanprover/lean4:v4.28.0` (matches the toolchain all canonical
Aristotle runs were proven under). Mathlib: tag `v4.28.0`
(rev `8f9d9cff6bd728b17a24e163c9402775d9e6a365`).

**LeanEVM removed 2026-07-16**: nothing imported it and its pinned rev
(`Philogy/LeanEVM @ ab5e33949f9053a494b05ab0143f9ca92567eb4a`) requires
toolchain v4.30.0. Restore the `[[require]]` and the v4.30 toolchain
together when on-chain proofs begin.

## Libraries (three independent proof families)

| Lib | Modules | Proves | Docs (model layer) |
|---|---|---|---|
| `exp` | `eta`, `CESLongVolPayoff`, `EtaReplication`, `EtaPartitionChange`, `EtaLiquidityPayoff`, `SocialChoiceParameters`, `MeanVarianceEta`, `EtaIndexConsistency`, `MeanVarianceOptimization`, `ComparativeStatics`, `EnvelopeTheorem`, `DynamicsOptimization`, `BondingCurveCurvature`, `InventoryObserverDynamics` | η bonding-curve trading invariant, band optimization, FOC/comparative statics, mean-variance | `model/exp/`, `model/exp/aristotle/` |
| `vol_markets` | `Main`, `PosSpec`, `Flow`, `RiskDesign` | admissible region, skew-tick position map, bang-bang collateral schedule (`Flow.schedule_isLeast`), risk-design (`p_risk = oracle/(1−h)`) | `model/vol_markets/` (consumed by the plank worktree) |
| `tao` | `AMM`, `Injection`, `Halving`, `Rewards`, `GBM`, `APY`, `Model`, `Main` | DTAO investment-market consistency (corrections C1–C3) | `model/tao/` |

Aliases: `tao` ↔ DTAO/TaoCFMM. Modules `vol_markets.X` were named
`RequestProject.X` inside Aristotle runs — read run summaries with that map.

## Naming & import policy (deliberate deviations)

- Module prefixes are lowercase/snake_case (`exp.eta`, `vol_markets.Main`),
  deviating from Mathlib UpperCamelCase — they are byte-what-Aristotle-proved.
  Renaming is a conscious re-verification event, not a drive-by cleanup.
- Cross-family imports are technically possible (shared `srcDir`) but
  **allowed only via explicit recorded decision**; Lake will not police the
  boundary. Today there are none.

## Proof status

**Zero code `sorry`s.** The three `grep -w sorry` hits are comment prose:
`exp/eta.lean:602` (describes the *absent* small-trade band-max theorem —
future Aristotle work), `exp/DynamicsOptimization.lean:23` and
`exp/BondingCurveCurvature.lean:26` ("no sorry" notes). Flagship theorems
depend only on `propext`, `Classical.choice`, `Quot.sound`.

## Provenance

Canonical runs (tracked in `archive/`): `aristotleFOCThree.tar.gz`
(family exp, Jun 30 2026), `9804c2b5-a6a5-4a7f-a67b-89119b4b7bfb-aristotle.tar.gz`
(family vol_markets, Jul 15 2026),
`arsitotleTaoCFMM.tar.gz` (family tao, Jun 30 2026). All other archived
tarballs are superseded runs/drafts; every shared `.lean` file was verified
byte-identical to the canonical copy except
`aristotleMeanVariance/exp/MeanVarianceEta.lean` (pre-`noncomputable` draft).
Family-1 tarballs also carry top-level pre-proof *input* copies of
`eta.lean`/`CESLongVolPayoff.lean` — the `exp/`-path copies are the proven
ones. `exp/eta.lean` here is a strict superset of the FOCThree copy
(adds the tick-spacing optimization section, commit `841df7b`).

Archive integrity (only the 3 canonical tarballs are tracked; verify any
recovered tarball against this table — recovery source: git history for the
formerly-tracked tarballs, another machine/disk copy for the never-tracked
`.aristotle-*` drafts, which were gitignored from the start):

| Tarball | sha256 (first 16) | Date | Bytes |
|---|---|---|---|
<!-- PROVENANCE ROWS -->

Policy for future runs: download to `archive/` (ignored by default), verify
supersession, then track the new canonical tarball and un-track the one it
replaces; append its row here.

## Theorem-proving workflow (Aristotle)

State theorems with `sorry` placeholders, then submit:

```bash
export ARISTOTLE_API_KEY=...   # in your shell, never in chat
aristotle submit "Fill in all sorries in exp/eta.lean" \
  --project-dir ./lean --wait \
  --destination ./lean/archive/<descriptive-name>.tar.gz
```

One in-flight Aristotle task at a time — never queue submissions
(`--files` upload overwrites the prior task's server-side proof).
````

- [ ] **Step 3: Verify the placeholder was replaced**

```bash
grep -c 'PROVENANCE ROWS' /home/jmsbpp/cfmms-playground/cfmm-wt/lean4-spec/lean/README.md
grep -c '| `' /home/jmsbpp/cfmms-playground/cfmm-wt/lean4-spec/lean/README.md
```
Expected: `PROVENANCE ROWS` count `0` (comment removed when rows pasted); at least 24 table rows containing `` | ` ``.

---

### Task 6: Verification gate, then Commit 2

**Files:**
- Create (temporary, deleted before commit): `lean/AxiomAudit.lean`
- Commit: everything from Tasks 2–5

**Interfaces:**
- Consumes: all prior tasks.
- Produces: commit 2 on `feat/lean4-spec`.

- [ ] **Step 1: Build (network required; expect long first run)**

```bash
cd /home/jmsbpp/cfmms-playground/cfmm-wt/lean4-spec/lean
lake exe cache get
lake build
```
Expected: `lake build` exits 0 having built all three default targets. If it
fails on manifest resolution, apply the Task 4 Step 3 fallback and retry. If a
`.lean` file fails elaboration, STOP — report the error verbatim; do not "fix"
proofs (spec risk table: only `exp/eta.lean`'s superset section is expected to
possibly break; that is a user decision + Aristotle resubmission, not an
inline edit).

- [ ] **Step 2: Sorry census**

```bash
grep -rn -w sorry exp vol_markets tao --include='*.lean'
```
Expected: exactly 3 hits, all comment prose:
```
exp/eta.lean:602:        Substantive; left as `sorry` for Aristotle.
exp/DynamicsOptimization.lean:23:...(all proved, no `sorry`)...
exp/BondingCurveCurvature.lean:26:...no `sorry`...
```
Any hit outside these three lines = FAIL (likely a miscopied superseded file).

- [ ] **Step 3: Axiom audit**

```bash
grep -rn '^axiom' exp vol_markets tao --include='*.lean'; echo "axiom-exit=$?"
cat > AxiomAudit.lean <<'EOF'
import exp.eta
import vol_markets.Flow
import tao.Halving
#print axioms CFMM.Eta.pi_trader_half_band_min_at_left
#print axioms Flow.schedule_isLeast
#print axioms DTAO.Halving.total_supply
EOF
lake env lean AxiomAudit.lean
rm AxiomAudit.lean
```
Expected: `axiom-exit=1` (zero axiom declarations); each `#print axioms` line
reports only `propext`, `Classical.choice`, `Quot.sound` (a subset is also
fine). Anything else = FAIL, report verbatim.

- [ ] **Step 4: Commit 2**

```bash
cd /home/jmsbpp/cfmms-playground/cfmm-wt/lean4-spec
git add lean/exp lean/vol_markets lean/tao lean/lakefile.toml \
        lean/lean-toolchain lean/lake-manifest.json lean/README.md \
        model/exp/aristotle model/vol_markets model/tao
# Guard: everything must be cleanly staged; only the 3 known out-of-scope
# leftovers may remain. Catches partially-staged files (AM/MM/RM) too.
LEFT=$(git status --porcelain | grep -v '^[AMR]  ' \
  | grep -vxF -e ' M model/exp/eta.md' \
              -e '?? model/exp/eta_pi_trader_delta_control.md' \
              -e '?? bpp@hotmail.es>')
[ -z "$LEFT" ] && echo GUARD-PASS || { echo "GUARD-FAIL — unexpected working-tree state:"; echo "$LEFT"; }
git commit -m "feat(lean): conglomerate all aristotle work into one Lake project

Three libs: exp (14 modules, η invariant), vol_markets (4 modules,
collateral schedule + risk design, ex-RequestProject), tao (8 modules,
DTAO consistency). Toolchain v4.28.0, mathlib v4.28.0, LeanEVM deferred.
Design docs on the model/ layer (model/exp/aristotle, model/vol_markets,
model/tao). Gate: lake build green, sorry census clean (0 code sorries),
axiom audit = propext/Classical.choice/Quot.sound only.

Per docs/superpowers/specs/2026-07-16-lean-conglomeration-design.md.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```
Expected: `GUARD-PASS` printed before the commit runs. On `GUARD-FAIL`, stop
and resolve: an `AM`/`MM`/`RM` line means a file was edited after staging
(re-`git add` it); any other unexpected line is out-of-plan working-tree
state. The whitelist is exactly the three pre-existing out-of-scope items
(note the stray file's real name ends in `>`: `bpp@hotmail.es>`).

---

### Task 7: Clean-clone gate + plank notification

**Files:**
- None in the repo (scratch clone only)

**Interfaces:**
- Consumes: commit 2 (Task 6).
- Produces: green clean-clone build; a claude-peers message to agent `ul2inqpl`.

- [ ] **Step 1: Clean-clone build (proves no dependence on un-tracked archive/ or stale .lake)**

```bash
SCRATCH=/tmp/claude-1000/-home-jmsbpp-cfmms-playground-cfmm-wt-lean4-spec/c66bd6ec-5a5f-4ab9-98e8-661e1c88a3b5/scratchpad
rm -rf "$SCRATCH/clean-clone"
git clone --branch feat/lean4-spec /home/jmsbpp/cfmms-playground/cfmm-wt/lean4-spec "$SCRATCH/clean-clone"
cd "$SCRATCH/clean-clone/lean"
lake exe cache get   # network required: fetches the mathlib SOURCE repo from
                     # GitHub first; the olean cache then hits ~/.cache/mathlib
lake build
```
Expected: exits 0. If it fails while the Task 6 build passed, the diff is a
missing tracked file — fix by `git add`ing it in the worktree and
`git commit --amend --no-edit`, then re-run this step.

- [ ] **Step 2: Notify the plank session**

Send via claude-peers `send_message` to agent id `ul2inqpl`:

> Lean conglomeration landed on feat/lean4-spec. Canonical EVM design docs for
> the collateral-schedule/risk module now live at `model/vol_markets/`
> (SCHEDULE.md, pos_spec.md, tbd.md, RISK_ALTERNATIVES.md, DESIGN_SPACE.md,
> risk.md, exposure.md) — proven backbone in `lean/vol_markets/` (Flow.schedule_isLeast
> bang-bang controller consumes your realized-vol oracle; RiskDesign has the
> p_risk = oracle/(1−h) convention and X96 rounding proofs).

- [ ] **Step 3: Report gate results to the user**

Summarize: build status, sorry census, axiom audit output, clean-clone result,
the two commit hashes, and any deviations.

---

## Self-Review (completed by plan author)

- **Spec coverage:** archive policy → Task 1; source-of-truth table (Lean) → Task 2; docs/PDFs/summaries → Task 3; lakefile/toolchain/manifest/.lake → Task 4; README (provenance sha256, ledger, policies, aliases, workflow) → Task 5; four-part gate + two commits → Tasks 1, 6, 7; plank notification → Task 7. No spec item unmapped.
- **Placeholder scan:** the single `<!-- PROVENANCE ROWS -->` slot is generated data with an exact generation command and a verification step that it was replaced — no TBDs remain.
- **Consistency:** lakefile roots (Task 4) match filenames created in Task 2 one-to-one; axiom-audit names verified against actual sources (`CFMM.Eta.pi_trader_half_band_min_at_left` at eta.lean:477, `Flow.schedule_isLeast` at Flow.lean:172, `DTAO.Halving.total_supply` at Halving.lean:25); tarball lists in Task 1 verified against `git ls-files` (13 tracked) and disk (24 total).
