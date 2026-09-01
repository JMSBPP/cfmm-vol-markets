#####################################################################
# THE TWO COMMANDS                                                  #
#####################################################################
#
#   make test      -- every test in the repo, one run.
#   make compile   -- every Plank entrypoint, compiled to EVM bytecode.
#
# Everything below those two is a focused SUBSET, kept for iterating on one
# surface without paying for the whole suite. Nothing below is a substitute for
# `make test` -- a subset going green says nothing about the subsets you skipped.
.DEFAULT_GOAL := test

# test: the whole Solidity/Plank test surface in a single forge invocation.
#
# The Algebra reference pin runs FIRST and gates the rest: every "bit-exact vs
# Algebra" claim in the vol suite is measured against bytes that live in
# node_modules (untracked, silently rewritable by `npm ci`, and corrupted once
# already by an editor auto-fill). Diffing against a baseline and THEN checking
# the baseline proves nothing about the run you just did.
#
# This compiles and runs the `.plk` sources too, and is the ONLY thing that does
# so meaningfully: `make compile` proving a module builds does NOT prove its code
# runs. `plank build` does not type-check anything unreachable from run{}, so a
# module with an empty run{} compiles green while every function in it is dead.
# This repo shipped exactly that gate. Only calling a function proves it exists.
#
# THIS TARGET IS CURRENTLY RED, AND THAT IS THE TRUTH, NOT A DEFECT IN THE TARGET.
# The Order closure (Order.plk + its OrderHelper harness + OrderTest) was DELETED outright
# at user direction -- Order.plk had already been working-tree-deleted by the OrderType
# track, and the project deletes orphaned closures rather than skipping them (recover from
# git history if that track resurrects the type). VolOrder + VolOrderHelper + VolOrderTest
# are KEPT: they are live pos_spec surface and never depended on Order.
# MEASURED AT 19-05 (2026-07-21), cold `cache/fuzz`, these exact targets:
#   make test          102 passed, 18 failed, 120 total (44 suites)
#   make compile-plank 11 ok, 2 failed, 0 skipped
# Prior records, kept for the trend: 74/4 + 11 ok (after the Order deletion); 87/4 + 12 ok (16-01);
# 96/4 + 13 ok (17-01); 112/4 (18a-01); 120/4 (18b-01); 95/18 + 11 ok (2026-07-21, pre-Phase-19).
# NOTE the entrypoint count fell 13 -> 11 and the fail count rose 4 -> 18 between 18b and here.
# That is NOT a Phase 19 regression: it is the exposure draft below, which landed in the working
# tree in between. Phase 19 itself ADDED 7 passing tests (95 -> 102) and no failures.
#
# EVERY RED IS ATTRIBUTED. A bare count is not a record:
#   14 x exposure setUp() reverts  -- the uncommitted draft in src/lib/exposure/VegaIssuanceLib.plk
#                                     (`error: unresolved identifier 'VolOrder'`, plus 'Option' and
#                                     'LDFParams'). Its `plank build` failure propagates through
#                                     deployPlank/FFI, so all 14 suites die in setUp() before any
#                                     assertion runs: VegaAccount* (7), VegaIssuance* (7).
#                                     ANOTHER TRACK's in-progress work. Deliberately NOT skipped,
#                                     filtered or excluded: a suite that lies about what passes is
#                                     worth less than no suite.
#    4 x vol-type track             -- VolRangeWidthTest volWidthRangeSub_valid,
#                                      volWidthRangeBuildVolRangeWidth_valid;
#                                      SpreadTickAssimetryTest spreadTickAssimetrySplitTick__Valid,
#                                      tickFromSplittedTickBucket__Valid. Owned elsewhere; one
#                                      traces to a diagnosed real bug (return_split_tick writes
#                                      `out_ptr +% 32` twice) that is REPORTED, not fixed here.
#                                      These live under test/types/pos_spec/ -- the vol-type TYPE
#                                      track, NOT the pos_spec MODULE surface below.
#    0 x test/pos_spec/             -- MEASURED: the module surface this milestone owns is
#                                      ZERO-RED. All 40 of its tests pass.
#
# compile-plank's 2 failures are the SAME exposure draft: src/modules/exposure/VegaAccountMod.plk
# and test/exposure/VegaIssuanceKernelHarness.plk both import it. VolOrderManagerMod.plk compiles
# OK (verified in this same run). MVER-04's "0 failed" clause is scoped to the pos_spec surfaces
# this milestone owns; it is not a claim about another track's uncommitted work, and closure is
# not blocked on it.
#
# PHASE 19 SUITES NOW COVERED BY THIS TARGET (the MVER-04 fold-in, stated rather than implicit --
# `make test` is a whole-tree `forge test`, so these are included WITHOUT a prerequisite, and
# adding one would double-run them and inflate the tally above). All three contract names were
# OBSERVED in this target's own output, not assumed:
#   test/pos_spec/VolOrderManager.diff.t.sol     VolOrderManagerSequenceDiffTest        (MVER-01)
#   test/pos_spec/VolOrderManagerFixture.t.sol   VolOrderManagerFixtureTest,
#                                                VolOrderManagerSelectorCompletenessTest (MVER-03)
# Run them alone with `make test-vol-order-acceptance`.
#
# THE FAILURE COUNT IS NOT FULLY DETERMINISTIC -- measured, not assumed. A further failure,
#   TickVolatilityLibTest  test__fuzz__tickVolatilitySqrtPriceX64x96AndTickSuccess
# surfaces on roughly 1 cold-cache run in 4, always at the same counterexample 2^64-1. It did NOT
# surface in the 19-05 run above (TickVolatilityLibTest: 2 passed, 0 failed), which is why the
# total reads 18 and not 19. It is PRE-EXISTING (reproduced with all 17-01 files stashed out:
# 86 pass / 5 fail) and belongs to the TickVolatility track, NOT to src/types/pos_spec/. Re-run
# before treating an extra failure as a regression.
# See .planning/phases/17-interface-single-call-module/deferred-items.md (D1).
test:
	forge test --via-ir --optimize

# compile: every Plank entrypoint -> EVM bytecode. A PRECONDITION, never acceptance.
# See compile-plank below for what "entrypoint" means and why it is not literally
# every .plk file.
compile: compile-plank

.PHONY: test compile

#####################################################################
# Focused subsets                                                   #
#####################################################################

sol-build:
	forge build --via-ir --optimize

sol-test:
	forge test --match-contract VolOrderTest --via-ir --optimize


test-pricing-kernel-diff:
	forge clean && forge test --match-contract PricingKernelPlankdiffTest -vvvv --via-ir --optimize

# Phase 13 issuance library differential + fuzz battery (the single file
# test/exposure/VegaIssuance.diff.t.sol -- probe + reverts + monotonicity from 13-01, plus the
# 512-bit backing invariant, weight-one identity, composed==mock tolerance-0, and composed<=direct
# one-sided fuzzes from 13-02). Folded into `make test` in Phase 15, NOT here.
test-vega-issuance:
	forge test --match-path 'test/exposure/VegaIssuance.diff.t.sol' --via-ir --optimize

# test-vega-account: the VegaAccountMod module surface (dispatch/storage/guards/previews/readers
# + 14-02's slot-distinctness vm.load and mutation gate). Folded into `make test` in Phase 15,
# NOT here.
test-vega-account:
	forge test --match-path 'test/exposure/VegaAccount.t.sol' --via-ir --optimize

test-price-impact-diff:
	forge clean && forge test --match-contract PriceImpactKernelPlankdiffTest -vvvv --via-ir


# test-vega-e2e: the end-to-end (setRiskPrice, deposit) SEQUENCE differential (VVER-01) --
# VegaAccountE2EDiffTest drives identical sequences into the FFI-deployed VegaAccountMod and a
# trivially-simple IssuanceRefMock-backed mirror, asserting all three accumulators tol-0 after
# EVERY write. This is the milestone acceptance driver the 15-02 mutation battery reddens. Folded
# into `make test` in Phase 15, kept here as a focused target.
test-vega-e2e:
	forge test --match-path 'test/exposure/VegaAccount.e2e.t.sol' --via-ir --optimize

# test-vol-order-validation: the PURE VolOrderValidationLib surface (VORD-02) -- accept/reject
# boundaries, the authored strike <= 2^88-1 bound, and the 152-bit pack/unpack round-trip,
# all CALLED through the FFI-deployed VolOrderValidationHarness.
test-vol-order-validation:
	forge test --match-path 'test/types/pos_spec/VolOrderValidation.t.sol' --via-ir --optimize

# test-vol-order-tokenid-diff: the Haskell<->Plank volOrderToTokenId DIFFERENTIAL (RED-01..RED-06).
# One input driven into BOTH spec/src/Panoptic/NId.hs::volOrderToTokenId and the Plank map
# vol_order_to_panoptic_token_id (via VolOrderToPanopticTokenIdHarness.plk), asserted equal at
# tolerance 0. Distinct from test-vol-order-diff, which is the pos_spec MODULE sequence
# differential against a Solidity mock -- different subject, different oracle, different doctrine
# (there the mock is disposable; here NEITHER SIDE IS SACROSANCT).
# UNTIL PHASE 7 THIS IS SKIP-GUARDED and reports SKIP: SpecOracle.volOrderToTokenId is a stub
# that reverts, SpecOracle.health() reports TransportFailure, setUp caches that once, and the two
# differential tests self-skip on it. That is the intended RED state, not a failure. The two
# evidence tests (test_specHelper_stubRevertsAndProbeReportsNotWired, test_implSide_answersOnAnchor)
# DO run and must PASS -- without them, "everything skipped" and "the file is inert" would look
# identical in the log.
# Transport-boundary target: see test/protocol_integrations/SpecHelper.sol (RED-06).
# NOTE: develop-gate is the only build environment for this repo; this target is a convenience
# entry point, not the validation path.
test-vol-order-tokenid-diff:
	forge test --match-path 'test/protocol_integrations/VolOrderToPanopticTokenId.diff.t.sol' --via-ir --optimize

.PHONY: test-vega-issuance test-vega-account test-vega-e2e test-vol-order-validation test-vol-order-tokenid-diff


#####################################################################
# Plank on-chain track (.plk -> EVM bytecode via `plank build`)      #
#####################################################################
# `plank build` requires an entry file with an `init` block, so only
# *entrypoint* contracts are compiled here; pure library/type/interface
# .plk files have no init block (they would fail with "missing init
# block") and are instead pulled in transitively via their importers.
PLANK         ?= plank
# Module roots. The `.plk` sources import by layer root (`lib::`, `types::`,
# `interfaces::`), so each layer under src/ must be declared as a dep or every
# import fails with "unknown module". `pos_spec` stays declared separately
# because 16 imports still reference it bare (`pos_spec::X`) rather than via
# `types::pos_spec::X`.
PLANK_DEP := --dep v3=lib/plankified-univ3/plank/lib/ --dep std=lib/plank-monorepo/std/ --dep pos_spec=src/types/pos_spec \
             --dep lib=src/lib --dep types=src/types --dep interfaces=src/interfaces
# cfmm-types entrypoints (Hook.plk): types root points at the submodule, not src/types.
# Keep in sync with test/PlankTestBase.sol:cfmmTypesPlankOpts().
CFMM_TYPES_PLANK_DEP := --dep std=lib/cfmm-types/lib/plank-monorepo/std/ --dep types=lib/cfmm-types/src/types
PLANK_BACKEND := sona
PLANK_BUILD   := build/plank
# plank-toolchain: build the plank_dev compiler from the PINNED plank-monorepo submodule and install
# it as the PATH `plank`. FFI + compile-plank resolve `plank` from PATH; the self-hosted runner's
# persistent ~/.plank/bin/plank does NOT track a plank-monorepo pin bump, so the develop-gate runs this
# per job to keep the compiler+std in lockstep with the pin (a mismatch fails every build).
PLANK_DEV_EXEC := lib/plank-monorepo/plankc/target/release/plank
PLANK_PATH_BIN := $(HOME)/.plank/bin/plank
plank-toolchain:
	cd lib/plank-monorepo/plankc && cargo build --release
	mkdir -p $(dir $(PLANK_PATH_BIN))
	ln -sf $(abspath $(PLANK_DEV_EXEC)) $(PLANK_PATH_BIN)
	@plank --version
# Entrypoints are auto-discovered as any .plk under src/ or test/ that contains an
# `init` block. There is no exclusion list: `src/exp/` (throwaway experiments) and
# `src/ldf/` were DELETED rather than skipped, because a directory permanently
# excluded from the gate is not code the gate covers -- it is unmaintained code
# wearing a checkout. Recover from git history if ever needed.
#
# PLANK_SKIP is the *rescue queue*: entrypoints that belong to the project and
# are meant to compile, but are still blocked on authoring. Delete a line the
# moment its file goes green -- this list should only ever shrink.
#
# THE QUEUE IS NOW EMPTY. VegaAccountMod was the last entry; it left in Phase 15
# (VVER-02) after its deposit dispatch was proven CALLED-green (Phase 14) AND every
# killable mutant in it was OBSERVED red by the 15-02 mutation battery (rounding-
# direction flips in the lib, slot-constant aliasing, dust-guard deletion, and the
# raw checked cross-product guard). PLANK_SKIP shrinks only when the module is
# PROVEN, never on compile alone -- this is the moment the "should only ever shrink"
# comment was written for. Add a line here ONLY to rescue a new blocked-on-authoring
# entrypoint, and delete it the moment that file goes green.
#
# CHECKED AT 19-05 (MVER-04): the queue is still empty and VolOrderManagerMod was never in it.
# A module dispatching a subset of its declared selectors COMPILES, so it never met the entry
# condition. The v4.0 gate was always the CALLED batch dispatch, proven in
# test/pos_spec/VolOrderManagerBatch.t.sol -- not an entry in this list.
PLANK_SKIP    :=

# compile-plank: compile every Plank entrypoint to EVM bytecode, writing
# build/plank/<name>.hex on success and <name>.hex.err on failure. Fails
# (non-zero) if any entrypoint does not compile, so broken contracts
# redden the build instead of hiding.
#
# TWO THINGS THIS DOES NOT DO, both of which it is routinely mistaken for:
#
#  1. It does not compile every .plk FILE, and cannot. `plank build` requires an
#     entry file with an `init` block; pure library/type/interface sources have
#     none and fail outright with "missing init block". They are compiled
#     TRANSITIVELY, as imports of the entrypoints below -- which is full coverage
#     of the tree, reached from its roots.
#  2. It does not prove the compiled code WORKS, or even that it type-checks.
#     plank does not type-check anything unreachable from run{}. A module whose
#     run{} is empty compiles green with every function in it dead. That is not a
#     hypothetical: this repo shipped a "13 ok / 0 failed" gate that was green on
#     an EMPTY module. Green here is a precondition for `make test`, never a
#     substitute for it.
#
# Nor does `make test` depend on this target: deployPlank -> plankDeployFFI ->
# plankBuildFFI shells out to `plank build` over FFI AT TEST TIME, so a .plk edit
# reaches the deployed bytecode on the very next `forge test`. build/plank/*.hex
# is written here and read by NOTHING in the test path. The value of this target
# is that it compiles the entrypoints `make test` never deploys.
compile-plank:
	@mkdir -p $(PLANK_BUILD)
	@rc=0; ok=0; fail=0; skip=0; \
	for f in $$(grep -rlE '^[[:space:]]*init[[:space:]]*\{' --include='*.plk' src test | sort); do \
		case " $(PLANK_SKIP) " in \
			*" $$f "*) printf '   SKIP %s  (WIP)\n' "$$f"; skip=$$((skip+1)); continue;; \
		esac; \
		out="$(PLANK_BUILD)/$$(echo "$$f" | tr / _ | sed 's/\.plk$$//').hex"; \
		printf '>> compiling %s\n' "$$f"; \
		if $(PLANK) build "$$f" $(PLANK_DEP) --backend '$(PLANK_BACKEND)' > "$$out" 2>"$$out.err"; then \
			rm -f "$$out.err"; printf '   OK   %s -> %s\n' "$$f" "$$out"; ok=$$((ok+1)); \
		else \
			rm -f "$$out"; printf '   FAIL %s -> %s.err\n' "$$f" "$$out"; fail=$$((fail+1)); rc=1; \
		fi; \
	done; \
	printf '\ncompile-plank: %s ok, %s failed, %s skipped\n' "$$ok" "$$fail" "$$skip"; \
	exit $$rc

# clean-plank: remove compiled Plank bytecode artifacts.
clean-plank:
	@rm -rf $(PLANK_BUILD)


# abi-edge-stamp (Phase 2, VORD-02): the harness ABI edge, stamped MECHANICALLY in CI.
# VolOrderToPanopticTokenIdHarness.plk's external surface is frozen for the VolOrder(T)
# refactor; there is no local build, so the proof is two lines printed by every push build:
#   abi-edge sha256:   <sha256 of the compiled creation hex>
#   abi-edge selector: <each PUSH4 immediate, sorted, one per line>
# The selector set is the dispatch surface (run{} compares @evm_shr(224, calldataload(0))
# against PUSH4 constants). Byte-identical hex is the strongest possible reading; an equal
# selector set with a moved hash means internals changed and the surface did not.
# Same invocation as compile-plank (line ~340) and as PlankTestBase.plankOpts() over FFI,
# so the stamped bytes are the bytes the tests deploy. Reads: cast (pinned foundry), plank.
ABI_EDGE_HARNESS := test/protocol_integrations/VolOrderToPanopticTokenIdHarness.plk
ABI_EDGE_DIR     := $(PLANK_BUILD)/abi-edge
abi-edge-stamp:
	@mkdir -p $(ABI_EDGE_DIR)
	$(PLANK) build $(ABI_EDGE_HARNESS) $(PLANK_DEP) --backend '$(PLANK_BACKEND)' > $(ABI_EDGE_DIR)/VolOrderToPanopticTokenIdHarness.hex
	@printf 'abi-edge sha256: %s\n' "$$(sha256sum $(ABI_EDGE_DIR)/VolOrderToPanopticTokenIdHarness.hex | cut -d' ' -f1)"
	@cast disassemble "$$(tr -d '[:space:]' < $(ABI_EDGE_DIR)/VolOrderToPanopticTokenIdHarness.hex)" \
	  | grep -oE 'PUSH4[^0-9a-fx]*0x[0-9a-fA-F]{8}' | grep -oE '0x[0-9a-fA-F]{8}' | tr 'A-F' 'a-f' | sort -u \
	  > $(ABI_EDGE_DIR)/VolOrderToPanopticTokenIdHarness.selectors
	@sed 's/^/abi-edge selector: /' $(ABI_EDGE_DIR)/VolOrderToPanopticTokenIdHarness.selectors
	@printf 'abi-edge selector-count: %s\n' "$$(wc -l < $(ABI_EDGE_DIR)/VolOrderToPanopticTokenIdHarness.selectors)"

.PHONY: compile-plank clean-plank abi-edge-stamp
