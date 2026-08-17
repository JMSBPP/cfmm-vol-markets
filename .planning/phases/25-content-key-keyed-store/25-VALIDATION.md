---
phase: 25
slug: content-key-keyed-store
status: ready
nyquist_compliant: true
wave_0_complete: true
created: 2026-08-17
---

# Phase 25 — Validation Strategy

> **Authoritative source:** `25-RESEARCH.md` `## Validation Architecture` — a 48-row
> requirement→test map (all fourteen IDs plus inherited KEY-07) and a 50-row guard→firing-input
> table. Every row it marks MEASURED was captured on this machine.
>
> The **Per-Task Verification Map** below is filled after `gsd-planner` runs, since task IDs do not
> exist yet. It is marked pending rather than left with template placeholders — phase 24 shipped
> an unpopulated template and the plan checker correctly blocked on it.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | **None, by design.** Hand-rolled `exitcode-stdio-1.0` runner in `offchain/test/Main.hs`; every check runs, non-zero exit if any fails |
| **Config file** | `cfmm-replicationPlank-rpc-api.cabal` |
| **Registration point** | `core_checks` — **a check not in this list does not exist** |
| **Quick run** | `cabal build --enable-tests -j all` |
| **Full suite** | `cabal test` |
| **Baseline (measured cold 2026-08-17)** | **151/151**, wall **152.9 s** |
| **Runtime budget** | **900 s ceiling.** Record wall before/after. The sentinel harness pays each added check ~**3828** times. **Extend `store-conformance.json` (+22 leaves ≈ +0.2 s) rather than add a seventh swept artifact (+19 s).** |
| **Hard gates** | zero `-Wall` warnings; **`cabal build -j all` WITHOUT `--enable-tests` is VACUOUS** and never counts |
| **Chain / DB / GAMS** | **NONE of the three inside `cabal test`.** No row in the req→test map needs a DB or GAMS. Both structural greps stay **0** |
| **New test file** | **None.** One file, one runner |

### Tiers

- **A — pure.** Framing, edge normalization, preimage construction, refusal predicates.
- **B — stubs + `Store.Memory`.** The store contract executed for real; `Gams.Run` driven against
  shell stubs. This is where cache elision and the echo cross-check actually discriminate.
- **C — committed capture.** Assertions over `store-conformance.json`, captured out of band.

---

## Sampling Rate

- **Per task:** `cabal build --enable-tests -j all` (zero warnings), then `cabal test`.
- **Per wave:** the above plus that wave's named guard firings demonstrated verbatim.
- **Phase gate:** FAIL 0; both structural greps 0; every added guard OBSERVED rejecting its named
  input; the 50-row ledger reconciled with any un-observed guard reported **by name**.

---

## Per-Task Verification Map

**PENDING — filled from the PLAN files once `gsd-planner` has run.** Every task's quick gate will
be `cabal build --enable-tests -j all` with zero warnings; the full gate is `cabal test`. No task
may cite the bare `cabal build -j all`.

---

## Requirement Coverage

All fourteen IDs covered; per-check detail is `25-RESEARCH.md`'s 48-row map. **No row needs a DB or
GAMS inside `cabal test`.**

| Req | Tier | Note |
|---|---|---|
| **KEY-01** | A + C | `H(inputs ‖ GAMS ver ‖ CONOPT ver ‖ model source digest ‖ solver options digest)`; `key_scheme` already inside the unique constraint from phase 23 |
| **KEY-02** | **B** | One renderer feeds argv AND preimage — see the standing finding below; a token-set assertion in BOTH directions **plus** an elision observation, because they fail on opposite designs |
| **KEY-03** | A | `28e18` → `28000000000000000000` normalized once at the edge; no `show`/`printf` on a float anywhere on the key path |
| **KEY-04** | A | Framing — see the standing finding; must point at the FRAMER, not at `render_argv`'s accidental framing |
| **KEY-05** | A | The pips denominator (`FEE_DENOMINATOR = 1e6`) is in the preimage |
| **KEY-06** | A | A missing or unparseable input is an error BEFORE hashing — never a default. **The omission clause currently has no subject** (no per-shock assembler exists); the phase must create one or say so |
| **STORE-01** | B | **Cache elision — the user called this critical.** An identical shock returns the artifact WITHOUT invoking the solver |
| **STORE-02** | B + C | A re-solve producing different bytes is a determinism failure with non-zero exit |
| **STORE-03** | B + C | The original is KEPT and the divergent bytes **quarantined**, not discarded |
| **STORE-04** | B | Verification on demand, never on every hit (Nix shipped always-verify and removed it in 2.13 as broken) |
| **STORE-05** | B | Pinning survives retention |
| **STORE-06** | B + C | `reset` is separate and explicit — and it is exactly the operation that reaches for `TRUNCATE`; see the standing finding |
| **STORE-07** | B + C | Append-only run log `(timestamp, key, event tx, block)` |
| **STORE-08** | B | **A partial or failed run never becomes a cache entry.** Absence is the pass condition — the empty-log `grep -q` shape; the check must be shown FAILING when an entry does appear |

---

## Standing Findings the Execution Must Carry

**Three of the roadmap's own success criteria are unsound as worded. Plan against these.**

1. **SC-1's framing test CANNOT FAIL as written.** 343 shock tuples swept through `render_argv`'s
   token form gave **0 collisions** — every token is `--<literal name>=<digits>` and `-`/`=` are
   outside the digit alphabet, so the concatenation is uniquely parsable. **The `--name=` prefixes
   are ACCIDENTAL framing.** The same 343 tuples under bare-decimal concatenation give **30**
   collisions. The test must point at the **framer directly**, at a named bare-decimal negative
   control, and at the free-form components.
2. **The obvious KEY-02 implementation gives a cache hit rate of exactly ZERO — and every KEY-02
   check still passes.** `Gams.Run.spawn_into` puts `curdir=<per-run exclusive temp dir>` in
   `wrapper_argv`, so "reconstruct the argv actually passed from the stored preimage" is *most*
   satisfied by the design that makes the store useless. Answer: a two-directional token-set
   assertion (`curdir=`, `/usr/bin/timeout`, `-k`, the budget and the absolute binary all
   FORBIDDEN in the preimage) **plus** an elision observation — the two fail on opposite designs.
3. **`REVOKE` is a silent no-op and `TRUNCATE` walks through an append-only row trigger.**
   MEASURED on PG 18.4: after `revoke update, delete … from postgres`, a superuser UPDATE
   **landed** and read back `TAMPERED` with no error — **and the app connects as `postgres`**. A
   `BEFORE UPDATE OR DELETE` row trigger refuses it; then `truncate run_log` **emptied the table
   with no error**, which needs `BEFORE TRUNCATE … FOR EACH STATEMENT`. STORE-06's `reset` is
   precisely the operation that reaches for `TRUNCATE`.

**Two key-poisoning hazards, verified in the source:**

- **`ti_model_sources :: ![(FilePath, String)]` carries an ABSOLUTE machine path.** In the
  preimage that makes the key machine-specific — the same shock on another box misses the cache
  forever, silently. Digest the CONTENT, never the path.
- **`ti_conopt_version :: !(Maybe ConoptVersion)`.** Phase 24 built a version that cannot be
  constructed empty and then wrapped it in a type that can be **absent**. `Nothing` reaching the
  preimage is the empty-version hole one constructor up. KEY-06 must reject it.

**Other measured facts:**

- `on conflict do nothing returning` returns **no row** on conflict — `xmax = 0` is the
  discriminator (`t` then `f`).
- **`lock_probe_filename = "004_lock_probe.sql"` collides with the first real `004` migration** —
  the identical defect 24-06 fixed at `003`, one plan later.
- Tree-derived floors: `purge_file_floor` **59**, `credential_scan_floor` **68**,
  `sentinel_pair_floor` **3828**. They moved every wave of phases 23–24 and **two phase-24
  summaries misreported them** — treat every inherited number as a hypothesis and RE-MEASURE.
- **Carried guard #21** (the echoed-field cross-check, disclosed by phase 24 as having a standing
  assertion and no mutation) **is addressed here**: its firing input IS KEY-02's mutant — mutate
  one token post-render, have the stub echo the unmutated token, assert `EchoMismatch`. The
  freshness conjunct cannot catch it, because the stub writes a fresh file. The other three
  carried guards have no subject in this phase and are re-reported, not dropped.
- **A guard never OBSERVED rejecting is treated as ABSENT.** Restore mutated files from a **saved
  copy** verified by digest — never `git checkout`.
- **Prose is inside a grep's blast radius** — fifteen-plus instances across phases 23–24.

---

## Wave 0 Requirements

**None.** Test infrastructure exists and is reused. Every registration point is a plan task.

---

## Manual-Only Verifications

| Behavior | Requirement | Why manual | Instructions |
|---|---|---|---|
| Live Postgres observations (trigger refusals, `xmax` discriminator, quarantine) | STORE-02/03/06/07 | Requires a real server; deliberately out of `cabal test` | `bash offchain/rig/capture-store-conformance.sh` — `postgres:18-alpine` on host port **55433**, not 5432 |

---

## Validation Sign-Off

- [ ] `cabal build --enable-tests -j all` — zero warnings
- [ ] `cabal test` — FAIL 0, total ≥ 151 baseline
- [ ] Both structural greps 0 (DB-free AND GAMS-free)
- [ ] Every added guard observed rejecting its named input; 50-row ledger reconciled
- [ ] Tree-derived floors re-measured, not inherited
- [ ] Wall recorded before and after, under 900 s
- [ ] Territory clean: `git status --porcelain src test foundry-scripts Makefile foundry.toml .github` empty
