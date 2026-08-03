// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {SemiFungiblePositionManagerV4} from "@contracts/SemiFungiblePositionManagerV4.sol";

// ARTIFACT ANCHOR, no logic. This file is compilation-restricted to the LEGACY (non-via-IR)
// profile (foundry.toml), which is the only codegen the vendored SFPM compiles under. Its
// sole purpose is to force the SemiFungiblePositionManagerV4 artifact into out/ so
// DynamicFeeHookE2E.t.sol can vm.deployCode it. Do NOT import SFPM from any via-IR file --
// that would drag it back into a via-IR unit and reintroduce the Yul stack-too-deep.
contract SFPMLegacyAnchor {}
