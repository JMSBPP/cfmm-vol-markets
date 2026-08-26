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
test: check-algebra-ref-pin
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

# The Solidity oracle references (Algebra + UniV3). This is the baseline the Plank
# differential test diffs against, so it must be green before that work means anything.
test-market-statistics:
	forge test --match-contract MarketStatisticsTest --via-ir --optimize

# The WHOLE realized-volatility differential suite -- all five contracts, which now live in the
# single file test/market_state_measurements/RealizedVolatility.diff.t.sol:
#
#   RealizedVolatilityKernelProbeTest    the kernel pair on ONE point, vs a hand-derived anchor
#   RealizedVolatilityKernelDiffTest     VDIFF-02: the 5-D kernel fuzz, full uint256, tolerance 0
#   RealizedVolatilitySmokeTest          the module deploys, dispatches, and each past bug is
#                                        falsifiable
#   RealizedVolatilityDiffTest           Algebra vs UniV3 vs Plank on the TICK surface
#   RealizedVolatilityTimepointDiffTest  VDIFF-04: Algebra vs Plank on the VARIANCE surface,
#                                        asserted after EVERY write
#
# `make compile` passing proves NONE of this -- see the note on `test` above.
test-realized-vol:
	forge test --match-path 'test/market_state_measurements/RealizedVolatility.diff.t.sol' --via-ir --optimize

# The Algebra reference the whole differential exercise is measured against lives in
# node_modules -- untracked (.gitignore:2) and silently rewritten by `npm ci`. It was already
# corrupted once by an editor auto-fill (tickCumulative -> tickC umulative). This pins the whole
# 4-file import closure the harness links, NOT just VolatilityOracle.sol: pinning one file of a
# closure is false assurance. Red here means the baseline moved -- every "bit-exact vs Algebra"
# claim downstream is void until it is restored or deliberately re-pinned.
check-algebra-ref-pin:
	@bash scripts/check-algebra-ref-pin.sh

# Everything that must be green for the oracle: the pinned baseline refs, then the whole vol
# suite. The pin runs FIRST: verifying the baseline after diffing against it proves nothing.
test-vol-prereqs: check-algebra-ref-pin test-market-statistics test-realized-vol

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

# test-vol-order-manager: the VolOrderManagerMod MODULE surface (VORD-01/03/04/05) -- create_order
# dispatch, the two keccak-derived slots, the unmasked derived-slot store, monotonic ids, the
# state-asserted invalid-tuple guard, both readers with the zero sentinel, and the selector +
# slot-distance conformance checks. Distinct from test-vol-order-validation, which owns the PURE
# lib surface (Phase 16). One file per surface.
test-vol-order-manager:
	forge test --match-path 'test/pos_spec/VolOrderManager.t.sol' --via-ir --optimize

# test-vol-order-batch: the create_orders BATCH surface (MCAL-01/02/03/04/06) -- the three calldata
# guards, MAX_BATCH, per-tuple validate-then-skip with contiguous ids, batch-of-1 equivalence and
# the N=0 no-op. Distinct from test-vol-order-manager, which owns the SINGLE-CALL surface: this file
# needs hand-rolled MALFORMED calldata over low-level .call, which a typed interface cannot express.
test-vol-order-batch:
	forge test --match-path 'test/pos_spec/VolOrderManagerBatch.t.sol' --via-ir --optimize

# test-vol-order-return: the hand-rolled (bool,uint256)[] RETURN ENCODER (MCAL-05) -- head 0x40,
# stride 0x40, total 64+64N, the N=0 64-byte edge, canonical bools, (false,0) failures and the
# N=128 allocation probe, all compared BYTE FOR BYTE against solc's standard abi.encode. Distinct
# from test-vol-order-batch, which owns the INPUT half (guards, MAX_BATCH, state effects).
test-vol-order-return:
	forge test --match-contract VolOrderManagerReturnEncodingTest --via-ir --optimize

# test-vol-order-diff: the MVER-01 after-every-write SEQUENCE DIFFERENTIAL. Interleaved
# (create_order | create_orders) sequences driven into the FFI-deployed module AND an independent
# Solidity reference mock, asserting orderCount, every stored packed word via raw vm.load + the
# single VolOrderDecoder, and raw return-byte equality against solc's STANDARD abi.encode -- at
# tolerance 0, after EVERY write. Distinct from test-vol-order-batch and test-vol-order-return,
# which test the two entrypoints in ISOLATION: the interleave is the one thing they structurally
# could not cover, and it is where an id-allocation disagreement between the two paths surfaces.
test-vol-order-diff:
	forge test --match-path 'test/pos_spec/VolOrderManager.diff.t.sol' --via-ir --optimize

# test-vol-order-fixture: the MVER-03 CONSUMER GOLDEN FIXTURE. The module's returndata compared
# byte-for-byte against bytes produced by `cast abi-encode` (alloy) -- an encoder OUTSIDE this
# repo and a different implementation from solc's -- plus the selector-completeness gate over
# every `signature::` string in src/interfaces/pos_spec/VolOrderManagerInterface.plk.
# SCOPE LIMIT, recorded so the exit record cannot conflate two claims: alloy confirms the bytes
# are STANDARD ABI. It does NOT exercise the Haskell consumer's decoder. That gap is tracked as a
# per-case placeholder inside the fixture file itself.
test-vol-order-fixture:
	forge test --match-path 'test/pos_spec/VolOrderManagerFixture.t.sol' --via-ir --optimize

# test-vol-order-acceptance: THE PHASE 19 ACCEPTANCE BAR (MVER-01/03/04) in one invocation --
# the whole pos_spec surface: validation lib, single-call module, batch input, return encoder,
# sequence differential and consumer fixture. This is the dedicated target MVER-04 asks for.
#
# IT IS A SUBSET, NEVER A SUBSTITUTE FOR `make test`. Green here says nothing about the suites it
# skips, and MVER-02's mutation evidence is not reproducible from any target -- it lives in
# .planning/phases/19-*/19-MUTATION-BATTERY.md as recorded OBSERVATIONS.
test-vol-order-acceptance: test-vol-order-validation test-vol-order-manager test-vol-order-batch test-vol-order-return test-vol-order-diff test-vol-order-fixture

.PHONY: check-algebra-ref-pin test-market-statistics test-realized-vol test-vol-prereqs test-vega-issuance test-vega-account test-vega-e2e test-vol-order-validation test-vol-order-manager test-vol-order-batch test-vol-order-return test-vol-order-diff test-vol-order-fixture test-vol-order-acceptance


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
             --dep lib=src/lib --dep types=src/types --dep interfaces=src/interfaces \
             --dep helpers=test/protocol_integrations/helpers \
             --dep model_interfaces=src/models/mev_tax_model_one/interfaces/ \
             --dep model_libraries=src/models/mev_tax_model_one/libraries/
# ^ `helpers`: test-only Plank helper libs (PriceUpdateLogWithSwap) that a src module's
#   TEST-oriented entrypoint (PriceSetterHook.write_price) imports. Kept in sync with
#   test/PlankTestBase.sol:plankOpts().
# ^ `model_interfaces`/`model_libraries`: the mev_tax_model_one dep roots so compile-plank can
#   build the model's own entrypoints (AlgebraIntegralShocksWriterMod, ShockHarness). Unused by
#   non-model entrypoints (plank resolves only imported modules), so declaring them globally is safe.
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


.PHONY: compile-plank clean-plank

# --- PriceSetterHook: local tick-experiment rig -------------------------------
# Stands up PoolManager + a flag-mined PriceSetterHook + a bound (liquidity-free) pool
# on a local anvil. Prints the PriceSetterHook address and its verified slot0 slot.
# Requires `anvil` running: anvil --silent
price-setter-deploy:
	forge script foundry-scripts/PriceSetterHook.s.sol --broadcast --rpc-url local --via-ir --optimize

# Impose a tick on the bound pool: make price-setter-set-tick HOOK=0x.. TICK=-8888
# This is the off-chain entry point -- a single anvil_setStorageAt of the value the hook
# packs (tick + matching sqrtPriceX96, fee bits preserved). A stochastic driver issues
# exactly this per step.
price-setter-set-tick:
	@test -n "$(HOOK)" || (echo "usage: make price-setter-set-tick HOOK=0x.. TICK=<n>"; exit 1)
	cast rpc --rpc-url local anvil_setStorageAt \
		$$(cast call --rpc-url local $(HOOK) 'poolManager()(address)') \
		$$(cast call --rpc-url local $(HOOK) 'slot0Slot()(bytes32)') \
		$$(cast call --rpc-url local $(HOOK) 'packSlot0For(int24)(bytes32)' -- $(TICK))
	@echo "tick  = $$(cast call --rpc-url local $(HOOK) 'readTick()(int24)')"
	@echo "sqrtP = $$(cast call --rpc-url local $(HOOK) 'readSqrtPriceX96()(uint160)')"
