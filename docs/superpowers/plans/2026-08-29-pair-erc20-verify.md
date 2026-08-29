# `Pair` ERC20 verification — implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `pair_verify_erc20(p: Pair) void` to `src/types/Pair.plk` — inline duplicated ERC20 probes for `token0` and `token1` using Plank std return/revert helpers (try/catch semantics).

**Architecture:** `pair()` stays structural (sort + remap only). `pair_verify_erc20` is a separate proof function in the same file. Per token: `balanceOf` must succeed via staticcall; `transfer` and `transferFrom` must fail with OZ `InsufficientBalance` / `InsufficientAllowance` custom errors. Probe blocks are copy-pasted for `token0` and `token1` — no shared library, no `verify_erc20(addr)` helper. No `vol_market_key` wiring in this phase.

**Tech Stack:** Plank (`lib/plank-monorepo/std` — `membytes`, `abi`, `option`, return/revert helpers), Foundry (`forge test --via-ir --offline` via `PlankTestBase`), verification via `.github/workflows/push-build.yml`.

**Spec:** `.spec/.research/plank_introspection.md`, `.spec/POOL_KEY.md` § PAIR, agent rules `.spec/README.md`

## Global Constraints

- **Worktree mandatory.** Branch `type/pair-erc20-verify` in `../vol-markets-pair-erc20-verify`. Never implement inline on `develop`.
- **Issue + PR before RED commits.** File issue on `develop`; open PR referencing it (`Closes #N`) before first push.
- **NO LOCAL COMPILATION as sign-off.** Verification = `git push` → read `push-build.yml` on GitHub Actions.
- **Confirm scope in CI log.** After every push, confirm `PairTest` / `PairHarness.plk` compiled and **your new tests executed** (not skipped).
- **Chunk approval before commit.** Present each file diff; maintainer approves/modifies; then commit.
- **TDD RED first.** First push intentionally fails or skips until `Pair.plk` implements `pair_verify_erc20`.
- **Name every path on `git add`.** Never stage dirty submodules or unrelated WIP.
- **Scope:** `Pair` ERC20 verify only. No `Erc20Introspect.plk` library, no IERC165 helper, no legacy false-return tokens, no `vol_market_key` call-site wiring.

---

## File structure (this phase)

| File | Responsibility | Action |
|------|----------------|---------|
| `src/types/Pair.plk` | Add selector constants + `pair_verify_erc20` (inline duplicated probes) | **Modify** (Task 2) |
| `test/types/PairHarness.plk` | Expose `pairVerifyErc20(address,address,uint256)` | **Modify** (Task 1) |
| `test/types/Pair.t.sol` | ERC20 verify pass/fail tests + Solidity mocks | **Modify** (Task 1) |
| `test/mocks/PairVerifyCompliantERC20.sol` | OZ-style custom-error ERC20 mock | **Create** (Task 1) |
| `test/mocks/PairVerifyBadTransferERC20.sol` | `transfer` succeeds instead of reverting | **Create** (Task 1) |
| `test/mocks/PairVerifyBadAllowanceERC20.sol` | `transferFrom` reverts with wrong selector | **Create** (Task 1) |

**Not in this phase:** `src/lib/token/Erc20Introspect.plk`, `src/interfaces/token/`, `vol_market_key` integration, `TODO.md` §1 quote-orientation.

---

### Task 0: Worktree, issue, and PR shell

**Files:** none (git + `gh` only)

- [ ] **Step 1: Create worktree**

```bash
cd /home/jmsbpp/cfmms-playground/cfmm-wt/vol-markets
git fetch origin develop
git worktree add ../vol-markets-pair-erc20-verify -b type/pair-erc20-verify origin/develop
cd ../vol-markets-pair-erc20-verify
```

- [ ] **Step 2: Pin std helpers — read before Task 2**

```bash
git submodule update --init lib/plank-monorepo
rg -n 'revert|staticcall|call_' lib/plank-monorepo/std --glob '*.plk' | head -40
```

Record exact helper module paths and function names (return-on-success, revert-with-selector). Task 2 must use these — not ad-hoc `@evm_revert` only.

- [ ] **Step 3: Open tracking issue**

```bash
gh issue create --repo JMSBPP/cfmm-vol-markets \
  --title "type(pair-erc20-verify): pair_verify_erc20 inline ERC20 probes" \
  --body-file docs/superpowers/plans/2026-08-29-pair-erc20-verify.md
```

Record issue number as `ISSUE_N`.

- [ ] **Step 4: Open draft PR**

```bash
git push -u origin type/pair-erc20-verify   # after Task 1 first commit, or empty branch + PR now
gh pr create --base develop --head type/pair-erc20-verify --draft \
  --title "type(pair-erc20-verify): pair_verify_erc20 inline ERC20 probes" \
  --body "Closes #ISSUE_N

## Plan
docs/superpowers/plans/2026-08-29-pair-erc20-verify.md"
```

---

### Task 1: RED — mocks, harness, Foundry tests (no `pair_verify_erc20` yet)

**Files:**
- Create: `test/mocks/PairVerifyCompliantERC20.sol`
- Create: `test/mocks/PairVerifyBadTransferERC20.sol`
- Create: `test/mocks/PairVerifyBadAllowanceERC20.sol`
- Modify: `test/types/PairHarness.plk`
- Modify: `test/types/Pair.t.sol`

**Interfaces:**
- Consumes: `pair_verify_erc20(p: Pair) void` — **does not exist yet** (intentional RED)
- Produces for Task 2:
  ```plank
  const pair_verify_erc20 = fn (p: Pair) void;
  ```
- Harness external ABI:
  - existing: `pair(address,address,uint256) returns (address,address,uint256)`
  - new: `pairVerifyErc20(address,address,uint256)` — builds `pair(a,b,assetIdx)` then calls `pair_verify_erc20`; returns `uint256 1` on success, reverts on failure

**Probe account (locked for tests + implementation):** `@evm_address()` cast to `addr` — the harness contract. `balanceOf(harness)` must return `0`.

**Selector constants (Task 2 will copy into `Pair.plk`):**

| Name | Value |
|------|-------|
| `SEL_BALANCE_OF` | `0x70a08231` |
| `SEL_TRANSFER` | `0xa9059cbb` |
| `SEL_TRANSFER_FROM` | `0x23b872dd` |
| `ERR_INSUFFICIENT_BALANCE` | `0xe450d38c` |
| `ERR_INSUFFICIENT_ALLOWANCE` | `0xfb8f41b2` |

- [ ] **Step 1: Write `test/mocks/PairVerifyCompliantERC20.sol`**

Minimal ERC20 with OZ IERC20Errors custom errors. `balanceOf` always succeeds. `transfer` / `transferFrom` revert with `InsufficientBalance` / `InsufficientAllowance` when balance or allowance is insufficient (zero balance and zero allowance for probe account).

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @dev Minimal ERC20 for pair_verify_erc20 probes — OZ-style custom errors only.
contract PairVerifyCompliantERC20 {
    error InsufficientBalance(address sender, uint256 balance, uint256 needed);
    error InsufficientAllowance(address spender, address allowanceOwner, uint256 allowance, uint256 needed);

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    function transfer(address to, uint256 amount) external returns (bool) {
        uint256 bal = balanceOf[msg.sender];
        if (bal < amount) revert InsufficientBalance(msg.sender, bal, amount);
        unchecked {
            balanceOf[msg.sender] = bal - amount;
            balanceOf[to] += amount;
        }
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        if (allowed < amount) revert InsufficientAllowance(msg.sender, from, allowed, amount);
        uint256 bal = balanceOf[from];
        if (bal < amount) revert InsufficientBalance(from, bal, amount);
        unchecked {
            allowance[from][msg.sender] = allowed - amount;
            balanceOf[from] = bal - amount;
            balanceOf[to] += amount;
        }
        return true;
    }
}
```

- [ ] **Step 2: Write `test/mocks/PairVerifyBadTransferERC20.sol`**

Same as compliant but `transfer` returns `false` instead of reverting (probe must reject — `ok == true` on intentional-fail call).

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @dev transfer never reverts — pair_verify_erc20 must reject this token.
contract PairVerifyBadTransferERC20 {
    function balanceOf(address) external pure returns (uint256) { return 0; }
    function transfer(address, uint256) external pure returns (bool) { return false; }
    function transferFrom(address, address, uint256) external pure returns (bool) { return false; }
}
```

- [ ] **Step 3: Write `test/mocks/PairVerifyBadAllowanceERC20.sol`**

`transfer` reverts correctly; `transferFrom` reverts with a **wrong** selector so allowance probe fails.

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

contract PairVerifyBadAllowanceERC20 {
    error InsufficientBalance(address sender, uint256 balance, uint256 needed);
    error WrongAllowanceError();

    function balanceOf(address) external pure returns (uint256) { return 0; }

    function transfer(address, uint256 amount) external pure returns (bool) {
        revert InsufficientBalance(msg.sender, 0, amount);
    }

    function transferFrom(address, address, uint256) external pure returns (bool) {
        revert WrongAllowanceError();
    }
}
```

- [ ] **Step 4: Extend `test/types/PairHarness.plk`**

```plank
// cast sig "pairVerifyErc20(address,address,uint256)" -> compute before commit:
// cast sig "pairVerifyErc20(address,address,uint256)"
const SEL_PAIR_VERIFY_ERC20 = 0x........;

// In run{}, after SEL_PAIR branch:
if selector == SEL_PAIR_VERIFY_ERC20 {
    let p = pair(
        addr_from_u256(@evm_calldataload(4)),
        addr_from_u256(@evm_calldataload(36)),
        @evm_calldataload(68)
    );
    pair_verify_erc20(p);
    let out = @malloc_uninit(32);
    @mstore32(out, 1);
    @evm_return(out, 32);
}
```

Replace `0x........` with `cast sig` output. Do not guess the selector.

- [ ] **Step 5: Extend `test/types/Pair.t.sol`**

Add helper and four new tests. Keep all existing `pair()` tests unchanged.

```solidity
import {PairVerifyCompliantERC20} from "../mocks/PairVerifyCompliantERC20.sol";
import {PairVerifyBadTransferERC20} from "../mocks/PairVerifyBadTransferERC20.sol";
import {PairVerifyBadAllowanceERC20} from "../mocks/PairVerifyBadAllowanceERC20.sol";

function _pairVerifyErc20(address a, address b, uint256 assetIdx) internal {
    (bool ok,) = harness.staticcall(
        abi.encodeWithSignature("pairVerifyErc20(address,address,uint256)", a, b, assetIdx)
    );
    require(ok, "pairVerifyErc20 reverted");
}

function test__unit__pairVerifyErc20_acceptsCompliantTokens() public {
    PairVerifyCompliantERC20 t0 = new PairVerifyCompliantERC20();
    PairVerifyCompliantERC20 t1 = new PairVerifyCompliantERC20();
    _pairVerifyErc20(address(t0), address(t1), 0);
}

function test__unit__pairVerifyErc20_rejectsBadTransfer() public {
    PairVerifyBadTransferERC20 t0 = new PairVerifyBadTransferERC20();
    PairVerifyCompliantERC20 t1 = new PairVerifyCompliantERC20();
    (bool ok,) = harness.staticcall(
        abi.encodeWithSignature("pairVerifyErc20(address,address,uint256)", address(t0), address(t1), 0)
    );
    assertFalse(ok, "bad transfer token must fail verify");
}

function test__unit__pairVerifyErc20_rejectsBadAllowance() public {
    PairVerifyCompliantERC20 t0 = new PairVerifyCompliantERC20();
    PairVerifyBadAllowanceERC20 t1 = new PairVerifyBadAllowanceERC20();
    (bool ok,) = harness.staticcall(
        abi.encodeWithSignature("pairVerifyErc20(address,address,uint256)", address(t0), address(t1), 0)
    );
    assertFalse(ok, "wrong allowance revert must fail verify");
}

function test__unit__pairVerifyErc20_rejectsEoa() public {
    address eoa = address(0xBEEF);
    PairVerifyCompliantERC20 t1 = new PairVerifyCompliantERC20();
    (bool ok,) = harness.staticcall(
        abi.encodeWithSignature("pairVerifyErc20(address,address,uint256)", eoa, address(t1), 0)
    );
    assertFalse(ok, "EOA must fail balanceOf probe");
}
```

- [ ] **Step 6: Maintainer approval**

- [ ] **Step 7: Commit and push RED**

```bash
git add test/mocks/PairVerifyCompliantERC20.sol \
        test/mocks/PairVerifyBadTransferERC20.sol \
        test/mocks/PairVerifyBadAllowanceERC20.sol \
        test/types/PairHarness.plk \
        test/types/Pair.t.sol
git commit -m "$(cat <<'EOF'
test(pair-erc20-verify): RED harness and mocks for pair_verify_erc20

EOF
)"
git push -u origin type/pair-erc20-verify
```

- [ ] **Step 8: Read push-build**

```bash
gh run list --branch type/pair-erc20-verify --workflow push-build.yml --limit 1
gh run view <RUN_ID> --log-failed
```

**Expected:** RED — `PairHarness.plk` fails to compile (`pair_verify_erc20` undefined) OR new tests fail/revert. Record run URL.

---

### Task 2: GREEN — `pair_verify_erc20` inline in `Pair.plk`

**Files:**
- Modify: `src/types/Pair.plk`

**Interfaces:**
- Produces:
  ```plank
  const pair_verify_erc20 = fn (p: Pair) void;
  ```
- Imports (add as needed from pinned std):
  ```plank
  import std::membytes::*;
  import std::core::addr::{addr, cast_addr};
  // + return/revert helper module discovered in Task 0 Step 2
  ```

**Implementation contract (inline, duplicated — no inner helper fn):**

At top of `Pair.plk`, add selector constants from Task 1 table.

`pair_verify_erc20` body structure:

```plank
const pair_verify_erc20 = fn (p: Pair) void {
    let probe = cast_addr(@evm_address(), addr);

    // ========== token0 block (copy-paste; do not extract) ==========
    // 1. staticcall balanceOf(probe) — return helper: must succeed
    // 2. call transfer(probe, 1) — revert helper: must fail, selector ERR_INSUFFICIENT_BALANCE
    // 3. call transferFrom(probe, probe, 1) — revert helper: must fail, selector ERR_INSUFFICIENT_ALLOWANCE

    // ========== token1 block (duplicate of token0, replace p.token0 -> p.token1) ==========
};
```

Calldata encoding for each probe (same pattern as `VolMarketKey.plk` `staticcall_word` but using std helpers):

- `balanceOf`: 4 + 32 bytes — selector at word 0, `probe` left-padded at word 1
- `transfer`: 4 + 32 + 32 — selector, `probe` as `to`, `amount = 1`
- `transferFrom`: 4 + 32 + 32 + 32 — selector, `probe` as `from`, `probe` as `to`, `amount = 1`

Use `@evm_call` (not staticcall) for steps 2 and 3 — state-changing ERC20 functions.

If step 2 or 3 returns `ok == true`, call `require(false)` — token is not conforming.

- [ ] **Step 1: Implement `pair_verify_erc20` in `src/types/Pair.plk`** per structure above. `pair()` body unchanged.

- [ ] **Step 2: Maintainer approval**

- [ ] **Step 3: Commit and push GREEN**

```bash
git add src/types/Pair.plk
git commit -m "$(cat <<'EOF'
feat(pair-erc20-verify): add pair_verify_erc20 with inline ERC20 probes

EOF
)"
git push origin type/pair-erc20-verify
```

- [ ] **Step 4: Read push-build**

```bash
gh run view <RUN_ID> --log | rg -i 'PairTest|pairVerify|PASS|FAIL'
```

**Expected:** GREEN — all `PairTest` tests (existing + four new) **running and passing**.

---

### Task 3: Merge and teardown

- [ ] **Step 1: Mark PR ready**

```bash
gh pr ready
```

- [ ] **Step 2: develop-gate green → merge**

```bash
gh run list --branch type/pair-erc20-verify --workflow develop-gate.yml --limit 1
# after gate green:
gh pr merge --squash --delete-branch
```

- [ ] **Step 3: Teardown worktree**

```bash
cd /home/jmsbpp/cfmms-playground/cfmm-wt/vol-markets
git fetch origin develop && git checkout develop && git pull
git worktree remove ../vol-markets-pair-erc20-verify
git branch -d type/pair-erc20-verify
```

- [ ] **Step 4: Update `TODO.md`** — add § Pair follow-on entry for `pair_verify_erc20` as **done** with PR link (maintainer approval before commit).

---

## Spec self-review

| Requirement (`.spec/.research/plank_introspection.md`) | Task |
|----------------------------------------------------------|------|
| `pair()` unchanged (structural only) | Task 2 |
| `pair_verify_erc20(p)` separate proof fn | Task 2 |
| Inline duplicated probes token0 + token1 | Task 2 |
| No shared library | Tasks 1–2 |
| `balanceOf` succeeds (staticcall) | Task 2 |
| `transfer` fails with `InsufficientBalance` | Task 2 + mocks Task 1 |
| `transferFrom` fails with `InsufficientAllowance` | Task 2 + mocks Task 1 |
| Std return/revert helpers (try/catch) | Task 0 Step 2 + Task 2 |
| Selectors in `Pair.plk` top | Task 2 |
| No `vol_market_key` wiring | — (deferred) |
| IERC165 / legacy false-return | — (deferred) |
| RED harness + Foundry tests | Task 1 |
| Worktree + push-build verification | Tasks 0–2 |
| Issue + PR before commits | Task 0 |

---

## Execution handoff

**Plan saved to `docs/superpowers/plans/2026-08-29-pair-erc20-verify.md`. Two execution options:**

1. **Subagent-Driven (recommended)** — fresh subagent per task, review between tasks
2. **Inline Execution** — execute tasks in this session via executing-plans with checkpoints

Which approach?
