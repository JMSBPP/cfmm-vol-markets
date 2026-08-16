---
phase: 23-postgres-foundation-byte-exact-schema
plan: 05
subsystem: database
tags: [conformance, freshness, sentinel-harness, override-sweep, bytea, jsonb, migrations, credentials]

# Dependency graph
requires:
  - "23-01: Store.Types (adversarial_corpus + cm_bytes, the two golden pins, sha256_hex), Store.Config (the two resolvers and the two env-var constants)"
  - "23-02: expected_store_laws as a SET, the corpus SET, Store.Laws"
  - "23-03: Store.Schema (expected_migrations, identity_constraint_name/columns), the two migrations"
  - "23-04: offchain/rig/store-conformance.json — the committed evidence, 8/8 verdicts, server_version 18.4"
provides:
  - "Twelve Tier-C checks over store-conformance.json — every DB-only value plan 23-04 measured is now asserted, and the artifact FAILS-never-skips when absent"
  - "A COMPUTED freshness oracle: each migration's md5 recomputed from the repo's own bytes, so a .sql edited without a re-capture reddens"
  - "bare_path_prediction — an outside-oracle MODEL of the broken write path (NUL truncation then legacy escape decode) that reproduces all five returning corpus members exactly, in length AND digest"
  - "store_overrides_are_probed_or_named_as_gaps + unprobed_overrides — the honest, ASSERTED record of the one override this suite cannot probe"
  - "store-conformance.json as the FIFTH swept artifact, with both sentinel floors RE-MEASURED at five artifacts"
  - "no_credential_is_present_in_a_tracked_file — DB-02 as a scan with a positive control that also proves the environment forms do NOT match"
affects: [24 toolchain identity, 25 content key, 26 fee split]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "A MODEL of the failure mechanism as the expected side: the bare path's damage is COMPUTED from cm_bytes (truncate at the first NUL, decode legacy backslash escapes) and compared to what a real server did, instead of pinning the recorded output beside it"
    - "An override that cannot honestly be probed goes in an ASSERTED gap list with the two halves that ARE measurable exercised — never a validator written only to satisfy the probe"
    - "A tree-derived floor is re-measured by RAISING it until the instrument reports the number it actually reached, never by adding an estimate to the old one"
    - "An error text is anchored to a value from OUTSIDE the artifact (the member name it must contain), which turns a recorded string into a cross-check"

key-files:
  created: []
  modified:
    - offchain/test/Main.hs
    - cfmm-replicationPlank-rpc-api.cabal

key-decisions:
  - "PGSTORE_DSN is NOT registered in advertised_overrides. Its consumer is libpq, reachable only through the client module and the capture executable, and neither is reachable from cabal test BY CONSTRUCTION — that is DB-03. Manufacturing a consumer (a validate_dsn written only to be probed) would be a registered-but-vacuous probe, the exact defect the sweep exists to catch. It goes in an ASSERTED unprobed_overrides list with a written reason"
  - "The harness reported FOUR fields of the new artifact absorbed on its first run; THREE were asserted rather than pardoned, and asserting bare_out_len/bare_out_sha256 required modelling the mechanism rather than pinning the values"
  - "The drift MESSAGE is asserted for the FILE IT NAMES and never for the words 'checksum mismatch', which do not appear on that path — and that arm reproduces 23-04's real defect (a server NOTICE recorded in its place)"
  - "The credential pattern and its bait are BUILT from fragments, because spelled out contiguously they match the file asserting their absence — the fifth time prose has turned out to be inside a grep's blast radius on this branch"
  - "sentinel_pair_floor and all five artifact_field_floors RE-MEASURED in one run at five artifacts; the four older per-artifact numbers came back unchanged, which is what says none of them shrank while this one was added"

requirements-completed: [DB-01, DB-02, DB-03, DB-04, BYTE-01, BYTE-02, BYTE-03, BYTE-05, KEY-07]
requirements-partial: []

# Metrics
duration: 71min
completed: 2026-08-16
---

# Phase 23 Plan 05: The Evidence Made Load-Bearing Summary

**Thirteen new checks turn `offchain/rig/store-conformance.json` from a committed file nothing read
into the artifact eleven assertions rest on, and the sweep that finds unasserted fields now reaches
it. Sixteen falsifications were OBSERVED, each against its named input. The bare path's damage
turned out to be PREDICTABLE from the mechanism, which upgraded two fields from "pardon them" to an
outside oracle. `PGSTORE_DSN` could not be honestly probed and is recorded as an asserted gap rather
than given a probe written to pass.**

## Performance

- **Duration:** 71 min
- **Tasks:** 2
- **Files:** 2 modified
- **`cabal test` WALL:** **78 s before** (four artifacts, 98 checks) → **97 s after** (five
  artifacts, 111 checks). Budget was 900 s. **The artifact was NOT narrowed.**

## The suite count, and the arithmetic from the cold baseline

```
23-01 COLD BASELINE (re-measured, not inherited)        91/91
23-01 end   types only, no check registered             91/91   (+0)
23-02 end   the law suite, the corpus SET, BYTE-03      96/96   (+5)
23-03 end   the migration manifest, KEY-07's file half  98/98   (+2)
23-04 end   the capture (the new law is DATA, not a check) 98/98 (+0)
23-05 end                                             111/111   (+13)
```

**+13 = 12 Tier-C checks (task 1) + 1 override-gap check (task 2).** `91 + 5 + 2 + 0 + 13 = 111`.
`cabal test` exit 0, **FAIL count 0**, and still DB-free:

```
grep -cE 'Store\.Postgres|connectPostgreSQL|CFMM_REQUIRE_DB' offchain/test/Main.hs   ->  0
cabal build --enable-tests -j all   exit 0, 0 lines matching ^offchain/[^ ]*:[0-9]+:[0-9]+: warning:
                                    (after every task and after every one of the sixteen probes)
```

## THE FOUR FALSIFICATIONS THE PLAN NAMES, VERBATIM

`offchain/rig/store-conformance.json` sha256 **`1e5f076af2b5c2839ca590f637959af49b57c5559942dab3014e9a293d332153`
before and after all sixteen probes, IDENTICAL.** Every artifact probe ran against a scratch copy
under `/tmp` with `STORE_CONFORMANCE` pointed at it, and the committed digest was re-compared after
each one.

### 1. ABSENT — fails, never skips, and names the command

```
FAIL store_conformance_is_present_and_fresh: no /nonexistent-probe/x.json -- re-take it with: bash offchain/rig/capture-store-conformance.sh
```

**All ELEVEN artifact-reading checks failed**, each with that shape. Not one went quietly green.
(The twelfth new check, `no_credential_is_present_in_a_tracked_file`, does not read the artifact and
correctly stayed silent.)

### 2. STALE — the REAL `.sql` edited, the digest RECOMPUTED

`-- freshness probe` appended to `offchain/migrations/002_byte_corpus.sql`:

```
FAIL store_conformance_is_present_and_fresh: the committed conformance capture is STALE. These migrations have been edited since it was taken:
      002_byte_corpus.sql: recorded=9e89722c2ca66bd632f4f5f343934e2f recomputed=ff649f32dc294e3f15a8ba1f450356cb
      Every DB-only verdict in that artifact was measured against the OLD schema. Nothing here can tell you whether it still holds. Re-take it: bash offchain/rig/capture-store-conformance.sh
```

Restored from a **SAVED COPY** and verified by diffing digest files. `git checkout --` was not used
anywhere in this plan.

### 3. TRUNCATED — `sc_complete` false

```
FAIL store_conformance_is_present_and_fresh: the capture did not reach the end: sc_complete is False. The flag starts False and is flipped last, after every observation block has returned, so this is a TRUNCATED run and not a stale one -- the values below were never all produced. Re-take it: bash offchain/rig/capture-store-conformance.sh
```

### 4. A LAW VERDICT MISSING — reported as a SET mismatch, not a count

`law_key_scheme_orphans_rather_than_matching` deleted from `law_verdicts`:

```
FAIL store_conformance_verdicts_are_all_pass: a law the set names has NO VERDICT in the capture: law_key_scheme_orphans_rather_than_matching
```

**Note what did NOT fire: `sc_law_count` is still 8.** A count-based instrument would have passed
this input. That is the whole reason the verdicts are a set in both directions, demonstrated rather
than argued.

## THE OTHER TWELVE FALSIFICATIONS OBSERVED

| # | Input | Check that reddened, verbatim head of the message |
|---|---|---|
| 5 | a verdict set to `"fail: 4 bytes in, 3 out"` | `store_conformance_verdicts_are_all_pass: the store contract does NOT hold against a real Postgres…` |
| 6 | `corpus[octal-escape]` recorded as round-tripping | `bare_bytestring_…: octal-escape is the DISCRIMINATING member and it came back UNCHANGED through the bare path: 6 bytes / 3a515689… in, 6 bytes / 3a515689… out` |
| 7 | all three `SilentlyCorrupted` members retagged `ServerRejects` in the artifact | `bare_bytestring_…: nul: the capture recorded behaviour "ServerRejects" and Store.Types tags it "SilentlyCorrupted"` |
| 8 | **`Store.Types` mutated too**, so the corpus has no `SilentlyCorrupted` class at all | `bare_bytestring_…: NOT ONE captured member was recorded as returning a WRONG VALUE with no complaint. The corpus has lost its discriminating member…` — **the anti-collapse arm**, and the only way to reach it is a coordinated mutation of source and artifact |
| 9 | `corpus[crlf].in_sha256` replaced | `store_conformance_digests_match_the_pinned_source_digest: the capture's recorded input digests do not match the digests of the corpus bytes in Store.Types` |
| 10 | `doc_text_sha256 := raw_out_sha256` | `jsonb_round_trip_…: the exhibit records the jsonb projection and the bytea artifact as BYTE-IDENTICAL. That does not mean jsonb is safe -- it means the exhibit has stopped exercising jsonb…` |
| 11 | `checksum_drift_exit := 0` | `store_conformance_records_a_nonzero_exit_on_checksum_drift: the capture recorded exit 0 on checksum drift.…` |
| 12 | **23-04's real defect replayed** — the drift stderr set back to `NOTICE:  relation "schema_migrations" already exists, skipping` | `store_conformance_records_a_nonzero_exit_on_checksum_drift: the recorded drift message does not name the migration that drifted` |
| 13 | `after_release_applied := 0` | `store_conformance_records_the_second_migrator_applying_nothing: THE POSITIVE CONTROL FAILED: after release, the second migrator applied 0 migrations…` |
| 14 | `empty_db_run2_applied := 1` | `store_conformance_records_two_runs_from_an_empty_database: the second run against the same database applied 1 migrations and should have applied none.` |
| 15 | `image_tag := "postgres:latest"` | `store_conformance_records_the_pinned_image_and_server_version: the capture provisioned "postgres:latest" and this suite is written against "postgres:18-alpine"` |
| 16 | `unique_constraint.columns := ["model","key"]` | `store_conformance_records_the_live_identity_constraint: the LIVE catalogue reports the identity constraint over ["model","key"] and KEY-07 requires ["model","key_scheme","key"]` |
| 17 | `json_agreement[nul-escape].postgres_accepts := true` | `json_recogniser_agrees_with_jsonb_except_where_measured: the ONE measured divergence (nul-escape-in-a-string) no longer reproduces…` |
| 18 | `exponent-1e100000` probe deleted | `json_recogniser_…: the json-agreement probe SET has moved. Not captured: exponent-1e100000` — the probe that records a REFUTED prediction, and the first one a tidying pass would delete |
| 19 | a DSN seeded into `offchain/rig/__db02-bait.sh` | `no_credential_is_present_in_a_tracked_file: a credential is written down in a tracked file under offchain/… offchain/rig/__db02-bait.sh:1:DSN=postgres://u:hunter2@localhost:5432/db` |

Plus five source-mutation probes on the override machinery (§ below). Every mutated source file was
restored from a **SAVED COPY** and verified by diffing digest files: `offchain/lib/Store/Types.hs`,
`offchain/migrations/002_byte_corpus.sql`, and `offchain/test/Main.hs` three times over.

## THE FINDING THAT CHANGED THE PLAN: the bare path is PREDICTABLE

The plan's guard budget expected the corpus block to be largely pardoned. The sentinel harness,
on its first run over the new artifact, reported exactly four fields absorbed:

```
store-conformance.json.corpus[].bare_error        x4 per sentinel
store-conformance.json.corpus[].bare_out_len      x2  (numeric-zero only)
store-conformance.json.corpus[].bare_out_sha256   x3
store-conformance.json.generatedAt                x1 per sentinel
```

**Three of the four were ASSERTED rather than pardoned**, and the middle two required noticing that
the damage is not arbitrary. The bare path composes two mechanisms, both already MEASURED in this
phase:

1. `ToField ByteString` is `Escape`; libpq's C-string escaper stops at the first NUL (23-04);
2. what arrives is read by `byteain`, which still accepts the legacy escape format — `\\` collapses
   to one backslash and `\NNN` is re-read as one octal byte (23-01).

`bare_path_prediction` composes them. It is written from the mechanisms, in the test file, over
`cm_bytes` from `Store.Types` — **the expected side never touches the artifact.** MEASURED against
what a real Postgres 18.4 did:

```
member             in   predicted   recorded   len ✓   sha256 ✓
nul                 1       0           0        ✓       ✓
crlf                4       4           4        ✓       ✓
trailing-newline    2       2           2        ✓       ✓
octal-escape        6       3 ("aAb")   3        ✓       ✓
double-backslash    4       3 ("a\b")   3        ✓       ✓
```

All five agree in **length and digest**. That converts BYTE-05's negative control from *"fewer
bytes came back"* into *"exactly the bytes the mechanism predicts came back"* — an outside oracle,
not a transcription. `bare_error` was closed separately by asserting it NAMES its own member (the
capture writes the row key from `cm_name`, so an error text copied from another member's run does
not contain this one's).

**One pardon remains**, and it is the field 21-02 already measured as not being a regeneration
witness:

```haskell
( "store-conformance.json.generatedAt"
, [("empty-string",1),("numeric-zero",1),("zero-address",1),("zero-word",1),("git-null-object-id",1),("json-null",1)]
, reason_generated_at )
```

**Count of `absorbed_by_design` entries whose path begins `store-conformance.json.`: 1.** Its reason
is `reason_generated_at`, reused rather than re-authored, and it explains WHY (a 1-second stamp
resolution against a sub-second capture) rather than noting that the field is unread.

## `PGSTORE_DSN` — THE ROUTE TAKEN, AND WHY

**Route: a NAMED GAP in a new, asserted `unprobed_overrides` list. It is NOT in
`advertised_overrides`, and `probe_override` was not weakened.**

`probe_override` asserts three things and the third is the load-bearing one: pointing the variable
at a value nothing can resolve makes the **consumer** fail, NAMING that value. `PGSTORE_DSN`'s
consumer is libpq, reached through the client module and the capture executable — and **neither is
reachable from `cabal test` by construction.** That is what DB-03 is, and the three-token grep over
`offchain/test/Main.hs` that must return 0 is its structural form.

There were exactly two ways to manufacture a subject, and both were rejected:

- **import the client and let the probe attempt a connection.** Breaks DB-03 on the way to
  enforcing DB-02, and turns every contributor's first `cabal test` into a socket call.
- **write a `validate_dsn` in the config module that rejects the probe value.** This is the worse
  one *because it looks right*. The function would exist only to be probed; its rejection would
  prove that a function written to reject rejects, and would say nothing about whether the variable
  steers a connection. That is a registered-but-vacuous probe — the exact defect the sweep exists to
  catch — installed to close the sweep's own list.

So the gap is named, and the two halves that ARE honestly measurable are **asserted**, not
commented: the resolver returns the override verbatim, and it returns something other than its unset
default. A `pgstore_dsn` that stopped reading the environment reddens. The check also asserts that
the two lists are DISJOINT, that every variable `Store.Config` names appears in exactly one of them
(so a rename in the library that this file does not follow reddens), and that each reason is a real
paragraph rather than a stub.

**What nothing in `cabal test` can tell you** is whether the resolved DSN reaches a connection. The
evidence that it does lives in the capture: `capture-store-conformance.sh` exports the variable and
the artifact it produced records `server_version 18.4`, which is a value no unconsumed DSN could
have produced. That is written into the reason constant, in those terms.

## The override machinery, OBSERVED firing

`every_advertised_override_is_honoured` passes with the new entry. Five probes, each on a saved copy
of `Main.hs`:

**(a) the consumer's failure text NAMES the resolved path** — the criterion the plan asks for
verbatim:

```
FAIL store_conformance_is_present_and_fresh: no /nonexistent-override-probe/STORE_CONFORMANCE.json -- re-take it with: bash offchain/rig/capture-store-conformance.sh
```

**(b) the resolver stops honouring the variable** (`store_conformance_path` → a constant):

```
FAIL every_advertised_override_is_honoured: STORE_CONFORMANCE is ADVERTISED and DEAD: its resolver returned "offchain/rig/store-conformance.json" with the variable set to "/nonexistent-override-probe/STORE_CONFORMANCE.json". Every falsification aimed through this variable is vacuous until it is honoured -- measured three times in this module already (22-03 RIG_MANIFEST, 22-04 RIG_CHEAT_SWAP_PROOF, 22-07 RIG_PINS).
```

**(c) nothing consumes the resolved path** (`ov_probe` → `pure Nothing`):

```
FAIL every_advertised_override_is_honoured: STORE_CONFORMANCE resolved to "/nonexistent-override-probe/STORE_CONFORMANCE.json" and the consumer LOADED ANYWAY. A resolver whose result nothing reads is the same defect one layer down: the override looks live and still cannot aim a falsification at anything.
```

**(d) a variable both probed and pardoned:**

```
FAIL store_overrides_are_probed_or_named_as_gaps: these variables are BOTH probed and pardoned as unprobed gaps: STORE_CONFORMANCE. A variable in both lists is excused and counted at the same time.
```

**(e) the library renames the variable and this file does not follow** (`"PGSTORE_DSN"` →
`"PGSTORE_DSN_OLD"`):

```
FAIL store_overrides_are_probed_or_named_as_gaps: the store advertises these environment variables and this file's override lists name NEITHER of them: PGSTORE_DSN.
```

**(f) a pardon with a stub reason** (`"not needed"`):

```
FAIL store_overrides_are_probed_or_named_as_gaps: these unprobed-override entries carry no real reason: PGSTORE_DSN.
```

## The sentinel harness — floors RE-MEASURED, never incremented

Both floors were measured by **raising the constant until the harness reported the number it had
actually reached**, then setting it to that number. No arithmetic was performed on the old values.

```
sentinel_pair_floor      2457 (four artifacts)  ->  3250  MEASURED at five
artifact_field_floors    rig-manifest.json          20    (re-measured, UNCHANGED)
                         rig-pins.json             110    (re-measured, UNCHANGED)
                         driver-run-capture.json   151    (re-measured, UNCHANGED)
                         cheat-swap-proof.json     130    (re-measured, UNCHANGED)
                         store-conformance.json    134    NEW
```

The four older per-artifact numbers came back at exactly the values they were written with. That is
what says none of them shrank while this one was being added — which a total-only floor cannot say.

**The arithmetic is the check on the measurement:** 134 leaves × 6 sentinels = 804 possible pairs;
793 were exercised, the 11 missing ones being mutations the harness SKIPS as identities (the several
recorded zeroes, the two empty digests, the five null error fields). `3250 − 2457 = 793`. So the four
older artifacts still contribute exactly 2457.

### A correction to 23-04's carried-forward budget input

**The harness enumerates 134 leaves, not 121.** 23-04's 121 is `jq 'paths(scalars)'`, which **omits
JSON nulls**; the harness's `scalar_json_paths` treats a null as a leaf and mutates it. Both numbers
are right about their own question, and the harness's is the one to budget with. Recorded in
`sentinel_pair_floor`'s haddock for whoever adds the sixth artifact.

### The harness is reaching the new artifact — proven, not assumed

The negative control (`__sentinel_harness_probe`) still passes. And a deliberately-bogus pardon for a
field that IS asserted made the harness name a caught leaf of the new artifact itself:

```
FAIL sentinel_falsification_harness: absorbed_by_design lists (field, sentinel) pairs that are now CAUGHT:
      store-conformance.json.image_tag  :=  empty-string  x1
```

130 of the artifact's 134 fields were reported caught on the first run, and one is named here by the
harness's own report. Its "absorbed" verdicts are therefore not vacuous.

## THE NINETEEN-GUARD LEDGER — the phase's gate, closed

One row per guard in `23-RESEARCH.md` § *"Every guard, and the input that makes it fire"*.

| # | Guard | Input that made it fire | Plan | Evidence |
|---|---|---|---|---|
| 1 | `Binary` on write (value-level kill) | `a\101b`, 6 bytes | 23-04 DRIVEN, 23-05 ASSERTED | recorded `6 → 3, "returned"`; and `FAIL bare_bytestring_…: octal-escape … came back UNCHANGED` when the artifact says otherwise |
| 2 | `Binary` on write (secondary, loud) | `0xFF`, `0xC3 0x28` | 23-04 DRIVEN, 23-05 ASSERTED | both `SqlError`. **`nul` is NOT in this row — 23-04 falsified it**; `FAIL … recorded behaviour "ServerRejects" and Store.Types tags it "SilentlyCorrupted"` |
| 3 | corpus discrimination | 23-02: delete `octal-escape` (did NOT discriminate → `expected_corpus_members` added). 23-05: remove the whole class | 23-02, 23-05 | `FAIL bare_bytestring_…: NOT ONE captured member was recorded as returning a WRONG VALUE with no complaint` |
| 4 | `bytea` authoritative | the real 606-byte artifact; then `doc_text := raw_out` | 23-04 DRIVEN, 23-05 | `b50a14b4… ≠ e7b14f38…` measured; `FAIL jsonb_round_trip_…: … BYTE-IDENTICAL … the exhibit has stopped exercising jsonb` |
| 5 | `jsonb` never compared | add `deriving Eq` to `DerivedDoc`; write a `DerivedDoc -> Artifact` | 23-01 | G1 and G3, both **compile errors**, exit 1 |
| 6 | aeson off the storage path | a seeded import in `Store/Schema.hs`, then in the REAL `Store/Postgres.hs` | 23-02, 23-03 | scan branch fired naming `Store/Schema.hs:47`; observed again against the real module |
| 7 | aeson still mutates | a pinned vector whose round trip IS the identity (`{"d":1}`) | **23-05** | `FAIL aeson_round_trip_mutations_are_re_measured: aeson's decode->encode has become the identity on "{\"d\":1}"` — **this row was empty until this plan**; see finding 2 |
| 8 | migration checksum drift | a comment appended to `001_*.sql` | 23-04 DRIVEN, 23-05 ASSERTED | recorded exit `1`; `FAIL …: the capture recorded exit 0 on checksum drift` |
| 9 | migration concurrency | a second migrator against a held lock | 23-04 DRIVEN, 23-05 ASSERTED | `false`/`0`, and the release control `true`/`1`; `FAIL …: THE POSITIVE CONTROL FAILED: after release, the second migrator applied 0` |
| 10 | migration from empty | a fresh container, run twice | 23-04 DRIVEN, 23-05 ASSERTED | `run1 true`, `run2_applied 0`; `FAIL …: the second run … applied 1 migrations` |
| 11 | `key_scheme` orphaning | write under scheme 1, read under scheme 2 | 23-02, 23-04 | both KEY-07 laws fired against a `(model,key)` store; both pass live |
| 12 | unique constraint completeness | drop `key_scheme` from the DDL; then from the recorded catalogue | 23-03 (file), **23-05 (live)** | `FAIL store_conformance_records_the_live_identity_constraint: the LIVE catalogue reports … ["model","key"]` |
| 13 | **`PGSTORE_DSN` override** | `PGSTORE_DSN=/nonexistent-override-probe/PGSTORE_DSN.json` | — | **NEVER OBSERVED. PHASE-LEVEL FINDING — see below.** |
| 14 | `STORE_CONFORMANCE` override | the same probe shape | **23-05** | three arms: resolver dead, consumer loaded anyway, and the failure text containing `/nonexistent-override-probe/STORE_CONFORMANCE.json` |
| 15 | conformance freshness | `-- freshness probe` appended to `002_byte_corpus.sql` | **23-05** | `recorded=9e89722c… recomputed=ff649f32…` |
| 16 | conformance completeness | `sc_complete := false`; a verdict deleted | **23-05** | the truncation message; and the set mismatch **while `sc_law_count` still read 8** |
| 17 | law SET | rename a law in `Store.Laws`; delete a verdict key | 23-02, **23-05** | GUARD #17 at 23-02; `a law the set names has NO VERDICT in the capture` here |
| 18 | sentinel harness | a leaf no check reads | **23-05** | four field-groups reported absorbed by name with their sentinels, three then asserted; and a caught leaf named by the harness itself |
| 19 | `sc3_literal_purge` | a `0x`-prefixed 40-hex literal in a `.sql` | 23-03 | GUARD #19, the scan branch, exit 0 |

**18 of 19 observed. One is a phase-level finding.**

### PHASE-LEVEL FINDING — guard #13 has no observation and cannot get one offline

The research table's `PGSTORE_DSN` row asks that the consumer fail naming the probe value. **No such
observation exists anywhere in this phase, and one cannot be made from `cabal test`** — the consumer
is libpq and DB-03 forbids reaching it. It is named here rather than omitted, and it is registered
in `unprobed_overrides` rather than papered over with a probe written to pass. A guard never seen
rejecting is treated as ABSENT; this one is recorded as absent, with the reason, and with the two
adjacent properties that ARE asserted so that the entry is not merely a comment.

The **only** evidence that `PGSTORE_DSN` is honoured end to end is 23-04's capture, which exports it
and gets a `server_version` back. That evidence is real, and it is not a `cabal test` observation.

## Requirement status — the phase's nine, and why they are marked COMPLETE now

Four plans running, `requirements mark-complete` was deliberately NOT run, on the grounds that
evidence unread by any check is the artifact-asserted-by-nothing shape (issue #19). **That condition
is now discharged.**

| Req | Verdict | The assertion that discharges it |
|---|---|---|
| **DB-01** | **Complete** | Drift exits 1, the empty-db second run applies 0, the second migrator gets `f`/0 and after release `t`/1 — all four ASSERTED, and all four OBSERVED reddening. |
| **DB-02** | **Complete** | `no_credential_is_present_in_a_tracked_file` over 56 files in four extensions, with a positive control that fires on a seeded DSN AND proves the environment forms do NOT match. `store_overrides_are_probed_or_named_as_gaps` asserts both variables resolve from the environment. |
| **DB-03** | **Complete** | `cabal test` is green with no database, the three-token grep is 0, and the store checks DISCRIMINATE — proven by nineteen observed falsifications, not by the suite being green. |
| **DB-04** | **Complete** | `image_tag == "postgres:18-alpine"` (asked for) **and** `server_version` starts `18.` (replied). Two-sided; the tag alone passes against a stale local image. |
| **BYTE-01** | **Complete** | Every corpus member round-trips byte-identically through the `Binary` path, and the real 606-byte artifact's `raw_out == raw_in`, both ASSERTED against the pin in `Store.Types`. |
| **BYTE-02** | **Complete** | A compile-time guarantee (23-01) plus `doc_text_sha256 /= raw_out_sha256` asserted as an INEQUALITY, observed reddening when made equal. |
| **BYTE-03** | **Complete** | `aeson_is_absent_from_the_storage_path` green over eight files that all exist with a proven positive control; and guard #7's identity arm now OBSERVED. |
| **BYTE-05** | **Complete, and STRONGER than the requirement asks** | Three members corrupt silently, and the corruption is now compared to a MODEL of the mechanism rather than to a recorded value — exact in length and digest for all five returning members. |
| **KEY-07** | **Complete** | Three subjects: the Haskell constant, the DDL text (23-03), and the LIVE catalogue (here). All three asserted; the file half and the live half each observed reddening. |

## Task Commits

1. **The Tier-C checks — the committed evidence becomes load-bearing** — `96736a4` (feat)
2. **The fifth swept artifact, the honest `PGSTORE_DSN` gap, floors re-MEASURED** — `90f6c4f` (feat)

## Files Created/Modified

- `offchain/test/Main.hs` — **modified.** Thirteen checks; `json_object_pairs`; `md5_hex` and the
  freshness oracle; `bare_path_prediction` and `decode_legacy_escapes`; the credential scan with its
  built pattern, built bait and re-measured floor; `UnprobedOverride`/`unprobed_overrides`; the fifth
  `MutableArtifact`; both floors re-measured; one `absorbed_by_design` entry.
- `cfmm-replicationPlank-rpc-api.cabal` — **modified.** `crypton` added to the test-suite stanza for
  the md5 the migration library speaks. **Not a new package** — already resolved at 1.0.6 through the
  library stanza and through `web3-crypto`'s `crypton <1.1` pin; the build printed no `Downloading`.

## Decisions Made

- **`PGSTORE_DSN` gets a named gap, not a probe.** Written up in full above. This was the plan's own
  explicit fork and the brief's explicit warning; both options for manufacturing a consumer were
  rejected and the reason is in the source, not only here.
- **Assert three of the four absorbed fields rather than pardon them.** The plan permitted a pardon
  with a written reason. A pardon would have been the cheaper honest answer; modelling the mechanism
  was the better one, and it is the difference between recording that bytes were lost and predicting
  exactly which.
- **The drift message IS asserted — for the filename, never for "checksum mismatch".** 23-03's
  source-read and 23-04's measurement both say the payload is the script name. The brief said not to
  assert the mismatch text; it did not say to assert nothing. The filename comes from
  `expected_migrations`, and the arm reproduces 23-04's real defect (a server `NOTICE` recorded in
  its place), so it is a guard with a demonstrated catch rather than a decoration.
- **`json_agreement` is asserted, though the plan did not ask for it.** 23-04 added the block to make
  the user ruling falsifiable per input. Leaving it unasserted would have meant pardoning 27 leaves of
  the phase's own central claim. The check asserts the probe SET, that every probe agrees, AND that
  the one measured divergence still diverges — so a capture in which it quietly stopped reproducing
  reddens instead of silently widening what the recogniser is trusted for.
- **A twelfth Tier-C check, `no_credential_is_present_in_a_tracked_file`, is in `expensive_checks`.**
  It spawns a recursive grep and reads none of the swept artifacts, so the sentinel harness filters it
  out of every per-mutation run; the ordering constant keeps it last in the runs that do include it.
- **The credential pattern permits the ENVIRONMENT forms and rejects only literals.** `password=$VAR`
  and `POSTGRES_PASSWORD="$VAR"` do not match; `password=hunter2` does. A pattern that matched the
  capture script's legitimate form would have to be relaxed the first time it fired, which is how a
  credential scan becomes decorative — and the positive control asserts BOTH directions.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing critical] two corpus fields would have been pardoned; they are assertable**
- **Found during:** Task 2, reading the harness's first report over the new artifact
- **Issue:** `bare_out_len` and `bare_out_sha256` were reported absorbed for the `SilentlyCorrupted`
  members. Every inequality-shaped assertion available (`bare_len < in_len`, `bare_sha /= in_sha`)
  leaves the numeric-zero sentinel absorbed, because 0 is a plausible truncation.
- **Fix:** `bare_path_prediction` — a model of the two mechanisms, computed from `cm_bytes`. Verified
  against all five returning members in length AND digest before it was written into the check.
- **Verification:** the harness's absorbed list for those two fields is now empty; `cabal test` 111/111.
- **Commit:** `90f6c4f`

**2. [Rule 2 - Missing critical] guard #7 had never been observed firing**
- **Found during:** Task 2, compiling the nineteen-guard ledger
- **Issue:** `aeson_round_trip_mutations_are_re_measured`'s *"the round trip became the identity"*
  arm is guard #7 in the research table. 23-02 registered it and recorded it GREEN; no plan ever
  observed it rejecting. A guard never seen rejecting is treated as absent, so the ledger would have
  closed with two findings rather than one.
- **Fix:** OBSERVED, by pinning a vector whose round trip genuinely is the identity — which is the
  research table's own named input for this row. Message quoted in the ledger.
- **Verification:** the vector was restored from a saved copy and the digest diffed; suite 111/111.
- **Recorded in:** this summary; no source change was kept.

**3. [Rule 1 - Prose inside a grep's blast radius, fourth instance on this branch]**
- **Found during:** Task 1, the DB-free acceptance grep
- **Issue:** a FAILURE MESSAGE in the new `json_agreement` check named the postgres store module in
  prose. `grep -cE 'Store\.Postgres|connectPostgreSQL|CFMM_REQUIRE_DB' offchain/test/Main.hs`
  returned **1**. The grep IS the structural form of DB-03's claim, so the file asserting the
  absence would have been counted by the scan asserting it.
- **Fix:** reworded to "the real client". The grep returns 0.
- **Commit:** `96736a4`
- **Carry forward:** the same trap took the credential pattern and its bait, which are BUILT from
  fragments for exactly this reason. That is the fifth and sixth instance.

### Deviations from acceptance criteria, properties verified directly

**4. `/usr/bin/time` does not exist on this machine.** The plan's `<verify>` block invokes it
directly; the WALL figures above were taken with `date +%s` around the invocation instead. The
property — before and after, recorded, compared to the 900 s budget — is unaffected.

**5. `grep -c '"PGSTORE_DSN"'` returns 1, in `unprobed_overrides` rather than `advertised_overrides`.**
The plan permits either and asks which; the answer is above. The literal is written out AND asserted
equal to `Store.Config.pgstore_dsn_env_var`, which is the two-subject idiom this file already uses
for the identity constraint.

**6. The plan asks for ten checks; thirteen landed.** Ten as specified, plus
`json_recogniser_agrees_with_jsonb_except_where_measured` (27 leaves the plan did not budget for),
`no_credential_is_present_in_a_tracked_file` (the plan's item 11, which its own count omitted), and
`store_overrides_are_probed_or_named_as_gaps` (task 2's gap list, asserted).

---

**Total deviations:** 6 (2 missing-critical strengthenings — one of which found a guard that had
been registered for three plans without ever being seen to reject; 1 prose-in-a-grep fix; 3
acceptance deviations with the properties verified directly)
**Impact on plan:** No scope creep, nothing weakened. Deviation 1 is the substantive one: the plan
budgeted for the corpus block to be pardoned and it turned out to be predictable, which makes
BYTE-05's control an oracle rather than a bound. Deviation 2 is the one worth carrying: a guard can
sit registered, green and cited for three plans without anyone having watched it reject, and only
compiling the ledger surfaced it.

## Issues Encountered

Beyond the deviations: none. Every build exited 0 with zero `offchain/` warning lines after every
task and after every one of the sixteen probes. The only warnings produced anywhere in this plan
came from deliberate mutants (`-Wunused-imports` on the stub-reason probe, which orphaned
`reason_dsn_has_no_offline_consumer`) — a small confirmation that the probe was a real code change
rather than a no-op.

## Out of scope, logged not fixed

`deferred-items.md` in this directory is unchanged and still applies: `225a/` (GAMS scratch,
pre-dating this phase) and the untracked `CHANGELOG.md` / `Setup.hs` / `stack.yaml*`, the first of
which is named by the `.cabal`'s `extra-doc-files` so an `sdist` from a clean checkout would fail.
Neither is this workstream's territory.

## User Setup Required

None. `cabal test` needs no database, no container and no network, and opens no socket. Re-taking
the evidence still needs `docker` and `jq`:
`bash offchain/rig/capture-store-conformance.sh`.

## Next Phase Readiness

Phase 23 is COMPLETE — 5/5 plans, all nine requirements. Carry forward to phase 24 and 25:

- **The harness enumerates 134 leaves of `store-conformance.json`, not 121.** Budget the sixth
  artifact with `scalar_json_paths`'s number (nulls included), not `jq 'paths(scalars)'`'s.
- **`sentinel_pair_floor` is 3250 and `artifact_field_floors` has five entries.** Re-measure by
  raising the constant until the harness reports what it reached. Never add an estimate.
- **`purge_file_floor` is 48 and `credential_scan_floor` is 56**, both RE-MEASURED cold at the end of
  this plan. Extension census under `offchain/`: `hs 38, sh 8, json 8, md 3, txt 2, sql 2`. Phase 25
  will move both.
- **Guard #13 (`PGSTORE_DSN`) is an open phase finding.** If phase 25 or 26 introduces a consumer of
  the DSN that is reachable offline, that is the moment to move the entry from `unprobed_overrides`
  into `advertised_overrides` — and the moment to be suspicious of any consumer introduced *in order
  to* move it.
- **Any new module under `offchain/lib/Store/` goes into `aeson_storage_path` in the commit that
  creates it.** Still true; phase 25 adds more.
- **A new committed artifact needs three things in the same plan:** an `OverrideProbe` (or a written
  gap), a `MutableArtifact` entry, and a re-measured `artifact_field_floors` row. This plan is the
  worked example.
- **The credential pattern permits `VAR=$EXPANSION` and rejects literals.** A future capture script
  that hardcodes a password will redden; one that passes it through the environment will not. That
  line is deliberate and its positive control asserts both sides of it.
- **Territory clean:** `git status --porcelain src test foundry-scripts Makefile foundry.toml
  .github` is EMPTY, and so is `git status --porcelain offchain/`.

---
*Phase: 23-postgres-foundation-byte-exact-schema*
*Completed: 2026-08-16*

## Self-Check: PASSED

Re-verified against disk and git rather than asserted.

- Both commits resolve: `96736a4`, `90f6c4f`.
- Both modified files exist and are tracked (`git ls-files --error-unmatch`):
  `offchain/test/Main.hs`, `cfmm-replicationPlank-rpc-api.cabal`. No file was created by this plan,
  and the frontmatter says so.
- All **thirteen** new check names exist in `offchain/test/Main.hs`, and
  `grep -c` over the `core_checks` registration lines returns **13** — definition and registration
  for each, none orphaned.
- `bare_path_prediction` and `unprobed_overrides` are present and referenced (3 and 7 occurrences).
- `absorbed_by_design` entries whose path begins `store-conformance.json.`: **1** — matching the
  count claimed above.
- Floors read back from source: `sentinel_pair_floor` **3250**, `purge_file_floor` **48**,
  `credential_scan_floor` **56**. The last two re-measured cold from `find` at plan end and equal.
- `artifact_field_floors` has **five** entries, the new one `("store-conformance.json", 134)`.
- `offchain/rig/store-conformance.json` sha256 **`1e5f076a…d332153`** — byte-identical to the value
  at plan start, after all sixteen artifact probes and six source mutations.
- Final suite: **111/111, FAIL count 0**; `cabal test` exit 0; **0** `offchain/` warning lines under
  `cabal build --enable-tests -j all`.
- `grep -cE 'Store\.Postgres|connectPostgreSQL|CFMM_REQUIRE_DB' offchain/test/Main.hs` = **0**.
- `git status --porcelain offchain/` is EMPTY — every probe removed, every mutated file restored
  from a SAVED COPY and verified by diffing digest files. `git checkout --` was not used.
- `git status --porcelain src test foundry-scripts Makefile foundry.toml .github` is EMPTY.
