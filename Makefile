sol-build:
	forge build --via-ir --optimize

sol-test:
	forge test --match-contract VolOrderTest --via-ir --optimize 


test-utils:
	forge clean && forge test --match-contract UtilsTest -vvvv --via-ir --optimize

test-pricing-kernel-diff:
	forge clean && forge test --match-contract PricingKernelPlankdiffTest -vvvv --via-ir --optimize

# The Solidity oracle references (Algebra + UniV3). This is the baseline the Plank
# differential test diffs against, so it must be green before that work means anything.
test-market-statistics:
	forge test --match-contract MarketStatisticsTest --via-ir --optimize

# Proves RealizedVolatilityMod.plk is deployable and its ABI dispatch is live.
# NOTE: `make compile-plank` passing does NOT prove this. plank does not type-check code
# unreachable from run{}, so a module with an empty run{} compiles green while every
# function in it is dead. Only calling it proves anything.
test-realized-vol-smoke:
	forge test --match-contract RealizedVolatilitySmokeTest --via-ir --optimize

# The Plank<->Algebra<->UniV3 differential test (Phase 0-1): one driver, three targets,
# exact agreement on the accumulator, the TWAP, and the stored state. No-wrap regime.
test-vol-diff:
	forge test --match-contract RealizedVolatilityDiffTest --via-ir --optimize

# The Algebra reference the whole differential exercise is measured against lives in
# node_modules -- untracked (.gitignore:2) and silently rewritten by `npm ci`. It was already
# corrupted once by an editor auto-fill (tickCumulative -> tickC umulative). This pins the whole
# 4-file import closure the harness links, NOT just VolatilityOracle.sol: pinning one file of a
# closure is false assurance. Red here means the baseline moved -- every "bit-exact vs Algebra"
# claim downstream is void until it is restored or deliberately re-pinned.
check-algebra-ref-pin:
	@bash script/check-algebra-ref-pin.sh

# Everything that must be green for the oracle: baseline refs, Plank smoke, and the diff test.
# The pin runs FIRST: verifying the baseline after diffing against it proves nothing.
test-vol-prereqs: check-algebra-ref-pin test-market-statistics test-realized-vol-smoke test-vol-diff

.PHONY: check-algebra-ref-pin test-market-statistics test-realized-vol-smoke test-vol-diff test-vol-prereqs


build-random:
	@plank build src/lib/BinomialProxy.plk --dep v3=lib/plankified-univ3/plank/lib/ --backend 'sona'

build-cash:
	@plank build src/lib/SwapAmtGen.plk --dep v3=lib/plankified-univ3/plank/lib/ --backend 'sona'	

build-pool:
	@plank build src/ReferenceMarket.plk --dep v3=lib/plankified-univ3/plank/lib/ --backend 'sona'


#####################################################################
# build-pool:							    #
# 	@plank build src/ReferenceMarket.plk \			    #
# 		--dep v3=lib/plankified-univ3/plank/lib/ \	    #
# 		--dep le_proj=test/le-proj \			    #
# 		--backend sona					    #
#####################################################################


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
# Entrypoints are auto-discovered as any .plk under src/ or test/ that contains
# an `init` block -- EXCEPT anything under an `exp/` directory. `exp/` holds
# throwaway experiments (CESLongPayoff, VarianceMarketPlant); they are kept on
# disk but must never redden the gate, so discovery skips the directory outright
# rather than listing each file in PLANK_SKIP.
PLANK_EXCLUDE_DIR := exp
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
compile-plank:
	@mkdir -p $(PLANK_BUILD)
	@rc=0; ok=0; fail=0; skip=0; \
	for f in $$(grep -rlE '^[[:space:]]*init[[:space:]]*\{' --include='*.plk' --exclude-dir='$(PLANK_EXCLUDE_DIR)' src test | sort); do \
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
