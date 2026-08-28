# Harness ABI edge — PRE-refactor reference (plan 02-02)

- **Harness:** `test/protocol_integrations/VolOrderToPanopticTokenIdHarness.plk` at `f626408`
  (byte-identical to `origin/develop`: `git diff origin/develop -- <harness> src/types/pos_spec/VolOrder.plk | wc -c` → 0)
- **Toolchain:** plank `00c0a1aa3cb40b63de81c6ca4f92bec392b423c3`, forge `1.5.1` / `b0a9dd9ceda36f63e2326ce530c10e6916f4b8a2` (from the run log)
- **Run:** push-build `33169215017` (https://github.com/JMSBPP/cfmm-vol-markets/actions/runs/33169215017), job `98841958358`, step "Harness ABI edge stamp" = success
- **Same-push gate:** develop-gate `33169217185` success, `Ran 75 test suites … 273 tests passed, 0 failed, 3 skipped (276 total tests)` — the stamp step changed nothing the gate measures
- **Harvested:** 2026-08-28

## Stamp (quoted from the log)
```
abi-edge sha256: e801b0e1dea74b1316ce8991663c914da64b31ab359127c67f56a788689077d9
abi-edge selector: 0x08c379a0
abi-edge selector: 0x4e487b71
abi-edge selector: 0x728ebb96
abi-edge selector: 0xa00af595
abi-edge selector: 0xed7143d4
abi-edge selector: 0xfe7ebf55
abi-edge selector: 0xffffffff
abi-edge selector-count: 7
```

## What plan 02-04 must show
- `abi-edge selector:` line set IDENTICAL (sorted set equality, all 7) — the frozen surface.
- `abi-edge sha256:` identical → bytecode-identical (strongest); different → internals moved,
  surface did not; recorded either way, never hidden.
- The four dispatch selectors present: `0xfe7ebf55` `0xa00af595` `0xed7143d4` `0x728ebb96`.

## Anomalies
- Three PUSH4 immediates beyond the four dispatch selectors, all expected compiler artifacts and
  all part of the frozen set: `0x08c379a0` = `Error(string)` revert selector, `0x4e487b71` =
  `Panic(uint256)` revert selector, `0xffffffff` = a 32-bit mask constant. None is a callable entry.
- The push-build suite line reads `75 suites / 273 / 0 / 3`, equal to 02-01's gate counts — the
  push build and the gate agree on the surface, as the ledger-parity script intends.
