# cfmm-vol-markets — agent guide

The on-chain protocol core for typed volatility markets. The build is **Foundry + the
Plank toolchain** — there is no Hardhat step (the Hardhat sample scaffold was removed).

## Project layout

```
src/              Plank (*.plk) + Solidity (*.sol) protocol sources
test/             Foundry tests (*.t.sol)
foundry-scripts/  Foundry scripts (forge script)
lib/              submodule dependencies (forge-std, panoptic-v2-core, plank-monorepo, …)
spec/ offchain/ refs/   canonical-repo submodules (see README "Repository split")
notes/            binding spec docs (DATA_CONTRACT.md, UNITS_AND_SCALES.md)
.planning/        GSD planning tree
```

## Working in this project

- **Build/test:** `make plank-toolchain` (build the Plank compiler from the pinned
  `lib/plank-monorepo`), `make compile-plank` (compile Plank entrypoints), and
  `forge test --via-ir --offline` (Foundry suite). `npm ci --ignore-scripts` is required —
  it installs the `@cryptoalgebra/*` Solidity sources that `remappings.txt` maps into
  `node_modules/` (a hard forge dependency, not a Hardhat/JS runtime).
- **The `notes/` docs are binding spec** (`DATA_CONTRACT.md`, `UNITS_AND_SCALES.md`) and are
  cited from `src/*.plk` comments — treat their notation as authoritative.
- **`develop-gate`** (`.github/workflows/develop-gate.yml`) is the sole required check on
  `develop`: environment approval → `forge` + `plank` jobs on a self-hosted runner. It — not a
  local run of the commands above — is what decides whether work is good (see Contributing).

## Contributing / workflow

**New work GitHub flow (set 2026-09-06).** When adding something new (type, feature, or fix
track), do **not** start inline on `develop`. Follow this sequence:

1. Create a tracking issue titled for the work (e.g. `type/Foo`). Empty body is fine.
2. Create a branch and worktree of that name from latest `origin/develop`:
   `git worktree add -b <name> .worktrees/<name-with-slashes-as-hyphens> origin/develop`.
3. Open a PR into `develop` whose body cites the issue number (`#N`).

Do the implementation in that worktree until the PR merges. The main checkout stays on
`develop` for everything else.

*Standing exception, Phase 2.5 only (set 2026-08-28):* the maintainer reinstated a worktree for
`feat/volmarketkey`, which runs in `../vol-markets-volmarketkey`. It is **phase-scoped** —
recorded here because a session that hears about 2.5's worktree second-hand would otherwise
misread placement (sibling dir vs `.worktrees/`).

*Standing exception, vol-position track (set 2026-09-01):* `feat/vol-position` is a **persistent
integration branch**, not a one-shot phase branch. It owns the dedicated worktree
`../vol-markets-vol-position` (also linked under `.worktrees/feat-vol-position`). The branch
**stays** after its PR merges to `develop` — do not delete it locally or on origin, and do not
remove the worktree as teardown. Ongoing vol-position work continues on `feat/vol-position` in
that worktree; merge slices to `develop` via PR as usual.

*Canonical publish (set 2026-09-01):* fork `develop` syncs to `d2p-finance:main` via PR
(`prod.yml` gate). Vol-position track: `JMSBPP:feat/vol-position` → `d2p-finance:vol-position`
(`vol-position-gate.yml`). Never push directly to `d2p-finance/*`. See
`docs/superpowers/specs/2026-09-01-canonical-vol-position-publish-design.md`.

**Close the branch that did the merge.** A phase is not finished when its PR merges — it is
finished when the branch is retired. Remove the worktree (`git worktree remove …`), confirm the
branch is fully merged, then delete it locally **and on origin**. Never `git branch -D`: if
`-d` refuses, unmerged commits mean something did not reach `develop` — inspect and report. A
stale branch on a merged PR is a trap for the next phase. **Does not apply to
`feat/vol-position`** — see the standing exception above.

`d2p-finance/*` are the canonical/upstream repos; `JMSBPP/*` are the develop forks. **All
changes land on the `JMSBPP` fork and reach `d2p-finance` ONLY via pull request
(fork → upstream).** Never push directly to a `d2p-finance` canonical repo.

**CI is the validation gate, not your local machine.** Do NOT establish that work is correct by
compiling or running the suite locally. Push the branch and read the GitHub Actions
`develop-gate` result — the push is accepted only if `develop-gate` passes. Never report work
as verified on the basis of a local build.

**Do NOT run tests or builds locally.** Agents must not invoke `forge test`, `forge build`,
`make compile-plank`, `make plank-toolchain`, or equivalent validation commands on the
developer machine — not to verify a fix, not to reproduce a CI failure, not to "quickly check"
before push. Local runs are unreliable here (submodules, node deps, Plank toolchain) and are
explicitly out of scope. The workflow is: edit → push → monitor CI (`push-build` on the branch,
`develop-gate` on merge). Diagnose failures only from GitHub Actions logs (`gh run view --log-failed`).
Set 2026-08-31 after an agent ran `forge test` locally during LDF work.

**Code chunks are approved before they are committed.** Present every source chunk (a file's
diff, or one coherent hunk) to the maintainer in an `AskUserQuestion` block whose options are
**approve** / **modify**, wait for the answer, and only then `git commit`. Auto mode permitting an
edit is not the maintainer approving it; a plan step that says "commit and push" means
"show → approve → commit → push". Set 2026-08-28 after a refactor was committed unseen.

**Tests are written FIRST, RED, for any new type or behaviour.** "The existing suite still
passes" is regression evidence, not test-first. A phase that introduces a type constructor or a
new behaviour gets a harness + test file that exercises **every branch** of it before the
implementation is written, and the first push is red on purpose. Phase criteria must say
"compiles AND exercises every branch" — Plank only type-checks a comptime branch that something
instantiates, so an un-instantiated branch is text the compiler has never seen.

**Type development workflow (set 2026-09-06).** A new Plank type `Foo` is introduced with this
file layout (reference: `LegStep`):

1. `src/types/Foo.plk` — type module under the `types` Plank root.
2. `test/harness/types/FooHarness.plk` — Plank harness entrypoint (deployed via `deployPlank`).
3. `test/types/Foo.t.sol` — Foundry suite that imports `PlankTestBase` from
   `test/PlankTestBase.sol`, inherits it, and declares a Solidity harness ABI interface
   (e.g. `IFoo`, or a domain name such as `ILeg` for `LegStep`).

Existing rules still apply: tests first / RED before the type API is implemented; chunk
approve → commit → push → CI. Do not put new type harnesses under `test/types/` — that tree
holds the `.t.sol` suites (and older co-located harnesses); new harnesses go under
`test/harness/types/`.

## Docs

- Foundry — https://book.getfoundry.sh
- Plank / protocol spec — the `spec/` submodule (`d2p-finance/cfmm-vol-markets-spec`)

## [.spec](./spec/README.md)

For this implementation, new work uses the issue → worktree → PR flow above and is heavy on
`AskUserQuestion` for code chunk approvals.

## Development Approach

> type-implementer only AGENT

# PRE-REQUISITES
- File structure discussed and understood , minimal .spec/ ideally on .agda but .md and .mmd are tolerable
- justfile with minimal `just plank file` command that targes the compilation(with dependecies) of the files


- use Harness when testing files

All type design goes under a process of definition, exploration, labeling, test-driven-development
1. definition
   This is the mathematical representation fo the type
   
2. exploration
   This is exploration on how other types use it and make the output of this shape the labeling
3. labeling
   This is after exploration finding the best type category (dependent type, generic, others)
   We must consider the widest type definitions and discuss which one can fit which
4. test-driven-development
   Although the highest level development rule is type driven development once a type is defined
   we ewant to write .btt file with the exploration use cases other types do for them [SEE](https://www.getfoundry.sh/guides/branching-tree-technique)


for the type implementation, this is a heavy `AskUserQuestion` sessions on each
