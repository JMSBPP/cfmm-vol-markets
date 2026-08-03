# The `@openzeppelin/` remapping — what was actually measured

**Status:** correction of record. The merge commit `d7d1823` justified its `@openzeppelin/`
resolution with a claim that is FALSE. The resolution itself stands; the reasoning does not.
This file exists so the next person to touch this line does not re-derive it from the false
premise, and so the open question below reaches its actual owner.

## What `d7d1823`'s message claimed

> Both candidates exist on disk and both resolve every one of the five `@openzeppelin/` paths
> imported anywhere in the tree [...] Nothing forced the choice.

Both halves are wrong. "Five" came from grepping four directories (`src`, `foundry-scripts`,
`test`, `lib/panoptic-v2-core/contracts`, `lib/unistrata`) and calling that "anywhere in the
tree". And the two candidates are not interchangeable.

## What is actually true

Two roots are on disk, and they are different OpenZeppelin MAJOR versions:

| remapping target | OZ version |
|---|---|
| `lib/panoptic-v2-core/lib/openzeppelin-contracts/` (develop's value, **chosen**) | **4.8.3** |
| `lib/panoptic-v2-core/lib/v4-core/lib/openzeppelin-contracts/` (**rejected**) | **5.0.2** |

Measured over all 33 distinct `@openzeppelin/` paths imported by any `.sol`/`.plk` in the tree:

```
chosen   (4.8.3)  ->  resolves 18 / 33
rejected (5.0.2)  ->  resolves 25 / 33
```

The rejected root is a strict **superset**: it resolves all 18 that the chosen one does, plus 7
more, and there is **no** path that resolves only under the chosen root. Eight paths resolve
under neither — they use a `contracts/`-less prefix (`@openzeppelin/token/ERC20/ERC20.sol`,
`@openzeppelin/utils/Address.sol`, …) and belong to some other project's remapping convention.

So the choice was not neutral. By the metric the commit message itself invoked, it was strictly
worse.

## Three further facts the message did not account for

1. **`lib/panoptic-v2-core/remappings.txt:2` is `@openzeppelin/=lib/v4-core/lib/openzeppelin-contracts/`.**
   Panoptic is authored against **5.0.2**. Here it compiles against 4.8.3.

2. **`forge remappings` emits NO contextual `@openzeppelin` override.** One global entry decides
   for every library in the build, regardless of what each was written against. There is no
   per-dependency escape hatch in play.

3. **The copies differ in security-relevant code.** `SignatureChecker.sol`'s ERC-1271 return
   check is `result.length == 32` in 4.8.3 and `result.length >= 32` in 5.0.2.

## Why the resolution nonetheless stands

- **Net effect on develop is zero.** develop was already on 4.8.3; this merge did not move it.
- **Nothing reachable breaks.** Of the 7 paths only the rejected root resolves, 6 are inside
  vendored OZ test/mock files and 1 is `@openzeppelin/contracts/utils/ReentrancyGuard.sol`,
  imported by `lib/reactive-smart-contract-demos/src/demos/leverage-loop/LeverageAccount.sol` —
  a submodule this merge brought in. **None is reachable from `src/`, `test/` or
  `foundry-scripts/`**, so none is compiled.
- **Measured green:** `forge build` exits 0 and the gate's exact surface is 252 passed / 0 failed.

The risk was retired by measurement, not by the argument that was given.

## The open question, and whose it is

Which OpenZeppelin major the repo compiles panoptic-v2-core against is **not this workstream's
call**. Switching the global entry to 5.0.2 would compile panoptic against the version it was
authored for and strictly improve resolution — but it would also change what develop's 252-test
surface has been validating, and OZ 4→5 moved `Ownable`'s constructor, `ERC20` internals and the
`SignatureChecker` check above.

An offchain-client PR is the wrong vehicle for that change. Raise it with the plank / CI track.
Whoever takes it should re-measure rather than trusting the numbers here — they were taken on
`d7d1823` and the vendored tree moves.
