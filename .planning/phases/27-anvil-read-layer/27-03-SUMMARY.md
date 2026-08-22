---
phase: 27-anvil-read-layer
plan: 03
subsystem: chain-read
tags: [chain-05, fixture-identity, attach-not-construct, binary64-ceiling, phase-close, chain-01-blocked]

# Dependency graph
requires:
  - phase: 27-anvil-read-layer
    plan: 02
    provides: "the committed chain-read-conformance.json, from which this plan takes block_b and chainId rather than spelling them; BlockRef itself, so the fixture cannot record a height at which no read could have been made; and the standing rule that a mutation baseline is RE-TAKEN after every intentional edit"
  - phase: 27-anvil-read-layer
    plan: 01
    provides: "the endpoint census and chain_reaching_terms, which every new line of prose in this plan was scanned against before it was committed"
  - phase: 26-shock-assembly-fee-split-event-decode
    plan: 02
    provides: "Chain.Shock and its 21-member synthetic corpus -- the pool in the published identity is se_pool of a corpus member decoded by decode_shock, not a literal"
  - phase: 23-byte-fidelity
    provides: "BYTE-04's measurement that dQx[0] loses exactly 32 wei through the 53-bit carrier, and double_image, which this plan's precision arm is asserted equal to"
provides:
  - "Chain.Read.FixtureIdentity and render_fixture_identity: the published fixture's pool / blockNumber / chainId, rendered without a serialisation library because this module is on aeson_storage_path"
  - "render_address_token, which does NOT mask to the low 160 bits -- an oversized value arrives LONGER and a negative one carries a sign character, so neither becomes a plausible-but-different pool"
  - "two checks in core_checks (203 -> 205), each OBSERVED rejecting its named input"
  - "the measurement that a JSON number decoded into the 53-bit carrier loses the 2^53+1 witness by exactly 1, AND the finding that the suite's own JSON value type does NOT -- the loss belongs to the consumer's carrier, not to the JSON text"
  - "27-SUMMARY.md, with CHAIN-01 recorded BLOCKED by name and by dependency"
  - "CHAIN-01's stale next-event wording and CHAIN-06's nine-sites count, both corrected in REQUIREMENTS.md"
affects: [28]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "An EXPECTATION imported from outside the repository is spelled in the CHECK, never derived from the producer -- a key set the producer also supplies is the producer agreeing with itself. This does not contradict 27-02's decoy rule, which is about CONTROLS whose job is to collide with the subject"
    - "A guard against a vacuous subject is asserted BEFORE anything the subject did, and it is then REMOVED on purpose to find out whether it was load-bearing"
    - "A renderer that cannot mask is safer than one that can: an out-of-range value arriving LONGER is visible, an out-of-range value silently wrapped is a different pool"
    - "Where a value comes from is part of the assertion: pool from decode_shock, height and chain id from the committed capture, and only the three CONTRACT NAMES written by hand"
    - "A shape arm and a zero arm are separate, and M2 measured why -- the zero address is shape-VALID, so folding them together loses the arm that fires"

key-files:
  created:
    - .planning/phases/27-anvil-read-layer/27-SUMMARY.md
  modified:
    - offchain/lib/Chain/Read.hs
    - offchain/test/Main.hs
    - .planning/REQUIREMENTS.md

decisions:
  - "The fixture's pool is SYNTHETIC and it is LABELLED synthetic in the check's own haddock rather than quietly sourced from the rig manifest. The rig is a v4 pool identified by a 32-byte poolId and has no Algebra pool ADDRESS; recording the manager's address under the key `pool` would have been a recorded measurement that is false, which is the exact defect 27-02 corrected at measured_pre_pool_block. CHAIN-04's stance applies instead: synthetic subjects are how a decoder is testable before the upstream event exists"
  - "The three key names are spelled in the SUITE and not derived from the producer, because they are an EXTERNAL contract (plank f713089). Deriving them would make the key-set assertion a tautology"
  - "The height and chain id are taken from the COMMITTED CAPTURE rather than written as constants, so `the identity it was SOLVED FOR` is literally true: block_b is the height the pinned reads were made at and chainId is the chain they were made against"
  - "The precision check asserts BOTH paths -- the 53-bit carrier losing the witness AND the suite's own JSON value type carrying it exactly. Asserting only the first would have been the claim the plan asked for and would have left the reader believing the loss is in the JSON text"
  - "render_address_token does not mask. A masked oversized value is shape-valid and names a different pool, which is the zero-word trap in mirror"

metrics:
  duration: ~2h
  tasks: 3
  completed: 2026-08-22
---

# Phase 27 Plan 03: Fixture identity, and the phase closed — Summary

CHAIN-05 retired and phase 27 closed. The published fixture now says **which pool, at which height,
on which chain**, so the consuming forge test can ATTACH rather than construct — and the reason the
height is a string is **driven, not narrated**: `9007199254740993` through a JSON number decoded into
the 53-bit carrier comes back `9007199254740992`, short by exactly one. **203/203 → 205/205**, exit
0, zero warnings, four firing inputs observed.

## What CHAIN-05 is actually about

The consuming forge test used to **construct** its subject: two fresh mock tokens, a pool
initialised at the prover's own self-test defaults, then an assertion that the fixture agreed with
it. That passes only while the read happens to land on a genesis-state pool and is fatal the moment
a loop moves the price. Issue #29 asked for an ATTACH; plank landed `f713089`; and a test that
attaches must be told **what** to attach to. Forking alone cannot substitute — a constructed pool
mints new token addresses every run, so its pool id can never equal an observed one.

The contract came back naming three fields and their JSON types, and `token0`/`token1` deliberately
absent because the test reads them from the pool itself. That asymmetry — two strings and a number —
**is** the requirement, and it is why `fixture_identity_entries` is split out of the renderer: the
names and the JSON types are one expression a reader can hold against the contract without reading
punctuation.

## Where every third of the subject comes from, and why none of it is spelled

| Field | Source | Why not a literal |
|---|---|---|
| `pool` | `se_pool` of a corpus member **decoded by `decode_shock`** | the same function that will produce it in production; a spelled address would test the check's own literal |
| `blockNumber` | `block_b` out of the **committed capture** | it is the height the pinned reads were actually made at — which is what "the identity it was SOLVED FOR" means |
| `chainId` | `chainId` out of the **committed capture** | the chain those reads were made against |
| the three KEY NAMES | spelled in the suite, sorted | they are an EXTERNAL contract, and a key set derived from the producer is the producer agreeing with itself |

That last row is worth stating because it looks like a violation of 27-02's rule and is not. 27-02's
rule is about **controls**, whose whole job is to collide with the subject — a hand-spelled decoy
kept its own quotes while the producer lost them and the arm passed by construction. A **contract
imported from outside the repository** is the opposite case: it must NOT move when the producer
moves. The subject it is held against — the rendered document — is still built by the producer and
parsed by a real parser.

### The pool is synthetic, and it says so

CHAIN-01's emitter is blocked, so no mined `Shock` exists to take a real pool address from. The rig
this workstream stands up is a **v4** pool identified by a 32-byte `poolId`; it has no Algebra pool
ADDRESS at all. Recording the manager's address under the key `pool` would have been a recorded
measurement that is false — the exact defect 27-02 corrected when `measured_pre_pool_block` moved
5 → 7. So the subject is synthetic, it is labelled synthetic in the check's own haddock, and the
SHAPE assertions are precisely the ones that do not care whether the address was mined. That is
CHAIN-04's stance, one requirement over: decoding is exercised against synthetic logs so it is
testable before the upstream event exists.

## The firing table

Four inputs, each applied to a baseline taken **this session** (`bc31ebc6fccd83…`), restored from
it, and the restored `sha256` re-checked (`sha256sum -c`, `OK`, both times). Every one **CAUGHT**.

| # | Input | Observed |
|---|---|---|
| M1 | `blockNumber` published as a JSON number | **BOTH checks.** Check 1's type arm named the observed value — `blockNumber is published as a JSON NUMBER (13.0)` — and check 2's arm (5) said the fixture would carry the value it had just measured wrong by one |
| M2 | `pool` set to the zero address | the **ZERO arm alone**. The shape arm stayed green, which is exactly why they are separate |
| M3 | the witness moved below 2^53 | the **ordering arm**, and it fired FIRST, before any arm could report an agreeing round trip |
| M4 | the ordering arm disabled, witness still below the ceiling | **STILL CAUGHT** — see below |

**M1 is the one that shows the two checks are not redundant.** They fire on the same input from
opposite ends: one says *the contract says a string and this is a number*, the other says *the value
you just published as a number is the value we OBSERVED the number path getting wrong by one*. Only
the second connects the type to the consequence.

**M2 is why the shape arm and the zero arm are separate assertions.** The zero address is
shape-VALID: `0x` plus forty lowercase hex digits, length 42, every guard satisfied. Folded into one
arm it would have been unreachable. This repository has recorded the zero address passing a
hex-shape guard before, and `the_pool_topic_is_a_nonzero_address` already refuses it one layer up —
but that is a different place. A pool that decoded fine and was then rendered from an unset field
satisfies the topic check and fails here.

### M4, which was not predicted and is the finding

The plan's third firing input exists to prove the ordering arm is load-bearing: *make the precision
check compare a value below 2^53, so the control cannot go green against a subject that cannot
fail.* M3 confirmed the arm fires. **M4 asked the harder question — with that arm removed, would the
rest of the check go green?**

**It would not.** With the witness at `9007199254740991` and the ordering arm neutralised, the check
still reddened, through a **different arm**:

```
FAIL a_block_number_above_two_to_the_fifty_three_is_OBSERVED_losing_precision_as_a_number:
  the witness 9007199254740991 came back from a JSON NUMBER decoded into the 53-bit type
  UNCHANGED. If that has become true, the reason blockNumber is a string no longer has a
  subject -- RE-MEASURE it, do not delete it.
```

So the check has **two independent guards against a vacuous subject**, and they give **different
diagnoses**. The ordering arm tells an operator *the witness was chosen wrong*; the inequality arm
tells them *the carrier stopped losing it*. Only the first is true, and an operator who saw only the
second would go looking at the wrong thing. That is 26-03's finding again — existence and order are
separate assertions over the same subject — arriving from a direction nobody aimed at.

## The measurement itself, and the finding beside it

```
witness            = 9007199254740993        (2^53 + 1, the first integer the mantissa cannot hold)
through a JSON NUMBER decoded into the 53-bit carrier
                   = 9007199254740992        short by exactly 1
BYTE-04's double_image of the same integer
                   = 9007199254740992        AGREES -- same carrier, same loss
through the suite's own JSON value type
                   = 9007199254740993        EXACT
through the renderer's string form
                   = 9007199254740993        EXACT
```

**The third line is the finding, and it is why this hazard is easy to miss from inside this suite.**
The suite's JSON value type carries a number as an exact decimal, so a round trip through it does
not lose the witness. The loss is a property of the **consumer's carrier**, not of the JSON text:
it appears the moment anything decodes that number into the 53-bit type, which is what JavaScript
does unconditionally and what this repository's own BYTE-04 measured on `dQx`. Publishing a string
is what makes the fixture independent of a decoder this workstream does not control.

Asserting only the exact path would have been reassuring and wrong. Both are driven and both are
recorded, and the exact-path arm's failure message says what would have to change if it ever fires.

Every arm is an **equality on `Integer`s**, following BYTE-04: a check written as "the difference is
small" would pass under the very carrier the requirement exists to keep out of the fixture. One
block is the difference between a fork pinned at the state the reads were made against and a fork
pinned at the one before it.

## The renderer does not mask, and that is the decision

`render_address_token` left-pads to twenty bytes and **does not** reduce modulo 2^160. A value too
large for an address therefore arrives at the shape arm **LONGER** than an address token, and a
negative one arrives carrying a sign character, which is not hexadecimal. Masking would have
produced a shape-valid token naming a **different pool** — the zero-word trap in mirror, a value
that passes every structural guard and is not the one anybody measured.

The rendering is done here rather than handed to a serialisation library for two reasons, and only
the first is style: what leaves this workstream is this module's decision, and `Chain/Read.hs` is on
`aeson_storage_path`, where a library that carries an integer through a floating type is precisely
what is forbidden. The output is checked **by a parser** — the suite decodes it and asserts the JSON
type of every field — so a height rendered as a number reddens instead of looking fine in a diff.

## Deviations from Plan

### Auto-fixed / added beyond the plan

**1. [Rule 2 — Missing critical functionality] A fourth firing input the plan did not ask for**

- **Found during:** Task 1, after M3 confirmed the ordering arm fires
- **Issue:** M3 proves the arm *fires*. It does not prove the arm is *necessary* — a guard that
  duplicates another guard is decoration, and this plan's whole subject is guards that pass because
  their subject is absent. The plan's own framing ("so the control cannot go green against a subject
  that cannot fail") is a claim, and it was untested.
- **Fix:** M4 — disable the ordering arm, leave the witness below the ceiling, run. Result above.
- **Outcome:** the claim as stated is **false in the strict form and true in the useful one**: the
  check does not go green, but without the ordering arm it reports the wrong diagnosis. Recorded
  rather than smoothed over.

**2. [Rule 2] The precision check asserts the EXACT path too**

- **Issue:** the plan says "drive `2^53 + 1` through a `Number` and show it come back wrong". Driven
  literally through this suite's JSON value type, it comes back **right**, because that type is
  exact. A check written to the plan's letter, using this suite's own parser, would either have
  failed or would have had to be quietly reworded.
- **Fix:** both paths are driven and both recorded, with the exact-path arm carrying the reason it
  matters.

**3. [Rule 1 — Bug] `roadmap update-plan-progress 27` recorded `4/3` plans**

- **Found during:** Task 2, immediately after running it
- **Issue:** the tool counts `*-SUMMARY.md` files in the phase directory. The plan's own Task 2
  requires a **phase-level** `27-SUMMARY.md` in that same directory, so it was counted as a fourth
  plan summary against three plans. `{"plan_count": 3, "summary_count": 4}` in its own output.
  A progress row reading `4/3` is a recorded count that is false, and this repository's standing
  contract is that a recorded measurement is true.
- **Fix:** row corrected by hand to `3/3`. The same pass corrected the phase's headline line, which
  still read *"**BLOCKED** … (CHAIN-01, CHAIN-02, CHAIN-03)"* while being marked complete — wrong
  twice, because CHAIN-02 and CHAIN-03 were never blocked and the phase also carried CHAIN-05,
  CHAIN-06 and CHAIN-07.
- **CARRY-FORWARD, and it is not cosmetic:** anyone who re-runs `roadmap update-plan-progress 27`
  re-breaks it. `roadmap update-plan-progress` was the one gsd-tools command this plan was told is
  SAFE, and it is safe for `STATE.md`'s frontmatter — which was verified intact after it ran — but
  it is **not** safe for the plan count of any phase that keeps a phase-level summary beside its
  plan summaries. Either the phase summary moves out of the phase directory or the row is corrected
  by hand every time.

### Plan expectations that held

`BASE + 2`, exactly as budgeted: 203 → 205. No new file under `offchain/`, so both floors are
unchanged and were re-measured by RUNNING `find` rather than reasoned about.

## Measurements

| | Value |
|---|---|
| `cabal build --enable-tests -j all` | exit **0**, **0** warnings |
| `cabal test` | exit **0**, **205/205**, **0** FAIL lines |
| Baseline before this plan | 203/203, exit 0, wall **3 m 15 s** |
| Delta | **BASE + 2**, as planned |
| `purge_file_floor` | **72**, re-measured by RUNNING `find` → 72, zero slack |
| `credential_scan_floor` | **83**, re-measured separately → 83, zero slack |
| Census under `offchain/` | hs **57**, sh **12**, json **11**, sql **3** — unchanged |
| `endpoint_sites` | **18**, counted on disk |
| Structural greps at 0 | **three** (DB-free, GAMS-free, chain-free) |
| Scans over the edited read layer | float/rational **0**, aeson **0**, moving-head (case-insensitive) **0**, endpoint census **0** |
| `git status --porcelain src test foundry-scripts Makefile foundry.toml .github` | empty |
| NUL bytes in either touched file | none (`wc -c` == `tr -d '\000' \| wc -c`) |
| Mutation baseline restored and re-verified | `sha256sum -c` **OK**, after every one of the four |

## Commits

| Task | SHA | Subject |
|---|---|---|
| 1 | `306b587` | the fixture says which pool, and the string is a measurement not a preference |
| 2 | *the commit that introduces this file* | close the phase — CHAIN-01 named blocked, three stale texts corrected |

Task 2's SHA is deliberately not transcribed: it is the commit that creates this file, so any
value written here would either be wrong or would have to be amended into existence. `git log`
for `.planning/phases/27-anvil-read-layer/27-03-SUMMARY.md` resolves it, and that is the form
that stays true.

Task 3 was the gate; its measurements are in the table above and in `306b587`'s message.

## Carried forward

Phase-level carry-forwards are consolidated in `27-SUMMARY.md` (the spike's S1/S2/S3, the
`anvil_setStorageAt` finding, the unswept artifact, the non-idempotent captures, README's prefix bug,
the foundry alias, and the untracked `stack` files). Specific to this plan:

- **The fixture's pool is synthetic until CHAIN-01 is discharged.** The shape is asserted; the value
  is not a mined address. The day a `Shock` is mined, the value changes and nothing else does — but
  nobody should read the green check as evidence that a real pool has ever been published.
- **`render_fixture_identity` renders the identity BLOCK, not the whole fixture.** LOOP-03 has to
  join it to the prover's output when it publishes, and that join is where a duplicate key or a
  dropped field would appear. There is no check over the joined document because there is no joined
  document yet.
- **`roadmap update-plan-progress 27` will report `4/3` again** on the next run, because it counts
  the phase-level `27-SUMMARY.md` as a plan summary. Corrected by hand here; the fix is to move the
  phase summary or to stop trusting that row.
- **No check asserts that the published `pool` is the pool the READS were made against.** It asserts
  the height and the chain id are the capture's, and that the pool is well-shaped and nonzero. Tying
  the pool to the capture needs the capture to record a pool identity, which it does not — and on a
  v4 rig the honest thing to record is a `poolId`, not an address, which is a contract question for
  whoever discharges CHAIN-01.

## Self-Check: PASSED

Both modified source files present on disk with the claimed additions (`FixtureIdentity`,
`render_fixture_identity`, `render_address_token`, `exact_integer_ceiling`,
`block_number_precision_witness` exported from `Chain.Read`; both check names registered in
`core_checks` exactly once each); `27-SUMMARY.md` and this file present; commit `306b587` resolves;
`cabal test` reads 205/205 exit 0 on the restored tree; `purge_file_floor = 72` and
`credential_scan_floor = 83` are the values on disk AND the values `find` prints; `endpoint_sites`
holds 18 entries; CHAIN-01's and CHAIN-06's texts in `REQUIREMENTS.md` carry their corrections and
CHAIN-01 is **not** marked complete.
