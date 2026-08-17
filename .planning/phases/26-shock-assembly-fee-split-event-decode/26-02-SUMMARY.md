---
phase: 26-shock-assembly-fee-split-event-decode
plan: 02
subsystem: chain-event-decode
tags: [event-decode, sign-extension, two-topic-log, abi-oracle, emitter-authenticity, zero-trap, trip-wire, scan-scope-growth, chain-04]

# Dependency graph
requires:
  - phase: 26-shock-assembly-fee-split-event-decode
    plan: 01
    provides: "Fee.Split's ellipse_test and is_admissible, which check 4 uses to show that the prover cannot answer a zero rate; and the BASE + N discipline plus the two re-measured tree floors this plan re-measured again"
  - phase: 22-driver-and-realized-vol
    provides: "RealizedVol.Decode.signed_word -- the 2^255-threshold conversion the emitter's @evm_signextend(2, raw) makes correct for word 0 -- and the module haddock idiom this decoder's MUST-NOT-BE-TRUSTED-ON paragraph extends"
  - phase: 21-event-repin
    provides: "VolOrder.Decode's data_word/hex_to_integer/be_integer, and the synthetic_log + topic0_of chain-free decode idiom the corpus is built on"
provides:
  - "offchain/lib/Chain/Shock.hs: shock_signature, ShockEvent (4 fields), ShockDecodeError (10 constructors), decode_shock -- Either, total, no IO, six imports, +0 packages"
  - "a 21-member NAMED synthetic corpus in offchain/test/Main.hs, driven by name in every check"
  - "twelve CHAIN-04 checks in core_checks (169 -> 181), each OBSERVED failing under its named input"
  - "an INDEPENDENT ABI-coder oracle for the data-word layout (cast abi-encode), which closes Solidity M2 / RC-M7"
  - "expected_emitter + WrongEmitter: an event topic is unauthenticated, and the decoder now says so with a guard rather than with prose (RC-M4)"
  - "the ShockLib trip-wire RE-SCOPED to origin/develop: it now parses the emitter's own SHOCK_EVENT_TOPIC0 and compares it to keccak of the signature, closing RC-m7 by measurement"
  - "the scan scope grown to offchain/lib/Chain in the SAME commit as the module, both tree floors re-measured cold (63->64, 71/72->73)"
affects: [26-03, 26-04, 27]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "A synthetic corpus that shares the decoder's belief about the wire is a tautology until a SECOND coder's output is pinned beside it"
    - "An event topic is unauthenticated: expected_emitter is an ARGUMENT, exactly as expected_topic0 is, and for a stronger reason"
    - "A refusal whose subject is a LEGAL upstream state is named after the state (ZeroShock), not after damage (AllZeroPayload), and its consumer rule is haddocked at the constructor"
    - "A trip-wire whose subject cannot become true is re-scoped to a subject that can -- here, a ref this branch reads and never merges"
    - "A range window is asserted from BOTH ends: the half no fixture reaches is a standing assertion"
    - "SET arms run BEFORE count arms: a count arm placed first short-circuits and never names the member"
    - "A constant separately named but DEFINED as its twin (shocklib_local_path = shocklib_path) makes an otherwise unfireable arm fireable without touching another workstream's tree"

key-files:
  created:
    - offchain/lib/Chain/Shock.hs
  modified:
    - cfmm-replicationPlank-rpc-api.cabal
    - offchain/test/Main.hs

key-decisions:
  - "decode_shock takes TWO expected values, not one: expected_topic0 and expected_emitter, with a WrongEmitter constructor (RC-M4). The corpus carries a wrong-emitter member, which synthetic_log alone could never express"
  - "AllZeroPayload renamed ZeroShock (RC-M3 option a), but for a DIFFERENT and stronger reason than the finding gives -- the finding's own justification is measured FALSE here"
  - "The ABI-coder oracle is a sibling constant, NOT a ground_truth row: sc4_ground_truth_encoder hashes every row's signature and compares it to the value, so a 192-char payload row would redden it"
  - "The trip-wire's subject moved from the working tree to origin/develop and its assertion moved from 'the file is absent' to 'the emitter's constant, word order and payload length are what this decoder assumes'"
  - "Two corpus rows added for the int24 window's POSITIVE half (m6): +8388607 in range, +8388608 out"
  - "The pin-set verification grep is anchored to '^expected_topic_pins ::': the unanchored form matches the ground_truth comment that explains the exclusion and could never print 0"

patterns-established:
  - "A guard whose firing is DOMINATED by another guard is reported as such and then observed under a two-part mutation that lifts the dominating one"
  - "A mutation ledger records which ARM fired and what it printed, not merely that the check went red"

requirements-completed: [CHAIN-04]

# Metrics
duration: ~5h
completed: 2026-08-17
---

# Phase 26 Plan 02: `Chain.Shock` — the Decoder for an Event Whose Every Production Log Is Two-Thirds Zero — Summary

**The `Shock` decoder lands as 259 lines of total `Either` code with six imports and no IO, and the
thing that makes it believable is not the decoder — it is a 21-member corpus carrying a negative
tick and a nonzero decay that production never emits, checked against an independent ABI coder so
the corpus and the decoder are not the same mistake twice. Four corrections to the plan and the
findings were made with the measurement that found them, the largest being that RC-M3's stated
justification for renaming `AllZeroPayload` is FALSE: `render_argv` has eight refusals, not nine,
and its `txlVolumeRate` lower bound is `0`, so nothing downstream kills a zero rate — which makes
the `ZeroShock` consumer rule load-bearing rather than merely tidy.**

## Performance

| | Wave start (BASE) | After this plan |
|---|---|---|
| `cabal test` | **169/169** | **181/181** |
| FAIL | 0 | **0** |
| exit code | 0 | **0** |
| `-Wall` warnings | 0 | **0** |
| `cabal test` wall | **181 s** | **176 s** |
| `purge_file_floor` | 63 | **64** |
| `credential_scan_floor` | 72 | **73** |
| modules under `offchain/lib/Chain` | 0 | **1** |
| packages added | — | **0** (`DL=0`) |

**BASE was measured COLD at `2026-08-17T17:01:25Z`, before this plan edited a single file:**
`cabal build --enable-tests -j all` exit `0` with `0` warnings, then `cabal test` → `169 PASS`,
`0 FAIL`, exit `0`, wall `181 s`. That equals exactly what `26-01-SUMMARY.md` recorded on exit
(169), so there is no BASE finding to report. Every gate in this plan was `BASE + N` against 169
and no absolute total was inherited. The 149.5 s wall in `26-VALIDATION.md` remains superseded; the
finished suite runs at **176 s against a 900 s ceiling**, and the twelve new checks plus one
subprocess-backed git read cost nothing measurable above run-to-run variance (the same tree
measured 151 s, 154 s, 157 s, 168 s and 176 s across five green runs today).

## Task Commits

| Task | Name | Commit |
|---|---|---|
| 1 | `Chain.Shock` — the decoder, the emitter it cannot authenticate, and the scan scope | `b22b637` |
| 2 | The 21-member named corpus and the eight CHAIN-04 decode checks | `e69a2e8` |
| 3 | The corpus set, the decay that never renders, and two trip-wires seen to fire | `d536d08` |

## Gate readings, as PRINTED

| Gate | Command | Reading |
|---|---|---|
| build | `cabal build --enable-tests -j all` | exit `0`, `WARN=0`, `DL=0` |
| hex literals, module | `grep -cE '0x…{40}\b\|0x…{64}\b\|0x…{8}\b' offchain/lib/Chain/Shock.hs` | `HEXLIT=0` |
| hex literals, suite | same pattern over `offchain/test/Main.hs` | `HEXLIT=0` |
| no 24-bit mask | `grep -cE '16777215\|0xffffff\|\.&\.' offchain/lib/Chain/Shock.hs` | `MASK24=0` |
| sign extension present | `grep -c 'signed_word' offchain/lib/Chain/Shock.hs` | `4` |
| length rule | `grep -c '>= 96'` / `grep -c '== 96'` | `0` / `1` |
| constructors | `grep -cE '^  [=\|] (WrongTopicArity\|WrongTopic0\|WrongEmitter\|NotAnAddress\|ZeroPool\|WrongDataLength\|ZeroShock\|TickDiffOutOfRange\|NormRateOutOfRange\|DecayOutOfRange)'` | `10` |
| imports | `grep -c '^import' offchain/lib/Chain/Shock.hs` | `6` |
| cabal registration | `grep -n 'Chain.Shock' cfmm-replicationPlank-rpc-api.cabal` | line 171, in `exposed-modules` |
| decay absent from renderer | `grep -nHE '[Dd]ecay' offchain/lib/Gams/Argv.hs` | no output, **exit 1** |
| pin set | `sed -n '/^expected_topic_pins ::/,/^$/p' … \| grep -c Shock` | `0` |
| scan membership | `grep -c 'offchain/lib/Chain/Shock.hs'` / `grep -c '"offchain/lib/Chain"'` | `1` / `1` |
| DB-free | `grep -cE 'Store\.Postgres\|CFMM_REQUIRE_DB\|connectPostgreSQL' offchain/test/Main.hs` | `DBFREE=0` |
| GAMS-free | `grep -cE 'Gams\.Invoke\|CFMM_REQUIRE_GAMS\|/usr/gams' offchain/test/Main.hs` | `GAMSFREE=0` |
| emitter absent locally | `test -e src/models/mev_tax_model_one/libraries/ShockLib.plk` | `ABSENT` |
| NUL bytes | `wc -c` vs `tr -d '\000' \| wc -c` | `803685` both ways (suite); `14814` both ways (module) |
| territory | `git status --porcelain src test foundry-scripts Makefile foundry.toml .github` | **empty** |

### The two floors, re-measured COLD as a pair

Both commands were RUN at task 1's commit, with `offchain/lib/Chain/Shock.hs` on disk, and RUN
AGAIN at task 3. Neither number was derived from the other and neither was obtained by adding one
to what was beside it.

```
find offchain -type f \( -name '*.hs' -o -name '*.sh' -o -name '*.sql' \) | wc -l
64
find offchain -type f \( -name '*.hs' -o -name '*.sql' -o -name '*.sh' -o -name '*.json' \) | wc -l
73
```

Census under `offchain/` at that measurement: `hs 52, sh 9, json 9, sql 3`. Wave-start readings,
taken cold before this plan touched anything, were **63 / 72** — so the delta is exactly the one
`.hs` this plan creates, confirmed by running both commands at both ends rather than by arithmetic.
Both floors are set to the printed values, **zero slack**, and both were re-read unchanged at the
final verification run.

## The firing ledger — twelve guards, seventeen observations, every one OBSERVED

Every mutation was applied to the working tree, built, run, and then restored from a **saved copy
verified by `sha256sum` on all four files**, never `git checkout`. Restore was verified after every
single mutation and again at the end: `Chain/Shock.hs` →
`b5d4002fe1ccf15a85db4ea9399a3f3c058362163eb7631a407689461926e64a`, `Gams/Argv.hs` →
`e7475dd7095136798c22ee3fd04a784d0e845d368e9344413584aa6d406e0409`, `app/GamsConformance.hs` →
`0af39b72fcdd23738e8962e7c120d1f5dc04f5b2243f69b9c2510d0d0d5554c1`, and `offchain/test/Main.hs` to
the digest current at each stage.

| # | Guard / arm | Firing input | What went red, VERBATIM |
|---|---|---|---|
| 1 | `shock_topic0_is_computed_from_the_signature_string` | `int24` → `int23`, one character, in the LIBRARY's `shock_signature` | `the ground-truth row's signature is "Shock(address,int24,uint24,uint24)" and the LIBRARY's Chain.Shock.shock_signature is "Shock(address,int23,uint24,uint24)". The test must hash the string the decoder is documented against; two copies that drift apart would both keep agreeing with themselves.` |
| 2 | `the_corpus_payload_agrees_with_an_independent_abi_coder` | words 1 and 2 transposed in the **corpus** | `the corpus built the payload` / `…ff3800000000…0007 0000…077a10` / `and a SECOND ABI coder (cast abi-encode "f(int24,uint24,uint24)" for -200 490000 7) produced` / `…ff380000…077a10 0000…0007` / `These differ, so the corpus's model of the wire is wrong -- word order, padding or sign extension -- and every decode assertion below is being made against a payload the chain would never emit.` |
| 3a | `a_negative_tick_diff_decodes_sign_aware` **range arm, mask** | `signed_word` → `\`mod\` 16777216` | `the corpus member "negative-tick-and-decay" was REFUSED as TickDiffOutOfRange 16777016, and it is a member that must DECODE.` |
| 3b | same, **pinned-mask-answer arm** | mask AND the int24 window widened to `uint24` | `se_tick_diff is 16777016, which is EXACTLY the 24-bit-mask answer for this word. The emitter ends shock_tick_diff with @evm_signextend(2, raw), so the word arrives sign-extended to the full 256 bits and a mask is wrong.` |
| 3c | same, **range arm, identity** | `signed_word` replaced by the identity | `the corpus member "negative-tick-and-decay" was REFUSED as TickDiffOutOfRange 115792089237316195423570985008687907853269984665640564039457584007913129639736` |
| 3d | same, **pinned-unconverted-answer arm** | identity AND the tick range guard removed | `se_tick_diff is 115792089237316195423570985008687907853269984665640564039457584007913129639736, which is the raw 256-bit word with no conversion applied at all.` |
| 4 | `an_all_zero_payload_is_rejected` | the `ZeroShock` arm deleted | `the all-zero payload decoded to` / `Right (ShockEvent {se_pool = 730750818665451459101842416358141509827966283833, se_tick_diff = 0, se_norm_rate = 0, se_txl_decay = 0})` / `It must be refused BY NAME.` |
| 5 | `a_wrong_length_payload_is_rejected` | `== 96` relaxed to an at-least rule | `the corpus member "length-128" decoded to Right (ShockEvent {… se_norm_rate = 490000 …}) and the corpus says it must decode to Left (WrongDataLength 128)` |
| 6a | `wrong_topic0_wrong_arity_and_wrong_emitter…` **arity arm** | `[topic0, pool_topic]` → `(topic0 : pool_topic : _)` | `the corpus member "three-topics" decoded to Right (ShockEvent {…}) and the corpus says it must decode to Left (WrongTopicArity 3)` |
| 6b | same, **emitter arm** | the emitter guard dropped | `the corpus member "wrong-emitter" decoded to Right (ShockEvent {… se_tick_diff = -200 …}) and the corpus says it must decode to Left (WrongEmitter 730750818665451459101842416358141509827966275730)` |
| 7 | `the_pool_topic_is_a_nonzero_address` | both pool guards dropped | `the corpus member "zero-pool" decoded to Right (ShockEvent {se_pool = 0, …}) and the corpus says it must decode to Left ZeroPool` |
| 8a | `out_of_range_words_are_rejected` **transposition arm** | `data_word 1` and `data_word 2` transposed in `decode_shock` | `the corpus member "norm-rate-at-2-24" decoded to Left (DecayOutOfRange 16777216) and the corpus says it must decode to Left (NormRateOutOfRange 16777216)` |
| 8b | same, **pip-domain arm** | `in_range "txlVolumeRate"` upper bound widened to `16777215` | `render_argv ACCEPTED the shock and rendered all seven tokens. Its txlVolumeRate is 5000000, and this arm exists because that value must be refused BY FIELD NAME.` |
| 9a | `the_synthetic_corpus_carries_what_production_never_emits` **SET arm, deletion** | `negative-tick-and-decay` DELETED | `these pinned corpus members are NOT in shock_corpus: negative-tick-and-decay. A member that vanishes takes every assertion made about it with it, and the suite total shrinks silently -- which is why this is a SET and not a count.` |
| 9b | same, **SET arm, count-preserving RENAME** | renamed to `negative-tick-and-decay-v2` (21 before, 21 after) | identical SET failure, plus three by-name lookup failures printing all 21 members — **a count-based assertion would have survived this** |
| 10a | `txl_volm_decay_never_reaches_the_prover` **token-set arm** | an eighth `--txlRateEcho=` token added to `render_argv` | `the rendered command line carries argv keys that are not pinned: --txlRateEcho. VOLUME_PATH.md section 2 rules the decay rate is not an input by ruling: the closed loop is trusted.` |
| 10b | same, **prose-scan arm** | the word written into a `Gams/Argv.hs` haddock, prose only | `the decay identifier appears in offchain/lib/Gams/Argv.hs, … so the word may not be written there even in prose.` / `offchain/lib/Gams/Argv.hs:121:-- The decay rate is deliberately absent from this list.` |
| 10c | same, **seven-field arm** | an eighth field added AND every record literal fixed up | **BUILD FAILURE**, verbatim: `offchain/test/Main.hs:13283:17: error: [GHC-27346]` / `• The data constructor 'Shock' should have 8 arguments, but has been given 7` / `• In the pattern: Shock a b c d e f g` |
| 11a | `the_upstream_shocklib_pin_is_a_live_trip_wire` **control, negative direction** | `shocklib_absent_path` pointed at a path that IS on `origin/develop` | `the upstream reader reports src/models/mev_tax_model_one/libraries/Shock.plk as PRESENT in origin/develop. It says yes to a path that is not there, so its yes about the emitter is worth nothing. A trip-wire never seen to say NO is ABSENT.` |
| 11b | same, **constant arm** | `shocklib_path` pointed at the sibling `Shock.plk` | `no SHOCK_EVENT_TOPIC0 declaration was found in src/models/mev_tax_model_one/libraries/Shock.plk on origin/develop. The constant is what decides whether this decoder ever matches a real log; the pin only decides whether two copies of a hash agree.` |
| 11c | same, **pin-set arm** | `"Shock"` added to `expected_topic_pins` | `"Shock" is in expected_topic_pins, but offchain/rig/generate-pins.sh iterates the interface files present in THIS worktree and …ShockLib.plk is not one of them, so the generator can never produce that pin…` — and `sc4_pin_surface_is_the_expected_set` went red beside it with `missing : Shock` |
| 11d | same, **merge-landed arm** | `shocklib_local_path` pointed at a file that exists here | `offchain/lib/Chain/Shock.hs is now in THIS worktree… Do all four: (1) move the topic0 pin out of ground_truth into the generated offchain/rig/rig-pins.json surface; (2) add "Shock" to expected_topic_pins; (3) RE-VERIFY THE CONSTANT … rather than merely re-homing the pin, because those are different facts and only the second one decides whether a real log ever matches; (4) delete this check, whose subject has been overtaken.` |
| 12 | `the_decoder_holds_no_IO_and_no_chain` | `import System.IO.Unsafe (unsafePerformIO)` added to `Chain/Shock.hs` | `the Shock decoder names a process spawn, the unsafe-IO escape hatch, the web3 runner or an IO action.` / `offchain/lib/Chain/Shock.hs:70:import System.IO.Unsafe (unsafePerformIO)` |

**NO guard added by this plan lacks an observed firing.** Arms are reported separately from their
check because the ORDER of arms inside a check is what makes them different guards.

### What the mutations also taught, recorded rather than smoothed over

- **The int24 range guard DOMINATES the two pinned-wrong-answer arms.** Under a plain mask or a
  plain identity, `decode_shock` never returns `16777016` or the 77-digit word — the range guard
  refuses first, and the check reddens on `shock_right` instead. Both arms were therefore observed
  under a two-part mutation that lifts the dominating guard (rows 3b and 3d). They are not dead
  code: they are what remains if the range window is ever widened, and the pair of two-part
  mutations is the evidence.
- **A count arm placed before a set arm never names anything.** MEASURED: the first draft of check
  10 asserted `length tokens == 7` before comparing the key sets, and the eighth-token mutation
  reported `8, expected 7` without ever saying which key was new. The arms were reordered — set
  first, count second — and the count arm's message rewritten to say what a count mismatch means
  *after* the sets agree (a duplicate key).
- **An eighth field breaks the build at the record LITERALS, not at the pattern match.** The
  plan's arm-3 firing input (add a field, watch the build fail) fails at `fixture_shock` and at
  `GamsConformance.hs:140` before the compiler ever reaches the seven-field pattern. So a second
  mutation was run that adds the field AND fixes every literal, leaving the pattern match as the
  only objector — that is the GHC error quoted at row 10c. **There is no `_` in that pattern**, and
  the arm was proved to have teeth independently of the literals.
- **The eighth-token mutation reddens `gams_conformance_is_present_and_fresh` too**, by digest, in
  every case where `Gams/Argv.hs` was touched. That is the freshness oracle doing its job and it is
  recorded here so a future reader does not mistake it for collateral damage.

## Deviations from Plan

### 1. `[RC-M3 — and a CORRECTION TO THE FINDING]` `AllZeroPayload` → `ZeroShock`, for a reason the finding gets backwards

The rename is right and it shipped. Issue #28 emits all three components always with absent ones as
`0`, v6.0 tags `flags = 0b010`, and a period with no transactional volume makes the third word zero
too — so an all-zero payload is a legal "quiet period", and naming its refusal after corruption
would make Phase 27 raise an alarm on the most ordinary event there is. `ZeroShock` is haddocked at
the constructor with the consumer rule: **it is a SKIP, never a decode alarm.**

**But the finding's justification is FALSE, and this plan is where that was found.** RC-M3 says
*"`render_argv`'s ninth refusal already kills `txlVolumeRate = 0` for free"*. MEASURED at
`offchain/lib/Gams/Argv.hs:137`:

```
_ <- in_range "txlVolumeRate" (sh_txl_volume_rate shock) 0 999999
```

The lower bound is **`0`**, so a zero rate renders cleanly and reaches the prover. And there is no
ninth refusal: `render_argv` has **eight** — seven `in_range` calls and `distinct_fees` — which the
suite's own `argv_refusals` list already calls "the eight shocks that must not render". The first
draft of check 4 asserted the finding's claim and **went red**, which is how it was caught:

```
FAIL an_all_zero_payload_is_rejected: render_argv ACCEPTED the shock
```

The arm was rewritten to assert what is true and to record the consequence. The half of the finding
that IS true — `E(x, m, 0) = D⁴xm > 0`, so `δ* = 0` is inadmissible for every fee pair — is now
asserted against `Fee.Split`'s shipped `ellipse_test` and `is_admissible` at the fixture's own fee
pair. **The consequence points the opposite way from the finding's:** nothing downstream refuses a
zero rate and the prover cannot answer one, so the `ZeroShock` skip is **load-bearing** — it is the
only thing between a quiet period and a solve that must abort. That is a stronger reason to keep
the refusal than the one the finding offers.

### 2. `[RC-M4]` `expected_emitter`, `WrongEmitter`, and the corpus member that could not previously exist

`decode_shock` takes TWO expected values. An event topic is unauthenticated: any contract can emit
topic0 `21b0e4f8…` with any word in topic 1, and `pool /= 0` plus `pool < 2^160` make a log
well-shaped, not authentic. The guard sits between the topic0 check and the address-shape checks,
with the ordering reasoned in the haddock. The MUST-NOT-BE-TRUSTED-ON paragraph carries all three
obligations: the zero trap, the unauthenticated topic, and the block/log-index/transaction the
return type cannot hold — the last stated as an explicit obligation on any caller that decodes more
than one log.

`synthetic_log` hardcodes `filler_address` (the zero address) for every log it builds, so **no
phase-26 check could observe emitter discrimination even in principle**. A `shock_log_from` helper
was added that makes the emitter explicit, and the `wrong-emitter` member — identical to the
canonical negative fixture in topic0, arity and payload, differing only in where it came from — is
its firing input (row 6b).

### 3. `[M2 / RC-M7 — and a CORRECTION TO THE FINDING'S PLACEMENT]` The ABI oracle is a sibling constant, not a `ground_truth` row

The oracle shipped exactly as specified in content: `cast abi-encode "f(int24,uint24,uint24)" -- -200 490000 7`,
192 bare hex characters, asserted equal to the `negative-tick-and-decay` member's `changeData`,
with the transposition firing input (row 2). `ShockRoundTrip.t.sol` is cited in the haddock as
corroboration from the other side and was **read only**, never edited.

**It is NOT in `ground_truth`, and it cannot be.** `sc4_ground_truth_encoder` (`Main.hs:766`)
iterates every row of that list and asserts `keccak(sig) == value`; a row whose value is a 192-char
ABI encoding rather than a 32-byte hash reddens it immediately. The list is a signature-to-hash
table. `shock_payload_ground_truth` is a sibling constant beside it, following the same bare-hex
convention, with the reason recorded in its own haddock. The event's **topic0** row IS in
`ground_truth` as the finding intended, and it gains a free in-suite recomputation from that
existing check.

### 4. `[UPDATE 2026-08-17 / RC-M7]` The trip-wire was re-scoped, and it now asserts something

The plan's check 10 had as its subject `doesFileExist "src/models/…/ShockLib.plk"` in this
worktree, required to be `False`. PR #30 merged all 17 files of that model into `origin/develop`
(merge `291d8a6`, verified here with `git rev-parse`), and this branch is 84 ahead / 293 behind and
must not merge it — so that subject would stay permanently satisfied-by-absence.

The subject moved to `origin/develop`, read through `git cat-file -e` and `git show`, never through
a merge. The check now asserts **five** things, control first and in both directions:

1. **control**: the reader says YES to `ShockLib.plk` on `origin/develop` and NO to a path that is
   not there. A reader that says yes to everything proves nothing (row 11a).
2. the emitter's hand-written `SHOCK_EVENT_TOPIC0` **equals** `keccak(shock_signature)` — **this is
   RC-m7, closed by measurement instead of by prose** (row 11b). Both were verified independently
   here: `ShockLib.plk:7` and `cast keccak` agree byte for byte.
3. the three `@mstore32` calls name the accessors in the order `[shock_tick_diff,
   shock_txl_volm_norm_rate, shock_txl_volm_decay]` — the word order this decoder assumes, read
   back out of the emitter rather than asserted about it.
4. the log call is `@evm_log2` over **96** bytes.
5. `"Shock"` is not in `expected_topic_pins`, and the emitter has not landed in this worktree —
   with the four-step instruction text, which keeps the finding's advice: **re-verify the CONSTANT,
   not merely re-home the pin** (rows 11c, 11d).

Arm 5 needed one accommodation to be fireable at all: `shocklib_local_path` is a separate name
**defined as** `shocklib_path`, so the two cannot drift, and repointing it makes the arm fire
without creating a file under `src/`, which is another workstream's tree and read-only here.

### 5. `[m6]` Two corpus rows, and the half of the window that was never asserted

`most-positive-tick` (`8388607`, must decode) and `tick-above-range` (`8388608`, must be refused).
Without them `tick < 8388608` was a standing assertion — and it is the half that catches a 24-bit
mask, since the mask answer for the `-200` word is `16777016`, comfortably above `8388607` and
comfortably inside `uint24`. Both are in check 8's first arm and both were exercised by the mask
mutation.

### 6. `[m8]` and `[m1]`, folded in as specified

- `NotAnAddress` carries a haddock line at `shock_signature` recording that this event is
  address-keyed because THIS signature says so, and that the poolId-keyed sibling
  (`UniswapV4MevTaxModelOneShocksWriterInterface.plk`) would be a different signature and therefore
  a different topic0 — so a future reader does not relax `pool < 2^160`.
- Check 10's three arms each have their own firing input in the acceptance list and each was
  observed separately (rows 10a, 10b, 10c).

### 7. `[NEW — found here]` The pin-set verification grep could never have printed 0

The plan's acceptance command is
`sed -n '/expected_topic_pins/,/^$/p' offchain/test/Main.hs | grep -c Shock` = 0. `sed` **restarts**
its range at every matching line, so the comment beside the `ground_truth` row — the one that
explains *why* the name is excluded, and which therefore has to name `expected_topic_pins` — opens
a range that runs to the next blank line and swallows the `Shock` row. MEASURED: **2**, not 0.

Resolved the way this repository resolves this class: **the pattern was anchored to what it means**,
not the prose moved and not the scan narrowed. `sed -n '/^expected_topic_pins ::/,/^$/p'` selects
the declaration block alone and prints **0**. This is instance 24 of prose inside a grep's blast
radius on this branch; instance 23 was 26-01's `\bsqrt\b`. A second instance was hit and fixed
inside `Chain/Shock.hs` itself: the haddock paragraph explaining why the length rule is an equality
originally spelled the at-least operator followed by `96`, tripping the plan's own `GE96=0` gate at
`GE96=1`. The paragraph now says so explicitly, which is cheaper than the next reader rediscovering
it.

### 8. `[Executor rule]` The scan-scope growth landed in task 1's commit, not task 2's

`the_artifact_path_scan_covers_every_module_on_it` is bidirectional. Creating
`offchain/lib/Chain/Shock.hs` without listing it leaves it *unlisted*; listing it without listing
`offchain/lib/Chain` makes it a *phantom*. Both edits and both floor re-measurements are in
`b22b637`, the commit that creates the file — so task 1's file list includes `offchain/test/Main.hs`,
which the plan does not list. Same correction 26-01 made, for the same reason.

### 9. `[Count]` Twelve checks, not eleven

The plan specifies eleven; `the_corpus_payload_agrees_with_an_independent_abi_coder` is the twelfth,
and it exists because M2 / RC-M7 arrived after the plan was written. It is a separate check rather
than an arm of check 3 because it is the only assertion in the phase whose evidence comes from
outside this repository, and folding it into a check about sign extension would bury that. Final
total is **BASE + 12 = 181**, recorded and not predicted.

### 10. `[Check names]` One rename

`wrong_topic0_and_wrong_topic_arity_are_rejected` became
`wrong_topic0_wrong_arity_and_wrong_emitter_are_rejected`, because RC-M4's emitter arm belongs with
the other authenticity arms and a check name that omitted it would be a name that lies.
`an_all_zero_payload_is_rejected` kept its name exactly, as the plan's `must_haves` requires —
the rename was of the CONSTRUCTOR, not of the check, and "rejected" remains literally true.

## What the module actually is

`offchain/lib/Chain/Shock.hs`, 259 lines, six imports, **+0 packages** (`DL=0` measured at the
commit): `Data.ByteString`, `Data.ByteArray.HexString`, `Data.Solidity.Prim.Address`,
`Network.Ethereum.Api.Types`, and two modules of this same stanza. Nothing does IO, spawns, hashes
or parses.

| Guard | Order | Refusal |
|---|---|---|
| topic arity is exactly 2 | 1 | `WrongTopicArity n` |
| topic 0 matches | 2 | `WrongTopic0 got` |
| the emitting address matches | 3 | `WrongEmitter got` |
| topic 1 fits in 160 bits | 4 | `NotAnAddress pool` |
| topic 1 is nonzero | 5 | `ZeroPool` |
| payload is EXACTLY 96 bytes | 6 | `WrongDataLength n` |
| not all three words zero | 7 | `ZeroShock` |
| `-8388608 <= signed_word w0 < 8388608` | 8 | `TickDiffOutOfRange tick` |
| `w1 < 16777216` | 9 | `NormRateOutOfRange w1` |
| `w2 < 16777216` | 10 | `DecayOutOfRange w2` |

`signed_word` is applied to word 0 and to nothing else, with the reason at the call site: the
emitter ends `shock_tick_diff` with `@evm_signextend(2, raw)` and masks the two rates with
`& MASK_U24`, so applying it to a `uint24` would be a bug that never announces itself.

## Structural facts held

- Both structural greps over `offchain/test/Main.hs` are **0** (`DBFREE`, `GAMSFREE`).
- `core_checks` is the sole registration point; all twelve names are defined AND registered.
- `git status --porcelain src test foundry-scripts Makefile foundry.toml .github` is **empty**.
  `develop` was never merged. `ShockLib.plk`, `Shock.plk` and `ShockRoundTrip.t.sol` were read with
  `git show origin/develop:…` and cited; none was edited.
- The four pre-existing untracked root files (`CHANGELOG.md`, `Setup.hs`, `stack.yaml`,
  `stack.yaml.lock`) were left alone.
- No file written by this plan contains a NUL byte.
- No corpus member is reached by position: `grep -nE 'shock_corpus *!!|head shock_corpus|tail shock_corpus'`
  is empty, and the one `head` that briefly existed was removed because `-Wx-partial` made it a
  warning — which is a gate failure here.

## Open, and named

1. **`ShockEvent` still carries no block, log index or transaction.** RC-M4's cheaper fix shipped
   (the emitter argument); the type-level half did not, because `Change` values are what carry that
   information and every consumer would have to change. The obligation is stated in the module's
   MUST-NOT-BE-TRUSTED-ON paragraph and is **Phase 27's to discharge**: a batch decode must keep
   the `Change` alongside the `ShockEvent`, or the two blocks mix silently.
2. **`render_argv` admits `txlVolumeRate = 0`.** Measured, asserted, and left alone deliberately —
   raising the lower bound to 1 is a change to 26-03/26-04's file and to the GAMS conformance
   digest, and it is not this plan's to make. Check 4's arm 2 is written to be REWRITTEN rather than
   deleted if that bound ever moves, and its failure text says so.
3. **The pip domain is closed by two guards that neither of them owns.** `decode_shock` bounds the
   rates by `2^24`; `render_argv` bounds them by `1000000`. The composition is asserted end to end
   in check 8's fifth arm, but nothing asserts that the two remain the only two.
4. **The trip-wire depends on `origin/develop` being resolvable in the clone.** If it is not, the
   check fails loudly with `git fetch origin develop` in its message. That is deliberate — a guard
   that skips itself when its evidence is unavailable is a guard that is absent — but it is a new
   external dependency for the suite (`git`, alongside the existing `grep` and `/bin/sh`), and it is
   recorded as one.
5. **Phase 27 must treat `ZeroShock` as a SKIP.** The rule is haddocked at the constructor and in
   `decode_shock`, and check 4 records why it is load-bearing. Nothing in phase 26 can enforce it.

## Self-Check: PASSED
