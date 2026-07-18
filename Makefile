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

# Everything that must be green for the oracle: baseline refs, Plank smoke, and the diff test.
test-vol-prereqs: test-market-statistics test-realized-vol-smoke test-vol-diff

.PHONY: test-market-statistics test-realized-vol-smoke test-vol-diff test-vol-prereqs

test-price-impact-diff:
	forge clean && forge test --match-contract PriceImpactKernelPlankdiffTest -vvvv --via-ir


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
	for f in $$(find . -name '*.gms' -not -path './test/*' -not -path './build/*' | sed 's|^\./||' | sort); do \
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

# test-gams: run GAMS assertion tests under model/test/ with action=ce (execute,
# so `abort$$(...)` checks actually fire). A failing assertion returns a non-zero
# GAMS exit code, which fails the build. No Model/Solve -> no solver/license.
test-gams:
	@mkdir -p $(GAMS_DIR)/$(GAMS_BUILD)
	@cd $(GAMS_DIR) && rc=0; ok=0; fail=0; \
	for f in $$(find test -name '*.gms' 2>/dev/null | sed 's|^\./||' | sort); do \
		out="$(GAMS_BUILD)/$$(echo "$$f" | tr / _ | sed 's/\.gms$$//').lst"; \
		printf '>> testing %s\n' "$$f"; \
		if $(GAMS) "$$f" action=ce o="$$out" scrdir="$(GAMS_BUILD)" lo=0 >/dev/null 2>&1; then \
			printf '   PASS %s\n' "$$f"; ok=$$((ok+1)); \
		else \
			printf '   FAIL %s  (gams rc=%s) -> %s/%s\n' "$$f" "$$?" "$(GAMS_DIR)" "$$out"; \
			fail=$$((fail+1)); rc=1; \
		fi; \
	done; \
	printf '\ntest-gams: %s passed, %s failed\n' "$$ok" "$$fail"; \
	exit $$rc

# clean-gams: remove GAMS listings, save/scratch, and build artifacts.
clean-gams:
	@rm -rf $(GAMS_DIR)/$(GAMS_BUILD) $(GAMS_DIR)/225* \
		$(GAMS_DIR)/*.lst $(GAMS_DIR)/*.g00 $(GAMS_DIR)/*.lxi

# payoff-fixtures: regenerate committed per-theorem payoff GDX(s).
# Detects compile/execution errors by post-grepping the .lst — `gams` exits 0
# even on compile errors, so the recipe MUST grep, not rely on exit code alone.
.PHONY: payoff-fixtures
payoff-fixtures:
	@mkdir -p $(GAMS_DIR)/$(GAMS_BUILD)
	@cd $(GAMS_DIR) && rc=0; \
	for f in $$(find payoff -name 'eta_*.gms' 2>/dev/null | sort); do \
		out="$(GAMS_BUILD)/$$(echo "$$f" | tr / _ | sed 's/\.gms$$//').lst"; \
		printf '>> regenerating fixture from %s\n' "$$f"; \
		$(GAMS) "$$f" action=ce o="$$out" scrdir="$(GAMS_BUILD)" lo=0 >/dev/null 2>&1 ; \
		if grep -qE 'Status: (Compilation|Execution) error' "$$out"; then \
			printf '   FAIL %s -> %s/%s (status line indicates error)\n' "$$f" "$(GAMS_DIR)" "$$out"; rc=1; \
		else \
			printf '   OK %s\n' "$$f"; \
		fi; \
	done; \
	exit $$rc

# spec-preflight: extract code blocks from the rev-4 spec MD into a mirror of
# the production layout (model/payoff/* + model/PayoffModule.gms) and drive
# the orchestrator the way production does. Catches divergences in include
# paths, file boundaries, and orchestrator wiring that a flat-concat preflight
# would miss. Codifies the rev-4 discipline: before any spec commit, this
# target must pass.
.PHONY: spec-preflight
spec-preflight:
	@rm -rf $(GAMS_DIR)/$(GAMS_BUILD)/spec
	@mkdir -p $(GAMS_DIR)/$(GAMS_BUILD)/spec/payoff $(GAMS_DIR)/$(GAMS_BUILD)/spec/test
	@SPEC=docs/superpowers/specs/2026-06-28-payoff-zero-slippage-design.md; \
	ROOT=$(GAMS_DIR)/$(GAMS_BUILD)/spec; \
	python3 -c "import re; text = open('$$SPEC').read(); secs = re.split(r'^(## \d+\.[^\n]*)\n', text, flags=re.M); body = {n: next((secs[i+1] for i in range(1,len(secs),2) if secs[i].startswith('## %s.' % n)), None) for n in (5,6,7,8)}; missing = [n for n,b in body.items() if b is None]; assert not missing, 'spec sections missing: %s' % missing; blocks = {n: re.search(r'\`\`\`gams\n(.*?)\n\`\`\`', b, re.S) for n,b in body.items()}; missing = [n for n,m in blocks.items() if m is None]; assert not missing, 'no gams code block in sections: %s' % missing; open('$$ROOT/payoff/_PayoffScaffolding.gms','w').write(blocks[5].group(1)); open('$$ROOT/payoff/eta_pi_trader_zero_slippage.gms','w').write(blocks[6].group(1)); open('$$ROOT/PayoffModule.gms','w').write(blocks[7].group(1)); open('$$ROOT/test/PayoffModuleTest.gms','w').write(blocks[8].group(1))"; \
	cp $(GAMS_DIR)/PricingKernel.gms $(GAMS_DIR)/primitives.gms $(GAMS_DIR)/$(GAMS_BUILD)/spec/; \
	cd $(GAMS_DIR)/$(GAMS_BUILD)/spec && \
	$(GAMS) test/PayoffModuleTest.gms action=ce o=run.lst scrdir=. lo=0 >/dev/null 2>&1 ; \
	if grep -qE 'Status: (Compilation|Execution) error' run.lst; then \
		printf 'spec-preflight FAIL: see $(GAMS_DIR)/$(GAMS_BUILD)/spec/run.lst\n'; \
		grep -A1 '^\*\*\*\*' run.lst | head -10; exit 1; \
	else \
		printf 'spec-preflight OK (production layout: test/PayoffModuleTest.gms → PayoffModule.gms → payoff/*)\n'; \
	fi

# gams-fixtures: regenerate committed GAMS->Solidity diff fixtures (read-only GAMS run).
.PHONY: gams-fixtures
gams-fixtures:
	uv run --project tools/gamsdiff gamsdiff

.PHONY: compile-plank clean-plank compile-gams test-gams clean-gams payoff-fixtures spec-preflight

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
