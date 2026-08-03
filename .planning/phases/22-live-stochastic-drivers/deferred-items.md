# Phase 22 — deferred items

Out-of-scope discoveries. Logged, NOT fixed. Each names the plan that found it.

---

## D22-1 — `RIG_PINS` is documented as an override the test suite does not honour

**Found during:** 22-03 Task 2, while fixing the `RIG_MANIFEST` analogue.

`offchain/test/Main.hs` still resolves the *pin* file through a hardcoded constant:

```haskell
pins_file :: FilePath
pins_file = "offchain/rig/rig-pins.json"
```

`Rig.Manifest.rig_pins_path` reads `RIG_PINS` and every `Rig.Manifest` error message tells the
reader to "Override the path with the RIG_PINS environment variable" — but no check in the suite
would notice, exactly as measured for `RIG_MANIFEST` in 22-03 (the suite went GREEN at 68/68
against a deliberately broken manifest supplied via the variable).

**Why not fixed here:** unlike `manifest_file`, `pins_file` is consumed inside PURE
message-building code at three sites (`Main.hs` ~239, ~696, ~1022), so lifting it to `IO FilePath`
is a wider refactor than the fault 22-03 measured. `rig-pins.json` is also COMMITTED, so a
falsification can mutate the real file and restore it by `git checkout` — which is how Phase 20
and 21 actually falsified the pin checks. The gap is a documentation/mechanism mismatch, not a
blind check.

**Fix when touched:** resolve `pins_file` through `Rig.Manifest.rig_pins_path` and thread the
resolved path into the message builders, or drop the `RIG_PINS` sentence from the messages the
suite emits.

---

## D22-2 — Phase 21's `batch-return-capture.json` still has no `generatedFrom`

**Found during:** 22-04 Task 2 (recorded as a DECISION, not an oversight).

Phase 21's F4 measured that `rpin05_capture_is_present_and_fresh` cannot see a module CHANGE: it
asserts `chainId` + `manager` only, and `manager` is a `CREATE` address, measured identical across
three from-scratch deploys. `generatedFrom` — the imported source-of-truth ref — is the field that
CAN see it.

22-04 closes that gap on the NEW artifact (`offchain/rig/cheat-swap-proof.json` writes
`generatedFrom` unconditionally, and `driv01_cheat_swap_proof_is_present_and_fresh` asserts it
against `rig-pins.json`'s own value). It deliberately does NOT re-capture
`offchain/rig/batch-return-capture.json` to add the field there.

**Why not fixed here:** re-taking that capture churns a committed artifact and its four checks for
a provenance field, on a plan whose subject is the cheat-swap composition. Recording the residual
gap explicitly is more honest than closing it on paper.

**Fix when touched:** add `generatedFrom` to `capture-batch-return.sh`'s `jq -n` emitter (read from
`offchain/rig/import-ref.txt`), re-take the capture, and extend
`rpin05_capture_is_present_and_fresh` to assert it — the same three lines
`driv01_cheat_swap_proof_is_present_and_fresh` already carries.

**Note on D22-1:** 22-04 fixed the *cheat-swap proof* half of the same family — `proof_file` is now
resolved through `RIG_CHEAT_SWAP_PROOF` rather than a constant, and the override was PROVEN
non-vacuous (pointed at a nonexistent path, all five `driv01_` proof checks redden). `pins_file`
remains a constant; D22-1 stands.
