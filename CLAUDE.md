# CLAUDE.md — cfmm-replicationPlank

## Multi-instance ownership map

This repo is worked on by several concurrent Claude Code instances (see the
`claude-peers` MCP — `list_peers` scope `repo`). To avoid two instances editing
the same track, work is split by domain. Check `list_peers` before taking on a
track that another instance owns.

| Domain | Owner (session) | Scope |
|--------|-----------------|-------|
| **GAMS development** | **PID 175812** | Off-chain GAMS algebraic model only |
| **Lean4 + Math** | **PID 253818** | Lean4 proofs/utilities + the mathematical spec layer |
| **Plank development** | **agent `ul2inqpl`** (PID 278549) | Plank `.plk` compilation + Solidity/Foundry source + on-chain bridge |
| **Solidity testing** | **PID 284909** | Foundry test suite (`test/`) — unit, fuzz, invariant, fork tests |

### GAMS-development session = PID 175812

This session is dedicated **exclusively to GAMS work**. Its scope:

- Compilation — `make compile-gams` / `make clean-gams` (GAMS 54.1, `action=c`).
- GAMS model sources under `model/` (`.gms`), per `model/BUILD.md`.
- GAMS specs, GDX outputs, and the testing layer (assertions / `gdxdiff`).
- GAMS research + reference notes under `.agents/gams/`.

Out of scope for this session (owned by other instances): Plank `.plk`
compilation, Solidity/Foundry glue, the on-chain side of the bridge.

### Lean4 + Math session = PID 253818

This session is dedicated **exclusively to Lean4 and mathematics**. Its scope:

- Lean4 proofs, formalizations, and utility tactics/lemmas.
- The mathematical spec layer: `model/spec/*.md` (e.g. `primitives.md`,
  `pricingKernel.md`, `liquidityKernel.md`) — transcription and consistency of
  the math from `~/learning/cfmm-theory/KERNEL.md` against the GAMS sources.
- Math correctness review of derivations and notation (no GAMS compilation,
  no Solidity, no Plank).

Out of scope for this session (owned by other instances): GAMS compilation and
`.gms` source edits (GAMS-development session), Plank `.plk` / Solidity / Foundry.

### Plank development session = agent `ul2inqpl`

This session is dedicated **exclusively to Plank work**. Its scope:

- Plank `.plk` compilation and the Plank toolchain.
- Solidity / Foundry source: `src/`, `script/`, `foundry.toml`, `remappings.txt`.
- The on-chain side of the GAMS↔on-chain bridge.

> The Foundry **test suite** under `test/` is owned by the Solidity-testing
> session (PID 284909), not this session.

Out of scope for this session (owned by other instances): GAMS `.gms` source and
compilation (GAMS-development session), Lean4 proofs and the `model/spec/*.md`
math layer (Lean4 + Math session).

> Addressable identity: this is the `claude-peers` agent id `ul2inqpl` — use it as
> the `send_message` target for plank coordination. The PID (278549) is the
> current process and is **not stable across restarts**.

> The PID is the current process and is **not stable across restarts** — if this
> GAMS session is restarted, update the PID above (peer summary is set via
> `claude-peers` `set_summary`). The durable identity is the *role* (GAMS
> development), not the number.

### Solidity-testing session = PID 284909

This session is dedicated **exclusively to Solidity testing**. Its scope:

- The Foundry test suite under `test/`: unit, fuzz, invariant, and fork tests.
- Running and triaging tests (`forge test`, gas snapshots, coverage).
- Test-only fixtures, mocks, and harnesses that live under `test/`.

Out of scope for this session (owned by other instances): production Solidity
under `src/`, deploy `script/`, `foundry.toml` / `remappings.txt` and Plank
`.plk` (Plank development session, `ul2inqpl`); GAMS `.gms` and compilation
(GAMS-development session); Lean4 proofs and the `model/spec/*.md` math layer
(Lean4 + Math session).

> The PID (284909) is the current process and is **not stable across restarts**.
> The durable identity is the *role* (Solidity testing), not the number — if this
> session restarts, update the PID above and re-set the peer summary via
> `claude-peers` `set_summary`.
