---
gsd_state_version: 1.0
milestone: v6.0
milestone_name: Model Output Store + VolumePath Bridge (rpc_api workstream)
status: in-progress
stopped_at: "Completed 27-03-PLAN.md and CLOSED PHASE 27. CHAIN-05 RETIRED (203/203 -> 205/205, exit 0, zero warnings). The published fixture now carries pool / blockNumber (STRING) / chainId, exactly the contract issue #29 handed back at plank f713089, so the consuming forge test can ATTACH rather than construct; token0/token1 stay ABSENT because the test reads them from the pool. THE STRING IS A MEASUREMENT: 9007199254740993 (2^53+1) through a JSON number decoded into the 53-bit carrier comes back 9007199254740992 -- short by exactly 1, an equality no tolerance can absorb, and equal to BYTE-04 double_image of the same integer. THE FINDING BESIDE IT: the suite own JSON value type carries that number EXACTLY, so the hazard is invisible from inside this suite -- the loss belongs to the CONSUMER carrier, not to the JSON text, which is precisely why publishing a string is the remedy. NONE OF THE SUBJECT IS SPELLED: the pool is se_pool of a corpus member decoded by decode_shock, the height and chain id are block_b and chainId out of the committed capture; only the three CONTRACT KEY NAMES are written by hand, because a key set derived from the producer is the producer agreeing with itself. Four firings observed. M4 WAS NOT PREDICTED: with the ordering guard REMOVED and the witness still below the ceiling the check STILL reddened, through a different arm -- so there are two independent guards against a vacuous subject and they give DIFFERENT diagnoses. PHASE CLOSE: CHAIN-01 recorded BLOCKED by name with its dependency (plank/mev-migrate, issue #26, SELECTOR_NEXT 0xd3827b0b) and with what would discharge it; CHAIN-01 stale next-event wording and CHAIN-06 nine-sites count both corrected in REQUIREMENTS.md. Next: phase 28 (LOOP), and S1 must be decided BEFORE it plans its loop."
last_updated: "2026-08-22"
last_activity: "2026-08-22 — 27-03 executed and PHASE 27 CLOSED. 203/203 -> 205/205, 0 warnings, 0 Downloading. Two checks over the fixture identity, four firing inputs observed, both floors re-measured by RUNNING find and UNCHANGED at 72/83 (this plan creates no file). Six of seven CHAIN requirements retired; CHAIN-01 blocked externally and named as such. 27-SUMMARY.md written."
progress:
  total_phases: 6
  completed_phases: 5
  total_plans: 21
  completed_plans: 21
---

<!--
FRONTMATTER WARNING, RECORDED AT 24-03 AND STILL BINDING.
`gsd-tools state record-session`, `state add-decision` and `state update-progress` all REWRITE this
frontmatter from a global view of the repository's .planning trees, and they get it wrong for this
one: the milestone reverts to v2.0, `status:` is overwritten with whatever prose the "Status:" line
of the body happens to start with, and the four progress counters are replaced by machine-wide
totals (25 phases / 43 plans). 24-03 ran all three and had to restore every field by hand.
EDIT THIS BLOCK BY HAND. `roadmap update-plan-progress <N>` is the one that is safe.
-->


# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-07-19)

**Core value (v4.0):** `VolOrderManagerMod.plk` is a vol-order REGISTRY — `create_order(uint88,uint24,uint16)` (strike/width/skew, selector `0x6501fe94`) validating against the machine-checked `vol_order_is_complete` predicates, assigning a sequential id, storing a packed `VolOrder` word — plus a BEST-EFFORT batch entrypoint running N create_order calls in one tx (invalid tuples skipped, batch never reverts). Built for the rpc_api Haskell `StochasticOrderGen` consumer (PR #9 awaits this surface). Every claim is a CALLED test or an OBSERVED mutation kill; compiling is NOT evidence; the gate is the batch dispatch being CALLED green through FFI-deployed bytecode (**CORRECTED at 19-05** — `PLANK_SKIP` is the rescue queue for entrypoints that do NOT compile, so this module never belonged there; the queue is empty and there was no exit to perform).
**Current focus (v6.0):** the **model output store** — a Postgres/JSONB keyed store whose key is
the shock that produced the output, so an identical shock skips the solve and a re-solve that
disagrees is caught; and the issue #25 bridge carrying a live Anvil `next` event through the
GAMS VolumePath prover to the fixture the forge test reads. Binding reference:
`model/mev_tax_model_one/VOLUME_PATH.md` — consume, do not re-derive.

**Prior focus (v4.0, record):** **MILESTONE v4.0 COMPLETE (2026-07-21).** All five phases (16, 17, 18a, 18b, 19) and all 15 requirements shipped. `VolOrderManagerMod.plk` is a proven vol-order registry: `create_order` and `create_orders` both CALLED green through FFI-deployed bytecode, a 10-application mutation battery with ZERO survivors, an independent-mock sequence differential at tol 0, and a consumer golden fixture from an encoder outside this repo. Next action: tag v4.0 and hand off to peer `mv15a18k`, OR resume v2.0 (`/gsd:plan-phase 10`).

**Track note:** Sixth milestone — **v6.0 is the rpc_api workstream's** (offchain Haskell, branch `feat/rpc-api`), phases 23–28, from issue #25. The **subgraph (issue #14) was renumbered v6.0 → v7.0 on 2026-08-16** and is queued behind this one, on dependency grounds: it needs somewhere to put what it indexes, and v6.0 builds exactly that. v5.0 (VolOrder V2 re-pin + stochastic drivers, phases 20–22) SHIPPED 2026-08-03. v3.0 (VegaAccountMod vault, Phases 12–15) SHIPPED 2026-07-19 (tag `v3.0`). v1.0 (GAMS plumbing, Phases 1–7) PAUSED. v2.0 (vol-oracle differential, Phases 8–11) PAUSED after Phase 9 — VDIFF-05..08 (Phases 10–11) remain pending, NOT part of v4.0. Resuming v2.0 = `/gsd:plan-phase 10`. These phase ranges are separate tracks — never renumbered.

## Current Position

Phase: **27 — Anvil Read Layer** — **COMPLETE (3/3 plans)**, with ONE requirement blocked
externally and named as such. Phase summary:
`.planning/phases/27-anvil-read-layer/27-SUMMARY.md`.
Plan: **27-03 COMPLETE** (commit `306b587` + this close). Summary:
`.planning/phases/27-anvil-read-layer/27-03-SUMMARY.md`. **CHAIN-05 retired.**
203/203 → **205/205**, exit 0, zero warnings, 0 `Downloading`; floors **72/83** UNCHANGED and both
re-measured by RUNNING `find` (this plan creates no file). Next: **phase 28 (LOOP)**.

**PHASE 27 DISPOSITION.** CHAIN-02, CHAIN-03 (27-02), CHAIN-05 (27-03), CHAIN-06, CHAIN-07 (27-01)
shipped; CHAIN-04 was already done at 26-02; **CHAIN-01 is BLOCKED**. Suite **194 → 205** across the
phase. CHAIN-02 and CHAIN-03 were carried in marked *Blocked* and **were never blocked** — that was
inherited from CHAIN-01's row rather than measured, and a pinned read needs only a POOL.

**CHAIN-01 — BLOCKED, BY NAME, WITH ITS DEPENDENCY.** Plank / mev-migrate workstream, issue #26,
`SELECTOR_NEXT 0xd3827b0b`. There is no deploy script for the Shock writer —
`foundry-scripts/mev_tax_model_one/` holds only `DeployAlgebraFactory.s.sol` — and the event is
emitted from a forge **test**, not from a deployable contract another process can drive. **Not this
workstream's to build.** WHAT WOULD DISCHARGE IT: one driver that emits a single `Shock` in a MINED
transaction on the resolved endpoint. Everything on this side is ready: `Chain.Shock` decodes it
(CHAIN-04, 12 checks, 21-member corpus), `Chain.Read` pins the reads to its block, `Chain.Endpoint`
resolves the endpoint it would be pointed at, and CHAIN-05's fixture already carries the identity
slot the decoded pool goes into.

**TWO REQUIREMENT TEXTS CORRECTED AT CLOSE, neither by changing a status.** CHAIN-01 said *"the
`next` event"* and `next(address,uint160,int24,uint24,uint24)` is a FUNCTION SELECTOR
(`0xd3827b0b`), never an event — the event is `Shock(address indexed pool, int24, uint24, uint24)`,
topic0 `0x21b0e4f8…55987d64`. CHAIN-06 said *"Nine sites, one rule"* and the count was wrong three
ways: TEN by its own pattern, ELEVEN counting `verify-rig.sh` (invisible to any pattern built from
those two tokens, because it reached the chain through foundry's alias), and the rule was
implemented **ZERO** times. The durable form is `endpoint_sites`, checked in both directions, **18**
entries.

**THE FIXTURE SAYS WHICH POOL, AND THE STRING IS A MEASUREMENT.** `pool` (string address),
`blockNumber` (**STRING**) and `chainId` (number) — issue #29's returned contract, plank `f713089`.
`token0`/`token1` deliberately ABSENT: the consuming test reads them from the pool, so the pool
stays the single source of truth. OBSERVED, not asserted: `9007199254740993` through a JSON number
decoded into the 53-bit carrier comes back `9007199254740992`, short by **exactly 1**, equal to
BYTE-04's own `double_image` of that integer. **AND THE FINDING BESIDE IT:** the suite's own JSON
value type carries that number EXACTLY, so the hazard is invisible from inside this suite — the loss
belongs to the CONSUMER'S carrier, not to the JSON text, which is precisely why publishing a string
is the remedy. Asserting only the exact path would have been reassuring and wrong.

**NONE OF THE SUBJECT IS SPELLED IN THE CHECK.** The pool is `se_pool` of a corpus member decoded by
`decode_shock`; the height and chain id are `block_b` and `chainId` out of the COMMITTED capture,
which is what "the identity it was SOLVED FOR" means. Only the three CONTRACT KEY NAMES are written
by hand, and deliberately: they are external, so a key set derived from the producer would be the
producer agreeing with itself. **The pool is SYNTHETIC and labelled so** — CHAIN-01's emitter is
blocked, the rig is a v4 pool with a 32-byte `poolId` and no Algebra pool ADDRESS, and recording the
manager's address under the key `pool` would have been a recorded measurement that is FALSE.

**M4 WAS NOT PREDICTED, AND IT IS THE FINDING.** The plan's third firing input exists to show the
ordering guard is load-bearing. M3 showed it fires. M4 asked the harder question — with that arm
REMOVED and the witness still below the ceiling, does the rest go green? **It does not:** the check
still reddens, through a DIFFERENT arm ("came back UNCHANGED"). So there are two independent guards
against a vacuous subject and they give **different diagnoses** — the ordering arm says the WITNESS
was chosen wrong, the inequality arm says the CARRIER stopped losing it, and only the first is true.
26-03's existence-versus-order finding, arriving from a direction nobody aimed at.

**M2 IS WHY THE SHAPE ARM AND THE ZERO ARM ARE SEPARATE.** The zero address is shape-VALID — `0x`
plus forty lowercase hex digits, every guard satisfied — so folded into one arm the zero arm would
be unreachable. Measured: M2 fired the zero arm ALONE while the shape arm stayed green.

**S1 BINDS PHASE 28 AND MUST BE DECIDED BEFORE IT PLANS ITS LOOP.** From
`.planning/SPIKE-end-to-end.md`: a `KeyIdentity` can only be obtained from a COMPLETED RUN
(`key_identity` needs a `ToolchainIdentity` whose only producer is `run_prover`'s `Produced` arm,
yet `decide` needs the identity BEFORE the first solve, and there is no `detect_toolchain`), so the
loop bootstraps with a throwaway solve or the library grows a detection function. **S2:**
`invoke_shock` does not fit the `Solver` seam and `AbortReason` has no constructor for a resolution
failure, so the composition function phase 28 will reach for first is the wrong one. **S3:**
`Decision` drops `CapturedStreams`, so a caller cannot tell an inadmissible shock (abort line 109)
from an unsolvable one (171/173) — which touches CHAIN-03's spirit directly.

### 27-02, still standing (the record)

**THE PIN IS A TYPE, NOT A CONVENTION.** `BlockRef` is a `newtype` with one constructor, so the
moving-head tag is not something the read layer avoids — it is something the type cannot express,
and re-opening the question means changing `newtype` to `data`, a diff nobody writes by accident.
Every read takes it as a required positional argument. `latest_appears_nowhere_in_the_read_layer`
then closes the corridor the type leaves open (a string handed to the transport, a second import),
with a positive control that greps a SEEDED COPY of the read layer beside a CLEAN copy of it.

**CHAIN-03 IS A PURE TOTAL FUNCTION**, drivable at arguments a local anvil will not produce on
demand: twelve refusals across five diagnoses (negative height, absent answer, four unparseable
shapes, an ALL-ZERO WORD, a decoded zero) and four acceptances, because a rule that refuses
everything passes a refusal table. `lpFee` is NOT zero-refused, and that is a measurement: a
dynamic-fee pool stores it as zero at initialise, so a blanket rule would refuse the rig's own
genesis state on every call.

**THE DECOY HAD TO BE BUILT BY THE FUNCTION UNDER TEST.** The naming arm's control was hand-spelled
first, and the mutation that drops the delimiters from `refusal_naming_of` MEASURED **201/201,
exit 0, NOT CAUGHT** — the hand-spelled decoy kept *its* quotes while the producer lost them, so the
two strings stopped being able to collide and the arm that exists to observe the collision passed by
construction. Routed through the producer, the same mutation fires at 199/201.

**anvil_setStorageAt DOES NOT CREATE A BLOCK.** The first capture recorded
`pinned_equals_block_b = false` and looked exactly like CHAIN-02's defect. Driven with `cast`
independently: the cheat writes into the state OF THE CURRENT HEAD, so pinning at the head pins to
the block the cheat is about to occupy. The pin was never broken — the same run reads block 0 and
gets the bare `0x` marker, which it could only do if the block parameter were reaching the node.
Fixed with one `evm_mine` BEFORE the write; `write_landed_above_b` is now a recorded and asserted
field so the construction can never again be mistaken for the defect. **This binds anything else
that constructs a historical divergence on this rig.**

**A CLAIM THIS PLAN HAD ALREADY COMMITTED WAS WRONG.** `measured_pre_pool_block` moves **5 → 7**.
Walking every height of a from-scratch rig: blocks 0–5 the PoolManager has NO CODE and the call
returns the bare `0x` marker; blocks 6–7 it has code and the pool is uninitialised, returning an
ALL-ZERO WORD; block 8 the pool is live at tick 0; block 13 tick −1 after the probe swap. Those are
two different diagnoses and the earlier draft merged them.

**cabal test STILL OPENS NO SOCKET**, now asserted by a **third** structural grep beside the DB-free
and GAMS-free ones. Its tokens are not equally load-bearing and that was measured: `web3-ethereum`
IS a test dependency so the JSON-RPC method module can be imported today and only the scan stops it
(the firing input compiled and was caught); `web3-provider` is NOT, so that import does not build at
all and its firing input had to be a comment.

### 27-01, still standing (the record, and it caught this plan twice)

**ONE RESOLVER, IN TWO LANGUAGES, WITH THE TWO STATEMENTS ASSERTED BYTE-EQUAL.**
`Chain.Endpoint` states `ETH_RPC_URL` and the default authority once for the Haskell tree;
`offchain/rig/endpoint.sh` states the default once for the three bash sites and splits it into
`RPC_URL` / `RPC_HOST` / `RPC_PORT`. `bash` cannot import a Haskell module, so the value exists
twice by necessity and `the_producer_and_the_consumers_bind_one_endpoint` compares them — the move
`Fee.Split` and `Store.Key` already make for the pip denominator.

**WHAT CHAIN-06 DESCRIBES IS NOT WHAT WAS THERE.** It reads as though nine sites each implement the
rule and might drift. MEASURED: the rule was implemented **ZERO** times — the only occurrence of the
variable under `offchain/` was a COMMENT in `deploy-rig.sh` saying the deploy scripts scrub it.

**THREE PLAN ERRORS, EACH FOUND BY MEASUREMENT.** (1) `offchain/rig/verify-rig.sh` is an **ELEVENTH
site** that CHAIN-06's list of nine does not contain: fourteen `cast` calls against a live rig,
reached through foundry's `--rpc-url local` alias, so it named neither token and no pattern built
from them could see it. (2) The plan's census pattern would have reported the fix as a regression —
it found 10 before the rewiring and **8 after**, because five of the six Haskell consumers stop
naming either token the moment they name the resolver. (3) `"cast call"` matched
`CheatSwap/Encoding.hs`'s `cast calldata`: the 26-03 longer-wrong-value shape, and
`offchain/rig/README.md`'s hand-run grep still carries it.

**A CHECK OF MINE WAS VACUOUS AND ITS OWN MUTATION PROVED IT.**
`an_empty_eth_rpc_url_does_not_resolve_to_the_empty_string`, written against the environment,
MEASURED GREEN against a deliberately unguarded resolver. `System.Environment.setEnv k ""` routes an
empty value to `unsetEnv`, so it was driving the UNSET path twice — the passes-because-the-subject-is-
absent defect, inside the guard against it. Repaired by factoring the rule into the pure
`endpoint_from`, with the empty export's reachability OBSERVED in a child shell.

**FEE-02 IS PROVEN AGAINST THE REAL PROVER, AND THE DISCRIMINATOR IS NOT THE EXIT CODE.**
`Fee.Split.is_admissible` and `volume_path.gms`'s own `ellTest` gate agree on twelve points that
bracket four exact boundaries — 82804 / 109769 / 300361 / 495953 — by one pip on each side.
**All twelve rows exit 3.** What separates the four the prover REFUSES from the eight it merely
cannot solve is the model's own SOURCE LINE: **109 is the half-ellipse refusal; 171 and 173 are
CONOPT failing to reach an ADMISSIBLE point**, which is `admissible-but-unsolved` and never a
disagreement. `gams_admits = (abort_line /= 109)`, pinned in the capture, in the shell gate and in
three in-suite arms. Gates: `DISAGREE=0`, `VERDICTS=2`, `BADCTL=0`, `complete=true`, and four rows
refused at line 109. GAMS 54.1.0 / CONOPT 4.39.0, model `79940449…ca53ad`, sixteen invocations in
**846 ms** (a solve is 35 ms; the sweep doc's "~2 s per run" was its own script's overhead).

**RC-B1 CLOSED.** The 160-run sweep left `(1000, 3000)` open because its grid stepped
300000 → 400000. Re-swept at ten points here: last ELLIPSE **300360**, first non-ellipse
**300361**, and `min_admissible_dstar 1000 3000 == Just 300361`. **All four pairs now agree with
the prover at the boundary exactly.** The controls are the sweep's MEASURED solvable targets —
490000 (ROADMAP SC-2's own 0.49) for three pairs and 497000 for `(700, 800)` — not the plan's
parabola vertices, three of which abort.

**RC-B2 CLOSED, by a DIFFERENT derivation than the finding proposed.** Its
`(gams_exit == 0 && gams_artifact_present)` is measured FALSE here — `gams_artifact_present` is
false on all twelve rows and eight of them are admissible. Its own falsifying input (every
`gams_exit` set to 0, `gams_admits` untouched) was RUN and reddens naming **all twelve rows**, on an
arm that ties the exit to the line and requires the line to be in the model's known abort taxonomy.

Suite **190/190 → 194/194**, exit 0, zero warnings, wall **173 s** against a 900 s ceiling. Phase
arithmetic `162 + 32 = 194` (the plan says 31; the extra one is 26-02's own recorded twelfth check).
Seventh swept artifact; all seven field floors named by the harness in ONE run
(20 / 110 / 151 / 130 / 156 / 76 / **125**) and **none of the six moved** — including
`store-conformance.json`, which `26-VALIDATION.md` predicted phase 25 would grow by ~22 and which
did not grow at all. `sentinel_pair_floor` **3828 → 4574**, the four identity skips NAMED. Floors
re-measured COLD as a pair: `purge_file_floor` **67**, `credential_scan_floor` **77**. Four guards,
**thirteen firings observed**, every one restored from a sha256-verified copy. Both structural greps
**0**. Territory clean.

**FEE-01's text is corrected in BOTH documents.** `REQUIREMENTS.md` and `PROJECT.md` claimed the
composition is exact; it is not. Exactness needs `10⁶ ∣ φ_X·φ_M`, true for **4.935 %** of
`f ∈ [1, 20000]` (987 of 20000, recomputed today) and for **none** of 100 / 500 / 3000 / 10000 pips.
`split_for 0 3000 490000` gives `(752, 2250)` composing to **3000.308** pips. Both now say
round-and-report, with the measured numbers. `ROADMAP.md` was not edited.

**CARRY-FORWARD (replacing "phase 26 owes phase 25 nothing else").** `fs_seed` and
`fs_splitter_version` exist and are asserted by check 18, and all twelve `FeeSplit` fields are read
by a check — but `splitter_version` has **no consumer**: phase 25 ran first and imports nothing from
`Fee.Split`. Wiring it into the content key is non-destructive via `key_scheme` — RC-M5's anchor
**ROADMAP:1288-1289**, whose sentence has since drifted to **ROADMAP:1304-1305** — and belongs to
whoever next touches `Store.Key`. SC-1's store half is likewise still open.

**AN INADMISSIBLE SHOCK HAS NO ARGV AT ALL, AND THE PROCESS WAS OBSERVED NOT STARTING.**
`volume_path.gms:100-108`'s own `ellTest` is `render_argv`'s **ninth** refusal, in exact `Integer`
arithmetic, evaluated AFTER `distinct_fees`. `Gams.Run.run_prover` hands the `Left` to
`refused_before_spawn`, so there is no argv for `spawn_into` to receive — and a `/bin/sh` stub whose
whole body touches a marker was driven through the real edge to say so from the filesystem rather
than from the case expression: POSITIVE CONTROL first at `txlVolumeRate = 82804` (marker present,
`cs_run_dir` non-empty), then the subject at `82803` — marker ABSENT,
`Aborted (ArgvRejected (Inadmissible 500 6000 82803 …)) 0`, and **`cs_run_dir == ""`**, which says
more than "no marker". Suite **181/181 → 190/190**, exit 0, zero warnings, wall **158 s** against a
900 s ceiling. Floors re-measured COLD as a pair: `purge_file_floor` **64**, `credential_scan_floor`
**73** — UNCHANGED, this plan creates no file. Nine guards, **ten firings observed**, every one
restored from a sha256-verified copy. Both structural greps **0**. Territory clean.

**BLOCKER B1 IS CLOSED.** `split_for` tests `fee_in_domain f` BEFORE `admissible_band`, because that
enumeration reaches `x = 1000000` for every `f > 1000000` and `nearest_partner` divides by zero
there — an exception no `Either` can carry. Asserted as a value:
`split_for 0 8388608 490000 == Left (FeeOutOfDomain 8388608)`, and 8388608 is v4's
`DYNAMIC_FEE_FLAG` in `PoolKey.fee`, not a fee of 8388608 pips. **The finding's ordering clause
cannot bite:** step 0 tests the POOL fee and says nothing about the legs, which `split_for` DERIVES;
an in-domain `(3000, 3000)` shock is still `FieldOutOfRange "phiXpips"` citing §1.2. **26-01's
boundary disagreement is CARRIED, not resolved:** v4's `isValid` admits `f = 1000000` and the
splitter does not, and the domain was NOT widened to match.

**THE ORDERING GUARANTEE IS NOW BEHAVIOURAL, AND ITS LINE-NUMBER HALF EXPIRES AT 26-04.**
`distinct_fees` is at `Gams/Argv.hs:206` and `admissible_pair` at `:207` today. Deleting
`distinct_fees` was OBSERVED leaving the refusal INTACT as
`Inadmissible 6000 6000 490000 18944769600000000000000000000 Nothing` — the count unchanged, §1.2's
diagnosis gone — while `equal_fees_are_refused_in_haskell_with_the_1_2_diagnosis` reddened naming
the constructor. **That constructor arm is what 26-04's `render_argv_ungated` split must leave
standing**; the composition must be `render_argv_ungated >>= then admissible_pair`, never the
inverse.

**RC-M6 IS CONFIRMED AT 2, AND BOTH DOCUMENTS ARE CORRECTED.**
`admissible_band 3000 1000 == [(1,2999),(2,2998)]`, size **2** — measured independently and again by
the check's own failure text. The **4** in `26-03-PLAN.md:178` and `26-VALIDATION.md:232` is the
count of BOTH orientations; `admissible_band` keeps only `m > x`. The EMPTY input is
`delta* = 200`, the SINGLETON is `delta* = 500` (`[(1,2999)]`, `fs_band_size == 1`), and both are
now asserted BY VALUE.

**`gams-conformance.json` HAD TO BE RE-TAKEN, AND NO PLAN OF THIS PHASE SAYS SO.**
`gams_freshness_subjects` is `["offchain/lib/Gams/Argv.hs", "offchain/lib/Gams/Artifact.hs"]` and the
oracle recomputes both digests from disk, so touching the renderer reddens it. It was re-driven
against the REAL GAMS 54.1 (`CFMM_REQUIRE_GAMS=1`, `GAMS_BIN=/usr/gams/gams54.1_…/gams`,
`GAMS_MODEL=…/cfmm-wt/gams/model/mev_tax_model_one/volume_path.gms`), exit 0, **9/9 verdicts pass**.
The whole diff is `argv_module_sha256` and two banner timestamps: **with the ninth refusal installed
the golden artifact still reproduces at `e7b14f38..07d0d884`.** **26-04 must re-take it too** — its
`render_argv_ungated` split necessarily edits that file.

**FOUR PLAN DEFECTS, EACH WITH THE MEASUREMENT THAT FOUND IT.** (1) `ResidualTooLarge`'s arguments
are specified as `(x, m, f, r)` and 26-01 shipped `(f, x, m, r)` — four `Integer`s, nothing would
have type-checked differently and the message would have named the fee as a leg. (2) The plan's
step 1 and step 2 are the SAME test, because `pick_from_band` is `Nothing` exactly when the band is
empty; merged, so no branch needs a message for a state that cannot exist. (3) Check 16's stated
firing input — "move the ninth refusal after the token list" — is a NO-OP in an `Either` do-block;
the only mutation that produces an argv is one that takes the gate off the rendering path. (4) The
`BADDEPS` collision RC-B3 warns about does NOT bite this gate: it scans `Fee/Split.hs` only, which
has no `sqrtPriceX96`, and the unanchored pattern prints 0 there too. It DOES bite
`no_floating_value_is_on_the_fee_path`, which 26-01 already anchored.

**RC-m11 IS CLOSED.** All twelve `FeeSplit` fields are now read by a check; `fs_ellipse_e` and
`fs_boundary_pips` are asserted against `Fee.Split` recomputed at the split's own pair and target.
A sixth `SplitRefusal` constructor, `NoBoundaryForAnAdmissiblePair`, carries RC-M4's impossible
`Nothing` as a named refusal rather than a `fromMaybe` default.

**CHAIN-04 IS COMPLETE. `Chain.Shock` DECODES AN EVENT WHOSE EVERY PRODUCTION LOG IS TWO-THIRDS
ZERO.** 259 lines, six imports, +0 packages, no IO, no hexadecimal literal, `Either` with ten named
refusals: arity, topic0, EMITTER, address shape, zero pool, exact-96 length, the zero shock, and
three per-word ranges. Suite **169/169 → 181/181**, exit 0, zero warnings, wall **176 s** against a
900 s ceiling. Floors re-measured COLD as a pair with the module on disk: `purge_file_floor`
**63 → 64**, `credential_scan_floor` **72 → 73**, zero slack, census `hs 52, sh 9, json 9, sql 3`.
Twelve guards, **seventeen firings observed**, every one restored from a sha256-verified copy. Both
structural greps **0**. Territory clean; `develop` never merged and `ShockLib.plk`, `Shock.plk` and
`ShockRoundTrip.t.sol` were read with `git show origin/develop:…` and cited, never edited.

**RC-M3'S JUSTIFICATION FOR THE `ZeroShock` RENAME IS FALSE, AND THE CONSEQUENCE INVERTS IT.** The
finding says *"`render_argv`'s ninth refusal already kills `txlVolumeRate = 0` for free"*. MEASURED
at `Gams/Argv.hs:137`: the bound is `in_range "txlVolumeRate" value 0 999999` — **lower bound 0** —
and `render_argv` has **eight** refusals, not nine. A zero rate renders cleanly and reaches the
prover, which cannot answer it (`E(x, m, 0) = D⁴xm > 0`, asserted against the shipped
`ellipse_test`). So the `ZeroShock` **consumer rule is load-bearing**: Phase 27 must SKIP the
period, and it is the only thing between a quiet period and a solve that must abort. The first
draft of check 4 asserted the finding and went red, which is how this was caught.

**AN EVENT TOPIC IS UNAUTHENTICATED, AND THE DECODER NOW SAYS SO WITH A GUARD (RC-M4).**
`decode_shock` takes `expected_emitter` alongside `expected_topic0` and refuses `WrongEmitter`.
`synthetic_log` hardcodes one address for every log it builds, so no phase-26 check could observe
emitter discrimination even in principle until a `shock_log_from` helper and a `wrong-emitter`
corpus member existed. **STILL OPEN and Phase 27's to discharge:** `ShockEvent` carries no block,
log index or transaction, so a batch decode must keep the `Change` beside the event or two blocks
mix silently. The obligation is haddocked in the module's MUST-NOT-BE-TRUSTED-ON paragraph.

**THE DATA LAYOUT NOW HAS AN INDEPENDENT ORACLE (M2 / RC-M7).** The corpus and the decoder shared
one belief about word order and padding, so a shared misreading passed every check and the headline
claim was a tautology. `cast abi-encode "f(int24,uint24,uint24)" -- -200 490000 7` is pinned as 192
bare hex characters and compared to the `negative-tick-and-decay` member's `changeData`; transposing
two words in the corpus reddens it, which nothing did before. It is a SIBLING constant, **not** a
`ground_truth` row — `sc4_ground_truth_encoder` hashes every row's signature and would redden on a
192-char payload.

**RC-m7 IS CLOSED BY MEASUREMENT AND THE TRIP-WIRE WAS RE-SCOPED.** PR #30 merged the model into
`origin/develop` (`291d8a6`), so check 10's old subject — the emitter's absence from this worktree —
was permanently satisfied-by-absence. It now reads `origin/develop` through `git`, with a control
shown saying YES and NO, and asserts the emitter's hand-written `SHOCK_EVENT_TOPIC0` **equals**
`keccak(shock_signature)`, plus the word order and the 96-byte payload the decoder assumes. Its
failure text keeps the advice: **re-verify the CONSTANT, not merely re-home the pin.** This adds
`git` as a suite dependency alongside `grep` and `/bin/sh`; if `origin/develop` is unresolvable the
check fails loudly with `git fetch origin develop`.

**`"Shock"` IS DELIBERATELY NOT IN `expected_topic_pins`**, with the reason in the file:
`generate-pins.sh` iterates LOCAL interface files and the emitter is not one, so the generator could
never produce that pin. **New prose-in-a-grep instance (24):** the plan's own acceptance command
`sed -n '/expected_topic_pins/,/^$/p' | grep -c Shock` prints **2**, not 0, because `sed` restarts
its range at the comment that explains the exclusion. Anchored to `^expected_topic_pins ::` it
prints 0.

**`Fee.Split` IS THE SPLITTER'S ARITHMETIC, AND IT IS TOTAL.** 465 lines, one import
(`Data.Word`), no floating value, no rational type, no IO, no hexadecimal literal. `compose_scaled`
is the level constraint exactly; `ellipse_test` is `volume_path.gms:100-108` transcribed term for
term times `D^6`; `min_admissible_dstar` bisects. Suite **162/162 → 169/169**, exit 0, zero
warnings, wall **181 s** against a 900 s ceiling. Floors re-measured COLD as a pair with the module
on disk: `purge_file_floor` **62 → 63**, `credential_scan_floor` **71 → 72**, zero slack, census
`hs 51, sh 9, json 9, sql 3`. Both structural greps **0**. Territory clean.

**BASE WAS 162, NOT 151.** Every gate in phase 26 is `BASE + N` against a BASE measured cold at
`2026-08-17T16:07:46Z`, before any edit. The 151 the phase was drafted against, and the 149.5 s wall
beside it, both predate phase 25 and are dead. The comparand wall is **191 s**.

**THREE DEFECTS WERE FOUND IN THE PLAN ITSELF, each fixed with the measurement that found it.**
(1) `RC-M4`: the specified bisection returns `Nothing` at `x = 99, m = 101` though `499975` is
admissible — and the reviewer's own one-line fix is wrong in the mirrored case, so the shipped code
tries BOTH candidate right ends and haddocks why that is complete. (2) `RC-B3`: the plan mandated a
haddock sentence containing `sqrt` in a file its own gate scans for `sqrt`; the sentence moved to the
check's haddock. (3) **NEW**: the plan's float-scan pattern matches `sqrtPriceX96` on **13 lines** of
the already-scanned set, so the check could never have exited 1 — the pattern is word-anchored, the
scanned set is not narrowed.

**BLOCKER B1 IS HALF-CLOSED, AND THE OTHER HALF IS NAMED.** `nearest_partner` divides by `D - x` and
a band over `[1 .. f-1]` reaches `x = 1000000` for every `f > 1000000` — which v4's
`DYNAMIC_FEE_FLAG` (8388608) is. `fee_in_domain` and `FeeOutOfDomain` landed here with three
asserted arms. **26-03 owes** `split_for`'s step-0 guard and the
`split_for 0 8388608 490000 == Left (FeeOutOfDomain 8388608)` arm, with "delete the guard, observe
the exception" as its firing input.

**FEE-01 AND FEE-02 ARE NOT MARKED COMPLETE, DELIBERATELY.** FEE-01's text says "the splitter
produces (φ_X, φ_M)" and `split_for` does not exist until 26-03; its word "exactly" is FALSE under
the round-and-report ruling and 26-04 owns the correction. FEE-02's "checked before the solver is
invoked" is 26-03's ninth refusal and its Tier-C grid agreement is 26-04's. What shipped is FEE-01's
arithmetic and FEE-02's Tier-A half. Marking either complete now would be the assertion-without-an-
implementing-task shape this milestone keeps finding.

**SEVEN OF `FeeSplit`'S TWELVE FIELDS ARE ASSERTED BY NO CHECK IN ANY PLAN OF THIS PHASE**
(`fs_pool_fee_pips`, `fs_dstar_pips`, `fs_realized_scaled`, `fs_is_exact`, `fs_ellipse_e`,
`fs_boundary_pips`, `fs_band_size`) — reviewer minor `RC-m11`. The record is an interface for
26-03's constructor. If 26-03 does not assert them they are unread fields, and the phase close must
report them by name.

**THE CHAIN FLOORS WHAT THE SPLITTER DOES NOT.** `ProtocolFeeLibrary.calculateSwapFee` computes
`x + m - div(mul(x,m), 1000000)` under truncating EVM `div`, so the realized on-chain fee is high by
`frac(xm/D)` — up to a whole pip, always the same direction — independent of the splitter's own
signed half-pip residual. Phase 27's `compose(read pair) == pool fee` reconciliation will disagree by
exactly that term and must not read it as a splitter bug. **Also OPEN**: v4's `MAX_PROTOCOL_FEE` is
1000 pips and the pinned `f = 6497` seed-0 result `(1036, 5467)` exceeds it on BOTH legs, so which
two on-chain fields the legs are realized in is undecided.

### Phase 25 — closed, and the record below still binds

**THE SHOCK IS NOW THE KEY.** `Store.Key` frames its preimage so no two distinct inputs collide and
no per-run path can reach it (KEY-01..06, six checks); `Store.Cache.decide` looks that key up
BEFORE the solver is reachable and elides on a hit (STORE-01, two checks); an aborted run leaves
nothing behind (STORE-08, one check with a `Produced` positive control ordered first); and emptying
the store is a scoped operation the solve path does not name (STORE-06, two checks).

Suite **151/151 → 157/157 → 160/160 → 162/162**, exit 0, zero `-Wall` warnings, 0 `FAIL` lines.
Both structural greps **0** over `offchain/test/Main.hs` (DB-free and GAMS-free), each captured as
its OWN exit status, never from a pipeline and never gated on `grep -c`. Floors `purge_file_floor`
**62** and `credential_scan_floor` **71**, both re-measured cold at close against `find` printing
exactly 62 and 71 — **zero slack, and they did not move at 25-03, which is the expected reading**
because that plan adds no file under `offchain/`. Census `hs 50, sh 9, json 9, md 3, txt 2, sql 3`.
Territory clean.

**FIVE REQUIREMENTS ARE DEFERRED AND THEY ARE NAMED: STORE-02, STORE-03, STORE-04, STORE-05,
STORE-07.** Not dropped. Each has a written reason in `REQUIREMENTS.md`'s Store deferral block
(`REQUIREMENTS.md:70-88`) with traceability rows at `:208-214`. A requirement that vanishes without
a record is indistinguishable from one that was forgotten, so they are listed here, in
`25-SUMMARY.md`, in `REQUIREMENTS.md` and in `ROADMAP.md`'s phase entry.

**THREE DATABASE-REVIEW FINDINGS STILL BIND ANY FUTURE STORE WRITE.** `DB-B2`: a bare `ByteString`
on a `bytea` parameter type-checks, runs and CORRUPTS silently (6 bytes in, 3 out, measured on PG
18.4) — the `Binary` newtype is mandatory and **nothing structurally enforces it**, no compile
error, no helper, no source scan. `DB-M4`: the derived `doc` column's placeholders are all
`Binary ByteString`, so **transposing positions 3 and 4 compiles, runs, and derives `doc` from the
KEY**; a generated column would close it and is unavailable (`convert_from` is STABLE). `DB-M5`:
`jsonb` refuses the JSON escape for the NUL code point, so a legal RFC-8259 artifact containing it
**cannot be stored at all** while `doc` is `not null` — the derived projection vetoing the
authoritative bytes, undecided by this phase. The trigger-hardening findings `DB-B1`, `DB-M1` and
`DB-M2` attach to `run_log` and `quarantine`, which belong to deferred requirements, and do NOT
bind — unreached, not resolved.

**STORE-06 IS A TYPE PLUS A SCAN, IN THAT ORDER.** `store_reset :: ResetScope -> IO ()` makes the
unscoped call unwritable — there is no `store_reset store` that type-checks. What the type cannot do
is stop a module CALLING the scoped form: the field is in scope wherever `Store (..)` is imported,
and a typeclass would have the identical property. So the second half is a scan over
`Store/Cache.hs`. The plan's name `reset_is_unreachable_from_a_solve_or_a_publish` was rejected on
measurement — there is no publish path in this tree and the field is not unreachable — and it is
`no_solve_path_names_the_reset_entry_point`.

**THE ABSENCE SCAN READS THE FILE RATHER THAN SHELLING `grep -c`.** `grep -c` prints `0` for a file
that does not exist, so an absence claim built on it passes for the one reason that should fail it
loudest. The check asserts the file EXISTS and names `decide`, `store_put` and `store_lookup` —
fields of the same record, through the same import — before it asserts the reset token is absent.

**`25-02` HAS NO PLAN SUMMARY, AND THAT IS RECORDED RATHER THAN BACK-FILLED.** Its three task
commits landed (`1b733c4`, `6eba818`, `1164b4d`) and no closeout followed; this file's Current
Position still read "25-01 COMPLETE" until now, and its progress counters were never advanced for
25-02. Precedent: 24-05's summary was written and left untracked until 24-06 carried it. 25-02's
content is in `25-SUMMARY.md` and in its own unusually full commit messages; a summary reconstructed
after the fact from commit messages is a weaker artifact than the commit messages.

**`Store.Postgres.store_reset` IS NOT EXERCISED BY ANYTHING.** `cabal test` is server-free by
construction (DB-03) and no capture script drives a reset. Its statement takes no parameters, so it
carries neither the DB-B2 `Binary` hazard nor a DB-M4 placeholder — but "it compiles" is the whole
of the evidence for it, and the module haddock says so at the point of definition.

**NO END-TO-END STORE-01.** Nothing builds a production `Solver` from `Gams.Run.run_prover`;
elision is proven at the seam with a counting test solver. That was reviewer finding M3 and it is
the first thing phase 26 owes.

**GUARD #21 IS STILL OPEN**, and now closes as a phase-level carry-forward rather than a plan one.
Phase 24 named the artifact-side echoed-field cross-check as the mutation Phase 25 owed;
`the_preimage_excludes_every_per_run_token` discharges KEY-02's scope half, and the echoed-field
mutation was in the cut scope.

Next action: **execute 26-03** (`split_for`, `admissible_band`, the argv assembly). It carries three
inherited debts by name: blocker B1's `split_for` step-0 guard and its
`split_for 0 8388608 490000 == Left (FeeOutOfDomain 8388608)` arm; RC-M6's corrected empty-band size
(**2**, not 4 — `admissible_band 3000 1000 == [(1,2999),(2,2998)]`); and RC-m11's seven unasserted
`FeeSplit` fields. **`offchain/lib/Gams/Argv.hs` is now inside a grep's blast radius**: check 10's
second arm requires the decay identifier to appear NOWHERE in that file, prose included, and 26-03
and 26-04 both edit it — that arm has been OBSERVED firing on a haddock line. The production
`Solver` adapter that closes STORE-01 end to end is still owed and 26-02 did not touch it.

Last activity: 2026-08-17 — 26-02 executed (commits `b22b637`, `e69a2e8`, `d536d08`), 181/181.

## Phase 25 Plan 01 Position (record)

Plan: **25-01 COMPLETE** (commits `c0e2e9c`, `26378ad`). `Store.Key` shipped at `f00b40b` with no
check on it; it has six now, and KEY-01..06 are all discharged.

Suite **151/151 → 157/157**, exit 0, zero `-Wall` warnings, 157 s wall. Both structural greps still
**0** over `offchain/test/Main.hs` (DB-free and GAMS-free), each captured as its OWN exit status.
File floors did not move — no module was added, and that was the expected reading.

**THE FRAMING CHECK'S FIRST ARM IS THE CHECK.** `[("a","bcd"),("e","f")]` and
`[("ab","cd"),("e","f")]` are asserted byte-identical CONCATENATED BARE before anything is said
about `frames`. A pair built from fixed-length digests differs bare too and would have passed with
the framer deleted — the collision has to be exhibited or the separation is green about nothing.
The third arm carries it to `key_preimage`, so the claim lands on the real preimage.

**KEY-01'S PLAN STEP WAS WRONG AND THE CODE SAID SO.** The plan asked for `key_identity` to return
`Left` on an absolute model-source path. It does not: `relativise` takes `takeFileName` FIRST, so
`/var/lib/…/volume_path.gms` becomes `volume_path.gms` — not absolute, no separator — and the
identity is `Right` with the directory discarded. `AbsoluteModelSourcePath` fires only for a path
whose file name is EMPTY. The check asserts both halves (relativisation + the directory absent from
the preimage bytes; refusal naming the ORIGINAL path for the unrelativisable case) and was renamed
`no_key_identity_carries_an_absolute_model_source_path`, because a check named "refuses" while the
behaviour is "relativises" is the misleading artifact this repository keeps paying for.

**THE PER-RUN SCOPE CHECK WAS OBSERVED REDDENING, ONCE, THROWAWAY.** Seeding a legitimately-present
token (`lo=2`) into `key_per_run_tokens` took
`the_preimage_excludes_every_per_run_token` to FAIL at 155/157. Absence claims are cheap to write
and free to pass; this one has a live subject. It is the check that stops the store being useless —
`Gams.Run`'s wrapper vector carries an EXCLUSIVE PER-RUN temp dir, so a preimage containing it
reconstructs the argv perfectly and hits the cache exactly never.

**ABSENCE IS ASSERTED ON THE FRAMED FORM, NOT AS A BARE SUBSTRING.** The wrapper's budget and kill
delay are bare integers; a substring claim about them is a claim about which digits happen to occur
inside a sha256. `frames [token]` makes it a claim about a component. The forbidden tokens and the
installation path are assembled from string fragments, so the GAMS-free grep over `Main.hs` stays 0
— instance 19 of that hazard, anticipated rather than discovered.

**FOUR NAMES IN THE PLAN'S API LIST ARE NOT EXPORTED** — `build`, `relativise`, `source_frames`,
`parse_frames`. They are top-level bindings in `Store.Key` and absent from its export list. Nothing
was lost (the checks use `frames` and `key_preimage` instead), but 25-02 must not assume them.

**GUARD #21 IS STILL OPEN.** 24's phase-level finding named the echoed-field cross-check as the
mutation Phase 25 owes. `the_preimage_excludes_every_per_run_token` asserts KEY-02's scope half —
one renderer, no per-run tokens — but the artifact-side echoed-field mutation is not this plan's
subject and remains owed.

Next action (as recorded then): `/gsd:execute-phase 25` continues at **25-02** (`Store.Solver` /
`Store.Cache`: elide on hit, and no cache entry for an aborted run).

Last activity: 2026-08-17 — 25-01 executed (commits `c0e2e9c`, `26378ad`).

## Phase 25 Plan 02 Position (reconstructed at close — NO SUMMARY WAS WRITTEN)

Plan: **25-02 COMPLETE** (commits `1b733c4`, `6eba818`, `1164b4d`). No `25-02-SUMMARY.md` exists and
none was back-filled; see the note in the Current Position above. What it shipped:

- `Store.Solver` — the solver seam, a record of functions over `Gams.Run`'s own `ProverOutcome`. The
  outcome sum is **RE-EXPORTED, not redefined**: a second sum of the same name would have the cache
  speaking a type the real prover never returns.
- `Store.Cache.decide` — lookup FIRST, elide on a hit, persist only a completed run. It takes a
  `KeyIdentity` and a `Shock` and nothing that varies per invocation, so no budget, kill delay,
  binary path or per-run working directory can reach the key. `grep -c 'RunRequest'` over the file
  is 0.
- Three checks: `an_identical_shock_elides_the_solve`, `a_miss_invokes_the_solver_exactly_once`,
  `an_aborted_run_produces_no_cache_entry`. Suite **157/157 → 159/159 → 160/160**.
- **Two throwaway reddening observations, from its commit messages:** `decide` solving before the
  lookup and discarding the answer gave `FAIL … the solver was invoked 1 times on a shock whose key
  was already stored` (156/159) **with the VALUE arm still green** — exactly the "ran and was
  ignored" solver a counter-free check would pass; and `decide` returning the solver's bytes on a
  hit gave `FAIL … expected Elided with the STORED bytes` (156/159), naming the B′ document it
  returned. The pair is non-redundant, and that was measured rather than argued.
- Both floors re-measured by running both `find` commands, twice, once per module-adding commit:
  purge 60 → 61 → 62, credential 69 → 70 → 71, each against exactly that many files, zero slack.

## Phase 24 Closing Position (record)

Phase: **24 — GAMS Invocation & Toolchain Identity** — **COMPLETE (6/6 plans, 7/7 requirements)**
Plan: **24-06 COMPLETE.** `NOT NULL` is not non-empty, and the database was WATCHED saying so.

**A `"" == ""` LIVE SINCE PHASE 23 IS CLOSED ONE LAYER BELOW THE HASKELL GUARD.**
`001_model_run.sql` declares `gams_ver` and `conopt_ver` `text not null`, and **`text not null` does
not forbid `''`** — so the schema underneath `Gams.Version`'s unconstructible-empty newtype would
still have accepted the empty string from any other writer. Migration
`003_version_columns_nonempty.sql` adds a NAMED `check (length(gams_ver) > 0 and length(conopt_ver)
> 0)`, and the refusal was **OBSERVED against a real Postgres 18.4**, not argued from the DDL:
SQLSTATE **`23514`**, on **`gams_ver` and `conopt_ver` independently** (each with the other column
left non-empty), through **`store_put` — the store's own `Binary`-wrapped write path**, with the
server's own message naming the constraint and `rows_after` **0** from the server's own count. Suite
**149/149 → 151/151**, FAIL 0, zero `-Wall` warnings, still DB-free AND GAMS-free, wall 150.0 s
against 900 s.

**THE POSITIVE CONTROL IS WHAT MAKES THE REFUSAL MEAN ANYTHING.** The identical row with both
versions non-empty **LANDS** (`control_accepted true`, `control_rows_after 1`). "It raised" is
satisfied by a dead connection, a malformed key, a `doc` that is not JSON and a table that does not
exist — this repository's whole defect class. The control is evaluated BEFORE the rejections in both
the script gate and the in-suite check.

**THE COPY-PASTE CONSTRAINT WAS MEASURED, NOT ARGUED.** With `003` cut down to
`check (length(gams_ver) > 0)` and nothing else changed, the capture recorded **`rejected: false`** —
the server **STORED** an empty `conopt_ver`. The two-conjunct constraint is not tidiness, and the
same run is the restore-on-failure proof: the capture DID write a new artifact, the gate fired, and
the committed evidence came back **byte-identical by DIGEST** (`4111b1f3…520f18e8`), which is the
instrument phase 23's first docker probe taught us to use instead of an exit code.

**A FIELD THE HARNESS CAUGHT WAS DELETED, NOT ASSERTED.** The first version of the observation
carried a per-column `attempted` and it was the literal `True`; the sentinel sweep reported all six
of its mutations ABSORBED. Asserting it would have compared a constant to itself — 24-04 MEASURED
that shape leaving a suite **138/138 green with the library renamed underneath it**. The honest
per-column form is the ENTRY, and the array's column set is compared to
`Store.Schema.versions_nonempty_columns` in BOTH directions.

**THE STORE ARTIFACT'S TOP-LEVEL SURFACE IS NOW A SET IN BOTH DIRECTIONS** —
`expected_store_observation_blocks`. **Fifth list found in this phase without a growth guard and the
fifth to get one.** OBSERVED with the COUNT-PRESERVING RENAME control:
`empty_version_rejected` → `empty_version_refused` leaves **14 keys before and 14 after**, so a
count passes, and the set reddens in both directions at once.

**THE READINESS POLL WAS NOT A READINESS GATE, AND IT COST THREE CAPTURES.**
`pg_isready` over the container's UNIX SOCKET is satisfied by the entrypoint's TEMPORARY bootstrap
server — and it reports `FATAL: database "..." does not exist` as *accepting connections*. The poll
passed, the bootstrap server shut down, and the client's first query hit the close. `-h 127.0.0.1`
is the discriminator, because the bootstrap server has no TCP listener. Pre-existing since 23-04; it
failed in the SAFE direction every time, which is exactly why it survived. A companion bug in the
same block: `read -r a b c <<< "$(jq …)"` collapses when `sqlstate` is legitimately empty — one `jq`
call per field now.

**BOTH TREE-DERIVED FLOORS RE-MEASURED COLD, BEFORE AND AFTER, and the brief was wrong.** The plan
brief said `purge_file_floor` 55 / `credential_scan_floor` 63; those are **24-04's** numbers.
Measured cold on disk before anything was edited: **58 / 67**, zero slack. After the migration:
**59 / 68**, zero slack, census `hs 47, sh 9, json 9, md 3, txt 2, sql 3`. `sentinel_pair_floor`
**3698 → 3828** and `artifact_field_floors`'s `store-conformance.json` **134 → 156**, both raised
until the harness NAMED what it reached; the five other artifacts came back at exactly their old
numbers.

**PROSE INSIDE A GREP'S BLAST RADIUS — INSTANCE 18.** This plan's own haddock said "every future
writer that is not `Store.Postgres`", inside the file whose scan asserts no such token is in it. The
verification grep returned 1. Eighteen times now; the answer has never changed.

**PHASE-LEVEL FINDING: FOUR of 24-RESEARCH's 41 guards have a standing assertion and NO mutation.**
Named, not omitted (23-05's guard #13 precedent): **#11** `conopt_parse_is_position_independent`
(never falsified — 24-01 records it staying GREEN under a sibling's mutation, which is not an
observation of it); **#21** the echoed-field cross-check (24-03 exercised it and it PASSED; the
freshness conjunct did the catching); **#23** the 2 MB stderr drain (its firing input is a deadlock
and no mutation removed the drain); and **#28/#30** (the empty hostile-variable set and the
fewer-than-16-of-16 arm, both asserted every run, neither mutated). Guard #21 is the one Phase 25
must close — KEY-02's own success criterion asks for exactly that mutation.

**ALL SEVEN PHASE-24 REQUIREMENTS ARE COMPLETE**, and `24-RESEARCH`'s five-part gate on starting
Phase 25 is discharged in full.

Next action: `/gsd:plan-phase 25`.

Last activity: 2026-08-17 — 24-06 executed (commits `158ca84`, `79f8ad8`).

## Phase 24 Plan 05 Position (record)

Plan: **24-05 COMPLETE** (commits `15c539c`, `2e1a390`, `ac607bd`, closeout `1df084a`). The real
GAMS 54.1.0 / CONOPT 4.39.0 driven once out of band into `offchain/rig/gams-conformance.json`; ten
Tier-C checks resting on it; 75 of the artifact's 76 leaves read by one of them; the sixth swept
artifact; four floors re-measured; fourteen firing observations; `cabal test` still structurally
unable to name the solver. Suite **138/138 → 149/149**. GAMS-01/02/04/06 marked COMPLETE.
**Its summary was written but never committed** — `24-05-SUMMARY.md` was untracked until 24-06's
metadata commit carried it, unmodified. A phase record that exists only on one machine's disk is not
a record.

Its three carry-forwards that outlive the phase: `gams-conformance.json` is NOT byte-stable across
re-captures (`generatedAt` and two banner `line1`s carry a wall clock, MEASURED);
`Gams.Invoke.raw_gams`'s timeout has never been observed firing (the production path through
`run_prover` HAS been, at 24-04); and `conopt_true_line_index_real` is **48**, not the 47
`24-RESEARCH` records.

## Phase 24 Plan 04 Position (record)

Plan: **24-04 COMPLETE.** The hung GRANDCHILD, two real environment vectors, a version that cannot
be missing, and the structural guarantee that `cabal test` cannot reach the real prover. Suite
**131/131 → 138/138**, FAIL 0, zero `-Wall` warnings, still DB-free AND GAMS-free, **+0 packages**.

**THIS PLAN WAS INTERRUPTED AND CONTINUED.** Tasks 1 and 2 were committed (`8f5d2ef`, `a8a3a21`)
and the executor then died mid-Task-3 on a connection loss, not a code failure. A second executor
re-measured every inherited claim cold before touching anything — build, suite, both greps,
`git status`, both commits — and only then executed Task 3 (`76184d0`) and closed the plan out.

**THE TIMEOUT IS NOW FALSIFIED, AND ON THE RIGHT SUBJECT.** 24-03 left guards 23/24/25 built and
never observed firing, and this phase's own rule treats an unobserved guard as ABSENT. The stub
backgrounds `sleep 300 &` and `wait`s, so the process under test is a GRANDCHILD — **MEASURED,
written against a direct child the check CANNOT FAIL**, because `System.Timeout.timeout` reaps a
direct child with no orphan and the assertion would be green with or without the group-owning
`/usr/bin/timeout -k`. Liveness is read from `/proc/<pid>`. The negative control was OBSERVED: with
`Gams.Run` spawning the binary directly, `/proc/3896506/stat` reported `3896506 (sleep) Z 1 …` —
the grandchild reparented to PID 1 and still present. `pgrep -a 'sleep 3'` is 0 after the suite.

**THE WHITELIST IS PROVEN IN FORCE BY TWO REAL VECTORS, NOT BY BYTES.** The inherited child carries
**64 keys** against the whitelist's 3, and `shell_injected_env_keys = ["PWD","SHLVL","_"]` was
MEASURED on this host rather than copied from the plan. A byte comparison could not do this work:
four hostile ambient variables changed nothing and there is no comma-decimal locale on this machine.
**And the check as planned COULD NOT FAIL** — its expected side was `whitelist_for scratch`, the
same expression as its subject, so deleting `LC_ALL` moved both sides together. OBSERVED, then
fixed against `whitelist_keys`. **Seventh representation of this project's standing defect, found
inside the check written to catch the sixth.**

**`cabal test` IS NOW STRUCTURALLY INCAPABLE OF NAMING THE REAL SOLVER, AND SAYS SO IN-SUITE.**
`the_suite_never_names_the_real_solver` is the DB-free scan's twin: three tokens BUILT by
concatenation, scanned over `offchain/test/Main.hs`, with a **PROVEN positive control** — a seeded
bait carrying all three in the shapes they would really appear in must be NAMED, a clean file
carrying the IO edge and `/bin/sh` must not be, and the control is ordered FIRST. It is no longer a
verification-time command an executor has to remember.

**23-05's `PGSTORE_DSN` RULING TRANSFERS UNWEAKENED.** `GAMS_CONFORMANCE` is registered and probed;
`GAMS_BIN` and `GAMS_MODEL` are NAMED GAPS with written reasons, because their consumer is the
module the grep above makes unreachable, and both ways of manufacturing a subject are rejected —
importing it breaks the GAMS-free property on its way to enforcing it, and a validator written only
to be probed is a registered-but-vacuous probe. `probe_override` was not weakened.

**A PLAN ACCEPTANCE CRITERION WAS MEASURED BACKWARDS AND REJECTED.** Criterion 5 asked for the
variable to be referenced through `gams_conformance_env_var` rather than spelled, *"which is what
makes a rename in the config module redden the sweep"*. It is the reverse, and the plan contradicts
itself (its action says "same shape as `STORE_CONFORMANCE` exactly", which is a literal). MEASURED:
with the constant in the list, renaming it in `Gams.Config` leaves the whole suite at **138/138,
exit 0**; with the literal, the identical rename reddens **two independent checks**. The literal is
kept and the counter-measurement is written into the check's haddock so it is not re-proposed.

**THE LIST ITSELF GOT A GROWTH GUARD.** `config_env_vars` now pairs each value with the NAME of the
constant holding it, and a census grepped out of `offchain/lib/{Store,Gams}/Config.hs` is compared
BOTH WAYS. Dropping a variable from the list was OBSERVED leaving the pre-existing coverage arm
GREEN — it is a per-variable arm — and the census is what reddened. A sixth variable in either
config module can no longer be added silently.

**GAMS-05 IS COMPLETE.** Every row of roadmap SC-4 shipped and every one is OBSERVED, and "never an
output row" was discharged at the TYPE level at 24-03 under planning correction 1. **GAMS-03 and
GAMS-06 stay PARTIAL**, each owing exactly one capture-artifact row that does not exist until 24-05:
the resolved absolute binary path plus executable sha256 (GAMS-03), and a hostile ambient variable
producing byte-identical output (GAMS-06).

**BOTH FLOORS RE-MEASURED COLD, TOGETHER, AND NEITHER MOVED:** `purge_file_floor` **55** against
exactly 55 files, `credential_scan_floor` **63** against exactly 63 — zero slack on both. This plan
adds no file; the re-measurement was done because the rule is that a floor is re-measured whenever a
plan is already editing this block, and 24-02 is why.

**PROSE INSIDE A GREP'S BLAST RADIUS — INSTANCE 16.** Task 3 wrote a check, a pattern, a bait, a
positive control and three override reasons that all have to DESCRIBE the three forbidden tokens
without naming them, inside the file being scanned. Every one describes rather than lists; pattern
and bait are both built by concatenation. Sixteen times now, and the answer has never changed.

**THE WALL.** 78.3 s at 24-03's end → **140.9 s**, all with the binary pre-built. Tasks 1-2 cost
+61.7 s (six checks that each spawn several real children, one waiting out a 2 s budget, one pushing
2,000,000 bytes through a pipe); Task 3's structural check costs **+0.9 s**. Budget 900 s.

Next action: `/gsd:execute-phase 24` (plan 24-05).

Last activity: 2026-08-16 — 24-04 executed (commits `8f5d2ef`, `a8a3a21`, `76184d0`).

## Phase 24 Plan 03 Position (record)

Plan: **24-03 COMPLETE.** The ONE IO edge. `Gams.Run.run_prover` is the only function in this
phase that spawns a process, and the verdict it returns is a **conjunction of six** of which not
one is log text: the exit code classifies as `Solved`; the artifact exists in a directory that
could not have pre-existed; its mtime is at or after a marker written just before the spawn; it
decodes; both echoed fields equal the argv token **sent**; and the run's own log carries a job
banner naming the invoked model.

Status: **EXIT 0 MEANS "GAMS RAN", AND THE SUITE NOW DRIVES THAT RATHER THAN ARGUING IT.** Five
Tier-B checks spawn real `/bin/sh` children the checks write themselves. A stub whose whole body
is `exit 0` is REFUSED — MEASURED with the real binary, `action=c` is exactly that shape. The
**real 606 committed golden bytes** planted at the process's own working directory, with a valid
job banner beside them and a shock equal to the golden's own inputs, are UNREACHABLE. Two stubs
with the same exit code and opposite log text (`Normal completion` against `** Locally
Infeasible`) give the IDENTICAL verdict, and that arm has its own positive control asserting the
two stdouts actually DIFFER. Suite **126/126 → 131/131**, FAIL 0, zero `-Wall` warnings, still
DB-free AND GAMS-free, **+0 packages**.

**`Aborted` HAS NO ARTIFACT, AND THE COMPILER SAID SO THREE WAYS.** Correction 1 is stated at the
type level rather than deferred to Phase 25's run-log table, and the GHC output is quoted verbatim:
`Patterns of type 'ProverOutcome' not matched: Aborted _ _ _` (the accessor cannot be total),
`Couldn't match expected type 'ProverArtifact' with actual type 'AbortReason'` (there is nothing of
that type inside `Aborted`), and `Module 'Gams.Run' does not export 'outcome_artifact'`. A
consequence measured rather than predicted: **the mutation the plan named for firing observation 1
is not expressible** — `Produced` demands an artifact and a run that wrote nothing has none.

**THE FRESHNESS CONJUNCT WAS THE BELT, NOT THE BRACES.** Firing observation 2 pointed the artifact
read at the process CWD instead of the run directory, and the plant was caught by `StaleArtifact`
— found, decoded, echoed fields matching, and losing on its modification time. Pitfall 8's
belt-and-braces observed doing the catching.

**`purge_file_floor` HAD NEVER MOVED.** 24-02's summary states it went 51 → 54 in `2a558e3`;
`git show` on that commit and every commit since reports **51**, against **55** files on disk —
**four of slack**, in the guard whose entire job is to detect a scan that collapsed. Its twin
`credential_scan_floor` DID move, so one half of a pair that is always re-measured together landed
and nothing reddened. Both are now re-measured cold: **51 → 55** and **62 → 63**, zero slack on
both, with the discrepancy recorded in the floor's own haddock and the rule restated as a pair.

**PROSE INSIDE A GREP'S BLAST RADIUS, THREE MORE TIMES IN ONE PLAN — instances 13, 14 and 15.**
`Gams/Exit.hs`'s explanation of why a layer must not read the model-status word contained it;
`Gams/Run.hs`'s haddock spelled all three identifiers its own acceptance criteria grep for at zero;
and the comment beside the new `Gams.Run` import asserted the three GAMS-free tokens stay out of
`Main.hs` **while listing all three**, so the verification grep returned 2. Every time the prose
moved and no pattern was relaxed.

**THE TIMEOUT IS BUILT BUT NOT YET FALSIFIED.** `/usr/bin/timeout -k` (which owns the process
GROUP, because CONOPT is a grandchild at `Solvelink=2`) and the in-process backstop are both in
`Gams.Run`, and neither has been OBSERVED firing. Guards 23/24/25 are GAMS-05's and belong to
24-04; until they run, this phase's own rule treats the timeout as absent.

**THE WALL.** 73.1 s before, **78.3 s** after, both with the binary pre-built. +5.2 s for five
checks that each spawn several real children, and the reason it is that cheap is `sweep_one`'s
`readable` filter: these five read no swept artifact, so they run once per full `core_checks` pass
rather than once per sentinel pair. Budget 900 s.

**GAMS-01 and GAMS-02 stay PARTIAL.** Every Tier-A and Tier-B row of both shipped and every one is
OBSERVED; each still has exactly one **Tier-C** row that reads a capture artifact which does not
exist until 24-06.

Next action: `/gsd:execute-phase 24` (plan 24-04).

Last activity: 2026-08-16 — 24-03 executed (commits `847bc9c`, `f557e16`).

## Phase 24 Plan 02 Position (record)

Plan: **24-02 COMPLETE.** The renderer that decides the artifact's bytes, the environment
whitelist, and the decoder that never builds a 53-bit floating value. **BYTE-04 is MARKED
COMPLETE** — the first requirement closed in this phase, because all six of its Tier-A rows
shipped here and every conjunct has a check that reads it. GAMS-02 and GAMS-06 stay PARTIAL:
their remaining halves are Tier-B subprocess checks that do not exist yet.

Status: **THE LEADING ZERO CANNOT REACH THE `execve`.** `parse_shock_field` NORMALIZES at the
edge, so `079228162514264337593543950336` and `79228162514264337593543950336` become one
`Integer` and one token — which also settles Phase 25's KEY-04 (`28e18` and
`28000000000000000000` are the same value) upstream of any row. `Shock` carries seven strict
`Integer`s with no optional and no defaultable field, and eight shape-valid shocks are refused BY
FIELD NAME. Suite **117/117 → 126/126**, FAIL 0, zero `-Wall` warnings, still DB-free AND
GAMS-free, +0 packages.

**BYTE-04 IS TWO EQUALITIES ON `Integer`s, TIED TO THE FILE BY A DIGEST CHECKED FIRST.**
`dQx[0]`'s 53-bit image is pinned at `-2613128317657530368` and the move is asserted as
`image - exact = +32` — the research table's sign convention, now STATED, because the check was
first written the other way round and its own first run caught it (an `abs` would have hidden it).
16 of 16 elements are shown inexact, `|delta|` in `[4, 328]`. The provenance digest runs BEFORE
the decode, so an edited artifact fires on identity rather than producing a
different-but-plausible vector.

**THE REASSIGNED HOLE IS CLOSED, NOT DEFERRED.** `aeson_storage_path` had no directory
cross-check and wave 1 proposed 24-04. `Gams/Artifact.hs` went onto the list in the commit that
created it, all five sibling GAMS modules with it, and research guard 34 landed in the same
commit — a both-directions assertion over `offchain/lib/{Store,Gams}/` with an EMPTY, reasoned
exemption list. Then the same defect was found INSIDE the fix: the new float scan was a
hardcoded two-file list with no growth guard of its own. `artifact_float_path` is now
`aeson_storage_path` — one set, one growth guard, thirteen more files covered at zero cost, and
`budget :: Double` seeded into `Gams/Env.hs` was OBSERVED reddening it by file and line, which
before that fix would have been silent.

**FIVE FIRING OBSERVATIONS.** A leading-zero renderer named the `=0` token; an edge that REFUSED
the leading zero instead of normalizing it fired the M7 arm the plan named (the planned mutation
fired the positive arm first, so both were run and both recorded, as at 24-01); a decoder that
took `1.5` as `1` put a wrong wei amount into `dQx`; ONE byte of
`offchain/rig/volume-path-golden.json` — length unchanged at 606 — fired on the DIGEST before
the decode; and an unlisted `Gams/Publish.hs` was named by BOTH directory-vs-list guards. Every
source restored **from a saved copy** verified sha256-identical, never by `git checkout`.

**THE PROSE TRAP FIRED A TWELFTH TIME — AND THIS TIME IT WAS IN THE PLAN.** 24-02's task 1 action
asked for a haddock explaining why `show` on a `Double` is locale-dependent, while its own
acceptance criterion greps that file for `Double` expecting 0. The reasoning was kept and the
words changed; the pattern was not relaxed.

**BOTH TREE-DERIVED FLOORS RE-MEASURED COLD, in the same commit as the modules that moved them:**
`purge_file_floor` 51 → **54** and `credential_scan_floor` 59 → **62**, each from
`find … | wc -l` run at execution time. **Zero slack for the second plan running** — 51 against
exactly 51 files, 59 against exactly 59.

> **CORRECTED AT 24-03 — the `purge_file_floor` half of that sentence is FALSE.** `git show` on
> `2a558e3` and on every commit after it reports `purge_file_floor = 51`. The number was measured
> and written into the summary; the edit never reached `Main.hs`. Only `credential_scan_floor`
> moved. The floor therefore sat four below its subject with nothing red, which is the defect class
> this milestone's standing rule names, inside the guard that exists to detect it. Left in place
> rather than rewritten, because what was believed is part of the record; the correction is 24-03's
> deviation 3 and both floors are now 55 / 63 against exactly 55 / 63 files.

**THE WALL.** 68 s before, **76 s** after, with the test binary already built both times (24-01's
87.8 s included compilation and is not comparable). Nine checks cost ~8 s, two of which spawn
`grep` inside the sentinel harness's ~3250-pair multiplier. Budget 900 s.

Next action: `/gsd:execute-phase 24` (plan 24-03).

Last activity: 2026-08-16 — 24-02 executed (commits `2a62cce`, `46ba4fc`, `2a558e3`, `8fc2bd6`).

## Phase 23 Closing Position (record)

Phase: **23 — Postgres Foundation & the Byte-Exact Schema** — **COMPLETE (5/5 plans)**
Plan: **23-05 COMPLETE.** All **nine** phase requirements marked complete for the first time
(DB-01..04, BYTE-01/02/03/05, KEY-07) — four plans deliberately held them at PARTIAL because
evidence unread by any check is the artifact-asserted-by-nothing shape (issue #19). **That
condition is now discharged.** Next: `/gsd:plan-phase 24`.

Status: **THE EVIDENCE IS LOAD-BEARING.** Thirteen new checks turn
`offchain/rig/store-conformance.json` from a committed file nothing read into the artifact eleven
assertions rest on. **Suite 111/111, FAIL count 0, still DB-free** — the three-token grep over
`offchain/test/Main.hs` is still **0**. `cabal test` WALL went **78 s → 97 s** with the fifth swept
artifact; the budget was 900 s and the artifact was NOT narrowed.

**SIXTEEN FALSIFICATIONS OBSERVED**, each against its named input, and the committed artifact's
sha256 (`1e5f076a…d332153`) is byte-identical before and after all of them. The four the plan named:
ABSENT (all eleven artifact-reading checks fail, naming the capture command — none skips), STALE (a
real `.sql` edited: `recorded=9e89722c… recomputed=ff649f32…`), TRUNCATED (`sc_complete false`), and
a MISSING LAW VERDICT — **reported as a SET mismatch while `sc_law_count` still read 8**, which is
the demonstration that a count-based instrument would have passed that input.

**THE BARE PATH TURNED OUT TO BE PREDICTABLE.** The sentinel harness reported four fields of the
new artifact absorbed; three were ASSERTED rather than pardoned. `bare_out_len` and
`bare_out_sha256` are now compared against `bare_path_prediction` — a MODEL of the two mechanisms
(libpq's C-string escaper truncating at the first NUL, then `byteain`'s legacy escape decode)
computed from `cm_bytes` in `Store.Types`, never from the artifact. It reproduces **all five
returning corpus members exactly, in length AND digest**. BYTE-05's negative control is now an
outside oracle rather than a bound. Only `generatedAt` is pardoned.

**`PGSTORE_DSN` IS A NAMED GAP, NOT A PROBE.** Its consumer is libpq, reachable only through the
client module and the capture executable, and neither is reachable from `cabal test` BY
CONSTRUCTION — that is DB-03. Manufacturing a consumer (a `validate_dsn` written only to be probed)
would be a registered-but-vacuous probe, the exact defect the sweep exists to catch. It lives in a
new **asserted** `unprobed_overrides` list with a written reason, and the two halves that ARE
measurable (verbatim resolution, differs-from-default) are asserted. `probe_override` was not
weakened. `STORE_CONFORMANCE` IS registered and was observed firing on three arms.

Next action (at the time): `/gsd:plan-phase 24` — DONE; phase 24 is planned (6 plans) and 24-01
is executed.

Last activity: 2026-08-16 — 23-05 executed (commits `96736a4`, `90f6c4f`).

### The six phases

| Phase | Name | Reqs | Blocked? |
|---|---|---|---|
| 23 | Postgres Foundation & the Byte-Exact Schema | 9 | **COMPLETE 5/5, all 9 reqs** |
| 24 | GAMS Invocation & Toolchain Identity | 7 | No |
| 25 | The Content Key & Keyed Store | 14 | No |
| 26 | Shock Assembly — Fee Split & Event Decode | 5 | No |
| 27 | Anvil Read Layer | 3 | **Yes** — plank must emit `next` (issue #26) |
| 28 | Resident Loop & Fixture Publication | 5 | **Yes** — inherits 27 |

Execution order 23 → 24 → 25 → 26 → 27 → 28, with **26 parallelizable against 23–25** (zero
dependencies beyond `base`). **23 → 24 → 25 is a genuine chain.**

### Three changes from the six phases approved in brainstorm

The approved shape was (1) Postgres foundation, (2) keyed store, (3) GAMS invocation, (4) Anvil
read layer, (5) fee splitter, (6) resident loop. Same six bodies of work; three things moved:

1. **GAMS invocation moved 3rd → 2nd, ahead of the store.** The key contains the GAMS and CONOPT
   versions (KEY-01), so GAMS-03/GAMS-04 are a *prerequisite* of STORE-01. An emptily-succeeding
   detector (`"" == ""` — this repo's defect #1, verbatim) poisons every row written before it is
   fixed, and those rows are indistinguishable afterwards.
2. **Byte-exactness + `key_scheme` moved into the earliest schema phase (23).** BYTE-01/02/05 and
   KEY-07 are schema decisions every later phase consumes; an artifact stored only in `jsonb` is
   unrecoverable as bytes, and a key-formula change without `key_scheme` is a full-table rebuild.
   Phase 23 is **not plumbing**.
3. **Fee splitter and Anvil swapped (5th ↔ 4th), and CHAIN-04 pulled out of the Anvil phase into
   the splitter phase.** The Anvil phase is BLOCKED; the splitter is not. CHAIN-04 is explicitly
   not blocked — decoding runs against synthetic logs. This makes 23–26 a contiguous chain-free
   block.

**Unchanged and load-bearing:** the byte-reproduction proof — the milestone's headline falsifiable
claim — lands at the end of **Phase 25, with no chain and no upstream**. If the plank block
persists, 23–26 still deliver a complete, verified subsystem.

### Requirement count correction

`REQUIREMENTS.md` said *"39 v6.0 requirements defined"* in both its header and its footer. The
actual checkbox count is **43** (BYTE 5, KEY 7, STORE 8, DB 4, GAMS 6, FEE 4, CHAIN 4, LOOP 5).
Corrected in place; nothing was added or dropped to make the arithmetic work.

### Standing rule for every v6.0 success criterion

This project's review history is dominated by **one** defect class: *an assertion that passes
when its subject is absent* — found six times, each after the previous sweep was declared
complete (`"" == ""`, numeric zero, a count-preserving rename defeating a count floor, an empty
ref file, a CI `grep -q` over an empty log, `0x00…00` passing every hex-shape guard), plus a
seventh (a recorded field derived from the same expression as its own comparison target). v6.0
hands it five new representations: a content hash, a version string, a subprocess exit code, a
determinism check, and a DB test that skipped. **Every criterion is stated as something that can
FAIL** — "X is rejected", "Y aborts when absent", "the mutant Z is OBSERVED caught". "Tests pass"
is not a criterion; a suite that skips also passes.

### Blocked-work coordination

Phases 27–28 wait on the plank worktree emitting the `next` event (`SELECTOR_NEXT 0xd3827b0b` =
`next(address,uint160,int24,uint24,uint24)`); it is a stub today, owned by issue #26. Phase 28
additionally needs the `test/models/mev_tax_model_one/fixtures/` path agreed with the owning
track **before** planning — it does not exist in this worktree today.

**v5.0 closed:** merged to develop as `19a06f3` (PR #9, 209 commits) on 2026-08-03 with
`--admin`, bypassing the `gate` check. CI has NEVER validated it; the `haskell` gate job's
first real execution will be on develop — and v6.0 adds Postgres as a *second* external
prerequisite to a job that has not yet survived its first. Local evidence at merge:
`cabal test` 91/91, zero `-Wall` warnings, `forge test` 252/0 (== develop's baseline),
`verify-rig.sh`/`verify-import.sh` exit 0. Follow-ups filed: #19 (rig payload asserted by
nothing), #20 (MixedReadback block unfalsifiable offline).

## v4.0 Closing Position (record, plank workstream)

Phase: 19 — Differential, Mutation Battery & Consumer Fixture (MVER-01..04) — **COMPLETE**
Milestone: **v4.0 COMPLETE** — all five phases (16, 17, 18a, 18b, 19) and all 15 requirements (VORD-01..05, MCAL-01..06, MVER-01..04) done.
Plan: 19-01 COMPLETE (MVER-01), 19-02 COMPLETE (MVER-03), 19-03 COMPLETE (MVER-02 part A), 19-04 COMPLETE (MVER-02 part B — **MVER-02 fully satisfied**), 19-05 COMPLETE (MVER-04).
Status: 19-05 done — MVER-04 satisfied. `test-vol-order-acceptance` (plus `test-vol-order-diff`, `test-vol-order-fixture`) exists and exits 0; the fold-in is an OBSERVATION (all three Phase 19 contract names seen in plain `make test`), not a prerequisite — `make test` is already a whole-tree `forge test`, and a prerequisite would double-run pos_spec and inflate the tally. **Counts re-MEASURED cold at execution time and every red ATTRIBUTED:** `make test` **102 passed / 18 failed / 120 total (44 suites)**, `make compile-plank` **11 ok / 2 failed** — 14 exposure `setUp()` reverts (the uncommitted `VegaIssuanceLib.plk` draft, `unresolved identifier 'VolOrder'`), 4 vol-type track under `test/types/pos_spec/`, **0 under `test/pos_spec/`**, 0 TickVolatility (did not surface). The stale `MEASURED AT 17-01` block (96 pass / 4 fail, 13 ok — both wrong) was REPLACED, not amended. The real gate is VERIFIED not inferred: `batchSelectorIsNowDispatched`, `mixedBatchFootprintAndContiguity`, `mixedBatchReturnIsByteExact` all CALLED green through `deployPlank`/FFI bytecode. `PLANK_SKIP` byte-identically empty; no exit ceremony invented. `src/` byte-untouched.
Status: 19-04 done — the consolidated MVER-02 battery is complete. **10 mutant applications across parts A and B, 10 observed REDs, SURVIVOR COUNT ZERO**, every mutated source restored sha256 byte-identical (`be196dcb…cc9b8787`, `5fe71f30…73fe8f35`). Guard 3's kill was taken from the REVERT assertion, never a state check, and its state-invisibility was RE-MEASURED (`VolOrderManagerBatchStateTest` green 2/0 under the mutant). M8's N=0 blindness re-measured GREEN; the element-base-shift (N=0-BLIND) vs head-drop (N=0-VISIBLE) mapping settled by measuring BOTH variants rather than inheriting 18b's. M9 killed by the raw-word canonicality assertion, with the `abi.decode` `EvmError: Revert` cascade recorded separately as the Haskell-consumer contract. **Four mutants have a SINGLE point of failure** (M2 outside pos_spec entirely; M4's 65536 test; M5/M6/M7's `VolOrderManagerBatchGuardTest`) — wave 1 structurally cannot cover the malformed-input or large-id surfaces.
Status: 19-01 done — the interleaved sequence differential is green and the module AGREES with an independent Solidity mock at tol 0 across mixed `(create_order | create_orders)` sequences. No disagreement observed. `src/` byte-untouched (both sha256 pins match the 18b baseline).
Status: 19-02 done — MVER-03 satisfied. The consumer golden fixture is committed with bytes produced by `cast abi-encode` (alloy), an encoder OUTSIDE this repo; the module's returndata matches it byte-for-byte across 5 cases including N=0, INDEPENDENTLY CONFIRMING 18b's 64+64N layout from a third encoder. All four interface selectors recomputed with `cast sig` and matching, plus a completeness gate that reddens on an unpinned fifth. **The cross-language gap is NOT closed:** alloy proves STANDARD-ABI conformance only; peer `mv15a18k`'s Haskell decoder remains unexercised and is marked per-case in the fixture.
Last activity: 2026-07-21 — 19-05 executed: three dedicated make targets (acceptance target exits 0); the stale `MEASURED AT 17-01` block replaced with cold-measured counts, every red attributed to a named cause; the CALLED-green batch dispatch verified by three named tests; `PLANK_SKIP` confirmed empty and the roadmap's stale exit wording corrected. `src/` byte-untouched.

Progress (v4.0): [██████████] 100% — 5/5 phases (16, 17, 18a, 18b, 19), 9 plans complete. **MILESTONE COMPLETE.**

## Performance Metrics

**Velocity:**
- Total plans completed (v4.0): 9
- Average duration: 29 min

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 16 — Type Packing & Validation | 1 | 118 min | 118 min |
| 17 — Interface & Single-Call Module | 1 | 11 min | 11 min |
| 18a — Batch Input & State Effects | 1 | 21 min | 21 min |
| 18b — Typed Return Encoding | 1 | 27 min | 27 min |

*Updated after each plan completion*
| Phase 23 P01 | 41min | 3 tasks | 5 files |
| Phase 23 P02 | 62min | 3 tasks | 5 files |
| Phase 23 P03 | 44min | 2 tasks | 6 files |
| Phase 23 P04 | 33min | 3 tasks | 12 files |
| Phase 23 P05 | 71min | 2 tasks | 2 files |
| Phase 24 P01 | 22min | 3 tasks | 5 files |
| Phase 24 P02 | 33min | 3 tasks | 5 files |
| Phase 24 P04 | 107min (interrupted; 20:45→22:32 across two sessions) | 3 tasks | 1 file |
| Phase 25 P01 | 41min | 3 tasks | 1 file |
| Phase 19 P01 | 6 | 3 tasks | 3 files |
| Phase 19 P02 | 33 | 3 tasks | 3 files |
| Phase 19 P03 | 24 | 3 tasks | 1 files |
| Phase 19 P04 | 21 | 2 tasks | 1 files |
| Phase 19 P05 | 5 | 3 tasks | 2 files |
| Phase 20 P01 | 4 | 3 tasks | 3 files |
| Phase 20 P02 | 13 | 3 tasks | 40 files |
| Phase 20 P03 | 12 | 3 tasks | 4 files |
| Phase 20 P04 | 14 | 2 tasks | 4 files |
| Phase 20 P05 | 22 | 3 tasks | 11 files |
| Phase 21 P02 | 6 | 2 tasks | 3 files |
| Phase 21 P01 | 11 | 3 tasks | 6 files |
| Phase 21 P03 | 15 | 3 tasks | 4 files |
| Phase 21 P04 | 15 | 2 tasks | 5 files |
| Phase 21 P05 | 19min | 3 tasks | 6 files |
| Phase 22 P01 | 9 | 2 tasks | 10 files |
| Phase 22 P02 | 47 | 3 tasks | 5 files |
| Phase 22 P04 | 31min | 3 tasks | 8 files |
| Phase 22 P05 | 22min | 3 tasks | 8 files |
| Phase 22 P06 | 41 | 3 tasks | 9 files |
| Phase 24 P03 | 41 | 2 tasks | 4 files |
| Phase 24 P05 | 110min | 3 tasks | 7 files |
| Phase 24 P06 | 120min | 2 tasks | 6 files |
| Phase 26 P02 | ~5h | 3 tasks | 3 files |
| Phase 26 P03 | 180min | 3 tasks | 5 files |
| Phase 27 P01 | ~2h | 4 tasks | 16 files |

## Accumulated Context

### Decisions

**v6.0 (Phase 27) decisions:**

- [Phase 27]: [27-02 MEASURED, and it is the plan's headline] **`anvil_setStorageAt` does not create
  a block — it writes into the state OF THE CURRENT HEAD.** The first capture pinned at the head,
  read back the value the cheat had just written, and recorded `pinned_equals_block_b = false`,
  which is indistinguishable from CHAIN-02's defect. Driven with `cast` independently of the
  program: `head = 19; setStorageAt; evm_mine x3` leaves `--block 19` showing the WRITE and
  `--block 18` showing the old word. The pin was never broken — the same program reads block 0 and
  gets the bare `0x` marker, which it could only do if the block parameter were reaching the node.
  The construction now mines ONE block before the write, and `write_landed_above_b` is a recorded
  and asserted field so the two causes can never be confused again. **Binds anything else that
  constructs a historical divergence on this rig.**

- [Phase 27]: [27-02 FINDING] **A decoy a check compares against must be BUILT BY THE FUNCTION UNDER
  TEST.** The naming arm was written with the delimiters spelled out inside the check; the mutation
  that drops them from the producer MEASURED **201/201, exit 0, NOT CAUGHT**, because the
  hand-spelled decoy kept its own quotes and the two strings could no longer collide. The arm was
  asserting about its own literal. Routed through `refusal_naming_of` the same mutation fires at
  199/201. Same shape as 27-01's `setEnv k ""` finding one level in: an assertion passing because its
  subject is absent, inside the guard written against exactly that.

- [Phase 27]: [27-02 CORRECTED, a committed measurement that was false] **`measured_pre_pool_block`
  5 → 7.** Blocks 0–5 of a from-scratch rig have NO PoolManager code, so the call returns the bare
  `0x` marker; blocks 6–7 have code and no pool, returning an ALL-ZERO WORD; block 8 is the first
  readable. Those are two DIFFERENT diagnoses and the earlier draft merged them — the exact pair
  `decode_word_token` exists to keep apart. Heights shift between deploys (21-02: 9, 11, 10), so
  what is durable is the ORDER of the three regimes, not the numbers.

- [Phase 27]: [27-02 DECIDED] **A capture that constructs a divergence must record BOTH "the chain
  moved" and "the two reads came apart", because neither implies the other.** `unpinned_differs`
  false means the divergence was never constructed and the artifact is void;
  `pinned_and_unpinned_disagree` false means both reads followed the head, which is the defect
  itself. A capture where the chain moved and both reads followed it satisfies the first and fails
  the second.

- [Phase 27]: [27-02 DECIDED] **The capture is an EXECUTABLE, not only a shell script.**
  `Chain.Read`'s wiring half (`read_pool_field`, `read_raw_word_token`, `block_param`) is
  unreachable from `cabal test` by construction, and an unexercised surface is this package's
  advertised-and-dead shape — measured three times at 22-03, 22-04 and 22-07. Its cabal stanza is
  `+0 packages` in the build plan but NOT `+0 dependency lines`: the first build failed `GHC-87110`
  naming two packages the library already depends on, and the comment states the narrower true claim
  rather than copying the sibling stanza's.

- [Phase 27]: [27-02 FINDING] **A structural grep's tokens are not interchangeable, and which one is
  load-bearing is measurable.** `the_suite_never_reaches_a_chain` names three. `web3-ethereum` IS a
  test-suite dependency, so the JSON-RPC method module can be imported today and only this scan
  stops it — that firing input COMPILED and was caught. `web3-provider` is NOT, so that import does
  not build at all and its firing input had to be a comment, which works only because the scan
  covers the whole file deliberately. One guards a state reachable in a line of Haskell, the other
  one reachable in a line of `.cabal`.

- [Phase 27]: [27-02 DECIDED] **A positive control built from a COPY OF THE SUBJECT beats a
  three-line bait.** `latest_appears_nowhere_in_the_read_layer` greps a seeded copy of the read layer
  beside a clean copy of it. OBSERVED: when the token is seeded into the real file, the control's
  third arm fires FIRST and says so more precisely than the main scan — "the real file already
  carries the token and the main arm below is about to report the same thing less clearly."

- [Phase 27]: [27-02 STATED GAP] **`chain-read-conformance.json` has an override
  (`CHAIN_READ_CONFORMANCE`, probed) and is NOT in the sentinel sweep.** The sweep COULD reach it, so
  it is recorded in `unswept_artifacts` with its own reason and that list's haddock now states the
  reason per entry rather than one blanket claim that would be false for this member. Folding it in
  means an `absorbed_by_design` entry, with a count and a reason, for every (leaf, sentinel) pair no
  check objects to.

- [Phase 27]: [27-01 MEASURED] **CHAIN-06's "nine sites" is wrong three ways, and each was measured
  rather than reasoned about.** It is TEN by its own pattern (`offchain/spec/types.md` is the tenth,
  a pasted RPC transcript). It is ELEVEN counting `offchain/rig/verify-rig.sh` — fourteen `cast`
  calls against a live rig, reached through foundry's `--rpc-url local` ALIAS, so it named neither
  the variable nor the authority and **no pattern built from those two tokens could ever have found
  it**. And the rule was implemented ZERO times, not nine: the only occurrence of `ETH_RPC_URL`
  under `offchain/` was a COMMENT in `deploy-rig.sh`. **Correct the requirement text at phase close.**
- [Phase 27]: [27-01 DECIDED] **A census term set is anchored to what the census MEANS, not to the
  tokens that happened to find the current members.** MEASURED both ways: the plan's pattern ("names
  the variable or the authority") found 10 sites BEFORE the rewiring and only 8 AFTER, because five
  of the six Haskell consumers stop naming either token the moment they name `resolve_endpoint`. A
  census on that pattern would have reported five correctly-fixed files as missing.
  `endpoint_census_terms` therefore closes over the resolver, the shell resolver's path, and the two
  shapes of REACHING a chain — and that last pair is what found `verify-rig.sh`.
- [Phase 27]: [27-01 FINDING] **`"cast call"` is a prefix of `"cast calldata"`.** It was a census
  term because `offchain/rig/README.md`'s hand-run chain-independence grep names it; on its first run
  it matched `CheatSwap/Encoding.hs`, whose haddock says the calldata is built by shelling to `cast
  calldata` — purely local, no endpoint. The 26-03 shape (`"828040"` contains `"82804"`) in mirror.
  Dropped: an endpoint flag is the anchored form. **README's grep still carries the bug** and has
  simply never met a file that says `cast calldata`.
- [Phase 27]: [27-01 FINDING, base] **`System.Environment.setEnv k ""` routes an empty value to
  `unsetEnv`.** OBSERVED: `setEnv "PROBE_VAR" "" >> lookupEnv` returns `Nothing`. So a check that
  sets a variable empty and asserts a default comes back drives the UNSET path twice — and the first
  draft of `an_empty_eth_rpc_url_does_not_resolve_to_the_empty_string` MEASURED GREEN against a
  deliberately unguarded resolver. A shell reaches the state easily (`export VAR=` leaves it present
  and empty). **A rule that must be tested at a value the process cannot install in its own
  environment is factored into a PURE function of that value**, with the value's reachability
  observed in a child process rather than assumed.
- [Phase 27]: [27-01 DECIDED] **A duplication a check compares is a checked agreement.** `bash`
  cannot import a Haskell module, so the default authority is stated once per language and the two
  statements are asserted byte-equal — the move `Fee.Split` and `Store.Key` already make for the pip
  denominator. The alternative (inlining the parameter expansion in three shells) would have been
  four statements, three of them unchecked.
- [Phase 27]: [27-01 DECIDED] **Existence and ORDER are separate assertions over the same subject.**
  OBSERVED that neither alone suffices: moving the chainId assertion below the first `--broadcast`
  fires only the order arm; deleting it fires only the existence arm. That is 26-03's finding, where
  an ordering gate written only as line numbers was structurally voided by 26-04's refactor while
  staying green.
- [Phase 27]: [27-01 DECIDED] **Prose inside the census's blast radius is DECLARED, never argued
  away.** `offchain/spec/types.md` and `offchain/rig/README.md` are `Transcript` sites and
  `offchain/test/Main.hs` is a `Census` site whose rule is the inverse of every other kind's — it
  must NAME the resolver and name none of `chain_reaching_terms`, which makes README's hand-run
  chain-independence grep executable. Instance 26 of prose caught by a pattern on this branch was
  hit during this plan; the prose moved, as it did the other 25 times.

Older decisions are logged in PROJECT.md Key Decisions table. Recent decisions affecting v4.0:

**v6.0 (Phase 24) decisions:**

- [Phase 24]: [24-06 DECIDED, from MEASURED M14] **the schema refuses the empty version, and the
  refusal is a NAMED check.** `text not null` does not forbid `''`, so `Gams.Version`'s abstract
  newtype — the primary defence — protects only the writers that go through Haskell. Migration
  `003_version_columns_nonempty.sql` adds `check (length(gams_ver) > 0 and length(conopt_ver) > 0)`
  under the name `model_run_versions_nonempty`, and the name is load-bearing rather than stylistic:
  SQLSTATE `23514` says only that SOME check refused, and `model_run` is free to grow other checks.
  The recorded evidence asserts the server's own message CONTAINS that name. OBSERVED against
  Postgres 18.4 on both columns independently, with a positive control that lands.
- [Phase 24]: [24-06 DECIDED] **a refusal exhibit that does not also record an ACCEPTANCE is not
  evidence.** "The insert raised" is satisfied by a dead connection, a malformed key, a `doc` that
  is not JSON and a missing table. `empty_version_rejected` therefore carries `control_accepted` and
  `control_rows_after` — the identical row with non-empty versions, which must land exactly one row
  — and both the shell gate and the in-suite check evaluate the control BEFORE the rejections.
  `rows_after` per attempt is the SERVER'S own count, because "an exception was raised" and "nothing
  was written" are different claims.
- [Phase 24]: [24-06 DECIDED, MEASURED by the sentinel harness] **a field the writer hardcodes is
  DELETED, never asserted.** The first version of the observation carried a per-column `attempted`
  that was the literal `True`; the harness reported all six of its mutations ABSORBED. Asserting it
  would have compared a constant to itself, which is 24-04's measured defect (a suite green with the
  library renamed underneath it). The honest per-column form is the ENTRY, compared to
  `Store.Schema.versions_nonempty_columns` in both directions, so a missing attempt is a set
  mismatch rather than a shorter list.
- [Phase 24]: [24-06 DECIDED] **`pg_isready` over a container's unix socket is not a readiness
  gate.** The postgres entrypoint runs a temporary bootstrap server on that socket during `initdb`,
  and `pg_isready` reports a server answering `FATAL: database "..." does not exist` as accepting
  connections. THREE consecutive captures died on the subsequent shutdown. The gate is now
  `pg_isready -h 127.0.0.1`, because the bootstrap server has no TCP listener — a discriminator,
  not a longer sleep. Pre-existing since 23-04 and invisible because it failed in the safe
  direction.
- [Phase 24]: [24-01 DECIDED, from MEASURED M2] **the GAMS version's discriminator is the banner's
  JOB NAME, not the shape of the version token.** The three real banners — the production run
  (`volume_path.gms`), the no-argument help banner (`?`, **exit 0**, version present three times,
  no model run) and the flag (`--version`, exit 6) — differ in exactly one field, and every one of
  them carries a perfectly well-formed `54.1.0`. So the rule is one equality: the job name must
  equal the basename of the `.gms` actually invoked. It rejects both wrong-subject banners without
  a denylist and keeps rejecting the ones nobody has met. A shape-first rule would accept the help
  banner. OBSERVED: with the equality removed, that banner parses to
  `Right (GamsVersion ("54.1.0","37378ce0"))`.
- [Phase 24]: [24-01 DECIDED, from MEASURED M3] **CONOPT is recognised by the SPACED-LETTER form
  and by scanning every line.** Both decoys carry the token `CONOPT`; only the true line carries
  `C O N O P T`. Position is refused as evidence because the true line was measured at buffer index
  38 in the hermetic probe and 47 in the production run. OBSERVED twice: relaxing the marker to the
  bare token makes the parser reject the TRUE line (its letters are spaced, so it has no bare
  `CONOPT` token at all — an unplanned finding worth keeping), and making the marker
  spacing-insensitive makes it accept the GAMS-side link version as `ConoptVersion "54.1.0"`.
- [Phase 24]: [24-01 DECIDED] **`Unclassified` is a FAILURE and 0 is the only `Solved`, and
  `gams_code_domain` names the mod-256 IMAGES.** GAMS reports 400/401/402/909 and an exit status is
  a byte, so a collision argument for the timeout codes made against the unfolded numbers would be
  about codes no caller ever observes; the domain holds 141/144/145/146. The domain is asserted in
  BOTH directions — non-membership of 124/137 alone is satisfied by a domain that shrank to nothing.
- [Phase 24]: [24-01 FINDING, the prose trap caught by a guard rather than by a review] **a haddock
  comment in `Gams/Exit.hs` reddened the very scan the same commit installed.** The word spelled
  c-a-t-c-h appeared in a sentence explaining why the fall-through is not success, and the
  no-fallback pattern matched it, naming the file and the line. The prose moved; the pattern was not
  relaxed. This is the eleventh instance of prose-inside-a-grep on this branch and the first where
  the guard did the catching — which is the argument for widening a scan's scope rather than the
  argument against it.
- [Phase 24]: [24-01 DECIDED, extending the plan] **the no-fallback scan's file set is asserted
  against the DIRECTORY, in both directions, with reasoned exemptions.** `Gams/Config.hs` is EXEMPT
  WITH A WRITTEN REASON (`fromMaybe <default> <$> lookupEnv` IS the `Store.Config` resolver idiom
  and no version value exists on that path), not omitted. 23-03 measured what a hardcoded list does
  alone: `Store/Schema.hs` sat unlisted for two commits with nothing red. NOTE the boundary —
  `aeson_storage_path` still has no such cross-check; `Gams/Artifact.hs` must be added there and
  plan 24-04 owns it.
- [Phase 24]: [24-01 MEASURED, correcting two inherited numbers] **the cold `cabal test` baseline
  was 111/111 at wall 71.8 s**, not the 97 s recorded in this file and in `24-RESEARCH.md` nor the
  66 s in the execution prompt. Six PURE checks took it to 117/117 at 87.8 s: +16 s, because the
  sentinel harness re-runs `core_checks` once per (leaf × sentinel) pair and pays every added check
  roughly 3250 times. Tier-B stub checks spawn subprocesses INSIDE that multiplier.

**v6.0 (Phase 23) decisions:**

- [Phase 23]: [23-05 DECIDED, the plan's own explicit fork] **`PGSTORE_DSN` is a NAMED GAP in an asserted `unprobed_overrides` list, NOT a registered `OverrideProbe`.** `probe_override`'s third assertion is that pointing the variable at an unresolvable value makes the CONSUMER fail NAMING that value. `PGSTORE_DSN`'s consumer is libpq, reached only through the client module and the capture executable, and **neither is reachable from `cabal test` by construction** — that is DB-03, and the three-token grep that must return 0 is its structural form. Both ways of manufacturing a subject were rejected: importing the client breaks DB-03 on the way to enforcing DB-02, and a `validate_dsn` written only to be probed is worse *because it looks right* — its rejection would prove that a function written to reject rejects. That is a registered-but-vacuous probe, the exact defect the sweep exists to catch, installed to close the sweep's own list. `probe_override` was NOT weakened. The two halves that ARE measurable (verbatim resolution, differs-from-default) are asserted, plus disjointness of the two lists and a both-directions check that every variable `Store.Config` names appears in exactly one of them.
- [Phase 23]: [23-05 MEASURED, upgrades BYTE-05 from a bound to an ORACLE] **the bare write path's damage is PREDICTABLE from its two mechanisms.** libpq's C-string escaper truncates at the first NUL (23-04) and `byteain` then decodes the legacy escapes — `\\` to one backslash, `\NNN` to one octal byte (23-01). `bare_path_prediction` composes them over `cm_bytes` from `Store.Types`, and the expected side never touches the artifact. It reproduces **all five returning corpus members exactly, in length AND digest** (`nul` 1→0, `crlf` 4→4, `trailing-newline` 2→2, `octal-escape` 6→3 `aAb`, `double-backslash` 4→3 `a\b`). The sentinel harness had reported `bare_out_len` and `bare_out_sha256` as absorbed and the plan permitted pardoning them; modelling the mechanism was the better answer and is the difference between recording that bytes were lost and predicting exactly which.
- [Phase 23]: [23-05 MEASURED, corrects 23-04's carried-forward budget input] **the sentinel harness enumerates 134 leaves of `store-conformance.json`, not 121.** 23-04's 121 is `jq 'paths(scalars)'`, which OMITS JSON nulls; `scalar_json_paths` treats a null as a leaf and mutates it. `sentinel_pair_floor` RE-MEASURED 2457 → **3250** by raising the constant until the harness reported what it reached, never by arithmetic; 134 × 6 = 804 possible, 793 exercised, the 11 difference being identity skips, so `3250 − 2457 = 793` confirms the four older artifacts still contribute exactly 2457. All five `artifact_field_floors` re-measured in that run and the four older ones came back UNCHANGED (20 / 110 / 151 / 130), which is what says none of them shrank while the new one was added.
- [Phase 23]: [23-05 FINDING, a guard registered and green for three plans had never been seen to reject] **research guard #7 (`aeson_round_trip_mutations_are_re_measured`'s "the round trip became the identity" arm) had no firing observation anywhere in the phase** until it was compiled into the nineteen-guard ledger. OBSERVED by pinning a vector whose round trip genuinely is the identity — the research table's own named input. Carry forward: a guard can sit registered, green and cited for three plans without anyone having watched it reject, and only building the ledger surfaces it.
- [Phase 23]: [23-05 FINDING, the phase's ONE unobserved guard] **research guard #13 (`PGSTORE_DSN` override) has no observation and cannot get one offline.** It is named as a phase-level finding rather than omitted. The only evidence the variable is honoured end to end is 23-04's capture, which exports it and gets a `server_version` back — real evidence, and not a `cabal test` observation. If a later phase introduces a DSN consumer reachable offline, that is the moment to move the entry into `advertised_overrides` — and the moment to be suspicious of any consumer introduced *in order to* move it.
- [Phase 23]: [23-05 MEASURED, the assertion a COUNT cannot make] deleting one key from `law_verdicts` reddens `store_conformance_verdicts_are_all_pass` as a SET mismatch **while `sc_law_count` still reads 8**. That is the demonstration, not the argument, that a skipped law is structurally unrepresentable rather than merely detectable.
- [Phase 23]: [23-05 DECIDED] the checksum-drift MESSAGE **is** asserted — for the FILENAME it names, from `expected_migrations`, and never for the words "checksum mismatch", which do not appear on that path. The arm reproduces 23-04's real defect (a server `NOTICE` recorded in its place), so it is a guard with a demonstrated catch rather than a decoration.
- [Phase 23]: [23-05, the FIFTH and SIXTH instances of prose inside a grep's blast radius] a FAILURE MESSAGE naming the postgres store module took the DB-free grep from 0 to 1. The credential pattern and its bait are therefore BUILT from fragments rather than written contiguously, for the same reason `purge_control_literal` and `aeson_bait_source` are. **Rule, now with six instances: any token a check greps for must not appear contiguously in a file that check reads — including in prose and including in failure text.**

- [Phase 23]: [23-04 USER RULING, implemented AND validated by measurement] the keyed path **REQUIRES a json value** — `model_run.doc` is `not null jsonb` derived from the same parameter as `raw`, and the server computes the row before it resolves the conflict clause, so `on conflict do nothing` does not save a non-json artifact. `Store.Memory` is TIGHTENED to match (rather than the server loosened) because **TIER B MUST PREDICT TIER C**: a law suite that passes against the reference store and fails against Postgres defeats the three-tier design, which is the only reason `cabal test` may run with no database. `law_first_writer_wins`'s second payload became `{"a":2,"note":"SECOND-SOLVE-DISAGREED"}` — still different bytes, so its discriminating power is unchanged — and the old non-json bytes became the probe of the new eighth law. **MEASURED: all 8 laws pass against `Store.Postgres` unchanged.** BYTE-01's arbitrary-bytes requirement is served by `byte_corpus`, which deliberately has no `jsonb` column.
- [Phase 23]: [23-04 DECIDED] `Store.Json` — a total, pure RFC 8259 recogniser behind a UTF-8 gate — is the predicate the server-free tier rejects with. Hand-written because every module under `offchain/lib/Store/` is in `aeson_storage_path`, and because a RECOGNISER builds no value and therefore cannot re-render a number or reorder a key. Its agreement with `jsonb` is **MEASURED per input** in the capture's `json_agreement` block, never claimed in prose. Added to `aeson_storage_path` in the commit that created it, per the rule 23-03 wrote down and then broke.
- [Phase 23]: [23-04 MEASURED, FALSIFIES the plan's own guard table AND the research] **`corpus[nul]` is `SilentlyCorrupted`, not `ServerRejects`.** Driven through `postgresql-simple`'s bare-`ByteString` path it goes in at **1 byte and comes back at 0**, with NO error — because `ToField ByteString` is `Escape`, which hands the value to libpq's C-string escaper, and **a C string ends at its first NUL**, so the parameter reaching Postgres is empty and there is nothing left for the encoding check to reject. The research measured a different path (a text literal not going through parameter escaping). The tag is corrected, and this **STRENGTHENS BYTE-05**: a total truncation is a worse silent corruption than `octal-escape`'s 6→3 and had been filed under the loud behaviour that proves the least. Any citation of "the secondary `Binary` observation" must name `high-byte` and `invalid-utf8`, which do raise. Also: `crlf` and `trailing-newline` round-trip CORRECTLY through the broken path and must never be cited as evidence for the wart.
- [Phase 23]: [23-04 MEASURED, refutes this executor's own prediction] the predicted `Store.Json` / `jsonb` **numeric-overflow divergence DOES NOT EXIST** — `1e1000` and `1e100000` were both ACCEPTED by the server. The one real divergence is a `\u0000` escape inside a string (RFC-valid, refused by `jsonb`, because Postgres text cannot carry a NUL). Both refuted probes are KEPT under their own names: a probe deleted for agreeing is a probe that can never disagree later.
- [Phase 23]: [23-04 MEASURED, confirms 23-03's source-read EMPIRICALLY] on checksum drift through `runMigrations` the stderr line is `migration FAILED: 001_model_run.sql (dir: …)` — the **SCRIPT NAME**, exactly as 23-03 read out of `Migration.hs:181`, and not the words "checksum mismatch". `checksum_drift_stderr` is recorded for a human reader and **23-05 must not assert on its text**; the exit code (`1`, from the runner's own `exitFailure`) is the observation.
- [Phase 23]: [23-04 MEASURED, strengthens the plan] an exclusion observation needs its RELEASE observation. `second_migrator_try_lock false` / `applied 0` against an already-migrated database is satisfied by a migrator that could never apply anything, by a closed connection, and by a directory with nothing new in it. The probe directory therefore carries a THIRD migration and the lock is measured again after release: `after_release_try_lock true`, `after_release_applied 1`. Only that pair says the lock EXCLUDED work that would otherwise have happened.
- [Phase 23]: [23-04 FINDING, a guard PROBE can itself be vacuous] the docker-absent refusal probe did NOT fire on its first attempt: a `chmod 000` `docker` shim placed first on `PATH` is SKIPPED by bash's PATH search, the real binary was found, the capture ran to completion and the artifact CHANGED. It was caught only because the artifact digest was compared before and after rather than the exit code being read alone. The valid probe builds a 2750-entry symlink farm of `/usr/bin` with `docker` omitted and verifies `command -v docker` is empty BEFORE invoking the script. Guard then fired: exit 1, message naming `docker`, artifact byte-identical.
- [Phase 23]: [23-04 MEASURED, validates a design choice by accident] the capture's **non-default host port `55433` is not taste** — `docker ps` during this plan showed another project's `postgres:18-alpine` bound to `0.0.0.0:5432` on this very machine. On the default port the capture would have connected to a foreign database, migrated it, and reported success.
- [Phase 23]: [23-04 DECIDED, corrects a self-contradiction in the plan] the artifact FILE is written exactly ONCE, atomically, at the end; only the completeness FLAG starts `False`. The plan's "write `sc_complete` `False` FIRST" taken literally means the tool replaces the committed evidence with an empty skeleton before it has produced any — the precise failure the capture scripts' restore-on-failure shape exists to prevent, and forbidden by this plan's own standards.
- [Phase 23]: [23-04 MEASURED, 23-05's budget input] `store-conformance.json` has **121 LEAVES**, 70 of them the corpus block (7 members × 10 fields, the plan's own prescribed shape). At ~6 full `core_checks` re-runs per leaf the sentinel harness must be budgeted explicitly; consider ONE iterating check over the corpus array rather than per-field checks. The number is reported rather than trimmed — trimming a recorded field to make a harness cheaper is how fields stop being asserted.
- [Phase 23]: [23-03 MEASURED, the count every later v6.0 plan compares against] the suite is **98/98, FAIL count 0** — 23-02's 96 total plus EXACTLY the 2 checks 23-03 registered, with BOTH deliberate reds closed by the single file `offchain/lib/Store/Postgres.hs`. 23-02's anti-control C2 predicted this to the check. Counts taken from the BUILT TEST BINARY, not from `cabal test`.
- [Phase 23]: [23-03 MEASURED, a BUG in the research's AND the plan's own prescribed code] `execute` / `execute_` **THROW** on a statement that returns columns — `finishExecute` raises `QueryError "execute resulted in 1-column result"` on `PQ.TuplesOk` (`Internal.hs:408-428`). So `execute_ con "select pg_advisory_lock(872304)"`, the form BOTH the research's §Code Examples and 23-03's task 2 prescribe, compiles cleanly and throws at the FIRST acquisition. Both lock statements go through `query` and consume the row: `[Only ()]` for the void-returning blocking lock (`FromField ()` exists and requires exactly `voidOid`), `[Only Bool]` for try and unlock. **Never use `execute_` for a `select` run for its side effect.**
- [Phase 23]: [23-03 MEASURED, source-read, binds 23-05] on checksum drift through `runMigrations` the payload is `MigrationError name` — the **SCRIPT NAME** (`Migration.hs:181`) — NOT the string `"Checksum mismatch"`. That wording belongs to the separate `MigrationValidation` path (`:239`), which the runner does not take. A check asserting on the drift payload TEXT would be asserting on a filename. The observation that counts is `echo $?` == 1 either way.
- [Phase 23]: [23-03 MEASURED, source-read] `postgresql-migration` applies **EVERY entry** in the migration directory — `scriptsInDirectory dir = sort <$> listDirectory dir` (`Migration.hs:155-158`), no extension filter anywhere on the path. A README or an editor backup dropped into `offchain/migrations/` is read and handed to `execute_` as SQL. `migration_list_is_ordered_and_gapless` therefore asserts the directory's WHOLE contents against the manifest, in both directions, and both arms were OBSERVED firing (a rename names both violations in one message; a `[1,3]` version list fires the gapless arm alone).
- [Phase 23]: [23-03 FINDING, a stale measurement inherited as fact by four documents] the research, the plan, 23-01's summary and 23-02's summary all state `purge_file_floor` is **36 against exactly 36 scanned files, zero slack**. At execution time the scan was **41** — waves 1 and 2 added five `.hs` files — so the stated consequence ("the first `.sql` reddens the floor immediately") was already FALSE; only the extension census would have fired. Re-measured to **45** (36 hs + 7 sh + 2 sql) and the block now records the RULE for when to re-measure, not just the number. It was measured three times and wrong twice, once because it was taken before the commit's own new module existed.
- [Phase 23]: [23-03 OBSERVED, the anti-control that matters] **declaring an extension is NOT scanning it.** With `.sql` in `purge_known_extensions` but NOT in `purge_scanned_extensions`, a seeded `0x`-prefixed 64-hex literal in a tracked `.sql` file is INVISIBLE to the purge — the floor fires first (42 < 44), and lowering the floor as well makes `sc3_literal_purge` **PASS with the literal on disk**. Two edits, each looking reasonable alone. This is why `.sql` went into BOTH lists, and it is what pins the guard-#19 FAIL to the SCAN rather than to the declaration.
- [Phase 23]: [23-03 CARRIED FORWARD, a real incompatibility 23-04 must RULE on] `model_run.doc` is `NOT NULL jsonb` derived from `raw`, so every artifact on the keyed path must be valid JSON — and `law_first_writer_wins_on_the_identity_triple` (`Store/Laws.hs:298`) writes the non-JSON bytes `SECOND-SOLVE-DISAGREED` as its second put. Against `Store.Postgres` that statement raises `invalid input syntax for type json` **before the `on conflict` clause is reached** (Postgres computes the row before resolving the conflict); against `Store.Memory` the same law passes. NOT papered over by editing wave 2's fixture. 23-04 chooses: the disagreeing payload becomes a disagreeing JSON *document* (it is the SOLE kill site for the last-writer-wins mutant, so it must still differ in its bytes), or the keyed surface stops requiring JSON. Recording the `SqlError` as the law's verdict would record a schema decision as a store defect.
- [Phase 23]: [23-03 FINDING, the pattern's TENTH instance and now also its INVERSE] prose in the grep's blast radius struck again on the first attempt in a brand-new file: `Store/Postgres.hs`'s haddock SAYING the `…Simple.Binary` module does not exist was counted by the acceptance grep asserting that import is absent. And the INVERSE appeared for the first time: `Store/Schema.hs` was created in 23-03 task 1 and spent two commits **absent from `aeson_storage_path`** — a storage module BYTE-03's scan did not read. The usual defect is a guard's scope SHRINKING; this is the scope failing to GROW, it is quieter, **nothing reddens**, and it was caught only by the plan's own self-check. A glob would have caught it and would have lost the property the named list exists for.
- [Phase 23]: [23-02 MEASURED, the count every later v6.0 plan compares against] the suite is **94/96** — the 23-01 cold baseline of 91 plus EXACTLY 5 new checks, with 2 RED BY DESIGN. With a clean stub `offchain/lib/Store/Postgres.hs` on disk it is **96/96**, which is what 23-03 lands on. Counts were taken from the BUILT TEST BINARY, not from `cabal test`: `cabal test` buffers the runner's stdout and printed `91/91 checks passed` on one invocation and nothing on the next, so a step that reads `cabal test | tail -3` can silently record no count at all.
- [Phase 23]: [23-02 OBSERVED, all seven laws, with the correct store as the CONTROL column] every law in `Store.Laws` was seen returning `Left` against a named wrong store: a `byteain` blob write (`member octal-escape went in at 6 bytes and came back at 3 bytes` — the MEASURED PG 18.4 corruption reproduced), a phantom `get_blob`, a key dropping `key_scheme`, a key dropping `model`, last-writer-wins, and a no-op `put`. **HONEST NEGATIVES:** the `key_scheme`-dropping mutant moves EXACTLY TWO laws and leaves the other five untouched (23-01's finding, reproduced through the law set itself); `law_key_scheme_orphans_rather_than_matching` does NOT fire against a store that stores NOTHING, so it is evidence only alongside the round-trip and the two-scheme insert; and last-writer-wins has a SINGLE kill site, which Phase 25's determinism claim rests on.
- [Phase 23]: [23-02 FINDING, corrects the plan] the corpus BEHAVIOUR-TAG set does **not** discriminate deleting `octal-escape` — `double-backslash` carries the same `SilentlyCorrupted` tag, so all three classes survive and the only surviving instrument was `length == 7`, a count defeated by substitution. `expected_corpus_members` (the member NAME set, both directions, ordered ahead of the count) is what actually caught the deletion.
- [Phase 23]: [23-02 DECIDED, strengthens the plan] `aeson_storage_path` names **SIX** files — every module under `offchain/lib/Store/`, with NO exemptions — not the plan's four. `Store/Types.hs` was to be exempted, and measurement showed its haddock was the ONLY thing under `offchain/lib/Store/` matching the pattern at all, on two lines SAYING the import is absent. Exempting a storage module because its comments trip the guard is the scope-shrinking defect; the prose was reworded instead.
- [Phase 23]: [23-02 MEASURED, unsatisfiable gate] the plan's "the suite fails on exactly ONE check" **cannot hold**. `sentinel_falsification_harness` carries an explicit `expect (null baseline)` that refuses to certify against a failing suite, so ANY deliberate red costs TWO FAIL lines. The harness was NOT weakened and no baseline-exemption list was added. Related: a red baseline also EMPTIES the harness — the run drops from ~75s to ~8s because the reader set collapses to the single always-failing check. Do not read a fast harness run as a fast suite.
- [Phase 23]: [23-02 FINDING, the pattern is now nine-times-over and deserves a pre-commit check] **prose is inside the grep's blast radius**, three more times in one plan — `Store/Laws.hs` naming the aeson module path that its own scan looks for; `Store/Types.hs` likewise; and worst, `store_laws_run_against_the_memory_store`'s haddock spelling `Store.Postgres` and the require-a-database variable while explaining that they are absent, which is EXACTLY the acceptance grep. A first fix reintroduced the token inside the sentence warning about it, caught only by re-running the grep.
- [Phase 23]: [23-02 PROCEDURE, standing rule] restore a mutated file from a SAVED COPY, never from `git checkout -- <file>`, whenever that file also carries uncommitted work. `git checkout --` on `offchain/test/Main.hs` after a pattern mutation restored it to HEAD and deleted ~170 lines of uncommitted implementation; it was caught only because the before/after digest comparison did not match.

- [Phase 23]: [23-01 MEASURED, the cold baseline every later v6.0 plan compares against] `cabal test` = **91/91 checks passed**; `cabal build --enable-tests -j all` exit 0 with **0** `offchain/` warning lines; `find offchain/{lib,app,test} -name '*.hs' | wc -l` = **28** before, **32** after; `find offchain -name '*.sql' | wc -l` = **0**, so `sc3_literal_purge`'s extension census and its zero-slack `purge_file_floor` of 36 are still untouched. STATE.md's 91/91 and the CI header's 78/85 were NOT inherited — both were re-measured cold. **`cabal build -j all` WITHOUT `--enable-tests` is VACUOUS** (it exits 0 against a non-compiling test suite) and was never used as evidence.
- [Phase 23]: [23-01 MEASURED, confirms the research rather than contradicting it] `plan.json` set-diff puts the install plan at **152 → 158 units (+6)**. `postgresql-simple` **0.7.0.1** is +4 (`Only-0.1`, `postgresql-libpq-0.11.0.0`, `postgresql-libpq-configure-0.11`, itself); `postgresql-migration` **0.2.1.8** is +2 (itself, `cryptohash-md5-0.11.101.0`); **`crypton` 1.0.6 is +0 — it is in BOTH sets**, because `web3-crypto` already pins `crypton <1.1`. Zero `Downloading` lines. `cryptonite` units in the resolved plan: **0**.
- [Phase 23]: [23-01 OBSERVED, BYTE-02 is a compile error and it was seen firing] `probe :: DerivedDoc -> DerivedDoc -> Bool ; probe = (==)` fails with `[GHC-39999] No instance for 'Eq DerivedDoc'`, and an `escape_hatch :: DerivedDoc -> Artifact` written in a DIFFERENT module fails with `[GHC-01928] Illegal term-level use of the type constructor`. **The plan's stated recipe could not fail** — it asked for `deriving Eq` AND the probe together, which compiles. Measured as a PAIR instead: probe alone → exit 1, probe WITH the instance → exit 0. Without that anti-control, a compile error does not tell you WHICH missing thing caused it.
- [Phase 23]: [23-01 OBSERVED, binds 23-02's law set] `Store.Memory` keyed on the FULL `(model, key_scheme, key)` triple orphans correctly: a lookup under superseded scheme 2 returns `Nothing`, and the same `(model,key)` under scheme 2 INSERTS without disturbing scheme 1. The negative control — keying on `(model, key)` alone — **compiles**, returns the scheme-1 row for a scheme-2 lookup, and SILENTLY DROPS the second insert. **HONEST NEGATIVE: only the superseded-scheme lookup and the two-scheme insert discriminate. Round-trip, first-writer-wins, blob-verbatim and label arms are all UNCHANGED under the mutant** — a law suite without a cross-scheme lookup would pass against a store that has no `key_scheme` at all.
- [Phase 23]: [23-01 DECIDED, deviation from the research sketch] `DerivedDoc` wraps `Text` (the `doc::text` rendering), NOT `Data.Aeson.Value`. Identical type-level guarantee, and it keeps `Data.Aeson` off the storage path that BYTE-03's own grep polices from 23-02. The `doc` column is still `jsonb`; only the Haskell-side view changes.
- [Phase 23]: [23-01 FINDING, the eighth self-contradicting-criterion instance in this repo] Three of the plan's acceptance greps counted matches in HADDOCK, not code — `cryptonite` (the plan prescribed a comment containing the token it then forbade), `octal-escape`, `DerivedDoc(..)`, and the credential grep (2 hits, both on the word "password" in comments SAYING there is no password). The last is substantive: DB-02's planned `no_credential_is_present_in_a_tracked_file` check greps exactly those tokens with a positive control, so a comment asserting its own cleanliness would have reddened it. **Prose is inside the grep's blast radius.** Also unsatisfiable as written: `grep -c 'lookupEnv' Store/Config.hs == 2`, since the import line alone makes the floor 3.
- [Phase 23]: [23-01 FINDING, gsd-tools is not safe on this STATE.md] `gsd-tools state advance-plan` errors (`Cannot parse Current Plan or Total Plans in Phase`) and `state update-progress` rewrote the frontmatter to `milestone: v2.0`, 25 phases / 37 plans by scanning EVERY phase directory on disk — folding the v1.0–v5.0 tracks, which this file says are separate and never renumbered, into v6.0. Reverted; the v6.0 progress block is maintained BY HAND.
- [Phase 26]: [26-02 CONFIRMED, the 23-01 finding RECURS] `gsd-tools state advance-plan` errored identically (`Cannot parse Current Plan or Total Plans in Phase`) and `state update-progress` again rewrote the frontmatter to `milestone: v2.0`, `milestone_name: milestone`, a `status` line made of a stray sentence fragment, and 25 phases / 50 plans / 47 complete by scanning every phase directory on disk. Reverted by hand at 26-02's closeout and the v6.0 counters set by hand (15 -> 16 of 18). `state record-metric` and `roadmap update-plan-progress` are SAFE and were used. `requirements mark-complete` is SAFE and was used. **Do not run `state update-progress` or `state advance-plan` against this file.**
- [Phase 26]: [26-03 FINDING, the "safe" list is WRONG and this is the SEVENTH occurrence] `gsd-tools state record-metric` ALSO rewrites this frontmatter to `milestone: v2.0`, `milestone_name: milestone`, a `status` line made of a stray prose fragment, 25 phases / 50 plans / 48 complete, and it reverts `stopped_at` and `last_activity` to older values. 26-02's own note lists it as SAFE and the 26-03 execution brief repeated that. **BISECTED at 26-03 on a scratch copy, one command at a time, checking line 3 after each:** `state record-metric` -> `milestone: v2.0`; `roadmap update-plan-progress 26` -> `milestone: v6.0`; `requirements mark-complete FEE-01` -> `milestone: v6.0`. So the culprit is `record-metric` alone, and the other two are genuinely safe. The metrics row it appends is CORRECT and worth having -- it also writes the duration without the `min` suffix every other row carries -- so the rule is: run it, then restore the frontmatter by hand and fix the units. **Do not run `state update-progress`, `state advance-plan` or `state record-metric` against this file without restoring the frontmatter afterwards.**

- [18b-01 MEASURED, supersedes 18a's number]: N=128 batch gas is now **execGas 3,231,765 + intrinsic 21,000 + EIP-2028 calldata 23,000 = 3,275,765 TOTAL**, a **+28,313 (+0.87%)** move from 18a's 3,247,452. The encoder adds 2 mstores per element plus memory expansion for the 8256-byte buffer; calldata gas is unchanged (the INPUT did not change). Still 3.05x under MCAL-01's 10,000,000 ceiling and well inside the plan's 3,400,000 stop-and-investigate band.
- [18b-01 MEASURED, the honest negatives — record these rather than the kill count alone]: (a) the **element-base-shift mutant (`base = 32 + 64*i`) is BLIND at N=0** — `test__unit__emptyReturnIsExactlySixtyFourBytes` stayed GREEN under it, because with no elements there is nothing to misplace and the total is 64 bytes either way. Killable only at N >= 1. (b) The **stride mutant (`64 + 32*i`) is blind at N <= 1** — OBSERVED directly: `test__unit__oneAndTwoElementReturnsAreByteExact` reddened at its **N=2** assertion while its N=1 assertion passed, since i=0 makes `64 + stride*i` independent of the stride. (c) The **dropped-outer-offset-word mutant IS killable at N=0** (32 bytes vs 64) — it and the base-shift mutant are COMPLEMENTARY, which is why both are run. A corpus that is N=0-only, or N<=1-only, would silently miss real encoder bugs.
- [18b-01 MEASURED, binds any future all-invalid corpus]: the `(false, id)` leak mutant is **NOT killable by an all-invalid batch on a fresh registry** — `test__unit__allInvalidBatchReturnsAllFalseZero` stayed GREEN under it, because `id` never leaves 0 there, so `(false, id)` IS `(false, 0)`. The SEEDED mixed corpus is the SOLE kill site. An all-invalid corpus alone would have recorded a fake pass.
- [18b-01 DECIDED, equivalence-checked and NOT counted as a kill]: the pure allocation-REORDERING mutant is **unconstructible**, and for a stronger reason than the bump-allocator argument the plan anticipated: moving the buffer allocation inside the loop makes the trailing `@evm_return(out, ...)` fail to compile with `error: unresolved identifier 'out'` (OBSERVED). Any reordering that keeps the return reachable requires `out` in the outer scope before the loop, so the before-the-loop ordering is enforced by SCOPING, not merely by convention. The under-allocated-buffer mutant carries the allocation-hazard evidence instead. **Kill count is 6, not 7.**
- [18b-01 CORROBORATED, HARD REQUIREMENT for the Haskell peer]: solc's `abi.decode` **REJECTS a non-canonical success word outright** — under the `success = 2` mutant the entire 18a suite reddens with `EvmError: Revert`, not with wrong values. A lenient Haskell decoder would accept a truthy 2. The two consumers would then disagree about the same bytes, which is exactly why the canonical-bool guarantee is a CONSUMER-SIDE CONTRACT and not a test detail.
- [18a-01 MEASURED, gas number SUPERSEDED at 18b-01 — see above]: N=128 batch gas is **execGas 3,203,452 + intrinsic 21,000 + EIP-2028 calldata 23,000 = 3,247,452 TOTAL**, against MCAL-01's 10,000,000 ceiling (3.08x headroom). This is 1.10x the research's UNVERIFIED ~2.94M estimate — same order of magnitude, so the loop does no unintended work. Pinned by `test__unit__maxBatchGasUnderBudget`, whose success/count/slot assertions all precede the threshold check so a passing `assertLe` cannot certify an early revert.
- [18a-01 DISCHARGED, was ACTION REQUIRED]: the M5 counter-hoist mutant is now a **REAL KILL**, exactly as 17-01 predicted. Observed RED: `id contiguity: third valid order at C+2: 0 != 2381976974094761317277030730967468670979` — slot C+2 holds ZERO because the skipped middle tuple consumed the id and pushed valid_B to C+3. The `orderCount` assertion also reddens (8 != 7) but is NOT discriminating; a count-only corpus would not have pinned where the order landed.
- [18a-01 FINDING, binds every future mutation gate]: **forge reports only the FIRST failing assertion per test**, so assertion ORDER is mutation-evidence design. The plan's original ordering had `orderCount` mask the contiguity red under M5, which would have been recorded as a count-only kill. Place the DISCRIMINATING assertion first. Fixed at `eac83f7`.
- [18a-01 EMPIRICAL, supersedes SC-6's original wording]: deleting the validation branch **cannot** produce a batch revert — `pack_vol_order` is pure shl/&/| and `@evm_sstore` cannot revert here, so an unvalidated tuple is STORED WRONG and COUNTED. Observed: `assertTrue(ok, "MCAL-04: no batch-revert observed")` stayed GREEN under M-VAL while three value assertions reddened. This also CORROBORATES the MCAL-04 structural enumeration: M-VAL drove arbitrary unvalidated tuples through the entire post-validation path and produced no revert, so no step's totality was contradicted. SC-6 was corrected at `56c4721` before execution; the correction is now backed by measurement.
- [18a-01 DECIDED, HARD REQUIREMENT for the Haskell peer]: guard 1 requires the **CANONICAL array offset `0x40` at byte 36**. The ABI spec permits a non-minimal offset, so a bespoke encoder that legally pads the head is REJECTED with an empty revert. Deliberate — it closes the PHANTOM-ORDER hole: the module reads elements at a fixed `100 + 32*i`, which is sound ONLY because the offset is pinned.
- [18a-01 DECIDED]: `width` is read UNMASKED. It is the TOP input field, so any bit >= 128 inflates it past `0xffffff` and validation rejects it — dirty-high-bit rejection with zero new arithmetic. Masking to `& 0xFFFFFF` would map two distinct calldata words onto one stored order, a malleability seam for the Phase 19 differential.
- [18a-01 DECIDED]: MAX_BATCH (128) is checked FIRST, before the three calldata guards, because Plank's `*` and `+` are CHECKED — an adversarial `count` near 2^256 would panic 0x11 inside `32 * count` before the size comparison ran, muddying MCAL-02's mutation evidence with panic data instead of an empty revert.
- [18b-01 baselines]: `make compile-plank` 13 ok / 0 failed / 0 skipped (UNCHANGED — the return type adds no entrypoint); `make test` **120 pass / 4 pre-existing fails** (was 112 / 4; +8 = the new `VolOrderManagerReturnEncodingTest`). The 4 reds are the vol-type track's `src/types/pos_spec/` harness failures, unchanged and not ours.
- [18a-01 baselines, count SUPERSEDED at 18b-01]: `make compile-plank` 13 ok / 0 failed / 0 skipped (UNCHANGED — the batch adds no new entrypoint); `make test` **112 pass / 4 pre-existing fails** (was 99 / 4).
- [17-01 MEASURED, binds 18a/19]: `v3::storage::array_slot` uses Plank's CHECKED `+`, so `keccak(base) + id` PANICS (0x11) rather than wrapping. Addressable ids cap at `2^256-1 - keccak(SLOT_ORDERS_BASE)` (~6.5e74). VORD-05's "no revert for a nonexistent id" therefore holds for every REACHABLE id (counter-assigned, +1/tx), which is the property it exists to establish. NOT worked around: `array_slot` is another track's file and masking the id module-side is exactly the ring-mask corruption M1 forbids. Boundary pinned as a VALUE instead.
- [17-01 DECIDED, ACTION REQUIRED IN 18a]: the "counter store hoisted above validation" mutant (M5) is an EQUIVALENCE-CHECKED NON-KILL in the strict path — `validate_order_strict` reverts, and a revert rolls back the prior SSTORE, so the hoist is unobservable. It becomes NON-equivalent in 18a, where the batch SKIPS instead of reverting: a hoisted store would advance the id on a skipped tuple. **18a MUST re-run this mutant and expect a RED.**
- [17-01 DECIDED]: both entrypoint selectors pinned in `src/interfaces/pos_spec/VolOrderManagerInterface.plk` — `create_order(uint88,uint24,uint16)`=0x6501fe94 (dispatched) and `create_orders(uint256,uint256[])`=0x81357911 (DECLARED, falls through to `revert_empty()` until 18a). This is what breaks the 17<->18a circular dependency. `test__unit__batchSelectorNotYetDispatched` locks the current fall-through and must be updated when 18a dispatches it.
- [17-01 EVIDENCE]: the id-65536 test is the SOLE kill site for the ring-mask mutant — every other test stayed GREEN under it, because `& 0xFFFF` is a no-op at ids 1 and 2. Small-id tests alone were provably insufficient; this is measured, not argued.
- [17-01 baselines]: `make compile-plank` 13 ok / 0 failed / 0 skipped (was 12); `make test` 99 pass / 4 pre-existing fails (was 87 / 4), MODAL — see the nondeterminism blocker below. `PLANK_SKIP` stays EMPTY (MVER-04 corrected at af488a0: a module that compiles never enters the rescue queue).
- [16-01 DECIDED, binds 17/18a]: `validate_order` is a bool-returning CORE with `validate_order_strict` as a thin reverting wrapper. Phase 17 calls the wrapper, Phase 18a calls the core — MCAL-04's "same validation both paths" is true by construction, not by assertion. Do not collapse them.
- [16-01 DECIDED]: `TICK_SPACING = 20` pinned inside `build_vol_order` (one place). `vol_range_width_is_complete` ANDs `tickSpacing > 0`, so a zeroed field makes the composed validator IDENTICALLY FALSE — under which an all-reject validator passes a naive fuzz trivially. Mutant M5 proves this is observable. All order construction in 17/18a MUST go through `build_vol_order`.
- [16-01 MEASURED]: stored word is the FULL 152-bit `(width << 128) | (20 << 104) | (strike << 16) | skew`. NOTE this SUPERSEDES the earlier v4.0 roadmap-time assumption of a 128-bit `skew|strike|width` subset with tickSpacing deferred, and supersedes the "REDUCED width check (no tickSpacing operand)" note below — the full `vol_range_width_is_complete` is reused verbatim, tickSpacing included.
- [16-01 MEASURED]: accept sets, verified against the real predicates — skew [1, 65534] (1 and 65534 ACCEPTED, do NOT revert), width [1, 0xffffff], strike [1, 2^88-1]. The requirement's earlier "both endpoints revert" wording was wrong.
- [16-01 baselines]: `make compile-plank` 12 ok / 0 failed / 0 skipped (was 11); `make test` 87 pass / 4 pre-existing pos_spec fails (was 74 / 4).
- [16-01 pattern]: when a roadmap-named mutation site lives in another track's file, apply the identical semantic flip at OUR call site by inlining the flipped predicate, and record the substitution rationale in-file. Used for M3 (skew comparison, home is SpreadTickAssimetry.plk:12).
- [v4.0 roadmap]: 4 phases from the research SUMMARY skeleton; VORD-04 mapped to Phase 17 ALONE (Phase 16 delivers the pack/unpack layout its store consumes, but the requirement is mapped once).
- [v4.0 constraint]: runtime `while` only — `inline while` (comptime unroll) is parsed but compiler-rejected in v0.1.1; the batch loop is a plain bounded `while i < count`, not unrolled, not recursive.
- [v4.0 constraint]: best-effort containment is a pure-validation pre-check (branch-only, no self-call), NOT a self-`@evm_call` boundary — `create_order` has no revert-prone dependency call.
- [v4.0 constraint]: `array_slot(base,id) = keccak256(base)+id` reused verbatim from `v3::storage`, WITHOUT the RealizedVolatility ring's 16-bit wraparound mask (load-bearing for a ring, corruption-causing for a monotonic-id registry). Zero arithmetic in the module.
- [v4.0 constraint]: two peer-dependent placeholders (`MAX_BATCH` value; typed `(bool,uint256)[]` return shape) — NAMED placeholders with test structure written against them; never guessed, never blockers. Peer = rpc_api track `mv15a18k` (PR #9).
- [v4.0 constraint — **SUPERSEDED at 16-01, do not use**]: ~~stored word is the 128-bit create_order-native subset (`skew|strike|width` at offsets 0/16/104, bits 128–151 zeroed, `tickSpacing` deferred with pricing); width validated by the REDUCED check `width in (0,0xffffff]` (no `tickSpacing` operand).~~ Phase 16 measured the real layout: the FULL 152-bit word with `tickSpacing = 20` live in bits 104..127, and the FULL `vol_range_width_is_complete` (tickSpacing conjuncts included) reused verbatim. See the 16-01 MEASURED entries above.
- [carried, v3.0]: `make compile-plank` passing is NOT evidence — Plank does not type-check code unreachable from `run{}`. Proof = CALLING the module through FFI-deployed bytecode.
- [carried, v3.0]: `deployPlank` recompiles the `.plk` fresh on every test run via FFI — a mutation battery does NOT need `make compile-plank` between mutants; the mutant reaches the deployed bytecode as long as tests use `deployPlank` (re-check if any test ever deploys from a prebuilt artifact).
- [carried, v3.0]: observed-RED discipline — mutant applied → cache/fuzz cleared → verbatim RED recorded → restored sha256-identical → green; equivalence-masked mutants documented, never counted. Keep a NON-FUZZ unit anchor alongside each fuzz (cache-independent by construction). Reference mock must NEVER echo Plank's own output (vacuous differential).
- [carried, v3.0]: one shared decoder, not a fourth copy — `test/.../TimepointDecoder.sol` precedent; v4.0 promotes a single `VolOrderDecoder` and reuses it.
- [Phase 19]: [19-01 MEASURED] The module and the independent mock AGREE at tol 0 across interleaved (create_order | create_orders) sequences — orderCount, every stored word, and return bytes — over a seeded 8-step anchor ending at id 12 and a 256-run cold-cache fuzz. Step 3 (strict path resuming on a BATCH-advanced counter) is the property 18a/18b structurally could not test; VolOrderManagerMod satisfies it. No disagreement observed.
- [Phase 19]: [19-01 FINDING, binds every seeded differential] vm.store seeding moves the COUNTER, not the orders: ids in [1, seedBase] are legitimately EMPTY on both sides. The plan's after-every-write helper asserted 'pw != 0' and 'tickSpacing == 20' over all of [1, pc] and would have failed on every seeded test. Agreement is asserted over the full range; live-order SHAPE only for id > seedBase, with assertEq(pw, 0) below it (which also catches phantom-order seeding bugs).
- [Phase 19]: [19-01 BLOCKING, affects any test-side NatSpec] solc parses a leading at-sign + word in NatSpec as a doc tag: the field-at-bit layout shorthand triggers 'Error (6546): Documentation tag @128 not valid for contracts' and the file will not compile. Use prose in NatSpec; the shorthand survives in string literals, which is where failure messages need it.
- [Phase 19]: [19-02 CONFIRMED, the milestone's strongest encoder evidence] cast abi-encode (alloy) INDEPENDENTLY confirms 18b's pinned return layout from a THIRD encoder outside this repo: offset 0x20 at byte 0, length in ELEMENTS, static tuples at stride 0x40, total exactly 64+64N, and the N=0 case at exactly 64 bytes. Two independent encoders (solc at 18b, alloy here) now agree with the hand-rolled Plank encoder.
- [Phase 19]: [19-02 SCOPE, must NOT be blurred in the exit record] alloy proves the return bytes are STANDARD-ABI CONFORMANT. It does NOT exercise the Haskell consumer's decoder. The cross-language gap with peer mv15a18k remains OPEN and is kept visible in four places: the fixture's _scope_limit and _peer_status fields, 5 NOT-PEER-VERIFIED placeholders, and the dedicated test__unit__peerHaskellBytesAreStillAnOpenGap.
- [Phase 19]: [19-02 MEASURED, honest negative] test__unit__externalEncoderConfirmsTheEmptyEncodingIsSixtyFourBytes is NOT an anti-inaction gate — it stayed GREEN under a 5-to-4 fixture case-count drop because it reads expected[0] only. The count gate lives solely in the differential and the peer-gap tests. A refactor keeping only the N=0 test would silently lose falsifiability.
- [Phase 19]: [19-02 FINDING, binds remaining Phase 19 plans] the acceptance criterion 'git diff --stat src/ produces NO output' is UNSATISFIABLE at execution time — the pre-existing uncommitted src/lib/exposure/VegaIssuanceLib.plk draft (which CONTEXT itself defers) always shows. Fifth instance of the self-contradicting-criterion pattern. Scope the criterion to src/**/pos_spec instead; the real property (pos_spec byte-untouched, module sha256 be196dcb...cc9b8787) was verified directly.
- [Phase 19]: M8's N=0 blindness belongs to the ELEMENT-BASE SHIFT, not the head-drop — established by measuring BOTH variants
- [Phase 19]: M9 is also N=0-blind and all-invalid-blind; its kill needs an N>=1 corpus containing a VALID tuple
- [Phase 19]: The three calldata guards have a SINGLE point of failure in VolOrderManagerBatchGuardTest; wave 1 structurally cannot cover them
- [Phase 19]: [19-05 MEASURED, replaces the stale 17-01 record] `make test` = 102 passed / 18 failed / 120 total (44 suites); `make compile-plank` = 11 ok / 2 failed. Every red ATTRIBUTED: 14 exposure setUp() reverts (the uncommitted src/lib/exposure/VegaIssuanceLib.plk draft, `unresolved identifier 'VolOrder'`, propagating through deployPlank/FFI), 4 vol-type track under test/types/pos_spec/, **0 under test/pos_spec/**, 0 TickVolatility. The 13->11 entrypoint drop and 4->18 fail rise vs 18b are the exposure draft landing in between, NOT a Phase 19 regression: Phase 19 moved the pass count 95->102 and added zero failures.
- [Phase 19]: [19-05 FINDING, will fire on every future run] the acceptance criterion `grep 'FAIL' <output> | grep -c 'pos_spec'` == 0 is a FALSE POSITIVE — it matches the `--dep pos_spec=src/types/pos_spec` flag echoed inside `[FAIL: vm.ffi: ffi command [...]]` lines from the EXPOSURE suites, not any failing test. It measured 28 while the real count of reds under test/pos_spec/ was ZERO. Scope such gates to `test/pos_spec/`, and note that test/types/pos_spec/ is the vol-type TYPE track — a different owner.
- [Phase 19]: [19-05 VERIFIED, the real MVER-04 gate] the BATCH dispatch is CALLED green through FFI-deployed bytecode, not inferred from compile-green: batchSelectorIsNowDispatched (selector 0x81357911 reaches a dispatch branch rather than revert_empty), mixedBatchFootprintAndContiguity (the branch does real work — state effects at raw vm.load addresses from a seeded counter), mixedBatchReturnIsByteExact (the return half). All reach the module via deployPlank -> plank build over FFI AT TEST TIME.
- [Phase 19]: [19-05 CORRECTED, fourth stale-criterion fix in this milestone] roadmap SC-4, the Phase 19 Goal line and the one-line entry all asserted a `PLANK_SKIP` exit that does not exist. PLANK_SKIP is the rescue queue for entrypoints that do NOT compile; a module dispatching a subset of its declared selectors compiles fine, so VolOrderManagerMod never met the entry condition. Queue verified byte-identically empty. Like the previous three, resolved by fixing the DOCUMENT, never the code.
- [Phase 20]: [20-01 MEASURED] Upstream gate OPEN — PR #15 (feat/plank->develop) MERGED; origin/develop pinned at 9f5ccba92ddf89d80efe81bae1dcd1d0a1c10e2d in offchain/rig/import-ref.txt. This SUPERSEDES research §1's CLOSED measurement (origin/develop = 1c41935, PR #15 OPEN at 14:20 UTC). The gate is a re-runnable command whose sharpest discriminator is a grep for the V2 selector 0x98d950ec, not path existence — a path check cannot tell a merged V2 interface from the stale v1 file.
- [Phase 20]: [20-01 MEASURED, binds 20-02's delta] Cold PRE-IMPORT baselines on feat/rpc-api: forge test --via-ir --fuzz-seed 4880 = 139 passed / 5 failed / 144 total (47 suites); make compile-plank = 14 ok / 0 failed / 0 skipped. 19-05's 102/18/120 + 11ok/2fail were NOT carried forward — the gap is the exposure draft: src/lib/exposure/VegaIssuanceLib.plk is now TRACKED and COMPILES here, so the 14 VegaAccount*/VegaIssuance* setUp() reverts and 2 compile failures are gone. 4 of the 5 reds are the known vol-type track failures; the 5th (VolOrderManagerFuzzTest test__fuzz__logCreateOrder) is NEW to this branch record and is pre-import, so 20-02 must not mistake it for import damage. 0 reds under test/pos_spec/.
- [Phase 20]: [20-01 VERIFIED] forge build exits 0 on the PRE-import tree after npm ci --ignore-scripts (172 pkgs) + the develop-gate.yml submodule sequence with the submodule.lib/panoptic-helper.update=none recursion guard (guard OBSERVED firing: 'Skipping submodule'). Any post-import build failure is therefore unambiguously attributable to the import. No tracked file moved: git status --porcelain on src/ test/ Makefile foundry.toml remappings.txt is EMPTY.
- [Phase Phase 20]: [20-02 VERIFIED] The import LANDED byte-identical: 36 paths checked out from origin/develop @ 9f5ccba, git diff against the ref EMPTY, none re-typed. src/lib/TickUtils.plk removed as superseded (R054 -> src/types/pricing/TickUtils.plk; its only 3 importers were all in the list and switch to types::pricing::TickUtils on the ref). The V2 discriminators are LIVE not merely present: SELECTOR_CREATE_ORDER = 0x98d950ec is the sole live const and 0x6501fe94 survives only as a RETIRED-NEVER-LIVE comment.
- [Phase Phase 20]: [20-02 PROVEN] The Plank closure is COMPLETE, established by compilation before anvil was ever started: all four deploy module roots build with the exact plankOpts() flag set (7 deps, verified against the IMPORTED PlankDeployBase.s.sol, not just research) and emit pure hex bytecode. VolOrderManagerMod's bytecode contains 6398d950ec -- the V2 selector is in the compiled DISPATCH TABLE, strictly stronger than a constant in a source file. ZERO closure gaps: no path was added, the 36-path list is unchanged from task 1. A 20-03 anvil failure therefore cannot be a closure gap.
- [Phase Phase 20]: [20-02 MEASURED, binds the Solidity-testing session] Post-import delta, ATTRIBUTED not repaired: forge test --via-ir --fuzz-seed 4880 = 139/5/144 -> 85 passed / 27 failed / 112 total; make compile-plank = 14ok/0 -> 13 ok / 3 failed / 16 entrypoints. forge build STILL exit 0, confirming solc never sees .plk, so all 27 reds are runtime/FFI and forge script (20-03) is unaffected. The total FELL 32 because six suites now fail in setUp(), which forge reports as ONE failure while the rest never run. Four named causes: C1 V2 arity create_order(uint88,uint24,uint16,uint96)/0x98d950ec with the v1 3-arg RETIRED (20 tests); C2 two harnesses importing the removed lib::TickUtils; C3 per-test --dep sets lacking types=src/types; C4 harness call sites at v1 arity. By transition: 1 carried pre-existing, 2 transformed, 24 genuinely new.
- [Phase Phase 20]: [20-02 FINDING] C3 is a DEPENDENCY-ROOT problem, not a content problem, and the proof is a divergence: VolRangeWidthHelper.plk compiles OK under make compile-plank (full dep set) while the SAME file fails under forge test's FFI (narrower per-test set). Re-running the failing command with --dep types=src/types added emits bytecode and exits 0 (MEASURED, no file edited). So C2/C3 are mechanical fixes for the Solidity-testing session, not a migration. Separately, test__unit__everyInterfaceSignatureStringIsPinned is a WORKING pin, not a bug -- it reddened because it DETECTED the source-of-truth change, exactly its job.
- [Phase Phase 20]: [20-02 PATTERN, falsify-before-trust] The SC-1 verifier was driven to FAIL on purpose before being reported green: a flipped pin digest and a deleted pin row each exit 1 with a named message, and both restorations were verified byte-identical. Faults were injected into IMPORT-PIN.md (this workstream's own file), never a plank-owned one. This answers the repo's four recorded instances of criteria that passed vacuously. Also carried forward for 20-04: IMarketStateSocket.plk was imported for set-completeness and IS the broken stub (seven const NAME = lines with no values, no terminators) -- the pin parser must skip valueless consts DELIBERATELY, with the skip asserted in a test.
- [Phase 20]: [20-03 RESOLVED, closes research §12.1 and REFUTES its prediction] Foundry records DeployDynamicFeeHook's raw .call to the CREATE2 proxy as a TOP-LEVEL transactionType CREATE2 attributed to the hook (contractAddress = the mined hook, contractName null), NOT as a CALL to 0x4e59b448 with the hook in additionalContracts[] -- additionalContracts is [] on all six transactions, in both runs. The plan's PRIMARY extractor branch never fires; the FALLBACK is the real path. contractName is null for the same reason it is null on plankDeployFFI modules (Plank initcode solc never saw), so the Plank hook is keyed on transactionType while PriceSetterHook (new X{salt:...}) carries a contractName and is keyed by name. The hook address also appears a second time as a CALL (initializeHook), so keying on CREATE2 is correct by construction, not by ordering luck.
- [Phase 20]: [20-03 MEASURED, SC-5] Two from-scratch deploy-rig.sh runs produce a byte-identical manifest: jq -S 'del(.generatedAt)' diff EMPTY, both normalised files sha256 197acd740685fb0860ec1f8227d95afc541985fe6d081b3fade6712f5888f354, with generatedAt DIFFERING (18:46:13Z vs 18:49:15Z) so run 2 provably regenerated the file. Two determinism results that were NOT guaranteed: (a) BOTH CREATE2-mined addresses reproduce, which for the Plank DynamicFeeHook means plank build emitted byte-identical initcode -- stronger than 20-02's 'compiles and emits hex'; (b) the seeded packed timepoint is identical across runs (1766847064...619776), confirming it derives from the fixed INIT_TS literal and not the wall clock. A date +%s INIT_TS would still have PASSED SC-5 (the seed is not a manifest field) while silently making the rig's STATE irreproducible.
- [Phase 20]: [20-03 VERIFIED, SC-2 falsified] verify-rig.sh exits 0 with '7 contracts live, RealizedVolatilityMod seeded' and contains ZERO address literals (every target read from the manifest via jq -r). All six injected faults exit 1 with named messages, run against COPIES via a RIG_MANIFEST override with the real manifest's sha256 confirmed unchanged after. TWO faults are load-bearing beyond box-ticking: pointing RealizedVolatilityMod at the LIVE 17151-byte PoolManager passes probe 1 and is caught ONLY by probe 3 (so probe 3 does not ride on the bytecode check), and swapping contracts.PoolManager for PriceSetterPoolManager proves probe 5 discriminates between two REAL contracts, not merely live-vs-empty. A live-vs-empty-only falsification would have left both unproven.
- [Phase 20]: [20-03 FINDING, one research-table label is stale] Research §3.2 lists DeployDynamicFeeMod printing 'owner (TOFU)  : <address>'. The IMPORTED file prints 'owner (TOFU)  : the deployer, captured in-broadcast' -- a sentence, not an address -- so there is no console address to cross-check and none is attempted. TOFU ownership is instead PROVEN on chain by verify-rig.sh probe 4 (owner() == manifest accounts.deployer), which is strictly stronger than matching a printed string. Every other console label matched the imported source exactly. Separately: poolId is the ONLY console-primary field with no independent source (it is not an address in the broadcast record); currency0/currency1 were upgraded to a SET cross-check against the two MinimalToken CREATEs.
- [Phase 20]: [20-04 MEASURED] Every pin is GENERATED, never typed: 30 selectors + 5 topic0s computed by cast sig/cast keccak from signature strings parsed out of the imported .plk files, each then ASSERTED equal to that file's own declared const. All 35 agreed -- zero disagreements, so no interface constant is wrong and the parser truncated nothing. generate-pins.sh contains ZERO hex literals; rig-pins.json names the signature and the source path for every pin. The truncation hazard was MEASURED not argued: a naive single-line parse of the wrapped TimepointWritten signature yields 0xc0055983... , a valid-looking WRONG 32-byte hash. Only the in-file cross-check separates it from the correct 0x44d3c76a... value.
- [Phase 20]: [20-04 FINDING, corrects research 5.3] The // signature:: convention is NOT used by all six interface files. DynamicFeeInterface.plk uses a THIRD shape -- bare // name(args) comments with no marker -- for all five of its selectors. A marker-only parser would have emitted 25 selectors instead of 30 and EXITED 0, silently hand-picking a subset. Fixed by anchoring the parser on the const DECLARATIONS and walking backward through the contiguous comment block (marker form takes precedence, bare form is the fallback); a const with a hex value and no derivable signature is a loud abort, so a fourth shape appearing later fails rather than shrinking the output.
- [Phase 20]: [20-04 PROVEN] Normaliser idempotency is established by CROSS-FILE AGREEMENT, not by assertion. TimepointWritten, WindowChanged, FeeConfigurationChanged and getAverageVolatility are each declared in two files in two DIFFERENT comment shapes -- decorated (indexed + parameter names, one of them wrapped across two lines) and already-canonical single-line. Both paths through the parser produced identical signature strings and identical computed values, and the generator ABORTS if any duplicate disagrees.
- [Phase 20]: [20-04 DECIDED, resolves a self-contradicting criterion -- the SIXTH in this repo] The plan required that deleting contracts.VolOrderManagerMod make the decode FAIL, while its own schema locks contracts as an OPEN map so a new deployment needs no Haskell change. A smaller map is still a valid map, so aeson structurally cannot fail. Resolved by KEEPING the map open (20-03's contract preserved, extra contracts accepted) and adding a required_contracts completeness check in load_rig_from that runs after decoding and names both the missing and the present contracts. The failure is raised by the completeness check, NOT by aeson -- do not blur this.
- [Phase 20]: [20-04 VERIFIED, closes a 20-05 question early] 20-03's rig-manifest.json already existed at 20-04 execution time and Rig.Manifest decoded the REAL file, not merely the fixture. It matches the wave-3 schema B contract with ZERO deviation -- every key, every nesting level, all hex lowercase, chainId/tickSpacing/initTs/initTick as JSON numbers. There is nothing for 20-05 task 1 to reconcile on the manifest shape. Also: the v1 E1 topic0 did NOT have to be omitted -- it is present VERBATIM and complete in the imported notes/DATA_CONTRACT.md:16, so it is parsed from there rather than expanded from memory, while the truncated .plk form is rejected by an explicit ellipsis guard.
- [Phase 20]: [20-05 MEASURED, the purge fixed a LIVE bug] Sample.hs's price_setter_hook literal 0x78f77B58... has ZERO bytecode on the deployed rig (cast code returns 0x) while the manifest's PriceSetterHook 0x683ee59f... has 2183 bytes. The driver's entire price-write path was aimed at an address with no contract at it. The other two literals were still correct by nonce accident (VolOrderManagerMod landed at the same address), which is the point: a literal is right only by accident and cannot announce when it stops being right. Six literals were purged, not the research inventory's four -- check-upstream.sh carried 0x98d950ec and 0x6501fe94 and is IN the decided *.hs/*.sh scope; both are now read from rig-pins.json with jq.
- [Phase 20]: [20-05 FINDING, the SEVENTH self-contradicting criterion] The plan's own prescribed Decode.hs comment ('The RETIRED v1 value 0xa8892769 lives in rig-pins.json') contains an 8-hex literal that its OWN purge criterion matches -- written verbatim, task 1 could never pass. Resolved by pointing the comment at the retired block without the hex. Separately, two acceptance criteria measure TEXT where they mean STRUCTURE (grep -c on 'account|order_manager|price_setter_hook' in Sample.hs and on 'Rig.Manifest' in the decode chain counted explanatory COMMENTS, not code); both were satisfied by rewording, at the cost of moving the removed-binding routing table into the summary.
- [Phase 20]: [20-05 DECIDED, a working tool would have broken silently] generate-pins.sh parsed retired.topic_order_created_stale out of offchain/lib/VolOrder/Decode.hs -- the very constant this plan deletes -- so the generator would have aborted with 'matched 0 values'. Re-pointed at src/modules/VolOrderManagerMod.plk, the superseded duplicate module carrying 'const TOPIC_ORDER_CREATED = 0xa8892769' verbatim: the file the Decode.hs constant was ORIGINALLY transcribed from and the origin of the rot (research 2.2). Better provenance, still never typed, another track's file READ only. Re-run produces rig-pins.json byte-identical. CAVEAT for Phase 21: the generator now depends on that superseded file existing; plank deleting it is a loud failure needing a new recorded home, not a silent drop.
- [Phase 20]: [20-05 VERIFIED, SC-4 is falsifiable and was OBSERVED red] cabal test = 44/44 (35 per-pin + 9 named). Every pin is recomputed from the signature PARSED OUT OF the .plk file its own source field names, by a SECOND independent parser anchored differently from generate-pins.sh's (comment-block forward scan vs const-declaration backward walk). A one-character pin corruption (0x98d950ec -> 0x98d950ed) reddens exactly sc4_pin_selector_create_order and sc4_cast_agreement at 42/44 exit 1, with the recomputed value CORRECT and the pin wrong, both Haskell keccak256 and cast saying so independently; git checkout restores 44/44. The suite also caught a defect in ITSELF first: cast's trailing newline made two identical-looking hex strings compare unequal.
- [Phase 20]: [20-05 FINDING, the clean-machine trap the plan's template would have shipped] The README's submodule step needs 'git -c submodule.lib/panoptic-helper.update=none'. The plain recursive command exits 0 in this checkout ONLY because the skip is recorded in lib/panoptic-v2-core/.git/config, a machine-local artifact; upstream's committed .gitmodules points lib/panoptic-helper at an unreachable repo and this repo has no overriding stanza. A clean machine following the plain form fails at step 2. Separately documented: cabal run completes and reports a receipt but the order REVERTS -- Encoding.hs still builds the retired 3-arg create_order against a V2 module dispatching 0x98d950ec (20-02's cause C1, pre-existing, Phase 21's re-pin), recorded in the README so a reader does not read it as a rig failure.
- [Phase 21]: [21-02 MEASURED, stronger than planned] All THREE golden-comparable cases match the v4.0 alloy fixture BYTE-FOR-BYTE, not just N0_empty. The plan expected N1_success/N2_success_then_fail to differ in the order-id words because the golden was taken against a fresh registry. They do not, and structurally cannot from this script: create_orders RETURNS its array, so the capture is four eth_calls, and an eth_call does not mutate state -- every case executes against orderCount = 0, exactly the golden's condition. The differs_only_in_order_ids comparator was built and ships (it becomes load-bearing against a rig that has taken real transactions) but is recorded false on all three. COROLLARY for 21-05: the captured order ids are HYPOTHETICAL, ids the calls WOULD have assigned; an assertion hardcoding id == 1 is really asserting the rig is fresh.
- [Phase 21]: [21-02 FINDING, binds 21-05] generatedAt is NOT a regeneration witness for capture-batch-return.sh. The Phase-20 idempotence recipe (two runs, generatedAt must DIFFER) was designed around deploy-rig.sh, which takes tens of seconds. The capture takes 294 ms against a 1-second timestamp resolution, so two back-to-back runs SHARE a generatedAt -- MEASURED, both 18:30:37Z -- and the check would have passed on a stale artifact. Regeneration was re-proven by deleting the artifact before each run and gating the second on the wall-clock second rolling over (bounded until-loop, no fixed sleep): runs A/B at 18:31:02Z and 18:31:03Z, normalised diff EMPTY, same sha256 786c9506...824c0cd7 as the first pair. Five runs, one normalised sha256. Use blockNumber/manager as the discriminating provenance fields; generatedAt is a label. Caveat written into offchain/rig/README.md.
- [Phase 21]: [21-02 CONFIRMED, hazard F1 -- REPORTED to the plank track, never edited] src/modules/pos_spec/VolOrderManagerMod.plk lines 177-188 carry a V1 comment block ('width@104..127 | bits >=128 MUST BE ZERO', 'width IS DELIBERATELY UNMASKED. It is the TOP field') that its OWN file contradicts at lines 221-235, where the executing V2 code masks width to 0xFFFFFF at 104 and reads targetVega UNMASKED from bit 128. The stale block is dangerous because it is plausible and co-located: a word built from it carries targetVega = 0, the tuple is rejected, and the batch SKIPS rather than reverting, so a capture would degenerate into a legitimate-looking all-(false,0) artifact proving nothing. The warning is recorded in offchain/rig/capture-batch-return.sh immediately above input_word(), naming the line range and the failure mode.
- [Phase 21]: [21-02 SCOPE, binds 21-03] The capture emitted NO E1 VolOrderCreated v2 log and could not: these are eth_calls, which produce no logs. The v2 E1 log remains UNOBSERVED and 21-03's decode shape is still derived from emitter source alone. Closing that gap needs a real eth_sendTransaction against create_orders -- cheap now that the rig is standing and the V2 input word (skew@0..15 | strike@16..103 | width@104..127 | targetVega@128..223) is proven live -- but it is 21-03's work.
- [Phase 21]: [21-02 DECIDED, RPIN-05 deliberately left PENDING] RPIN-05 is claimed by BOTH 21-02 and 21-05, and its text is 'decode_create_orders_result is verified byte-unchanged against the V2 module's (bool,uint256)[] return'. 21-02 delivered the LIVE half -- the observed bytes with provenance -- but produced no Haskell decoder verification at all, and was explicitly scoped OUT of adding assertions to offchain/test/Main.hs (21-05 owns the suite side). Checking the box now would record a decoder verification that does not exist. Left unchecked in REQUIREMENTS.md; 21-05 closes it once decode_create_orders_result is asserted against offchain/rig/batch-return-capture.json.
- [Phase 21]: [21-01 MEASURED, invalidates a gate used in three tasks] `cabal build -j all` does NOT build the test suite -- it exited 0 with 0 warnings against a test suite carrying `Not in scope: record field 'target_vega'`. cabal only builds test components when tests are enabled. Every build/warning gate in this workstream must be `cabal build --enable-tests -j all`; the plain form certifies lib+exe only and would report a non-compiling suite as green.
- [Phase 21]: [21-01 MEASURED, honest negative that limits what RPIN-03 may claim] Under the `shiftR 152`->`shiftR 144` storage mutant, `rpin03_input_word_is_not_storage_word` stayed GREEN. Its final assertion is an INEQUALITY (`unpack_vol_order_storage input /= base`), and a WRONG offset satisfies an inequality as well as the right one. That check discriminates CONFLATION of the two layouts, never CORRECTNESS of either -- only `rpin03_storage_round_trip` establishes the 152 offset. Do not cite the former as evidence for the latter.
- [Phase 21]: [21-01 MEASURED, discrimination is specific] Under the `shiftL 128`->`shiftL 120` input-word mutant, `rpin01_encoder_argument_order` and `rpin02_field_rejections` correctly stayed GREEN: the calldata path goes through `cast calldata` and never touches `pack_vol_order_input` (genuinely independent encoders), and rejection checks assert BOUNDS not POSITIONS -- a misplaced field is still in range. Neither family covers the other; both are load-bearing.
- [Phase 21]: [21-01 FINDING, the EIGHTH self-contradicting criterion in this repo] The plan prescribed a comment stating the V1 3-arg path is deleted, while its own verification step 6 requires `grep -rn 'uint88,uint24,uint16)' offchain/` to produce NO output -- the natural comment matches that grep. Resolved by rewording the comment to omit the signature string (and to say why), never by relaxing the criterion. Same class as 20-05's prescribed Decode.hs comment.
- [Phase 21]: [21-01 FINDING, F1 CONFIRMED against the source] `src/modules/pos_spec/VolOrderManagerMod.plk:177-188` still reads 'bits >=128 MUST BE ZERO' and 'width IS DELIBERATELY UNMASKED. It is the TOP field', both FALSE of that same file's V2 code at 229-235 (width is masked and interior; targetVega is the unmasked top field at 128). Plank track's file -- REPORTED, never edited. An implementer trusting it ships a V1 packer that passes every offchain test and is SILENTLY SKIPPED on the batch path as an ordinary `(false,0)`. The Haskell-side comment in Encoding.hs now names the block as untrustworthy.
- [Phase 21]: [21-01 FINDING, F2] The module pins TICK_SPACING = 20 into storage bits 104..127 while the rig's own deployed pool has tickSpacing = 10 (rig-manifest.json .pool.tickSpacing). REPORTED in Decode.hs and offchain/test/Main.hs; the test expectation is written against the MODULE CONSTANT so a change to it reddens rather than passing silently. Not resolved -- resolving it means editing another track's module.
- [Phase 21]: [21-01 DECIDED] `cabal run` was deliberately NOT executed: it writes live orders to the shared anvil rig that 21-02 was capturing batch-return data from in the same wave. The V2 fix is proven statically (encoder selector == module's dispatched selector, three ways); live confirmation belongs to a plan that owns the rig state.
- [Phase 21]: [21-03 MEASURED] rpin06's inequality assertions do NOT catch a decoder that destroys targetVega -- with the baseline round-trip assertion neutralised the check PASSES under the target_vega=0 mutant. The baseline is the sole discriminator; an inequality never establishes correctness of the thing it is unequal about.
- [Phase 21]: [21-03 FINDING] sc4_no_retired_value_is_live is defeated by ZERO-PADDING: it compares pin values as strings, so the left-padded 32-byte form of a retired 8-hex value stays GREEN while that value is live. Pre-existing (Phase 20's check); logged to deferred-items.md, fix = compare numerically.
- [Phase 21]: [21-03 OBSERVED] FIRST E1 VolOrderCreated v2 log ever seen on chain: 2 topics, 128 bytes/4 data words, topic0 == pin, orderId in topic 1 only, data = (12345,600,77,1e18). Captured non-destructively via evm_snapshot/evm_revert; rig restored to block 9, orderCount 0, SC-2 green.
- [Phase 21]: 21-04: the plan's predicted mutant discriminator was REFUTED by measurement -- a linear-uniform draw spans 9 distinct bit-lengths (62..70) over 256 fixed-seed draws and clears the >= 8 spread assertion; bottom-decade mass (77 vs 4 of 256) is the real shape discriminator and was added
- [Phase 21]: 21-04: draw_target_vega's zero-lower-bound rejection is INCIDENTAL (0 * Infinity = NaN in the log transform), not an explicit parameter guard -- a second VegaDraw constructor must supply its own validation
- [Phase 21]: [21-05] RPIN-05 closed: live captured bytes asserted byte-for-byte against the alloy golden inside a suite PROVEN chain-independent with anvil stopped (65/65, pgrep anvil empty)
- [Phase 21]: [21-05 REFUTED] The plan's instruction to record follow-up #5 as ADDRESSED is FALSE — verify_mined_order is unchanged and still discards tickSpacing and bits >= 248 before comparing. Recorded PARTIALLY ADDRESSED.
- [Phase 21]: [21-05 REFUTED] blockNumber is NOT a provenance discriminator — three from-scratch deploys of the same rig gave heights 9, 11, 10. Freshness asserts chainId + manager only.
- [Phase 21]: [21-05 MEASURED] decode_create_orders_result never reads the outer offset word (follow-up #2 demonstrated); and the freshness check cannot see a module change behind an unchanged CREATE address (F4).
- [Phase 21]: [21-05 CLOSED] sc4_no_retired_value_is_live now compares NUMERICALLY — under 21-03's identical injection the suite reports 4 failures where 21-03 recorded 3.
- [Phase 22]: 22-01: IMPORT-PIN.md stays THE pin file (verify-import.sh's PIN= constant unchanged) — a Phase-22 pin file would create two sources of truth for one fact
- [Phase 22]: 22-01: .planning/issue-17-swappable-rig-SPEC.md (+134 on develop) deliberately NOT imported — the 37-path set is authoritative and every acceptance criterion is stated against the literal 37 (finding F22-3)
- [Phase 22]: 22-01: forge/plank delta measured with Phase 20's exact command AND seed (forge test --via-ir --fuzz-seed 4880), not the plan's bare 'forge test', so 85/27/112 is a real comparison
- [Phase 22]: 22-01: DRIV-01/DRIV-02 NOT marked complete despite being in the plan's requirements frontmatter — this is the import/unblock plan (1 of 6) and neither driver has run against a live rig; REQUIREMENTS.md stays Pending, matching Phase 20's RIG-01-at-20-05 precedent
- [Phase 22]: 22-02: EVERY signed field needs at least one NEGATIVE pin of its own — MEASURED, the third refuted discriminator in this workstream
- [Phase 22]: 22-02: compose_slot0 masks at bit 184 so protocolFee/lpFee survive BY CONSTRUCTION (G5b); masking at 160 breaks tick/sqrtPrice coherence (G5a)
- [Phase 22]: 22-02: PoolSwapTest.swap calldata is 388 bytes (4+32*12), not the planned 324 — the empty bytes member still costs an offset AND a length word
- [Phase 22]: 22-02: POOLS_SLOT = 6 is CONSUMED from the pinned DynamicFeeHook.plk constant, never re-derived from v4-core, so the hook and the client cannot disagree
- [Phase 22]: 22-02: RealizedVol.Decode is a DECODER only — the module name is not evidence the no-writeTimepoint-client decision was violated
- [Phase 22]: 22-04: the cheat-swap composition is DISCHARGED BY MEASUREMENT — an E3 carrying the cheated tick 5000 was observed on chain; the identical sequence aimed at PriceSetterPoolManager returns status 1, one E3, one E5 and tick 4999
- [Phase 22]: 22-04: G1 cannot be reached by OMITTING the clock advance — that races wall time (observed both ways); CheatSwap.Rpc gained ForceTimestamp to construct the collision, and anvil was measured accepting an EQUAL next-block timestamp while rejecting only strictly-lower
- [Phase 22]: 22-04: the near-floor tick -887259 does NOT revert and E3 carries it, so 22-05 needs no per-step direction/limit selection
- [Phase 22]: 22-05: DRIV-01 CLOSED by a PATH — five consecutive cheat->clock->swap steps, each producing exactly one E3 carrying the tick AND the timestamp submitted (t0=1700001670, stride=12, seed 123456789)
- [Phase 22]: 22-05: the plan's own G1 detector was MEASURED GREEN under its mutant and FIXED — a count equality over recorded steps is blind to the run being truncated; compare against configuredSize
- [Phase 22]: 22-05: DRIVER_CAPTURE redirects the WRITER as well as the checks, deliberately unlike 22-04's RIG_CHEAT_SWAP_PROOF — here the driver IS the capture tool
- [Phase 22]: or_complete is DRIV-02's OWN completion flag: dr_complete means the DRIV-01 path finished and is set before the order side runs, so borrowing it would report a price-path success as an order-side success
- [Phase 22]: The three submitted mixed-batch tuples are pinned BY VALUE, never by relations: a batch cut 3->2 is self-consistent in every relation a check could form (M4, measured)
- [Phase 22]: preview_create_orders exposed rather than widening create_orders' return type: a mined transaction carries NO returndata, so the 64-byte empty return is observable only through the preview eth_call
- [Phase 24]: 24-03: Produced carries CapturedStreams too -- the plan's two tasks contradicted each other on cs_run_dir observability, and the addition strengthens rather than weakens (Aborted still has no artifact)
- [Phase 24]: 24-03: backstop_no_exit_code = -1 -- when the in-process backstop fires there IS no exit status, and -1 is not a byte any process can return, so it cannot be mistaken for an observed code
- [Phase 24]: 24-03: GAMS-01 and GAMS-02 held at PARTIAL -- every Tier-A and Tier-B row shipped and is OBSERVED, but each has one Tier-C row that reads a capture artifact not existing until 24-06

### Pending Todos

**Next action: tag `v4.0` and send the peer hand-off.** Phase 19 is COMPLETE and the milestone is closed. Phases 16 (VORD-02), 17 (VORD-01/03/04/05), 18a (MCAL-01/02/03/04/06) and 18b (MCAL-05 + MCAL-06's carried clause) are DONE — the multicall is feature-complete. Phase 19 (MVER-01..04) is a **coordination checkpoint, NOT a research gap**: proceed on the placeholder + a `NOT-PEER-VERIFIED` stand-in fixture if the peer has not answered. The 18b research question is CLOSED — `std::abi` provably cannot encode an array (`abi_encoded_size` has no array case and Plank has no array type), so the head/tail was hand-rolled and proven byte-exact against solc.

**Peer hand-off ready for `mv15a18k` — now TWO documents.** 18a-01-SUMMARY.md CARRY-FORWARD section 2 has the input-word layout, the canonical-offset hard requirement and skip-vs-revert semantics. **18b-01-SUMMARY.md adds the RETURN side**: the exact `64 + 64N` byte layout, the N=0-returns-64-bytes clause (the one most likely to break a Haskell decoder, and invisible on-chain), and the canonical-bool divergence (solc REJECTS a non-canonical success word; a lenient Haskell decoder may accept it). Send both.

### MILESTONE v4.0 EXIT RECORD — OPEN ITEMS (none blocking)

- **F1 — the strike bound is UNPROVEN at the `create_order` entrypoint.** Mutant M2 dies ONLY in the Phase-16 pure-lib harness. No pos_spec test can express `strike >= 2^88` (the whole corpus is uint88-bounded), and on the BATCH path M2 is genuinely EQUIVALENT because `create_orders` masks the strike to 88 bits BEFORE validation, making `<= MAX_STRIKE` dead code there. The STRICT path reads the strike unmasked, so it IS killable: one `create_order` call with `strike = (1 << 88) + 7` asserting a revert would close it. Reported, not fixed — Phase 19 builds nothing.
- **Four mutants have a SINGLE POINT OF FAILURE.** Survivor count is genuinely 0 of 10, but M2 (only outside `test/pos_spec/`), M4 (the 65536 test alone) and M5/M6/M7 (`VolOrderManagerBatchGuardTest` alone) each rest on one test. Wave 1 is a kill site on 5/10 (19-01) and 4/10 (19-02) — real strengthening — but structurally CANNOT cover these: a typed Solidity mock and a golden-bytes fixture cannot emit a non-canonical offset or a truncated payload, and neither reaches id 65536. Delete any one of those tests and a real mutant survives with 39/40 still green.
- **[19-02 honest negative] `test__unit__externalEncoderConfirmsTheEmptyEncodingIsSixtyFourBytes` is NOT an anti-inaction gate** — it reads `expected[0]` only and stayed GREEN under a 5-to-4 fixture case-count drop. The count gate lives solely in the differential and the peer-gap tests.
- **Cross-language gap still OPEN.** alloy proves STANDARD-ABI conformance; it does NOT exercise peer `mv15a18k`'s Haskell decoder. Two different claims — the exit record must not conflate them.

### Blockers/Concerns

- **[RESOLVED at `8b11d73`, verified again at 19-05] The `--skip 'src/modules/protocol_integrations/PriceSetterHook.sol'` flag NO LONGER EXISTS.** The untracked sketch was deleted and the flag removed from all NINE Makefile recipes. Every prior phase's documented forge command is STALE on this point. Do NOT reintroduce it. Verified at 19-05: `grep -c -- '--skip' Makefile` = 0 and `grep -c 'PriceSetterHook' Makefile` = 0.
- **4 pre-existing pos_spec harness failures** (vol-type-system track) remain visible in `make test` — not v4.0 defects; the v4.0 suite must not filter them.
- **[17-01] The `make test` failure count is NOT deterministic.** A FIFTH failure, `TickVolatilityLibTest::test__fuzz__tickVolatilitySqrtPriceX64x96AndTickSuccess`, surfaces on roughly 1 cold-cache run in 4, always at counterexample `2^64-1`. PROVEN pre-existing (reproduced with all 17-01 files stashed: 86 pass / 5 fail) and owned by the TickVolatility track — it is NOT one of the 4 known `src/types/pos_spec/` reds. Re-run before treating a 5th failure as a regression. See `.planning/phases/17-interface-single-call-module/deferred-items.md` (D1); worth reporting `2^64-1` upstream as a genuine latent bug.
- **[17-01 MEASURED, binds 18a/19 and the Haskell consumer] `array_slot`'s add is CHECKED.** `v3::storage::array_slot` is `keccak256(base) + index` under Plank's checked `+`, so it PANICS (0x11) instead of wrapping. Addressable ids are capped at `2^256-1 - keccak(SLOT_ORDERS_BASE)` ≈ 6.5e74; above that `getOrderPacked` reverts rather than returning the 0 sentinel. Unreachable for counter-assigned ids, but relevant to any path accepting caller-supplied ids. Pinned by `test__unit__getOrderPackedOverflowBoundaryIsExactlyWhereCheckedAddSaturates`.
- **Peer coordination:** `MAX_BATCH` value and return-shape confirmation still pending peer `mv15a18k`. 18a-01 shipped MAX_BATCH = **128** (hard admissibility ceiling 512; a peer value above it is CAPPED and reported, never silently adopted). **18b-01 shipped the return shape** as `(bool,uint256)[]` at `64 + 64N` bytes; every 18a state assertion was inherited unchanged and now flows through `abi.decode`, so they got strictly stronger. Does not block Phase 19.
- **[18b-01] The N=0 64-byte return is a HARD ENCODING REQUIREMENT on the consumer, and its failure is INVISIBLE on-chain.** A zero-arrival Poisson tick returns 64 bytes (offset `0x20`, length `0`), never 0 and never 32. A decoder that treats an empty batch as an empty returndata will revert in the Haskell client, not here. This is the single clause in the return contract most likely to break `StochasticOrderGen`.
- **[18a-01] The canonical-offset guard is a HARD ENCODING REQUIREMENT on the consumer**, not a soft convention. Solidity/`cast`/ethers/web3.py all emit `0x40` at byte 36, but a bespoke Haskell encoder that legally pads the head will be rejected with an empty revert. Flagged to the peer; if they cannot emit canonical offsets this becomes a real integration blocker rather than a test detail.

## Session Continuity

Last session: 2026-08-17T05:13:03.000Z
Stopped at: PHASE 24 COMPLETE (6/6 plans, 7/7 requirements) -- next /gsd:plan-phase 25
Resume file: None
