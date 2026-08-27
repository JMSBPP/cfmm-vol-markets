# Deferred items — Phase 1 (RED Differential Scaffold)

Out-of-scope discoveries recorded rather than fixed, per the executor scope boundary.

## 1. RED-01 / RED-02 / RED-03 / RED-05 are satisfied but still `Pending` in REQUIREMENTS.md

Found during plan 01-04.

Plan 01-03 landed `test/protocol_integrations/VolOrderToPanopticTokenId.diff.t.sol` and its
SUMMARY records RED-01, RED-02, RED-03 and RED-05 as satisfied, CI-verified by push-build run
`33116421403` on `263f96d` (suite `273 passed / 0 failed / 3 skipped`). But 01-03 was executed via
the superpowers path, which does not touch `.planning/REQUIREMENTS.md`, so all four are still
`- [ ]` in the checklist and `Pending` in the traceability table.

NOT fixed here: plan 01-04 owns RED-06 only, and this executor does not tick requirements belonging
to another plan. **Owner: plan 01-05 or 01-06**, which should tick all four against run
`33116421403` (or the PR gate run, which is the stronger evidence for RED-01/RED-05 since criterion
1 and 2 of the phase are stated against `develop-gate`, not push-build).

## 2. The `.planning` position counter is phase-agnostic

`state advance-plan` maintains a single `current_plan` counter across Phase 1 and the inserted
Phase 1.1, so it cannot represent "Phase 1 at plan 4 of 6, Phase 1.1 complete at 6 of 6". Every
plan in this phase has therefore set STATE.md's position block by hand. Not a defect to fix in
this milestone; recorded so the hand-editing is not mistaken for drift.
