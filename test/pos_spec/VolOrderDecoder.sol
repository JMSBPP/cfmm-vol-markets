// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title VolOrderDecoder
/// @notice THE single test-side decoder for the packed VolOrder word (MVER-01). V2 layout:
///         targetVega at bit 152 | width at 128 | tickSpacing at 104 | strike at 16 | skew at 0
///         (248 bits).
///         (Written in prose rather than the field-at-bit shorthand the plan used: solc parses a
///         leading at-sign followed by a word in NatSpec as a documentation tag and rejects the
///         file with Error 6546. The shorthand survives inside string literals, which is where
///         the differential's failure messages still name the fields by bit offset.)
/// @dev DELIBERATELY UNGUARDED. No length check, no success check, no early return. A helper
///      that guards its decode can turn every downstream assertion vacuous when a type changes
///      -- that is exactly what nearly shipped in Phase 18b. decode() is total on all of uint256.
library VolOrderDecoder {
    struct Fields {
        uint256 width;
        uint256 tickSpacing;
        uint256 strike;
        uint256 skew;
        uint256 targetVega;
    }

    function decode(uint256 packed) internal pure returns (Fields memory f) {
        f.skew = packed & 0xFFFF;
        f.strike = (packed >> 16) & 0xFFFFFFFFFFFFFFFFFFFFFF; // 2^88 - 1
        f.tickSpacing = (packed >> 104) & 0xFFFFFF;
        f.width = (packed >> 128) & 0xFFFFFF; // interior in V2
        f.targetVega = packed >> 152; // the top field
    }
}
