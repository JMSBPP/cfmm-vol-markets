// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {PlankTestBase} from "../PlankTestBase.sol";

// ===========================================================================================
// THE VegaAccountMod MODULE surface. Everything that exercises the dispatch/storage/guard/
// preview/reader behaviour of src/modules/exposure/VegaAccountMod.plk lives in THIS FILE.
//
// WHY A SEPARATE FILE FROM VegaIssuance.diff.t.sol. That file owns the PURE ARITHMETIC surface
// (the VegaIssuanceLib kernel). This file owns the MODULE surface -- selector dispatch, the four
// keccak-derived storage slots, and the three deposit guards -- which is categorically distinct.
// One file per surface: we do NOT re-test the Phase-13 arithmetic here.
//
// GLOBAL RULE: "it compiles" is never acceptance. `plank build` does NOT type-check code
// unreachable from run{}. deployPlank -> plankDeployFFI -> plankBuildFFI shells out to
// `plank build` over FFI AT TEST TIME, so every assertion below runs the DEPLOYED bytecode.
// Only a CALLED selector outcome proves the module exists. The module STAYS in PLANK_SKIP this
// phase -- its exit is Phase 15 (VVER-02), gated on this CALLED-green deposit surface.
//
// 14-02 EXTENDS this file (slot-distinctness vm.load proof + the mutation gate); do NOT fork a
// second file.
// ===========================================================================================

/// @notice The module ABI, declared from the SAME signature strings pinned in
///         src/interfaces/exposure/VegaAccountInterface.plk (a mismatch means the differential
///         never dispatches). deposit/setRiskPrice are state-changing; previews and readers view.
interface IVegaAccount {
    function deposit(uint256 collateralAmt) external;
    function setRiskPrice(uint256 pRiskX96) external;
    function previewDeposit(uint256 amt) external view returns (uint256);
    function previewRiskPrice(uint256 oracleX96, uint256 hX96) external view returns (uint256);
    function totalDeposits() external view returns (uint256);
    function totalShares() external view returns (uint256);
    function riskWeightedShares() external view returns (uint256);
    function riskPrice() external view returns (uint256);
}

/// @dev Shared deploy: one FFI compile+deploy of the module per test (Foundry reverts state to the
///      post-setUp snapshot between fuzz runs, so each run starts from a fresh zeroed vault).
abstract contract VegaAccountBase is PlankTestBase {
    IVegaAccount internal acct;

    // Weight-one anchor: pRisk == 2^96 makes shares == collateral exactly (never dust for amt>=1).
    uint256 internal constant PRISK = 1 << 96;
    uint256 internal constant COLLATERAL = 1000;

    function setUp() public virtual {
        acct = IVegaAccount(deployPlank("src/modules/exposure/VegaAccountMod.plk"));
    }
}

/// @title VegaAccountSmokeTest
/// @notice VMOD-01 + VMOD-04: deposit moves all three accumulators, additively, and every reader
///         observes them. Two deposits double each accumulator -- proving each is a genuine
///         running total, not a one-shot write.
contract VegaAccountSmokeTest is VegaAccountBase {
    function test__unit__depositMovesAllThreeAccumulators() public {
        acct.setRiskPrice(PRISK);
        assertEq(acct.riskPrice(), PRISK, "riskPrice reader confirms the stored price");

        acct.deposit(COLLATERAL);
        assertEq(acct.totalDeposits(), COLLATERAL, "totalDeposits after first deposit");
        assertEq(acct.totalShares(), COLLATERAL, "totalShares after first deposit (weight-one)");
        assertEq(acct.riskWeightedShares(), COLLATERAL, "riskWeightedShares after first deposit");

        // Non-degeneracy: the anchor is not a trivial zero.
        assertTrue(COLLATERAL != 0, "collateral must be non-zero");
        assertTrue(acct.totalShares() != 0, "shares must be non-zero after a deposit");

        // Second deposit: every accumulator is additive, not a one-shot write.
        acct.deposit(COLLATERAL);
        assertEq(acct.totalDeposits(), 2 * COLLATERAL, "totalDeposits doubled");
        assertEq(acct.totalShares(), 2 * COLLATERAL, "totalShares doubled");
        assertEq(acct.riskWeightedShares(), 2 * COLLATERAL, "riskWeightedShares doubled");
    }
}

/// @title VegaAccountGuardTest
/// @notice VMOD-01 + VMOD-02: the three deposit reverts + the setter zero-revert, each asserted
///         ON STATE (totalDeposits / riskPrice unchanged) -- NEVER inferred from the return value.
contract VegaAccountGuardTest is VegaAccountBase {
    /// @notice Guard 1: deposit(0) reverts; totalDeposits unmoved.
    function test__unit__depositZeroReverts() public {
        acct.setRiskPrice(PRISK);
        vm.expectRevert();
        acct.deposit(0);
        assertEq(acct.totalDeposits(), 0, "deposit(0) must not move state");
    }

    /// @notice Guard 3 (dust floor): at pRisk == 2^97, deposit(1) mints
    ///         floor(1 * 2^96 / 2^97) = 0 shares -> revert. Collateral cannot be banked for zero
    ///         shares. totalDeposits unmoved.
    function test__unit__dustDepositReverts() public {
        acct.setRiskPrice(2 * (1 << 96));
        vm.expectRevert();
        acct.deposit(1);
        assertEq(acct.totalDeposits(), 0, "dust deposit must not move state");
    }

    /// @notice Guard 2 (unset price): with no setRiskPrice, storedRiskPrice == 0 reverts. That
    ///         "set at least once" reading is valid ONLY because setRiskPrice rejects 0 -- the
    ///         documented coupling. totalDeposits unmoved.
    function test__unit__depositBeforeSetRiskPriceReverts() public {
        vm.expectRevert();
        acct.deposit(COLLATERAL);
        assertEq(acct.totalDeposits(), 0, "deposit before setRiskPrice must not move state");
    }

    /// @notice setRiskPrice(0) reverts; riskPrice unmoved (stays 0).
    function test__unit__setRiskPriceZeroReverts() public {
        vm.expectRevert();
        acct.setRiskPrice(0);
        assertEq(acct.riskPrice(), 0, "setRiskPrice(0) must not store");
    }
}

/// @title VegaAccountSetRiskPriceTest
/// @notice VMOD-02: the setter stores and re-prices (overwrites).
contract VegaAccountSetRiskPriceTest is VegaAccountBase {
    function test__unit__setRiskPriceStores() public {
        acct.setRiskPrice(PRISK);
        assertEq(acct.riskPrice(), PRISK, "first setRiskPrice stores");
        acct.setRiskPrice(7 * (1 << 96));
        assertEq(acct.riskPrice(), 7 * (1 << 96), "setRiskPrice overwrites");
    }
}

/// @title VegaAccountPreviewTest
/// @notice VMOD-03: previewDeposit (pure, no state change, SAME lib call as deposit) equals the
///         observed totalShares delta of the following deposit -- the canonical-vault-bug guard --
///         and previewRiskPrice computes the H1 price and inherits the lib's h>=1 revert.
contract VegaAccountPreviewTest is VegaAccountBase {
    /// @notice previewDeposit == deposit-delta at BOTH the weight-one price and a second stored
    ///         price, proving preview can never diverge from the action.
    function test__unit__previewDepositEqualsDepositDelta() public {
        acct.setRiskPrice(PRISK);
        uint256 predicted = acct.previewDeposit(COLLATERAL);
        uint256 before = acct.totalShares();
        acct.deposit(COLLATERAL);
        uint256 delta = acct.totalShares() - before;
        assertEq(predicted, delta, "previewDeposit MUST equal the totalShares delta of the following deposit");

        // Second stored price (non-weight-one) so predicted != 0 and the equality is exercised
        // away from the trivial cancel.
        acct.setRiskPrice(3 * (1 << 96));
        uint256 collateral2 = 30;
        uint256 predicted2 = acct.previewDeposit(collateral2);
        uint256 before2 = acct.totalShares();
        acct.deposit(collateral2);
        uint256 delta2 = acct.totalShares() - before2;
        assertEq(predicted2, delta2, "previewDeposit == deposit delta at a second stored price");
        assertTrue(predicted2 != 0, "second-price prediction must be non-zero");
    }

    /// @notice Fixed weight-one price so shares == amt exactly (never dust for amt >= 1); the full
    ///         u256 amt range is legal. previewDeposit(amt) must equal the observed deposit delta.
    ///         The corpus is CONSTRUCTED via bound() only -- never assume-filtered.
    /// forge-config: default.fuzz.runs = 256
    function test__fuzz__previewDepositEqualsDepositDelta(uint256 raw) public {
        acct.setRiskPrice(1 << 96);
        uint256 amt = bound(raw, 1, type(uint256).max);
        uint256 predicted = acct.previewDeposit(amt);
        uint256 before = acct.totalShares();
        acct.deposit(amt);
        uint256 delta = acct.totalShares() - before;
        assertEq(predicted, delta, "fuzz: previewDeposit == totalShares delta of the following deposit");
    }

    /// @notice previewRiskPrice computes the H1 p_risk at the risk.md §4 inexact anchor, then
    ///         reverts at h == 1 (denom 0). h<1 is enforced by the lib, not the module.
    function test__unit__previewRiskPriceComputesAndRejectsHGe1() public {
        uint256 pRisk = acct.previewRiskPrice(10 * (2 ** 92), 3 * (2 ** 92));
        assertEq(pRisk, 60944740395587951995033807951, "previewRiskPrice p_risk ceil at inexact anchor");

        vm.expectRevert();
        acct.previewRiskPrice(1 << 96, 1 << 96);
    }
}
