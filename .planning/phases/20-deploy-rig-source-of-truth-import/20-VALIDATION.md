---
phase: 20
slug: deploy-rig-source-of-truth-import
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-07-31
---

# Phase 20 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Source: 20-RESEARCH.md §11 (Validation Architecture) — full req→test map and rationale live there.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | cabal `test-suite cfmm-replicationPlank-rpc-api-test` (`exitcode-stdio-1.0`, `offchain/test/Main.hs`) — currently a stub; Wave 0 replaces it |
| **Config file** | `cfmm-replicationPlank-rpc-api.cabal` (test-suite stanza exists; build-depends is base + library only today) |
| **Quick run command** | `cabal test` |
| **Full suite command** | `cabal build -j all && cabal test && offchain/rig/deploy-rig.sh && offchain/rig/verify-rig.sh` |
| **Estimated runtime** | quick ~seconds; full rig cycle ~minutes (four FFI deploys) |
| **On-chain side** | `forge` 1.5.1 — `test/` is another session's territory: this phase only MEASURES `forge test` before/after the import and attributes deltas, never repairs |
| **Hard gate** | zero `-Wall` warnings (`common warnings` stanza) on every Haskell change |

---

## Sampling Rate

- **After every task commit:** `cabal build -j all` (zero warnings) + `cabal test`
- **Per wave merge:** `cabal test` + `offchain/rig/verify-import.sh` + a full `deploy-rig.sh` run
- **Phase gate (before /gsd:verify-work):** `npm ci --ignore-scripts && forge build && offchain/rig/deploy-rig.sh && offchain/rig/verify-rig.sh && cabal test` all green, plus the double-run reproducibility check (`jq -S` on the manifest, `generatedAt` excluded)

---

## Requirements → Test Map (summary — authoritative table in 20-RESEARCH.md §11)

| Req / SC | Automated check |
|----------|-----------------|
| Upstream gate | `offchain/rig/check-upstream.sh` — `origin/develop` interface file greps `0x98d950ec`; BLOCKS the phase otherwise |
| SC-1 | `offchain/rig/verify-import.sh` — `git diff --exit-code <recorded ref> -- $(cat offchain/rig/import-paths.txt)` + sha256 recompute vs `IMPORT-PIN.md` |
| SC-2 | `offchain/rig/deploy-rig.sh` exit 0 + `offchain/rig/verify-rig.sh` liveness probes (`orderCount()`, nonzero seeded timepoint, `owner()`, hook `poolManager()`/`poolId()`) |
| SC-3 | `cabal test`: `Rig.Manifest.load_rig` succeeds on generated files, fails loudly on a corrupted copy; literal-purge grep (no 0x-addr/selector/topic0 under scope) |
| SC-4 | `cabal test`: every pin in `rig-pins.json` recomputed via `keccak256` from the imported `.plk` signature strings (incl. the multi-line `TimepointWritten`); falsifiability case injects the stale `0xa8892769…` and asserts failure; `cast sig`/`cast keccak` cross-encoder agreement |
| SC-5 | `deploy-rig.sh` run twice from scratch → `jq -S` manifests byte-identical (generatedAt excluded) |
| Regression | `forge test --via-ir --fuzz-seed 4880` before/after import — deltas recorded and attributed, not repaired |

---

## Wave 0 Gaps

- [ ] `offchain/rig/check-upstream.sh` — the BLOCKING gate
- [ ] `offchain/rig/import-paths.txt` — binding paths + the §2.3 transitive `.plk` closure (~20 files)
- [ ] `offchain/rig/verify-import.sh` — SC-1 re-diff + sha256
- [ ] `offchain/rig/deploy-rig.sh` — SC-2/SC-5, owns anvil (kill-stale → fresh → poll → rm stale broadcasts → 4 scripts → manifest from run-latest.json + console cross-check)
- [ ] `offchain/rig/verify-rig.sh` — SC-2 liveness probes
- [ ] `offchain/rig/rig-pins.json` — committed static pins GENERATED from imported `.plk` files
- [ ] `offchain/lib/Rig/Manifest.hs` — aeson records + loader (exposed-modules)
- [ ] `offchain/test/Main.hs` — replace stub; hosts SC-3/SC-4 checks
- [ ] `cfmm-replicationPlank-rpc-api.cabal` — `web3-crypto` (lib + test), `process`/`directory` in test build-depends, `Rig.Manifest` exposed
- [ ] `.gitignore` — `offchain/rig/rig-manifest.json`
- [ ] `.planning/phases/20-deploy-rig-source-of-truth-import/IMPORT-PIN.md`
- [ ] Framework install: none — `cabal`, `forge`, `jq`, `plank` present and version-verified; `npm ci --ignore-scripts` is the one preflight install
