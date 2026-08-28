---
phase: 02-volorder-t-minimal-instantiation
plan: 01
status: complete
completed: 2026-08-28
executor: superpowers inline (maintainer session) — per the phase EXECUTION GATE
requirements: [VORD-02]
duration: ~45 min wall-clock (two gate cycles + one maintainer decision)
---

# 02-01 — plank-monorepo pin bump, gate green on the unchanged suite

## Identifiers

| | |
|---|---|
| Tracking issue | **#61** |
| Branch | `feat/volorder-t-minimal` (inline, off `develop` tip `a623b97`) |
| Draft PR | **#62** — https://github.com/JMSBPP/cfmm-vol-markets/pull/62 |
| RUN_PRE (push-build, pre-bump tree `a623b97`) | `33167936025` |
| GATE_PRE | **does not exist** — see deviation 1; baseline = last green `develop` gate `33124709716` on `7a6b25f` |
| Bump commit | `8872eca` (pin + `.gitmodules` + 15 planned edits + TOOLCHAIN_PINS §7) |
| GATE_POST (RED) | `33168041777` on `8872eca` — forge 271/1, plank 36/2 |
| Fix commit | `5ccefd6` (`addr.raw` → `cast_addr`, 3 sites + 1 import) |
| PUSH_POST2 | `33168564429` — success |
| **GATE_POST2 (GREEN)** | **`33168567137`** on `5ccefd6` — all jobs success, `gate` check pass |
| Evidence | `02-01-GATE-EVIDENCE.md` (`bca07e2`) |
| Plan amendment | `a3aedb9` |

## Verdict

**GREEN ON UNCHANGED SUITE.** `Ran 75 test suites … 273 tests passed, 0 failed, 3 skipped (276 total tests)`,
floor `VolOrderToPanopticTokenId.t.sol` 10 tests ok, 3 identical `[SKIP` lines (both differentials
still on `spec oracle not wired`), `forge` `b0a9dd9`, `compile-plank: 38 ok, 0 failed, 0 skipped` with an
identical per-file entry set, 236 warning lines both sides. The compiler moved alone; VORD-02 has one variable.

## Pin-layout references read (constraint: enumerate, none names the SHA/branch)

`Makefile:258` (`--dep std=lib/plank-monorepo/std/`), `:275` (`PLANK_DEV_EXEC`), `:278` (`cargo build --release`
in `plankc/`); `develop-gate.yml:130`, `:168-170`; `push-build.yml:173`. All consume the gitlink.

## `--evm-version` contingency

**Not needed.** Osaka default emitted nothing forge 1.5.1 rejected.

## Deviations (both amended into the plan at `a3aedb9` BEFORE being relied on)

1. **Zero-diff draft PR refused** — `No commits between develop and feat/volorder-t-minimal` (measured).
   The PR was opened after the bump commit; `GATE_PRE` cannot exist. Baseline substituted with the last
   green `develop` gate, after proving `git diff 7a6b25f a623b97` outside `.planning/docs/notes/AGENTS/TODO`
   is empty.
2. **A 4th migration cost the planning census missed.** Upstream `addr` is now `struct { as_uint: u160 }`
   (was `{ raw: u256 }`). The census grepped import paths and `memptr`, not field reads on imported std
   types. Per plan the executor STOPPED on an unsanctioned red shape; sized it at 3 sites
   (`TickVolatilityLib.plk:26,54`, `VolOrderManagerMod.plk:38`); the maintainer chose **"amend the plan
   first"**; the fix uses upstream's own `cast_addr(x, u256)`. Lesson recorded in TOOLCHAIN_PINS §7.

## Measurements worth carrying forward

- **Cold `plankc` rebuild at a new pin: 52 s** (`33168041777` forge job, `11:40:45 → 11:41:37`), warm 1 s.
  Closes the Phase 1 open item on `timeout-minutes` headroom for the plank toolchain (25-min job budget).
- The `.gitconfig` "could not lock config file" lines are present in every run including green ones — runner noise.

## Untouched, proved

`git diff origin/develop` on `VolOrder.plk`, `PanopticTokenIdSetterLib.plk`, the harness, the floor test,
the differential, `SpecHelper.sol` and `.github/` → **0 bytes**. No dirty-list file was staged.
