# CFMM protocol registry (resolve-only)

**Date:** 2026-09-06  
**Track:** `feat/cfmm-protocol-registry` (#112)  
**Status:** approved design sketch

## Goal

Minimal **versioned** registry whose **protocol → factory/entry addresses are hardcoded in bytecode** (enum-keyed). Adding a protocol = **deploy a new registry** with one more `(protocol, address)` pair; **consumers switch** the registry address they call.

Single API:

```text
getPool(protocol: CFMMProtocol, pair: Pair) → Pool(PoolUninitialized)
```

**Resolve only** — return an uninitialized handle (pool address / pool id + protocol). No fee / tickSpacing / slot0 hydration in this call. Hydration (`PoolUninitialized` → `PoolInitialized`) is a later step.

## On-chain shape (Solidity)

```solidity
enum CFMMProtocol {
    UniswapV3,
    UniswapV4,
    Camelot,
    QuickSwap
    // append-only across registry versions
}

/// One deployment = frozen bytecode table.
contract CFMMProtocolRegistry {
    // immutables / constants per enum member (factory or entry)
    // ...

    /// @notice Resolve pool handle for (protocol, pair). Does not hydrate.
    function getPool(CFMMProtocol protocol, address tokenA, address tokenB /*, fee if needed */)
        external
        view
        returns (address pool /* or bytes32 poolId for V4 */);
}
```

Dispatch: `protocol` selects which hardcoded factory/entry and which get-pool ABI (V3 `getPool`, Algebra `poolByPair`, V4 path, …).

**Upgrade model:** no storage mapping of protocols. New enum member ⇒ new contract bytecode ⇒ new address; callers update their registry pointer.

## Plank mirror

| Symbol | Role |
|--------|------|
| `PoolUninitialized` / `PoolInitialized` | Hydration phantoms (`struct {}`) |
| `UniswapV3`, `UniswapV4`, `Camelot`, `QuickSwap` | Protocol phantoms (optional; align with enum) |
| `get_pool` / registry wrapper | Calls registry `getPool`; builds typed uninitialized handle |

**Do not conflate** with today’s `Venue` (`V3`/`V4`/`Algebra`) + `Pool(V)` which **hydrate** fee/ts at construction. This registry is thinner SoT for **protocol brand → factory** and **resolve-only** handles. Venue remains the AMM-family backend behind each protocol’s get-pool path.

## File layout (sketch)

```text
docs/superpowers/specs/2026-09-06-cfmm-protocol-registry-design.md   # this file

src/types/protocol_integrations/PoolState.plk   # PoolUninitialized | PoolInitialized
src/types/protocol_integrations/CFMMProtocol.plk # protocol phantoms + is_cfmm_protocol

src/modules/CFMMProtocolRegistry.sol            # enum + bytecode table + getPool

test/modules/CFMMProtocolRegistry.t.sol         # resolve-only unit tests
test/types/protocol_integrations/PoolState.t.sol  # optional Plank harness later
```

## Out of scope (this track’s first slice)

- `hydrate` / `PoolInitialized` field load
- Proxy/UUPS in-place table mutation
- Replacing `Registry(V)` / `pool_*_at` call sites (migration later)
