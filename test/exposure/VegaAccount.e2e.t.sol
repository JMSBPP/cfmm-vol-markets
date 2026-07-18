// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {PlankTestBase} from "../PlankTestBase.sol";
import {IssuanceRefMock} from "../mocks/IssuanceRefMock.sol";

// ===========================================================================================
// THE end-to-end (setRiskPrice, deposit) SEQUENCE differential (VVER-01). This is the milestone
// acceptance driver: it drives IDENTICAL (setRiskPrice, deposit) sequences into the deployed
// VegaAccountMod.plk and a TRIVIALLY-SIMPLE stateful mirror backed by the Solidity reference
// IssuanceRefMock, asserting all three accumulators (totalDeposits, totalShares,
// riskWeightedShares) EQUAL at TOLERANCE 0 AFTER EVERY WRITE, with the assertion INSIDE the
// driver helpers so it aborts at the earliest write a 15-02 mutant can diverge.
//
// WHY A NEW FILE (not folded into VegaAccount.t.sol or VegaIssuance.diff.t.sol).
//   * VegaAccount.t.sol owns the MODULE surface -- selector dispatch, the four keccak-derived
//     storage slots, and the three deposit guards. Its header states one-file-per-surface.
//   * VegaIssuance.diff.t.sol owns the LIB arithmetic surface (the VegaIssuanceLib kernel).
//   * The end-to-end (setRiskPrice, deposit) SEQUENCE differential vs the Solidity reference mock
//     is a distinct THIRD surface: it is neither a single-write module assertion nor a pure-
//     arithmetic diff, it is a STATEFUL sequence differential. The repo already separates
//     differential drivers by a named/.diff convention (RealizedVolatility.diff.t.sol,
//     VegaIssuance.diff.t.sol); VegaAccount.e2e.t.sol (the name 15-CONTEXT gives it) keeps
//     VegaAccount.t.sol pure. The 15-02 battery runs BOTH files.
//
// WHY THE MIRROR IS TRIVIALLY SIMPLE. It is three uint256 accumulators plus a mirror of the
// stored price, updated ONLY via the mock's pure functions (issueShares floor / haircutRiskPrice
// ceil). A mirror with any arithmetic of its OWN would be a second implementation to distrust; by
// deferring every computation to the mock (which is itself proven tolerance-0 vs the lib in
// Phase 13) the mirror can only be wrong by a bookkeeping slip, and the three-field tol-0 assert
// after every write catches that. The three share/deposit accumulators are kept SEPARATE in the
// mirror bookkeeping (mShares and mRiskWeighted are never conflated) so the d==1 consequence
// riskWeightedShares == totalShares is a genuine cross-check, not a tautology of shared storage.
//
// GLOBAL RULE (inherited): "it compiles" is never acceptance. deployPlank -> plankDeployFFI ->
// plankBuildFFI shells out to `plank build` over FFI AT TEST TIME, so every assertion below runs
// the freshly-compiled DEPLOYED bytecode -- a 15-02 .plk mutation reaches this driver with no
// `make compile-plank` in the path.
// ===========================================================================================

/// @notice The module ABI, identical to IVegaAccount in VegaAccount.t.sol (re-declared verbatim
///         from the signature strings pinned in src/interfaces/exposure/VegaAccountInterface.plk).
///         deposit/setRiskPrice are state-changing; previews and readers are view.
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

/// @title VegaAccountE2EDiffTest
/// @notice VVER-01: end-to-end (setRiskPrice, deposit) sequence differential. The deployed module
///         and an IssuanceRefMock-backed mirror are driven with IDENTICAL sequences; the three
///         accumulators must agree at tolerance 0 AFTER EVERY write. The assertion lives INSIDE
///         the _setPriceBoth/_depositBoth/_depositExpectRevertBoth helpers -- so "after every
///         write" cannot be forgotten at a call site, and the driver aborts at the EARLIEST write
///         a mutant can diverge (abort-at-earliest-divergence, the RealizedVolatility VDIFF-04
///         pattern this mirrors).
///
///         SENSITIVITY MAP (why 15-02's killable mutants each have a green here to redden):
///           * p_risk CEIL site  -- the mid-sequence price is derived via the module's
///             previewRiskPrice and diffed tol-0 against mock.haircutRiskPrice; a ceil->floor lib
///             mutant makes previewRiskPrice floor and that assertEq reddens.
///           * shares FLOOR site -- the Phase-12 anchor (deposit=10 at the P12 price mints exactly
///             12 shares, INEXACT) and the 2.5->2 point; a floor->ceil lib mutant makes these 13/3
///             and reddens the after-write accumulator assert.
///           * dust GUARD        -- a mid-sequence dust deposit reverts on the module and leaves
///             all three accumulators synced with the mirror (asserted ON STATE, both sides).
///           * cross-product OVERFLOW -- a ~2^200 weight-one deposit the baseline ACCEPTS (15-02
///             mutant (c) overflow-reverts there).
contract VegaAccountE2EDiffTest is PlankTestBase {
    IVegaAccount acct; // deployPlank("src/modules/exposure/VegaAccountMod.plk")
    IssuanceRefMock mock; // the mirror's expected-value source (proven tol-0 vs the lib in Phase 13)

    // The TRIVIALLY-SIMPLE mirror: three SEPARATE accumulators + the mirrored stored price.
    uint256 mDeposits; // sum of collateral deposited
    uint256 mShares; // sum of issued shares
    uint256 mRiskWeighted; // sum of risk-weighted shares -- NEVER conflated with mShares in bookkeeping
    uint256 mRiskPrice; // mirror of the module's stored risk price

    function setUp() public {
        acct = IVegaAccount(deployPlank("src/modules/exposure/VegaAccountMod.plk"));
        mock = new IssuanceRefMock();
        // all four mirror uints start 0 (default), matching the freshly-deployed zeroed vault.
    }

    // ---- The driver helpers: the assertion lives INSIDE each one ----------------------------

    /// @dev A price set moves NO accumulator on either side. We assert the stored price matches the
    ///      mirror AND that the three accumulators are unchanged (still synced) across the set.
    function _setPriceBoth(uint256 p) internal {
        acct.setRiskPrice(p);
        mRiskPrice = p;
        assertEq(acct.riskPrice(), p, "riskPrice stored == mirror");
        _assertAccumulatorsMatch(); // accumulators UNCHANGED across a price set
    }

    /// @dev A deposit at the currently-stored price. The expected share count comes from the mock's
    ///      floor issueShares(collateral, storedPrice) -- the SAME mulDiv-floor the module runs.
    ///      The mirror is updated BEFORE the module call so the post-call assert compares the NEW
    ///      totals on both sides.
    function _depositBoth(uint256 collateral) internal {
        uint256 expShares = mock.issueShares(collateral, mRiskPrice); // floor, identical to module's mulDiv
        mDeposits += collateral;
        mShares += expShares;
        mRiskWeighted += expShares;
        acct.deposit(collateral);
        _assertAccumulatorsMatch();
    }

    /// @dev A DUST deposit: floor(collateral*2^96/storedPrice) == 0, which the module rejects
    ///      (Guard 3). The mirror is NOT updated -- a revert must leave state SYNCED. We prove the
    ///      precondition (this really is a dust point per the mock), expect the module revert, then
    ///      assert all three accumulators are STILL synced ON STATE (not on a return value).
    function _depositExpectRevertBoth(uint256 collateral) internal {
        assertEq(mock.issueShares(collateral, mRiskPrice), 0, "precondition: this IS a dust point");
        vm.expectRevert();
        acct.deposit(collateral); // module reverts; mirror UNCHANGED
        _assertAccumulatorsMatch(); // all three still synced after the revert
    }

    /// @dev THE three-field tolerance-0 assertion, plus the d==1 consequence. The three fields are
    ///      compared INDEPENDENTLY (never as a quotient), so compensating errors cannot cancel; the
    ///      final assert is that the two SEPARATE mirror accumulators agree, i.e. riskWeightedShares
    ///      == totalShares as a genuine d==1 consequence rather than a shared-storage tautology.
    function _assertAccumulatorsMatch() internal view {
        assertEq(acct.totalDeposits(), mDeposits, "totalDeposits: module vs mirror, tol 0");
        assertEq(acct.totalShares(), mShares, "totalShares: module vs mirror, tol 0");
        assertEq(acct.riskWeightedShares(), mRiskWeighted, "riskWeightedShares: module vs mirror, tol 0");
        assertEq(mRiskWeighted, mShares, "d==1 consequence: riskWeightedShares == totalShares (mirror kept separate)");
    }

    // ---- Test A: the fixed, hand-checkable anchor sequence -----------------------------------

    /// @notice A fixed (setRiskPrice, deposit) sequence, every value hand-checkable, that makes BOTH
    ///         lib rounding sites AND the module guards sensitive. Hand-checked totals (all mirror
    ///         and module, tol 0):
    ///
    ///           1. setRiskPrice(2^96)        -- weight-one; accumulators still (0, 0, 0)
    ///           2. deposit(1000)             -- floor(1000*2^96/2^96)=1000 => (1000, 1000, 1000)
    ///           3. p12 = previewRiskPrice(10*2^92, 3*2^92)
    ///                                        == mock.haircutRiskPrice(...) (p_risk ceil, tol 0)
    ///                                        == 60944740395587951995033807951 (Phase-12/13 anchor)
    ///              setRiskPrice(p12)         -- accumulators unchanged (1000, 1000, 1000)
    ///           4. deposit(10) at p12        -- floor(10*2^96 / p12) = 12 (INEXACT: the Phase-12
    ///                                           shares=12 anchor, inherited NOT invented)
    ///                                           => (1010, 1012, 1012)
    ///           5. setRiskPrice(2^97)        -- dust regime; accumulators unchanged
    ///              deposit(1) DUST REVERT    -- floor(1*2^96/2^97)=0 => module reverts; state stays
    ///                                           SYNCED at (1010, 1012, 1012)
    ///           6. deposit(5) at 2^97        -- floor(5*2^96/2^97)=floor(2.5)=2 (INEXACT)
    ///                                           => (1015, 1014, 1014)
    ///           7. setRiskPrice(2^96); deposit(2^200) -- weight-one; BASELINE accepts a ~2^200
    ///                                           deposit (the cross-product mutant's kill site)
    ///                                           => (1015+2^200, 1014+2^200, 1014+2^200)
    ///
    ///         Sensitivity: a p_risk ceil->floor mutant reddens step 3's assertEq(p12, ...); a shares
    ///         floor->ceil mutant makes step 4 mint 13 (=> 1013) and step 6 mint 3 (=> 1015) and
    ///         reddens the after-write accumulator assert INSIDE _depositBoth; the dust-guard delete
    ///         mutant banks collateral for 0 shares so _depositExpectRevertBoth's post-revert sync
    ///         assert reddens; the raw-checked cross-product mutant overflow-reverts at step 7 where
    ///         this baseline accepts.
    function test__unit__fixedAnchorSequenceDiffers() public {
        // 1. weight-one; accumulators must still be 0
        _setPriceBoth(1 << 96);
        _assertAccumulatorsMatch();

        // 2. first real deposit at weight-one: expShares = 1000
        _depositBoth(1000); // mirror: D=1000 S=1000 RW=1000

        // 3. mid-sequence PRICE CHANGE derived via the module's previewRiskPrice, diffed vs the
        //    mock. This is what makes the p_risk CEIL site sensitive in the e2e (a ceil->floor lib
        //    mutant makes previewRiskPrice floor and this assertEq reddens):
        uint256 p12 = acct.previewRiskPrice(10 * (2 ** 92), 3 * (2 ** 92));
        assertEq(p12, mock.haircutRiskPrice(10 * (2 ** 92), 3 * (2 ** 92)), "p_risk ceil: module preview vs mock, tol 0");
        assertEq(p12, 60944740395587951995033807951, "p_risk hand-derived anchor (Phase-12/13)");
        _setPriceBoth(p12); // accumulators unchanged (1000,1000,1000)

        // 4. deposit priced at the NEW price -- inherits the Phase-12 anchor shares=12 (INEXACT:
        //    floor). A shares floor->ceil lib mutant makes this 13 and reddens the after-write assert.
        _depositBoth(10); // mirror: D=1010 S=1012 RW=1012

        // 5. dust regime, then a mid-sequence DUST REVERT proving state stays synced
        _setPriceBoth(2 * (1 << 96)); // pRisk = 2^97
        _depositExpectRevertBoth(1); // floor(1*2^96/2^97)=0 -> revert; state stays (1010,1012,1012)

        // 6. another INEXACT deposit after the revert (5*2^96/2^97 = 2.5 -> 2)
        _depositBoth(5); // mirror: D=1015 S=1014 RW=1014

        // 7. back to weight-one; a ~2^200 deposit the BASELINE accepts (the cross-product mutant's
        //    kill site in the e2e -- 15-02 mutant (c) overflow-reverts here)
        _setPriceBoth(1 << 96);
        _depositBoth(1 << 200); // mirror: D=1015+2^200 S=1014+2^200 RW=1014+2^200

        // non-vacuity: at least one nonzero mint happened
        assertTrue(acct.totalShares() != 0, "corpus non-vacuous: shares minted");
    }
}
