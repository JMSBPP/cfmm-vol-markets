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
# As of the merge to a single vol test file: 50 pass, 5 fail (55 total).
# The 5 are pre-existing and all in the pos_spec type track:
#   VolRangeWidthTest         volWidthRangeSub_valid, volWidthRangeBuildVolRangeWidth_valid
#   SpreadTickAssimetryTest   spreadTickAssimetrySplitTick__Valid, tickFromSplittedTickBucket__Valid
#   OrderTest                 OrderMakeSucceed
# All five are diagnosed as bugs in the TEST HARNESSES (not the .plk under test)
# and are owned by the vol-type-system track. They are deliberately NOT skipped,
# excluded, or filtered out to make this target green: a suite that lies about
# what passes is worth less than no suite. Fix them or leave them visible.
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
	@bash script/check-algebra-ref-pin.sh

# Everything that must be green for the oracle: the pinned baseline refs, then the whole vol
# suite. The pin runs FIRST: verifying the baseline after diffing against it proves nothing.
test-vol-prereqs: check-algebra-ref-pin test-market-statistics test-realized-vol

# Phase 13 issuance library differential + fuzz battery (the single file
# test/exposure/VegaIssuance.diff.t.sol -- probe + reverts + monotonicity from 13-01, plus the
# 512-bit backing invariant, weight-one identity, composed==mock tolerance-0, and composed<=direct
# one-sided fuzzes from 13-02). Folded into `make test` in Phase 15, NOT here.
#
# --skip routes around an UNTRACKED parallel-track file
# (src/modules/protocol_integrations/PriceSetterHook.sol) whose empty imports break `forge build`
# for the whole src/ tree. It is not this suite's file; skipping it is a no-op once the owning
# track fixes/removes it. See the phase deferred-items.md.
test-vega-issuance:
	forge test --match-path 'test/exposure/VegaIssuance.diff.t.sol' --skip 'src/modules/protocol_integrations/PriceSetterHook.sol' --via-ir --optimize

.PHONY: check-algebra-ref-pin test-market-statistics test-realized-vol test-vol-prereqs test-vega-issuance


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
PLANK_BACKEND := sona
PLANK_BUILD   := build/plank
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
#   VegaAccountMod         - RESCUING. Pure skeleton: SLOT_* / SELECTOR_DEPOSIT consts have
#                            no values, and it does not yet import VegaExposure. Needs the
#                            deposit(collateral) -> vegaExposure logic authored.
PLANK_SKIP    := src/modules/exposure/VegaAccountMod.plk

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


#####################################################################
# GAMS algebraic model (off-chain solver track)                     #
#####################################################################
# GAMS resolves relative `$$include` against the *working directory* of
# the invocation, so every compile runs from $(GAMS_DIR). `action=c`
# does a compile/syntax check only — no Model/Solve exists yet, so no
# license or solver is required. Authoritative reference: model/BUILD.md.
GAMS       ?= gams
GAMS_DIR   := model
GAMS_BUILD := build
# Files to skip (none — every .gms is compile-checked). Add space-separated
# paths relative to $(GAMS_DIR) here if a file should be excluded.
GAMS_SKIP  :=

# compile-gams: compile-check every .gms file under model/ with action=c.
# Fails (non-zero) if any file does not compile, so broken models redden
# the build instead of hiding.
compile-gams:
	@mkdir -p $(GAMS_DIR)/$(GAMS_BUILD)
	@cd $(GAMS_DIR) && rc=0; ok=0; fail=0; skip=0; \
	for f in $$(find . -name '*.gms' | sed 's|^\./||' | sort); do \
		case " $(GAMS_SKIP) " in \
			*" $$f "*) printf '   SKIP %s  (fragment/stub — BUILD.md)\n' "$$f"; skip=$$((skip+1)); continue;; \
		esac; \
		out="$(GAMS_BUILD)/$$(echo "$$f" | tr / _ | sed 's/\.gms$$//').lst"; \
		printf '>> compiling %s\n' "$$f"; \
		if $(GAMS) "$$f" action=c o="$$out" scrdir="$(GAMS_BUILD)" lo=0 >/dev/null 2>&1; then \
			printf '   OK   %s\n' "$$f"; ok=$$((ok+1)); \
		else \
			printf '   FAIL %s  (gams rc=%s) -> %s/%s\n' "$$f" "$$?" "$(GAMS_DIR)" "$$out"; \
			fail=$$((fail+1)); rc=1; \
		fi; \
	done; \
	printf '\ncompile-gams: %s ok, %s failed, %s skipped\n' "$$ok" "$$fail" "$$skip"; \
	exit $$rc

# clean-gams: remove GAMS listings, save/scratch, and build artifacts.
clean-gams:
	@rm -rf $(GAMS_DIR)/$(GAMS_BUILD) $(GAMS_DIR)/225* \
		$(GAMS_DIR)/*.lst $(GAMS_DIR)/*.g00 $(GAMS_DIR)/*.lxi

# gams-fixtures: regenerate committed GAMS->Solidity diff fixtures (read-only GAMS run).
.PHONY: gams-fixtures
gams-fixtures:
	uv run --project tools/gamsdiff gamsdiff

.PHONY: compile-plank clean-plank compile-gams clean-gams
