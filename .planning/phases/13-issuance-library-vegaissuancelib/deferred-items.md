# Phase 13 — Deferred Items (out of scope, not fixed in-phase)

## 1. Untracked broken file breaks the whole `forge` build tree

- **File:** `src/modules/protocol_integrations/PriceSetterHook.sol` (UNTRACKED, created 2026-07-17T12:14 by a parallel track/peer — not part of the git baseline).
- **Symptom:** `import {PoolKey} from "";` — empty import path → `Error (6326): Import path cannot be empty.` fails `forge build`/`forge test` for the ENTIRE `src/` tree, including unrelated suites.
- **Discovered during:** 13-01 Task 3 (running `test/exposure/VegaIssuance.diff.t.sol`).
- **Why NOT fixed here:** out of scope — it is another track's untracked work-in-progress, not caused by this task's changes (SCOPE BOUNDARY rule). Deleting or editing it would clobber a peer's file.
- **Workaround used in 13-01:** ran the suite with `--skip 'src/modules/protocol_integrations/PriceSetterHook.sol'` (compilation-only route-around; no file modified). Since the offending file is untracked, it does not affect the committed 13-01 deliverables and will not reach CI. Once the owning track completes or removes it, `make test` / plain `forge test` will pick up `VegaIssuance.diff.t.sol` normally.
- **Owner:** the protocol-integrations / PriceSetterHook track.
