# Toolchain pins

Binding. The values live in `.github/foundry-version`; this file is the reason they are
those values and the procedure for changing them.

## 1. Foundry — `v1.5.1` / `b0a9dd9ceda36f63e2326ce530c10e6916f4b8a2`

CI does not use "whatever `forge` is on the box". Both workflows install the pinned release,
put it on `PATH`, then assert `forge --version` contains `b0a9dd9...` and fail the run if it
does not.

This matters more here than in a normal repo for one structural reason: **the `cfmm-build`
runner is persistent, not a fresh container.** Its `forge` survives between runs, so a single
`foundryup` typed on that box by anyone, ever, silently redefines what every subsequent gate
run measures — retroactively invalidating conclusions already recorded as evidence, with no
diff to point at. A pin turns that from an invisible event into a red run.

## 2. What is measured at this commit, and would have to be re-measured

Recorded findings, not preferences. Each was measured on `forge 1.5.1-stable` `b0a9dd9` and
each is load-bearing for the Haskell-Plank differential milestone.

1. **`vm.rpc` result coercion is value-dependent.** The same JSON record decodes to different
   ABI types by number *magnitude*: `tokenId "0"` gives `tuple(string,string,string)`;
   `tokenId "18446744073709551616"` gives `tuple(string,string,uint256)`. A fuzz campaign hits
   both, so a decoder correct for one is intermittently wrong for the other — and would
   present as a Plank divergence. This is the finding that forces the "one even-length
   `0x`-hex string with a tag byte" wire design.
2. **`vm.rpc` return encoding.** `bytes memory b = vm.rpc(...)` is unsafe: static-coerced
   results give a bare un-messaged `EvmError: Revert`, and object results silently return
   garbage with `b.length == 96`. Explicitly version-dependent — Foundry master encodes
   returns differently from 1.5.1.
3. **`[rpc_endpoints]` `${...}` resolves lazily, at alias *use*.** With the variable unset,
   `forge build` exits 0 and `forge config` stores the literal `"${EVM_SPEC_BRIDGE_URL}"`;
   only a test that uses the alias fails, with a self-describing message, and the failure does
   not spread across suites. Every "the alias is safe to add before anything can answer on it"
   conclusion rests on this. Measured on 1.5.1-stable only.
4. **Whether `try`/`catch` catches a cheatcode revert** — still OPEN, and any measurement of
   it is a claim about this binary and no other (`try`/`catch` does an `extcodesize` check
   against the cheatcode address).

Related, same binary: a server that accepts a connection and never answers costs **45.00 s per
call and the test PASSED**, because the call site ignored `success`. That is the founding
failure mode of the transport work. `vm.rpc`'s retry and timeout constants are hardcoded in
the binary (`max_retry` 8, `initial_backoff` 800 ms, `REQUEST_TIMEOUT` 45 s) and unreachable
from config, so they are a property of the pinned version rather than of any setting.

## 3. Why not v1.8.0

`vm.rpcJson` (merged 2026-06-05, PR #15076) ships only in v1.8.0, published **2026-08-27** —
the same day this pin was written. Adopting a same-day release to obtain one convenience
cheatcode, in exchange for re-measuring all four findings above against an encoding that is
*known* to have changed, is not a trade this project makes. `vm.rpc` is sufficient.

A standing rule that produced this note: **Foundry docs track `master`, not the shipped
binary.** A researcher recommended `vm.rpcJson` at high confidence from real documentation,
for a cheatcode absent from every binary anyone here runs. Only `cheatcodes.json` at a release
tag is a claim about what ships.

## 4. Why the installer is pinned too

`.github/foundry-version` also pins `FOUNDRYUP_INSTALLER_COMMIT`. Fetching `foundryup-init.sh`
from a moving branch would leave the toolchain's *installer* unpinned, which makes the
toolchain pin conditional on a third party's default branch. The pinned commit is the same one
`foundry-rs/foundry-toolchain@v1` pins in its own `src/index.ts`.

## 5. Where CI installs it, and why not `~/.foundry`

Both workflows install into `$HOME/.foundry-pins/$FOUNDRY_VERSION` and prepend that `bin` to
the job's `PATH`. They deliberately do NOT install into `$HOME/.foundry`, which is where a
bare `foundryup` — and where `foundry-rs/foundry-toolchain@v1`, whose `src/index.ts` sets
`FOUNDRY_DIR = path.join(os.homedir(), ".foundry")` — would put it. On a persistent runner
that shared directory IS the box's default `forge`, so installing there would have CI rewrite
the machine for every other job and every human on it. A per-pin directory cannot collide,
and `$GITHUB_PATH` is prepended, so the pinned binary wins for the job and nothing outside the
job is mutated.

## 6. Changing the pin

1. Edit `.github/foundry-version`. That diff is the change; there is no other place to edit.
2. Re-measure every finding in section 2 against the new binary and update this file with the
   new results. A bump whose PR does not touch section 2 has not been reviewed, only merged.
3. Expect the coercion-conformance fixture (assigned to Phase 5, RPC-03) to go red with a
   named cause. That is the third drift layer working:
   **the pin prevents, the version stamp reveals, the fixture fails.**
   Turning any of the three off is how a green run comes to mean nothing.
