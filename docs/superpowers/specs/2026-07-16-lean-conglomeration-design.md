# Lean4 conglomeration — design spec

**Date:** 2026-07-16
**Session:** Lean4 + Math (feat/lean4-spec worktree)
**Status:** reviewed — Reality Checker + Software Architect findings resolved (rev 2)

## Goal

Reconcile all Lean4 work produced to date — 24 Aristotle output tarballs plus the
checked-in `lean/` files — into a single, buildable Lake project under `lean/`.
Structure only: no new proofs, no theorem renames.

## Scan findings (evidence base)

Three independent proof families exist. Supersession evidence (restated
precisely after review):

- For the **14 named tarballs**, all shared `.lean` files across successive runs
  were verified byte-identical, with one exception: `exp/MeanVarianceEta.lean`
  in `aristotleMeanVariance` differs from later runs (FOCThree added
  `noncomputable` on `def MV`). The FOCThree copy wins (it is the version the
  downstream modules elaborated against).
- The **10 hidden `.aristotle-out*` / `.aristotle-final` tarballs** are early
  iteration drafts of `eta.lean`: `out5/out8/out10/out12/out13` carry
  `exp/eta.lean` byte-identical to FOCThree's 446-line version; the earlier
  ones are shorter drafts. All are superseded; none contributes content.
- Byte-identity does **not** hold for non-Lean docs across family-2 runs
  (`tbd.md`, `pos_spec.md`, `ARISTOTLE_SUMMARY.md` differ between
  `collateral_schedule_raw` and `9804c2b5`) — hence the single-source rule
  below: **all family-2 docs come from `9804c2b5` only** (it contains all 9,
  including `risk.md`/`exposure.md` which exist nowhere else).

### Family 1 — η / `exp` (bonding-curve trading invariant)

Canonical run: **`aristotleFOCThree`** (Jun 30, superset, 14 modules, proven
under v4.28.0): `eta`, `CESLongVolPayoff`, `EtaReplication`,
`EtaPartitionChange`, `EtaLiquidityPayoff`, `SocialChoiceParameters`,
`MeanVarianceEta`, `EtaIndexConsistency`, `MeanVarianceOptimization`,
`ComparativeStatics`, `EnvelopeTheorem`, `DynamicsOptimization`,
`BondingCurveCurvature`, `InventoryObserverDynamics`.

Special cases:
- The checked-in `lean/exp/eta.lean` (731 lines, commit `841df7b`) is a
  **strict superset** of FOCThree's (446 lines; diff is one pure deletion
  block, the tick-spacing optimization section). Repo copy wins; FOCThree's 12
  new modules import only the shared prefix.
- Family-1 tarballs also carry **top-level** `eta.lean`/`CESLongVolPayoff.lean`
  *input* copies (FOCThree's top-level CES still contains its pre-proof
  `sorry`). Executors must take the `exp/`-path copies only.
- FOCThree additionally ships 9 companion module docs
  (`exp/<Module>.md`), `ARISTOTLE_SUMMARY.md`, and 2 PDFs
  (`monotoneCompStatics.pdf`, `monotoneCompStaticsTwo.pdf`) — migrated, see
  source-of-truth table.

Import DAG root: `exp.eta` (7 modules import it; all use `import exp.X`
style already — zero edits needed).

### Family 2 — `RequestProject` / vol-markets (collateral schedule + risk design)

Canonical run: **`9804c2b5-…-aristotle.tar.gz`** (Jul 15, newest artifact
overall, currently untracked; proven under v4.28.0, sorry-free). Modules:
`Main`, `PosSpec`, `Flow`, `RiskDesign`. The `.lean` chain
`tbd ⊂ collateral_schedule_raw ⊂ 9804c2b5` is byte-identical (verified);
the docs chain is **not** — single-source rule applies.

### Family 3 — TaoCFMM (DTAO investment-market model)

Single run `arsitotleTaoCFMM` (Jun 30, proven under v4.28.0, sorry-free).
Modules: `AMM`, `Injection`, `Halving`, `Rewards`, `GBM`, `APY`, `Model`,
`Main`. Imports only Mathlib. Ships `CONSISTENCY_REPORT.md` (corrections
C1–C3) and `ARISTOTLE_SUMMARY.md`.

### Proof-status ledger (corrected after review)

There are **zero code `sorry`s** in any file being shipped (exhaustive
`grep -n -w sorry` over the repo file and all canonical-run modules; the 3
hits are comment prose). The real ledger is:

| Item | Status |
|---|---|
| Small-trade band-max theorem (`exp/eta.lean:602` comment) | **theorem absent** — noted for a future Aristotle run, not a sorried proof |
| All 14 exp modules, 4 vol_markets modules, 8 tao modules | proven, no `sorry`/`admit`; per run summaries, only standard axioms |

## Decisions

User-confirmed 2026-07-16:

1. **Structure:** single Lake package, domain directories, three `lean_lib`
   targets (`exp`, `vol_markets`, `tao`).
2. **Toolchain:** `leanprover/lean4:v4.28.0`, mathlib tag `v4.28.0`
   (= rev `8f9d9cf`, verified against the live remote; identical pin across
   all three canonical runs). LeanEVM requirement **removed for now**
   (nothing imports it; its pinned rev
   `ab5e33949f9053a494b05ab0143f9ca92567eb4a` requires v4.30 — recorded in the
   README so it can be restored when on-chain proofs start).
3. **Tarballs:** moved to `lean/archive/` and un-tracked — with the
   durability policy below (review finding).

Review-driven decisions (rev 2 — **flagged for user veto at spec review**):

4. **Design docs go to the `model/` layer, not inside `lean/`** (Software
   Architect M1). The repo convention is "`lean/` mirrors `model/`; markdown
   specs live in `model/`, Lean counterparts in `lean/`" — and the plank
   worktree consumes these docs. So: `model/vol_markets/` receives the 9
   family-2 docs; `model/tao/` receives `CONSISTENCY_REPORT.md` +
   `ARISTOTLE_SUMMARY.md`; FOCThree's 9 companion module docs + summary + 2
   PDFs go to `model/exp/aristotle/`. This relaxes the previous "no changes
   outside `lean/`" constraint — deliberately, to preserve the mirror
   convention. The plank session (`ul2inqpl`) gets notified of the canonical
   paths after the migration lands.
5. **Archive durability policy** (Architect M3): the three canonical tarballs
   (`aristotleFOCThree`, `9804c2b5…`, `arsitotleTaoCFMM`) **stay tracked** in
   `lean/archive/` (negative gitignore entries); the other 21 are un-tracked.
   The README provenance table records sha256 + size + date + run-id for all
   24, so any un-tracked archive is verifiable if recovered from history or
   another machine. New Aristotle tarballs: track the canonical latest per
   family, un-track superseded ones.
6. **Stronger verification gate** (Architect M2 / Reality Checker): see below.

## Target layout

```
lean/
├── lakefile.toml          # 1 package, 3 lean_libs
├── lean-toolchain         # leanprover/lean4:v4.28.0
├── lake-manifest.json     # copied from 9804c2b5 tarball (exact closure the
│                          # proofs elaborated against), not regenerated
├── README.md              # family map, provenance table (sha256), proof-status
│                          # ledger, LeanEVM deferral, naming-deviation note,
│                          # cross-family import policy, alias maps
├── exp/                   # Family 1 — 14 modules
│   ├── eta.lean               (repo superset, unchanged)
│   ├── CESLongVolPayoff.lean  (repo == FOCThree, unchanged)
│   ├── …12 modules from aristotleFOCThree (exp/ paths, not top-level copies)
│   └── eta_*.md               (9 existing tracked working notes — unchanged)
├── vol_markets/           # Family 2 — from 9804c2b5
│   └── Main.lean  PosSpec.lean  Flow.lean  RiskDesign.lean
├── tao/                   # Family 3 — from arsitotleTaoCFMM
│   └── AMM.lean Injection.lean Halving.lean Rewards.lean
│       GBM.lean APY.lean Model.lean Main.lean
├── spec/                  # unchanged; planned mirrors of model/spec/*.md
└── archive/               # all 24 tarballs; only the 3 canonical ones tracked

model/
├── exp/aristotle/         # FOCThree: 9 module docs, ARISTOTLE_SUMMARY.md, 2 PDFs
├── vol_markets/           # 9804c2b5: SCHEDULE.md, pos_spec.md, tbd.md, tbd2.md,
│                          # RISK_ALTERNATIVES.md, DESIGN_SPACE.md, risk.md,
│                          # exposure.md, ARISTOTLE_SUMMARY.md
└── tao/                   # CONSISTENCY_REPORT.md, ARISTOTLE_SUMMARY.md
```

### lakefile.toml (target content)

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

Naming notes (deliberate, documented in README): lowercase/snake-case module
prefixes (`exp.eta`, `vol_markets.Main`) deviate from Mathlib UpperCamelCase
convention but are byte-what-was-proven — a future rename is a conscious
re-verification event. Two `Main` modules are fine (fully qualified names
differ); avoid a future `lean_exe` named `Main`. Cross-family imports are
technically unenforced by Lake (shared `srcDir`); policy: allowed only via
explicit decision recorded in the README.

## Source-of-truth table

| Destination | Source | Edit |
|---|---|---|
| `lean/exp/eta.lean` | repo (unchanged) | none |
| `lean/exp/CESLongVolPayoff.lean` | repo (== FOCThree) | none |
| `lean/exp/<12 new modules>.lean` | `aristotleFOCThree`, **`exp/` paths only** | none |
| `lean/exp/eta_*.md` (9 files) | repo (unchanged) | none |
| `lean/vol_markets/{Main,PosSpec,Flow,RiskDesign}.lean` | `9804c2b5` | `import RequestProject.X` → `import vol_markets.X` (3 lines: PosSpec in Flow; Main + Flow in RiskDesign) |
| `lean/tao/*.lean` (8) | `arsitotleTaoCFMM` | none (imports only Mathlib) |
| `lean/lake-manifest.json` | `9804c2b5` | none (verify mathlib rev == `8f9d9cf`) |
| `model/exp/aristotle/*` (9 docs + summary + 2 PDFs) | `aristotleFOCThree` | none |
| `model/vol_markets/*` (9 docs) | **`9804c2b5` only** | none |
| `model/tao/{CONSISTENCY_REPORT,ARISTOTLE_SUMMARY}.md` | `arsitotleTaoCFMM` | none |

Everything else in every tarball is a superseded duplicate, an early draft, or
a top-level input copy — archived, not migrated. This is an explicit,
intentional drop; the archive + provenance table is the recovery path.

## Migration steps (two commits)

**Commit 1 — archive:**
1. Create `lean/archive/`; move all 24 tarballs there. `git rm --cached` the
   21 superseded ones; keep the 3 canonical ones tracked. Gitignore
   `lean/archive/*` with negative entries (`!`) for the 3 canonical tarballs.
2. Record the sha256/size/date/run-id provenance table (goes into
   `lean/README.md` in commit 2; generated now).

**Commit 2 — conglomeration:**
3. Copy files per the source-of-truth table; apply the 3 import rewrites.
4. Replace `lean/lakefile.toml` + `lean-toolchain`; copy `lake-manifest.json`
   from `9804c2b5`; `rm -rf lean/.lake` (stale v4.30/LeanEVM artifacts —
   classic source of confusing post-downgrade build failures).
5. Rewrite `lean/README.md` (family map, provenance table, corrected
   proof-status ledger, LeanEVM deferral, naming/import-policy notes, alias
   maps `RequestProject.X → vol_markets.X` and `tao ↔ DTAO/TaoCFMM`,
   updated Aristotle workflow paths).
6. **Verification gate** (all must pass before commit 2 lands):
   - `lake exe cache get && lake build` succeeds for all three libs
     (network required: elan fetches v4.28.0, mathlib cache is multi-GB).
   - **Sorry census:** `grep -rn -w sorry lean/exp lean/vol_markets lean/tao
     --include='*.lean'` returns only the known comment-prose hits
     (eta.lean:602, DynamicsOptimization.lean:23, BondingCurveCurvature.lean:26)
     — zero code sorries.
   - **Axiom audit:** `grep -rn "^axiom"` over the three libs = zero hits;
     `#print axioms` on one flagship theorem per family
     (`schedule_isLeast`, the η band theorem, the Halving series) shows only
     `propext`/`Classical.choice`/`Quot.sound`.
   - **Clean-clone build:** the gate runs from a fresh checkout (archive/ is
     mostly untracked — the build must not depend on it).
7. After landing: notify the plank session (`ul2inqpl`) of the canonical doc
   paths under `model/vol_markets/`.

## Known risks

| Risk | Likelihood | Mitigation |
|---|---|---|
| Repo `eta.lean` superset section (proven under v4.30/mathlib-4.30) breaks under 4.28 | low–medium | fix locally; if substantive, resubmit to Aristotle (one in-flight task at a time — no queueing, per standing rule) |
| Mathlib v4.28 toolchain+cache download | certain, one-off | `lake exe cache get`; needs network |

## Out of scope

- New proofs (including the absent small-trade band-max theorem).
- Renaming theorems or namespaces.
- Populating `lean/spec/` (stays a planned mirror of `model/spec`).
- The stray untracked file `bpp@hotmail.es` at the worktree root (accidental
  shell-redirect artifact; flagged for the user, not touched here).
- `model/exp/eta.md` (modified) and `model/exp/eta_pi_trader_delta_control.md`
  (untracked) — working state of the math layer, not part of this migration
  (the new `model/exp/aristotle/` subdir does not touch them).

## Review record

Two-step review (2026-07-16, parallel): **Reality Checker** and **Software
Architect** (chosen: build-structure/module-boundary artifact, no EVM code).
Both returned NEEDS WORK; all BLOCKER/MAJOR findings are resolved in this
rev 2: completeness of the source-of-truth table (docs/PDFs/summaries),
corrected proof-status ledger (zero code sorries), honest supersession
evidence statement, single-source rule for conflicting docs, model/-layer doc
placement, strengthened verification gate, archive durability policy.
Accepted MINORs folded in: `.lake` purge, manifest copy, two-commit split,
tracked-size correction (~10.2 MB), naming/alias documentation, network note,
top-level-input-copy warning, `eta_*.md` disposition.
