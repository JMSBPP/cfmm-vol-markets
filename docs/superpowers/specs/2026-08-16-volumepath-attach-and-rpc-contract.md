# VolumePath Test — Attach-to-Live-Anvil + Endpoint-Resolution Contract

**Date:** 2026-08-16
**Issue:** #29 (raised from the rpc_api side; related #24 test, #25 bridge, #26 routing, #28 event)
**Milestone:** v6.0 (mev_tax_model_one on-chain VolumePath execution), Phase 24 vicinity
**Status:** Design spec — heavy-intervention (every change under direct user approval).
**Owns:** `foundry.toml` + `test/models/mev_tax_model_one/AlgebraIntegralMevTaxModelOneShocks.t.sol`.
**Hands to rpc_api:** the fixture pool-identity shape and the endpoint-resolution contract (its 6
`offchain/` sites + 2 rig scripts).

---

## 1. The collision this fixes

`test__priceInvarianceUnderVolumePath` runs entirely in the **in-process** EVM: `_createPool()` deploys
two fresh `MockERC20`s and calls `shocks_writer.init()`, which deterministically lands at
`SQRT_PRICE_1_1 = 2^96` / `UNIT_LIQUIDITY = 2^64`. It then asserts the fixture agrees (line 163). That
passes **only because** today's `volume_path.json` carries the genesis-state self-test defaults. The
moment rpc_api's bridge describes a *live* pool whose price has moved, line 163 hard-fails — the test
reddens exactly when the pipeline starts working.

**The test constructs its subject; the bridge observes one.** The fix is to make them the same pool:
the test must **attach** to the live pool the fixture was solved against, not construct a new one — and
it must **fail loud** if the live node is absent, never silently fall back to in-process (the defect
class this repo has been burned by seven times across PR #9 review rounds).

Line 163 is **correct** and stays; we make the two pools identical, not loosen the check.

## 2. Endpoint-resolution contract (all consumers)

One full-URL env var, one order, identical in every language:

```
resolve() = ETH_RPC_URL (env, wins if set)  ->  else  "http://127.0.0.1:8545"  (loud default)
```

- `ETH_RPC_URL` is foundry's native variable, so `forge`/`cast --rpc-url` honor it for free.
- **forge test (Solidity):** `vm.envOr("ETH_RPC_URL", "http://127.0.0.1:8545")`
- **shell (rig):** `"${ETH_RPC_URL:-http://127.0.0.1:8545}"`
- **Haskell (providers):** `fromMaybe "http://127.0.0.1:8545" <$> lookupEnv "ETH_RPC_URL"`
- **`foundry.toml`:** `local = "http://127.0.0.1:8545"` is the **single source** for the default; the
  test resolves `vm.envOr("ETH_RPC_URL", vm.rpcUrl("local"))`, so the literal is never duplicated in
  Solidity. A port change edits `foundry.toml` alone.

**Producer must bind the same endpoint (critical — else the desync returns).** The resolver above is
for *consumers* (reads). The *producer* — `deploy-rig.sh` launching `anvil` and broadcasting the pool
deploy — must derive anvil's `--host`/`--port` **and** its deploy `--rpc-url` from the **same**
`ETH_RPC_URL` (parse host/port from the URL; default `127.0.0.1:8545`). Otherwise `ETH_RPC_URL=…:9545`
brings anvil up on 8545 while the test attaches to 9545 — the exact `RPC_PORT` desync #29 rejected,
reintroduced. Binding producer and consumer to one source is what actually retires the divergence;
the two-token consumer resolver alone does not.

This retires the "10 hardcoded `127.0.0.1:8545` sites" divergence: every site becomes the same
resolver, producer and consumer. rpc_api owns the six `offchain/` sites + `deploy-rig.sh`/`capture-*.sh`
(including the anvil-bind derivation and a **`chainid` guard before `--broadcast`**, mirroring the
test); this repo owns `foundry.toml` + `test/`. No `RPC_PORT` knob (a port knob on the deploy script
alone desyncs consumers — already correctly refused on the rpc_api side).

## 3. Fixture shape (rpc_api emits; test consumes)

`volume_path.json` gains three pool-identity fields (existing fields unchanged):

| Field | Type (JSON) | Purpose |
|---|---|---|
| `pool` | string (address) | the pool to **attach** to |
| `blockNumber` | string (uint) | pin the fork to the block the path was solved at |
| `chainId` | number (uint) | wrong-network guard |
| *(existing)* `sqrtPriceX96`, `liquidity` | string (uint) | solved-for state — the determinism check |
| *(existing)* `dQx`, `nEvents` | int[] / uint | the swap path |

`token0`/`token1` are **not** in the fixture — the test reads them from the attached pool
(`IAlgebraPoolImmutables(pool).token0()/token1()`), keeping the pool the single source of truth.
Big-integer fields stay **JSON strings** (VOLUME_PATH.md §3): `sqrtPriceX96`, `liquidity`,
`blockNumber` exceed the 53-bit double-exact ceiling — parse as strings, never as JSON numbers.

## 4. Attach protocol (the test change)

A new `_attachPool()` replaces `_createPool()` **only** on the VolumePath path; the in-process
`_createPool()` stays for the unit tests (`pluginConfig`, `beforeSwap`) that legitimately construct.

```
_attachPool(fxPool, fxBlockNumber, fxChainId):
    string url = vm.envOr("ETH_RPC_URL", vm.rpcUrl("local"))  // env -> foundry.toml default (single source)
    console2.log("VolumePath: attaching to", url)            // endpoint named before we try
    vm.createSelectFork(url, fxBlockNumber)                  // THE liveness guard: reverts loud
                                                             //   (endpoint in the message) if unreachable
    require(block.chainid == fxChainId, "wrong chain")       // wrong-network guard (genuine node read)
    require(fxPool.code.length > 0, "pool not deployed on fork")  // ATTACH, not construct
    activePool = fxPool
    token0 = IAlgebraPoolImmutables(activePool).token0()     // pool = source of truth
    token1 = IAlgebraPoolImmutables(activePool).token1()
    // line 163 stays: assert pool sqrtPrice/liquidity == fixture (now a determinism guard)
```

The earlier draft's `vm.activeFork()` sentinel and `block.number == fxBlockNumber` checks were removed:
`activeFork()` *reverts* when no fork is active (so it cannot be sentinel-compared), and `block.number`
is pinned to `fxBlockNumber` by `createSelectFork` construction — both are vacuous as liveness guards
(verified empirically). The single real guarantee is `createSelectFork` reverting; `chainid` is the
only non-vacuous on-chain cross-check.

The swap **replay** through the writer's `SELECTOR_NEXT` + tick-closure assertion remains **#26** — this
spec delivers the attach + liveness scaffolding the replay runs on, not the replay itself.

**setUp interaction (implementation note):** `setUp()` currently FFI-deploys the writer + factory
in-process unconditionally. Under attach, `createSelectFork` switches away and those artifacts are
orphaned (harmless, but the FFI deploy is slow). The attach test tolerates this; a follow-up may gate
the in-process deploy on fixture-absence. Not required for #29.

## 5. Fork-liveness guard — fail loud, never fall back

The single defect this issue exists to prevent: **a test that silently runs in-process when Anvil is
absent passes while testing nothing.**

**Skip policy (asymmetric, deliberate):**
- Fixture **absent** → `vm.skip(true, "...")`. The bridge isn't wired yet; skipping is honest.
- Fixture **present** but node unreachable → **HARD FAIL**, endpoint named. A present fixture means
  rpc_api produced it against a live node, so the node must be up. `createSelectFork` on a dead RPC
  reverts (the loud failure); the `console2.log` above already named the endpoint.

Never the reverse — a present fixture must never degrade to a skip or an in-process run.

**Liveness is `createSelectFork` reverting** (verified: connection-refused reverts in ~30ms with the
endpoint in the message), backed by the `chainid` cross-check. This is *one* real guard, not three —
the `activeFork`/`block.number` "belt and suspenders" of the first draft were vacuous and were removed.
A guard never observed rejecting is, by this project's standard, absent — so it is **observed firing**
(§6.2). Caveat: a *blackholed* endpoint (TCP accepts, never answers) fails *slow* (provider timeout),
not in 30ms; "loud" is guaranteed, sub-second is not.

## 6. Verification

1. **Compilation + skip path (CI-safe, now):** with no `volume_path.json`, the suite compiles and
   `test__priceInvarianceUnderVolumePath` skips; the other tests are unaffected.
2. **Guard observed firing — DONE (Anvil-down half):** with a **complete** throwaway fixture (so the
   first failure point is `createSelectFork`, not a missing field) and Anvil not running, the test
   **FAILS loud** — `[FAIL: vm.createSelectFork: ... url (http://127.0.0.1:8545/); Connection refused]`
   plus the `console2` log `VolumePath: attaching to http://127.0.0.1:8545`. It does **not** skip. The
   throwaway fixture is then removed and the suite returns to the skip path (3 pass, 1 skip). The
   fixture-present + node-down → hard-fail contract is thus observed, not claimed. (The earlier "any
   pool" recipe was wrong: a random address fails the `code.length > 0` check even when the node is up,
   so it can't isolate node-down; a complete fixture with the node down does.)
3. **Happy-path attach E2E (deferred to rpc_api's rig):** proving a real solved pool replays to tick
   closure needs a pool already deployed + driven on Anvil (the rig's job, #25) — the node-UP half
   can't be greened here without it. Standing up a throwaway mini-rig purely to green this now is the
   over-build the issue warns against; deferred and flagged, not silently skipped.

## 7. rpc_api handoff (comment on #29)

After this lands, comment on #29 with: (a) the fixture additions in §3 (exact keys/types), (b) the
`ETH_RPC_URL → default` resolver in §2 for the six `offchain/` sites + `deploy-rig.sh`/`capture-*.sh`,
(c) the string-encoding rule for `blockNumber`. rpc_api implements its side against this contract.

## 8. Open / deferred

- **Swap replay + tick-closure** — #26 (`SELECTOR_NEXT` routing + writer callback), not #29.
- **Happy-path attach E2E** — deferred to rpc_api's rig (§6.3).
- **setUp in-process deploy under attach** — orphaned-but-harmless; optional follow-up (§4).
- **Multi-pool fixtures** — one pool per fixture for now; array shape is a later contract revision.

---

*Spec written 2026-08-16 (issue #29). Feeds an implementation plan: endpoint resolver + attach helper +
liveness guard in the test, `foundry.toml` note, then the #29 handoff comment. Replay stays #26.*
