# Phase 24: GAMS Invocation & Toolchain Identity — Research

**Researched:** 2026-08-16
**Domain:** A controlled subprocess layer around a real GAMS 54.1 / CONOPT 4.39 prover, in Haskell
(GHC 9.10.3), under a hand-rolled `Check` runner that must stay database-free and now also
solver-free
**Confidence:** HIGH — every measurement in **New Measurements** was executed against the real
`gams` binary at `/usr/gams/gams54.1_linux_x64_64_sfx/gams`, the real `volume_path.gms`, and this
project's own build plan, on this machine, today. The exit-code taxonomy is cross-checked against
GAMS's official return-code page.

> **This document does not re-derive the domain.**
> `.planning/research/{SUMMARY,PITFALLS,STACK,ARCHITECTURE}.md` settled the aeson/`jsonb`/`bytea`
> hazards, the three test tiers, the polling decision and the `ExceptT` rejection.
> `model/mev_tax_model_one/VOLUME_PATH.md` (in the `cfmm-wt/gams` worktree) is the AUTHORITATIVE
> contract for §2 the seven inputs, §3 the output and determinism, §4 every named abort. Those are
> cited, not repeated. What is new is in **New Measurements** and **Validation Architecture**, and
> the new measurements change **four** of the phase's success criteria.

---

## User Constraints

**No `CONTEXT.md` exists for this phase** — `.planning/phases/24-gams-invocation-toolchain-identity/`
was empty at research time. There are therefore no locked user decisions, no explicitly-delegated
discretion areas, and no deferred ideas beyond what `ROADMAP.md` and `REQUIREMENTS.md` state.

### Locked (treated as binding, from ROADMAP.md and the phase brief)

- **Territory:** `offchain/` and `.planning/` only. `model/` is the GAMS workstream's tree — the §3
  output shape is their contract and this phase does not change it. Nothing is written into `test/`.
- **`cabal build --enable-tests -j all`**, zero `-Wall` warnings. The bare `cabal build -j all` is
  **VACUOUS** and must never appear in a plan, a task, or a summary.
- **`cabal test` stays DB-free and now also GAMS-free.** No check may shell out to the solver. Live
  GAMS observations belong in a committed capture, the `store-conformance.json` pattern.
- **"It type-checks" is never acceptance. "The suite is green" is never acceptance** — a suite that
  skips is also green.
- **Tree-derived floors MOVE**: `purge_file_floor` (48), `credential_scan_floor` (56),
  `sentinel_pair_floor` (3250). Any check touching them RE-MEASURES; none is incremented by
  arithmetic.
- `.planning/config.json` sets `workflow.nyquist_validation: true`, so **Validation Architecture**
  below is mandatory and authoritative.
- **Sequencing is locked and load-bearing:** this phase lands BEFORE the store's first production
  write, because an emptily-succeeding detector poisons every row written before it is fixed and
  those rows are indistinguishable afterwards (see *Why 24 precedes 25*).

### Claude's discretion (recommendations made below, none pre-locked)

Module layout under `offchain/lib/Gams/`; the subprocess library (`process` vs `typed-process`);
the timeout mechanism; the capture artifact's shape; whether migration `003` adds a non-empty
CHECK on the version columns.

### Out of scope

The content key itself (Phase 25 — `Store.Key` takes version **strings** as arguments, so this
phase is a leaf), the fee splitter (26), any chain read (27), the resident loop (28), and any change
to `volume_path.gms` or to §3's emitted JSON shape.

> ### A note on `./CLAUDE.md`
> The project `CLAUDE.md` in this worktree describes a **Hardhat + viem** layout and points at the
> `hardhat` skill. That file is stale with respect to this workstream: there is no `hardhat.config.ts`,
> no `ignition/`, and this milestone is Haskell under `offchain/`. The two skills present
> (`.claude/skills/hardhat`, `hardhat-toolbox-viem`) have no bearing on a GAMS subprocess layer and
> were not loaded. Flagging it rather than silently ignoring it.

---

<phase_requirements>

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| **GAMS-01** | The prover is invoked as a subprocess whose success is decided by the **exit code**, never by log text | Exit codes MEASURED today at 54.1: `0` clean, `2` compile, `3` `abort$` **and** `3` unhandled execution error, `6` missing input/parameter error, `0` for a no-argument help banner. Official table cross-checked (M4). The decision function is a total `ExitCode -> Verdict`; a source scan proves no log text reaches it |
| **GAMS-02** | A run that exits 0 without producing the artifact is a failure | **MEASURED with the real binary**: `action=c` exits **0** and writes **no** `volume_path.json` (M5). Plus `gams` with no arguments exits **0** and prints a 1239-byte banner (M1b). Fresh per-invocation `curdir` MEASURED working (M6) |
| **GAMS-03** | GAMS and CONOPT versions detected and fed into the key; detection that finds nothing **fails loudly** | `gams --version` does not exist — it is parsed as a filename, exit **6**, all output on **stdout**, stderr **0 bytes** (M1a). Three real sources of the GAMS version measured (job banner, `.lst` header, no-arg help banner) and a discriminator found: the banner's **job name** (M2). A real garbage battery is capturable rather than invented |
| **GAMS-04** | CONOPT detection reads the **true** solver version, not the link version or the `.so` name | All three candidates reproduced side by side today, and the true one is obtainable from an **8-line hermetic NLP probe in 0.008 s** — the production prover is not required (M3). Line positions differ between the probe (34/38) and the real run (42/47), so parsing must be pattern-anchored, never positional |
| **GAMS-05** | A hung solve is bounded by a timeout that terminates the child | **MEASURED, and the naive test cannot fail**: `readProcessWithExitCode` drains 2 MB of stderr with no deadlock (+0 packages), `timeout` kills and reaps a **direct** child — but a **grandchild SURVIVES with PPID 1**, and GAMS runs CONOPT at **Solvelink=2 as a separate process**, so the grandchild is the real case (M10). `/usr/bin/timeout -k 1 N` kills the group; exit **124** |
| **GAMS-06** | The invocation environment is controlled | A three-variable whitelist (`PATH`, `HOME`, `LC_ALL=C`) reproduces the golden bytes; so does an absolute-path invocation with the GAMS directory **off** `PATH` and four hostile ambient variables set (M9). Honest limit: **no ambient variable or config file was found that changes the artifact bytes**, and no comma-decimal locale exists on this machine — so the "inheriting differs" half must be observed on the **child's environment vector**, not on bytes |
| **BYTE-04** | `dQx`/`dQM` decoded as `Integer`, never `Double` | The golden vector is COMPUTED from the committed `offchain/rig/volume-path-golden.json`: `dQx[0] = -2613128317657530400` decodes as `Double` to `-2613128317657530368`, **|Δ| = 32 wei exactly**; **all 16 elements** are inexact under `Double`, |Δ| ranging 4…328 (M12). `Store.Json`'s hand-rolled recogniser is the precedent for a decoder that never builds an aeson `Value` |

</phase_requirements>

---

## Summary

The phase's whole job reduces to one sentence: *nothing this layer reports may be true because a
subject was absent* — not an empty version string, not an exit code that only means the binary ran,
not a stale file left by someone else's run, not a `Double` that rounds a wei away, and not a guard
whose test case is the easy one.

Three findings reshape the plan.

**First, this phase does not need to guess at GAMS — the whole surface is measurable, and I measured
it.** `gams --version` really is parsed as an input filename (exit **6**, everything on **stdout**,
stderr exactly **0 bytes**). `gams` with **no arguments at all** exits **0** and prints a 1239-byte
help banner **containing the version string three times** — an exit-0, non-empty, version-shaped
result produced by an invocation that ran no model whatsoever. That is a far better garbage-battery
member than any string one could invent, and it is capturable verbatim. The discriminator that
rejects it is the job banner's **job name**: `--- Job volume_path.gms Start …` for the real run,
`--- Job ? Start …` for the help banner, `--- Job --version Start …` for the flag. Anchor the parse
on the job name equalling the basename of the `.gms` actually invoked, and every wrong-subject
banner is rejected by construction.

**Second, CONOPT's true version needs no production solve.** An eight-line NLP (`z = (x−1)² + 1`)
solved with `option nlp = conopt` prints `    C O N O P T   version 4.39.0` in 0.008 s, alongside
both decoys — the GAMS-side link line `CONOPT 4         54.1.0 37378ce0 …` and, on disk,
`libconopt464.so`. All three exist simultaneously and all three are plausible. Their **line
positions differ between the probe and the real run** (34/38 vs 42/47), which retires any
positional parse. The version also appears in the production run's own `.log` and `.lst`, which is
where it should be read from for key material: the version that produced *these* bytes, not a
version from a separate probe that could have resolved a different binary.

**Third, the two hazards that look hardest are already closed, and the one that looks closed is
open.** `readProcessWithExitCode` from `process-1.6.26.1` — already a dependency, **+0 packages** —
forks two draining threads and swallowed 2,000,000 bytes of stderr without deadlocking; and
`System.Timeout.timeout` around it terminated *and reaped* a hung child with no orphan. But a
**grandchild survives**: measured, PPID 1, still running. GAMS executes CONOPT at **Solvelink=2, as
a separate process** (verbatim in the log: `--- Executing CONOPT (Solvelink=2)`), so the grandchild
is not a hypothetical — it is the actual case, and a GAMS-05 test written against a direct `sleep`
child would pass while leaving a `conopt4` process burning a core. `/usr/bin/timeout -k 1 N` signals
the whole group and the grandchild died; exit **124** collides with no GAMS code.

And one measurement that belongs to Phase 25 but can only be made here: **the artifact bytes are a
function of the argv TOKEN, not only of the numeric value.** `volume_path.gms:206-207` emits
`"%sqrtPriceX96%"` — a compile-time substitution of the raw command-line string. Passing
`079228162514264337593543950336` instead of `79228162514264337593543950336` gives **exit 0, every
§4 gate passing, and a different sha256** (`d64a7b32…` vs the golden `e7b14f38…`). Edge normalization
is therefore not key hygiene; it decides the bytes. Phase 24 owns the renderer because Phase 24 owns
the `execve`.

**Primary recommendation:** build `offchain/lib/Gams/{Argv,Version,Exit,Env,Artifact,Invoke}.hs`
with every decision total and pure except one IO edge in `Invoke`; use `process` (+0 packages) with
`readCreateProcessWithExitCode`-shaped draining and `/usr/bin/timeout -k` as the direct child so the
process **group** dies; make `GamsVersion`/`ConoptVersion` unconstructible-empty smart-constructed
newtypes anchored on the job name and the spaced-letter form; deliver every subprocess observation
in `cabal test` against **shell stubs the test writes itself** (the suite already spawns `grep`, so
this is precedent, not a new capability); and put every real-GAMS observation in one committed
`offchain/rig/gams-conformance.json` produced by `offchain/rig/capture-gams-conformance.sh`.

---

## New Measurements

Everything below was executed today against `/usr/gams/gams54.1_linux_x64_64_sfx/gams`
(GAMS 54.1.0, build `37378ce0`, LEX-LEG x86 64bit/Linux, demo licence) and
`/home/jmsbpp/cfmms-playground/cfmm-wt/gams/model/mev_tax_model_one/volume_path.gms`, or against
this project's own `dist-newstyle` build plan. Scratch directories were used throughout; nothing
under `offchain/` or `model/` was modified.

### M1a. `gams --version` does not exist — exit 6, everything on STDOUT, stderr exactly 0 bytes

```
$ gams --version            # exit 6, stdout 275 bytes, stderr 0 bytes
--- Job --version Start 08/16/26 16:01:42 54.1.0 37378ce0 LEX-LEG x86 64bit/Linux
*** Unable to open input file (RC=2) --version
*** SysMsg: No such file or directory
*** Status: Terminated due to parameter errors
--- Job --version Stop 08/16/26 16:01:42 elapsed 0:00:00.000
```

Two things matter beyond "it fails". **Stderr is empty** — a detector that reads stderr gets `""`,
which is the `"" == ""` defect handed to it by the tool itself. And line 1 **is** a well-formed job
banner carrying `54.1.0`, so a parser anchored only on "a version-shaped token near the word Job"
accepts the output of a *failed* invocation.

### M1b. `gams` with NO arguments exits **0** and prints the version three times

```
$ gams > out.txt 2> err.txt      # exit 0, stdout 1239 bytes (27 lines), stderr 0 bytes
line  1: --- Job ? Start 08/16/26 16:01:42 54.1.0 37378ce0 LEX-LEG x86 64bit/Linux
line  3: *** GAMS Base Module 54.1.0 37378ce0 Jun 15, 2026          LEG x86 64bit/Linux
line  8: *** GAMS Release     : 54.1.0 37378ce0 LEX-LEG x86 64bit/Linux
```

**Exit 0. A non-empty, correctly-shaped version. No model run at all.** This is the phase's defect
class in its most seductive form — not an empty comparand but a *plausible* one from the wrong
subject. It is the single most valuable member of the garbage battery and it costs nothing to pin,
because it is real output rather than an invented string.

*(Earlier in the session this appeared to exit 141; that was `PIPESTATUS` under `| head` —
128 + SIGPIPE. Redirected to a file it is 0. Recorded because the wrong number would have justified
the wrong taxonomy entry.)*

### M2. Three real sources of the GAMS version, and the discriminator

| Source | Text | Exit | Stream |
|---|---|---|---|
| The production run's own log, line 1 | `--- Job volume_path.gms Start 08/16/26 15:52:25 54.1.0 37378ce0 LEX-LEG x86 64bit/Linux` | 0 | file (`volume_path.log`) |
| The production run's listing, line 1 | `GAMS 54.1.0  37378ce0 Jun 15, 2026          LEX-LEG x86 64bit/Linux - 08/16/26 15:52:25 Page 1` | 0 | file (`volume_path.lst`) |
| `gams audit` | `GAMSX            54.1.0 37378ce0 Jun 15, 2026          LEG x86 64bit/Linux    ` | 0 | stdout |

`gams audit` reports **GAMSX**, a component, not the GAMS base module — a different subject that
happens to carry the same number today. The **job name field** is the discriminator that makes the
banner parse honest: `volume_path.gms` (real run), `?` (no args), `--version` (flag). Requiring it to
equal the basename of the `.gms` actually invoked rejects both wrong-subject banners without a
denylist.

Note also that the log's **last** line is `--- Job volume_path.gms Stop … elapsed 0:00:00.050`, so a
truncated log is detectable; and line 3 names the resolved system directory
(`/usr/gams/gams54.1_linux_x64_64_sfx/gmsprmun.txt`), which is corroboration for the resolved-binary
record.

### M3. CONOPT's true version comes from an 8-line hermetic probe — and both decoys sit beside it

```gams
variable z, x;  equation e;
e.. z =e= sqr(x-1) + 1;
x.lo = -10; x.up = 10;
model m /e/;  option nlp = conopt;
solve m using nlp minimizing z;
```

`gams probe.gms lo=3` → **exit 0, 3041 bytes on stdout, 0 bytes on stderr**, containing:

| # | Line | What it is |
|---|---|---|
| 33 | `CONOPT 4         54.1.0 37378ce0 Jun 15, 2026          LEG x86 64bit/Linux    ` | **DECOY** — the GAMS-side *link* version |
| 38 | `    C O N O P T   version 4.39.0` | **TRUE** — CONOPT's own banner, four leading spaces, spaced letters, three spaces before `version` |
| — | `/usr/gams/gams54.1_linux_x64_64_sfx/libconopt464.so` | **DECOY** — the shared object, `464`, neither 4.39 nor 54.1 |

In the **real** `volume_path` run those two lines are at **42** and **47**; in the probe at **33**
and **38**. Positional parsing is dead. The true line is also present in the `.lst` listing.

Two riders. `--- Executing CONOPT (Solvelink=2)` confirms CONOPT is a **separate process** (this is
the M10 grandchild). And the probe prints `Will use up to 4 threads.` — CONOPT's default here is
**four** threads; `volume_path.gms:167` sets `option threads = 1;` with an explicit determinism
comment, so the single-threaded pin lives in the model, not in the environment.

### M4. Exit codes, MEASURED, plus the official table

| Invocation | Exit | Class |
|---|---|---|
| clean solve (`action=ce`, valid shock) | **0** | success |
| `action=c` (compile only) | **0** | **success code, NO artifact** — see M5 |
| no arguments (help banner) | **0** | **success code, no model** — see M1b |
| syntax error in the `.gms` | **2** | model-level: compilation error |
| `abort$(…) "named abort"` | **3** | model-level: execution error |
| `a = 1/0;` (unhandled) | **3** | model-level: execution error |
| `--volTgtWad=abc` | **2** | model-level (compile-time substitution) |
| missing input file / `--version` | **6** | **environmental**: parameter error |

Official table (GAMS docs, *GAMS Return Codes*): `0` normal · `1` solver to be called · `2`
compilation error · `3` execution error · `4` system limits · `5` file error · `6` parameter error ·
`7` **licensing error** · `8` GAMS system error · `9` could not start · `10` out of memory · `11`
out of disk · `109–115` scratch-directory / parameter-file / environment-variable errors ·
`400/401/402` (`144/145/146` mod 256) compiler spawn, **`curdir` does not exist**, cannot set curdir
· `909` (`141`) path/environment · `1000+` driver errors. The page's own warning is quoted in
`.planning/research/PITFALLS.md` #8.

**Consequences the plan must carry:**

1. **Exit `3` does NOT distinguish a named §4 abort from an unhandled execution error.** Both were
   measured at 3. So "model-level code 3 ⇒ a named abort" is false; the *reason* is log text and
   therefore diagnostic only, never a gate.
2. **`7` is licensing.** Classifying "non-zero ⇒ the model says infeasible" turns an expired licence
   into a recorded infeasibility verdict — the failure PITFALLS #8 names.
3. **`401 → 145` is "curdir does not exist."** The fresh-temp-directory design has its own failure
   code, and it is environmental, not a model verdict.
4. The mod-256 folding means a collision argument for the timeout codes must be made against the
   **images**: `124` and `137` (128+9) appear nowhere in the folded table.

### M5. `action=c` exits 0 and writes NO artifact — GAMS-02's firing input, with the real binary

```
$ gams …/volume_path.gms action=c curdir=$T lo=2 --sqrtPriceX96=… --volTgtWad=28e18
exit 0
$ ls $T
volume_path.log   volume_path.lst          # volume_path.json ABSENT
```

The roadmap's SC-1 asks for a *stub* that exits 0 and writes nothing. There is no need to write one
for the Tier-C evidence: the real prover does it on request. (A stub is still required for the
in-suite Tier-B check, because `cabal test` must stay GAMS-free.)

### M6. `curdir=<tempdir>` puts the artifact in the temp directory — measured, golden digest

`volume_path.gms:202` is `file fj /volume_path.json/;` — a **relative** name, so it resolves against
the working directory. Running the real prover with `curdir=$T` produced
`$T/volume_path.json` at sha256 `e7b14f384ab4c027be5450218a52040110d45dbaddbbfb0bb7bd5ab707d0d884`
— byte-identical to the committed `offchain/rig/volume-path-golden.json` (606 bytes, ending
`5d 0a 7d 0a`). Repeated across five scratch directories in this session.

So `withSystemTempDirectory` + `curdir=` is the whole stale-file defence, and it is measured working
rather than argued. Companion files land there too (`volume_path.log`, `.lst`, `.txt`) — which is
also where the version banners are read from.

### M7. **The artifact bytes are a function of the argv TOKEN** — new, and load-bearing

`volume_path.gms:206-207`:

```gams
put '  "sqrtPriceX96": "%sqrtPriceX96%",' /;
put '  "liquidity": "%liquidityRaw%",'    /;
```

`%…%` is a **compile-time substitution of the raw command-line string**. Measured:

| `--sqrtPriceX96=` | Exit | §4 gates | sha256 |
|---|---|---|---|
| `79228162514264337593543950336` | 0 | all pass | `e7b14f38…07d0d884` (golden) |
| `079228162514264337593543950336` | 0 | all pass | `d64a7b32…14b9e650` |

Numerically identical, every gate green, **different bytes**. Two logically identical shocks produce
two different artifacts, which means "same inputs + same toolchain → same bytes" is only true modulo
a rendering convention — and the rendering happens **here**, in the argv this phase constructs.
Phase 25's KEY-03 normalization is downstream of a decision Phase 24 makes.

### M8. `volTgtWad` is a double and its rendering does NOT reach the bytes

| `--volTgtWad=` | Exit | sha256 |
|---|---|---|
| `28e18` | 0 | `e7b14f38…07d0d884` |
| `2.8e19` | 0 | `e7b14f38…07d0d884` — **byte-identical** |

This answers `.planning/research/SUMMARY.md`'s open question (b) and the ROADMAP's Phase-24 research
flag: **`volTgtWad` is a GAMS `Scalar` (double), it is not echoed into the JSON, and two renderings
of the same double give identical output.** The asymmetry with M7 is the finding to carry: the
**two echoed string fields** (`sqrtPriceX96`, `liquidityRaw`) are token-sensitive; the five numeric
fields are re-rendered by GAMS (`txlVolumeRate`, `phiXpips`, `phiMpips`, `nEvents` via `:0:0`,
`deltaRealized`/`rPhiRealized` via `:0:10`) and are not. A canonical renderer is still required for
all seven — the two are simply where the absence of one is *observable in the artifact*.

### M9. The environment whitelist is sufficient, and hostile ambient variables are inert

| Environment | Exit | sha256 |
|---|---|---|
| ambient developer shell | 0 | golden |
| `env -i PATH=<gamsdir>:/usr/bin HOME=$HOME LC_ALL=C` | 0 | golden |
| `env -i PATH=<gamsdir>:/usr/bin LC_ALL=C` (no `HOME`) | 0 | golden |
| `env -i PATH=/usr/bin LC_ALL=C GAMSTHREADS=8 GDXCOMPRESS=1 LC_NUMERIC=de_DE.UTF-8 GAMSDIR=/nonexistent`, invoking the **absolute** binary path | 0 | golden |

So: a **two-to-three variable whitelist reproduces the bytes**; the GAMS directory need not be on
`PATH` when the binary is invoked by absolute path (which removes the `PATH`-shadow surface
entirely); and four hostile ambient variables changed nothing.

**Honest limits, stated because SC-5 as written asks for more than this machine can give.**

- No ambient variable and no `gamsconfig.yaml` in `curdir` was found that changes the artifact bytes.
  An explicit CLI parameter beat a `curdir` `gamsconfig.yaml` in the one test run.
- `locale -a` on this machine offers only `C`, `C.utf8`, `en_US.utf8`, `POSIX` — **there is no
  comma-decimal locale installed**, so a locale-driven byte difference is not observable here at all.
- Therefore SC-5's *"a run inheriting the environment is OBSERVED to differ"* cannot be discharged on
  artifact bytes. It **is** cleanly dischargeable on the **child's own environment vector** — spawn a
  probe through the same invocation function with `env = Just whitelist` and with `env = Nothing`,
  capture both, and assert the inherited one carries variables the whitelist does not. That subject
  is unambiguous, non-vacuous, and it is what actually proves the whitelist is in force (a whitelist
  that silently fell back to inheritance is exactly what it catches). See the SC-5 correction below.

### M10. The subprocess hazards: two closed at +0 packages, one open and mis-tested by default

Executed with `process-1.6.26.1` (a GHC boot package, already a dependency of the library, both
executables and the test-suite) through `cabal exec -- runghc`:

| Probe | Result |
|---|---|
| child writes **2,000,000 bytes to stderr**, 5 to stdout, via `readProcessWithExitCode` | `ExitSuccess`, `out=5`, `err=2000000` — **no deadlock** (it forks two draining threads) |
| `timeout 2s` around `readProcessWithExitCode` on `sh -c 'echo $$ >f; exec sleep 300'` | returns `Nothing`; 0.5 s later `ps -p <pid>` exits 1 and `pgrep -a "sleep 300"` exits 1 — **terminated and reaped, no orphan** |
| `timeout 2s` around the same on `sh -c 'sleep 297 & echo $! >f; wait'` | returns `Nothing`; the **grandchild SURVIVES**: `PID 2158427  PPID 1  S  sleep 297` |
| `/usr/bin/timeout -k 1 2 sh -c 'sleep 291 & echo $! >f; wait'` | exits **124**; the grandchild is **gone** (`ps` exit 1) |

`terminateProcess` sends SIGTERM to the **direct child only**. GAMS runs CONOPT at `Solvelink=2`, as
a separate process (M3), so **the grandchild is the real case** and a GAMS-05 test written against a
direct `sleep` child *cannot fail* — the defect class, in the test rather than in the code.

A process-group SIGKILL from Haskell (`create_group = True` + `getPid` + `signalProcessGroup`) also
removed the grandchild, but the probe's bracket shape (`timeout` around `waitForProcess`, then a
second `waitForProcess` in cleanup) **hung** and had to be killed. Recorded as a caveat rather than
smoothed over: the group-kill mechanism works; the *shape* around it needs care and must be
OBSERVED, not argued. `/usr/bin/timeout -k` is the lower-risk primary because the group semantics
live in a battle-tested C program and the Haskell side only has to recognise exit 124/137.

### M11. `typed-process` costs +2 packages — MEASURED, not estimated

`cabal build --enable-tests -j all --dry-run` with `typed-process` added to the library stanza, by
`plan.json` set-diff against the current baseline: **158 → 160 distinct packages**. The two new units
are `typed-process-0.2.13.0` and `unliftio-core-0.2.1.0`; `async-2.2.6`, `transformers`,
`transformers-base` and `transformers-compat` were already in the plan. The `.cabal` file was
restored byte-identically (sha256 `c40833aa…101165` before and after).

Its one real advantage over `process`: `readProcess` returns **lazy `ByteString`**, so the child's
output never passes through a locale decoder. `process` returns `String` via `hGetContents`, which
decodes with the *handle's* encoding — and a non-UTF-8 byte in a banner would throw
`hGetContents: invalid byte sequence` rather than fail a parse. That hazard is real but avoidable:
this phase reads the version out of **files** in the temp directory (`volume_path.log`) with
`Data.ByteString.readFile`, and only needs the subprocess's streams for diagnosis.

### M12. BYTE-04's golden vector, computed from the committed artifact

From `offchain/rig/volume-path-golden.json` (606 bytes, sha256 `e7b14f38…07d0d884`, already pinned
in `Store.Types.volume_path_golden_sha256`), decoding each element as IEEE-754 binary64 and rounding
back:

| # | `dQx[n]` (exact) | as `Double` | Δ |
|---|---|---|---|
| **0** | `-2613128317657530400` | `-2613128317657530368` | **32** |
| 1 | `-2680707973111378000` | `-2680707973111377920` | 80 |
| 2 | `4861675431041821000` | `4861675431041820672` | −328 |
| 3 | `4608884887749073000` | `4608884887749072896` | −104 |
| 4 | `4529439681209106400` | `4529439681209106432` | 32 |
| 5 | `-2884368647455834000` | `-2884368647455834112` | −112 |
| 6 | `-2898559031733104600` | `-2898559031733104640` | −40 |
| 7 | `-2923236030042153000` | `-2923236030042152960` | 40 |

`dQM` likewise: Δ = 12, 240, −256, −248, −192, −16, 4, 4.

**All 16 elements are inexact under `Double`**, |Δ| ∈ [4, 328], and the first `dQx` element is
exactly the **32 wei** the requirement names. Two assertions follow, and the second is the one that
makes the check un-passable under a tolerance: (a) `dQx[0]`'s `Double` decode equals
`-2613128317657530368` **exactly**, so Δ = 32 is an equality on integers, not a bound; (b) **16 of
16** elements differ, so a decoder that silently widened one field would still be caught.

### M13. Binary identities (record, do not pin in Haskell source)

```
gams              79cd3a575f40565c5954754a6b6b575dec6e95f966b12ed1e0f7d99236c319fc   1,822,256 bytes
libconopt464.so   3f3b9411d6bc4e993773228b397ed1f308fac2c997d599b6f8d8036b2877c3c8
```

GAMS-03 asks for the resolved absolute path and a sha256 of the `gams` executable "because that is
the one component a wrapper script or `PATH` shadow cannot lie about". Correct — but these digests
are **machine-specific**, so pinning them in Haskell source would make `cabal test` fail on every
other install. They belong in the **capture artifact**, recorded per run, with the suite asserting
*shape and presence* (64 bare hex, non-empty, path absolute and existing at capture time) rather
than the value. Note also that a `0x`-prefixed digest anywhere under `offchain/` reddens
`sc3_literal_purge`; write digests **bare**, as `Store.Types` already documents.

### M14. `model_run` cannot refuse an empty version string

`offchain/migrations/001_model_run.sql` declares `gams_ver text not null` and `conopt_ver text not
null`. **`NOT NULL` does not forbid `''`** — the schema will happily store the empty string, which is
precisely the poisoned-row scenario this phase's sequencing exists to prevent, sitting one layer
below the Haskell guard. There is **no run-log table at all** (STORE-07 is Phase 25). Both facts feed
the SC corrections below.

---

## Two corrections of record to the phase's success criteria

These are deviations derived from measurement, in the shape Phase 23 recorded three of. They are for
the planner to adopt deliberately, not to discover as a red.

### Correction 1 — SC-4's "aborted run-log row" is not deliverable in Phase 24

SC-4 requires "a timed-out run produces an **aborted run-log row** and never an output row", and the
phase's `Depends on` line calls Phase 23 "the run-log table an aborted run lands in". **That table
does not exist.** `offchain/migrations/` contains `001_model_run.sql` and `002_byte_corpus.sql` and
nothing else; the append-only run log is STORE-07, mapped to Phase 25.

Restate it as a **type-level** property, which is stronger and is deliverable here:
`ProverOutcome` is a total sum type in which `Aborted { reason, exit_code, captured_streams }`
carries no `Artifact` and has **no conversion to one** — the `DerivedDoc` idiom from
`Store.Types`, which Phase 23 proved catches its subject at compile time (observed:
`[GHC-39999] No instance for 'Eq DerivedDoc'`). Then "never an output row" is unrepresentable rather
than merely untested, and Phase 25 persists the row when the table exists.

### Correction 2 — SC-5's "a run inheriting the environment is OBSERVED to differ" has no byte-level witness on this machine

Measured (M9): four hostile ambient variables, no comma-decimal locale installed, and a `curdir`
`gamsconfig.yaml` that lost to an explicit CLI parameter. Nothing available here changes the artifact
bytes. Writing the criterion against bytes would produce a check that can only be satisfied by
inventing a variable that matters — or, worse, one that passes because its subject is absent.

Restate the second half against the **child's environment vector**: the same invocation function,
run twice against a probe that prints its own environment, with `env = Just whitelist` and with
`env = Nothing`; assert (a) the whitelisted child's environment is *exactly* the whitelist as a SET,
and (b) the inherited child's environment is a strict superset naming at least one variable the
whitelist excludes. The first half — *a hostile ambient variable produces byte-identical output* —
is adopted unchanged and is discharged by M9 in the capture, with the four hostile variables named.

---

## Why 24 precedes 25 — and what must be proven before 25 may start

The ordering is not tidiness. `model_run.gams_ver` and `model_run.conopt_ver` are `text not null`
columns *inside* rows whose identity is `(model, key_scheme, key)`, and KEY-01 folds both version
strings into the key. If the detector returns `""`:

- `NOT NULL` does not catch it (M14);
- every toolchain hashes to the same key component, so GAMS 54.1's bytes are served to a GAMS 55
  request — the precise scenario `VOLUME_PATH.md` §3 warns about (*"a different CONOPT version may
  select a different member of the underdetermined path family — still passing every gate"*);
- and afterwards the poisoned rows are **indistinguishable** from good ones, because the only
  evidence of which toolchain produced them is the column that was emptied.

So the gate on starting Phase 25 is not "Phase 24's plans are done". It is:

1. `GamsVersion` and `ConoptVersion` have **no constructible empty or whitespace-only value**, and
   the garbage battery has been OBSERVED rejecting every member — including the exit-0 help banner.
2. Detection failure **aborts the invocation**, observed by driving it, not by reading the code.
3. The CONOPT parser has been OBSERVED rejecting **both** decoys.
4. The argv renderer is total and canonical, with the leading-zero case (M7) observed changing the
   bytes — so Phase 25 inherits a settled rendering rather than choosing one after rows exist.
5. `key_scheme` (Phase 23) remains the escape hatch if any of this changes later. Adding a
   **migration `003`** with `check (length(gams_ver) > 0 and length(conopt_ver) > 0)` is cheap
   defence-in-depth and is recommended — costed below, because it moves `Store.Schema.expected_migrations`,
   the computed freshness oracle and `purge_file_floor` together.

---

## Standard Stack

### Core — the decision is `process`, at +0 packages

| Library | Version | Purpose | Why |
|---|---|---|---|
| **`process`** | **1.6.26.1** (GHC boot) | subprocess spawn, pipe draining, exit codes | **Already a dependency of the library, both executables and the test-suite.** `readProcessWithExitCode` forks two draining threads — MEASURED swallowing 2 MB of stderr with no deadlock (M10). `readCreateProcessWithExitCode` takes a full `CreateProcess`, so `cwd`, `env` and `create_group` are all settable without hand-rolling the drain |
| **`bytestring`** | already present | `Data.ByteString.readFile` for the artifact and the log | **Never** `Prelude.readFile` — `String`, locale-decoded, newline-translating |
| **`directory`** | already present | temp-directory creation/removal | `withSystemTempDirectory` lives in `temporary`, which is **not** in the plan; see below |
| **`crypton`** | 1.0.6, already resolved | sha256 of the artifact and of the resolved binary | `Store.Types.sha256_hex` already exists and renders **bare** hex |
| **`unix`** | 2.8.7.0 (GHC boot, +0) | *only if* the Haskell-side group kill is chosen over `/usr/bin/timeout` | `signalProcessGroup`, `sigKILL` |

### The temp directory — a real gap

`withSystemTempDirectory` is in **`temporary`**, which is **not** in the current build plan. Three
options, in order of preference:

1. **Hand-roll it on `directory` (+0).** `createDirectory` under `getTemporaryDirectory` with a name
   from the pid plus a counter, `bracket`ed with `removeDirectoryRecursive`. ~15 lines, no new
   package, and the *exclusivity* property (`createDirectory` fails if the path exists) is exactly
   what the stale-file defence needs — a random name that silently reuses an existing directory
   would reopen the hole.
2. **Add `temporary`** — measure the delta before adopting; it is small but it is not zero, and the
   `.cabal` comment discipline (lines 107–115) requires a MEASURED package count, not an estimate.
3. Do **not** use `mktemp(1)` through a subprocess: it puts the isolation mechanism behind the very
   surface being isolated.

### Alternatives considered

| Instead of | Could use | Tradeoff |
|---|---|---|
| `process` | **`typed-process` 0.2.13.0** | **+2 packages, MEASURED** (M11). Buys `ByteString` streams (no locale decoding) and `bracket`-based cleanup. `.planning/research/SUMMARY.md` recommends it. Rejected as primary because the decode hazard is avoided anyway (versions are read from **files** with `Data.ByteString.readFile`), and +0 beats +2 when the +0 option's deadlock behaviour has been measured rather than assumed. **Reconsider** if the plan decides to parse versions from the subprocess's streams rather than from the temp directory's log |
| `/usr/bin/timeout` as the direct child | `create_group = True` + `signalProcessGroup` in Haskell | Keeps everything in-process and removes a coreutils dependency; MEASURED killing the grandchild. But the bracket shape around it **hung** in my probe (M10) and would need careful, observed construction. Recommended as the *secondary* mechanism, or as a backstop `System.Timeout.timeout` at a longer budget in case `timeout(1)` is itself absent |
| a JSON library for the artifact | **hand-rolled, on `Store.Json`'s precedent** | `Store.Json` is already a total pure recogniser written specifically so that no JSON library sits on the storage path. BYTE-03's scan lists every `Store/*.hs`; a new `Gams/Artifact.hs` that imported aeson would have to be *excluded* from that list, which is the scope-shrinking move Phase 23 was burned by |
| `readProcess` | anything else | `readProcess` **throws `IOError` on non-zero exit** — it discards the exit code that GAMS-01 is entirely about. Never on this path |

### Installation

```bash
# No new package is strictly required. If `temporary` is adopted, MEASURE first:
cabal build --enable-tests -j all --dry-run   # then plan.json set-diff against 158
```

**Version verification, executed today:** `process-1.6.26.1` and `unix-2.8.7.0` resolved in the
global package db; `crypton-1.0.6` already in the plan via `web3-crypto`'s `crypton <1.1` cap;
baseline plan = **158** distinct packages; `typed-process` would make it **160**.

---

## Architecture Patterns

### Module layout — role-named, one IO edge per area

`.planning/research/ARCHITECTURE.md`'s invariant is *one IO edge per area*, and the repo's actual
convention is role-named modules (`Rig.Manifest`, `Driver.Capture`, `Store.Postgres`), not a
`{Types,Encoding,Decode,Rpc}` template.

```
offchain/lib/Gams/
├── Argv.hs        # PURE. Shock -> [String]. The canonical renderer (M7 lives here).
├── Version.hs     # PURE. GamsVersion/ConoptVersion newtypes + smart constructors + parsers.
├── Exit.hs        # PURE. ExitCode -> Verdict. The total taxonomy (M4). No log text reaches it.
├── Env.hs         # PURE. The whitelist, as data, plus LC_ALL=C.
├── Artifact.hs    # PURE. Bytes -> Either Reason ProverArtifact. [Integer], never Double. BYTE-04.
├── Config.hs      # GAMS_BIN / GAMS_MODEL / GAMS_CONFORMANCE, the Store.Config idiom.
└── Invoke.hs      # THE ONE IO EDGE. temp dir, execve, drain, timeout, read back, classify.
offchain/app/GamsConformance.hs          # the capture executable -- the ONLY real-GAMS caller
offchain/rig/capture-gams-conformance.sh # provisions nothing; drives the real binary
offchain/rig/gams-conformance.json       # committed evidence
```

Six pure modules and one IO edge is deliberate: **every Tier-A check in the Validation Architecture
below tests a pure function**, so the suite's discriminating power does not depend on a subprocess.

### Pattern 1: the version that cannot be empty

```haskell
-- Gams/Version.hs -- ABSTRACT constructor, on the Store.Types.DerivedDoc precedent.
module Gams.Version
  ( GamsVersion, gams_version_text, parse_gams_version
  , ConoptVersion, conopt_version_text, parse_conopt_version
  , VersionError (..)
  ) where

newtype GamsVersion = GamsVersion String   -- constructor NOT exported

-- | The banner's JOB NAME is the discriminator (M2): '?' is the help banner (exit 0!),
-- '--version' is the flag, and only the real run names the model.
--
--   --- Job volume_path.gms Start 08/16/26 15:52:25 54.1.0 37378ce0 LEX-LEG x86 64bit/Linux
--       ^job-name                                   ^version ^build
parse_gams_version :: String -> ByteString -> Either VersionError GamsVersion
```

Requirements the plan must hold it to, each a check below: no `fromMaybe`, no `<|> pure ""`, no
`catch (\_ -> return "")` anywhere in `Gams/`; the shape is `MAJOR.MINOR.PATCH` plus an 8-hex build
id; and `GamsVersion ""` does not type-check outside the module.

### Pattern 2: the decision is a total function of `ExitCode`

```haskell
-- Gams/Exit.hs -- takes an ExitCode. Nothing else. There is no parameter to smuggle text through.
data Verdict = Solved | ModelLevel ModelFailure | Environmental EnvFailure | TimedOut
classify_exit :: ExitCode -> Verdict
```

Because the type carries no stream, "no decision reads solver stdout/stderr" is structural. The
source scan then only has to prove `Invoke.hs` does not re-introduce it.

### Pattern 3: the fresh directory is the stale-file defence, and it is exclusive

```haskell
with_fresh_run_dir :: (FilePath -> IO a) -> IO a   -- createDirectory FAILS if it exists
-- then:  gams <abs .gms> action=ce curdir=<dir> lo=2 <argv…>
-- and the artifact is read from <dir>/volume_path.json, which cannot pre-exist.
```

MEASURED working (M6). Belt and braces from PITFALLS #8: also assert the artifact's mtime is at or
after process start.

### Pattern 4: the timeout owns the process GROUP

```
argv = [ "/usr/bin/timeout", "-k", "5", show budget_secs, gams_abs, model_abs, "action=ce", … ]
```

`timeout(1)` exits **124** on expiry (**137** if it had to SIGKILL), and it signals the group — so
`conopt4` dies with `gams` (M10). Neither code collides with the mod-256 image of GAMS's table (M4).
Keep a Haskell `System.Timeout.timeout` at `budget + slack` as a backstop.

### Pattern 5: `Aborted` carries no artifact — Correction 1, as a type

```haskell
data ProverOutcome
  = Produced !ProverArtifact !ToolchainIdentity   -- the ONLY constructor carrying bytes
  | Aborted  !AbortReason !Int !CapturedStreams   -- no artifact, no conversion to one
-- and NO   outcome_artifact :: ProverOutcome -> ProverArtifact
```

### Anti-patterns

- **Positional log parsing.** Line 34/38 in the probe, 42/47 in the real run (M3). Anchor on
  patterns.
- **A version parser that scans for "something version-shaped".** M1b's help banner exits 0 and
  contains `54.1.0` three times.
- **Gating on log text.** §4 forbids it and it is unnecessary: exit code + artifact absence +
  structural post-conditions cover the gate. Streams are captured **for diagnosis** and the module
  must say so in a comment.
- **`Prelude.readFile` for the artifact.** `String`, locale-decoded, newline-translating.
- **Testing the timeout against a direct child.** It cannot fail (M10).
- **Pinning the `gams` binary's sha256 in Haskell source.** Machine-specific (M13); record it.

---

## Don't Hand-Roll

| Problem | Don't build | Use instead | Why |
|---|---|---|---|
| draining two pipes without deadlock | your own `forkIO` + `MVar` reader pair | `readProcessWithExitCode` / `readCreateProcessWithExitCode` | It is exactly that, already written and MEASURED at 2 MB (M10). Hand-rolling reintroduces the hazard the drain exists to close |
| killing a hung process tree | `terminateProcess` alone | `/usr/bin/timeout -k` (or `create_group` + `signalProcessGroup`) | `terminateProcess` reaches the direct child only; the grandchild survives with PPID 1 (M10) |
| a JSON reader for the artifact | an aeson decode | the `Store.Json` recogniser idiom, extended with an `[Integer]` reader | aeson's `decode→encode` mutates four fields at 9.10.3, and BYTE-03's scan lists every storage module — a new aeson importer would have to be *excluded* from the scan |
| sha256 | anything | `Store.Types.sha256_hex` | Already exists, already renders **bare** hex (a `0x`-prefixed digest reddens `sc3_literal_purge`) |
| environment override resolution | ad-hoc `getEnv` | the `Store.Config` / `Rig.Manifest` idiom | Named once, in one place both the resolver and `advertised_overrides` read — the fix for the three measured advertised-and-dead overrides |
| a JSON writer for the capture artifact | hand-rolled | **aeson, in the executable only** | Exactly what `app/StoreConformance.hs` does: the report is *a description of an experiment*, never an artifact byte, and BYTE-03's scan is scoped to the library's storage modules for that reason |
| a temp directory | `mktemp(1)` via a subprocess | `createDirectory` under `getTemporaryDirectory`, `bracket`ed | The isolation mechanism must not sit behind the surface being isolated; and `createDirectory`'s exclusivity is the property that matters |

**Key insight:** every one of these already exists in this repository, written for a reason that is
documented in the module that holds it. The phase's novel content is the *invocation contract*, not
the plumbing.

---

## Common Pitfalls

### Pitfall 7 (owned): version detection that succeeds emptily

`.planning/research/PITFALLS.md` #7. This phase's realisations, all measured: stderr is **empty**
under both `--version` and a normal run (M1a, M6); the no-argument help banner **exits 0** with three
version strings (M1b); `gams audit` reports **GAMSX**, a different component (M2); and CONOPT has two
plausible decoys (M3). Answer: an abstract newtype, a job-name-anchored parse, and a garbage battery
whose members are real captured output.

### Pitfall 8 (owned): exit `0` means "GAMS ran"

`action=c` exits 0 with no artifact — measured with the real binary (M5). The conjunct list is:
exit 0 → the artifact exists in the **fresh** run directory → its mtime ≥ process start → it is a
JSON value (`Store.Json`) → `length dQx == length dQM == nEvents` → every echoed input field equals
the argv token that was sent. Only then is anything an artifact.

### Pitfall 11 (owned): pipe deadlock, missing timeout, leaked environment

All three measured (M9, M10). Two are closed at +0 packages; the third — the **grandchild** — is the
one that survives a naive test.

### Pitfall 4 (partial): the model source digest

PITFALLS #4 recommends `model_source_digest` over the sorted `(path, sha256)` of every `.gms` the run
reads. That is KEY-01 (Phase 25), but **the file set is only knowable here**, because this phase is
what resolves the model path and runs it. Recommendation: `Gams.Invoke` returns the sorted
`(path, sha256)` list as part of `ToolchainIdentity`; Phase 25 hashes it. `volume_path.gms` has no
`$include` today — verify at plan time rather than assume, and make the *list* the deliverable so a
future include is covered automatically.

### New, phase-local: the argv token reaches the bytes

M7. Two logically identical shocks, two different artifacts, exit 0 both times, every §4 gate green.
The renderer is a Phase-24 deliverable and its canonical form is a decision of record.

### New, phase-local: `NOT NULL` is not non-empty

M14. The schema will store `''`. The Haskell smart constructor is the real guard; migration `003`
with a `check` is the recommended defence-in-depth, and it is **not free** — see Wave 0.

### New, phase-local: the BYTE-03 scan's scope must GROW

`aeson_storage_path` (`offchain/test/Main.hs:7082`) is a hardcoded list of eight files with **no
both-directions assertion against the directory**. Phase 23's own record says `Store/Schema.hs` sat
unlisted for two commits. `Gams/Artifact.hs` is on the artifact path and must be added — and the
better fix is a check that the list *equals* the set of modules under `offchain/lib/{Store,Gams}/`
minus an explicit, reasoned exemption list, so the next module cannot be silently exempt.

---

## Code Examples

### Reading the version out of the run that produced the bytes (GAMS-03)

```haskell
-- Source: MEASURED, /tmp/.../r1/volume_path.log line 1, this machine, 2026-08-16
-- --- Job volume_path.gms Start 08/16/26 15:52:25 54.1.0 37378ce0 LEX-LEG x86 64bit/Linux
--
-- Anchored on the JOB NAME so the two exit-0 wrong-subject banners are rejected:
--   "--- Job ? Start …"          the no-argument help banner  (exit 0, version present 3x)
--   "--- Job --version Start …"  the flag                     (exit 6)
parse_gams_version :: String -> ByteString -> Either VersionError GamsVersion
```

### Rejecting both CONOPT decoys (GAMS-04)

```
TRUE   "    C O N O P T   version 4.39.0"                                       -> ACCEPT "4.39.0"
DECOY  "CONOPT 4         54.1.0 37378ce0 Jun 15, 2026          LEG x86 64bit/Linux"
                                                                                -> REJECT
DECOY  "libconopt464.so"                                                        -> REJECT
```

The accept rule is the spaced-letter form (`C O N O P T`) followed by `version` and a dotted triple.
Both decoys contain the token `CONOPT`; only the true line contains the spaced form.

### The BYTE-04 golden vector (BYTE-04)

```haskell
-- Source: offchain/rig/volume-path-golden.json, sha256 asserted FIRST from
-- Store.Types.volume_path_golden_sha256, then decoded by the function under test.
golden_dqx :: [Integer]
golden_dqx =
  [ -2613128317657530400, -2680707973111378000,  4861675431041821000,  4608884887749073000
  ,  4529439681209106400, -2884368647455834000, -2898559031733104600, -2923236030042153000 ]

-- MEASURED: fromIntegral (head golden_dqx) :: Double, rounded back, is EXACTLY
--   -2613128317657530368        -- |delta| = 32 wei, an EQUALITY on Integers, not a bound
-- and ALL SIXTEEN elements of dQx ++ dQM differ under Double, |delta| in [4, 328].
```

### The invocation, whole (GAMS-01/02/05/06)

```
/usr/bin/timeout -k 5 <budget>                                  # owns the process GROUP
  /usr/gams/gams54.1_linux_x64_64_sfx/gams                      # ABSOLUTE, no PATH shadow
  <abs>/volume_path.gms  action=ce  curdir=<fresh temp dir>  lo=2
  --sqrtPriceX96=<canonical>  --liquidityRaw=<canonical>  --txlVolumeRate=…  --phiXpips=…
  --phiMpips=…  --volTgtWad=…  --nEvents=…
env = Just [ ("PATH","/usr/bin"), ("HOME",<home>), ("LC_ALL","C") ]      # MEASURED sufficient
```

With `lo=2`, **stdout and stderr are both 0 bytes** and the log is `<dir>/volume_path.log` (M6) —
which is where the banners are read from, and which removes the locale-decode hazard on the streams
entirely. If the plan prefers `lo=3` (everything on stdout, ~3–7 KB), note the streams become
`String` under `process` and `typed-process`'s +2 becomes worth reconsidering.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | **None, by design.** A hand-rolled `exitcode-stdio-1.0` runner: `data Check = Check { check_name :: String, check_run :: IO (Either String ()) }` (`offchain/test/Main.hs:421`), `guarded` at `:427`, `pure_check` at `:434`. Every check runs; the process exits non-zero if any failed |
| Config file | `cfmm-replicationPlank-rpc-api.cabal`, `test-suite cfmm-replicationPlank-rpc-api-test` (line 224) |
| Registration point | `core_checks :: IO [Check]` (`offchain/test/Main.hs:7210`). **A check not in this list does not exist** and the sentinel harness cannot re-run it |
| Quick run command | `cabal build --enable-tests -j all` — `--enable-tests` is load-bearing; the bare form exits 0 without compiling the suite |
| Full suite command | `cabal test` |
| Hard gates | zero `-Wall` warnings under `offchain/`; suite DB-free (the three-token grep over `Main.hs` = 0) **and now GAMS-free** (a new grep) |
| Baseline | **111/111** at the end of Phase 23 (`STATE.md`), wall **97 s** (budget 900 s). **RE-MEASURE cold at plan time** |
| Subprocess precedent | The suite **already** spawns subprocesses: `purge_scan` and `aeson_scan` both call `readProcessWithExitCode "grep"`. Tier-B stub checks are therefore an extension of an existing idiom, not a new capability |

**No new test file.** Phase 24 extends `offchain/test/Main.hs`. Deviating would put checks outside
`core_checks`, where the sentinel harness cannot reach them.

**The three tiers, for this phase:**

| Tier | What runs | Needs live GAMS? |
|---|---|---|
| **A** | pure functions and source scans — parsers, the garbage battery, the taxonomy, the renderer, the golden vector, the absence greps | **No** |
| **B** | real subprocesses inside `cabal test`, against **shell stubs the check writes into its own temp directory** — exit codes, missing artifact, stale artifact, 2 MB stderr, the hung grandchild, the environment vector | **No** |
| **C** | assertions over the committed `offchain/rig/gams-conformance.json`, produced out-of-band by `offchain/rig/capture-gams-conformance.sh` | **Only for the capture** |

### Requirement → Test Map

| Req | Check name | Lives in | Tier | The input that makes it FAIL | Needs live GAMS? |
|---|---|---|---|---|---|
| **GAMS-01** | `gams_exit_taxonomy_is_total_and_disjoint` | `Gams.Exit` + `pure_check` | A | Classifying `7` (licensing) or `6` (parameter) as model-level, i.e. as an infeasibility verdict; or any code falling through to a catch-all `Solved` | No |
| **GAMS-01** | `gams_verdict_ignores_the_streams` | `offchain/test/Main.hs`, `aeson_scan` idiom | A | The scan matching `infeasible`, `optimal`, `Locally`, `Normal completion`, `isInfixOf`, `Status:` in `offchain/lib/Gams/{Exit,Invoke}.hs`. **Positive control mandatory** — the pattern must be SHOWN matching a seeded bait file | No |
| **GAMS-01** | `stub_exit_codes_drive_the_verdict` | `offchain/test/Main.hs`, stubs in a temp dir | B | A stub exiting `2`/`3`/`7`/`124` that the layer reports as success; or two stubs with the **same** exit code and different stdout producing **different** verdicts | No |
| **GAMS-01** | `gams_conformance_records_the_measured_exit_codes` | `Main.hs` over `gams-conformance.json` | C | The artifact recording anything other than `{clean:0, compile_error:2, abort:3, exec_error:3, missing_file:6, no_args:0, action_c:0}`. A missing key is a SET mismatch, never a shorter list | Capture only |
| **GAMS-02** | `exit_zero_without_artifact_is_refused` | `Main.hs`, stub | B | A stub that exits 0 and writes nothing being accepted. **This is the check that fails if exit 0 is the only conjunct** | No |
| **GAMS-02** | `a_pre_existing_artifact_is_unreachable` | `Main.hs`, stub | B | Planting a valid-looking `volume_path.json` (the real 606 golden bytes) at the *caller's* CWD and at a fixed path, then running a stub that exits 0 writing nothing — acceptance means the layer read someone else's file | No |
| **GAMS-02** | `each_invocation_gets_a_fresh_directory_and_it_is_removed` | `Main.hs` | B | Two invocations resolving to the same directory; or the directory surviving after **either** outcome, success or abort | No |
| **GAMS-02** | `artifact_postconditions_reject_a_short_array` | `Gams.Artifact` + `pure_check` | A | A payload with `length dQx /= nEvents`, an empty `dQx`, or a non-JSON body being accepted. `Store.Json.is_json_value` is the recogniser | No |
| **GAMS-02** | `gams_conformance_records_action_c_exit_zero_with_no_artifact` | `Main.hs` over the artifact | C | The artifact recording an artifact present under `action=c`, or an exit other than 0 — either means the exhibit stopped exercising the case (MEASURED: exit 0, `volume_path.json` ABSENT) | Capture only |
| **GAMS-03** | `gams_version_parser_rejects_the_garbage_battery` | `Gams.Version` + `pure_check` | A | Accepting any battery member: `""`, `"\n"`, `"   \t "`, the **real 1239-byte no-argument help banner** (exit 0, `54.1.0` present 3×), the **real 275-byte `--version` output**, the `gams audit` GAMSX line, a localised banner, or a banner truncated before the version field | No |
| **GAMS-03** | `gams_version_is_not_constructible_empty` | `Gams.Version` (compile) + a scan | A | Exporting the `GamsVersion`/`ConoptVersion` constructor; or the scan finding `fromMaybe`, `<|> pure ""`, `catch (\_ -> return "")`, `"unknown"` under `offchain/lib/Gams/`. Positive control required | No |
| **GAMS-03** | `version_detection_failure_aborts_the_invocation` | `Main.hs`, stub | B | A stub that exits 0, writes a **valid** artifact, and writes a log with **no banner** — acceptance means a run completed with an empty version component. Must return `Aborted`, naming the missing banner | No |
| **GAMS-03** | `gams_conformance_records_the_resolved_binary_and_its_digest` | `Main.hs` over the artifact | C | `gams_path` not absolute, `gams_sha256` not 64 bare hex, `gams_size` ≤ 0, or the recorded version not matching `gams_version` elsewhere in the artifact. **Shape and cross-consistency, never the machine-specific value** | Capture only |
| **GAMS-04** | `conopt_parser_rejects_both_decoys` | `Gams.Version` + `pure_check` | A | Accepting `CONOPT 4         54.1.0 37378ce0 Jun 15, 2026 …` (the link version) or `libconopt464.so` (the shared object); or **rejecting** `    C O N O P T   version 4.39.0`. All three are real strings captured today | No |
| **GAMS-04** | `conopt_parse_is_position_independent` | `pure_check` | A | Feeding the true line at index 38 (probe) and at index 47 (real run) inside otherwise-identical buffers and getting different answers — i.e. any positional or line-number logic | No |
| **GAMS-04** | `gams_conformance_records_conopt_and_the_method_that_found_it` | `Main.hs` over the artifact | C | `conopt_version` ≠ `4.39.*`; `conopt_method` absent; or `conopt_link_version` **equal** to `conopt_version` — equality means the exhibit lost the decoy it exists to distinguish | Capture only |
| **GAMS-05** | `a_stderr_flood_completes_without_deadlock` | `Main.hs`, stub | B | A stub writing **> 1 MB to stderr** (MEASURED at 2,000,000 bytes) hanging, or the check timing out. An implementation that waits before draining fails here | No |
| **GAMS-05** | `a_hung_grandchild_is_terminated_and_reaped` | `Main.hs`, stub | B | **The stub MUST be a grandchild** (`sleep N & echo $! > pidfile; wait`), not a direct child. FAIL input: a direct-child-only kill leaves `ps -p <grandchild>` exiting 0 with `PPID 1`. MEASURED: this is precisely what `terminateProcess` alone does | No |
| **GAMS-05** | `a_timed_out_run_yields_Aborted_and_no_artifact` | `Main.hs`, stub + compile | B + compile | The stub timing out and the layer returning `Produced`; or a `ProverOutcome -> ProverArtifact` total accessor existing (**Correction 1** — a compile error, the `DerivedDoc` idiom) | No |
| **GAMS-05** | `timeout_codes_do_not_collide_with_gams_codes` | `pure_check` | A | `124` or `137` appearing in the GAMS taxonomy's domain, checked against the **mod-256 images** of the official table (`141/144/145/146` included) | No |
| **GAMS-06** | `the_child_environment_is_exactly_the_whitelist` | `Main.hs`, stub printing its own env | B | Spawning with `env = Nothing`; or the whitelisted child's environment differing from `Gams.Env.whitelist` **as a SET** in either direction. (**Correction 2**: this is the honest form of "inheriting differs") | No |
| **GAMS-06** | `an_inherited_environment_is_observed_to_differ` | `Main.hs`, same stub | B | The inherited child's environment **not** being a strict superset, i.e. failing to name at least one variable the whitelist excludes. A whitelist that silently fell back to inheritance is caught here | No |
| **GAMS-06** | `the_whitelist_pins_LC_ALL_C_and_admits_no_GAMS_variable` | `Gams.Env` + `pure_check` | A | `LC_ALL` absent or ≠ `C`; any key matching `GAMS*`, `GDX*`, `CONOPT*`, `LC_NUMERIC`, `LANG` present | No |
| **GAMS-06** | `argv_rendering_is_canonical_and_total` | `Gams.Argv` + `pure_check` | A | A leading zero, an exponent form, a `+` sign, or whitespace surviving into the argv token; a `Maybe` or defaultable field in the input record; any `show`/`printf` on a floating value on the path. **M7 is the motivating measurement** | No |
| **GAMS-06** | `gams_conformance_records_byte_identity_under_a_hostile_environment` | `Main.hs` over the artifact | C | The artifact's `hostile_env_sha256` ≠ `golden_sha256`; or `hostile_env_vars` being **empty** — an empty hostile set makes the exhibit vacuous. MEASURED with `GAMSTHREADS=8 GDXCOMPRESS=1 LC_NUMERIC=de_DE.UTF-8 GAMSDIR=/nonexistent` | Capture only |
| **GAMS-06** | `gams_conformance_records_the_minimal_whitelist_reproducing_the_golden_bytes` | `Main.hs` over the artifact | C | `whitelist_sha256` ≠ `golden_sha256`, or the recorded whitelist containing a variable `Gams.Env` does not name | Capture only |
| **BYTE-04** | `dqx_double_decode_loses_exactly_32_wei_on_the_first_element` | `Main.hs` / `Gams.Artifact` | A | `Double`-decoding `dQx[0]` and getting anything other than `-2613128317657530368` — an **equality**, so no tolerance can absorb it; or `Integer` decode differing from the pinned exact list on any of the 16 elements | No |
| **BYTE-04** | `every_golden_element_is_inexact_under_double` | `pure_check` | A | Fewer than **16 of 16** elements differing (MEASURED: |Δ| ∈ [4, 328]). Catches a decoder that widened only one field | No |
| **BYTE-04** | `the_golden_vector_comes_from_the_committed_artifact` | `Main.hs` | A | `sha256(offchain/rig/volume-path-golden.json)` ≠ `Store.Types.volume_path_golden_sha256`, asserted **before** the decode; or the decoded list ≠ the pinned `[Integer]` list. Both sides pinned, tied to the real file by its digest | No |
| **BYTE-04** | `the_artifact_decoder_refuses_a_non_integer_token` | `Gams.Artifact` + `pure_check` | A | `1.5`, `2.8e19`, `1e3`, `-0`, `007` or an empty array element being accepted into `dQx` | No |
| **BYTE-04** | `no_Double_and_no_aeson_on_the_artifact_path` | `Main.hs`, `aeson_scan` idiom **extended** | A | `Double`, `realToFrac`, `fromRational`, `Data.Aeson`, `toJSON`, `encode` appearing in `offchain/lib/Gams/Artifact.hs`; **and** `Gams/Artifact.hs` missing from the scan's file list | No |
| **BYTE-04** | `the_artifact_path_scan_covers_every_module_on_it` | `Main.hs` | A | A module under `offchain/lib/{Store,Gams}/` present on disk but absent from both the scan list and an explicit reasoned exemption list. **This is the "scope failed to GROW" fix** — Phase 23 measured `Store/Schema.hs` unlisted for two commits | No |

### Every guard, and the input that makes it fire

A guard never seen to reject is the empty-log finding. One row per guard; **no row says "invalid
input"** — each names an exact value, and every value marked MEASURED was captured on this machine
today.

| # | Guard | The exact input that makes it fire | Observation |
|---|---|---|---|
| 1 | GAMS version parser — empty | `""` | `Left EmptyVersion`. The `"" == ""` defect, verbatim |
| 2 | GAMS version parser — whitespace | `"\n"`, `"   \t  \n"` | `Left EmptyVersion` — a non-empty string that carries no information |
| 3 | GAMS version parser — **wrong subject, exit 0** | the real **1239-byte, 27-line** no-argument help banner, line 1 `--- Job ? Start 08/16/26 16:01:42 54.1.0 37378ce0 …` | `Left WrongJob "?"`. **MEASURED: exit 0, version present three times.** The strongest member |
| 4 | GAMS version parser — the flag's own output | the real **275-byte** `gams --version` stdout, line 1 `--- Job --version Start … 54.1.0 …` | `Left WrongJob "--version"`. MEASURED exit **6**, stderr **0 bytes** |
| 5 | GAMS version parser — wrong component | `GAMSX            54.1.0 37378ce0 Jun 15, 2026          LEG x86 64bit/Linux    ` (`gams audit`, exit 0) | `Left`. GAMSX is a component, not the base module |
| 6 | GAMS version parser — truncated | `--- Job volume_path.gms Start 08/16/26 15:52:25` (banner cut before the version field) | `Left MissingVersionField` |
| 7 | GAMS version parser — localised/foreign | a banner with the fields translated / reordered | `Left`. Synthetic, and labelled synthetic |
| 8 | GAMS version parser — **read from the wrong stream** | a stub writing the banner to **stderr** while stdout is empty, with the layer reading its configured stream | `Left`. MEASURED that the real tool leaves stderr at **0 bytes** in both modes, so a stderr reader gets `""` always |
| 9 | CONOPT parser — link-version decoy | `CONOPT 4         54.1.0 37378ce0 Jun 15, 2026          LEG x86 64bit/Linux` | `Left`. MEASURED present in every solve log |
| 10 | CONOPT parser — `.so` decoy | `libconopt464.so` | `Left`. MEASURED on disk beside `libconoptlu.so` |
| 11 | CONOPT parser — position independence | the true line at buffer index **38** and at index **47** | identical `Right "4.39.0"`. MEASURED at 38 (probe) and 47 (real run) |
| 12 | no empty version is constructible | export the `GamsVersion` constructor, or add `fromMaybe "unknown"` to `Gams/Version.hs` | compile error / scan red with a proven positive control |
| 13 | exit taxonomy — licensing | `ExitFailure 7` | `Environmental Licensing`, **not** an infeasibility verdict. Official table |
| 14 | exit taxonomy — curdir gone | `ExitFailure 145` (= `401` mod 256) | `Environmental` — the temp dir's own failure mode |
| 15 | exit taxonomy — ambiguity is recorded | `ExitFailure 3` | `ModelLevel ExecutionError`, **not** "a named abort" — MEASURED: `abort$` and `a = 1/0` both give 3 |
| 16 | verdict ignores streams | seed `isInfixOf "infeasible"` into `Gams/Invoke.hs` | scan red, positive control fired |
| 17 | **exit 0 with no artifact** | a stub that `exit 0`s and writes nothing; and, in the capture, **the real binary with `action=c`** | `Aborted NoArtifact`. MEASURED: real GAMS, exit 0, `volume_path.json` ABSENT |
| 18 | stale artifact is unreachable | plant the real 606 golden bytes at the caller's CWD, then run the exit-0-no-write stub | `Aborted NoArtifact` — the fresh `curdir` makes the plant unreachable. MEASURED that `curdir=<tmp>` relocates the put file |
| 19 | fresh directory | run twice and compare the two directory paths; then inspect after an `Aborted` | different paths; both removed |
| 20 | artifact post-conditions | an artifact with `nEvents: 8` and `dQx` of length 7 | `Aborted ShapeMismatch` |
| 21 | echoed-field cross-check | change one argv token after rendering (e.g. `sqrtPriceX96` + a leading zero) | the echoed field in the JSON no longer equals the token sent. **MEASURED: exit 0, all §4 gates pass, sha256 `d64a7b32…` vs golden `e7b14f38…`** |
| 22 | canonical argv renderer | `sqrtPriceX96 = 079228162514264337593543950336` | rejected/normalized before `execve`. Guard 21 is what it prevents |
| 23 | **stderr flood** | a stub writing **2,000,000 bytes** to stderr, 5 to stdout | completes, `err` length exactly 2000000. MEASURED with `process-1.6.26.1` |
| 24 | **hung grandchild** | `sh -c 'sleep 297 & echo $! > pidfile; wait'` | the grandchild must be **gone**. MEASURED: with `terminateProcess` alone it **survives** as `PPID 1`; with `/usr/bin/timeout -k 1` it dies and the wrapper exits **124** |
| 25 | timeout ⇒ no artifact | the same hung stub, with a valid artifact already written before it hangs | `Aborted TimedOut`; `Produced` must be unreachable (compile) |
| 26 | environment is the whitelist | spawn the env-printing stub with `env = Nothing` | the captured environment is a strict superset of the whitelist, naming an excluded variable |
| 27 | whitelist content | delete `LC_ALL` from `Gams.Env.whitelist`, or add `GAMSTHREADS` | pure check red |
| 28 | hostile ambient inertness | `GAMSTHREADS=8 GDXCOMPRESS=1 LC_NUMERIC=de_DE.UTF-8 GAMSDIR=/nonexistent`, absolute binary, `PATH=/usr/bin` | artifact sha256 still `e7b14f38…`. **MEASURED**. Firing input for the *check*: an empty hostile-variable set recorded in the artifact |
| 29 | **`Double` loses 32 wei** | `dQx[0] = -2613128317657530400` decoded as `Double` | exactly `-2613128317657530368`. **MEASURED**, an equality on `Integer`s |
| 30 | every element inexact | the 16-element `dQx ++ dQM` vector | 16 of 16 differ, \|Δ\| ∈ [4, 328]. Fewer than 16 ⇒ red |
| 31 | golden vector provenance | edit one byte of `offchain/rig/volume-path-golden.json` | the sha256 pin in `Store.Types` fires **before** any decode |
| 32 | non-integer token refused | `"dQx": [1.5]`, `[2.8e19]`, `[-0]` | `Left NotAnInteger` |
| 33 | no aeson / no `Double` on the artifact path | add `import Data.Aeson` or a `Double` field to `Gams/Artifact.hs` | scan red with a proven positive control |
| 34 | **scan scope grows** | add `offchain/lib/Gams/Publish.hs` without listing it | the directory-vs-list set check reddens naming the unlisted module. **The Phase-23 `Store/Schema.hs` finding, pre-empted** |
| 35 | capture freshness | edit `volume_path.gms` (or `Gams/Argv.hs`) without re-capturing | the recorded model-source digest ≠ the digest recomputed by the suite |
| 36 | capture completeness | truncate the capture mid-run | `gc_complete == False`, or the observation-name SET short — a SET, never a count (Phase 23 MEASURED a count passing a deletion) |
| 37 | `GAMS_CONFORMANCE` override | `GAMS_CONFORMANCE=/nonexistent-override-probe/GAMS_CONFORMANCE.json` | the consumer fails and the message CONTAINS that path. Registered in `advertised_overrides` |
| 38 | `GAMS_BIN` override | same probe shape | **Likely an `unprobed_overrides` entry with a written reason** — its consumer is the subprocess layer and `cabal test` is GAMS-free. Decide deliberately, following 23-05's `PGSTORE_DSN` precedent; do **not** manufacture a consumer in order to probe it |
| 39 | suite is GAMS-free | add `Gams.Invoke`, `gams`, or the absolute GAMS path to `offchain/test/Main.hs` | a token grep, the DB-free grep's twin, returns non-zero |
| 40 | sentinel harness | any leaf of `gams-conformance.json` that no check reads | reported as an **absorbed** pair, by name, with its sentinel |
| 41 | `sc3_literal_purge` | a `0x`-prefixed 64-hex digest in any new `.hs`/`.sh` under `offchain/` | grep exit 0. Write the binary digests **bare** |

### Sampling Rate

- **Per task commit:** `cabal build --enable-tests -j all`. `--enable-tests` is load-bearing;
  without it the command exits 0 without ever compiling the suite. The bare `cabal build -j all` is
  **VACUOUS and must never appear**.
- **Per wave merge:** `cabal test` — full `core_checks` + `sentinel_falsification_harness` — with
  **zero `-Wall` warnings** under `offchain/`, and both structural greps at 0 (no DB token, no GAMS
  token in `Main.hs`).
- **Phase gate:** full suite green; `-Wall` clean;
  `bash offchain/rig/capture-gams-conformance.sh` re-run from scratch producing an artifact whose
  observations are all `pass`; **every guard in the table above OBSERVED firing at least once with
  its named input**, recorded in a ledger in the phase summary in the shape of 23-05's
  nineteen-guard table. A guard with no observation is reported as a **phase-level finding**, named,
  not omitted (23-05's guard #13 precedent).
- **Do not** run the capture inside `cabal test`, and do not let any check invoke `gams`.
- **Budget note:** `cabal test` wall went 78 s → 97 s when Phase 23 added its fifth swept artifact.
  Tier-B stub checks each spawn a subprocess and one of them deliberately waits out a timeout —
  **keep the hung-child budget ≤ 2 s** and measure the new wall before and after.

### Wave 0 Gaps

No test *file* is created — the suite is one file and one runner. The gaps are registration points
and infrastructure, all of which must exist before the first assertion is written.

- [ ] `.cabal` library stanza — ~6 new `Gams.*` `exposed-modules`; **no new package** if `process`
      and a hand-rolled temp directory are chosen. If `temporary` or `typed-process` is adopted,
      MEASURE the delta by `plan.json` set-diff against the current **158** and record it in the
      existing comment discipline (lines 107–115) — `typed-process` is **+2**, MEASURED
- [ ] `.cabal` — a new `executable gams-conformance` stanza in the `store-conformance` family, with
      `aeson` **in the executable only** (it writes the report, never an artifact byte)
- [ ] **Decide the temp-directory mechanism** (`directory`-only hand-roll vs `temporary`) before the
      first plan writes `Gams/Invoke.hs`; `withSystemTempDirectory` is **not** in the build plan
- [ ] **Decide `lo=2` (log to file, streams 0 bytes) vs `lo=3` (everything on stdout)** — it decides
      whether the version parse reads a file or a stream, and therefore whether `typed-process`'s
      `ByteString` streams are worth +2 packages
- [ ] **Decide migration `003`** adding `check (length(gams_ver) > 0 and length(conopt_ver) > 0)`.
      Recommended. **Not free:** it moves `Store.Schema.expected_migrations`, requires a re-capture
      because the freshness oracle recomputes migration md5s from the directory, and adds a `.sql`
      to the purge scan
- [ ] `offchain/lib/Gams/Config.hs` — `GAMS_BIN`, `GAMS_MODEL`, `GAMS_CONFORMANCE` in the
      `Store.Config` idiom (named once, no literal credentials, and **no path literal in the prose**
      that would trip `no_credential_is_present_in_a_tracked_file`)
- [ ] `offchain/test/Main.hs` — new entries in `advertised_overrides` (`:3639`) and/or
      `unprobed_overrides` (`:3785`) with written reasons, following 23-05's `PGSTORE_DSN` ruling.
      **Do not manufacture a consumer in order to make a probe pass**
- [ ] `offchain/test/Main.hs` — `gams-conformance.json` added to `swept_artifacts` (`:5228`) **and**
      a new `artifact_field_floors` entry (`:5705`), both **MEASURED, never incremented**. Budget:
      the harness re-runs `core_checks` once per (leaf × 6 sentinels); Phase 23's 134-leaf artifact
      added 793 pairs and 19 s of wall. **Design `gams-conformance.json` NARROW** — every leaf either
      asserted or pardoned in `absorbed_by_design` (`:5517`) with a written reason
- [ ] `offchain/test/Main.hs` — `sentinel_pair_floor` (`:5695`, currently **3250**) **RE-MEASURED** by
      raising it until the harness reports what it reached
- [ ] `offchain/test/Main.hs` — `purge_file_floor` (`:916`, currently **48**) **RE-MEASURED**: this
      phase adds ~6 `.hs` + 1 app `.hs` + 1 `.sh` (+1 `.sql` if migration 003 lands), all scanned
      types. `credential_scan_floor` (`:6917`, currently **56**) likewise
- [ ] `offchain/test/Main.hs` — `aeson_storage_path` (`:7082`) extended with `Gams/Artifact.hs`,
      **plus** the new both-directions directory-coverage check (guard 34)
- [ ] `offchain/test/Main.hs` — the new **GAMS-free** structural grep, the DB-free grep's twin
- [ ] `offchain/test/Main.hs` — ~25 new `Check` values wired into `core_checks` (`:7210`). **A check
      not in this list does not exist**
- [ ] A **stub-writing helper** in `Main.hs`: writes an executable `sh` script into a temp directory
      and returns its path. Every Tier-B check uses it; the stubs are **built, not committed**, for
      the same reason `aeson_bait_source` and `purge_control_literal` are built — a committed stub
      that spelled a version banner would be found by the very scans it exists to exercise
- [ ] `offchain/rig/capture-gams-conformance.sh` — the `capture-store-conformance.sh` idiom: refuses
      to emit a partial artifact, names `gams` when it is absent, runs in scratch directories, and
      **never writes into `model/`**. `CFMM_REQUIRE_GAMS` belongs **here**, never in `cabal test`
      (23-RESEARCH's `CFMM_REQUIRE_DB` ruling, verbatim: gating the suite on it fails open)
- [ ] `offchain/rig/gams-conformance.json` — committed evidence
- [ ] **The CONOPT probe model.** An 8-line `.gms` written by the capture into its own scratch
      directory (**not** committed under `model/`, which is another workstream's territory)
- [ ] `.github/` — no change needed and none should be made: nothing in `cabal test` invokes GAMS.
      The `haskell` gate job has still never executed

---

## State of the Art

| Old approach | Current approach | Impact |
|---|---|---|
| `gams --version` to detect the version | the **job banner** of the run that produced the bytes, anchored on the job name | `--version` is parsed as a filename (exit 6); the no-arg form exits **0** with a plausible version and no model. MEASURED |
| `gams audit` for the solver version | an **8-line hermetic CONOPT probe**, or the production run's own log | `audit` reports **GAMSX**, a component. The probe costs 0.008 s and yields the true `4.39.0` |
| `readProcess` | `readProcessWithExitCode` / `readCreateProcessWithExitCode` | `readProcess` **throws** on non-zero exit, discarding the exit code GAMS-01 is about |
| `terminateProcess` as "the timeout" | `/usr/bin/timeout -k` (process **group**), or `create_group` + `signalProcessGroup` | MEASURED: the grandchild survives with PPID 1, and GAMS runs CONOPT as a separate process |
| `[Double]` for JSON numbers | `[Integer]`, hand-decoded | 32 wei on the first element; 16 of 16 elements inexact |
| `jsonb`/aeson anywhere near the artifact | `bytea` authoritative, hand-rolled recogniser | Settled in Phase 23; inherited here |

**Deprecated / does not exist:**
- `gams --version` — **not a flag.** It is an input filename.
- `withSystemTempDirectory` — in `temporary`, which is **not** in this build plan.
- A run-log table — **does not exist**; STORE-07 is Phase 25 (Correction 1).
- `cryptonite` — deprecated (last upload 2022-03-13); `crypton` is already resolved.

---

## Open Questions

1. **`lo=2` (log to a file, streams empty) or `lo=3` (everything on stdout)?**
   - Known: MEASURED, `lo=2` leaves stdout and stderr at **0 bytes** and writes an 89-line
     `volume_path.log` into `curdir`; `lo=3` puts ~3 KB on stdout with stderr still empty.
   - Unclear: whether the plan prefers parsing versions from a file (no locale-decode hazard, +0
     packages) or from a stream (nothing to clean up, but `String` decoding under `process`).
   - Recommendation: **`lo=2`**, read `volume_path.log` with `Data.ByteString.readFile` from the
     fresh directory. It keeps `process` at +0 and removes the decode hazard entirely.

2. **`/usr/bin/timeout` or a Haskell process-group kill?**
   - Known: both MEASURED killing the grandchild; `timeout(1)` exits 124; the Haskell bracket shape
     around `waitForProcess` **hung** in my probe.
   - Unclear: whether depending on a coreutils absolute path is acceptable to this project.
   - Recommendation: `timeout(1)` primary, a Haskell `System.Timeout.timeout` at `budget + slack` as
     the backstop, and **the grandchild stub as the test** either way.

3. **Does migration `003` land in this phase?**
   - Known: `NOT NULL` does not forbid `''` (M14); a `check` is three words of SQL.
   - Unclear: whether the cost (a re-capture, `expected_migrations`, `purge_file_floor`) is worth it
     when the Haskell guard is the primary defence.
   - Recommendation: **yes** — the phase is already moving those floors, and the database is the
     layer that outlives every Haskell refactor.

4. **Does `volume_path.gms` `$include` anything?**
   - Known: none seen in the sections read; the file is a single self-contained model.
   - Unclear: whether it will stay that way — it is under active development in another worktree.
   - Recommendation: make the deliverable the **sorted `(path, sha256)` list**, not a single digest,
     so a future include is covered without a code change. Verify at plan time.

5. **`GAMS_BIN` — `advertised_overrides` or `unprobed_overrides`?**
   - Known: `probe_override`'s third arm requires the *consumer* to fail naming the value, and this
     phase's consumer is the subprocess layer, which `cabal test` may not reach.
   - Recommendation: follow 23-05's `PGSTORE_DSN` ruling — an **asserted `unprobed_overrides` entry
     with a written reason**, plus the two halves that are measurable (verbatim resolution,
     differs-from-default). **Never** write a consumer whose only purpose is to be probed.

6. **The production `nEvents`** (`VOLUME_PATH.md` §6 ruling 1, fixture 8) is still open, and
   `fj.pw = 4000` bounds it at **N ≈ 174–180** before the put line wraps. Not this phase's ruling,
   but this phase's argv renderer is where it becomes concrete — and Phase 25 cannot freeze the key
   before it is answered.

---

## Sources

### Primary — executed on this machine today (HIGH)

- `/usr/gams/gams54.1_linux_x64_64_sfx/gams` (54.1.0, build `37378ce0`, demo licence):
  `--version` (exit 6, 275 B stdout, 0 B stderr); no-argument help banner (exit 0, 1239 B, 27 lines);
  `gams audit` (GAMSX); exit codes 0/2/3/3/6 across five crafted inputs; `action=c` exit 0 with no
  artifact; five real `volume_path.gms` runs under `curdir=<temp>` with the golden sha256; the
  leading-zero rendering producing `d64a7b32…`; `28e18` vs `2.8e19` byte-identical; four env
  configurations including `env -i` with hostile variables; the 8-line CONOPT probe (`lo=2` and
  `lo=3`) reproducing all three version candidates
- `process-1.6.26.1` via `cabal exec -- runghc`: the 2,000,000-byte stderr drain; `timeout` +
  direct-child reap (no orphan); `timeout` + **grandchild survival at PPID 1**; a process-group
  SIGKILL removing the grandchild; `/usr/bin/timeout -k 1 2` exit **124** with the grandchild gone
- `cabal build --enable-tests -j all --dry-run` + `plan.json` set-diff: baseline **158**,
  `typed-process` **160** (`typed-process-0.2.13.0`, `unliftio-core-0.2.1.0`); `.cabal` restored
  sha256-identical
- `offchain/rig/volume-path-golden.json` (606 B, `e7b14f38…07d0d884`, tail `5d 0a 7d 0a`): the
  16-element `Double`-vs-`Integer` truncation table
- `sha256sum` of the `gams` executable and `libconopt464.so`; `locale -a` (four locales, no
  comma-decimal)

### Primary — these repositories, read directly (HIGH)

- `.../cfmm-wt/gams/model/mev_tax_model_one/volume_path.gms` — `option nlp = conopt` (162),
  `option threads = 1` with its determinism comment (164-167), the §4 `abort$` gates (172-200),
  `file fj /volume_path.json/; fj.pw = 4000` (202), the `%sqrtPriceX96%`/`%liquidityRaw%`
  compile-time echoes (206-207), `dReal:0:10`/`rReal:0:10` (212-213)
- `.../cfmm-wt/gams/model/mev_tax_model_one/VOLUME_PATH.md` — §2 the seven inputs, §3 the output and
  the determinism guarantee, §4 every named abort, §6 the three open rulings
- `offchain/test/Main.hs` — `Check`:421, `guarded`:427, `pure_check`:434,
  `expected_selector_pins`:466, `purge_scanned_extensions`:883, `purge_known_extensions`:890,
  `purge_file_floor`:916, `advertised_overrides`:3639, `unprobed_overrides`:3785,
  `swept_artifacts`:5228, `absorbed_by_design`:5517, `sentinel_pair_floor`:5695,
  `artifact_field_floors`:5705, `expected_store_laws`:5916, `credential_scan_floor`:6917,
  `aeson_storage_path`:7082, `aeson_scan`:7100, `aeson_is_absent_from_the_storage_path`:7157,
  `main`:7190, `core_checks`:7210
- `offchain/lib/Store/{Types,Config,Class,Schema,Json}.hs` — the abstract-newtype idiom, the
  named-once env-var convention, the record-of-functions seam, the pure manifest, the hand-rolled
  total JSON recogniser
- `offchain/migrations/001_model_run.sql` — `gams_ver`/`conopt_ver` `text not null` (M14), the
  `(model, key_scheme, key)` constraint
- `offchain/rig/capture-store-conformance.sh`, `offchain/rig/deploy-rig.sh:344-405` (the prefix env
  scrub), `cfmm-replicationPlank-rpc-api.cabal`

### Secondary — settled prior research, cited not re-derived (HIGH)

- `.planning/research/SUMMARY.md`, `PITFALLS.md` (#4, #5, #7, #8, #11), `.planning/ROADMAP.md`
  Phase 24 §, `.planning/REQUIREMENTS.md`, `.planning/STATE.md`
- `.planning/phases/23-postgres-foundation-byte-exact-schema/23-RESEARCH.md` and `23-05-SUMMARY.md`
  — the tier design, the guard-ledger discipline, the `CFMM_REQUIRE_DB` relocation ruling, the
  `PGSTORE_DSN` unprobed-override ruling, the SET-not-count finding, the floor re-measurement rule

### External (MEDIUM — official docs)

- GAMS *Return Codes and Their Meanings* — the full code table and the warning that a return code
  says nothing about the model inside the job

---

## Metadata

**Confidence breakdown:**

- **GAMS behaviour (exit codes, banners, artifact placement, argv echo, environment):** **HIGH** —
  every claim executed against the real 54.1 binary and the real model today, with transcripts above.
- **CONOPT detection:** **HIGH** — all three candidates reproduced side by side, twice, at different
  buffer positions. This closes `.planning/research/SUMMARY.md`'s open question 1, which was LOW.
- **Subprocess mechanics:** **HIGH** for the drain, the direct-child reap, the grandchild survival
  and the `timeout(1)` group kill (all executed). **MEDIUM** for the exact Haskell bracket shape
  around a group kill — one probe hung and the shape must be OBSERVED, not inherited from this
  document.
- **BYTE-04:** **HIGH** — computed from the committed golden artifact, all 16 elements.
- **Package deltas:** **HIGH** — `plan.json` set-diff, `.cabal` restored byte-identically.
- **Validation architecture:** **HIGH** for the mechanism — every instrument (pure checks, source
  scans with positive controls, subprocess spawning, committed-artifact assertions, the sentinel
  sweep, SET-not-count) already runs in this repository with proven controls. **MEDIUM** for the
  floors, counts and wall-clock budget, which are tree-derived and **must be RE-MEASURED at plan
  time**.
- **The two SC corrections:** **HIGH** — Correction 1 is a directory listing (no run-log table
  exists); Correction 2 is four measured configurations plus `locale -a`.

**Research date:** 2026-08-16
**Valid until:** ~2026-09-15 for the GAMS/CONOPT facts (a toolchain upgrade invalidates every
version string and possibly the exit codes) and for the package deltas. The tree-derived numbers —
`purge_file_floor` 48, `credential_scan_floor` 56, `sentinel_pair_floor` 3250, the 111/111 suite
count, the 97 s wall, the 158-package baseline — **go stale on any commit** and are re-measured, not
inherited.
