// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @notice Plank's stored Timepoint, decoded from the packed u256 word returned by
///         getTimepointPacked(uint16).
struct PlankTimepoint {
    uint32 timestamp;
    uint88 volatilityCumulative;
    int24 tick;
    int24 avgTick;
    int56 tickCumulative;
    uint16 windowStartIndex;
    bool initialized;
}

/// @title TimepointDecoder
/// @notice THE single test-side unpacker for Plank's packed timepoint word.
///
/// @dev WHY A LIBRARY. This unpacker existed twice already (the full 7-field copy in
///      RealizedVolatilitySmoke.t.sol, a partial 3-field copy in RealizedVolatility.diff.t.sol) and
///      VDIFF-04 needed a third. Three copies of a bit layout is three chances to desynchronise from
///      src/types/fee_volatility/Timepoint.plk. There is now one.
///
/// @dev THE OFFSETS ARE MIRRORED, NOT SHARED. Plank's packing order is NOT Solidity's struct packing
///      order, so these constants restate Timepoint.plk:30-35 by hand. What must match Algebra is the
///      field WIDTHS; these offsets are Plank's own. If Timepoint.plk moves a field, this file must
///      move with it -- and the VDIFF-04 differential is what makes that failure loud rather than
///      silent.
library TimepointDecoder {
    uint256 internal constant OFF_VOL = 32; // uint88 volatilityCumulative
    uint256 internal constant OFF_TICK = 120; // int24  tick             (SIGNED)
    uint256 internal constant OFF_AVG_TICK = 144; // int24  avgTick          (SIGNED)
    uint256 internal constant OFF_TICK_CUM = 168; // int56  tickCumulative   (SIGNED)
    uint256 internal constant OFF_WSI = 224; // uint16 windowStartIndex
    uint256 internal constant OFF_INIT = 240; // bool   initialized

    /// @dev The int24/int56 fields are re-signed by the uintN -> intN cast: masking alone would turn
    ///      -200 into 16777016. Plank sign-extends on ITS side in unpack_timepoint; this is the test
    ///      side's mirror of that.
    function decode(uint256 w) internal pure returns (PlankTimepoint memory t) {
        t.timestamp = uint32(w & 0xFFFFFFFF);
        t.volatilityCumulative = uint88((w >> OFF_VOL) & 0xFFFFFFFFFFFFFFFFFFFFFF);
        t.tick = int24(uint24((w >> OFF_TICK) & 0xFFFFFF));
        t.avgTick = int24(uint24((w >> OFF_AVG_TICK) & 0xFFFFFF));
        t.tickCumulative = int56(uint56((w >> OFF_TICK_CUM) & 0xFFFFFFFFFFFFFF));
        t.windowStartIndex = uint16((w >> OFF_WSI) & 0xFFFF);
        t.initialized = ((w >> OFF_INIT) & 1) == 1;
    }
}
