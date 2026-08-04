// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {BatchResult} from "../pos_spec/VolOrderManagerBatch.t.sol";

/// @title VolOrderRefMock
/// @notice The INDEPENDENT Solidity reference registry for MVER-01. Reimplements the vol-order
///         registry SPECIFICATION -- the accept set (VolOrderValidationLib.plk:66-70), the
///         id = count + 1 rule, the 152-bit stored layout, and the input word read semantics
///         (VolOrderManagerMod.plk:212-217) -- from the source, in idiomatic Solidity.
/// @dev IT MUST NEVER MIRROR THE MODULE'S MANUAL ENCODING. There is no `assembly` block in this
///      file and there never may be. createOrders returns a typed BatchResult[]; the TEST calls
///      abi.encode on it. That is what keeps solc an INDEPENDENT oracle and the differential
///      non-vacuous: a mock that echoed the module's mstores would compare the module to itself.
/// @dev Storage is a plain mapping, NOT keccak(base)+id. Different on purpose -- the differential
///      compares observable behaviour, not a restatement of the module's slot arithmetic.
contract VolOrderRefMock {
    uint256 public orderCount;
    mapping(uint256 => uint256) public orders;

    uint256 internal constant TICK_SPACING   = 20;
    uint256 internal constant MAX_STRIKE     = 0xFFFFFFFFFFFFFFFFFFFFFF; // 2^88 - 1
    uint256 internal constant MAX_WIDTH      = 0xFFFFFF;
    uint256 internal constant MAX_TICK_SPACE = 200;
    uint256 internal constant MIN_SKEW       = 1;
    uint256 internal constant MAX_SKEW       = 65534;
    uint256 internal constant MAX_BATCH      = 128;

    uint256 internal constant MAX_TARGET_VEGA = (1 << 96) - 1; // V2 bound

    function isValid(uint256 strike, uint256 width, uint256 skew, uint256 targetVega) public pure returns (bool) {
        if (strike == 0 || strike > MAX_STRIKE) return false;          // strike_fits_packed
        if (width  == 0 || width  > MAX_WIDTH)  return false;          // vol_range_width_is_complete
        if (TICK_SPACING == 0 || TICK_SPACING > MAX_TICK_SPACE) return false;
        if (skew < MIN_SKEW || skew > MAX_SKEW) return false;          // spread_tick_assimetry_is_complete
        if (targetVega == 0 || targetVega > MAX_TARGET_VEGA) return false; // target_vega_fits_packed (V2)
        return true;
    }

    function packed(uint256 strike, uint256 width, uint256 skew, uint256 targetVega) public pure returns (uint256) {
        return (targetVega << 152) | (width << 128) | (TICK_SPACING << 104) | (strike << 16) | skew;
    }

    /// @dev The module's V2 INPUT read semantics: strike masked to 88 bits, width masked to 24
    ///      (now interior), skew to 16, and `targetVega` read UNMASKED as the new TOP field so
    ///      any calldata bit >= 224 inflates it past 2^96-1 and validation rejects it.
    ///      Reproducing that read is reproducing the INTERFACE CONTRACT, not the encoder.
    function readWord(uint256 word)
        public
        pure
        returns (uint256 strike, uint256 width, uint256 skew, uint256 targetVega)
    {
        strike     = (word >> 16) & MAX_STRIKE;
        width      = (word >> 104) & MAX_WIDTH;
        skew       =  word & 0xFFFF;
        targetVega =  word >> 128;
    }

    /// @notice The STRICT path: an invalid tuple REVERTS and leaves state byte-identical.
    function createOrder(uint256 strike, uint256 width, uint256 skew, uint256 targetVega) external {
        require(isValid(strike, width, skew, targetVega), "VolOrderRefMock: invalid tuple");
        uint256 id = orderCount + 1;
        orders[id] = packed(strike, width, skew, targetVega);
        orderCount = id;
    }

    /// @notice The BEST-EFFORT batch: invalid tuples are SKIPPED, the batch never reverts, and
    ///         results are positionally aligned to the input.
    function createOrders(uint256[] memory words) external returns (BatchResult[] memory rs) {
        require(words.length <= MAX_BATCH, "VolOrderRefMock: over MAX_BATCH");
        rs = new BatchResult[](words.length);
        uint256 id = orderCount;
        for (uint256 j = 0; j < words.length; j++) {
            (uint256 strike, uint256 width, uint256 skew, uint256 targetVega) = readWord(words[j]);
            if (isValid(strike, width, skew, targetVega)) {
                id++;
                orders[id] = packed(strike, width, skew, targetVega);
                rs[j] = BatchResult({success: true, orderId: id});
            } else {
                rs[j] = BatchResult({success: false, orderId: 0});
            }
        }
        orderCount = id;
    }

    /// @notice Test-side counter seeding, mirroring the vm.store seeding the Plank side uses.
    function seedCount(uint256 c) external { orderCount = c; }
}
