---
phase: 25-content-key-keyed-store
plan: 01
subsystem: testing
tags: [content-key, netstring-framing, sha256, preimage, haskell, cabal]

requires:
  - phase: 24-gams-invocation-and-versions
    provides: "render_argv / parse_shock_field (the single renderer and the normalization edge), the parsed GAMS and CONOPT version types, ToolchainIdentity"
  - phase: 23-postgres-foundation
    provides: "Store.Types.KeyScheme / current_key_scheme / sha256_hex"
provides:
  - "six registered checks covering Store.Key: the framer, the normalization edge, the pip denominator, the relativised model source, the refused absent solver version, and the preimage's scope"
  - "reusable key fixtures in the suite (key_toolchain, key_fixture_identity, key_fixture_preimage) that 25-02's cache checks can build on"
affects: [25-02, 25-03, store-cache, content-key]

tech-stack:
  added: []
  patterns:
    - "absence asserted on the FRAMED form of a token, so a numeric claim is about a component rather than about digits inside a digest"
    - "a colliding-when-bare fixture pair, with the collision itself asserted, so the framing check cannot pass with its subject deleted"

key-files:
  created: []
  modified:
    - offchain/test/Main.hs

key-decisions:
  - "KEY-01's plan step was WRONG as written and was corrected against the measurement: Store.Key.relativise basenames an absolute model-source path rather than refusing it, so the check asserts the relativisation AND the directory's absence from the preimage, and reserves the Left arm for a path that cannot be basenamed. Check renamed from key_identity_refuses_an_absolute_model_source_path to no_key_identity_carries_an_absolute_model_source_path so the name states what it proves."
  - "Per-run token absence is asserted on frames [token] rather than on a bare substring: the wrapper's budget and kill delay are bare integers, and a substring claim about them would be a claim about which digits happen to occur inside a sha256."
  - "Every per-run token and the installation path are assembled from string fragments, so the GAMS-free structural grep over Main.hs stays at 0."

patterns-established:
  - "Positive arm first inside an absence check: the seven shock tokens and both fixed options must be PRESENT before six absences are allowed to mean anything."
  - "Library constants (pips_denominator, fixed_model_options, current_key_scheme) are imported into the suite, never transcribed — a transcribed copy keeps agreeing with itself after the library moves."

requirements-completed: [KEY-01, KEY-02, KEY-03, KEY-04, KEY-05, KEY-06]

duration: 41min
completed: 2026-08-17
---

# Phase 25 Plan 01: Cover `Store.Key` Summary

**Six checks put the content key's pure core under assertion — the netstring framer separates a pair that concatenation provably conflates, `28e18` and its decimal spelling key once, the pip denominator moves every key, an absolute model-source path is relativised away before it can reach a preimage, an absent CONOPT version is a refusal naming the field, and no per-run token from the invocation wrapper is inside the preimage.**

## Performance

- **Duration:** 41 min
- **Tasks:** 3 of 3
- **Files modified:** 1 source file (`offchain/test/Main.hs`), plus `.planning/` records
- **Suite:** 151/151 → **157/157**, exit 0, zero warnings, 157 s

## Accomplishments

### Task 1 — Framing, normalization and the denominator (commit `c0e2e9c`)

| Check | What it asserts |
| ----- | --------------- |
| `framing_separates_what_concatenation_conflates` | `[("a","bcd"),("e","f")]` and `[("ab","cd"),("e","f")]` are byte-identical concatenated bare (arm 1), differ under `frames` (arm 2), and produce different `key_preimage` bytes (arm 3) |
| `edge_normalization_is_single_pass` | `28e18` and `28000000000000000000` give one `ContentKey`; a different value gives a different one; the key is 32 bytes |
| `the_pips_denominator_is_in_the_preimage` | `key_identity` carries the library's denominator, and `pips_denominator + 1` moves the preimage |

Arm 1 of the framing check is the one the plan singled out and it is load-bearing: a pair built from fixed-length digests differs bare too, so it would pass with the framer deleted. Asserting the bare collision first is what makes arms 2 and 3 mean anything.

The negative arm of `edge_normalization_is_single_pass` is there for the same reason — the equality on its own is satisfied by a key function that returns a constant.

### Task 2 — The refusing identity and the shared renderer (commit `26378ad`)

| Check | What it asserts |
| ----- | --------------- |
| `no_key_identity_carries_an_absolute_model_source_path` | an absolute path is relativised to its file name, the directory is absent from the preimage bytes, and a path with no file name is `Left (AbsoluteModelSourcePath <original>)` |
| `key_identity_refuses_an_absent_conopt_version` | `ti_conopt_version = Nothing` is `Left ConoptVersionAbsent` — never an empty string, never a placeholder |
| `the_preimage_excludes_every_per_run_token` | all 7 shock tokens and both fixed options ARE in the preimage (framed); the `-k` flag, kill delay, budget, timeout binary, absolute solver path and `curdir=` option are NOT |

`the_preimage_excludes_every_per_run_token` is the check that stops the store being useless. `Gams.Run` puts an exclusive per-run temp dir into its wrapper vector — a different path on every invocation, by design, as the stale-file defence. A preimage carrying it satisfies "the argv reconstructs from the stored preimage" perfectly while giving a cache hit rate of exactly zero, and every other check in this section stays green.

**OBSERVED reddening (throwaway, not committed):** seeding a legitimately-present token (`lo=2`) into `key_per_run_tokens` took the check to `FAIL the_preimage_excludes_every_per_run_token: the preimage carries THROWAWAY FALSIFICATION, "lo=2"`, suite 155/157. The absence machinery has a live subject.

### Task 3 — Gate

- `cabal build --enable-tests -j all` → exit 0, **0** warning lines
- `cabal test` → exit 0, **157/157**, 0 `FAIL` lines, 157 s
- `Store\.Postgres|connectPostgreSQL|CFMM_REQUIRE_DB` over `Main.hs` → **0** (grep exit 1, count zero — captured as its own status, not from a pipeline)
- `Gams\.Invoke|CFMM_REQUIRE_GAMS|/usr/gams` over `Main.hs` → **0**
- `git status --porcelain src test foundry-scripts Makefile foundry.toml .github` → empty

File floors did not move, as expected: no module was added.

## Deviations from Plan

### 1. [Rule 1 — Plan step contradicted by the code] KEY-01's refusal does not fire for an ordinary absolute path

- **Found during:** Task 2
- **Plan said:** "`key_identity` on a `ToolchainIdentity` whose `ti_model_sources` carries an absolute path returns `Left`, and the error names the path."
- **Measured:** `Store.Key.relativise` takes `takeFileName` FIRST and only refuses when the result is empty, absolute, or still carries a separator. `takeFileName "/var/lib/cfmm-replication/models/volume_path.gms"` is `"volume_path.gms"`, which is none of those — so the identity is `Right`, with the directory discarded. `AbsoluteModelSourcePath` fires only for a path whose file name is empty, e.g. one ending in a separator.
- **Fix:** the check asserts what the module actually guarantees, in both halves — the relativisation (identity carries only the file name; the directory string is absent from the preimage bytes) and the refusal (a path that cannot be basenamed is `Left`, naming the ORIGINAL path rather than the empty remainder). Renamed to `no_key_identity_carries_an_absolute_model_source_path`, because a check named "refuses" while the behaviour is "relativises" is a misleading artifact.
- **The requirement is still discharged:** KEY-01 asks that no machine-specific path reach a key, and both arms together say exactly that.
- **Commit:** `26378ad`

### 2. [Rule 3 — Plan context inaccurate] Four names in the plan's API list are not exported

- **Found during:** Task 1
- **Issue:** the plan lists `build`, `relativise`, `source_frames` and `parse_frames` as part of `Store.Key`'s API. They are top-level bindings but are NOT in the module's export list (`frame`, `field`, `frames`, `build`… — `build` is not there either).
- **Fix:** no library edit; the checks were written against the exported surface. `frames` on a flattened source list stands in for `source_frames`, and `frames [token]` as a needle stands in for `parse_frames`. Nothing was lost — the framing claim is still carried to `key_preimage` itself.
- **Recorded for 25-02:** if a later plan needs `parse_frames` or `preimage_tags`-style byte-level readback beyond what `preimage_tags` already exports, the export list has to change first.

### 3. Import churn between the two task commits

Task 1's commit temporarily omits `KeyIdentityError (..)` and `fixed_model_options` from the `Store.Key` import list, because `-Wall` reports an unused import as a warning and the gate treats warnings as failures. Task 2 re-adds both. This keeps each commit independently warning-clean.

## Deferred Issues

None. No auto-fix limit was approached; the two deviations above are the whole of it.

## Self-Check

- `offchain/test/Main.hs` — FOUND
- `.planning/phases/25-content-key-keyed-store/25-01-SUMMARY.md` — FOUND
- commit `c0e2e9c` — FOUND
- commit `26378ad` — FOUND
- all six check names present in `core_checks` — FOUND (verified by name in the `cabal test` PASS lines)

## Self-Check: PASSED
