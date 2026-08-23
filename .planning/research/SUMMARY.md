# Research Summary — Milestone v6.0

**Model Output Store + VolumePath Bridge (rpc_api workstream)**
Synthesized 2026-08-16 from STACK.md, FEATURES.md, ARCHITECTURE.md, PITFALLS.md.

> Replaces a stale v4.0-era SUMMARY.md (plank `VolOrderManagerMod` milestone, 2026-07-19).
> If anything downstream cites "SUMMARY.md" with a July date, it is reading the wrong file.

---

## The one finding that reshapes the milestone

**`jsonb` cannot carry a byte-identity guarantee, and `PROJECT.md` as written asked it to.**

Confirmed three times independently — from the Postgres docs, and by live measurement on
PG 18 and PG 18.4:

```
raw   bytea = {"z_last":1,"a_first":2,  "dup":1, "dup":3}
jsonb text  = {"dup": 3, "z_last": 1, "a_first": 2}
BYTE-IDENTICAL? False
```

`jsonb` does not preserve whitespace, key order, or duplicate keys, and re-renders numbers
through `numeric`. A determinism check reading a `jsonb` column tests **Postgres's
normalizer, not GAMS** — it would pass on real non-determinism. That is the milestone's
headline guarantee, silently voided.

**Resolution:** `output_bytes bytea` is authoritative (digested, compared, published);
`output_jsonb` is a **derived projection**, for querying only. Cheap — but it must land in
the earliest schema, because everything downstream consumes it.

### The same hazard, one layer up

`aeson`'s `decode → encode` is **not the identity** at GHC 9.10.3 — measured against this
project's own build plan, four mutations in one round-trip, including
`0.00318353 → 3.18353e-3` (aeson *introduces* exponent notation) and `2.8e19 →
28000000000000000000`.

So the prover's bytes must never pass through `Data.Aeson.Value` at all. That **rules out
reusing `Driver.Capture.write_json_atomically`** on the publication path — the helper this
workstream already trusts for committed artifacts is the wrong tool for this one.

Note `aeson` and `jsonb` normalize in **opposite directions**, so three mutually
incompatible canonical forms sit between the solver and the forge test.

### And a correctness bug waiting in the consumer

Decoding `dQx` as `[Double]` **loses 32 wei on the first element**. The forge test would
execute the wrong amounts. `[Integer]` is exact. Non-negotiable.

---

## Stack decision

**`postgresql-simple` 0.7.0.1.** The briefing premise — "several candidates lag on new
GHC" — was **wrong**: all six candidates compile clean on GHC 9.10.3. The decision had to
be made on footprint and fit, measured by `plan.json` set-diff against the real
152-package baseline:

| Candidate | New packages |
|---|---|
| **postgresql-simple** | **+4** |
| opaleye | +7 |
| hasql trio | +18 (+22 with `hasql-th`) |
| beam | +29 |
| persistent / +esqueleto | +43 / +44 |

Full recommendation (client + migrations + subprocess + hashing) = **+9 packages**.
`hasql` is a strong runner-up — better JSONB codecs, first-party pooling — losing on 4.5×
dependencies and ceremony, not merit. `persistent` is the worst fit (mandatory TH, drags
`monad-logger`/`conduit`/`blaze-html`).

**Hashing is free:** `crypton-1.0.6` is *already resolved* via `web3-crypto` (+0 packages).
`cryptonite` is deprecated (last upload 2022-03-13).

**Two hidden pins found:** `web3-crypto` caps `crypton <1.1` **and `aeson <2.3`**. Any
future dependency wanting `aeson >=2.3` will conflict.

---

## Key design

All seven inputs are **integers on the wire**; the floats (`deltaRealized`, `rPhiRealized`)
are outputs, not key material. So the canonical-serialization problem is far smaller than
it first appears.

**RFC 8785 (JCS) is the wrong tool** — it mandates numbers be IEEE-754 double-expressible,
and three inputs exceed binary64 (`sqrtPriceX96` uint160, `liquidityRaw` uint128,
`volTgtWad` wei; §3 already measured 2⁶⁴ printing 384 wei off).

**Recommended:** one renderer feeds both `execve` argv and the hash preimage, so
key/invocation agreement is **structural, not asserted** — you cannot have hashed something
other than what you ran. Riders:

- normalize at the edge (`28e18` → `28000000000000000000`) once, never between uses;
- **frame the fields** — unframed `H(a‖b‖c)` admits collisions;
- put the **pips denominator** in the preimage (§6 open ruling 2 is unresolved; if it
  changes later, every stored key means something different *without any key's bytes
  changing*).

**The key omits the model source.** Edit `volume_path.gms` and every existing key still
hits, silently, forever. Add `model_source_digest` and `solver_options_digest`, and a
`key_scheme` column **inside the unique constraint** so a future key-formula change
*orphans* rows rather than *corrupting* them. Cheapest insurance in the milestone.

---

## Cache and verification policy

Prior art disagrees, and the disagreement is informative: ccache never checks; Bazel's
ActionCache is last-write-wins (which is *why* poisoning is hard to find there); Nix keeps
the original and errors; Nix CA-derivations refuse a conflicting realisation outright;
rebuilderd publishes the disagreement as data.

**Nix shipped always-verify and deleted it** — `--repeat` and `enforce-determinism` were
removed in 2.13 (2023-01-17) as "broken under many circumstances for a long time." What
survived is on-demand `--check`: exit 1, keep the original, discard the divergent build.

**Recommended:** first-writer-wins, non-zero exit on mismatch, and **quarantine** the
divergent bytes rather than discard them — a mismatch becomes evidence instead of a lost
artifact. Verification is on-demand, not on every hit; always-verify defeats the cache
elision that motivated the store.

**Correction to the brief:** Bazel's `--experimental_repeated_by` **does not exist** —
absent from the flag reference, `bazel_flags.proto` and release notes. Bazel has no
repeat-and-compare build flag; its real workflow is out-of-band execution-log diffing.

---

## Architecture decisions

- **Module shape:** the `{Types,Encoding,Decode,Rpc}` template is *not* this repo's actual
  convention — `Rig.Manifest` and `Driver.Capture` already use role-named modules. The
  invariant to preserve is **one IO edge per area**.
- **Testing:** three tiers, and **Postgres is never a `cabal test` dependency** — pure
  checks, `Store.Laws` against an in-memory store, plus a committed conformance artifact
  (the `driver-run-capture.json` pattern applied to a DB). `tmp-postgres` **rejected**: it
  shells out to `initdb`/`pg_ctl`, and this machine has client-only Postgres.
- **Polling is forced, not chosen.** `eth_subscribe` is not in the Eth API surface and
  `jsonrpc-tinyclient` is structurally request/response. The loop is a watermark-driven
  fold.
- **`ExceptT` rejected.** `runWeb3'` catches only `Web3Error`, which `web3-ethereum`
  **never constructs** (0 occurrences in `src/`); real failures throw `JsonRpcException` or
  `IOException`, neither caught. Its `Left` branch is unreachable — the handlers at
  `offchain/app/Main.hs:235` and `offchain/lib/VolOrder/Rpc.hs:279` are **dead code**.
  Adding `ExceptT` would advertise a guarantee the runtime does not provide, which is the
  advertised-but-dead class the suite already guards against.
- **Build order:** the byte-reproduction proof lands with **no chain and no upstream**.
  Do not sequence it behind the Anvil phase.

---

## Library warts that bite silently

| Wart | Why it is dangerous |
|---|---|
| `ToField ByteString` sends a **quoted text literal**, not `bytea` | The `Binary` newtype is required. Types line up; **nothing complains at compile time**. |
| `postgresql-simple` `?` vs `??` depends on **which function** | `query`/`execute` need `??`; `query_`/`execute_` pass SQL verbatim and need `?`. Wrong form throws `operator does not exist: jsonb ?? unknown`. `@>` and `->>` unaffected. |
| `postgresql-migration` **exits 0** on checksum mismatch | Returns `MigrationError "Checksum mismatch"` and the process still exits 0. The caller must pattern-match and `exitFailure`. |
| `typed-process` timeout | **Verified from source**: `readProcess = bracket (startProcess …) stopProcess`, so `timeout` does terminate the child, and it returns exactly the `(ExitCode, stdout, stderr)` triple §4 needs. |

---

## GAMS reality check

**Exit code `0` means "GAMS ran", not "the model solved."** GAMS's own docs: *"the model may
have been infeasible or may have failed in another way while the return code says all is
fine."* So `VOLUME_PATH.md` §4's "gate on exit code" is a property of **`volume_path.gms`'s
abort coverage**, not of GAMS — and that file is under active development in another
worktree.

Measured here at 54.1 with `action=ce`: exit codes 0/2/3, so the `Makefile` comment that
"`gams` exits 0 even on compile errors" is **not reproducible**. The residual gap is
exit-0-with-no-output, closed by an **absence-of-artifact** test rather than log parsing.

**No wrapping landmine:** `volume_path.gms:202` sets `fj.pw = 4000` explicitly, not the
255 default. Bound worth recording: `dQx` elements are ~22 chars, so the line wraps around
**N ≈ 180 events**. `nEvents` defaults to 8; §6 open ruling 1 ("production `nEvents`") must
stay under that.

**`volTgtWad` is a GAMS `Scalar`** (double), defaulting to `28e18` = 2.8e19 — past 2⁵³, so
not exactly representable, which is exactly why §3 documents ~128–512 wei granularity.

---

## Six pitfalls that are reincarnations of this repo's recurring defect class

The class — *an assertion that passes when its subject is absent* — was found six times
across three review rounds, each after the previous sweep was declared complete. It has
six new homes here:

1. an emptily-succeeding `gams --version` parse (`"" == ""`, verbatim);
2. `nEvents` absent → `0` before hashing (`tickSpacing = 0`, one type over);
3. a determinism check that compares a cached row **to itself** (the tautology);
4. DB tests that **skip** when Postgres is absent (`grep -q` over an empty log);
5. GAMS exit code `0`;
6. unframed `H(a‖b‖c)` concatenation collisions.

Every one must be answered with a check that fails loudly on absence, not one that reads
nothing and reports clean.

---

## Environment

- **No Postgres server on this machine** — `psql`/`createdb`/`pg_isready` present;
  `postgres`/`initdb`/`pg_ctl` absent; nothing listening on 5432.
- **Docker 29.5.2 works**; `postgres:18-alpine` was ready in 3 seconds.
- Recommended: GH Actions `services:` container — with the caveat that on a
  *non-containerized* self-hosted runner you must map ports to localhost.
- **The `haskell` gate job has never executed** (v5.0 merged `--admin`), so its first run
  debuts both the gate itself and the Postgres wiring.

---

## Open questions carried into requirements

1. **CONOPT version detection has no clean method.** `gams --version` does not report it;
   the only obvious source is listing/log text, which §4 forbids gating on. Phase 3 must
   settle this — and it feeds the key.
2. **Is `VOLUME_PATH.md` §3's example JSON byte-accurate?** The prover emits
   `deltaRealized` via `dReal:0:10` (ten decimals) while §3 shows `0.49`. Unverified.
   One prover run against the scratch directory would settle this, the trailing newline,
   exit-code behaviour and CONOPT detection at once.
3. **Does the `volume_path.gms` source digest enter the key?** Prior-art recommendation,
   not a stated requirement. Without it, editing the model gives silent stale hits.
4. **The resident loop's concurrency shape** decides whether single-flight is P1 or P2.
5. Whether GH Actions `services:` containers work on the `cfmm-build` executor was not
   verified; the per-run-database recommendation was chosen partly because it does not
   depend on the answer.
