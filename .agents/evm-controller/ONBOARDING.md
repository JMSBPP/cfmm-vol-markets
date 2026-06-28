# EVM-controller session — onboarding

You are the dedicated **EVM-controller** peer for `cfmm-replicationPlank`. Everything
you need to start is below. Read it top to bottom once before touching code.

## 0. Your identity & scope

- **Track:** the on-chain **EVM controller** component.
- **Branch:** `feat/evm-controller` (already on origin).
- **Worktree:** `../cfmm-wt/evm-controller` (this checkout). Never edit the main
  checkout or another peer's worktree.
- **Peer map:** registered in `scripts/peers.tsv` as
  `evm-controller  feat/evm-controller  no`.

**Scope boundary — read this, it prevents collisions.** This repo is worked by
several concurrent sessions split by domain (see `CLAUDE.md` → ownership map, and
the `claude-peers` MCP `list_peers` scope `repo`). The relevant neighbors:

| Owner | Owns | You must NOT touch |
|---|---|---|
| Plank session (`ul2inqpl`) | `src/*.plk`, `script/`, `foundry.toml`, `remappings.txt`, the on-chain bridge | the existing Plank `.plk` sources |
| Solidity-testing (PID 284909) | the whole `test/` suite | unit/fuzz/invariant/fork tests |
| GAMS (PID 175812) | `model/*.gms`, GDX | the GAMS model |
| Lean4+Math (PID 253818) | Lean proofs, `model/spec/*.md` | the math layer |
| GAMS↔Sol diff (PID 299098) | the differential bridge / `tools/gamsdiff` | the diff harness |

> ⚠️ **`src/` is currently 100% Plank (`.plk`) and owned by `ul2inqpl`.** Before you
> add the controller under `src/`, message `ul2inqpl` via `claude-peers send_message`
> to agree where the EVM-controller contract lives and how it links to the Plank
> output. Do NOT silently edit `foundry.toml` / `remappings.txt` — those are Plank's;
> request changes through `ul2inqpl`. Confirm your exact file layout with the human
> before writing production Solidity.

## 1. First commands (verify the checkout builds)

The worktree was created **without** auto-initializing submodules on purpose
(`forge`'s blind recursive init hangs forever on the `panoptic-helper` recursion).
Initialize the forge closure the **panoptic-safe** way:

```bash
cd ../cfmm-wt/evm-controller
git submodule update --init lib/panoptic-v2-core
git -C lib/panoptic-v2-core config submodule.lib/panoptic-helper.update none
git submodule update --init --recursive
```

Then build/test (note the **required** flags):

```bash
export API_KEY=<alchemy-key>          # UtilsTest forks mainnet via vm.rpcUrl("mainnet")
forge test --via-ir --offline         # --offline is MANDATORY: without it forge re-runs
                                      # recursive submodule init and hangs on panoptic
make compile-plank                    # if you depend on the Plank build output
```

If `forge test` ever hangs, you forgot `--offline` (or the panoptic config step).

## 2. How your work ships — PRs to `develop`

`develop` is the integration branch and is **gate-protected**. Workflow:

1. Branch your work onto `feat/evm-controller`, commit normally.
2. `git push origin feat/evm-controller`.
3. Open a PR **into `develop`** (`gh pr create --base develop --head feat/evm-controller`).
4. The **`develop-gate`** workflow runs on a self-hosted runner. It will sit in a
   `Waiting` state until the repo owner **approves the `develop-gate` deployment**
   (one human-in-the-loop click — that's the security barrier before your code runs
   on the build machine). Ping the owner when your PR is up so they approve.
5. The gate runs the **full suite** — forge tests, GAMS compile, Plank compile,
   gamsdiff pytest, Lean no-`sorry`. **Branch protection blocks the merge until the
   single `gate` check is green.** A red `gate` = fix and push again.
6. Keep PRs small and rebased on the latest `develop` (`git fetch origin && git
   merge --ff-only origin/develop`) so the gate stays fast on one runner.

Your contribution must keep the **whole** suite green, not just forge — a broken
`.gms`/`.plk`/pytest/Lean anywhere reds the gate and blocks everyone.

## 3. Coordination

- Set your peer summary on start: `claude-peers set_summary` → "EVM-controller track".
- Check `list_peers` (scope `repo`) before taking anything outside this track.
- Reply to incoming `claude-peers` messages immediately.
- For the `src/` layout / remappings / build-wiring questions above, your
  counterpart is the Plank owner `ul2inqpl`.

## 4. References in-repo

- `CLAUDE.md` — full multi-instance ownership map.
- `.github/workflows/develop-gate.yml` — the exact gate jobs you must pass.
- `docs/superpowers/specs/2026-06-28-develop-gate-design.md` — why the gate is shaped
  the way it is (incl. the panoptic submodule gotcha).
- `scripts/wt-setup.sh` / `scripts/peers.tsv` — the worktree-per-peer infra.
