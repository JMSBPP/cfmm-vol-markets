---
phase: 27-anvil-read-layer
plan: 02
subsystem: chain-read
tags: [chain-02, chain-03, block-pinning, refusals, zero-word-trap, out-of-band-capture, chain-free-grep]

# Dependency graph
requires:
  - phase: 27-anvil-read-layer
    plan: 01
    provides: "Chain.Endpoint / offchain/rig/endpoint.sh -- the one endpoint rule both new sites resolve through; the 15-entry endpoint_sites manifest, which caught all three of this plan's new files on their first run; and the standing rule that a mutation baseline is RE-TAKEN after every intentional edit"
  - phase: 26-shock-assembly-fee-split-event-decode
    plan: 04
    provides: "purge_file_floor / credential_scan_floor and the re-measure-by-RUNNING-find discipline"
  - phase: 22-live-stochastic-drivers
    provides: "deploy-rig.sh's swappable v4 pool, CheatSwap.Types.pool_state_slot, CheatSwap.Rpc.anvil_set_storage_at, and the capture-script shape (preconditions, artifact preservation, value gates)"
provides:
  - "Chain.Read: BlockRef as a newtype with ONE constructor, every read taking it positionally, and a PURE refusal rule that names the field it is about"
  - "three offline checks: no_read_can_omit_its_block, latest_appears_nowhere_in_the_read_layer, a_zero_or_absent_read_is_refused_by_field_name"
  - "the_suite_never_reaches_a_chain -- the THIRD structural grep beside DB-free and GAMS-free, with a proven positive control"
  - "offchain/app/ChainReadConformance.hs + offchain/rig/capture-chain-read.sh + the committed chain-read-conformance.json: CHAIN-02's observational half"
  - "the_pinned_read_held_while_the_unpinned_read_moved, asserting over that artifact including unpinned_differs == true"
  - "CHAIN_READ_CONFORMANCE, probed in advertised_overrides, so the artifact check is falsifiable without damaging the evidence"
  - "the measurement that anvil_setStorageAt writes into the state OF THE CURRENT HEAD rather than creating a block"
affects: [27-03, 28]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "A decoy a check compares against must be BUILT BY THE FUNCTION UNDER TEST -- a hand-spelled one tests the check's own literal and passes by construction"
    - "A newtype with one constructor makes an absence-scan honest rather than aspirational: the forbidden state is not avoided, it is inexpressible"
    - "A capture that constructs a divergence must record BOTH 'the chain moved' and 'the two reads came apart' -- neither implies the other, and only the second is the defect"
    - "A cheat aimed at a local node is not a block: it lands in the head's state, so a read pinned at the head is not isolated from it"
    - "A positive control built from a COPY OF THE SUBJECT beats a three-line bait: it fires first and says which arm saw the token"
    - "A structural grep's tokens are not interchangeable -- measure which one guards a state reachable in one line of source and which needs a .cabal edit"

key-files:
  created:
    - offchain/app/ChainReadConformance.hs
    - offchain/rig/capture-chain-read.sh
    - offchain/rig/chain-read-conformance.json
  modified:
    - offchain/lib/Chain/Read.hs
    - offchain/lib/Chain/Endpoint.hs
    - offchain/test/Main.hs
    - cfmm-replicationPlank-rpc-api.cabal

decisions:
  - "The capture is an EXECUTABLE and not only a shell script, because Chain.Read's wiring half (read_pool_field, read_raw_word_token, block_param) is unreachable from cabal test by construction and an unexercised surface is this package's advertised-and-dead shape -- measured three times at 22-03, 22-04 and 22-07"
  - "The endpoint is deliberately NOT recorded in the artifact: it would be a third statement of the authority, committed, inside the endpoint census's blast radius. chainId is recorded instead and asserted against the manifest before any write"
  - "chain-read-conformance.json is DECLARED a Transcript endpoint site rather than argued out of the census -- its provenance note names the shell resolver, and 27-01's rule is that prose inside a grep's radius is declared, never exempted"
  - "The artifact has an override (CHAIN_READ_CONFORMANCE) and is NOT in the sentinel sweep. Recorded in unswept_artifacts as a STATED GAP with its reason rather than left silent, and that list's haddock now states the reason per entry instead of one blanket claim that would have been false for this member"
  - "measured_pre_pool_block moved 5 -> 7 because 5 was WRONG: at block 5 the manager has no code and the answer is the bare 0x marker, a different diagnosis from an all-zero word"

metrics:
  duration: ~5h (including the interrupted first session)
  tasks: 4
  completed: 2026-08-22
---

# Phase 27 Plan 02: The pinned read layer — Summary

CHAIN-02 and CHAIN-03 retired: a pin the type cannot omit and cannot express the moving head, five
refusals that name their field delimited, and a live capture in which a read pinned at block 13
returns the block-13 word while the unpinned read returns the one the state change wrote — 203/203,
exit 0, and `cabal test` still opens no socket, now asserted by a third structural grep.

## What this plan was resuming, and what did not survive re-measurement

Task 1 was committed (`596ed38`). Task 2's work was on disk and **uncommitted, and internally
inconsistent**: `Chain/Read.hs` carried a new `refusal_naming_of` whose haddock explained that the
suite's decoy *must* be built by it — while `Main.hs` still hand-spelled the decoy and
`refusal_naming_of` was **not exported**. The refactor had been reasoned about and not finished.

The instruction was to re-measure rather than trust the note. **The note was right, and it is now
right by observation rather than by inheritance:**

| | Command | Observed |
|---|---|---|
| decoy hand-spelled, quotes dropped from `refusal_naming_of` | `cabal test` | `201/201 checks passed`, `TEST_EXIT=0` — **NOT CAUGHT** |
| decoy routed through `refusal_naming_of`, same mutation | `cabal test` | `199/201`, `TEST_EXIT=1`, the delimited arm names itself |

The hand-spelled decoy kept *its* quotes while the producer lost them, so the two strings stopped
being able to collide at all and the arm that exists to observe the collision passed **by
construction**. It was asserting about its own literal. That is this milestone's standing defect one
level in — an assertion passing because its subject is absent, inside the guard written against
exactly that.

## The firing table for the three offline checks

Eleven mutations, each applied to a baseline taken **this session**, restored from it, and the
restored `sha256` re-checked after every one (`ac7290cc3937e1…`). Every one **CAUGHT**.

| # | Input | Observed |
|---|---|---|
| M1 | a read's signature drops the pin, defaulted in the body | `no_read_can_omit_its_block`, unpinned arm |
| M2 | the pin becomes `Maybe BlockRef` | optional arm |
| M3 | a top-level binding whose whole type is the pin | default arm, names `default_block` |
| M4 | a signature broken over two lines | completeness arm — reported as a FAILURE, not judged as a fragment |
| M5 | `newtype` → `data` | "Found 0 newtype declaration(s) and 1 data declaration(s)" |
| M6 | a read renamed out of the decided set | export-surface arm, both directions |
| M7 | the moving-head tag named in the layer (**a comment**) | `latest_appears_nowhere_in_the_read_layer` |
| M8 | a decoded zero returned instead of refused | CHAIN-03, the `sqrtPriceX96` row |
| M9 | the ALL-ZERO WORD arm dropped | CHAIN-03 — caught by the **fragment**, not by the `Left` |
| M10 | the fee's zero refused too (the blanket rule) | CHAIN-03, the acceptance row |
| M11 | the delimiters dropped from the refusal prefix | CHAIN-03, the delimited naming arm |

**M7 is worth its own line.** It fires through the **positive control's third arm**, not the main
scan: the control greps a *seeded copy of the read layer* beside a *clean copy of it*, so when the
real file carries the token the clean copy carries it too and the control says so first — *"the real
file already carries the token and the main arm below is about to report the same thing less
clearly."* Both arms see it; the control sees it more precisely. That is what a control built from
the subject rather than from a three-line bait buys, and it was not predicted.

**M8 and M9 together** are why each refusal row carries a DIAGNOSIS fragment and not just `Left`:
five rows refuse the same field, and a rule returning one message for all of them cannot tell a
reverting call from a truncated one from an uninitialised pool. M9 was caught by the fragment alone.

## The capture, and the finding that looked exactly like the defect

The first capture recorded **`pinned_equals_block_b = false`**. The read pinned at block 16 came back
carrying the tick the state change had just written — which reads as "the pin does not pin", i.e.
CHAIN-02's defect observed in the very plan that fixes it.

It was not. Driven with `cast`, independently of the program:

```
head = 19 ; anvil_setStorageAt(slot, 0x..42) ; evm_mine x3
cast storage --block 19  ->  0x..42          <-- the write landed IN block 19's state
cast storage --block 18  ->  the old word    <-- and nowhere below it
```

**`anvil_setStorageAt` does not create a block. It writes into the state OF THE CURRENT HEAD.** So
pinning at the head pins to the one height the cheat is about to occupy. The pin was never broken,
and the same program proves it in the same run: it reads block 0 and gets the bare `0x` marker back,
which it could only do if the block parameter were reaching the node.

The fix is one `evm_mine` **before** the write, verified before it was written:

```
b = 22, word@b = 0x..42 ; evm_mine ; setStorageAt(0x..ff) ; evm_mine x3 ; head = 26
word@b    -> 0x..42   (unchanged)
word@head -> 0x..ff
```

`write_landed_above_b` is now a recorded field and an asserted one, so this construction error can
never again be read as the defect. Its failure message says so explicitly.

## Two assertions, neither implying the other

`unpinned_differs` says the **chain** moved. Without it a pinned read agrees with itself on a chain
that did not change and the artifact is void — that is the vacuous pass CHAIN-02's whole shape is
built to avoid. `pinned_and_unpinned_disagree` says the two **reads** came apart. A capture where
the chain moved and both reads followed it satisfies the first and fails the second, and that case
is the defect. Both are recorded and both are asserted.

The measured run: `b = 13`, write at head `14`, `block_after = 17`.

| | Value | tick |
|---|---|---|
| pinned at 13 | `24519927192352584402830634309948276735881064672309344164` | −1 |
| unpinned (head) | `7307508186654514591018503391743929362538036019132324` | 5000 |

## A third arm that needs no state change at all

The capture reads the same slot at **every height from 0 to b** and records where the pool first
becomes readable. A pin being ignored would return the live word at every one of them. Measured on a
from-scratch rig, and it **corrects a claim this plan had already committed**:

```
blocks 0..5   PoolManager has NO CODE        -> the BARE 0x marker      (EMPTY payload refusal)
blocks 6..7   code, pool NOT initialised     -> an ALL-ZERO WORD        (ALL ZERO refusal)
block  8      pool initialised at tick 0     -> a well-formed word
block  13     after the rig's probe swap     -> tick -1
```

The earlier draft said *"an all-zero word at block 5"*. **Those are two different diagnoses and it
merged them** — a code-less call and an uninitialised slot are the exact pair `decode_word_token`
exists to keep apart, and the rig reaches both. `measured_pre_pool_block` moves **5 → 7**, the
largest height where the manager has code and the pool does not, and both haddocks now carry the
walked measurement. `measured_live_slot0` was checked against the capture and is **CONFIRMED**
byte-for-byte, as were `lpFee = 0` and `liquidity = 1e21`.

Heights shift between deploys (21-02 measured three from-scratch runs landing at 9, 11 and 10), so
what is durable is the **order of the three regimes**; the committed artifact records the run's
actual numbers.

## Ten artifact firings, with the evidence provably untouched

Every one driven through `CHAIN_READ_CONFORMANCE` pointed at a doctored copy. The committed
artifact's `sha256` is **identical before and after the whole sweep** (`4b15639d2e1d…`) — which is
the point of the override existing at all.

| Input | Observed |
|---|---|
| `unpinned_differs := false` | "THE CAPTURE IS VOID" |
| `pinned_equals_block_b := false` | names block 13, and points at `write_landed_above_b` first |
| `pinned_and_unpinned_disagree := false` | "the pin is being ignored: both reads followed the head" |
| `write_landed_above_b := false` | "landed at height 14 and the pinned height is 13" |
| a measurement renamed | lists the names it did find |
| `generatedFrom` blanked | the empty-provenance arm |
| `chainId := 0` | "a chain id is positive" |
| `unpinned_readback_height := 0` | "a plausible height a downstream reader cannot tell from a real one" |
| `all_below_refused := false` | "the node is answering from the head" |
| a field reading dropped | prints both sets |

## The third structural grep, and which of its tokens is load-bearing

`the_suite_never_reaches_a_chain` joins the DB-free and GAMS-free scans. Its two firing inputs were
**not equivalent, and the difference was measured rather than assumed**:

| Token | Firing input | Result |
|---|---|---|
| the JSON-RPC method module | `import qualified Network.Ethereum.Api.Eth` | **compiled**, and CAUGHT |
| the provider module | the same import | **did not compile** — `web3-provider` is not a test-suite dependency |
| the provider module | a comment naming it | CAUGHT, `offchain/test/Main.hs:90` |

So one guards a state reachable in one line of Haskell and the other one reachable in one line of
`.cabal`. The second is defence in depth, not the primary lock, and that is now written down. The
whole-file scope — comments included — is what made the second demonstrable at all.

## Deviations from Plan

### Auto-fixed issues

**1. [Rule 1 — Bug] `measured_pre_pool_block = 5` recorded a measurement that is false**

- **Found during:** Task 3, when the capture's block scan printed the real regimes
- **Issue:** blocks 0–5 have no PoolManager code at all, so they return the bare `0x` marker, not
  the all-zero word the haddock claimed. The check was still correct (the value is a synthetic tag),
  but the recorded measurement was wrong, and in this suite a recorded measurement being true is the
  whole contract.
- **Fix:** 5 → 7, with the walked measurement in both `Chain/Read.hs` and `Main.hs`
- **Commit:** `28e7ffa`

**2. [Rule 3 — Blocking] The capture's construction wrote into the block it then read**

- **Found during:** Task 3, first capture run
- **Fix:** one `evm_mine` before the write, plus `write_landed_above_b` as a recorded and asserted
  field so the two causes can never again be confused
- **Commit:** `28e7ffa`

**3. [Rule 2 — Missing critical functionality] The capture is an executable, not only a script**

- **Issue:** the plan named only `capture-chain-read.sh`. With a shell-only capture, `read_pool_field`,
  `read_raw_word_token` and `block_param` would be executed by nothing — the advertised-and-dead
  shape this package has measured three times (22-03, 22-04, 22-07).
- **Fix:** `offchain/app/ChainReadConformance.hs` and its cabal stanza. `+0 packages` in the build
  plan, though **not** `+0 dependency lines`: the first build failed with `GHC-87110` naming
  `web3-solidity` and `jsonrpc-tinyclient` as hidden, both already library dependencies. The stanza's
  comment states the narrower true claim rather than copying the sibling's.
- **Commit:** `28e7ffa`

**4. [Rule 2] `CHAIN_READ_CONFORMANCE` and its `OverrideProbe`**

- **Issue:** without an override the new check's input path is a constant, so it can only be falsified
  by damaging the committed evidence — the exact defect measured at 22-03, 22-04 and 22-07.
- **Commit:** `28e7ffa`

### Caught by guards that already existed

Not deviations — the system working, recorded because each cost a run:

1. `the_endpoint_site_census_grows_with_the_tree` named **all three** new files on their first run.
   All three are declared; the artifact as a `Transcript`, because its provenance note names the
   shell resolver. Instance **27** of prose inside a grep's blast radius on this branch.
2. `every_endpoint_site_resolves_rather_than_hardcodes` then named `Main.hs` for spelling two
   `chain_reaching_terms` — one in a new haddock, one in the chain-free grep's own **bait**. The bait
   had been written to look like a realistic import. **The prose moved; the pattern did not.**

### Plan expectations that changed

- **`BASE + 4` → `BASE + 5`.** The plan folded the chain-free grep into Task 3's prose and budgeted
  four checks. It is a check in its own right with its own positive control, exactly like its two
  twins, so the count is 198 → 203.
- **The capture requires a fresh rig.** It writes storage and is not idempotent; the second run
  refused loudly (*"The pool is already at tick 5000"*) rather than recording a fake divergence.
  That guard fired for real during this plan and its message now says to redeploy.

## Measurements

| | Value |
|---|---|
| `cabal build --enable-tests -j all` | exit **0**, **0** warnings, **0** `Downloading` |
| `cabal test` | exit **0**, **203/203**, **0** FAIL lines |
| Baseline at wave start | 198/198 |
| Delta | **BASE + 5** |
| `purge_file_floor` | 70 → **72**, re-measured by RUNNING `find`, zero slack |
| `credential_scan_floor` | 80 → **83**, re-measured separately, zero slack |
| Census under `offchain/` | hs **57**, sh **12**, json **11**, sql **3** |
| Floors part company by | exactly **1**, as task 1 predicted in advance |
| Structural greps at 0 | **three** (DB-free, GAMS-free, chain-free), each with a positive control |
| `git status --porcelain src test foundry-scripts Makefile foundry.toml .github` | empty |
| NUL bytes in any touched file | none (`wc -c` == `tr -d '\000' \| wc -c`) |
| Committed artifact sha256, before/after the 10-mutation sweep | identical (`4b15639d…`) |

## Commits

| Task | SHA | Subject |
|---|---|---|
| 1 | `596ed38` | a read that cannot be made without saying which block *(committed in the interrupted session)* |
| 2 | `10a3231` | three guards, and the decoy that had to be built by the thing it tests |
| 3 | `28e7ffa` | the divergence, constructed — and the cheat that landed in the block it was read at |

Task 4 was the gate; its measurements are in the table above and in `28e7ffa`'s message.

## Carried forward

- **`chain-read-conformance.json` is NOT in the sentinel sweep**, and it has an override, so the
  sweep *could* reach it. Declared in `unswept_artifacts` with the reason. Folding it in means
  enumerating its leaves against six sentinels and writing an `absorbed_by_design` entry, with a
  count and a reason, for every pair no check objects to. A decision with its own measurement,
  deliberately not made silently here.
- **The capture is not idempotent and needs a fresh rig.** Same class as
  `capture-cheat-swap-proof.sh`. Anything that wants both in one sitting must sequence them and
  redeploy between.
- **`anvil_setStorageAt` writes into the head's state.** This binds anything else that constructs a
  historical divergence on this rig, and it is the reason `write_landed_above_b` exists. Worth
  checking whether `capture-cheat-swap-proof.sh`'s reasoning depends on the opposite anywhere — it
  swaps after cheating, so its evidence is about a mined transaction, but nobody has looked.
- **CHAIN-06's "nine sites" is still wrong** (27-01's carry-forward), and `endpoint_sites` is now
  **18**. Correct the requirement text at phase close together with CHAIN-01's stale `next`-event
  wording.
- **`CHANGELOG.md`, `Setup.hs`, `stack.yaml`, `stack.yaml.lock` are untracked and pre-date this
  session.** Not produced by this plan, not committed by it, and out of its scope. Somebody ran a
  `stack` init in this worktree; they should be tracked or ignored deliberately rather than left in
  `git status` forever.

## Self-Check: PASSED

All 7 claimed source files present on disk plus this summary; all 3 commit SHAs resolve; all 5 new
checks registered in `core_checks` exactly once each; `endpoint_sites` holds **18** entries as
claimed (15 from 27-01 plus this plan's three); `purge_file_floor = 72`, `credential_scan_floor = 83`
and `measured_pre_pool_block = 7` are the values on disk; the committed artifact's sha256 is
`4b15639d2e1d177a7af310cc15ead82bdce8561ed3064552589f0105a248c93c`, matching the digest recorded
before and after the ten-mutation sweep.
