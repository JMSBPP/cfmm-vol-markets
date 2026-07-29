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

## 09-02 state updates (NOT fixed — out of scope, pre-existing)

- `.planning/ROADMAP.md` v2.0 progress table (~line 277): the **Phase 8** row still reads
  `0/3 | Planned | -` even though Phase 8 is COMPLETE (all 3 plans landed summaries; STATE.md
  says so). Pre-existing staleness, not caused by 09-02; only the Phase 9 row was updated here
  (`2/2 | Complete`). Phase 8's row should be corrected to `3/3 | Complete` by whoever verifies
  Phase 8.
- `gsd-tools roadmap update-plan-progress 09` reports `"status": "Complete", "complete": true`
  but writes NOTHING to ROADMAP.md — it does not match this roadmap's
  `| 9. <name> | 0/TBD | Not started | - |` row format. The Phase 9 row was therefore updated by
  hand. Worth knowing for Phases 10-11: the command's success output does NOT imply the file
  changed. Verify with `git diff`.
- `gsd-tools state advance-plan` errors on this STATE.md with
  `Cannot parse Current Plan or Total Plans in Phase` — the prose format
  (`Plan: 1 of 2 in Phase 9 — ...`) is not what it expects. Frontmatter counters were still
  advanced by `update-progress`; the prose body was updated by hand.
