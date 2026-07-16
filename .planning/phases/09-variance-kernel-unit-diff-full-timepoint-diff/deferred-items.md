# Deferred items — Phase 9

## 09-02 Task 1 (NOT fixed — out of scope, pre-existing)

- `test/market_state_measurements/RealizedVolatilitySmoke.t.sol:164` — solc `Warning (2072):
  Unused local variable` for the first `_last()` read in
  `test__unit__timestampBelowWindowDoesNotInvertComparator`. **Pre-existing**, verified against
  HEAD (`TP memory t = _last();` was already unused before the TimepointDecoder extraction; the
  refactor only renamed its type). Not caused by this task's changes, so not touched. It is
  harmless (the test's real assertions are on `t2`), but the dead read could be deleted, or the
  test could assert on `t` to pin the pre-write avg_tick == spot == 2000 state the comment
  describes.
- `test/market_state_measurements/RealizedVolatilitySmoke.t.sol:4` — forge-lint `unused-import`
  for `console2`. Also pre-existing, also untouched.
