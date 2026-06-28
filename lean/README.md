# `lean/` — Lean4 formalization layer

Mirrors `model/` directory layout. Each file under `lean/` is the formal
counterpart of the same-named markdown spec under `model/`:

| Markdown spec | Lean formalization |
|---|---|
| `model/spec/primitives.md` | `lean/spec/primitives.lean` *(planned)* |
| `model/spec/pricingKernel.md` | `lean/spec/pricingKernel.lean` *(planned)* |
| `model/spec/liquidityKernel.md` | `lean/spec/liquidityKernel.lean` *(planned)* |
| `model/exp/eta.md` | `lean/exp/eta.lean` ✓ |

## Dependencies

| Require | Version | Notes |
|---|---|---|
| `mathlib` | `v4.30.0` | Real analysis, power functions. Pinned to match LeanEVM. |
| `evm` ([Philogy/LeanEVM](https://github.com/Philogy/LeanEVM)) | commit `ab5e339` | Executable formal EVM model — scaffolding for later proofs about the on-chain Plank implementation. **Native build cost**: pulls SHA-2 / Keccak C sources and builds a Rust helper (`tools/evmrs`), so the host needs `cc` and `cargo`. `exp/eta.lean` does not import it. |

The toolchain is pinned to `leanprover/lean4:v4.30.0` to match LeanEVM (Lake
requires aligned toolchains across deps).

## Theorem-proving workflow (Aristotle)

State theorems with `sorry` placeholders, then submit the project for
automated proof:

```bash
# one-time: put your key in your shell environment (not on the command line)
export ARISTOTLE_API_KEY=...   # do this in your shell, not in chat

aristotle submit "Fill in all sorries in exp/eta.lean" \
  --project-dir ./lean --wait --destination ./lean/.aristotle-out.tar.gz
```

Aristotle runs the Lean toolchain pinned in `lean-toolchain` server-side,
resolves the `[[require]]` dependencies, and attempts to discharge each
`sorry`. The result archive contains the proven file(s) or partial progress.

## Naming convention

Lowercase camelCase filenames mirror `model/`. Module names follow Lean's
`<dir>.<file>` convention, so `lean/exp/eta.lean` is module `exp.eta`.
