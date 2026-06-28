test-utils:
	forge clean && forge test --match-contract UtilsTest -vvvv --via-ir

test-pricing-kernel-diff:
	forge clean && forge test --match-contract PricingKernelPlankdiffTest -vvvv --via-ir


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
PLANK_DEP     := --dep v3=lib/plankified-univ3/plank/lib/
PLANK_BACKEND := sona
PLANK_BUILD   := build/plank
# Entrypoints are auto-discovered as any .plk under src/ or test/ that
# contains an `init` block. Add space-separated paths (relative to the
# repo root) here to skip a known-WIP entrypoint.
PLANK_SKIP    :=

# compile-plank: compile every Plank entrypoint to EVM bytecode, writing
# build/plank/<name>.hex on success and <name>.hex.err on failure. Fails
# (non-zero) if any entrypoint does not compile, so broken contracts
# redden the build instead of hiding.
compile-plank:
	@mkdir -p $(PLANK_BUILD)
	@rc=0; ok=0; fail=0; skip=0; \
	for f in $$(grep -rlE '^[[:space:]]*init[[:space:]]*\{' --include='*.plk' src test | sort); do \
		case " $(PLANK_SKIP) " in \
			*" $$f "*) printf '   SKIP %s  (WIP)\n' "$$f"; skip=$$((skip+1)); continue;; \
		esac; \
		out="$(PLANK_BUILD)/$$(echo "$$f" | tr / _ | sed 's/\.plk$$//').hex"; \
		printf '>> compiling %s\n' "$$f"; \
		if $(PLANK) build "$$f" $(PLANK_DEP) --backend '$(PLANK_BACKEND)' >"$$out" 2>"$$out.err"; then \
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

# gams-fixtures: regenerate committed GAMS->Solidity diff fixtures (read-only GAMS run).
.PHONY: gams-fixtures
gams-fixtures:
	uv run --project tools/gamsdiff gamsdiff

.PHONY: compile-plank clean-plank compile-gams test-gams clean-gams
