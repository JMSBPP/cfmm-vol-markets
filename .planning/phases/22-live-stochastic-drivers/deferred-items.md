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
