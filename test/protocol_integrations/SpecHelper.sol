// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @title SpecOracle
/// @notice THE ONE SEAM between the Foundry test process and the Haskell executable
///         specification (`spec/src/Panoptic/NId.hs :: volOrderToTokenId`), reached over the
///         JSON-RPC transport that `evm-spec-bridge` serves (RED-06 transport boundary).
///
/// @dev PROVISIONAL HAND-WRITTEN STAND-IN - NOT YET GENERATED.
///      `evm-spec-bridge` GENERATES this library from the same schema as its Haskell protocol
///      types, so the two sides cannot drift silently. The bridge does not exist yet, so Phase 1
///      hand-writes the SHAPE the generator will emit and nothing else. Phase 7 REPLACES the
///      library below with the generated artifact. Nothing here may be relied on except its
///      shape.
///
///        generated-from spec commit: <unset - no bridge yet>
///        protocol version:           <unset - no bridge yet>
///
///      PHASE 1 CONTRACT (RED-04):
///        - `health()` is THE WIRING PREDICATE. It reports `Status.TransportFailure` because
///          there is no oracle. The differential test probes it ONCE in `setUp`, caches the
///          answer, and skips on the cached value. Phase 7 keeps the SAME predicate
///          (`status == Status.TransportFailure`) against a live endpoint - that is what RED-06
///          means by extend rather than redesign.
///        - `volOrderToTokenId` ALWAYS reverts with `SpecOracleNotWired`, naming its input.
///          THE REVERT IS THE STUB'S ONLY CORRECT BEHAVIOUR AND IT IS DELIBERATELY FAIL-SAFE.
///          A struct-returning stub would be FAIL-OPEN: a test that forgot to check `status`
///          would proceed silently with `tokenId == 0`, which is exactly the false-green class
///          this milestone exists to eliminate. Reverting makes that mistake impossible.
///          THIS APPLIES ONLY TO THE STUB. Phase 7's real implementation RETURNS the tagged
///          struct - including `Status.TransportFailure` - and does NOT revert, because a revert
///          would make spec rejection indistinguishable from a genuine Solidity revert and would
///          destroy the guard identity Phase 9's revert-vs-return assertion needs (GUARD-05).
///        - There is exactly ONE wiring mechanism. The Phase 1 draft's separate `isWired()`
///          probe was COLLAPSED INTO `health()`: two mechanisms are two things that can drift,
///          and the wiring predicate is the one thing that must not.
///
///      MUTABILITY IS DELIBERATELY UNRESTRICTED - neither function is `view` or `pure`. Phase 7
///      implements these bodies over `vm.rpc`, a state-mutating cheatcode. Declaring them `pure`
///      today would force mutability churn on every call site later. solc's warning 2018
///      ("state mutability can be restricted") is EXPECTED here; do not "fix" it.
///
///      TRANSPORT MECHANICS ARE OUT OF SCOPE FOR THIS FILE. The transport is RESOLVED
///      (JSON-RPC, decided at `evm-spec-bridge` initialization outside Phase 5), but no cheatcode
///      call appears here: Phase 1 needs the SHAPE, not the mechanics. Transport rules bind
///      every caller: check vm.rpc success before touching returned bytes; three-way outcomes
///      (Ok / Rejected / TransportFailure) must never be conflated.
///
///      BINDING RULE FOR EVERY CALLER, NOW AND IN PHASE 7: a call to this seam MUST bind its
///      boolean success value and check it BEFORE touching the returned bytes. No call site may
///      discard it. This is not style. MEASURED at forge 1.5.1-stable (b0a9dd9): a server that
///      accepts the connection and never answers costs a HARDCODED 45 s per call - there is no
///      timeout knob for `vm.rpc` - and the test PASSED, because the call site ignored `success`.
///      At `fuzz.runs = 256` that is 3.2 hours of green CI meaning nothing: this project's
///      founding failure mode, reproduced against the transport we chose.
///
///      EXTENSION POINTS - later phases fill these in, they do not redesign them:
///        Phase 4  - `volOrderWire` becomes the `VolOrder(T)` wire format bytes. It is OPAQUE
///                   here on purpose: `bytes` is the parameter type precisely so that choosing
///                   the format changes the encoder and not this seam.
///        Phase 5  - fixes the responsibility split (RPC-02) and proves `health()` end to end.
///        Phase 6  - gives the Haskell an out-of-process entrypoint. Nothing changes here.
///        Phase 7  - REPLACES this library with the GENERATED one; both bodies become real.
///        Phase 9  - asserts revert-vs-return parity over `TokenIdResult.guard` (GUARD-05).
///        Phase 11 - the wiring predicate stops governing execution; every `vm.skip` guarded by
///                   it is REMOVED (CI-04).
library SpecOracle {
    /// @notice The three outcomes that must NEVER be conflated (XPORT-02).
    ///         Ok               - the spec answered; `tokenId` is meaningful.
    ///         Rejected         - a spec guard rejected the input; `guard` is meaningful.
    ///         TransportFailure - the oracle was unreachable or did not answer. This is NEVER
    ///                            agreement and NEVER a rejection.
    enum Status {
        Ok,
        Rejected,
        TransportFailure
    }

    /// @notice Generated from the spec's guard set. The ids are STABLE so Phase 9 can assert on
    ///         them. `None` is the zero value, so a defaulted struct never names a real guard.
    ///         OptionRatioRange -> GUARD-01, LegSpanBelowSpacing -> GUARD-02,
    ///         TickOutOfBounds -> GUARD-03.
    enum Guard {
        None,
        OptionRatioRange,
        LegSpanBelowSpacing,
        TickOutOfBounds
    }

    /// @param status which of the three outcomes occurred
    /// @param tokenId meaningful IFF `status == Status.Ok`
    /// @param guard meaningful IFF `status == Status.Rejected`
    /// @param detail diagnostics ONLY. NEVER asserted on, in this phase or any later one: it is
    ///        free text from the far side, and asserting on it would couple the test to prose.
    struct TokenIdResult {
        Status status;
        uint256 tokenId;
        Guard guard;
        string detail;
    }

    /// @param status `TransportFailure` iff the oracle could not be reached. THE SKIP PREDICATE.
    /// @param specCommit the spec SHA the RUNNING BINARY was built from - not the SHA anyone
    ///        believes it was built from. Phase 5 asserts it equals this repo's `spec/` pin
    ///        (RPC-03): two paths to the oracle is a correctness hazard, not a build hazard.
    /// @param protocolVersion the generated protocol's version
    /// @param bridgeVersion the `evm-spec-bridge` version string
    struct Health {
        Status status;
        string specCommit;
        uint32 protocolVersion;
        string bridgeVersion;
    }

    /// @notice Raised by the PHASE 1 STUB ONLY, carrying the input it was asked about so a
    ///         failure NAMES the case rather than merely reporting "not wired".
    /// @param volOrderWire the serialized VolOrder that was to be transported
    /// @param poolId the Panoptic pool id that was to be transported
    error SpecOracleNotWired(bytes volOrderWire, uint64 poolId);

    /// @notice THE WIRING PREDICATE. Reports whether the spec oracle can be reached.
    /// @dev Phase 1 always reports `TransportFailure`: there is no oracle. Callers MUST treat
    ///      that as "skip this comparison", NEVER as "spec rejected this input" - an
    ///      unreachable oracle masquerading as a rejection is exactly how a differential test
    ///      goes silently green. Callers MUST probe ONCE and cache (RED-06).
    ///
    ///      THIS IS NOT A BARE-STRING PING. It returns the full `Health` struct and rides the
    ///      SAME tagged envelope as `TokenIdResult`, deliberately: a simple-typed health method
    ///      would round-trip cleanly while the domain path was broken, which is a green that
    ///      proves nothing. "Wired" must mean the real envelope round-trips.
    function health() internal returns (Health memory) {
        return Health({
            status: Status.TransportFailure,
            specCommit: "",
            protocolVersion: 0,
            bridgeVersion: ""
        });
    }

    /// @notice Would return the Haskell spec's `tokenId` for this input.
    /// @param volOrderWire the serialized `VolOrder(T)`. OPAQUE in Phase 1 - the format is
    ///        Phase 4's decision (VORD-06) and nothing here may assume a layout.
    /// @param poolId the 64-bit Panoptic pool id occupying tokenId bits 0..63.
    /// @return PHASE 1: unreachable. This function always reverts - see the fail-safe note above.
    function volOrderToTokenId(bytes memory volOrderWire, uint64 poolId)
        internal
        returns (TokenIdResult memory)
    {
        revert SpecOracleNotWired(volOrderWire, poolId);
    }
}

/// @notice The HAND-WRITTEN external call boundary around the seam. NOT generated, and it
///         survives Phase 7 unchanged.
/// @dev A library's `internal` functions are INLINED into the caller, so a revert inside
///      `SpecOracle` would abort the calling test rather than being observable. Routing through
///      a real external call is what makes the Phase 1 stub's revert assertable with
///      `vm.expectRevert`, and what lets a caller OBSERVE "not wired" instead of dying of it.
///
///      Phase 7 keeps this boundary for a sharper reason: a JSON-RPC transport fault arrives as
///      a cheatcode REVERT carrying untyped free text, and a revert must be catchable across a
///      real call boundary before it can be converted into `Status.TransportFailure`. Dropping
///      the boundary now would only mean Phase 7 reintroducing it.
///
///      CALLERS SHOULD REACH THIS WITH A LOW-LEVEL `address(probe).call(...)` RATHER THAN
///      `try`/`catch`. Whether `try`/`catch` behaves against a cheatcode-originated revert is an
///      OPEN question (it performs an `extcodesize` check against the cheatcode address); the
///      low-level form sidesteps it (RED-06 transport boundary).
contract SpecHelperProbe {
    function health() external returns (SpecOracle.Health memory) {
        return SpecOracle.health();
    }

    function volOrderToTokenId(bytes calldata volOrderWire, uint64 poolId)
        external
        returns (SpecOracle.TokenIdResult memory)
    {
        return SpecOracle.volOrderToTokenId(volOrderWire, poolId);
    }
}
