test-utils:
	forge clean && forge test --match-contract UtilsTest -vvvv --via-ir


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

.PHONY: compile-gams clean-gams
