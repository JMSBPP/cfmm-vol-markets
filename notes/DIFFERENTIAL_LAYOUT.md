# DIFFERENTIAL LAYOUT — the Haskell↔Plank differential's organization (RED-06)

Binding, in the same sense as `notes/DATA_CONTRACT.md` and `notes/UNITS_AND_SCALES.md`. It is
cited by path from `test/protocol_integrations/SpecHelper.sol` and from the header of
`test/protocol_integrations/VolOrderToPanopticTokenId.diff.t.sol`, which is why it lives here
rather than under `.planning/`.

## Scope

This document fixes the *organization* of the Haskell↔Plank differential: where the files live,
what they are called, where the process boundary between the Foundry test and the executable
specification sits, which behaviours of that boundary have been MEASURED rather than assumed, and
which outcomes must stay distinguishable for the comparison to mean anything. It fixes shape, not
content. It does NOT choose the `VolOrder(T)` wire format (Phase 4 owns that) and it does NOT
choose how the Haskell oracle is packaged (Phase 6 owns that). Phases 6 through 11 are expected to
extend this organization; a phase that finds it inadequate amends this file and says why.

## File layout and naming

| Path | Role |
|------|------|
| `test/protocol_integrations/VolOrderToPanopticTokenId.diff.t.sol` | the differential itself |
| `test/protocol_integrations/SpecHelper.sol` | the ONLY Solidity↔spec seam |
| `test/protocol_integrations/VolOrderToPanopticTokenIdHarness.plk` | the impl-side entrypoint |
| `test/protocol_integrations/VolOrderToPanopticTokenId.t.sol` | the structural suite; the REGRESSION FLOOR |
| `notes/DIFFERENTIAL_LAYOUT.md` | this document |

Naming rules, binding for every differential added to this family:

- `*.diff.t.sol` is this repo's established differential-test suffix. The existing family members
  are `test/pos_spec/VolOrderManager.diff.t.sol`,
  `test/market_state_measurements/RealizedVolatility.diff.t.sol`,
  `test/market_state_measurements/GetAverageVolatility.diff.t.sol` and
  `test/exposure/VegaIssuance.diff.t.sol`. New differentials join that suffix; they do not invent
  one.
- A `.diff.t.sol` sits in the SAME directory as the subject it diffs and as that subject's
  `*Harness.plk`, so the three are read together and a rename cannot separate them.
- The differential test contract is `<Subject>DiffTest`; the structural suite is `<Subject>Test`.
  Here: `VolOrderToPanopticTokenIdDiffTest` and `VolOrderToPanopticTokenIdTest`.
- Each `.diff.t.sol` gets a `make` target named `test-<subject>-diff`, matching the existing
  `test-vol-order-diff` / `test-realized-vol` convention. This file's target is
  `test-vol-order-tokenid-diff`.

## The Solidity<->spec transport boundary

Stated as rules, because each of them is load-bearing for the comparison rather than stylistic.

- `test/protocol_integrations/SpecHelper.sol` is the ONLY place a Foundry test may reach the
  Haskell spec. No test spawns a process, reads a spec-produced file, or aims a cheatcode at the
  spec directly. One seam is what makes the transport replaceable in Phase 7 without touching any
  test body.
- The seam is the library `SpecOracle`. It has exactly two methods:
  `health() -> Health` and `volOrderToTokenId(bytes volOrderWire, uint64 poolId) -> TokenIdResult`.
- The Phase 1 draft's `readTokenId(uint256,uint256,uint256[4])` and its SEPARATE `isWired()` probe
  were REPLACED by those two. The names now follow the interface the bridge generates, and
  `isWired()` COLLAPSED INTO `health()` because two wiring mechanisms are two things that can
  drift, and the wiring predicate is the one thing that must not. RED-04 is satisfied in
  substance — a stub that reverts when called, plus a wiring predicate the test queries first —
  under the generated names rather than the drafted ones. The roadmap's Phase 7 criterion still
  says `readTokenId`; it means this seam.
- `SpecHelperProbe` is the external call boundary around the library, and it is HAND-WRITTEN, not
  generated. It exists because a Solidity library's `internal` functions are inlined, so a revert
  inside the seam would abort the calling test rather than being observable. Phase 7 keeps it for
  a sharper reason recorded in `## Transport mechanics: measured constraints` below: a transport
  fault arrives as a REVERT, and a revert must be catchable across a real call boundary before it
  can be converted into `Status.TransportFailure`.
- Callers reach the boundary with a LOW-LEVEL `address(probe).call(...)`, not `try`/`catch` — see
  the open questions for why the low-level form assumes strictly less.
- The input crossing the boundary is Plank-originated. Plank is the fuzz source; the serialized
  `VolOrder(T)` is TRANSPORTED, never reconstructed independently on the Haskell side. Two
  independently constructed corpora would drift, and a differential over two drifting corpora
  tests nothing.
- `volOrderWire` is OPAQUE at this boundary. Phase 4 chooses the format; nothing else about the
  seam's shape changes when it does, because `bytes` is the parameter type precisely so that the
  choice lands in the encoder.
- `TokenIdResult.detail` is diagnostics ONLY and is NEVER asserted on, in this phase or any later
  one. It is free text from the far side; asserting on it couples the test to prose.

## The generated interface boundary

- `evm-spec-bridge` (canonical `d2p-finance/evm-spec-bridge`, `JMSBPP` fork, PR-only, like every
  repo in this ecosystem) enters this repo as a SUBMODULE. It is a Haskell library plus a JSON-RPC
  server executable, it depends on `cfmm-vol-markets-spec`, and it **generates the Solidity interface** from the
  same schema as its Haskell protocol types. Drift between the two sides is
  prevented BY CONSTRUCTION, not by review.
- Phase 1's `SpecOracle` in `test/protocol_integrations/SpecHelper.sol` is a **PROVISIONAL
  HAND-WRITTEN STAND-IN** for that generated artifact — the shape, and nothing else. Phase 7
  replaces it with the generated file and adopts whatever the generator emits. Where the two
  differ, the generator wins and the difference is recorded in this document.
- Two arrangements in Phase 1 are explicitly PROVISIONAL-PENDING-GENERATION:
  1. `Status` lives as a FIELD on `Health`, rather than `health()` returning a `(Status, Health)`
     pair. Either is defensible; the generator decides.
  2. The Phase 1 stub REVERTS rather than returning a `TransportFailure` struct. This is a
     property of the STUB only, and it is deliberate: a struct-returning stub is FAIL-OPEN, and a
     test that forgot to check `status` would proceed with `tokenId == 0` — precisely the
     false-green class this milestone exists to eliminate. The revert is FAIL-SAFE and is the
     backstop for anyone who bypasses the wiring predicate. Phase 7's real implementation RETURNS
     the tagged struct, including `Status.TransportFailure`, and does not revert.
- **Spec version must have ONE authority.** The bridge depends on `cfmm-vol-markets-spec` and this
  repo pins `spec/` directly — two paths to the oracle. Divergence breaks nothing and fails
  nothing, so the differential would compare Plank against a spec version nobody believes is the
  oracle and stay green. That is worse than a red, because the milestone's whole premise is that
  disagreement fails the build. Mitigation is mandatory: `Health.specCommit` reports the SHA the
  RUNNING BINARY was built from — not the SHA anyone believes it was built from — and Phase 5
  (RPC-03) asserts it equals this repo's `spec/` pin, failing loudly. Preferred topology if the
  bridge supports it: pin only the bridge, and let it be the single authority on the spec version.
- EXPECTED FUTURE METHODS, named now and NOT implemented in Phase 1: `spec_fixtureRejection`
  (returns a canned rejection) and `spec_fixtureTransportFault` (forces a transport error). Naming
  them here is what lets Phase 7 extend rather than redesign: the three-way outcome contract below
  is untestable without a way to provoke each of the three on demand.

## Transport mechanics: measured constraints

**All findings below are measured against `forge 1.5.1-stable` (`b0a9dd9`)**, the pin recorded in
`.github/foundry-version` and justified in `notes/TOOLCHAIN_PINS.md`. v1.8.0 encodes cheatcode
returns differently, so a pin bump invalidates these numbers until they are re-measured — see the
open risks and section 6 of `notes/TOOLCHAIN_PINS.md`. Each item below is a binding constraint
carried together with the measurement that produced it, because **a rule with its evidence
attached survives; a bare rule gets "simplified" away**, and each of these, simplified away,
reintroduces a false green.

1. **Every call site MUST bind its success flag and check it before touching the returned bytes.**
   MEASURED: a server that accepts the connection and never answers costs **45.00 s per call**,
   and **the test PASSED** — because the call site ignored `success`. At `fuzz.runs = 256` that is
   **3.2 hours of green CI meaning nothing**: this project's founding failure mode, reproduced
   against the transport we chose. Connection-refused fails fast; a half-dead server is far worse
   than a dead one, and there is no timeout knob (see 5).

2. **Spec rejection MUST ride the HTTP-200 `result` channel as a tagged value. The JSON-RPC
   `error` field is reserved exclusively for transport and protocol faults** (unknown method, bad
   params), which revert. MEASURED: `fork.rs:599-604` maps any provider error to `Err`;
   `inspector.rs:1443-1453` turns a cheatcode `Err` into `InstructionResult::Revert`;
   `error.rs:137-142` encodes it as `Vm::CheatcodeError { message: string }` — **untyped free
   text**. A JSON-RPC error object, HTTP 500, connection-refused, the timeout, and calling a
   cheatcode the binary lacks ALL revert with the same selector `0xeeaa9e6f`, differing only in
   unstable English. **The three-way distinction can therefore NEVER be recovered by matching
   selectors or parsing revert messages.** It exists only because rejection rides `result` with a
   tag. This is the mechanism XPORT-02 and Phase 9 depend on.

3. **The result MUST travel as ONE `"0x"`-prefixed, even-nibble hex string carrying a tag byte
   plus our own ABI encoding. This is the single highest-value constraint in the design.**
   MEASURED, three ways: `vm.rpc` runs the JSON `result` through `json_value_to_token`, where
   objects become tuples in **alphabetical key order**, numbers round-trip through `f64`, and
   `null` becomes 32 zero bytes; and the coercion is **VALUE-DEPENDENT** — the same record shape
   decodes to `tuple(string,string,string)` for `tokenId "0"` but `tuple(string,string,uint256)`
   for `tokenId "18446744073709551616"`, so a decoder correct for one is wrong for the other,
   intermittently, by input magnitude, across a fuzz campaign — and it would present as a Plank
   divergence. `"0x<even-nibble hex>"` is the only branch with no coercion, no reordering and no
   magnitude sensitivity. **A later phase must not "simplify" this into returning a JSON object.**

4. **NEVER write `bytes memory b = vm.rpc(...)` then `abi.decode(b, ...)`.** MEASURED on 1.5.1:
   static-coerced results give a bare un-messaged `EvmError: Revert`, and **object results
   silently return garbage with `b.length == 96`**. Silent garbage into `abi.decode` is the worst
   possible shape for this project. It is also version-dependent, so it is not a stable contract
   even where it appears to work.

5. **Timeouts and retries are HARDCODED and unconfigurable.** MEASURED: `rpc_result` builds its
   provider via `ProviderBuilder::new`, **not** `from_config`, so the 45 s `REQUEST_TIMEOUT`, the
   `max_retry` of 8 and the 800 ms `initial_backoff` cannot be tuned — neither the
   `eth_rpc_timeout` config key nor a per-endpoint `retries` key reaches this code path, and both
   are named here only so nobody spends a day discovering that. **There is no tuning knob; do not
   go looking for one.** Retries fire only on HTTP 429/503.

6. **Probe the wiring ONCE per test contract, in `setUp`, and cache it.** Every skip reads the
   cache; no test body calls the wiring predicate. Rationale, stated accurately: (a) hygiene — one
   wiring decision per contract rather than N identical ones; (b) insurance against the residual
   risk in (1), a hung server at a hardcoded 45 s per call. **It is NOT justified by a retry
   storm** — that justification is known to be false, since connection-refused fails fast. The
   inaccurate rationale is recorded as inaccurate so it is not re-adopted.

7. **The wiring predicate returns the SAME envelope as a domain method.** MEASURED: `"ok"` is a
   `string`, one of the few shapes that decodes cleanly — so a bare-string health check would
   round-trip green while the domain payload path was broken. "Wired" must mean **the real
   envelope round-trips**, so the predicate carries the full `Health` struct through the same
   tagged hex envelope as `TokenIdResult`.

8. **Address the oracle as `http://127.0.0.1:PORT`.** Alloy's `guess_local_url` recognises only
   `localhost`, `127.0.0.1` and `::1`; any other host form (a container name, a `.local` alias) is
   not treated as local, and `HTTP_PROXY` is then honoured — a bizarre failure mode on a proxied
   self-hosted runner.

9. **The cheatcode is `vm.rpc`, the three-argument form `vm.rpc(url, method, params)`.
   NOT `vm.rpcJson`.** VERIFIED FROM SOURCE: `rpc_result` calls
   `ProviderBuilder::<AnyNetwork>::new(url).build()` then `provider.raw_request(method, params)` —
   **no allowlist, no `eth_*` check, no namespace filter, no node handshake**; `rpc_endpoint`
   accepts any string beginning `http`/`ws`; and `rpc_1Call` is `apply`, not `apply_stateful`, so
   the three-arg form needs **no fork, no anvil and no `[rpc_endpoints]` entry** — a literal URL
   works in plain `forge test`. `vm.rpcJson` was merged 2026-06-05 (PR #15076) and ships only in
   v1.8.0, published 2026-08-27; the pinned toolchain is 1.5.1-stable, so it does not exist here,
   and adopting a same-day release to obtain one convenience cheatcode would be reckless.

10. **`[rpc_endpoints]` `${...}` alias resolution is LAZY — it happens at alias USE, not at config
    load.** MEASURED with the variable unset: `forge build` exits 0, `forge config` succeeds and
    stores the literal `"${EVM_SPEC_BRIDGE_URL}"` uninterpolated, unrelated suites pass, and only
    a test that uses the alias fails, with a self-describing message that does not spread. The
    alias is therefore safe to add before anything can answer on it.

## Outcome contract: three states, never conflated

| Outcome | Carried as | May it ever look like agreement? |
|---------|-----------|----------------------------------|
| spec success | `Status.Ok` + `tokenId`, in the `result` channel | it IS the comparison |
| spec rejection | `Status.Rejected` + `Guard`, in the `result` channel | no — it is compared against Plank's revert-vs-return (Phase 9, GUARD-05) |
| transport failure | `Status.TransportFailure`, produced by catching the cheatcode revert at the boundary | no — and it must never be reported as a rejection either |

An unreachable oracle reported as a rejection, or a rejection reported as agreement, is how a
differential test goes silently green; distinguishing the three is therefore a correctness
requirement, not ergonomics.

The distinction is only ACHIEVABLE because of constraint 2 above. The dependency is recorded
explicitly so that nobody later moves rejections onto the JSON-RPC `error` channel and destroys
it: every fault channel collapses into one untyped `CheatcodeError(string)`, and there is no
recovery from that collapse.

Stable `Guard` ids and their requirement mapping, generated from the spec's guard set and asserted
on by Phase 9:

| `Guard` | Requirement |
|---------|-------------|
| `None` (the zero value, so a defaulted struct never names a real guard) | — |
| `OptionRatioRange` | GUARD-01 |
| `LegSpanBelowSpacing` | GUARD-02 |
| `TickOutOfBounds` | GUARD-03 |

The shared-guard alignment requirement is GUARD-04; revert-vs-return parity over
`TokenIdResult.guard` is GUARD-05.

## The wiring probe and its lifecycle

- **Phase 1.** `SpecOracle.health()` reports `Status.TransportFailure` because there is no oracle.
  The test probes it ONCE in `setUp`, through `SpecHelperProbe`, with a low-level call, decodes the
  full `Health` struct, caches the status, and the two differential tests `vm.skip` on the CACHED
  value. The reverting stub is never reached on that path; it is the backstop for anyone who
  bypasses the predicate.
- **Phase 7.** The predicate becomes a live transport health check against the bridge. **The
  predicate itself is unchanged** — `status == Status.TransportFailure` — which is the concrete
  meaning of "extend, not redesign". The skip still governs, because the spec is not on the CI
  runner until Phase 11.
- **Phase 11 (CI-04).** The probe and every `vm.skip` guarded by it are REMOVED. A deliberately
  unreachable oracle must then make `develop-gate` RED, not green-with-a-skip.

**The skip is computed by the test, never configured in the gate.** Adding
`*VolOrderToPanopticTokenId.diff.t.sol*` to the `--skip` ledger in
`.github/workflows/develop-gate.yml` would exclude the file from compilation and execution
entirely, so nobody would notice it rotting — that is FORBIDDEN for this file in every phase.
A self-computed skip means the gate compiles the file under `--via-ir` on every run and names it,
in the log, as skipped for a reason the file itself states. (`*PanopticVegaLens.t.sol*` is on that
ledger as a drafted RED test — that is precisely the mechanism this milestone declines to use.)

## Doctrine and discipline

The doctrine and the discipline are NOT restated here; they live in the header of
`test/protocol_integrations/VolOrderToPanopticTokenId.diff.t.sol`, next to the code they bind, and
they are binding on every differential added to this family: corpora are CONSTRUCTED with `bound`
and never filtered with `vm.assume`; every fuzz names a non-fuzz anchor; non-vacuity is ASSERTED
via a live counter rather than assumed.

The orientation in two sentences. NEITHER SIDE IS SACROSANCT: both the Haskell spec and the Plank
implementation are load-bearing, independently maintained artifacts, so a divergence is a finding
about EITHER of them — or about the two answering subtly different questions — adjudicated case by
case on the evidence, with the triggering input recorded before anything is changed. The forbidden
move is picking a winner by default and editing the loser to match, which converts a real finding
into a silent agreement. This is exactly where this file departs from
`test/pos_spec/VolOrderManager.diff.t.sol`, whose oracle is a disposable Solidity restatement and
whose reds are therefore always findings about the module.

One rule this document owns rather than points at: **spec rejections are NEVER routed through
`vm.assume`.** `max_test_rejects` is 65536 and SHARED across the run, so a rejection filtered that
way burns a global budget and is HIDDEN rather than observed — and rejection parity (GUARD-05)
needs rejections visible.

## Open decisions, open questions and open risks

**Spec transport is RESOLVED: JSON-RPC.** It was decided at `evm-spec-bridge` initialization,
**outside Phase 5**, by the user, knowingly overriding this project's "open by design, do not
pre-resolve" instruction; the agent flagged the conflict before acting and the user confirmed
directly. The override is stated plainly here rather than smoothed over, because Phase 5's success
criterion 1 requires it visible. Rationale for JSON-RPC over `vm.ffi`: a warm service avoids a
per-case process spawn across a 256-run fuzz and generalizes to the whole spec surface rather than
to one entrypoint. **RPC-01 now RECORDS that decision; it no longer makes it.**

Open DECISIONS — each owned by a phase, and NONE of them picked here:

| Decision | Owner | Constraint any answer must satisfy |
|----------|-------|-------------------------------------|
| `VolOrder(T)` wire format — Shock-style tagged vs per-variant | Phase 4 | a consumer must recover WHICH `T` it received from the bytes alone |
| Oracle packaging — new cabal exe vs a mode on `cfmm-scratchpad-exe` | Phase 6 | must be buildable on the self-hosted runner; GHC/cabal availability there is UNVERIFIED |
| RPC-02 — the responsibility split for wire encode/decode, input validation, guard evaluation and error classification | Phase 5 | no responsibility unassigned or shared by default; **the Foundry test process owns none of them** — any semantics it holds is a re-implementation of the spec, which is the failure this milestone exists to eliminate |

Open QUESTIONS — no owner yet; answer before Phase 7 relies on them:

| Question | Why it matters | Status |
|----------|----------------|--------|
| Does `try`/`catch` work against a cheatcode-originated revert? | it performs an `extcodesize` check against the cheatcode address. This is the LOWEST-confidence item in the transport analysis, and the entire three-way distinction rests on catching that revert | OPEN — mitigated by using a low-level `address(...).call(...)` at the boundary instead. Do not assert either way |
| Does an end-to-end round trip against a NON-Ethereum JSON-RPC server actually work? | `vm.rpc` accepting an arbitrary method string is verified from source, but a full round trip against a non-Ethereum server has **no known prior art** | OPEN — Phase 5's RPC-03 skeleton is what answers it |

Open RISKS:

| Risk | Evidence | Disposition |
|------|----------|-------------|
| Foundry toolchain drift on the persistent runner | Every measurement above is scoped to `1.5.1-stable` `b0a9dd9`; v1.8.0 encodes cheatcode returns differently. The `cfmm-build` runner is persistent, so its `forge` would drift on any `foundryup` typed on the box | **CLOSED as an open risk by Phase 1.1 (CI-05).** When this risk was first recorded, Foundry was UNPINNED here and the `/gsd:insert-phase` candidacy was live; that insertion HAPPENED. `.github/foundry-version` now pins the release, the commit and the foundryup installer, both workflows install it into a per-pin directory and assert `forge --version` contains the commit, and `notes/TOOLCHAIN_PINS.md` documents why. Residual, not closed: a pin BUMP silently invalidates every measurement above — `notes/TOOLCHAIN_PINS.md` §6 makes re-measurement part of the bump |
| A pin bump reclassifies wire behaviour without a named failure | the encoding change between 1.5.1 and 1.8.0 is known, not hypothetical | mitigated by the coercion-conformance fixture assigned to Phase 5 (RPC-03), which needs a responder and so cannot exist earlier. Three layers: the pin prevents, the version stamp reveals, the fixture fails |
| Spec-version skew via two paths to the oracle | see `## The generated interface boundary` | mitigated by `Health.specCommit` asserted against the `spec/` pin (RPC-03); mitigation is mandatory, not optional |
| CI ordering — a service transport means Phase 5 itself needs the runner to build AND RUN a Haskell process, while CI-01/CI-02 sit in Phase 11 | ROADMAP Sequencing Notes; GHC/cabal on `cfmm-build` is unverified | pull CI-01/CI-02 forward via `/gsd:insert-phase` rather than reordering silently. The RED-05 wiring probe does NOT cover this |

## Extension points, phase by phase

This table matches the `EXTENSION POINTS` natspec block in
`test/protocol_integrations/SpecHelper.sol`. If the two ever disagree, that is a defect in one of
them, not a choice.

| Phase | What changes | What does NOT change |
|-------|--------------|----------------------|
| 4 | `volOrderWire` becomes the `VolOrder(T)` wire bytes; the test's one placeholder encoder is replaced | the seam file, the seam signature, the probe, the outcome contract |
| 5 | the responsibility split is fixed (RPC-02) and the wiring predicate is proven end to end | the transport choice, the seam's shape |
| 6 | the Haskell gains an out-of-process entrypoint | nothing on the Solidity side |
| 7 | the generated library replaces the provisional stand-in; both bodies become real; the three outcomes become observable | the file, the probe boundary, the skip predicate, the doctrine |
| 8-9 | Plank gains guards; revert-vs-return parity is asserted over `TokenIdResult.guard` | the corpus discipline, the `Guard` ids |
| 10 | the fuzz corpus widens to the divergence-prone geometry | the anchor, the non-vacuity counter |
| 11 | the probe and every `vm.skip` are removed; the gate builds the spec | the layout in this document |

A phase that finds this organization inadequate should AMEND THIS DOCUMENT in its own branch and
say why, rather than diverging from it silently. Silent divergence between the layout and the code
is the same failure class as silent divergence between the spec and Plank, and it is caught by
nothing.
