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
| `88d393e7-ec4e-438f-a5fd-9f34aab1c2e5-aristotle.tar.gz` | 422dddbfa95b85f6… | 2026-06-29 | 55643 |
| `9804c2b5-a6a5-4a7f-a67b-89119b4b7bfb-aristotle.tar.gz` | fd962350d334338a… | 2026-07-15 | 20553 |
| `aristotle_collateral_schedule_raw.tar.gz` | 032dc1b7d95e198b… | 2026-07-06 | 14220 |
| `aristotleFOCLongVar1.tar.gz` | 183cdc19c428819a… | 2026-06-30 | 3220633 |
| `aristotleFOCLongVol2.tar.gz` | 9cc333bab5587406… | 2026-06-30 | 3225099 |
| `aristotleFOCThree.tar.gz` | 3f64bdbe0b728689… | 2026-06-30 | 3232394 |
| `aristotleLiquPayoffs.tar.gz` | c82d4e6b22c533e4… | 2026-06-29 | 59520 |
| `aristotleMeanVarianceCompStatics.tar.gz` | 0ab124df28c71be0… | 2026-06-30 | 98706 |
| `aristotleMeanVarianceOptimizationRaw.tar.gz` | c3bbb4ba5c6e3ba2… | 2026-06-30 | 92104 |
| `aristotleMeanVariance.tar.gz` | 948661a7a6406618… | 2026-06-29 | 79731 |
| `aristotleSequencesInit.tar.gz` | 1e8f1b86a2e2e107… | 2026-06-29 | 86923 |
| `aristotleSocialChoice.tar.gz` | 80cdaa7e30d35393… | 2026-06-29 | 70767 |
| `aristotle_tbd.tar.gz` | ca8a05702c518e9b… | 2026-07-06 | 6790 |
| `arsitotleTaoCFMM.tar.gz` | 3ff5a010f066824b… | 2026-06-30 | 12257 |
| `.aristotle-final.tar.gz` | 75dab7a621295186… | 2026-06-28 | 4417 |
| `.aristotle-out10.tar.gz` | 9b758e77503320e4… | 2026-06-28 | 39826 |
| `.aristotle-out12.tar.gz` | 82b604913788f992… | 2026-06-28 | 48003 |
| `.aristotle-out13.tar.gz` | 2512d103a9169ba3… | 2026-06-28 | 49386 |
| `.aristotle-out2.tar.gz` | ea0b0073b7618725… | 2026-06-28 | 14549 |
| `.aristotle-out3.tar.gz` | 044eed34f0ec4194… | 2026-06-28 | 31975 |
| `.aristotle-out4.tar.gz` | 6688366e4e0d4d8a… | 2026-06-28 | 34967 |
| `.aristotle-out5.tar.gz` | 22e01ecf270abc10… | 2026-06-28 | 36283 |
| `.aristotle-out8.tar.gz` | e90a64c1024a9693… | 2026-06-28 | 44617 |
| `.aristotle-out.tar.gz` | 5aaf3fc53df9e685… | 2026-06-28 | 3700 |

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
