# Pitfalls Research

**Domain:** Adding a Postgres/JSONB content-addressed model-output cache, a GAMS subprocess layer, and a resident chain-watching loop to an existing Haskell/Foundry monorepo (v6.0)
**Researched:** 2026-08-16
**Confidence:** HIGH for the byte-exactness, Postgres, aeson and GAMS-exit-code findings (measured locally or quoted from official docs); MEDIUM for the resident-loop and CI-integration findings (official docs + repo inspection, not measured end-to-end)

---

## How to read this document

Every pitfall below is an instance of one predicate, and it is the predicate this repo has
already been burned by six times:

> **A guard that passes must have *read information*. A comparand that is empty, zero,
> defaulted, absent, or derived from its own comparison target proves nothing.**

The three adversarial review rounds fixed `"" == ""`, then `tickSpacing = 0`, then a
count-preserving rename, then an empty ref file, then `grep -q` over an empty log, then
`0x00…00` passing a hex-shape guard — each time generalising the *representation* just seen
instead of the predicate. This milestone hands that same defect class four brand-new
representations it has never worn before:

| New representation | The empty/zero/tautological form it takes |
|---|---|
| A content hash | `H("")`, or `H` of a tuple where an absent input defaulted to `0` before hashing |
| A version string | `""` from a failed `gams --version` parse, silently concatenated into the key |
| A subprocess exit code | `0` because GAMS *ran*, not because the model *solved* |
| A determinism check | `bytes == bytes` where both sides came from the same cached row, never re-solved |
| A DB-backed test | green because it **skipped** — no Postgres in the environment |

Each critical pitfall below names which of these it is.

---

## Critical Pitfalls

### Pitfall 1: `jsonb` structurally cannot return the bytes you gave it

**What goes wrong:**
The whole milestone rests on `VOLUME_PATH.md` §3's *"same inputs + same toolchain → same
bytes"*. If the solver's JSON is stored in a `jsonb` column, the bytes that come back are
**not** the bytes that went in, and the determinism check compares a normalised form against
a normalised form. It will pass for a genuinely nondeterministic solver (both sides get
normalised into agreement on whitespace/ordering) *and* fail spuriously (a cosmetic GAMS
formatting change flips bytes without changing a single number).

PostgreSQL documents this as designed behaviour, not a bug:

> "By contrast, `jsonb` does not preserve white space, does not preserve the order of object
> keys, and does not keep duplicate object keys. If duplicate keys are specified in the
> input, only the last value is kept."

> "in `jsonb`, numbers will be printed according to the behavior of the underlying `numeric`
> type. In practice this means that numbers entered with `E` notation will be printed
> without it"

The docs' own example is exactly this project's number shapes:

```
SELECT '{"reading": 1.230e-5}'::json, '{"reading": 1.230e-5}'::jsonb;
         json          |          jsonb
-----------------------+-------------------------
 {"reading": 1.230e-5} | {"reading": 0.00001230}
```

There is no escape hatch. jsonb's internal binary format is deliberately not exposed
(and is explicitly reserved for future change), and you cannot cast `jsonb` to `bytea`
directly — only via `text`, which hands you the *normalised* rendering, never the original.

`json` (not `jsonb`) *does* store "an exact copy of the input text" — but it is still not a
byte-safe container: it validates UTF-8 against the database encoding and it rejects
`U+0000`. jsonb rejects `U+0000` outright "because that cannot be represented in
PostgreSQL's `text` type."

**Why it happens:**
"JSONB schema for keyed model outputs" is in the milestone header, so `jsonb` looks like the
obvious column type for a JSON artifact. The category error is treating the solver output as
*a JSON document* when its contract makes it *a byte string that happens to parse as JSON*.

**How to avoid:**
Two columns, two different jobs, and say so in the schema comment:

- `output_bytes bytea NOT NULL` — the canonical artifact, exactly as the solver wrote it.
  This is what is hashed, what the determinism check compares, and what is published as the
  fixture. **Nothing ever reconstructs it by re-serialising.**
- `output_jsonb jsonb NOT NULL` — a *derived projection*, for querying/reporting only.
  Written in the same `INSERT` as the bytes, never read back into the artifact path.

Add `output_sha256 bytea NOT NULL` (the digest of `output_bytes`) and a `CHECK` /
insert-time assertion that it matches, so a corrupted row is loud rather than silent.

**Warning signs:**
- Any code path where the fixture or the determinism comparand is produced by `encode`,
  `jsonb_pretty`, `output_jsonb::text`, or a `SELECT ... ::text` on a JSON column.
- The determinism check passing on the very first attempt against a solver you have not yet
  proven deterministic — normalisation manufactures agreement.
- Schema review question that must have an answer: *if I `md5` the column on the way in and
  on the way out, do I get the same digest?* Make that a test, not a belief.

**Phase to address:**
**Phase 1 (Postgres foundation)** — column types and the round-trip test are foundation work.
Phase 2 consumes the guarantee; it must not be the place it is invented.

---

### Pitfall 2: the aeson `Value` round-trip is not the identity — MEASURED, on this project's actual field shapes

**What goes wrong:**
Even before Postgres touches it, `decode` → `encode` in Haskell rewrites the bytes. Measured
at this commit with the project's own build plan (`cabal exec -- runghc`, aeson resolved from
the existing `dist-newstyle`), feeding it `VOLUME_PATH.md` §3's literal output shape:

```
in : {"sqrtPriceX96": "792...336",
      "nEvents": 8, "deltaRealized": 0.49, "rPhiRealized": 0.00318353,
      "dQx": [-2613128317657530400, 2.8e19, 1.230e-5, 1.0, 100]}

out: {"dQx":[-2613128317657530400,28000000000000000000,1.23e-5,1.0,100],
      "deltaRealized":0.49,"nEvents":8,"rPhiRealized":3.18353e-3,
      "sqrtPriceX96":"792...336"}
```

Four independent mutations in one round-trip:

1. **Key order changed.** `Data.Aeson.KeyMap`'s docs: *"The order is not stable. Use
   `toAscList` for stable ordering."* The order you get depends on the KeyMap backing
   implementation and on aeson's build flags — so it can change under a dependency bump
   with no source change on your side.
2. **`2.8e19` → `28000000000000000000`** — exponent notation dropped.
3. **`1.230e-5` → `1.23e-5`** — trailing fractional zero dropped, exponent kept.
4. **`0.00318353` → `3.18353e-3`** — aeson *introduced* exponent notation into a plain
   decimal. This is `rPhiRealized`, a real field in the real output.

Now note that Postgres and aeson normalise **in opposite directions** on the same input:
aeson turns `0.00318353` into `3.18353e-3`; jsonb turns `1.230e-5` into `0.00001230`. GAMS
emits a third form. Three mutually incompatible canonical forms sit on the path between the
solver and the test. Any pipeline that passes the artifact through even one of them has lost
the byte guarantee.

**Also measured — the wei-truncation trap.** `dQx` entries are JSON *numbers* at the 1e18
scale, far past 2^53. Decoding them as `Double`:

```
[-2613128317657530400, 3044390494897843700]  decoded as [Double], rounded back:
[-2613128317657530368,  3044390494897843712]     -- 32 wei and 12 wei lost
re-encoded:  [-2.6131283176575304e18, 3.0443904948978437e18]
```

Decoded as `[Integer]` it is exact. The forge test that executes these swaps would execute
the **wrong amounts** — and `VOLUME_PATH.md` §3 already warns "never parse these fields as
doubles" for `sqrtPriceX96`/`liquidity`, but `dQx` is emitted as a bare number, so the
warning does not visibly cover the field that most needs it. The repo already has this rule
written down for its own artifacts (`Driver.Capture`'s "2^53 rule": every field that can
exceed 2^53 is a decimal string). The GAMS output does **not** follow it.

**Why it happens:**
`FromJSON`/`ToJSON` is the reflex for anything JSON-shaped in Haskell, and `Double` is the
reflex for a JSON number. Both are correct for *data* and wrong for a *byte artifact*.

**How to avoid:**
- Read the solver output with `Data.ByteString.readFile`, **never** `Prelude.readFile`
  (which is `String`, locale-decoded, and does newline translation).
- Hash and store that `ByteString`. Parsing is for *validation* and for the derived jsonb
  projection only, and the parse result is never re-encoded back onto the artifact path.
- Every numeric field that can exceed 2^53 is decoded as `Integer` / `Scientific`, never
  `Double`. Add a golden test that decodes a known `dQx` and asserts the exact integer —
  the truncation is 32 wei on 2.6e18, invisible to a tolerance-based assertion.
- Consider raising with the GAMS workstream whether `dQx`/`dQM` should become decimal
  strings, consistent with `sqrtPriceX96` and with this repo's own 2^53 rule. Until then,
  document the hazard where consumers will read it.

**Warning signs:**
`encode`, `toJSON`, or `Double` anywhere between the solver's file and the fixture.
A diff between stored and re-solved bytes that is *only* punctuation/exponents — that is
this pitfall, not solver nondeterminism.

**Phase to address:**
**Phase 1** for the read/store discipline (ByteString-only artifact path), **Phase 3 (GAMS
layer)** for the `Integer`-not-`Double` decode of `dQx`/`dQM` and its golden test.

---

### Pitfall 3: `ToField ByteString` in postgresql-simple sends **text**, not `bytea`

**What goes wrong:**
You declare the column `bytea`, you pass a `ByteString`, and postgresql-simple renders it as
a *quoted text literal*. The docs are explicit: the `ByteString` and `Text` instances use
`Escape` — *"Escape and enclose in quotes before substituting. Use for all text-like types"* —
while `EscapeByteA` is *"Escape binary data for use as a `bytea` literal … used by the
`Binary` newtype wrapper."*

Depending on the bytes, this either errors, or — worse — silently succeeds through client
encoding conversion and gives you back something that is not what you sent. Text-path bytes
also cannot carry `0x00`.

**Why it happens:**
The types line up (`ByteString` → binary column) so nothing complains at compile time. This
is the type system *appearing* to guard something it does not guard.

**How to avoid:**
Wrap every binary parameter in `Database.PostgreSQL.Simple.Binary`:
`Only (Binary bytes)` on the way in, `Binary bytes <- fromField` on the way out. Make it a
newtype in your own store module (`newtype Artifact = Artifact ByteString`) with `ToField`/
`FromField` instances that *only* go through `Binary`, so a bare `ByteString` cannot reach a
query by accident.

**Warning signs:**
Any query with a `bytea` column whose parameter is a naked `ByteString` or `Text`. A hash
column whose stored length is 64 (hex text) when you meant 32 (raw digest).

**Phase to address:**
**Phase 1 (Postgres foundation)**, with a round-trip test over an adversarial byte corpus:
must include `0x00`, `0xFF`, invalid UTF-8, a CRLF, and a trailing newline.

---

### Pitfall 4: the content key omits the model source — the cache serves pre-edit results forever

**What goes wrong:**
The key is `H(seven numeric inputs ‖ GAMS version ‖ CONOPT version)`. `volume_path.gms`
itself is not in it. Edit the model — change a bound, a formulation, the objective, the
`nEvents` default, a `put` format — and every existing key still hits. The store now answers
with results the current model would never produce, and the determinism check never fires
because you never re-solve.

This is the "keys that omit something semantically load-bearing" failure in its most
dangerous form, because the *symptom is silence*: the cache gets faster and stays wrong.

Two more omissions in the same family:

- **Solver options that are determinism-relevant.** §3's guarantee is conditioned on
  *"single-threaded CONOPT pinned"*. If thread count / CONOPT option-file contents are not
  in the key (or not asserted as an invariant), a multi-threaded run writes bytes under a key
  that promises single-threaded bytes.
- **GAMS put formatting.** GAMS put files default to a **255-column page width** (`.pw`,
  upper limit 32767); long lines wrap. An 8-element array of 20-digit signed integers is
  ~400 characters on one line. So the artifact's line structure is a function of a `.gms`
  file attribute. That is fine *if* the source hash is in the key, and a source of
  inexplicable byte diffs if it is not — and it gets worse when `nEvents` moves off 8
  (`VOLUME_PATH.md` §6 open ruling 1).

**Why it happens:**
The seven inputs are what `VOLUME_PATH.md` §2 calls "the shock", and the milestone header
quotes the key formula verbatim. The formula is a faithful transcription of the *stated*
inputs; it just isn't the *complete* set of things the output depends on.

**How to avoid:**
Extend the key to `H(seven inputs ‖ GAMS version ‖ CONOPT version ‖ model_source_digest ‖
solver_options_digest)`, where `model_source_digest` is a hash over the **sorted list of
(path, sha256)** for every `.gms` file the run reads — including includes — not just
`volume_path.gms`. Record the component digests in their own columns so a miss is
*explainable* ("model source changed") rather than mysterious.

Add a `key_scheme SMALLINT NOT NULL` column and make the unique constraint
`(model, key_scheme, key)`. When the key formula changes, bump the scheme: old rows become
**orphaned** (never matched) instead of **misinterpreted**. This is the migration-safe form
of a key change and it costs one column now versus a full-table rebuild later.

**Warning signs:**
- A cache hit immediately after editing a `.gms` file. That should be impossible.
- Hit rate near 100% during active model development.
- A determinism check that has never once reported a mismatch across a toolchain or model
  change — it isn't running.

**Phase to address:**
**Phase 2 (keyed store)** owns the key formula and `key_scheme`. **Phase 3 (GAMS layer)**
owns computing `model_source_digest` from the actual file set the invocation reads.

---

### Pitfall 5: an absent input defaults to `0`/`""` before hashing — the zero-word trap, one type over

**What goes wrong:**
`nEvents` has an **in-file default of 8**. `VOLUME_PATH.md` §2 says the in-file defaults are
"a self-test fixture only", which means the bridge is expected to pass everything — but
nothing enforces it. If the bridge omits `--nEvents`, GAMS uses 8 and the key builder hashes
whatever the Haskell side had: `Nothing`, `0`, or `""`. Two runs with genuinely different
`nEvents` both hash to "the absent key" and **collide**. The cache then returns a `dQx` array
of the wrong length for the requested `N`, and the forge test executes the wrong number of
swaps.

This is exactly pitfall #2 and #6 from the review rounds (`tickSpacing = 0`; `0x00…00`
passing a hex-shape guard) wearing a new costume: a *shape-valid* key that carries no
information about the field it claims to cover.

The same trap sits on every optional-looking field: a `phiMpips` that fails to read from
`MevTaxModelOneFees` and falls back to `0`; a `volTgtWad` that arrives unset and becomes `0`.
A `0` fee and a `0` volume are both *representable* and both would be hashed without
complaint.

**Why it happens:**
Haskell makes `Maybe` cheap and `fromMaybe 0` idiomatic. The default lives in the `.gms`
file, on the far side of a process boundary, so the Haskell type has no reason to know that
"absent" and "8" are the same thing downstream.

**How to avoid:**
1. **The key type has no `Maybe` fields and no defaultable fields.** `data Shock = Shock
   { shockSqrtPriceX96 :: !Integer, ... }` — seven strict, total fields. Defaults are
   resolved by an explicit `resolveShock :: PartialShock -> Either ShockError Shock` that
   *fails* rather than substitutes, or substitutes *loudly* and records that it did.
2. **The key is built from the argument vector actually passed to GAMS.** One function
   produces `[Text]` — the exact `--key=value` list — and both the subprocess call and the
   key derivation consume that same list. There is then no path where GAMS sees a value the
   key did not.
   *Careful:* this must not become pitfall #7 from the review rounds (the tautology). It is
   safe here because the comparand is the *subprocess's* input, not the store's own output —
   but the paired assertion ("the echoed fields in the output equal the fields in the key")
   must read the echoed values back out of the **solver's JSON**, not out of the request
   record. `VOLUME_PATH.md` §3 echoes `sqrtPriceX96`, `liquidity`, `txlVolumeRate`,
   `phiXpips`, `phiMpips`, `nEvents` precisely so this cross-check is possible. Use it.
3. **Range guards that reject the informationless value**, per field, with the
   representation explicitly enumerated: `nEvents >= 1`, `liquidityRaw > 0`,
   `volTgtWad > 0`, `sqrtPriceX96 > 0`, `0 < txlVolumeRate < 1000000` (§4 requires < 100%),
   `phiXpips > 0`, `phiMpips > 0`, `phiXpips /= phiMpips` (§1.2: equal fees are infeasible
   for *every* target — catch it in Haskell, not by reading a GAMS abort).
4. **A negative test per field**: a case that omits it and asserts the pipeline *refuses*.
   Not "handles gracefully" — refuses, with the field named.

**Warning signs:**
`fromMaybe`, `def`, `mempty`, or a record with `Maybe` on anything that reaches the hash.
A key that is computable from a partially-populated request. Any log line reading
`nEvents: 0`.

**Phase to address:**
**Phase 2 (keyed store)** for the type and the negative tests. **Phase 4 (Anvil reads)** for
the pool-state fields, which are the ones that can plausibly read back as zero from a chain
call that hit the wrong block or a not-yet-initialised pool.

---

### Pitfall 6: unframed concatenation — `H(a ‖ b ‖ c)` makes two *different* shocks collide

**What goes wrong:**
Seven variable-length decimal strings concatenated give `"1" ‖ "23"` == `"12" ‖ "3"`. Two
genuinely different shocks produce one key. The store returns the wrong path, the forge test
executes swaps that do not close, and the failure surfaces three layers away from its cause.

The mirror failure is just as bad: two *logically identical* shocks hash **differently**
because one side rendered `volTgtWad` as `28e18` (the literal form `VOLUME_PATH.md` §2's own
example command line uses) and the other as `28000000000000000000`. Cache miss, redundant
30-second solve, and — critically — a determinism check that can never compare them.

**Why it happens:**
`hash (T.concat [a,b,c])` reads correctly and is one line. Framing looks like ceremony.

**How to avoid:**
Fix a canonical encoding *as a written spec in the phase plan*, then implement it once:

- **Every numeric field is a bare canonical decimal integer** — no exponent, no sign for
  positives, no leading zeros, no thousands separators, no unit suffix. `28e18` is
  normalised to `28000000000000000000` **before** hashing and before being passed to GAMS.
  Decide explicitly whether `volTgtWad` is an integer or a float on the GAMS side; if float,
  the canonical form is whatever GAMS will actually parse to the same double, and that is a
  question to settle in Phase 3, not to assume.
- **Length-prefixed or unambiguously delimited.** Cheapest correct form:
  `H(concat [ field_name <> "=" <> value <> "\n" | in a FIXED order ])`, with a compile-time
  check that the field list is exhaustive (a total `keyFields :: Shock -> [(Text, Text)]`
  over a record with no wildcard pattern, so adding a field breaks the build). Field *names*
  in the preimage also mean a future reordering cannot silently produce an old key.
- **Locale is not permitted to participate.** Never use `printf`/`show` on a `Double` for a
  key component; a `LC_NUMERIC` that renders `0,49` would change every key on one machine.
  Render from `Integer`/`Scientific` with an explicit formatter.
- **Store the preimage.** A `key_preimage text NOT NULL` column costs nothing at this scale
  and turns every future "why did these collide / why did these miss" into a `diff`.

**Warning signs:**
A key function that takes `[Text]` instead of the `Shock` record. Any `show`/`printf` on a
floating value in the key path. Two rows with the same key and different `key_preimage` —
which is why the column exists; add the assertion.

**Phase to address:**
**Phase 2 (keyed store)**.

---

### Pitfall 7: toolchain version detection that *succeeds emptily* — the `"" == ""` defect, verbatim

**What goes wrong:**
`gams --version` is parsed with a regex; the regex misses (different GAMS build banner,
localised output, banner on stderr rather than stdout, a wrapper script on `PATH`); the
parser returns `""`; `""` is concatenated into the key. Every toolchain now hashes to the
same key component. GAMS 54.1 and GAMS 55 produce the same key, the 55 run hits 54.1's cached
bytes, and `VOLUME_PATH.md` §3's explicit warning — *"A different CONOPT version may select a
different member of the underdetermined path family — still passing every gate"* — becomes
a wrong answer that passes every gate.

This is the review rounds' defect #1 and #4 with a version string in place of a ref file. It
is the single most likely place for the class to recur, because a version string's failure
mode is *literally* the empty string.

CONOPT is harder than GAMS: it is a solver inside the GAMS distribution, so `gams --version`
does **not** tell you the CONOPT version. Reading it out of the listing/log file means
parsing text — the thing §4 tells you not to gate on.

**Why it happens:**
Version detection is treated as plumbing, written once, never given a negative test. And a
"best effort, fall back to unknown" default *feels* defensive.

**How to avoid:**
- **The parse is total or the run aborts.** `parseGamsVersion :: ByteString -> Either
  VersionError GamsVersion`, and the constructor is not reachable with an empty component.
  A `newtype GamsVersion = GamsVersion Text` with a smart constructor that rejects empty,
  whitespace-only, and anything not matching a version *shape*.
- **A positive assertion, not the absence of an error.** After detection, assert the parsed
  version is non-empty **and matches an expected pin** (`VOLUME_PATH.md` names GAMS 54.1 /
  CONOPT 4.39). A mismatch is not a crash — it is a recorded, keyed fact — but an
  *unparseable* result is a hard abort.
- **Resolve the binary, not the name.** Record the absolute resolved path *and* a sha256 of
  the `gams` executable itself alongside the version string. That is the one component that
  cannot lie about a wrapper script or a `PATH` shadow, and it is three lines.
- **A test that feeds the parser garbage** (`""`, `"\n"`, a help message, a localised banner)
  and asserts every one is rejected. This is the negative test whose absence caused six
  rounds of findings.
- For CONOPT: if the version is only obtainable from log text, that is acceptable *for the
  key* (the key is not a gate) but it must still be total, non-empty, and shape-checked.
  Record which method produced it.

**Warning signs:**
`fromMaybe "unknown"`, `<|> pure ""`, `catch (\_ -> return "")` in the version path. A key
whose version components are equal across two machines you know have different installs —
add that as an explicit two-machine check if the CI executor and the dev box differ.

**Phase to address:**
**Phase 3 (GAMS layer)**. Version detection must be complete and negatively tested *before*
Phase 2's key formula consumes it, so sequence Phase 3's detection ahead of the first
production write.

---

### Pitfall 8: exit code `0` means "GAMS ran", not "the model solved"

**What goes wrong:**
`VOLUME_PATH.md` §4 says *"Exit code is non-zero on every abort — gate on it, never on log
text."* That is correct **and it is a property of `volume_path.gms`, not of GAMS.** GAMS's
own documentation is blunt:

> "return codes do not provide information about a model inside the GAMS job: the model may
> have been infeasible or may have failed in another way while the return code says all is
> fine."

(Codes: `0` normal, `2` compilation error, `3` execution error; an `abort` statement yields
`3`.) So the exit-code gate is sound only for as long as the `.gms` file's `abort` coverage
is exhaustive — and the model is under active development in another worktree. The moment
someone adds a solve path without an `abort $` guard, `0` starts meaning "nothing checked".

Bazel has hit precisely this in production: *"if an action exits 0 but the output is
malformed (such as when a badly performing instance runs out of disk space), the cache will
be poisoned."* Exit code `0` is the informationless comparand of the subprocess world.

Two more specific instances:
- **A stale output file.** GAMS exits `0` without rewriting `volume_path.json` (an early
  `$exit`, a put-file error, a write to the wrong directory). The bridge reads *the previous
  run's file* and stores it under *this run's key*. Cache permanently poisoned, silently.
- **Non-zero for benign reasons.** GAMS's higher codes cover licensing/file/system errors.
  Treating "non-zero" as "the model says infeasible" turns an expired licence into a
  recorded infeasibility verdict.

**Why it happens:**
`§4 says gate on exit code` reads as a complete specification. It is a *necessary* condition
stated as if it were sufficient.

**How to avoid:**
Exit code `0` is the **first** of several conjuncts, none of which may be dropped:

1. `exitCode == ExitSuccess` — and distinguish `2`/`3` (model-level: a named abort, expected,
   record the reason) from everything else (environmental: licence, disk, missing binary —
   *not* an infeasibility verdict, must not be cached as one).
2. **The output file was written by *this* run.** Run in a fresh per-invocation temp
   directory created by `withSystemTempDirectory`; the output path cannot pre-exist. Belt
   and braces: assert `mtime >= process start time`. This alone kills the stale-file
   poisoning.
3. **It parses**, and the parse is strict (unknown fields, missing fields → failure).
4. **Positive structural post-conditions**: `length dQx == nEvents`, `length dQM == nEvents`,
   both arrays non-empty, `deltaRealized` and `rPhiRealized` present and finite, every
   echoed input field **equal to the corresponding key field** (read from the JSON, per
   Pitfall 5).
5. Only then does anything get written to the store — in one transaction.

Independently: put a **test on the gate itself**. Feed the layer a deliberately infeasible
shock (§1.2's equal-fees case is free: `phiXpips == phiMpips` is structurally infeasible for
every target) and assert the layer *refuses* with a non-success status. A gate that has never
been observed to reject is the `grep -q`-over-an-empty-log finding again.

**Warning signs:**
`when (code /= ExitSuccess) $ ...` with no `else` branch doing verification. Any read of
`volume_path.json` from a path that persists between runs. Solver stderr/stdout being
searched for words like `infeasible` or `optimal`.

**Phase to address:**
**Phase 3 (GAMS layer)** for the conjunct list and the temp-dir isolation. **Phase 2** for
the rule that only a fully-verified success may write an output row.

---

### Pitfall 9: cache elision means the determinism check *never runs* — the self-cancelling guarantee

**What goes wrong:**
The milestone says two things that are in direct tension: *"cache hit elides the solve"* and
*"re-solve of an existing key must reproduce bytes"*. If every hit elides, you never re-solve,
so the check that is the milestone's headline falsifiable claim executes zero times in
production. Worse, it is easy to build a check that *appears* to run: comparing the cached
bytes to themselves, or to a value derived from the same row. That is defect #7 from the
review rounds — a tautology that passes for every input.

**Why it happens:**
The two features are specified in the same sentence and implemented as one code path. The
check gets bolted onto the hit branch, where there is nothing new to compare against.

**How to avoid:**
Take the reconciliation the reproducible-build ecosystem already converged on: **verification
is a separate, explicit mode, off the hot path.** Nix does exactly this —
`nix-build --check` / `nix build --rebuild` rebuild an already-cached derivation and reject
on any bit-level difference, with `--keep-failed` plus a diff-hook preserving the divergent
output for inspection; `--repeat N` / `build-repeat` runs a build N+1 times and rejects if
any round differs. None of this happens on a normal cache hit.

Concretely, three modes, distinct in the code and in the CLI:

| Mode | Behaviour | When it runs |
|---|---|---|
| `solve` (default) | hit → return cached bytes, no subprocess | the resident loop, every event |
| `solve --check` | hit → **re-solve anyway**, compare bytes, record the verdict either way | on demand; nightly; in CI on a fixed shock corpus |
| `solve --repeat N` | miss or hit → solve N+1 times, all rounds must agree, then store | first write of any new key, if you want determinism proven at insert time |

And make the verdict a **first-class row**, not a log line or an exception:
`determinism_check(id, key, checked_at, cached_sha256, resolved_sha256, agreed bool,
first_diff_offset int, toolchain jsonb)`. A disagreement must not abort the loop — it must be
*recorded*, because a disagreement is the most valuable observation this system can make and
throwing it as an exception in a resident process loses it.

The check must be **structurally incapable of being a tautology**: the function signature is
`checkDeterminism :: CachedBytes -> FreshlySolvedBytes -> Verdict` with two distinct newtypes,
`FreshlySolvedBytes` constructible *only* by the subprocess layer, and no `Eq` between them
except through this function. Then "compare the row to itself" does not typecheck.

Add one more guard against the empty-comparand class: assert both sides are non-empty and
longer than a floor (a valid `volume_path.json` with 8 events is > 200 bytes) *before*
comparing. `"" == ""` must be impossible to reach.

**Warning signs:**
- `determinism_check` table with zero rows after a week. Alert on that; it is the
  empty-log-`grep -q` finding pre-empted.
- The check living inside the same function as the cache lookup.
- A check whose two comparands can be traced to the same `SELECT`.

**Phase to address:**
**Phase 2 (keyed store)** — this *is* the keyed store's core semantics, not a later addition.
The three modes and the `determinism_check` table are Phase 2 deliverables.

---

### Pitfall 10: poisoning the store with a partial run, and the `reset`/`pin` operations that make it worse

**What goes wrong:**
A run that dies mid-way (CONOPT killed by a timeout, disk full, OOM, the loop's process
receiving SIGTERM) leaves a truncated `volume_path.json`. The store's writer, seeing a file
that exists and parses far enough, inserts it. That key is now permanently wrong and, because
it is a hit, is never re-solved.

The `pin`/`retain` and `reset` operations amplify this:
- **A poisoned row that gets pinned is immortal.** Pin means "reset does not delete this",
  so a bad row survives precisely the operation designed to clear bad rows.
- **`reset` with no scope** wipes the append-only run log too, destroying the chronology the
  content key cannot reconstruct — the one thing the run log exists for.
- **`reset` racing a resident loop**: the loop re-populates from a half-cleared store, or
  hits a foreign key that vanished mid-transaction.

**Why it happens:**
The happy path is written first; "insert what we got" is the natural shape. Pin/reset are
specified as flags, and flags are cheap to add and hard to scope.

**How to avoid:**
- **Write outputs only after Pitfall 8's full conjunct list passes**, in one transaction with
  the run-log row. A partial run produces a run-log row with `status = 'aborted'` and
  `output_id = NULL` — never an output row. Model this in the schema: outputs and run-log
  entries are separate tables, and `output` has no "maybe complete" state.
- **Borrow the repo's own precedent.** `Driver.Capture` already solved exactly this problem
  for the driver artifact: `dr_complete` exists so *"a check can refuse a partial run
  outright"*, and `or_complete` is deliberately a *second* flag because *"two requirements,
  two flags"*. Same discipline here: the store's completeness flag is not the run log's.
- **`reset` takes a mandatory explicit scope** and refuses to run bare. `reset --model=X
  --unpinned` / `reset --model=X --key=<k>`; never `reset` alone. It must **never** touch the
  run log (append-only means append-only) and must **never** delete pinned rows silently —
  it reports the count it skipped.
- **Pin is a claim that must be re-verifiable.** A pinned row is exactly the row that most
  deserves `--check`. Make the verification mode prefer pinned keys.
- Take a Postgres advisory lock on `(model)` for the duration of a `reset` so a resident loop
  cannot interleave.

**Warning signs:**
An `INSERT` reachable from a code path that has not evaluated the exit code. `reset` with a
zero-argument form. A pinned row whose `determinism_check` history is empty.

**Phase to address:**
**Phase 2 (keyed store)** for the write-only-on-success rule, the two-table split, and the
scoped `reset`. **Phase 3** supplies the success predicate.

---

### Pitfall 11: subprocess pipe deadlock, missing timeout, and a leaked environment

**What goes wrong:**
Three separate failures, all in the GAMS invocation:

1. **Deadlock.** `createProcess` with `CreatePipe` on stdout *and* stderr, then reading only
   stdout, then `waitForProcess`: GAMS fills the ~64 KB stderr pipe buffer, blocks on write,
   never exits; you block on `waitForProcess`, never read. The resident loop hangs forever
   with no error. GAMS log output is verbose and easily exceeds 64 KB. The `System.Process`
   docs do **not** warn about this — verified: there is no deadlock caution in the
   `createProcess`/`waitForProcess` documentation, so the hazard is entirely on the caller.
2. **No timeout.** CONOPT on a badly-conditioned shock can run unboundedly. A resident loop
   with no timeout stops processing events and looks *healthy* (the process is alive).
3. **Environment leakage.** GAMS reads configuration from the environment and from files in
   the working directory (`gamsconfig.yaml`, parameter files, licence location). A stray
   `GAMS*` variable, a different licence, or an option file inherited from the developer's
   shell can change thread count — and §3's determinism guarantee is conditioned on
   single-threaded CONOPT. `LC_NUMERIC` can change decimal rendering in emitted output.
   The result: byte differences that look like solver nondeterminism and are actually
   environment drift between the dev box and the self-hosted CI executor.

**Why it happens:**
`readProcess` is the obvious call — but it **throws an `IOError` on any non-zero exit**
(confirmed in the docs), which converts §4's *named aborts* into an opaque exception and
discards the exit code you were told to gate on. So people reach for `createProcess`, and
then hand-roll the pipe handling.

**How to avoid:**
- Use `readProcessWithExitCode` (returns the code rather than throwing) — or, if you need
  streaming, use `withCreateProcess` and read stdout and stderr **on separate threads**
  (`concurrently` / `forkIO` + `MVar`), draining both to completion *before* `waitForProcess`.
  Never `waitForProcess` with an undrained pipe.
- Wrap every invocation in `System.Timeout.timeout` with a generous but finite budget, and on
  expiry `terminateProcess` **then** `waitForProcess` to reap. A timed-out run is an
  `aborted` run-log row, never an output row.
- **Explicit environment.** Set `env = Just <whitelist>` on the `CreateProcess` record — do
  not inherit. Whitelist only what GAMS genuinely needs (`PATH`, `HOME`/licence location,
  and an explicit `LC_ALL=C`). Record the whitelist in the run log so an environment change
  is visible as a diff, and consider hashing it into `solver_options_digest` (Pitfall 4).
- **Fresh working directory per invocation** (`withSystemTempDirectory`) — this simultaneously
  kills the stale-output-file poisoning of Pitfall 8 and any `gamsconfig.yaml` picked up from
  the repo root.
- Capture stdout/stderr into the run log regardless of outcome — for *diagnosis*, explicitly
  labelled as non-authoritative, so nobody is tempted to gate on it. A comment saying so.

**Warning signs:**
`readProcess` anywhere in the GAMS path. `createProcess` without a second reader thread.
A `CreateProcess` record with no explicit `env`. A loop that stops advancing but whose
process is alive — that is #1 or #2.

**Phase to address:**
**Phase 3 (GAMS layer)**.

---

### Pitfall 12: reading pool state at a different block than the event

**What goes wrong:**
The `next` event (`0xd3827b0b`) arrives from `eth_getLogs` at block `N`. The bridge then
calls `eth_call` for `slot0`/liquidity/fee **without a block tag**, which defaults to
`latest`. On a live Anvil with auto-mining or a driver running swaps, `latest` is already
`N+3`. The shock is then a chimera: a `txlVolumeRate` from block `N` married to a
`sqrtPriceX96` from block `N+3`. It hashes to a key that describes a state that never
existed, the solver produces a path for it, and the forge test's closure assertion fails for
reasons nothing in the pipeline can explain.

PROJECT.md already states the rule (*"every read pinned to one block"*). The pitfall is in
how it is *enforced*: pinning to a block **number** is not enough if the chain can be reset
or a snapshot reverted, which Anvil does routinely (`anvil_reset`, `evm_revert`). And a fresh
Anvil returns `0` for an uninitialised pool's `sqrtPriceX96` — feeding Pitfall 5's zero trap
directly.

**Why it happens:**
`eth_call`'s block parameter is optional and every library defaults it to `latest`. The
default is invisible at the call site.

**How to avoid:**
- **Pin to `blockHash`, not `blockNumber`.** `eth_getLogs` accepts a `blockHash` filter which
  is *"equivalent to setting fromBlock and toBlock to the block number referenced in the
  blockHash"*, and `eth_call`'s block parameter accepts a block hash on modern nodes. If your
  client cannot pass a hash to `eth_call`, pass the number **and** independently re-fetch the
  block header and assert its hash equals the event's `blockHash`, before and after the reads.
- **One `BlockRef` value threaded through every read.** Make the read functions take a
  mandatory `BlockRef` argument; there is no arity at which "the caller forgot" typechecks.
  No function in the read layer may call `latest`.
- **Assert the reads are non-degenerate**: `sqrtPriceX96 > 0`, `liquidity > 0`. A zero here
  means "wrong block" or "pool not initialised", never a valid shock. Name the field in the
  error.
- Record `(blockNumber, blockHash)` in the run log — the milestone already specifies
  `(timestamp, key, next-tx-hash, block)`; make `block` carry the **hash** too, so a later
  reader can tell whether the chain it references still exists.

**Warning signs:**
Any RPC call in the read layer without an explicit block argument. A shock whose
`sqrtPriceX96` is `0` or exactly `2**96` when you did not deploy the fixture pool. Run-log
rows with a `block` but no `blockHash`.

**Phase to address:**
**Phase 4 (Anvil reads)**. Note this phase is BLOCKED on the plank worktree emitting the
event — build the decoder against synthetic logs (the repo already does this: the test suite
"builds synthetic logs" for the Phase 21 event re-pin) so the blocker does not also block the
block-pinning discipline.

---

### Pitfall 13: the resident loop — re-delivery, reorg, restart, and unbounded growth

**What goes wrong:**
Four distinct failures that all present as "the fixture is wrong and nobody knows when it
became wrong":

1. **Re-delivered events.** Polling with `fromBlock = lastSeen` (inclusive) re-reads the
   boundary block every tick. The same `next` event is processed twice, appending two run-log
   rows for one on-chain fact and corrupting the chronology the log exists to provide.
2. **Reorg / chain replacement.** Anvil does not reorg naturally, but `anvil_reset`,
   `evm_revert`, and a restarted Anvil all replace history. Logs carry a `removed` field that
   is *"true when the log was removed due to a chain reorganization"* — a loop that ignores it
   keeps acting on events that no longer exist. Worse, the run log's `next-tx-hash` now points
   at nothing, and a later audit cannot distinguish "we made this up" from "the chain moved".
3. **Crash-restart duplicate work.** No persisted cursor → the loop restarts from `latest`
   and silently skips everything that happened while it was down, or restarts from `0` and
   re-solves everything.
4. **Unbounded growth.** An append-only run log plus one output row per distinct shock, on a
   loop that runs continuously against a driver generating events. At this project's scale
   this is a slow leak rather than an outage, but the interaction with `reset`/`pin` (Pitfall
   10) is where it bites: nobody wants to run `reset` because it might delete something
   load-bearing, so nothing is ever pruned.

**Why it happens:**
The loop is the last phase, written when the interesting problems feel solved. Every one of
these is a "we'll add it if it becomes a problem" item, and each becomes a problem silently.

**How to avoid:**
- **Idempotency key = `(txHash, logIndex)`**, `UNIQUE` in the run log, with
  `ON CONFLICT DO NOTHING`. Do **not** dedupe on the content key: two genuinely distinct
  events can legitimately produce the same shock, and collapsing them destroys the chronology
  that is the run log's entire justification (the milestone says so explicitly — chronology
  is what the content key *cannot* give).
- **Honour `removed`.** A removed log marks its run-log row `superseded`; it does not delete
  it. Store `blockHash` on every row; on startup, verify the cursor's `blockHash` still
  resolves — if it does not, the chain was replaced: log it loudly, rewind the cursor, and do
  not treat it as corruption.
- **Persisted cursor, committed in the same transaction as the work it covers.** Advance it
  only after the run-log row is durable. Two instances of the loop must not both hold it —
  take a Postgres advisory lock on the loop identity at startup and *exit* if it is held,
  rather than running a second loop nobody knows about.
- **Retention policy decided in the plan, not deferred**: run log is append-only forever
  (it is small and it is the audit trail); *outputs* are prunable by age with pinned rows
  exempt. Write the policy down even if the pruning job is not built.
- **Never hold a database transaction across the GAMS subprocess.** A 30-second solve inside
  a transaction is 30 seconds of `idle in transaction`, blocking vacuum and holding locks.
  Read the cache, `COMMIT`, solve, then open a new transaction to write.

**Warning signs:**
Two run-log rows with the same `(txHash, logIndex)`. A cursor stored in memory or in a file
rather than in the database. `pg_stat_activity` showing `idle in transaction` for tens of
seconds. Run-log rows whose `blockHash` no longer resolves.

**Phase to address:**
**Phase 6 (resident loop)**, with the `(txHash, logIndex)` unique constraint and the cursor
table landing in **Phase 1**'s schema so Phase 6 has somewhere to put them.

---

### Pitfall 14: publishing the fixture — a torn read into another workstream's tree

**What goes wrong:**
The loop writes `test/models/mev_tax_model_one/fixtures/volume_path.json` continuously while
a `forge test` reads it. Three failures:

1. **Torn read.** A non-atomic write (open-truncate-write) means the consumer can read a
   half-written file — or an empty one, if it reads between truncate and write. An empty
   fixture that a lenient parser accepts is the empty-ref-file finding all over again.
2. **Moving target.** PROJECT.md's stated intent is that publishing "keeps the forge test's
   input from being a moving target" — but a loop that republishes on every event makes it
   *maximally* a moving target unless the published artifact is a **committed** snapshot. A
   CI run and a local loop pointed at the same working tree will disagree about what the
   test's input was.
3. **Territory.** The milestone is explicit: `test/` belongs to another track. One file
   written into someone else's tree by a background process, with no marker saying which run
   produced it, is an unattributable failure waiting to happen.

**Why it happens:**
`encodeFile`/`writeFile` is one line and looks atomic. It is not.

**How to avoid:**
- **Reuse the repo's existing solution.** `Driver.Capture` already exports
  `write_json_atomically` for exactly this (write to a temp path, `renameFile` — atomic within
  a filesystem). Do not write a second one; import it or lift it into a shared module.
- **Two paths, one promotion.** The loop writes to a staging location it owns
  (`offchain/...`). Copying into `test/` is an explicit, deliberate act — a `make
  publish-fixture` target or a step in the loop that runs *only* when told to — and the
  result is **committed**. That is what makes the test's input stable; the loop alone cannot.
- **The fixture carries its own provenance**: the content key, `blockNumber` + `blockHash`,
  and the toolchain versions, so a failing forge test names the run that produced its input.
  Keep *volatile* provenance (wall-clock timestamp, hostname) out of the committed file or in
  a sidecar — otherwise every loop iteration produces a git diff and the fixture churns.
- **A shape floor on the published file**, asserted at write time: parses, `length dQx ==
  nEvents`, size above a floor. Refuse to publish otherwise. An empty or truncated fixture
  must never reach `test/`.
- Add a `.gitattributes` entry marking the fixture `-text` (binary) so no CRLF/EOL
  normalisation can rewrite the bytes in transit. The repo currently has **no**
  `.gitattributes` at all — verified — so nothing prevents this today.

**Warning signs:**
`writeFile`/`encodeFile` targeting a path under `test/`. A fixture that changes on every loop
tick. A forge failure that cannot be traced to a specific solve.

**Phase to address:**
**Phase 6 (resident loop)** for the publication mechanism; coordinate the `test/` path with
the owning track *before* Phase 6, not during it.

---

### Pitfall 15: migrations from a long-running process, and concurrent runners on a shared executor

**What goes wrong:**
- **Migrate-on-startup + N instances = a race.** Two resident loops (or a loop and a CLI
  invocation) start together, both see schema version 2, both run migration 3. Best case a
  unique-violation crash; worst case a half-applied DDL.
- **Irreversible key-scheme changes.** Altering the key column or the key formula after rows
  exist leaves old rows with old-scheme keys. They do not error — they silently miss (waste)
  or, if the schemes' outputs overlap, silently **hit the wrong row**.
- **This repo's CI makes it worse.** The develop gate runs on a `[self-hosted, cfmm-build]`
  executor; the workflow-level `concurrency` group is keyed on `github.ref` and, per the
  workflow's own comments, does **not** exclude runs on *different* refs — which is why the
  rig already needs a host-wide advisory `flock` for port 8545. A Postgres instance is a
  second shared singleton on that same host with the same problem, and the existing flock is
  keyed on the anvil port, not the database. Two CI runs on different branches will share one
  database, and a `reset` in one will delete the other's rows mid-run.
- **`git clean -ffdx`.** The workflow comments record that `actions/checkout`'s default
  `clean: true` runs `git clean -ffdx` and *"takes ignored files with it"* — so nothing under
  the workspace survives between runs. Any DB state, socket, or data directory placed there
  is gone; migrations must run correctly from a completely empty database every single time.

**Why it happens:**
Migrate-on-startup is the default in almost every framework and is genuinely convenient for a
single-instance service. This is not a single-instance service.

**How to avoid:**
- **Migrations are an explicit one-shot command**, never a side effect of the loop starting.
  The loop *checks* the schema version and **refuses to start** if it does not match the
  version it was compiled against. (A check that refuses is information; a check that
  auto-migrates is not.)
- Wrap the migration runner in `pg_advisory_lock(<constant>)` for its whole duration —
  this is the standard, correct primitive and it costs one line.
- **`key_scheme` in the unique constraint** (Pitfall 4). Key-formula changes then become
  additive and non-destructive: old rows orphan, new rows accumulate, nothing is
  reinterpreted. Never `UPDATE` a key in place.
- **Database-per-run in CI.** Give each CI job its own database name (or its own schema),
  derived from the run id, created and dropped in-job. That removes the shared-singleton
  problem entirely and is cheaper than extending the flock. If a shared instance is
  unavoidable, extend the existing host-wide flock to cover it and say so in the same comment
  style the workflow already uses.
- Migrations must be **idempotent from empty** and tested that way (`git clean -ffdx`
  guarantees "from empty" is the normal case in CI, so this is the *primary* path, not an
  edge case).

**Warning signs:**
A migration call in the loop's `main`. Any CI job that assumes a database persists between
runs. `key_scheme` absent from the unique index.

**Phase to address:**
**Phase 1 (Postgres foundation)** — migration mechanism, advisory lock, `key_scheme` column,
and the CI database strategy all belong here. Phase 6 only consumes the version check.

---

### Pitfall 16: DB-dependent tests that skip when Postgres is absent — the `grep -q` finding, reincarnated

**What goes wrong:**
Adding a database dependency to an existing test suite creates the strongest possible
incentive for self-skipping tests: "if `PGHOST` is unset, skip." The suite then reports green
on a machine with no Postgres — having verified nothing about the store. That is finding #5
from the review rounds exactly: a gate that certifies clean having read nothing.

This repo has already been burned by the adjacent version of it: the `haskell` gate job has
**never executed** (PR #9 was merged `--admin`), and the workflow's own comments record that
7 of its 85 checks hard-require a manifest that a clean checkout does not contain. The
milestone is adding a *second* external prerequisite (Postgres) to a job that has not yet
survived its first prerequisite.

There is a third instance waiting: the repo already ships a self-skipping scaffold
(`mev_tax_model_one #24`). Two self-skipping mechanisms in one repo is one too many.

**Why it happens:**
Skip-when-absent is the polite thing to do for contributors, and the cost is invisible.

**How to avoid:**
- **Skipping is permitted locally and forbidden in CI**, and the difference is enforced by a
  variable CI sets (`CFMM_REQUIRE_DB=1`): when set, an absent database is a **failure**, not
  a skip, and the failure message says which prerequisite was missing.
- **A count floor on executed DB checks**, asserted at the end of the run: "at least N store
  checks executed". This is the direct counter to finding #3 (the count-preserving rename)
  and to skip-inflation — and the repo's harness already reports `78/85 checks passed`, so
  the count is available.
- **A sentinel that must fail.** Ship one check that is *expected to be red* against a
  deliberately-wrong store (e.g. a key built from a shock with `nEvents` omitted must not
  match the fully-specified key). If it ever goes green, the guard has stopped reading.
  The repo has a precedent for this — the sentinel-falsification harness at `142b5cd`.
- Get Postgres onto the self-hosted executor *and prove the job runs* before Phase 2 lands
  anything the job is supposed to guard. A gate added ahead of its first real execution is a
  gate with no evidence behind it.

**Warning signs:**
A green suite on a machine with no `psql`. A skip count that grows and a pass count that does
not. Any `pending` status on the `haskell` check for a PR that touched `offchain/`.

**Phase to address:**
**Phase 1 (Postgres foundation)** — the test-environment contract is foundation work and
must exist before Phase 2 writes the first assertion that depends on it.

---

### Pitfall 17: the fee splitter's closed form silently becomes an approximation

**What goes wrong:**
`(φ_X, φ_M)` are derived from the pool fee `f` by `(1−φ_X)(1−φ_M) = 1−f` (level) plus
`δ* ≥ 2ρ/(1+ρ²)`, `ρ = φ_M/φ_X` (skew), with the boundary `ρ* = 3.8198` at `δ* = 0.49`. Three
ways this poisons the store:

1. **Rounding drift is a cache invalidator.** `φ_X`/`φ_M` are *pips* (integers). The closed
   form produces reals; rounding them to pips is a lossy step. If the rounding rule changes —
   or differs between the Haskell splitter and any other implementation — the same `f`
   produces different pips, different keys, and a cache that quietly stops hitting. If the
   *key* stores `f` instead of the derived pips, the opposite happens: a splitter change
   reuses results computed under the old split. **Both** must be in the key: the derived pips
   (because they are what GAMS receives) *and* a `splitter_version`.
2. **The feasibility proof drifts from the model.** PROJECT.md's stated value is that
   infeasibility becomes "a refusal we explain, not an exit code we interpret". That holds
   only while the Haskell feasibility predicate agrees with `volume_path.gms`'s §1.3 quadratic
   `(φ̄²+Δφ²)δ² − (φ_X+φ_M)·φ̄·δ + φ_X·φ_M ≤ 0`. Two implementations of one inequality drift.
   When they do, either you refuse feasible shocks (silent under-coverage) or you hand GAMS
   an infeasible one and get the exit code you promised to avoid.
3. **The boundary is exactly where floating point is worst.** `ρ* = 3.8198` at `δ* = 0.49` is
   a *boundary*, and `δ*` arrives as `txlVolumeRate` in integer pips (490000). A predicate
   evaluated in `Double` near equality will disagree with GAMS's evaluation of the same
   predicate near equality.

**Why it happens:**
"Closed form, no optimizer" reads as "trivially correct". Closed forms are exactly where
rounding conventions hide.

**How to avoid:**
- **A differential test against the model.** Sweep a grid of `(f, δ*)`, run the Haskell
  predicate and the GAMS prover on each, and assert the verdicts agree — every disagreement
  is a bug in one of them. Include points *on* the boundary and one pip either side.
- **Exact arithmetic at the boundary.** Evaluate the quadratic in `Rational` (the inputs are
  integer pips, so it is exact and cheap) rather than `Double`. Then "on the boundary" is
  decidable rather than coin-flipped.
- **Pin the rounding rule in writing** (round-half-even? floor? and in which direction is it
  safe?) and property-test that the rounded pips still satisfy the level constraint within a
  stated tolerance — a rounding that breaks `(1−φ_X)(1−φ_M) = 1−f` by a pip must be *known*,
  not discovered downstream.
- Reject `φ_X == φ_M` in Haskell with the §1.2 reason quoted in the error text.

**Warning signs:**
A `Double` comparison against `3.8198` or `0.49`. A splitter with no differential test.
`splitter_version` absent from the key.

**Phase to address:**
**Phase 5 (fee splitter)** for the predicate, exact arithmetic and differential test.
**Phase 2** must have reserved the `splitter_version` key component before Phase 5 runs.

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|---|---|---|---|
| Store the artifact in `jsonb` only; skip the `bytea` column | One column, queryable immediately | The determinism guarantee is unfalsifiable — the milestone's headline claim cannot be evaluated at all | **Never.** This is the milestone's core requirement |
| Key = the seven inputs only; add the model-source hash later | Matches `VOLUME_PATH.md` §2 literally; ships Phase 2 sooner | Every cached row becomes suspect the moment the `.gms` changes; retrofitting means invalidating everything with no way to tell which rows were affected | Only with `key_scheme` already in the unique index, so the later change orphans rather than corrupts |
| Migrate-on-startup in the loop | No separate command to remember | Races between instances and CI runs; half-applied DDL on a shared executor | Acceptable *only* if wrapped in an advisory lock and the loop is proven single-instance |
| Skip DB tests when Postgres is absent | Contributors without a DB aren't blocked | A green suite that verified nothing — this repo's #1 recurring defect | Acceptable locally; **never** in CI (`CFMM_REQUIRE_DB=1` + a count floor) |
| Gate GAMS purely on exit code, as §4 says | Simple; matches the written contract | Exit `0` with a stale/missing/malformed output file poisons the cache permanently and silently | Acceptable *only* as the first of Pitfall 8's conjuncts, never alone |
| Publish the fixture straight from the loop into `test/` | End-to-end demo works today | Torn reads, an unattributable moving target, and a background process writing another track's tree | Acceptable for a local demo; the committed fixture must come from an explicit promotion |
| `Double` for `deltaRealized`/`rPhiRealized` (they are genuinely small) | Natural Haskell type | Fine for *those two* — but the habit spreads to `dQx` and silently loses wei | Acceptable for the two rate fields only, with a comment naming the two and forbidding the rest |
| Reuse one long-lived `Connection` in the resident loop | No pool dependency | `Connection` is not thread-safe; a server restart or idle timeout kills the loop with no reconnect | Only single-threaded, with explicit reconnect-on-failure and a health check |

---

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|---|---|---|
| PostgreSQL `jsonb` | Storing the canonical artifact in it, expecting bytes back | `bytea` for the artifact, `jsonb` as a derived projection; both written in one `INSERT` |
| PostgreSQL `json` (non-b) | Treating it as byte-safe because it "stores an exact copy of the input text" | It is text: UTF-8 validated against the database encoding and `U+0000`-hostile. Still not a byte container |
| postgresql-simple | Passing a bare `ByteString` to a `bytea` column | Wrap in `Binary`; enforce with a newtype whose only `ToField` path goes through it |
| postgresql-simple | Assuming a built-in connection pool | There isn't one. Add `resource-pool` explicitly, or run strictly single-connection/single-threaded and say so |
| postgresql-simple | `SELECT` then `INSERT` on a cache miss | `INSERT ... ON CONFLICT (model, key_scheme, key) DO NOTHING` then re-`SELECT`; note `RETURNING` yields **no rows** on a `DO NOTHING` conflict |
| PostgreSQL indexing | GIN on the output `jsonb` because "it's JSONB" | Every lookup is exact-by-key. A `UNIQUE` btree on `(model, key_scheme, key)` over `bytea` is the whole access path. GIN buys nothing and costs write throughput |
| PostgreSQL hash storage | Hash as `text` hex | `bytea`, 32 bytes, no collation, no encoding, half the size, and no case-sensitivity ambiguity |
| GAMS subprocess | `readProcess` | Throws on any non-zero exit, discarding the exit code §4 tells you to gate on. Use `readProcessWithExitCode` |
| GAMS subprocess | Inheriting the environment | Explicit `env` whitelist + `LC_ALL=C`; fresh temp cwd per invocation |
| GAMS exit codes | Treating `0` as "solved" | GAMS docs: return codes carry no model-solution information. `0` + positive post-conditions, or nothing |
| GAMS put files | Assuming one JSON array = one line | Default page width is 255 columns; long lines wrap. The `.pw` setting is part of the artifact's byte identity → covered by the model-source hash |
| aeson | `decode` then `encode` to "normalise" | Not the identity — measured: key order, `2.8e19`→`28000000000000000000`, `0.00318353`→`3.18353e-3`. Never re-encode the artifact |
| aeson | `Double` for wei-scale JSON numbers | Measured 32-wei loss on `dQx[0]`. Use `Integer`/`Scientific` |
| Anvil / `eth_call` | Omitting the block parameter (defaults to `latest`) | Mandatory `BlockRef` argument on every read; pin to `blockHash` and assert |
| Anvil / `eth_getLogs` | Ignoring the `removed` field | `removed = true` marks a run-log row superseded; store `blockHash` so replacement is detectable |
| The `haskell` CI gate | Adding a Postgres dependency to a job that has never run | Get the job green *first*; per-run database name; extend the host-wide flock or avoid the shared singleton entirely |
| `test/` (another track's tree) | A background process writing into it | Loop writes to `offchain/` staging; promotion into `test/` is explicit and committed; atomic rename via the existing `write_json_atomically` |
| cabal build plan | Adding `postgresql-simple` + pool + migration lib casually | This repo documents every new dependency and whether it changes the resolved plan (see the `.cabal` comments). Measure and record the plan delta; a DB client pulls a non-trivial subtree |

---

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|---|---|---|---|
| Thundering herd on a cold key | Two runners/loops both miss the same key and both run a 30 s CONOPT solve | Advisory lock keyed on `hashtext(key)` around the solve; the loser re-reads the cache after | The moment a second consumer exists — a dev box and CI on the same DB |
| Transaction held across the solve | `pg_stat_activity` shows `idle in transaction` for tens of seconds; vacuum stalls | Read → `COMMIT` → solve → new transaction to write | Immediately, with any concurrency |
| GIN index on the output document | Slow inserts, large index, zero query benefit | Btree unique on the key; add GIN only when a real jsonb query exists | At a few thousand rows the write cost shows before any benefit does |
| Unbounded run log + output rows | Table growth with no prune path; `reset` too scary to run | Retention policy written down in Phase 1; pinned rows exempt; run log stays append-only forever (it is small) | Weeks of continuous loop operation |
| Connection leak in the resident loop | Connection count climbs to `max_connections`; new work fails to connect | `bracket`/`withConnection` everywhere; a pool with a bounded size; reconnect-on-failure | Days of uptime with any error path that skips cleanup |
| TOAST + large artifacts | Slow reads once documents exceed ~2 KB (compressed, then out-of-line) | Irrelevant at `nEvents = 8` (~1 KB); becomes real if `VOLUME_PATH.md` §6 ruling 1 raises `nEvents` substantially | Only if `nEvents` grows by an order of magnitude |
| Re-solving on every loop tick because the key never hits | Constant CPU, cache hit rate ~0 | Usually a *correctness* symptom (Pitfall 6 non-canonical rendering), not a perf one — instrument hit/miss and alarm on a 0% rate | Immediately, and it is diagnostic |

---

## Security Mistakes

| Mistake | Risk | Prevention |
|---|---|---|
| String-interpolating the model name or key into SQL | Injection via a value that ultimately traces to chain data | Parameterised queries only; `model` is a closed enum in Haskell, not free text |
| Connection string with the password in the repo or in `ps` output | Credential disclosure; the repo is intended to be **public** (PROJECT.md constraint) | `PGPASSFILE`/environment only; never a literal in a tracked file; add the path to `.gitignore` and check |
| Logging the full environment for reproducibility | Leaks the GAMS licence and DB credentials into the run log and CI output | Log the whitelisted **keys**, and values only for a non-secret allowlist |
| Trusting `dQx` from the store without re-validating shape before it reaches a test that spends real value | A poisoned row drives on-chain swaps | Re-validate at the consumption boundary too: array length, sign convention, magnitude bounds. Validation at the write boundary is necessary, not sufficient |
| The GAMS subprocess inheriting a writable cwd inside the repo | A model run overwrites tracked files | Fresh `withSystemTempDirectory` per invocation; the repo is never the working directory |
| Committing the fixture without provenance | An unattributable input to a test that gates merges | Fixture carries key + block hash + toolchain versions |

---

## Operator / Consumer UX Pitfalls

| Pitfall | Impact | Better Approach |
|---|---|---|
| A cache miss with no explanation | Operator cannot tell "new shock" from "model edited" from "version detection broke" | Store the key components separately; the miss message names *which component differed* from the nearest existing row |
| A determinism mismatch thrown as an exception | The most valuable observation the system can make is lost to a stack trace in a dead process | Record it as a `determinism_check` row with byte offsets; the loop continues |
| `reset` with no scope | Destroys the run log and pinned rows | Mandatory scope argument; refuses bare; reports skipped-pinned counts |
| Infeasibility surfaced as a GAMS exit code | Downstream cannot distinguish "unreachable rate pair" from "licence expired" | Phase 5 refuses infeasible shocks in Haskell with §1.2/§1.3 quoted; Phase 3 separates model-level (`2`/`3`) from environmental codes |
| A forge failure with no way back to the producing run | Cross-track debugging with no shared identifier | Fixture carries the content key; the run log maps key → tx hash → block hash |

---

## "Looks Done But Isn't" Checklist

- [ ] **Byte-exact store:** often missing the `bytea` column entirely — verify by hashing the artifact on the way in and on the way out and asserting equality, over a corpus including `0x00`, invalid UTF-8, and a trailing newline.
- [ ] **Determinism check:** often a tautology or never executed — verify `determinism_check` has non-zero rows, that a *deliberately corrupted* cached row makes it report disagreement, and that the two comparands are distinct newtypes.
- [ ] **Content key:** often omits the model source and the splitter version — verify by editing a comment in `volume_path.gms` and asserting the key changes.
- [ ] **Key canonicalisation:** often unframed — verify that a crafted pair of distinct shocks whose decimal renderings concatenate identically produce *different* keys.
- [ ] **Absent-input handling:** often defaults silently — verify one negative test per field asserting the pipeline refuses, with the field named in the error.
- [ ] **Version detection:** often returns `""` on a parse miss — verify with garbage inputs (`""`, `"\n"`, a help banner, a localised banner) that every one is rejected.
- [ ] **Exit-code gate:** often the only check — verify by pointing the layer at a script that exits `0` and writes nothing, and asserting the layer refuses.
- [ ] **Stale output file:** often invisible — verify by pre-creating a valid-looking `volume_path.json` at the expected path and asserting the run does not consume it.
- [ ] **Subprocess:** often deadlocks only under load — verify with a child that writes >1 MB to stderr and asserts completion; verify the timeout path terminates and reaps.
- [ ] **Block pinning:** often only on the first read — verify every read function's signature requires a `BlockRef`; grep for `latest` in the read layer.
- [ ] **Loop idempotency:** often absent — verify by replaying the same `(txHash, logIndex)` twice and asserting one run-log row.
- [ ] **Fixture publication:** often non-atomic — verify with a reader loop racing a writer loop for 10 s and asserting zero unparseable reads.
- [ ] **Migrations:** often only tested incrementally — verify from a completely empty database (which is what CI's `git clean -ffdx` guarantees), twice in a row, concurrently.
- [ ] **DB tests in CI:** often skip — verify the suite is **red** when `CFMM_REQUIRE_DB=1` and no database is reachable, and that a count floor on executed store checks exists.
- [ ] **Fee splitter:** often untested against the model — verify a `(f, δ*)` grid where the Haskell verdict and the GAMS verdict agree, including boundary points.

---

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---|---|---|
| Artifact stored only in `jsonb` | **HIGH** | Every stored artifact is unrecoverable as bytes. Add the `bytea` column, bump `key_scheme`, re-solve everything from the recorded shocks (the run log makes this possible — which is why it must never be reset) |
| Key omitted the model source | MEDIUM | Add the component, bump `key_scheme`. Old rows orphan. Cost is re-solve time only — *provided* `key_scheme` existed from day one; without it, the recovery is a full-table rebuild with no way to identify affected rows |
| Cache poisoned by an exit-`0`-but-bad run | MEDIUM | Delete unpinned rows lacking a passing `determinism_check`, then re-verify pinned rows one at a time under `--check` |
| Version detection returned `""` for a period | MEDIUM–HIGH | If the version column was stored separately (do this), the affected rows are identifiable by `version = ''` and deletable. If it was only folded into the hash, they are indistinguishable → delete all unpinned rows |
| Non-canonical key rendering caused duplicate keys | LOW | `key_preimage` column makes duplicates visible; canonicalise, bump `key_scheme`, re-solve |
| Loop double-processed events after a crash | LOW | `(txHash, logIndex)` unique constraint prevents it; if absent, de-duplicate the run log by that pair and add the constraint |
| Reorg / `anvil_reset` orphaned run-log rows | LOW | `blockHash` on every row makes them identifiable; mark superseded, do not delete |
| Migration half-applied on a shared CI database | MEDIUM | Per-run databases make this unreachable; if it happened, drop and recreate — which is only safe because CI state is disposable by design |
| Fixture published torn and committed | LOW | Re-publish from the staged artifact; the shape floor prevents recurrence |

---

## Pitfall-to-Phase Mapping

| # | Pitfall | Prevention Phase | Verification |
|---|---|---|---|
| 1 | `jsonb` cannot return input bytes | **1** Postgres foundation | Hash-in/hash-out equality over an adversarial byte corpus |
| 2 | aeson round-trip is not the identity; `Double` loses wei | **1** (artifact path) / **3** (decode) | Golden test: exact `Integer` decode of a known `dQx`; grep for `encode` on the artifact path |
| 3 | `ToField ByteString` sends text | **1** Postgres foundation | Round-trip a `ByteString` containing `0x00` and invalid UTF-8 |
| 4 | Key omits model source / solver options | **2** keyed store (formula, `key_scheme`) / **3** (source digest) | Edit a `.gms` comment → key must change |
| 5 | Absent input defaults before hashing | **2** keyed store / **4** for chain-read fields | One negative test per field asserting refusal, field named |
| 6 | Unframed concatenation collides | **2** keyed store | Crafted colliding-concatenation pair must yield different keys |
| 7 | Version detection succeeds emptily | **3** GAMS layer | Garbage-input battery on the parser; all rejected |
| 8 | Exit `0` ≠ solved; stale output file | **3** GAMS layer / **2** write rule | Script exiting `0` writing nothing → refused; pre-existing output file → not consumed |
| 9 | Elision means the check never runs | **2** keyed store | `determinism_check` row count > 0; corrupted cached row → reported disagreement; comparands are distinct types |
| 10 | Poisoning; `reset`/`pin` scope | **2** keyed store | No `INSERT` reachable without the success predicate; bare `reset` refuses |
| 11 | Pipe deadlock, no timeout, env leakage | **3** GAMS layer | >1 MB stderr child completes; timeout terminates and reaps; explicit `env` asserted |
| 12 | Reads at a different block than the event | **4** Anvil reads | Every read function requires `BlockRef`; zero `latest` in the read layer; non-degenerate-value assertions |
| 13 | Re-delivery, reorg, restart, growth | **6** resident loop (constraints land in **1**) | Replay a `(txHash, logIndex)` → one row; `removed` log → superseded not deleted; cursor survives restart |
| 14 | Torn / unattributable fixture publication | **6** resident loop | Reader/writer race for 10 s → zero unparseable reads; fixture carries key + block hash |
| 15 | Migrations from a loop; concurrent runners | **1** Postgres foundation | Two concurrent migrators → one applies; from-empty run twice; per-run CI database |
| 16 | DB tests skip → green having verified nothing | **1** Postgres foundation | Suite red under `CFMM_REQUIRE_DB=1` with no DB; count floor on executed store checks; a sentinel that must fail |
| 17 | Fee-splitter closed form drifts / boundary FP | **5** fee splitter (key component reserved in **2**) | `(f, δ*)` grid differential vs GAMS, including boundary ± one pip; `Rational` evaluation |

**Phase-ordering consequences implied by the above:**

- **Phase 1 carries more than "a database exists."** It owns the byte-exactness guarantee, the
  migration mechanism, `key_scheme`, the CI database strategy, and the "tests must not skip"
  contract. Phases 2–6 all consume decisions made here, and every one of them is expensive to
  retrofit. Phase 1 must not be scoped as plumbing.
- **Phase 3's version detection must land before Phase 2's first production write**, because
  the key formula consumes it and an emptily-succeeding detector poisons every row written
  before it is fixed. If the roadmap keeps the numeric order, Phase 2 must not write
  production rows until Phase 3's detector exists — or Phase 2's key must refuse to be
  constructed without validated version components.
- **Phase 2 must reserve key components for things later phases produce** (`splitter_version`
  from Phase 5, `model_source_digest` from Phase 3) — or `key_scheme` must be in place so
  adding them later is non-destructive. `key_scheme` is the cheapest insurance in the
  milestone.
- **Phase 4 is BLOCKED on the plank worktree** emitting the `next` event. The block-pinning
  discipline and the decoder can and should be built against synthetic logs (the existing test
  suite already constructs synthetic `Change` values), so the blocker delays the integration,
  not the correctness work.

---

## Sources

**Official documentation (HIGH confidence):**
- PostgreSQL — JSON Types (`json` vs `jsonb` whitespace/key-order/duplicate-key behaviour, `numeric` number normalisation with the `1.230e-5` → `0.00001230` example, `U+0000` rejection): https://www.postgresql.org/docs/current/datatype-json.html
- `postgresql-simple` — `ToField` (the `Escape` vs `EscapeByteA`/`Binary` distinction): https://hackage.haskell.org/package/postgresql-simple/docs/Database-PostgreSQL-Simple-ToField.html
- `aeson` — `Data.Aeson.KeyMap` (*"The order is not stable. Use `toAscList` for stable ordering."*): https://hackage-content.haskell.org/package/aeson-2.3.1.0/docs/Data-Aeson-KeyMap.html
- `process` — `System.Process` (`readProcess` throws `IOError` on non-`ExitSuccess`; **no** deadlock caution is documented for `createProcess`/`CreatePipe`, so the hazard is entirely the caller's): https://hackage-content.haskell.org/package/process-1.6.25.0/docs/System-Process.html
- GAMS — Return Codes (*"return codes do not provide information about a model inside the GAMS job … the model may have been infeasible … while the return code says all is fine"*; `abort` → code 3): https://www.gams.com/latest/docs/UG_GAMSReturnCodes.html
- GAMS — The Put Writing Facility (default page width 255 columns, `.pw` upper limit 32767): https://www.gams.com/latest/docs/UG_Put.html
- Nix — Verifying Build Reproducibility (`--check` / `--rebuild`, `--repeat`/`build-repeat`, `--keep-failed` + diff-hook): https://nix.dev/manual/nix/2.34/advanced-topics/diff-hook.html
- Ethereum JSON-RPC `eth_getLogs` (the `removed` field; `blockHash` filter equivalence to a pinned from/to): https://docs.metamask.io/services/reference/ethereum/json-rpc-methods/eth_getlogs/

**Measured at this commit (HIGH confidence):**
- aeson `decode`→`encode` round-trip on `VOLUME_PATH.md` §3's output shape, and `[Double]` vs `[Integer]` decode of wei-scale `dQx` values — run via `cabal exec -- runghc` against this project's existing build plan. Results reproduced inline in Pitfall 2.

**Community / production experience (MEDIUM confidence):**
- Bazel remote cache poisoning — *"if an action exits 0 but the output is malformed … the cache will be poisoned"*: https://github.com/bazelbuild/bazel/issues/4276 , https://bazel.build/remote/caching
- PostgreSQL -hackers thread on exposing jsonb's binary format as `bytea` (the internal format is deliberately unexposed and reserved for change; no direct `jsonb`→`bytea` cast): https://www.postgresql.org/message-id/CAOsiKEKAJn0TEVg=_nCOw=vdCDRyMrJGBrPKs4uZuerczj2KfA@mail.gmail.com
- Indexing EVM events / reorg handling in resident indexers: https://bilinearlabs.io/blog/indexing-blockchain-events/
- nixbuild.net on finding non-determinism by repeated builds: https://blog.nixbuild.net/posts/2021-01-13-finding-non-determinism-with-nixbuild-net.html

**Repository inspection (HIGH confidence for facts about this repo):**
- `model/mev_tax_model_one/VOLUME_PATH.md` (in the `gams` worktree) §§1–6 — the seven inputs, the output shape, the named aborts, the determinism claim and its toolchain condition, the open rulings
- `.planning/PROJECT.md` — v6.0 milestone scope, the six target features, the `test/` territory rule
- `offchain/lib/Driver/Capture.hs` — the existing 2^53 rule, `write_json_atomically`, and the `dr_complete`/`or_complete` two-flag discipline (all directly reusable precedent)
- `.github/workflows/develop-gate.yml` — self-hosted `cfmm-build` executor, `concurrency` keyed on `github.ref` only, the advisory `flock` for port 8545, and the recorded fact that `actions/checkout`'s `git clean -ffdx` removes ignored files between runs
- `cfmm-replicationPlank-rpc-api.cabal` — the repo's explicit build-plan-delta discipline for every new dependency
- Absence of `.gitattributes` — verified; no EOL normalisation protection exists for a published fixture today

**Gaps / lower confidence:**
- The exact CONOPT version-detection method is **unresolved**. `gams --version` does not report the solver's version, and the only obvious source is listing/log text — which §4 forbids gating on. Phase 3 must settle this; treat "record it from log text, totally and non-emptily, for the key only" as the working assumption, not a verified answer. **LOW confidence.**
- Whether `volTgtWad` is an integer or a float on the GAMS side is not settled by `VOLUME_PATH.md` (§2's own example passes `28e18`). This determines the canonical key rendering and must be answered in Phase 3 before Phase 2 freezes the key formula. **LOW confidence.**
- Whether `GAMS`-emitted `volume_path.json` currently ends with a trailing newline, and its `.pw` setting, were not inspected (the `.gms` lives in another worktree). Both are byte-identity-relevant and are cheap to check in Phase 3. **Unverified.**
- The claim that GitHub Actions `services:` containers behave usefully on this specific self-hosted executor was **not** verified; the per-run-database recommendation is chosen partly because it does not depend on the answer. **MEDIUM confidence.**

---
*Pitfalls research for: Postgres/JSONB content-addressed model-output cache + GAMS subprocess layer + resident chain-watching loop, added to an existing Haskell/Foundry monorepo*
*Researched: 2026-08-16*
