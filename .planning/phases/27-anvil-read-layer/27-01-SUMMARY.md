---
phase: 27-anvil-read-layer
plan: 01
subsystem: chain-endpoint
tags: [chain-06, chain-07, endpoint-resolver, site-census, producer-binding, bidirectional-manifest, no-chain-needed]

# Dependency graph
requires:
  - phase: 26-shock-assembly-fee-split-event-decode
    plan: 02
    provides: "offchain/lib/Chain/ and its entry in artifact_path_directories -- which is why Chain/Endpoint.hs had to join aeson_storage_path in the commit that created it"
  - phase: 26-shock-assembly-fee-split-event-decode
    plan: 04
    provides: "purge_file_floor = 67 and credential_scan_floor = 77, the readings this plan re-measured from; and the standing rule that a mutation baseline is RE-TAKEN after every intentional edit"
  - phase: 22-live-stochastic-drivers
    provides: "the nine endpoint sites themselves -- the four */Rpc.hs providers, both apps, deploy-rig.sh and the two capture scripts"
provides:
  - "Chain.Endpoint: resolve_endpoint, the pure endpoint_from rule, default_endpoint stated once, and the 15-entry endpoint_sites manifest with a SiteKind per entry"
  - "offchain/rig/endpoint.sh: the shell half of the one resolver -- default stated once, URL split into RPC_URL / RPC_HOST / RPC_PORT, loud on an unparseable endpoint"
  - "all nine listed sites plus verify-rig.sh rewired: none holds the default, every one resolves"
  - "deploy-rig.sh binds anvil's --host/--port and every --rpc-url to one reading of one variable, and asserts cast chain-id BEFORE the first --broadcast"
  - "four checks in core_checks (194 -> 198), each OBSERVED rejecting its named input"
  - "the finding that verify-rig.sh is an ELEVENTH site CHAIN-06's list of nine does not contain"
affects: [27-02, 27-03, 28]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "A value that must exist in two languages is stated once per language and the two statements are asserted BYTE-EQUAL -- a duplication a check compares is a checked agreement"
    - "A census term set is anchored to what the census MEANS, not to the tokens that happened to find the current members: 'names the variable' is not 'reaches a chain'"
    - "A rule that must be tested at a value the process cannot install in its own environment is factored into a PURE function of that value, and the value's reachability is OBSERVED in a child process"
    - "Existence and ORDER are separate assertions over the same subject, so a deletion reddens even when no position has shifted"
    - "A scan restricted to non-comment lines is the ANCHORED form when the property is about binding, and it is what lets a MEASURED transcript stay in the file unredacted"
    - "A substring term is checked against the scanned set before it is trusted: 'cast call' is a prefix of 'cast calldata'"

key-files:
  created:
    - offchain/lib/Chain/Endpoint.hs
    - offchain/rig/endpoint.sh
  modified:
    - offchain/test/Main.hs
    - cfmm-replicationPlank-rpc-api.cabal
    - offchain/lib/PriceSetter/Rpc.hs
    - offchain/lib/VolOrder/Rpc.hs
    - offchain/lib/StochasticOrderGen/Rpc.hs
    - offchain/lib/StochasticPriceGen/Rpc.hs
    - offchain/app/Main.hs
    - offchain/app/CheatSwapProof.hs
    - offchain/rig/deploy-rig.sh
    - offchain/rig/verify-rig.sh
    - offchain/rig/capture-batch-return.sh
    - offchain/rig/capture-cheat-swap-proof.sh

decisions:
  - "offchain/spec/types.md and offchain/rig/README.md are DECLARED as Transcript sites rather than argued out of the census -- prose inside a grep's blast radius that the grep's list does not know about is how a scan gets narrowed on the day it first fires"
  - "offchain/test/Main.hs is itself a site, kind Census: it must NAME the resolver and must name NONE of chain_reaching_terms, which makes README's hand-run chain-independence grep executable"
  - "The census scans all of offchain/ with NO extension filter, unlike purge_scan and credential_scan, because those two are backed by an extension census and this one is not"
  - "The hardcode and names-the-resolver arms read non-comment lines only: a comment binds nothing, and it lets deploy-rig.sh's MEASURED Step-0b transcript stay unredacted"
  - "cast call was DROPPED from chain_reaching_terms: it matched CheatSwap/Encoding.hs's 'cast calldata' -- neither necessary nor sufficient, and the endpoint flag is the anchored form"

metrics:
  duration: ~2h
  tasks: 4
  completed: 2026-08-17
---

# Phase 27 Plan 01: One endpoint rule, producer included — Summary

CHAIN-06 and CHAIN-07 retired: one resolver in two languages with the two statements of the
default asserted byte-equal, a 15-entry site manifest closed in both directions, and the producer
binding anvil's host and port to the same reading of the same variable it asserts a chainId against
before its first broadcast — 198/198, exit 0, no chain required.

## What CHAIN-06 says, and what was actually there

The requirement reads as though nine sites each implement the rule and might drift. **MEASURED at
27-01: the rule was implemented ZERO times.** The only occurrence of `ETH_RPC_URL` anywhere under
`offchain/` was a *comment* in `deploy-rig.sh` explaining that the deploy scripts scrub it. All nine
executable sites wrote `http://127.0.0.1:8545` out as a literal and read no environment at all, so
the variable was accepted by every shell and honoured by nothing. There was no drift between N
copies to reconcile; there was one hardcoded constant, nine times.

## The census, re-counted as instructed

| Scope | Command | Count |
|---|---|---|
| `offchain/` | `git grep -l -e ETH_RPC_URL -e '127\.0\.0\.1:8545' -- offchain` | **10** |
| whole tracked tree | same, unscoped | **34** |

The 24 outside `offchain/` are 16 planning documents, 5 historical `docs/superpowers/` plans,
`foundry.toml`, `.github/workflows/develop-gate.yml` and `test/MarketStatisticsTest.t.sol` — none a
consumer, none this workstream's territory. The census is therefore scoped to `offchain/`, and that
scope is asserted rather than assumed.

**The tenth is `offchain/spec/types.md`, and the decision is written down:** it is DECLARED as a
`Transcript` site, not argued away. It is not a consumer and the resolver rule does not apply to it,
but it sits inside the census grep's blast radius, and a file inside a grep's radius that the grep's
list does not know about is how a scan gets narrowed on the day it first fires. `offchain/rig/README.md`
joined it for the same reason once the terms were anchored.

## Three plan errors, each found by measurement

### 1. `verify-rig.sh` is an ELEVENTH site, and CHAIN-06's list of nine cannot see it

`offchain/rig/verify-rig.sh` makes **fourteen `cast` calls against a live rig** and is not among the
nine. It reached the chain through foundry's `--rpc-url local` ALIAS — resolved by `foundry.toml:59`
to the hardcoded authority — so it named neither the variable nor the default, and **no pattern built
from those two tokens could ever have found it.** `ETH_RPC_URL=…:9545` sent SC-2 to 8545 while the
rig it verifies ran elsewhere: the CHAIN-06 defect exactly, in the file whose job is to say the rig
is what the manifest claims. `foundry.toml` is outside this workstream's territory, which is also why
the alias could not be *made* to honour the variable — binding through it would have pinned the
producer to 8545 no matter what the resolver returned.

`generate-pins.sh` was checked in the same sweep and is NOT a site: `cast sig` and `cast keccak` are
local hashing with no endpoint.

### 2. The plan's census pattern would have reported the fix as a regression

MEASURED both ways. Under the plan's own pattern — "names the variable or the default authority" —
the scan found the original **10 before** the rewiring and only **8 after**, because five of the six
Haskell consumers stop naming either token the moment they name `resolve_endpoint` instead. That is
what the fix *is*. Check 2 as specified would have reported five correctly-fixed files as missing.

`endpoint_census_terms` closes over the variable, the authority, `resolve_endpoint`, the shell
resolver's path, and the two shapes of **reaching** a chain. The last pair is what found
`verify-rig.sh`, and the lesson is general: a grep must be anchored to what it MEANS.

### 3. `cast call` is a prefix of `cast calldata`

`chain_reaching_terms` initially carried `"cast call"` because `offchain/rig/README.md`'s hand-run
chain-independence grep names it. On its first run it **matched `offchain/lib/CheatSwap/Encoding.hs`**,
whose haddock says the calldata is built by shelling to `cast calldata` — a purely local ABI format
with no endpoint. This is the 26-03 shape (`"828040"` contains `"82804"`) in mirror. Dropped: it is
neither necessary nor sufficient, since a `cast` invocation that reaches a chain must name an
endpoint flag and the local ones never do. **README's grep carries the same latent bug** and has
simply never met a file that says `cast calldata`.

## The check that was vacuous, caught by its own mutation

`an_empty_eth_rpc_url_does_not_resolve_to_the_empty_string` was written against the environment:
set the variable to `""`, assert the default comes back. Driven against a **deliberately unguarded
resolver it MEASURED GREEN — TEST_EXIT=0, the mutation was not caught.**

The cause is in base, not in the resolver. `System.Environment.setEnv k ""` routes an empty value to
`unsetEnv`. OBSERVED directly:

```
setEnv "PROBE_VAR" ""  >> lookupEnv "PROBE_VAR"   ==>  Nothing
setEnv "PROBE_VAR" "x" >> lookupEnv "PROBE_VAR"   ==>  Just "x"
```

So the check was driving the UNSET path twice while reporting on the empty one — an assertion passing
because its subject is absent, *inside the guard written against exactly that*. Meanwhile a shell
reaches the state easily: `export VAR=` leaves the variable present and empty, and `printenv` exits 0
on it.

Repaired by factoring the rule into a pure `endpoint_from :: Maybe String -> String`, drivable at
`Just ""`, with the premise OBSERVED in a child `/bin/sh` rather than assumed. Re-run, the mutation
fires.

## Firing observations

Every input below was applied to a **fresh baseline taken this task**, verified by `sha256sum` on both
sides, restored from that same baseline, and the restored digest re-checked. All five `.base` files
were deleted at plan close; none outlives the task.

| # | Input | Check that fired | Observed |
|---|---|---|---|
| 1 | hardcode the default back into `PriceSetter/Rpc.hs` | check 1, hardcode arm | names that file, "1 code line(s)", exit 1 |
| 2 | drop `verify-rig.sh` from `endpoint_sites` | check 2, `unlisted` arm | "ON DISK, NOT IN THE MANIFEST: offchain/rig/verify-rig.sh" |
| 3a | list a path that is not on disk | check 2, `phantom` arm | "…is NOT ON DISK" |
| 3b | list `Fee/Split.hs`, on disk, touching no endpoint | check 2, `phantom` arm | "IS on disk but matches no census term" |
| 4 | state the default twice in the resolver | check 1, positive control | "2 code line(s)" |
| 5 | a shell consumer stops sourcing the resolver | check 1, does-not-resolve arm | named; it holds no literal, so only this arm can see it |
| 6 | the rule unguarded at `Just ""` | check 3 | fired **after** repair; green before it |
| 7 | move the chainId assertion below the first broadcast | check 4, order arm | "code line 181 … FIRST --broadcast at code line 163" |
| 8 | delete the chainId assertion entirely | check 4, existence arm | fires; the order arm does not |
| 9 | drop `--host`/`--port` from the anvil invocation | check 4, binding arm | "starts anvil without --host and --port" |
| 10 | change `endpoint.sh`'s default by ONE character | check 4 byte-equality **and** check 1's positive control, independently | both named it |
| 11 | rename the shell default variable | check 4, `Nothing` arm | names WHICH failure it is rather than reporting disagreement |

7 and 8 together are the point of splitting existence from order: **neither arm alone catches both
mutations.** That is 26-03's finding, where an ordering gate written only as line numbers was
structurally voided by 26-04's refactor while staying green.

## `endpoint.sh` observed directly

It is executable code `cabal test` cannot run, so it was driven on eight inputs with no anvil:

| Input | Result |
|---|---|
| unset | exit 0, default, `HOST=127.0.0.1 PORT=8545` |
| exported EMPTY | exit 0, **default** — the shell reaches the state `setEnv` cannot |
| `…:9545` (issue #29) | exit 0, `PORT=9545` |
| `https://node.example.org:8545` | exit 0, `HOST=node.example.org` |
| `http://10.0.0.5:7545/rpc` | exit 0, path stripped, `PORT=7545` |
| `http://127.0.0.1` (no port) | **exit 1**, names the parsed port `'127.0.0.1'` |
| `…:0` | **exit 1**, "outside 1-65535" |
| `not-a-url` | **exit 1**, names the value |

The empty-export row is the shell-side confirmation of exactly what `endpoint_from (Just "")` asserts
on the Haskell side.

## Ordering decisions in the producer

`endpoint.sh` is sourced **above** the `--stop` branch, which `deploy-rig.sh` otherwise treats as a
red flag — its Step-0b block narrates two gates that sat there and leaked anvil. The rule that block
draws is specific: *a precondition of DEPLOYING must not stand between a teardown and the process it
exists to kill.* This is not one. `--stop` kills the listener BY PORT and cannot run without
`RPC_PORT`, so it is the same class as the toolchain preflight, already placed above `--stop` for
that reason. A malformed `ETH_RPC_URL` therefore fails the teardown, which is correct: a teardown
that does not know which port it owns must not pick one.

The `ETH_` ambient scrub survives unchanged and is now load-bearing in a second way: the rig reads the
variable ONCE and hands children the resolved URL on the command line, so leaving the raw variable in
their environment would give forge and cast a *second, independent reading* — two readings of one
variable being precisely how a producer and its consumers diverge.

## Measurements

| | Value |
|---|---|
| `cabal build --enable-tests -j all` | exit **0**, **0** warnings, **0** `Downloading` (+0 packages, CONFIRMED) |
| `cabal test` | exit **0**, **198/198**, 0 FAIL lines |
| Baseline before the plan | 194/194, exit 0, 0 warnings |
| Delta | **BASE + 4**, as planned |
| `purge_file_floor` | 67 → **69**, re-measured by RUNNING `find`, zero slack |
| `credential_scan_floor` | 77 → **79**, re-measured separately, zero slack |
| Census under `offchain/` | hs **55**, sh **11**, json **10**, sql **3** |
| gams tokens over `test/Main.hs` | **0** |
| ungated-renderer token over `test/Main.hs` | **0** |
| README's three chain tokens over `test/Main.hs` | **0** |
| `git status --porcelain src test foundry-scripts Makefile foundry.toml .github` | empty |
| NUL bytes in any touched file | none (`wc -c` == `tr -d '\000' \| wc -c`) |

Both floors move by exactly two, where 26-04 moved them by two and three: this plan commits no
artifact, so the `.json` census is unchanged at 10 and the only new files are one `.hs` and one `.sh`.
Prediction and measurement agree; both ends were run.

## Commits

| Task | SHA | Subject |
|---|---|---|
| 1 | `e067e31` | the one endpoint rule, in two languages and a manifest |
| 2 | `4bf504b` | every site resolves, and the census that found the eleventh |
| 3 | `36bc427` | the producer binds it, and the chainId is asserted before any send |

Task 4 was the gate; its measurements are in the table above and in `36bc427`'s message.

## Carried forward

- **CHAIN-06's text says "nine sites".** It is **ten** by its own pattern and **eleven** counting
  `verify-rig.sh`, which its pattern cannot see. Correct the requirement text at phase close, in the
  same pass that fixes CHAIN-01's stale `next`-event wording (27-CONTEXT.md).
- **`offchain/rig/README.md`'s chain-independence grep carries the `cast call` / `cast calldata`
  prefix bug.** Harmless today because no scanned file says `cast calldata`, and the executable form
  in `chain_reaching_terms` no longer has it. Worth fixing the prose when README is next touched.
- **`foundry.toml:59` still defines `local = "http://127.0.0.1:8545"`.** Nothing in the rig uses the
  alias any more, but it is a third statement of the default that this workstream cannot edit and no
  check can reach. If the territory rule ever relaxes, delete it.
- **`endpoint.sh` is not exercised by `cabal test`** — it is bash. Its behaviour is recorded above
  from a direct run. A future plan wanting it under the gate would need a shell-driving check, which
  is a Tier decision this plan did not make.

## Self-Check: PASSED

All 15 claimed files present on disk; all 3 commit SHAs resolve; all 4 checks registered in
`core_checks` exactly once each; `endpoint_sites` holds 15 entries as claimed.
