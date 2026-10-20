// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @title WeinerGenerator
/// @notice Deployable seal/reveal entropy box + Ray-scale ΔW = √dt̄ · ε (cfmm-vol-markets#126).
/// @dev Timestamps (Window/dt) and block numbers are independent clocks. One reveal yields an
///      entropy root; per-step ε_j = map(keccak256(root, j)).
contract WeinerGenerator {
    uint256 public constant RAY = 1e27;
    uint256 public constant PIPS = 1e6;
    uint256 public constant MAX_ABS_EPS_PIPS = 6 * PIPS;
    uint256 public constant WINDOW = 86400; // 24 * 60 * 60; cfmm-types Window

    error NotSealer();
    error AlreadySealed();
    error NotSealed();
    error BadCommitment();
    error RevealTooEarly();
    error BlockhashUnavailable();
    error NoEntropyRoot();
    error JOutOfRange();
    error BadTimeSpacing();

    address public sealer;
    bytes32 public commitment;
    uint256 public sealBlock;
    bytes32 public entropyRoot;
    bool public hasRoot;

    modifier onlySealer() {
        if (msg.sender != sealer) revert NotSealer();
        _;
    }

    constructor(address sealer_) {
        sealer = sealer_;
    }

    function setSealer(address sealer_) external onlySealer {
        sealer = sealer_;
    }

    /// @notice Store commitment = keccak256(seed) and sealBlock.
    function seal(bytes32 seed) external onlySealer {
        if (commitment != bytes32(0)) revert AlreadySealed();
        commitment = keccak256(abi.encodePacked(seed));
        sealBlock = block.number;
        hasRoot = false;
        entropyRoot = bytes32(0);
    }

    /// @notice Verify seed, require block.number > sealBlock, use blockhash(sealBlock).
    ///         Stores entropyRoot = keccak256(seed, blockhash); clears commitment.
    function reveal(bytes32 seed) external onlySealer {
        if (commitment == bytes32(0)) revert NotSealed();
        if (keccak256(abi.encodePacked(seed)) != commitment) revert BadCommitment();
        if (block.number <= sealBlock) revert RevealTooEarly();
        bytes32 bh = blockhash(sealBlock);
        if (bh == bytes32(0)) revert BlockhashUnavailable();

        entropyRoot = keccak256(abi.encodePacked(seed, bh));
        hasRoot = true;
        commitment = bytes32(0);
        sealBlock = 0;
    }

    /// @notice ε_j from entropy root; j ∈ [0, Window/dt).
    function eps(uint256 dt, uint256 j) public view returns (uint256) {
        if (!hasRoot) revert NoEntropyRoot();
        _requireTimeSpacing(dt);
        uint256 n = WINDOW / dt;
        if (j >= n) revert JOutOfRange();
        bytes32 h = keccak256(abi.encodePacked(entropyRoot, j));
        return mapHashToShockPips(h);
    }

    /// @notice shock(dt, j) = deltaW(dt, eps(dt, j)).
    function shock(uint256 dt, uint256 j) external view returns (uint256) {
        return deltaW(dt, eps(dt, j));
    }

    /// @notice Sign from high bit; magnitude (h >> 1) % (6 * PIPS). neg_u256 for negative.
    function mapHashToShockPips(bytes32 h) public pure returns (uint256) {
        uint256 x = uint256(h);
        uint256 mag = (x >> 1) % MAX_ABS_EPS_PIPS;
        if (x >> 255 == 1) {
            unchecked {
                return uint256(0) - mag;
            }
        }
        return mag;
    }

    /// @notice ΔW = √dt̄ · ε in Ray; √ from TimeSpacing comptime table; product toward zero.
    function deltaW(uint256 dt, uint256 epsPips) public pure returns (uint256) {
        (uint256 mag, bool neg) = _decodeSigned(epsPips);
        uint256 sqrtRay = _sqrtDtRay(dt);
        uint256 prod = (sqrtRay * mag) / PIPS; // toward zero (unsigned)
        if (neg) {
            unchecked {
                return uint256(0) - prod;
            }
        }
        return prod;
    }

    /// @dev floor(√dt · RAY) for dt ∈ {2,3,4,5,6,8,9,10} — not getSqrtRatioAtTick.
    function _sqrtDtRay(uint256 dt) internal pure returns (uint256) {
        if (dt == 2) return 1414213562373095048801688724;
        if (dt == 3) return 1732050807568877293527446341;
        if (dt == 4) return 2000000000000000000000000000;
        if (dt == 5) return 2236067977499789696409173668;
        if (dt == 6) return 2449489742783178098197284074;
        if (dt == 8) return 2828427124746190097603377448;
        if (dt == 9) return 3000000000000000000000000000;
        if (dt == 10) return 3162277660168379331998893544;
        revert BadTimeSpacing();
    }

    function _requireTimeSpacing(uint256 dt) internal pure {
        if (
            !(dt == 2 || dt == 3 || dt == 4 || dt == 5 || dt == 6 || dt == 8 || dt == 9 || dt == 10)
        ) {
            revert BadTimeSpacing();
        }
        if ((WINDOW / dt) * dt != WINDOW) revert BadTimeSpacing();
    }

    function _decodeSigned(uint256 x) internal pure returns (uint256 mag, bool neg) {
        if (x > type(uint256).max / 2) {
            unchecked {
                return (uint256(0) - x, true);
            }
        }
        return (x, false);
    }
}
