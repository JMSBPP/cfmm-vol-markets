---
phase: 20-deploy-rig-source-of-truth-import
verified: 2026-07-31T19:32:31Z
status: passed
score: 5/5 must-haves verified
---

# Phase 20: Deploy Rig & Source-of-Truth Import Verification Report

**Phase Goal:** The full V2 contract set is standing on a local anvil and every address,
selector and event topic0 the drivers need exists in ONE place on this branch, traceable to
the interface file it came from — so no later phase has to guess at, or re-type, a value that
lives on another branch.
**Verified:** 2026-07-31T19:32:31Z
**Status:** passed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths (Success Criteria, ROADMAP.md Phase 20)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| SC-1 | Binding artifacts on `feat/rpc-api` are content-identical to the recorded ref `origin/develop @ 9f5ccba9…` | ✓ VERIFIED | `./offchain/rig/verify-import.sh` → `SC-1 OK: 36 imported paths content-identical to 9f5ccba92ddf89d80efe81bae1dcd1d0a1c10e2d and sha256-matched to IMPORT-PIN.md`, exit 0. Script independently runs (a) `git diff` against the live ref object and (b) a `sha256sum` recompute against 36 committed pin rows in `IMPORT-PIN.md` — not a single trust-the-file check. |
| SC-2 | All four deploy scripts run to completion on a fresh local anvil; every deployed contract proven LIVE by a read that could not pass against an empty address; RealizedVolatilityMod seeded nonzero | ✓ VERIFIED | Ran `./offchain/rig/verify-rig.sh` live against the running anvil rig: 7/7 contracts PASS bytecode-presence, `orderCount()` decodes 0, seeded `getTimepointPacked` returns a large nonzero packed value, owner/poolManager/poolId cross-checks all PASS. Exit 0. `RIG-RUN.md` additionally documents 6 injected-fault falsification runs of `verify-rig.sh` itself (each fired the correct named failure), which is stronger evidence than a single green run. |
| SC-3 | Printed addresses/selectors/topic0s captured into ONE manifest; no address/selector/topic0 hardcoded anywhere else under `offchain/` | ✓ VERIFIED | `grep -rE '0x[0-9a-fA-F]{40}\|0x[0-9a-fA-F]{64}' offchain --include='*.hs' --include='*.sh'` → zero matches. Broadened to any `0x[0-9a-fA-F]{6,}` in the same file set → also zero matches (no selector-length literals either). `Sample.hs`'s three former literals confirmed gone (file now docstring-only + non-address demo data); `Main.hs` calls `load_rig` before any RPC; `Decode.hs`'s `decode_order_created` takes `expected_topic0` as a parameter, not a constant. |
| SC-4 | Every selector/topic0 in the manifest recomputed in a test from its interface file's signature string and matched; mismatch fails | ✓ VERIFIED | `cabal test` → `44/44 checks passed`, `SC-3 and SC-4 OK`, exit 0. Inspected `offchain/test/Main.hs`: `verify_pin` re-parses the signature out of the `.plk` source file and keccak256-hashes it independently of the pin file, `sc4_falsifiable` injects the retired `0xa8892769…`-class stale value through the SAME checker and asserts it is REJECTED (would itself fail if the checker were a no-op), `sc4_cast_agreement` cross-checks against `cast sig`/`cast keccak` as an independent encoder, and `sc3_corrupted_manifest_fails` proves a manifest with a deleted contract or invalid JSON refuses to load. The cabal harness reports "1 of 1 test suites (1 of 1 test cases) passed" at the top level, but the suite internally runs and reports 44 named sub-checks including the falsifiability case — confirmed by reading the source, not by the pass count alone. |
| SC-5 | Reproducible from one documented command sequence; a second run from scratch produces the same contract set | ✓ VERIFIED | `offchain/rig/README.md`'s "Clean-machine sequence" matches `deploy-rig.sh`'s actual behavior (verified by reading both) and matches what was executed. `RIG-RUN.md` records two full `deploy-rig.sh` runs (`generatedAt` 18:46:13Z vs 18:49:15Z) whose manifests are byte-identical after `jq -S 'del(.generatedAt)')` (shared sha256, `diff -u` empty) — the differing timestamp proves the second run genuinely regenerated the file rather than re-reading the first. |

**Score:** 5/5 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `offchain/rig/check-upstream.sh` | Blocking upstream gate | ✓ VERIFIED | Executable, ran live: `OPEN: origin/develop = 9f5ccba9… carries the V2 rig artifacts (0x98d950ec present)`, exit 0. Now reads its two comparison selectors from the committed `rig-pins.json` (post-20-05 purge) rather than a hardcoded literal — confirmed this is not a live bootstrap problem because `rig-pins.json` is `git`-tracked (`git ls-files` confirms), so the script is self-contained on a fresh checkout. |
| `offchain/rig/import-ref.txt` | 40-char develop sha | ✓ VERIFIED | Contains `9f5ccba92ddf89d80efe81bae1dcd1d0a1c10e2d` |
| `.planning/phases/20.../FORGE-BASELINE.md` | Cold pre-import counts | ✓ VERIFIED | `139 passed, 5 failed, 144 total` recorded cold, matches the "before" side of `FORGE-DELTA.md` |
| `offchain/rig/import-paths.txt` / `IMPORT-PIN.md` | Enumerated import unit + sha256 provenance | ✓ VERIFIED | 36 paths, 36 sha256 rows (64-hex each), all independently re-verified passing via `verify-import.sh` above |
| `offchain/rig/deploy-rig.sh` | One-command rig owner | ✓ VERIFIED | Present, executable, contains `INIT_TS`; run twice per `RIG-RUN.md` with byte-identical resulting manifests |
| `offchain/rig/verify-rig.sh` | SC-2 liveness probes | ✓ VERIFIED | Present, executable, contains `getTimepointPacked`; ran live, exit 0 |
| `offchain/rig/rig-manifest.json` | Gitignored per-deploy addresses | ✓ VERIFIED | Present at runtime (anvil live), NOT tracked by git (`git ls-files` excludes it), `.gitignore:58` lists `offchain/rig/rig-manifest.json` |
| `offchain/rig/generate-pins.sh` + `rig-pins.json` | Mechanically generated static pins | ✓ VERIFIED | Committed `rig-pins.json` contains `0x98d950ec`; generator reads signature comments from imported `.plk` files and uses `cast keccak`/`cast sig` (confirmed by `sc4_cast_agreement` cross-check passing) |
| `offchain/lib/Rig/Manifest.hs` | aeson loader, `load_rig` | ✓ VERIFIED | Exports `load_rig`, `load_rig_from`; every field documented as mandatory, no defaulted address; wired into `Main.hs` |
| `cfmm-replicationPlank-rpc-api.cabal` | `Rig.Manifest` exposed, deps added, `-Wall` | ✓ VERIFIED | `Rig.Manifest` in exposed-modules, `web3-crypto` in both library and test-suite deps, `ghc-options: -Wall` present, zero warnings on `cabal build -j all` |
| `offchain/test/Main.hs` | SC-3/SC-4 cabal test cases | ✓ VERIFIED | Contains `keccak256` usage, 44 named checks, `cabal test` exit 0 |
| `offchain/app/Sample.hs` | Address literals removed | ✓ VERIFIED | File is now docstring-only re: addresses; contains no `0x…` address/selector/topic0 |
| `offchain/app/Main.hs` | Startup manifest load | ✓ VERIFIED | Contains `load_rig` called before RPC calls |
| `offchain/lib/VolOrder/Decode.hs` | `decode_order_created` takes topic0 as parameter | ✓ VERIFIED | Signature is `Integer -> Change -> Maybe OrderCreatedEvent`, no topic literal in body |
| `offchain/rig/README.md` | SC-5 documented sequence | ✓ VERIFIED | Contains `deploy-rig.sh`, matches actual clean-machine sequence and honestly documents the known `cabal run` revert caveat |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|----|--------|---------|
| `check-upstream.sh` | `origin/develop:...VolOrderManagerInterface.plk` | `git show` + `grep -q $V2_SELECTOR` | WIRED | Ran live, correctly discriminates V1 vs V2 interface |
| `check-upstream.sh` | `import-ref.txt` | writes `git rev-parse origin/develop` on success | WIRED | Confirmed file content matches |
| `deploy-rig.sh` | `broadcast/Deploy*.s.sol/31337/run-latest.json` | `jq` extraction | WIRED | `RIG-RUN.md` documents exact jq paths per contract, cross-checked against console logs |
| `deploy-rig.sh` | per-script console logs | case-insensitive cross-check | WIRED | `RIG-RUN.md` "Console cross-check" section lists all 7 labels checked |
| `verify-rig.sh` | `rig-manifest.json` | `jq -r` reads every probe target | WIRED | Live run confirmed probe values (addresses) match manifest, not literals |
| `generate-pins.sh` | `src/interfaces/**/*.plk` | signature-comment parsing | WIRED | `rig-pins.json` entries cite `pin_source` per value; `sc4_ground_truth_encoder` + `sc4_cast_agreement` cross-verify |
| `rig-pins.json` | `Rig/Manifest.hs` | aeson `FromJSON` | WIRED | `load_rig` loads both files; `sc3_load_succeeds`/`sc3_corrupted_manifest_fails` tests confirm |
| `Rig/Manifest.hs` | `rig-manifest.json` | `eitherDecodeFileStrict`, `RIG_MANIFEST` override | WIRED | Confirmed via source inspection and successful `cabal run` startup load |
| `Main.hs` | `Rig.Manifest.load_rig` | startup, before RPC | WIRED | `cabal run` demo confirmed manifest-sourced addresses used for all calls |
| `test/Main.hs` | `src/interfaces/**/*.plk` | parses signatures, `keccak256` recompute | WIRED | Confirmed by source read of `verify_pin`/`sc4_*` checks and passing test run |
| `test/Main.hs` | `rig-pins.json` | compares recomputed vs committed pin | WIRED | Same as above |

### Requirements Coverage

| Requirement | Source Plan(s) | Description | Status | Evidence |
|-------------|-----------------|-------------|--------|----------|
| RIG-01 | 20-01, 20-02, 20-03, 20-04, 20-05 | Four deploy scripts stand up the full rig; each script's addresses/selectors/topic0s captured for the drivers | ✓ SATISFIED | Each of the 5 plans deliberately left RIG-01 unchecked individually (partial capability per phase design); at phase end, ALL 5 success criteria are independently verified true above (import identity, live deployment + seeding, single-manifest purge, signature-derived recomputation with demonstrated falsifiability, and double-run reproducibility). `REQUIREMENTS.md:326` already records `RIG-01 | Phase 20 | Complete` — this verification confirms that status is earned, not merely marked. |

No orphaned requirements: `grep -n "Phase 20" REQUIREMENTS.md` shows only the RIG-01 row; all 5 plans declare `requirements: [RIG-01]` in frontmatter.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| — | — | none | — | A grep for `mktemp ... XXXXXX` template chars produced a false-positive `XXX` match in `deploy-rig.sh`; inspected and confirmed it is a `mktemp` template placeholder, not a stub marker. No genuine TODO/FIXME/placeholder/empty-implementation patterns found in any of the 10 phase-20 files scanned. |

### Documented Caveats — Cross-Checked, Accurately Characterized

- **`cabal run` demo order REVERTS.** Reproduced live: the single `create_order` tx shows `status reverted`, and the batch shows `0 succeeded, 3 failed (of 3)`, all orders `SKIPPED`. Root cause confirmed by source read: `offchain/lib/VolOrder/Encoding.hs:20` still calls `create_order(uint88,uint24,uint16)` (retired V1, 3-arg) while `verify-rig.sh` and the deployed module are V2 (4-arg). README documents this honestly as "a known gap in the driver, not a fault in the rig" and explicitly scopes it to Phase 21. Accurately characterized, not hidden.
- **`forge test` delta 139/5/144 → 85/27/112.** Confirmed: `FORGE-BASELINE.md` records the pre-import 139/5/144 cold measurement; `FORGE-DELTA.md` records the identical command post-import producing 85/27/112, with all 27 reds attributed one-by-one to 4 named causes (C1–C4) plus 1 pre-existing red, each with a concrete file:line citation and, for C3, a proven one-flag fix (not applied, since `test/` is out of scope). `forge build` re-confirmed exit 0 in this verification session. `git status --porcelain test/ Makefile foundry.toml remappings.txt` reported empty in FORGE-DELTA.md's own record — nothing under another workstream's territory was touched.
- **`generate-pins.sh` depends on the superseded `src/modules/VolOrderManagerMod.plk`.** Confirmed: `generate-pins.sh:51` sets `STALE_TOPIC_SRC="src/modules/VolOrderManagerMod.plk"`, and that file exists on disk (`src/modules/VolOrderManagerMod.plk`, distinct from the live `src/modules/pos_spec/VolOrderManagerMod.plk`). The script documents this as intentional provenance (reading the retired value from where the rot originated, not a copy) and fails loudly if the file disappears. Accurately characterized.

### Human Verification Required

None. Every success criterion for this phase was independently machine-verifiable and was independently re-executed (not merely read from SUMMARY claims) in this session: `verify-import.sh`, `verify-rig.sh`, `check-upstream.sh`, `cabal test`, `cabal build`, `forge build`, and a live `cabal run` demo. Anvil was already running at `127.0.0.1:8545` (confirmed via `eth_chainId` RPC call, PID 820571) so no deploy-rig.sh re-run was required to observe a live rig; a fresh manifest cross-check against the live contracts still passed.

### Gaps Summary

None. All 5 observable truths (ROADMAP Phase 20 success criteria) verified true against the live codebase and a live running rig, not against SUMMARY.md claims alone. RIG-01 is genuinely satisfied by the phase as a whole: none of the 5 individual plans claimed it standalone (by design — each delivered partial capability), but the union of what they built — a content-verified import, a live 7-contract deployment with seeded nonzero state, a single purged manifest, signature-derived and demonstrably-falsifiable pin tests, and proven double-run reproducibility — jointly satisfies the requirement text and all 5 ROADMAP success criteria. The three documented caveats (demo revert, forge test delta, generate-pins.sh's dependency on a superseded file) are correctly scoped to Phase 21 / another workstream and do not block Phase 20's own goal.

---

*Verified: 2026-07-31T19:32:31Z*
*Verifier: Claude (gsd-verifier)*
