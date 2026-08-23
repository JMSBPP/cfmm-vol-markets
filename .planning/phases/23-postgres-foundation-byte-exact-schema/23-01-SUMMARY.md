---
phase: 23-postgres-foundation-byte-exact-schema
plan: 01
subsystem: database
tags: [postgresql-simple, postgresql-migration, crypton, bytea, jsonb, haskell, byte-fidelity]

# Dependency graph
requires: []
provides:
  - "Store.Types — Artifact (the oracle, has Eq) and DerivedDoc (abstract, NO Eq, no converter): BYTE-02 as a compile error rather than a check"
  - "adversarial_corpus — 7 members, each tagged with the behaviour it was MEASURED to produce on the broken bare-ByteString write path; 2 carry SilentlyCorrupted"
  - "volume_path_golden_sha256 / _bytes_len — the real 606-byte GAMS artifact's identity, pinned BARE in Haskell source"
  - "Store.Config — PGSTORE_DSN and STORE_CONFORMANCE resolved through lookupEnv in the Rig.Manifest idiom, zero credential literals"
  - "Store.Class — the Store record-of-functions seam, three separated surfaces (keyed / blob / doc-digest)"
  - "Store.Memory — IORef-backed reference Store keyed on the FULL (model, key_scheme, key) triple"
  - "postgresql-simple 0.7.0.1, postgresql-migration 0.2.1.8 and crypton 1.0.6 in the library's build plan"
affects: [23-02 store laws, 23-03 schema and migrations, 23-04 conformance capture, 23-05 checks, 25 content key]

# Tech tracking
tech-stack:
  added: [postgresql-simple-0.7.0.1, postgresql-migration-0.2.1.8]
  patterns:
    - "The guard that is a TYPE ERROR, not a check: DerivedDoc has no Eq, no Ord, no Show, no exported constructor and no converter to Artifact"
    - "Record of functions as the store seam (zero typeclasses, consistent with the other 26 library modules)"
    - "Every corpus member carries the behaviour it was measured to produce, so 'the guard fired' names WHICH failure"
    - "Guard firing demonstrated as a PAIR (probe alone must fail; probe with the instance must compile) so the compile error's cause is pinned"

key-files:
  created:
    - offchain/lib/Store/Types.hs
    - offchain/lib/Store/Config.hs
    - offchain/lib/Store/Class.hs
    - offchain/lib/Store/Memory.hs
  modified:
    - cfmm-replicationPlank-rpc-api.cabal

key-decisions:
  - "DerivedDoc wraps Text (the doc::text rendering), not Data.Aeson.Value — wrapping Value would force Data.Aeson onto the storage path and defeat BYTE-03's own grep, at identical type-level strength"
  - "Store.Memory's put_run is FIRST-writer-wins on the full triple; put_blob is LAST-writer-wins, because the blob surface is not an identity surface"
  - "doc_digest uses lenientDecode and deliberately does NOT model jsonb normalization — a Memory-side jsonb 'exhibit' would compare a value to itself"
  - "The .cabal exposed-modules stanza for each Store module ships in the commit that creates its file, not all at once in task 1"

patterns-established:
  - "Package-count claims are settled by plan.json set-diff (152 -> 158), never by estimate"
  - "Prose is inside the grep's blast radius: comments were reworded so a future no_credential check with a positive control cannot redden on a comment saying there is no credential"

# NOT the plan's frontmatter list verbatim -- see "Requirement status" below. Checking off a
# database requirement from a plan that never contacted a database is this repo's defect class.
requirements-completed: []
requirements-partial: [BYTE-02, DB-02]
requirements-untouched-despite-plan-frontmatter: [BYTE-05]

# Metrics
duration: 41min
completed: 2026-08-16
---

# Phase 23 Plan 01: The Store Contract Summary

**`Artifact`/`DerivedDoc` make BYTE-02 a GHC type error (observed firing three ways), the
7-member adversarial corpus ships with its measured behaviour tags including the silently-
corrupting `a\101b`, and an IORef reference `Store` keyed on the full `(model, key_scheme, key)`
triple was observed orphaning across schemes where a two-part key silently serves the wrong row.**

## Performance

- **Duration:** 41 min
- **Started:** 2026-08-16T13:08:00Z
- **Completed:** 2026-08-16T13:49:00Z
- **Tasks:** 3
- **Files modified:** 5 (4 created, 1 modified)

## MEASURED VALUES (the output block this plan owes)

### Cold baseline — MEASURED at 23-01, before any edit

Neither `STATE.md`'s 91/91 nor the CI header's 78/85 was inherited; both were re-measured.

```
cabal test                                                        ->  91/91 checks passed
                                                                      SC-3 and SC-4 OK
cabal build --enable-tests -j all                                 ->  exit 0, 0 offchain warnings
find offchain/lib offchain/app offchain/test -name '*.hs' | wc -l ->  28
find offchain -name '*.sql' | wc -l                               ->  0
```

**COLD BASELINE, MEASURED at 23-01: `91/91 checks passed`.** Later plans compare against this,
not against any inherited number.

### After this plan

```
cabal test                                                        ->  91/91 checks passed  (UNCHANGED)
cabal build --enable-tests -j all                                 ->  exit 0, 0 offchain warnings
find offchain/lib offchain/app offchain/test -name '*.hs' | wc -l ->  32   (28 + 4)
offchain/lib .hs on disk / library exposed-modules declared       ->  28 / 28, ORPHANS: 0
find offchain -name '*.sql' | wc -l                               ->  0    (sc3_literal_purge untouched)
grep -rE '0x[0-9a-fA-F]{64}\b' offchain/lib/Store/                ->  0    (golden digest pinned BARE)
adversarial_corpus members / SilentlyCorrupted-tagged             ->  7 / 2
```

The count did not move because this plan registers no checks. A moved count would have meant
something else changed.

### Resolved dependency versions, and whether each entered the build plan

Settled by `plan.json` set-diff — the research's own method, re-run here, not estimated.

| Package | Resolved | New to the build plan? |
|---|---|---|
| `postgresql-simple` | **0.7.0.1** | **+4**: `Only-0.1`, `postgresql-libpq-0.11.0.0`, `postgresql-libpq-configure-0.11`, itself |
| `postgresql-migration` | **0.2.1.8** | **+2**: itself, `cryptohash-md5-0.11.101.0` |
| `crypton` | **1.0.6** | **+0 — CONFIRMED, not assumed** |

```
install-plan units BEFORE : 152
install-plan units AFTER  : 158     (+6, entirely the two postgresql stanzas)
```

**The research's "+0 packages" claim for `crypton` is CONFIRMED.** `crypton-1.0.6` appears in the
152-unit set taken *before* the dependency line existed as well as the 158-unit set after it,
because `web3-crypto` already pins `crypton <1.1`. `cabal build --enable-tests -j all` printed
**zero `Downloading` lines** and Built/Installed exactly two units; no `crypton` `Building` line
appeared at all. Nothing contradicted the research.

`cryptonite` units in the resolved `dist-newstyle/cache/plan.json`: **0**.

## Guards observed firing

A guard never seen rejecting is treated as absent. Three arms, all verbatim.

### G1 — research guard #5, "jsonb never compared". FIRED, exit 1.

`probe :: DerivedDoc -> DerivedDoc -> Bool ; probe = (==)` with `DerivedDoc` as shipped:

```
offchain/lib/Store/Types.hs:203:9: error: [GHC-39999]
    • No instance for ‘Eq DerivedDoc’ arising from a use of ‘==’
    • In the expression: (==)
      In an equation for ‘probe’: probe = (==)
    |
203 | probe = (==)
    |         ^^^^

Error: [Cabal-7125]
Failed to build cfmm-replicationPlank-rpc-api-0.1.0.0 (which is required by
exe:cheat-swap-proof from cfmm-replicationPlank-rpc-api-0.1.0.0,
test:cfmm-replicationPlank-rpc-api-test from cfmm-replicationPlank-rpc-api-0.1.0.0 and others).
```

### G2 — ANTI-CONTROL. The same probe with `deriving Eq` appended. Exit 0.

This is what makes G1 evidence rather than a coincidence: the only thing standing between
`doc == doc` and a green build is the absent instance. Without G2, G1 is indistinguishable from
a typo in the probe.

### G3 — the second half of the guard: no `DerivedDoc -> Artifact` converter. FIRED, exit 1.

Probed from a *different* module (`Store.Config`), which is the only honest place for it — inside
`Store.Types` the constructor is legitimately in scope:

```
offchain/lib/Store/Config.hs:85:15: error: [GHC-01928]
    • Illegal term-level use of the type constructor ‘Store.Types.DerivedDoc’
    • imported qualified from ‘Store.Types’ at offchain/lib/Store/Config.hs:34:1-28
      (and originally defined at offchain/lib/Store/Types.hs:99:1-38)
    • In the pattern: Store.Types.DerivedDoc t
      In an equation for ‘escape_hatch’:
          escape_hatch (Store.Types.DerivedDoc t)
            = Store.Types.Artifact (TE.encodeUtf8 t)
   |
85 | escape_hatch (Store.Types.DerivedDoc t) = Store.Types.Artifact (TE.encodeUtf8 t)
   |               ^^^^^^^^^^^^^^^^^^^^^^^^
```

Restore across the whole probe window verified by **diffing digest files, not asserting**:
`8974abe7…0462e16` / `6ae870b0…1a0ebaf` before and after, IDENTICAL.

### G4 — KEY-07 orphaning in `Store.Memory`. OBSERVED, with a negative control.

Correct implementation, driven through `cabal repl` against the real module:

| Arm | Expectation | Observed |
|---|---|---|
| A | lookup under the scheme it was written under | `Artifact "{\"a\":1}"` |
| **B** | **superseded scheme 2 → orphan, not near-miss** | **`Nothing`** |
| **C** | same `(model,key)` under scheme 2 INSERTS | scheme2 `{"b":2}`, scheme1 still `{"a":1}` |
| D | first-writer-wins on re-put | `{"a":1}` survives `"OVERWRITTEN"` |
| E | blob verbatim, all 7 corpus members | in == out for every one; `octal-escape` in=6B **out=6B** |
| F | `store_label` | `Store.Memory` |

Negative control — the exact mistake KEY-07 prevents, applied to this module (key on
`(model, key)` alone). **It compiles**, which is the danger, and:

- **B → `Artifact "{\"a\":1}"`, not `Nothing`.** A cross-scheme near-miss: the superseded scheme
  silently serves a row computed under a different key formula.
- **C → scheme2 = `{"a":1}`.** `row2` was SILENTLY DROPPED — under first-writer-wins the second
  scheme's insert collapses onto the first's key and vanishes.

**Honest negative, and it binds 23-02's law design: arms A, D, E and F are UNCHANGED under the
mutant. Only B and C discriminate.** A law suite that exercised round-tripping and
first-writer-wins but never looked up under a superseded scheme would pass against a store with
no `key_scheme` at all — this repo's defect class exactly. Mutant restored byte-identical
(`0743fb5e…286b7641` before and after).

## Requirement status — NOT marked complete, and why

The plan's frontmatter claims `requirements: [BYTE-02, BYTE-05, DB-02]`. Measured against what
actually shipped, **none of the three is complete**, and `requirements mark-complete` was
deliberately NOT run. Checking a box here is the cheapest possible way to manufacture the exact
defect this milestone's standing rule names — an assertion that passes when its subject is absent.

| Req | Verdict | Evidence, and what is still owed |
|---|---|---|
| **BYTE-02** | **Partial** | The clause "no check ever compares `jsonb` to `jsonb`" is discharged at COMPILE TIME and was OBSERVED firing (G1, G3). The clause "a `jsonb` projection EXISTS for querying" needs the schema (23-03) and the failing-comparison exhibit (23-04). |
| **BYTE-05** | **NOT satisfied** | The requirement is a round-trip *through the database*. **23-01 provisioned, contacted and required no database at all.** What landed is its precondition: the 7-member corpus with measured behaviour tags, including the `SilentlyCorrupted` member that ROADMAP SC-1's own five cannot produce. Lands at 23-04. |
| **DB-02** | **Partial** | `PGSTORE_DSN`/`STORE_CONFORMANCE` resolve via `lookupEnv` in the `Rig.Manifest` idiom with zero credential literals (grep-verified, prose included). Not complete until both are registered in `advertised_overrides` and OBSERVED honoured (23-05) — this repo has measured three advertised-and-dead overrides. |

`.planning/REQUIREMENTS.md`'s traceability rows carry these verdicts verbatim rather than a tick.

## Task Commits

1. **Task 1: wire the dependencies into the `.cabal`** — `69dbd0a` (chore)
2. **Task 2: `Store.Types` and `Store.Config`** — `e013395` (feat)
3. **Task 3: `Store.Class` and `Store.Memory`** — `ade3348` (feat)

## Files Created/Modified

- `offchain/lib/Store/Types.hs` — `Artifact` (the oracle, `Eq`), `DerivedDoc` (abstract, no `Eq`),
  `KeyScheme`, `StoredRun`, `CorpusBehaviour`/`CorpusMember`, `adversarial_corpus`, the bare-pinned
  golden digest, `sha256_hex`
- `offchain/lib/Store/Config.hs` — `PGSTORE_DSN` and `STORE_CONFORMANCE` resolution, `migrations_dir`
- `offchain/lib/Store/Class.hs` — the `Store` record-of-functions seam
- `offchain/lib/Store/Memory.hs` — the `IORef` reference implementation
- `cfmm-replicationPlank-rpc-api.cabal` — three dependencies with measured package-count comments;
  four `exposed-modules`

## Decisions Made

- **`DerivedDoc` wraps `Text`, not `Value`** (the plan's own recorded deviation, carried out).
  Identical type-level guarantee; keeps `Data.Aeson` off the storage path that BYTE-03's grep
  will police from 23-02.
- **`put_run` first-writer-wins, `put_blob` last-writer-wins.** The blob surface has no
  `key_scheme` and its names are corpus member names, so re-putting one is a re-measurement, not
  a conflicting second solve.
- **`doc_digest` uses `lenientDecode` and does not model `jsonb` normalization.** The
  reordered-keys exhibit is a Postgres observation belonging to the 23-04 capture; a Memory-side
  version would compare a value to itself.
- **`Store.Class` is a record, not a typeclass** — a store whose `store_put` fails on the third
  call is one line of record update, which is the sentinel-store instrument DB-03 leans on.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] `exposed-modules` split across the commits that create the files**
- **Found during:** Task 1
- **Issue:** The plan put all four `Store.*` `exposed-modules` lines in Task 1 while their `.hs`
  files land in Tasks 2–3. A module named in `exposed-modules` with no file on disk fails the
  build, so Task 1's own "`cabal build --enable-tests -j all` exits 0" criterion is unsatisfiable
  as written.
- **Fix:** Each module's stanza ships in the commit that creates its file — which is what the
  plan's own `<interfaces>` section requires ("every new `.hs` under `offchain/lib` MUST appear in
  `exposed-modules` in the SAME commit") and leaves every intermediate commit green.
- **Verification:** All four declared by plan end; `offchain/lib` `.hs` on disk 28 == declared 28,
  orphans 0.
- **Committed in:** `69dbd0a`, `e013395`, `ade3348`

**2. [Rule 3 - Self-contradicting criterion] `grep -c 'cryptonite' == 0` vs the prescribed comment**
- **Found during:** Task 1
- **Issue:** The plan requires zero `cryptonite` matches in the `.cabal` while *also* prescribing
  a comment whose text is "cryptonite is deprecated … and must not be used". Both cannot hold.
- **Fix:** The comment is kept (it is the useful part); the real property is verified with a
  strictly stronger instrument than a grep over a file — `cryptonite` units in the resolved
  `plan.json` == **0**. Its only `.cabal` occurrence is inside a `--` comment.
- **Verification:** `plan.json` scan returned `0 []`.
- **Committed in:** `69dbd0a`

**3. [Rule 3 - Unsatisfiable criterion] `grep -c 'lookupEnv' Store/Config.hs == 2`**
- **Found during:** Task 2
- **Issue:** The import line alone makes the floor 3 (1 import + 2 call sites), before the module
  haddock that quotes the idiom.
- **Fix:** Verified the property the criterion proxies for, directly:
  `grep -c 'lookupEnv [a-z_]*_env_var'` == **2** — exactly two resolvers, one per variable, each
  reading a named constant rather than a literal.
- **Committed in:** `e013395`

**4. [Rule 2 - Missing critical] Prose reworded out of three greps' blast radius**
- **Found during:** Task 2
- **Issue:** Three acceptance greps counted matches in *haddock*, not code: `octal-escape` (2, one
  a doc reference), `DerivedDoc(..)` (1, inside "Exporting `DerivedDoc(..)` re-opens BYTE-02"),
  and the credential grep (2, both on the word "password" in comments *saying there is no
  password*).
- **Fix:** Prose reworded in all three places. The third is substantive rather than cosmetic:
  DB-02's planned `no_credential_is_present_in_a_tracked_file` check greps exactly those tokens
  with a positive control, and a comment asserting its own cleanliness would have reddened it.
- **Verification:** 1 / 0 / 0 respectively.
- **Committed in:** `e013395`

**5. [Rule 1 - Bug in the stated procedure] The guard-firing recipe could not fail**
- **Found during:** Task 2
- **Issue:** The plan says to add BOTH `deriving Eq` AND `probe = (==)` and expect the build to
  fail. With the instance present the probe compiles; the recipe as written observes nothing.
- **Fix:** Measured as a pair instead — G1 (probe alone → exit 1) and G2 (probe + instance →
  exit 0) — plus G3 for the converter half from a different module. A compile error on its own
  does not tell you which missing thing caused it.
- **Verification:** Verbatim GHC text recorded above; files restored byte-identical.
- **Committed in:** `e013395`

---

**6. [Rule 1 - False green averted] `requirements mark-complete` NOT run**
- **Found during:** State updates
- **Issue:** The plan's frontmatter claims BYTE-02, BYTE-05 and DB-02. BYTE-05 is explicitly a
  round-trip *through the database*, and this plan contacted no database; BYTE-02 and DB-02 are
  each half-delivered.
- **Fix:** Left unchecked. `.planning/REQUIREMENTS.md`'s traceability rows record Partial /
  Pending with the specific plan that closes each, rather than a tick.
- **Verification:** See "Requirement status" above.

**7. [Rule 1 - Tooling bug] `gsd-tools state update-progress` corrupted STATE.md; reverted**
- **Found during:** State updates
- **Issue:** `state advance-plan` errors on this STATE.md (`Cannot parse Current Plan or Total
  Plans in Phase`), and `state update-progress` rewrote the frontmatter to `milestone: v2.0`,
  `total_phases: 25`, `total_plans: 37` by scanning EVERY phase directory on disk — folding the
  v1.0–v5.0 tracks, which STATE.md itself says are separate and never renumbered, into v6.0.
- **Fix:** `git checkout -- .planning/STATE.md`, then the v6.0 progress block edited by hand with
  an in-file NOTE recording why it is maintained manually. `roadmap update-plan-progress 23` was
  run and IS correct (`1/5`, In Progress) — the bug is confined to the STATE.md commands.
- **Verification:** Frontmatter reads `milestone: v6.0`, 6 phases, 5 plans, 1 complete.

---

**Total deviations:** 7 auto-fixed (3 blocking/unsatisfiable criteria, 1 missing critical,
1 bug in a stated procedure, 1 false green averted, 1 tooling bug)
**Impact on plan:** No scope creep. Five of the seven are criteria or procedures that could not
hold as written, resolved by measuring the property each stood for; three of those are the
self-contradicting-criterion pattern this repo has now recorded eight times. The remaining two
prevented false greens in the tracking documents rather than in the code.

## Issues Encountered

None beyond the deviations above. Every gate passed on the first build after each task.

## Out of scope, logged not fixed

See `deferred-items.md` in this directory: `225a/` (GAMS scratch, pre-dating this plan) and the
untracked `CHANGELOG.md` / `Setup.hs` / `stack.yaml*` — the first of which is named by the
`.cabal`'s `extra-doc-files`, so an `sdist` from a clean checkout would currently fail. Neither is
this workstream's territory.

## User Setup Required

None — no external service configuration. No database was provisioned, contacted, or required by
this plan.

## Next Phase Readiness

Ready for **23-02** (`Store.Laws` × `Store.Memory`, Tier B). Carry forward:

- **The law set must contain a superseded-scheme lookup.** G4's negative control proves that
  round-trip and first-writer-wins laws alone pass against a store with no `key_scheme`.
- **`Store.Schema`, `Store.Laws` and `Store.Postgres` are deliberately NOT declared** in
  `exposed-modules` yet — a module named there with no file on disk fails the build.
- **The corpus is available to laws now**, with `octal-escape` carrying 6 bytes through
  `Store.Memory` — the reference the 23-04 Postgres capture (3 bytes, no error) is compared to.
- **`purge_file_floor` is still 36 against 36 scanned files, zero slack**, and `find offchain -name
  '*.sql'` is still 0. The three `sc3_literal_purge` constants move in the same commit as the first
  `.sql`, which `Store.Config.migrations_dir` points at (`offchain/migrations`).
- **Territory clean:** `git status --porcelain src test foundry-scripts Makefile foundry.toml
  .github` is EMPTY.

---
*Phase: 23-postgres-foundation-byte-exact-schema*
*Completed: 2026-08-16*

## Self-Check: PASSED

- All 4 created modules exist on disk AND are tracked by git (`git ls-files offchain/lib/Store/`).
- Both planning artifacts exist (`23-01-SUMMARY.md`, `deferred-items.md`).
- All 3 task commits resolve: `69dbd0a`, `e013395`, `ade3348`.
- `Store/Memory.hs` digest `0743fb5e…286b7641`, quoted in the G4 restore claim, matches the
  committed file.
- `git status --porcelain src test foundry-scripts Makefile foundry.toml .github` is EMPTY.
