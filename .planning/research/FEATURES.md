# Feature Research

**Domain:** Keyed / content-addressed artifact store with cache elision and determinism verification, over Postgres, fronting an external deterministic solver (GAMS `volume_path.gms`)
**Researched:** 2026-08-16
**Confidence:** HIGH for prior art (Nix, ccache, Bazel, git, Postgres — all verified against primary docs, exact quotes below); MEDIUM for the synthesis into this project's shape (an opinionated recommendation, not an observed system)

---

## Scope Framing

This is **not** a general cache. It is a **falsifiable-evidence store that happens to elide work.** Two of the six required behaviours are in tension and that tension is the whole design:

- *cache elision* says **never re-run** a solve you already have;
- *determinism verification* says **sometimes re-run it on purpose and compare**.

Every prior-art system below sits somewhere on that line, and the ones that sit at the extremes (ccache: never check; Nix `--repeat`: always check) both failed in instructive ways. The recommendation is Nix's `--check` position: **elide by default, verify on explicit demand and on toolchain change, and treat a mismatch as an immutable finding rather than a repair.**

The binding input contract is `model/mev_tax_model_one/VOLUME_PATH.md` §2 (seven inputs), §3 (output shape + determinism guarantee), §4 (named aborts, gated on exit code). Read, not re-derived. The determinism claim being made falsifiable is §3: *"byte-identical JSON across 8 measured runs. Same inputs + same toolchain (GAMS 54.1, CONOPT 4.39) → same bytes."*

---

## Part 0 — The finding that reshapes the milestone header

**PROJECT.md calls this a "Postgres/JSONB keyed store." A `jsonb` column cannot hold the artifact.**

PostgreSQL documentation, verbatim ([datatype-json](https://www.postgresql.org/docs/current/datatype-json.html)):

> "Because the `json` type stores an exact copy of the input text, it will preserve semantically-insignificant white space between tokens, as well as the order of keys within JSON objects. ... By contrast, `jsonb` does not preserve white space, does not preserve the order of object keys, and does not keep duplicate object keys."

> "in `jsonb`, numbers will be printed according to the behavior of the underlying `numeric` type. In practice this means that numbers entered with `E` notation will be printed without it."

The whole milestone rests on *byte* identity. A `jsonb` round-trip destroys exactly the three things byte identity is made of: whitespace, key order, and number literal form. Storing the solver's output as `jsonb` and later comparing it to a fresh solve would compare **normalised** documents — which is a strictly weaker predicate than the one `VOLUME_PATH.md` §3 asserts, and would silently pass a real non-determinism (e.g. CONOPT emitting `2.7632E+19` where it previously emitted `27632000000000000000`).

**Therefore:** the artifact column is `bytea` (or `text`) holding the raw bytes as delivered, plus a stored `sha256` digest; `jsonb` is a *derived, queryable projection* (generated column or a second column), never the source of truth. This is a one-line schema decision with LOW implementation cost and it is load-bearing for the entire verification feature. It should become a REQ in the schema phase, not be discovered in the verification phase.

---

## Part 1 — Key design

### What goes in the key

| Component | In key? | Why |
|---|---|---|
| The seven inputs (§2: `sqrtPriceX96`, `liquidityRaw`, `txlVolumeRate`, `phiXpips`, `phiMpips`, `volTgtWad`, `nEvents`) | **YES** | They are the shock. This is the definition of the key. |
| GAMS version (54.1) | **YES** | §3 scopes the determinism guarantee to "same toolchain". |
| CONOPT version (4.39) | **YES** | §3: *"A different CONOPT version may select a different member of the underdetermined path family — still passing every gate."* A different member is different bytes. If the sub-solver version is not in the key, a toolchain bump makes every existing entry a **false mismatch**, and the store's one real alarm becomes noise on day one. |
| Digest of `volume_path.gms` source (and any `$include`d model files) | **YES — recommended addition** | Editing the model changes the output with all seven inputs and both versions unchanged. Nix and Bazel both key on the *build recipe*, not just its inputs: Bazel's action key "contains the command, arguments, and environment variables combined as a digest and a Merkle tree digest from the input files" ([EngFlow, The Many Caches of Bazel](https://blog.engflow.com/2024/05/13/the-many-caches-of-bazel/)); Nix's derivation hash covers the builder script transitively. Omitting the model digest is the single most likely cause of a **stale hit** — the failure mode that looks like success. |
| Wall-clock time, hostname, run counter, PID, absolute output path, Anvil block number, `next` tx hash | **NO** | Any of these makes every key unique and the hit rate zero. They belong in the run log (Part 5), which is precisely why the run log exists. |
| The Anvil block the pool state was read at | **NO** | Two blocks with the same `(sqrtPriceX96, liquidityRaw)` *are the same shock* and must hit. This is the discriminating example that proves the block belongs in the log and not the key. |

**Prior-art contrast on "toolchain in the key vs. beside it":** ccache keys the compiler in, by default hashing its **mtime and size** — `CCACHE_COMPILERCHECK` selects between `mtime` (default), `content` (hash the binary), or an arbitrary `string:`/command ([ccache manual](https://ccache.dev/manual/latest.html)). That default is a known trap: a rebuilt-but-identical compiler changes mtime and invalidates everything, and a touched-but-changed compiler in a container with a normalised mtime does not invalidate anything. **For us the analogue of `CCACHE_COMPILERCHECK=command` is right**: run `gams --version` / read CONOPT's banner and key the reported *version strings*, not the binaries' mtimes. Versions are what §3's guarantee is phrased in.

### Canonical serialization — the actual trap here

The seven inputs are not homogeneous:

- **Three exceed IEEE-754 binary64 exact range.** `sqrtPriceX96` is uint160 and `liquidityRaw` is uint128; the fixture values `79228162514264337593543950336` (= 2⁹⁶) and `18446744073709551616` (= 2⁶⁴) are both far above 2⁵³. §3 records the empirical bite: *"the double path printed 2⁶⁴ off by 384 wei — never parse these fields as doubles."* `volTgtWad` is wei at the 1e19 scale — same class.
- **Three are rationals transported as scaled integers.** `txlVolumeRate = δ*·1e6` (pips), `phiXpips`, `phiMpips`. The *value* is `490000/1e6 = 0.49`; the *transport* is the integer `490000`.
- **One is a small integer.** `nEvents` (fixture 8).

Three rules follow, and they are testable:

**K1 — Hash the exact argv bytes, produced by the same function that builds argv.**
GAMS `--key=value` overrides are compile-time textual substitutions. What the solver consumes is the literal argument string. So the correct key preimage is the literal argument string. Build one renderer `renderArg :: Input -> ByteString`, use it for *both* the subprocess argv and the hash preimage, and key-vs-invocation agreement becomes structural rather than an assertion someone has to remember to write. The testable property: *for every input tuple, the concatenation of bytes hashed is a substring-wise reconstruction of the bytes passed to `execve`.*

**K2 — Never round-trip a key component through a float, in either direction.**
This includes canonicalisation frameworks. RFC 8785 (JSON Canonicalization Scheme) is the obvious off-the-shelf answer and is **the wrong tool here**: JCS "requires that JSON number data MUST be expressible as IEEE 754 double-precision values" and explicitly tells you that for larger integers you should "represent such numbers as JSON strings" ([RFC 8785](https://datatracker.ietf.org/doc/rfc8785/)). Applying JCS naively to `{"sqrtPriceX96": 79228162514264337593543950336}` produces a *canonical* and *wrong* number. If a canonical-JSON preimage is wanted for readability, every wide integer must be a JSON **string**, and that must be enforced by the type (Haskell `Integer` rendered by `show`, never `Scientific`/`Double`).

**K3 — Rationals are keyed as `(numerator, declared denominator)`, never as a decimal expansion.**
`0.49` is not exactly representable in binary64; whether a renderer emits `0.49`, `0.490000`, or `0.48999999999999999` is a property of the renderer, not of the value. Key the integer `490000` with the scale `1e6` fixed in the schema (or in the key's version tag). Note `VOLUME_PATH.md` §6 open ruling 2 — *"the pips denominator (1e6) of `phiXpips`/`phiMpips` against the pool's actual fee encoding"* — is unresolved; that is a live risk to key stability and should be pinned before the key is minted, because changing the denominator later reinterprets every existing key without changing any key's bytes. That is the worst possible kind of change.

**K4 — Prefer a key finer than semantics; never coarser.**
If `--volTgtWad=28e18` and `--volTgtWad=28000000000000000000` are passed on different days, they are the same solve but will produce different keys under K1. That is a *spurious miss*: it costs one solve. The opposite error — two genuinely different shocks colliding onto one key — is a *spurious hit*: it returns bytes that do not correspond to the inputs, and no downstream test can detect it. A solve here takes seconds. Buy safety with misses. (Concretely: normalise at the **Haskell type boundary** — one `Integer`, one rendering — so this situation cannot arise from within the system, and accept it if a human hand-runs the CLI.)

**K5 — Version the key scheme itself.** A `key_scheme` column or a scheme tag inside the preimage. When K3's denominator ruling lands, or the model digest is added, old keys must become unreachable rather than silently reinterpreted. Nix does this implicitly (any change to the derivation changes the hash); a hand-rolled scheme has to do it explicitly.

---

## Part 2 — Cache semantics: hit / miss / mismatch

### What "stale" means here (and mostly does not)

Content-keyed entries do not go stale with time. They go stale when something outside the key changes — which is exactly the argument for putting the toolchain versions and the model digest *inside* the key (Part 1). With a complete key, **there is no stale state**: there is hit, miss, and mismatch. Any design that reintroduces a "stale" state (a TTL, a freshness window) is reintroducing a bug the key already solved. See anti-feature A-10.

### What every prior system actually does when stored bytes and a fresh run disagree

| System | Key → value model | Divergence policy | Verified from |
|---|---|---|---|
| **ccache** | input hash → cached object | **Never looks.** A hit returns the stored object; ccache does not re-run the compiler to compare. Divergence is invisible by construction. | [ccache manual](https://ccache.dev/manual/latest.html) |
| **Bazel / Remote Execution** | action digest (input-addressed) → `ActionResult`; blobs in a content-addressed CAS | **Never looks either**, in normal operation. The ActionCache entry is overwritten by whoever ran last; both output blobs coexist harmlessly in the CAS because *it* is content-addressed. Detection is **out of band**: run the build twice with `--execution_log_compact_file` and diff the logs ([Debugging Remote Cache Hits](https://bazel.build/remote/cache-remote)). There is a known class of bug where an action is cached as successful although its declared outputs were not produced ([bazel#14543](https://github.com/bazelbuild/bazel/issues/14543)) — the generic name is *cache poisoning*, and it is hard to find precisely because nothing checks. |
| **Nix, classic input-addressed** | derivation hash → fixed store path | **`--check` looks, on demand.** It rebuilds and compares. On divergence: exit status 1 and `derivation '/nix/store/…-unstable.drv' may not be deterministic: output '/nix/store/…-unstable' differs`. **The original output is kept; the divergent rebuild is discarded** — or preserved at a parallel `…​.check` path with `--keep-failed`, which is "not protected against garbage collection". A `diff-hook` executable can be configured to render the difference ([Verifying Build Reproducibility](https://nix.dev/manual/nix/2.25/advanced-topics/diff-hook)). **First writer wins; the mismatch is a report, not a repair.** |
| **Nix, content-addressed derivations** | drv output → *realisation* → CA store path | A store **may hold at most one realisation per derivation output**; a conflicting realisation offered by a substituter is **refused**. From RFC 0062 / the CA implementation: *"the current implementation has a naive approach that just forbids fetching a path if the local system has a different realisation for the same drv output"*, and *"it's illegal to register the realisation for Alice's glibc and Bob's glibc at the same time"* ([Tweag, Implementing a content-addressed Nix](https://www.tweag.io/blog/2021-12-02-nix-cas-4/), [RFC 0062](https://github.com/NixOS/rfcs/blob/master/rfcs/0062-content-addressed-paths.md)). Divergent *content* may exist; the *mapping* is single-valued. |
| **Reproducible Builds / rebuilderd** | (source, `.buildinfo`) → expected package hash | Divergence is **neither error nor overwrite: it is published as a status.** Independent rebuilders emit signed attestations; disagreement becomes a "unreproducible" record with a `diffoscope` report attached (logs capped at 20 MiB, diffoscope output at 10 MiB). Multiple attestations coexist by design ([reproducible-builds.org/tools](https://reproducible-builds.org/tools/)). |
| **Gradle / Develocity** | task input hash → output | Divergence never presents as a mismatch — it presents as a **cache miss**, because non-determinism upstream changes the key. Diagnosed by *task inputs comparison* across two builds ([Develocity task inputs comparison](https://docs.gradle.com/enterprise/tutorials/task-inputs-comparison/)). Netflix's documented finds via "build twice, compare": Java minor-version manifest differences, a generator producing different output on Linux vs macOS. |

### The four available policies, and the recommendation

1. **Never check** (ccache, Bazel-in-practice) — cheapest, and forfeits the entire point of this milestone.
2. **Last-write-wins overwrite** (Bazel ActionCache) — actively destroys the evidence. **Reject explicitly** (anti-feature A-1).
3. **Error, keep the original** (Nix `--check`) — first-writer-wins on the canonical row; the divergent bytes are discarded unless explicitly kept.
4. **Record both, publish the disagreement** (rebuilderd) — the divergence becomes durable data.

**Recommendation: 3 + 4.** The canonical row is immutable and first-writer-wins (Nix). The divergent bytes are *not* discarded — they land in a quarantine table with both digests, joined to the run log (rebuilderd). The operation exits non-zero. This gives the loud signal *and* the artifact needed to diagnose it, and it makes "a re-solve that disagrees is caught" (PROJECT.md's wording) an observable database row rather than a log line that scrolled past.

Explicitly **not** a fork/new-version: forking implies both bytes are legitimate, which contradicts §3's guarantee. If a fork ever seems needed, the honest conclusion is that the key is incomplete (something outside it changed) — the fix is Part 1, not a versioning scheme.

---

## Part 3 — Determinism verification as a feature

### The cost problem, and what the field learned

Nix once had exactly the "always verify" design: `--repeat N` ("specifies the number of times to repeat a build in order to verify determinism") together with `enforce-determinism` ("whether to fail if repeated builds produce different output"). **Both were removed in Nix 2.13 (2023-01-17) because they "had been broken under many circumstances for a long time"** ([Nix 2.13 release notes](https://nix.dev/manual/nix/2.34/release-notes/rl-2.13.html)). What survived is `--check`: opt-in, per-derivation, invoked when you want the answer. That is the single most useful data point in this research — **the industry tried always-on determinism enforcement, and the always-on version is the one that died.**

Bazel never had a repeat-and-compare flag at all. *(Correction to the brief: `--experimental_repeated_by` does not exist — searches across Bazel's flag reference, `bazel_flags.proto`, and the command-line reference return nothing. `--runs_per_test` repeats **tests**, not build actions, and does not compare outputs. Bazel's actual determinism workflow is out-of-band execution-log diffing via `--execution_log_compact_file`, plus `--experimental_execution_log_spawn_metrics` since Bazel 5.2.)* Treat any requirement written against that flag name as unfounded.

### When to re-check — a policy, in priority order

| Trigger | Cost | Rationale |
|---|---|---|
| **Explicit `verify <key>` / `verify --all` command** | on demand | The Nix `--check` position. This is the MVP and the only one strictly required. |
| **On toolchain-version change** | once per bump | The highest-value automatic trigger, and it is nearly free: when GAMS or CONOPT moves, the *old* key becomes unreachable anyway (versions are in the key), so re-verification here means re-solving a handful of representative old shocks under the new toolchain and recording whether the path family member changed. §3 predicts it will. That prediction is worth a recorded measurement. |
| **Sampled — verify p% of hits** | tunable | Bounds the ongoing cost while giving continuous coverage. p=0 in the resident loop's hot path by default. |
| **Scheduled (nightly / CI job)** | off the critical path | Where `make test-gams`'s existing "determinism double-run" (§5) already lives. Extend it to consult the store rather than run standalone. |
| **On every cache hit** | **unbounded — reject** | Anti-feature A-2. It is the exact negation of the critical requirement. |

### What a verification run should report

Beyond pass/fail, model the report on `diff-hook` + diffoscope: **the difference must be legible, not just detected.** The output is a JSON document containing two arrays of ~8 signed wei integers plus two realized rates. A raw byte diff of that is nearly useless. A *numeric-aware* diff — "`dQx[5]` differs: stored `-2613128317657530400`, fresh `-2613128317657530784`, Δ = 384 wei ≈ 1 double-ulp at this magnitude" — tells you immediately whether you are looking at a decimal-emission ulp (expected per §3's "roundoff only at decimal emission") or a genuinely different member of the underdetermined path family (the CONOPT-version signature §3 warns about). Those two findings have completely different responses. This is the highest-value differentiator in the whole store and it is MEDIUM-HIGH complexity — flag it for its own scoping decision.

Also report, always: both content digests, both toolchain version strings, the key, and the run-log ids of both runs.

---

## Part 4 — Retention: pin, GC, reset

The cleanest model is **git's**, which happens to have all four of this milestone's non-cache requirements in one system:

| This project | git | Nix |
|---|---|---|
| content key → bytes | object database (SHA of content) | store path |
| pin | a ref (branch/tag) | a GC root under `/nix/var/nix/profiles` — *"Nix treats `/nix/var/nix/profiles` as a GC root"* |
| latest pointer | `refs/heads/<x>`, updated via lockfile + rename | the `result` symlink / profile generation symlink |
| run log | the reflog | profile generations |
| GC | `git gc --prune`, keeping everything reachable from refs **and from the reflog** | `nix-store --gc`, keeping everything reachable from roots |
| reset | `git reflog expire --expire=now --all` **then** `git gc --prune=now` | `nix-collect-garbage -d`: *"delete old generations of all profiles, then collect garbage"* |

Two structural lessons, both verified:

**R1 — The run log is itself a retention root.** In git, *"an unreachable commit is never pruned as long as it is in a reflog"*; `gc --auto` runs `git reflog expire` first, honouring `gc.reflogExpire` (default 90 days) and `gc.reflogExpireUnreachable` (default 30 days), and `git gc` then calls `prune --expire 2.weeks.ago` (`gc.pruneExpire`) ([git-gc(1)](https://git-scm.com/docs/git-gc), [git-reflog(1)](https://git-scm.com/docs/git-reflog)). Applied here: **an entry referenced by a run-log row within the retention window must not be collected**, otherwise the chronology develops dangling references and the log stops being evidence. This is a real constraint on the GC query and it is easy to miss.

**R2 — Reset is a two-step, and the first step is the one that touches pins.** Nix's `-d` and git's reflog-expire-then-gc are the same shape: *un-root, then collect.* That decomposition is the answer to "what does reset mean when entries are pinned":

| Operation | Touches pins? | Semantics |
|---|---|---|
| `gc` | **No** | Evict unpinned, unreferenced-by-recent-log entries. Bounded by size and/or age — Bazel 7.4+ does exactly this for its disk cache via `--experimental_disk_cache_gc_max_size` and `--experimental_disk_cache_gc_max_age`, applying both criteria together, run in the background after `--experimental_disk_cache_gc_idle_delay` (default 5 min) ([Remote Caching](https://bazel.build/remote/caching)). Eviction order is LRU; ccache does approximate-LRU by mtime, and updates mtime on hit so a hit counts as a use. |
| `reset` | **No, by default — it *refuses* if pins exist** | Delete everything unpinned; report the count of pinned survivors and exit non-zero if any exist and `--force` was not given. |
| `reset --force` / `reset --all` | **Yes, explicitly** | Clear pins, *then* delete everything. Two verbs internally, one command externally, with the destructive one requiring the flag. |

`ccache -C` (clear the whole cache) versus `ccache -c` (cleanup to limits) is the same distinction with worse names. Use `reset` and `gc`.

**R3 — Latest is a pin.** Whatever the `latest` pointer references must be un-collectable, exactly as a git ref roots its commit. Otherwise a GC can delete the provenance of the fixture the forge test is currently reading. This is a dependency edge, not a nice-to-have.

---

## Part 5 — The run log

A content key carries no ordering, no causation, and no environment. The log carries all three. It is the **only** place the non-key context can live, which is what makes it structurally necessary rather than a convenience.

**Belongs in an append-only row (per PROJECT.md, extended):**

| Field | Why |
|---|---|
| `run_id` (monotonic), `started_at`, `finished_at` | chronology and duration; duration is what proves elision works |
| `key` (FK to the store, nullable on pre-key aborts) | the join |
| `outcome` ∈ {`hit`, `miss_solved`, `verified_match`, `verified_mismatch`, `abort_<named>`, `refused_infeasible`} | the state machine, one column |
| `next_tx_hash`, `block_number` | the chain provenance the key deliberately excludes; makes "which chain event caused this solve" answerable |
| `gams_version`, `conopt_version` | duplicated from the key **on purpose**: the log must stay readable after a key-scheme change |
| `exit_code`, `abort_reason` | §4 gates on exit code, never log text — the log records both but only the code is authoritative |
| `elided` (bool) + `solve_duration_ms` | the elision metric; without it "an identical shock skips the solve" is unmeasurable |

**Never in the log:** anything that gets updated. If a row is wrong, append a correcting row. Append-only is not a storage preference, it is what makes the log admissible — enforce it in the database (revoke UPDATE/DELETE on the table for the application role; a `BEFORE UPDATE OR DELETE ... RAISE EXCEPTION` trigger if role separation is not available). A log that *could* have been edited proves nothing about a determinism claim.

**How the two join:** one-to-many, log → store, never the reverse. The store row is immutable and does not know how many times it was hit; the log row references the key. Every useful question is a join in that direction: *"how many solves did we skip this week"* (count of `hit`), *"which chain event first produced this key"* (min `run_id` per key), *"has this key ever mismatched"* (exists `verified_mismatch`). The one field that legitimately lives on the store row as denormalised state is `pinned` — because it is a property of the entry, not of a run.

---

## Part 6 — Latest-pointer publication

The consumer is a forge test reading `test/models/mev_tax_model_one/fixtures/volume_path.json` — a file in **another track's tree**, read from a Solidity test via `vm.readFile`, while a resident loop republishes it.

**The mechanism (three patterns, ranked):**

1. **Write-temp-then-`rename(2)` in the same directory — REQUIRED, LOW complexity.** POSIX `rename` is atomic within a filesystem: a reader opening the path sees either the whole old file or the whole new file, never a truncated one. Writing in place (`open`/truncate/write) exposes a window where the test reads half a JSON document and fails with an unrelated parse error at 3am — the classic symptom. Same directory matters: `rename` across filesystems fails with `EXDEV` and the fallback copy is not atomic ([rename(2)](https://man7.org/linux/man-pages/man2/rename.2.html)).
2. **Symlink swap — only if done correctly.** `ln -sf` is **not atomic**: it calls `symlink`, `unlink`, `symlink`, leaving a window in which the path does not exist and readers get `ENOENT` ([Things UNIX can do atomically](https://rcrowley.org/2010/01/06/things-unix-can-do-atomically)). The correct form is `symlink` to a temp name then `rename` the *symlink* over the target — which is pattern 1 applied to a link. Given the consumer is a plain file read, a symlink adds an indirection with no benefit here. **Recommend a real file, not a symlink.**
3. **A pointer row in Postgres — REQUIRED for the history, not for the file.** A `latest(model, key, run_id, published_at)` row (or the max-`run_id` log row) is what makes "which key produced the fixture" answerable. MVCC gives readers a consistent snapshot with no torn state for free. This is git's refs-plus-reflog split: the ref is the pointer, the reflog is the history of what it pointed at. **Keep both**: the pointer row for the current answer, the log for the history. Do not implement "latest" as a bare `ORDER BY ts DESC LIMIT 1` view with no pointer row — that conflates "most recent run" with "most recently *published* run", and they differ the moment a verification run or an aborted run happens after a publish.

**Failure modes, concretely:**

| Failure | Cause | Fix |
|---|---|---|
| Test reads a truncated document | in-place write | temp + `rename` (pattern 1) |
| Test reads `ENOENT` intermittently | `ln -sf` unlink window | `rename` the symlink |
| Test passes against a fixture whose key nobody can name | no pointer row | pointer row + sidecar (below) |
| Fixture and pointer row disagree | file written outside the transaction | publish order: **commit the pointer row first, then rename the file**; a crash between them leaves the DB claiming a publish that the file does not show — recoverable by republishing from the stored bytes, which is idempotent. The reverse order leaves a file no row explains, which is not recoverable. |
| Git history churn / merge conflicts on another track's tree | resident loop committing every publish | see anti-feature A-11 |
| Test reads a fixture whose store entry was GC'd | latest not treated as a retention root | R3 |

**Provenance sidecar, and the conflict it resolves:** the published fixture should be traceable to its key, but **adding a `"key"` field to the JSON changes the bytes** — and those bytes are the object of the determinism guarantee. Injecting provenance in-band means the published file is no longer byte-identical to what the solver emitted, and any check comparing published-file-to-store now compares apples to oranges. **Resolve by sidecar**: publish `volume_path.json` byte-for-byte as stored, plus `volume_path.key` (or `.provenance.json`) alongside, atomically renamed in the same operation window. This is a genuine feature conflict and worth a REQ that names it.

---

## Feature Landscape

### Table Stakes (Users Expect These)

| ID | Feature | Why Expected | Complexity | Notes |
|---|---|---|---|---|
| F-01 | **Byte-exact artifact storage** (`bytea`/`text` + sha256; `jsonb` only as a derived projection) | The determinism guarantee is byte identity; a `jsonb` column cannot express it | **LOW** | Load-bearing. Part 0. Contradicts a literal reading of "Postgres/JSONB store" — settle in the schema phase |
| F-02 | **Canonical key preimage** — one renderer for argv and hash; exact-decimal wide integers; rationals as (numerator, declared scale); no float round-trip; no locale | Without it the key is unstable across runs/machines and the cache is either useless or wrong | **MEDIUM** | K1–K5. Testable: bytes hashed == bytes `execve`'d |
| F-03 | **Key scope**: seven inputs ‖ GAMS version ‖ CONOPT version ‖ model source digest; explicit exclusion list | Milestone definition + stale-hit prevention | **LOW-MEDIUM** | Model digest is an *addition* to PROJECT.md's stated key; recommend it |
| F-04 | **Lookup: hit elides the solve entirely** — no subprocess spawned on hit | The critical requirement, per the user | **LOW** | Testable by observation, not by log text: assert the subprocess was never spawned (call counter / process table), and assert `solve_duration_ms IS NULL` |
| F-05 | **Store-on-miss, gated on exit code** — non-zero exit ⇒ nothing stored, transactionally | §4: *"Exit code is non-zero on every abort — gate on it, never on log text"* | **MEDIUM** | A partially-written artifact must be impossible; wrap in one transaction, write the file only after commit |
| F-06 | **Append-only run log** with the Part 5 columns, UPDATE/DELETE denied at the database | A content key has no chronology; PROJECT.md requires it | **LOW-MEDIUM** | Enforce append-only in the DB, not in application discipline |
| F-07 | **Atomic latest publication** (temp + `rename(2)`, same directory) + pointer row | Downstream forge test reads it live | **LOW** | Publish order: pointer row committed, then rename |
| F-08 | **Pin / retain flag** | Explicit user requirement | **LOW** | Boolean on the entry + a pin/unpin verb; pinned entries survive gc and plain reset |
| F-09 | **Reset as its own operation**, distinct from gc, refusing over pins unless forced | Explicit user requirement | **LOW-MEDIUM** | Nix `-d` / git two-step. Semantics table in Part 4 |
| F-10 | **Toolchain version detection** feeding the key; refuse to run if undetectable | The key is meaningless without it; keying a placeholder is worse than failing | **MEDIUM** | Parse `gams` banner + CONOPT version; store the raw version strings, not a normalised form |
| F-11 | **Hit/miss statistics and a `why-miss` explanation** | "Why did it re-solve?" is otherwise unanswerable and elision becomes unfalsifiable | **MEDIUM** | ccache `-s` / Gradle task-inputs-comparison. Minimum viable: report which key component differed from the nearest stored key |

### Differentiators (Competitive Advantage)

| ID | Feature | Value Proposition | Complexity | Notes |
|---|---|---|---|---|
| F-12 | **`verify <key>` — re-solve and compare bytes; mismatch is a hard failure** | Turns §3's prose into a standing falsifiable check. This *is* the milestone's thesis | **MEDIUM** | Nix `--check`: exit 1, original kept, divergence reported |
| F-13 | **Quarantine of divergent bytes** — original row immutable, divergent artifact preserved with both digests, joined to the log | Nix's `--check` discards the divergent build by default and that is the part people regret; rebuilderd keeps it | **MEDIUM** | The evidence is the deliverable. Depends on F-01 + F-12 |
| F-14 | **Numeric-aware diff report** — per-field / per-array-index difference with ulp magnitude | Distinguishes "decimal-emission ulp" (expected, §3) from "different path-family member" (a CONOPT-version signature). Byte diffs cannot | **MEDIUM-HIGH** | The one feature worth its own scoping decision. diffoscope is the archetype |
| F-15 | **Verification triggers: on-toolchain-change + sampled + scheduled** | Continuous coverage without paying re-solve cost on the hot path | **MEDIUM** | Nix removed always-on `--repeat`; do not reinvent it |
| F-16 | **Single-flight on cold keys** (`pg_advisory_xact_lock` on the key hash) | The resident loop plus a manual run will collide; without it, two GAMS processes solve the same shock and race to insert | **MEDIUM** | Note the `INSERT … ON CONFLICT DO NOTHING RETURNING` trap: it returns **no row** on conflict, so the loser needs a follow-up SELECT. Also: advisory locks + PgBouncer transaction pooling interact badly — use `pg_advisory_xact_lock` (transaction-scoped), never the session-scoped variant |
| F-17 | **GC with pin-, latest-, and recent-log-reachability** | Unbounded growth otherwise; and naive GC creates dangling log references | **MEDIUM** | Bazel 7.4 disk-cache GC (max-size **and** max-age together) + git's reflog-as-root rule (R1) |
| F-18 | **Latest-pointer history** (every publish appended, not overwritten) | Answers "which key produced the fixture the test read at commit X" | **LOW-MEDIUM** | git refs + reflog. Falls out of F-06 nearly free |
| F-19 | **Provenance sidecar** (`volume_path.key` beside the fixture) | Traceability without perturbing the bytes under guarantee | **LOW** | Resolves a real conflict — see Part 6 |
| F-20 | **Negative caching of the *closed-form* aborts only** | An infeasible shock re-solved is as wasteful as a feasible one; §1.2/§1.3 gates are pure algebra and deterministic | **MEDIUM** | **Do not** negative-cache CONOPT's `Locally Infeasible` — §1.4 makes it a solver-behaviour verdict, i.e. version-dependent. Dovetails with the fee splitter's "proved feasible before GAMS is invoked" |

### Anti-Features (Commonly Requested, Often Problematic)

| ID | Feature | Why Requested | Why Problematic | Alternative |
|---|---|---|---|---|
| A-1 | **Auto-heal: overwrite the stored bytes on mismatch** | "The new run is more current" | Destroys the only evidence of the only finding the store exists to produce. This is literally Bazel's ActionCache last-write-wins behaviour, and it is why Bazel cache poisoning is hard to detect | First-writer-wins + quarantine (F-13). Mutation of a stored artifact is never correct |
| A-2 | **Verify on every cache hit** | "Then we'd always know" | Exactly negates the critical requirement — nothing is ever elided. Nix shipped this as `--repeat`/`enforce-determinism` and **removed both in 2.13 as long-broken** | Explicit + on-toolchain-change + sampled (F-15) |
| A-3 | **Fuzzy / nearest-neighbour key matching** ("round the shock inputs, reuse a close solve") | Higher hit rate on jittery live pool state | A "hit" stops meaning "these bytes are what the solver would produce". The store silently becomes an interpolator, and the determinism check becomes meaningless because the compared runs had different inputs | Exact keys. If input jitter is genuinely a problem, quantise the *inputs* explicitly and visibly upstream, so the quantised value is the real input and the key is still exact |
| A-4 | **Tolerance-based comparison** ("equal within 1e-12") | §3 already quotes tolerances (1e-10 on rates, 400 wei closure), so tolerance feels native | Those tolerances are the *solver's* certification of its own output (§4 post-solve gates). Using one as the cache's identity predicate launders a real non-determinism into a pass. Byte identity is the claim; weaken it and there is no claim | Byte identity is the store's predicate, full stop. A tolerance comparison is a **separate, additional** assertion with its own name, run against the numbers — never a relaxation of the identity check |
| A-5 | **Anything ambient in the key** (wall clock, hostname, PID, run counter, absolute paths, block number, tx hash) | "More provenance is better" | Hit rate → 0; the store becomes a write-only log with extra steps. The symmetric error — omitting the model source digest — gives silent stale hits | Ambient context lives in the run log (F-06). That is the log's entire justification |
| A-6 | **`jsonb` as the artifact column** | It is in the milestone title; it queries beautifully | Cannot express byte identity: whitespace, key order, and `E`-notation are all normalised away (Postgres docs, quoted in Part 0) | `bytea`/`text` source of truth + `jsonb` derived projection (F-01) |
| A-7 | **Mutable / "correctable" run log** | "That row was wrong, let me fix it" | A log that could have been edited proves nothing; the chronology is evidence or it is decoration | Append a correcting row; deny UPDATE/DELETE at the database |
| A-8 | **`ln -sf` symlink for `latest`, or an in-place file write** | It is one line | `ln -sf` is unlink-then-symlink — readers hit `ENOENT` in the window. In-place writes expose truncated JSON. Both fail intermittently under a resident loop, which is the worst debugging shape | temp + `rename(2)`, same directory (F-07) |
| A-9 | **Generic multi-model / multi-solver plugin framework now** | The layout is already `<model>/<key>`; "let's make it pluggable" | One tenant exists. A plugin abstraction designed against one example encodes that example's accidents as interfaces, and the second tenant breaks them | Model-agnostic **table layout** (a `model` column), model-**specific** code. PROJECT.md already says this: *"only the `volume_path` tenant is built"* |
| A-10 | **TTL / time-based invalidation of entries** | Habit from ordinary caches | Content-keyed entries do not go stale with time — they go stale when the toolchain or model changes, and both are in the key. A TTL discards free evidence and reintroduces a "stale" state the key design eliminated | Size- and count-bounded GC (F-17). Age as a *capacity* heuristic (Bazel's `max_age`) is fine; age as *invalidation* is not |
| A-11 | **Resident loop auto-commits every published fixture to git** | "The fixture is a tracked file, so it should be tracked" | The loop republishes continuously; that is a commit storm in another track's tree, with guaranteed merge conflicts and a history that hides real fixture changes | Publish to the working tree; commit deliberately (human or a single CI step). PROJECT.md already fences the territory: *"the only thing written into `test/` is the latest fixture copy"* |
| A-12 | **Storing the GAMS `.lst` listing inside the compared artifact** | "Keep everything about the run" | The listing contains timestamps, paths, and elapsed times — it can never be byte-stable, and including it makes every verification fail | Store the listing in a **separate**, explicitly-not-compared column keyed to the *run*, not the artifact |
| A-13 | **Trusting the solver's stdout/log text to classify aborts** | The abort names in §4 are right there in the log | §4 is explicit: *"gate on it, never on log text"*. Log text is not a stable interface and a locale or verbosity change silently reclassifies failures | Exit code is authoritative (F-05); the abort reason string is recorded as advisory metadata only |

---

## Feature Dependencies

```
F-02 canonical key preimage
  └──required-by──> F-03 key scope
        └──required-by──> F-04 lookup / elision
              └──enhanced-by──> F-16 single-flight
              └──required-by──> F-05 store-on-miss
                    └──required-by──> F-20 negative cache (closed-form aborts only)

F-01 byte-exact storage
  └──required-by──> F-12 verify
        └──required-by──> F-13 quarantine
              └──enhanced-by──> F-14 numeric-aware diff
        └──required-by──> F-15 verification triggers
F-10 toolchain detection
  └──required-by──> F-03 key scope
  └──required-by──> F-15 (on-toolchain-change trigger)

F-06 append-only run log
  └──required-by──> F-07 latest publication      (which run is "newest" is a log fact)
  └──required-by──> F-11 statistics
  └──required-by──> F-18 latest-pointer history
  └──required-by──> F-17 GC                       (recent-log rows are retention roots, R1)

F-08 pin
  └──required-by──> F-09 reset      (reset is defined by what pins survive)
  └──required-by──> F-17 GC
F-07 latest ──is-a-retention-root-for──> F-17 GC   (R3)

F-19 provenance sidecar ──conflicts-with──> in-band provenance field
F-12 verify             ──conflicts-with──> A-2 verify-on-every-hit  (and with F-04 if unbounded)
F-04 elision            ──conflicts-with──> A-3 fuzzy matching
```

### Dependency Notes

- **F-12 requires F-01:** you cannot compare bytes you did not keep. If the schema phase lands `jsonb`-only, the verification phase is unimplementable as specified and will quietly degrade to a normalised comparison. This is the single most important ordering constraint in the milestone: **F-01 must be decided in the earliest schema work, not in the verification phase.**
- **F-03 requires F-10:** the key cannot be computed before the toolchain versions are known, which means the GAMS invocation layer's version detection is a *prerequisite of the store*, not a peer of it — even though PROJECT.md lists the GAMS layer after the store. Either the version detection moves earlier, or the store phase ships with a stub key and a re-key migration, which is the worse option (K5).
- **F-07 requires F-06:** "newest" is a chronology question and the content key has no chronology — that is the stated reason the log exists. Publishing without the log means "newest" is whatever the filesystem mtime says, which is not durable.
- **F-17 requires F-06, F-08, and F-07:** the GC's reachability predicate is `pinned OR referenced-by-latest OR referenced-by-a-log-row-within-window`. Getting this wrong in either direction is bad: too aggressive gives dangling log references (the git reflog-as-root lesson), too conservative gives unbounded growth.
- **F-09 requires F-08:** reset's whole semantic content is "what survives", and pins are the answer.
- **F-13 conflicts with A-1:** they are the two branches of the same decision. Choosing quarantine means committing that a stored artifact is *never* mutated — worth stating as an invariant a test asserts (attempt an overwrite, assert it is rejected).
- **F-19 conflicts with in-band provenance:** injecting the key into the published JSON changes the bytes the guarantee covers. Sidecar or nothing.
- **F-16 enhances F-04 and is nearly required by the resident loop:** a continuously-solving loop plus any manual invocation is a guaranteed collision. Without single-flight the observable symptom is two GAMS processes on the same shock and an insert race — which, if F-05's transaction is right, is harmless-but-wasteful, and if it is not, is a partial write.

---

## MVP Definition

### Launch With (v1) — maps to the six approved phases

- [ ] **F-01 byte-exact storage** — the verification feature is unimplementable without it; LOW cost, earliest phase *(schema/foundation phase)*
- [ ] **F-02 + F-03 canonical key** — the definition of the deliverable *(store phase, but needs F-10 from the GAMS phase; resolve the ordering)*
- [ ] **F-04 elision** — the user called this critical *(store phase)*
- [ ] **F-05 exit-code-gated store-on-miss** — §4's binding rule *(store + GAMS phases)*
- [ ] **F-06 append-only run log** — explicit requirement, and three other features depend on it *(store phase)*
- [ ] **F-08 pin + F-09 reset** — explicit requirements, both LOW *(store phase)*
- [ ] **F-10 toolchain detection** — prerequisite of F-03 *(GAMS phase, or earlier)*
- [ ] **F-12 verify (explicit command) + F-13 quarantine** — this is the milestone's thesis; explicit-trigger-only is the minimum honest version *(store or verification phase)*
- [ ] **F-07 atomic publication + F-19 sidecar** — LOW cost, and the failure mode without it is intermittent and expensive to diagnose *(resident-loop phase)*

### Add After Validation (v1.x)

- [ ] **F-11 statistics / why-miss** — trigger: the first time someone asks "why did it re-solve?" and cannot answer. Expect this within days of the resident loop running
- [ ] **F-16 single-flight** — trigger: the resident loop lands, or the first observed duplicate solve
- [ ] **F-15 on-toolchain-change verification** — trigger: the first GAMS or CONOPT bump. §3 predicts the path-family member may change; capture that measurement when it happens
- [ ] **F-18 latest-pointer history** — trigger: the first "which key produced this fixture?" question
- [ ] **F-14 numeric-aware diff** — trigger: the first real mismatch. Until one occurs, a byte-inequality plus both digests is enough; after one, a byte diff of a float array is nearly useless

### Future Consideration (v2+)

- [ ] **F-17 GC** — defer: solve counts are small and artifacts are ~KB; unbounded growth is not a near-term risk, and a GC written before the retention roots are settled (F-06/F-07/F-08 all in place) will get the reachability predicate wrong
- [ ] **F-20 negative caching** — defer: the fee splitter already proves feasibility in closed form *before* GAMS is invoked, so the expensive infeasible path is largely pre-empted. Revisit if aborts turn out to be common
- [ ] **F-15 sampled/scheduled verification** — defer: `make test-gams` already runs a determinism double-run (§5); wire it to the store before building a sampler
- [ ] **A-9 multi-model abstraction** — defer indefinitely; PROJECT.md already scopes it out

---

## Feature Prioritization Matrix

| ID | Feature | User Value | Implementation Cost | Priority |
|---|---|---|---|---|
| F-01 | Byte-exact storage | HIGH | LOW | **P1** |
| F-02 | Canonical key preimage | HIGH | MEDIUM | **P1** |
| F-03 | Key scope (+ model digest) | HIGH | LOW-MEDIUM | **P1** |
| F-04 | Hit elides the solve | HIGH | LOW | **P1** |
| F-05 | Exit-code-gated store-on-miss | HIGH | MEDIUM | **P1** |
| F-06 | Append-only run log | HIGH | LOW-MEDIUM | **P1** |
| F-07 | Atomic latest publication | HIGH | LOW | **P1** |
| F-08 | Pin / retain | MEDIUM | LOW | **P1** |
| F-09 | Reset as its own operation | MEDIUM | LOW-MEDIUM | **P1** |
| F-10 | Toolchain version detection | HIGH | MEDIUM | **P1** |
| F-12 | Verify (explicit) | HIGH | MEDIUM | **P1** |
| F-13 | Quarantine divergent bytes | HIGH | MEDIUM | **P1** |
| F-19 | Provenance sidecar | MEDIUM | LOW | **P1** |
| F-11 | Statistics / why-miss | MEDIUM | MEDIUM | P2 |
| F-16 | Single-flight | MEDIUM | MEDIUM | P2 |
| F-15 | On-toolchain-change verification | MEDIUM | MEDIUM | P2 |
| F-18 | Latest-pointer history | MEDIUM | LOW-MEDIUM | P2 |
| F-14 | Numeric-aware diff report | HIGH (on first mismatch) | MEDIUM-HIGH | P2 |
| F-17 | GC of unpinned entries | LOW (near term) | MEDIUM | P3 |
| F-20 | Negative caching of closed-form aborts | LOW | MEDIUM | P3 |

---

## Competitor Feature Analysis

| Feature | ccache | Bazel / RBE | Nix | git | **Our approach** |
|---|---|---|---|---|---|
| Key model | preprocessed source + argv + compiler mtime/size | action digest: command + args + env + input Merkle tree | derivation hash (recipe, transitive) | SHA of content | seven inputs ‖ GAMS ver ‖ CONOPT ver ‖ model digest, keyed as exact argv bytes |
| Toolchain in key | yes, via mtime/size by default (`CCACHE_COMPILERCHECK`) | only if declared as an input (undeclared = poison) | yes, transitively | n/a | yes, as **version strings** — the unit §3's guarantee is written in |
| Mismatch policy | never checks | last-write-wins on ActionCache; detect out-of-band by execution-log diff | `--check`: exit 1, keep original, `diff-hook`; CA derivations refuse a conflicting realisation | n/a (key *is* content) | **first-writer-wins + quarantine + non-zero exit** (Nix + rebuilderd) |
| Determinism verification | none | none built in (**no repeat-and-compare flag exists**) | `--check` on demand; `--repeat`/`enforce-determinism` **removed in 2.13 as long-broken** | n/a | explicit `verify`, plus on-toolchain-change; never on every hit |
| Divergent bytes kept? | n/a | both live in the CAS incidentally | only with `--keep-failed` → `.check` path, itself GC-able | n/a | **always**, in a quarantine table joined to the log |
| Pinning | none | none | GC roots / profiles | refs | `pinned` flag + latest as an implicit root |
| GC | approximate-LRU by mtime; mtime touched on hit | 7.4+: `--experimental_disk_cache_gc_max_size` + `_max_age`, both criteria, background after `_idle_delay` (5 min) | reachability from roots | reachability from refs **and reflog** (`gc.reflogExpire` 90d, `gc.pruneExpire` 2w) | reachability from pins + latest + recent log rows |
| Reset | `ccache -C` (clear) vs `-c` (cleanup) | manual | `nix-collect-garbage -d`: delete generations, **then** collect | `reflog expire --expire=now` **then** `gc --prune=now` | `reset` (refuses over pins) / `reset --force` (clears pins, then deletes) / `gc` (never touches pins) |
| Chronology | none | build event stream | profile generations | reflog | append-only run log, DB-enforced |
| Latest pointer | n/a | n/a | profile symlink, atomic swap | ref, lockfile + rename | file via `rename(2)` + pointer row + log history |

---

## Open Questions / Gaps

1. **"Two of the inputs are rationals" (from the research brief) does not match `VOLUME_PATH.md` §2**, which lists **three** pips-scaled rationals (`txlVolumeRate`, `phiXpips`, `phiMpips`) and four integers, of which three (`sqrtPriceX96`, `liquidityRaw`, `volTgtWad`) exceed binary64 exact range. The canonicalisation rule (K3) is the same either way, but the requirements step should reconcile the count before writing a REQ that enumerates them.
2. **§6 open ruling 2 — the pips denominator (1e6) — is unresolved and is a key-stability risk.** Changing the denominator later reinterprets every stored key without changing any key's bytes. Recommend pinning it, or encoding the denominator explicitly in the key preimage, before the first key is minted.
3. **§6 open ruling 1 — production `nEvents`** (fixture 8). `nEvents` is in the key, so changing it is a clean miss rather than a hazard — but a change invalidates the entire store, which is a scoping fact worth stating.
4. **Whether the model source digest enters the key** is a recommendation from prior art (Bazel, Nix), not a requirement stated in PROJECT.md. It needs a decision. Without it, editing `volume_path.gms` produces silent stale hits.
5. **The GAMS-layer-before-store ordering tension** (F-03 requires F-10) is not resolved here; it is a roadmap-sequencing decision.
6. **Concurrency shape of the resident loop is unspecified** — how many solvers, whether manual invocations coexist. That determines whether F-16 single-flight is P1 or P2. Currently placed at P2 on the assumption of a single loop.
7. **Not researched:** Haskell library choices (`postgresql-simple` vs alternatives), migration tooling, and the `bytea`-vs-large-object threshold — those are STACK.md/ARCHITECTURE.md territory. Artifact size (~8-element arrays, low KB) makes `bytea` unambiguously fine.

---

## Sources

**Primary documentation (HIGH confidence)**
- PostgreSQL — JSON Types: https://www.postgresql.org/docs/current/datatype-json.html *(json vs jsonb text preservation — quoted verbatim)*
- Nix Reference Manual — Verifying Build Reproducibility (`--check`, `diff-hook`, `--keep-failed`, `.check` paths): https://nix.dev/manual/nix/2.25/advanced-topics/diff-hook
- Nix Reference Manual — Release 2.13 notes (`--repeat` / `enforce-determinism` removed): https://nix.dev/manual/nix/2.34/release-notes/rl-2.13.html
- Nix Reference Manual — `nix-collect-garbage` / Garbage Collection: https://nix.dev/manual/nix/2.34/command-ref/nix-collect-garbage
- ccache manual (input hash, `CCACHE_COMPILERCHECK`, direct vs preprocessor mode, approximate-LRU): https://ccache.dev/manual/latest.html
- Bazel — Remote Caching (disk cache GC flags, 7.4+): https://bazel.build/remote/caching
- Bazel — Debugging Remote Cache Hits (`--execution_log_compact_file`): https://bazel.build/remote/cache-remote
- git-gc(1): https://git-scm.com/docs/git-gc  ·  git-reflog(1): https://git-scm.com/docs/git-reflog
- rename(2) — Linux manual page: https://man7.org/linux/man-pages/man2/rename.2.html
- RFC 8785 — JSON Canonicalization Scheme: https://datatracker.ietf.org/doc/rfc8785/

**Secondary / corroborating (MEDIUM confidence)**
- EngFlow — The Many Caches of Bazel (action key composition): https://blog.engflow.com/2024/05/13/the-many-caches-of-bazel/
- Tweag — Implementing a content-addressed Nix (conflicting realisations): https://www.tweag.io/blog/2021-12-02-nix-cas-4/
- NixOS RFC 0062 — Content-addressed paths: https://github.com/NixOS/rfcs/blob/master/rfcs/0062-content-addressed-paths.md
- bazelbuild/bazel#14543 — actions cached as successful without producing outputs (cache poisoning): https://github.com/bazelbuild/bazel/issues/14543
- Develocity — Diagnosing Build Cache misses with task inputs comparison: https://docs.gradle.com/enterprise/tutorials/task-inputs-comparison/
- Reproducible Builds — Tools (diffoscope, rebuilderd, attestations): https://reproducible-builds.org/tools/
- Richard Crowley — Things UNIX can do atomically (`ln -sf` is not atomic): https://rcrowley.org/2010/01/06/things-unix-can-do-atomically.html

**Project-internal (binding, consumed not re-derived)**
- `model/mev_tax_model_one/VOLUME_PATH.md` §§1–6 — seven inputs, output shape, precision and determinism guarantees, named aborts, build/CI, open rulings
- `.planning/PROJECT.md` — Current Milestone v6.0 target features and territory fence

**Explicit negative finding (MEDIUM-HIGH confidence)**
- Bazel `--experimental_repeated_by` — **searched and not found** in Bazel's command-line reference, `bazel_flags.proto`, or release notes. Bazel appears to have no repeat-and-compare build flag; `--runs_per_test` repeats tests without comparing outputs. Any requirement citing this flag should be rewritten against execution-log diffing.

---
*Feature research for: keyed / content-addressed artifact store with cache elision and determinism verification*
*Researched: 2026-08-16*
