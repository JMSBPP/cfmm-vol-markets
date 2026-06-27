# cfmm-replicationPlank

Open-loop **plumbing** that carries a parameter set from a (stub) GAMS algebraic
model, through a defined fixed-point encoding contract, into a compiled **Plank**
(custom EVM language) write/read surface, and back out via a round-trip equality
check — both tracks bound to one authoritative type kernel.

> Status: early research repo. Most `.plk` sources are stubs or have parse/type
> errors, the Plank<->GAMS bridge is a work in progress, and the GAMS solver is a
> deliberate stub this milestone. This milestone proves the connection layer
> *carries parameters correctly* — it does not yet prove payoff replication.

## Two-track architecture

- **Plank track** (`src/*.plk`): on-chain CFMM logic compiled to EVM bytecode via
  the Plank FFI deployer (`lib/plank-foundry-deployer`), exercised from Foundry tests.
- **GAMS track** (`model/`): the algebraic model that (eventually) solves for optimal
  curve/fee parameters; a stub objective this milestone.
- **Bridge**: GAMS output -> fixed-point encode -> `IMarketDynamics.initVolTermStructure()`
  -> read back through lens views -> round-trip equality. The shared semantics live in
  `spec/entities/Types.md`.

## Prerequisites

- Foundry (forge 1.5.1+): `curl -L https://foundry.paradigm.xyz | bash && foundryup`
- Plank v0.1.1: `curl -L install.plankevm.org | bash && plankup` (backend `sona`)
- GAMS 54+ (for the `model/` track)
- An RPC key in `.env` as `API_KEY` for fork tests (tests fall back to local chain)

## Build & test

```bash
git submodule update --init --recursive
make build-pool        # compile the core Plank contract
forge test -vvv        # run the Foundry/Plank test suite (requires ffi = true)
```

See `Makefile` for the individual Plank build targets and `.planning/ROADMAP.md`
for the phased plumbing milestone.

## License

MIT — see `LICENSE`.
