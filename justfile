# Pinned Algebra Solidity sources live under node_modules (see package.json).
npm-ci:
    npm ci --ignore-scripts

# Export a volatility-oracle-plugin library creation bytecode via forge inspect.
# Usage: just bytecode VolatilityOracle
#        just bytecode VolatilityOracleStorage
# Prerequisite: `just npm-ci` (or `npm ci --ignore-scripts`).
# Isolated --root: copies all sibling libraries/ (relative imports) and avoids the
# repo foundry.toml pulling missing lib/ submodules (forge-std, …).
bytecode file:
    #!/usr/bin/env bash
    set -euo pipefail
    libdir="node_modules/@cryptoalgebra/volatility-oracle-plugin/contracts/libraries"
    src="$libdir/{{file}}.sol"
    if [[ ! -f "$src" ]]; then
        echo "error: missing $src" >&2
        echo "run: just npm-ci   # or: npm ci --ignore-scripts" >&2
        exit 1
    fi
    out=".bytecode/algebra/volatility_plugin"
    mkdir -p "$out"
    tmp="$(mktemp -d)"
    trap 'rm -rf "$tmp"' EXIT
    mkdir -p "$tmp/src"
    # Sibling libs (e.g. VolatilityOracleStorage → ./VolatilityOracle.sol).
    cp "$libdir"/*.sol "$tmp/src/"
    {
        echo "[profile.default]"
        echo 'src = "src"'
        echo 'out = "out"'
        echo 'solc = "0.8.20"'
        echo 'via_ir = true'
        echo 'optimizer = true'
    } > "$tmp/foundry.toml"
    forge inspect --root "$tmp" "{{file}}" bytecode \
        > "$out/{{file}}Lib.bytecode"

# Runtime / creation bytecode for VolatilityOraclePluginImplementation.
# Writes:
#   .bytecode/algebra/volatility_plugin/VolatilityOraclePluginImplementation.runtime.bytecode
#   .bytecode/algebra/volatility_plugin/VolatilityOraclePluginImplementation.bytecode
# Prerequisite: `just npm-ci`
bytecode-runtime:
    #!/usr/bin/env bash
    set -euo pipefail
    root="$(pwd)"
    out="$root/.bytecode/algebra/volatility_plugin"
    mkdir -p "$out"

    impl_json="$root/node_modules/@cryptoalgebra/volatility-oracle-plugin/artifacts/contracts/VolatilityOraclePluginImplementation.sol/VolatilityOraclePluginImplementation.json"
    if [[ ! -f "$impl_json" ]]; then
        echo "error: missing $impl_json" >&2
        echo "run: just npm-ci" >&2
        exit 1
    fi
    jq -r '.deployedBytecode | if type == "string" then . else .object end' "$impl_json" \
        | tr -d '\n' > "$out/VolatilityOraclePluginImplementation.runtime.bytecode"
    jq -r '.bytecode | if type == "string" then . else .object end' "$impl_json" \
        | tr -d '\n' > "$out/VolatilityOraclePluginImplementation.bytecode"
    echo "wrote $out/VolatilityOraclePluginImplementation.runtime.bytecode ($(wc -c < "$out/VolatilityOraclePluginImplementation.runtime.bytecode") bytes)"
    echo "wrote $out/VolatilityOraclePluginImplementation.bytecode ($(wc -c < "$out/VolatilityOraclePluginImplementation.bytecode") bytes)"

help:
	cat .offline/plank.helper

plank file:
    #!/usr/bin/env bash
    set -euo pipefail
    # Prefer explicit PLANK, then install path, then pinned release build, then PATH.
    if [[ -n "${PLANK:-}" && -x "${PLANK}" ]]; then
        plank_bin="$PLANK"
    elif [[ -x "$HOME/.plank/bin/plank" ]]; then
        plank_bin="$HOME/.plank/bin/plank"
    elif [[ -x lib/plank-monorepo/plankc/target/release/plank ]]; then
        plank_bin="lib/plank-monorepo/plankc/target/release/plank"
    elif command -v plank >/dev/null 2>&1; then
        plank_bin="$(command -v plank)"
    else
        echo "error: plank not found (missing/broken \$HOME/.plank/bin/plank)" >&2
        echo "run: make plank-toolchain" >&2
        exit 127
    fi
    "$plank_bin" build {{file}} \
        --dep v3=lib/plankified-univ3/plank/lib \
        --dep std=lib/plank-monorepo/std/ \
        --dep types=src/types/ \
        --dep cfmm_types=lib/cfmm-types/src/types/ \
        --dep lib=src/lib/ \
        --backend sona

# Anvil at [rpc_endpoints.local] if nothing is already listening.
anvil-rpc := "http://127.0.0.1:8545"

ensure-anvil:
    #!/usr/bin/env bash
    set -euo pipefail
    rpc="{{anvil-rpc}}"
    if cast chain-id --rpc-url "$rpc" >/dev/null 2>&1; then
        echo "anvil already at $rpc"
        exit 0
    fi
    if ! command -v anvil >/dev/null 2>&1; then
        echo "error: anvil not found" >&2
        exit 127
    fi
    echo "starting anvil at $rpc"
    anvil --port 8545 >/tmp/anvil-sigmaf.log 2>&1 &
    for _ in $(seq 1 50); do
        if cast chain-id --rpc-url "$rpc" >/dev/null 2>&1; then
            exit 0
        fi
        sleep 0.1
    done
    echo "error: anvil did not become ready (see /tmp/anvil-sigmaf.log)" >&2
    exit 1

# SigmaF TokenAmount product + IO run (#128). All txs on the Anvil backend.
test-sigmaf: ensure-anvil
    FOUNDRY_PROFILE=sigmaf forge test --match-path test/types/SigmaF.t.sol --via-ir --fork-url {{anvil-rpc}} -vvvv

# TokenHistory intro len=K + step_k fuzz K < n(dt). Offline (no Anvil).
test-tokenhistory:
    FOUNDRY_PROFILE=rv-init forge test --match-path test/types/TokenHistory.t.sol --via-ir --offline -vvvv

# TokenHistoryFlow run_k: all j<K Xfers, fuzz K≤128. Offline.
test-tokenhistoryflow:
    FOUNDRY_PROFILE=rv-init forge test --match-path test/types/TokenHistoryFlow.t.sol --via-ir --offline -vvvv

# RealizedVolatility init→one-bin write vs TimeIndex.lastIndex (cfmm-types pin).
test-rv-init-index:
    FOUNDRY_PROFILE=rv-init forge test --match-path test/types/RealizedVolatilityInitIndex.t.sol --via-ir --offline -vvvv

# --- Spec tools (Agda + Idris 2 via pinned Docker image) ---------------------
# Image ref: `.github/spec-tools-image` (GHCR tag). Build only when Dockerfile.spec-tools changes.
# Always Docker locally and in CI (no host-Agda escape). See AGENTS.md.

spec-tools-image := `tr -d '[:space:]' < .github/spec-tools-image`

# Pull GHCR pin; on miss, build from Dockerfile.spec-tools and tag as the pin.
spec-tools-ensure:
    #!/usr/bin/env bash
    set -euo pipefail
    img="{{spec-tools-image}}"
    if docker image inspect "$img" >/dev/null 2>&1; then
        echo "spec-tools image present: $img"
        exit 0
    fi
    if docker pull "$img"; then
        echo "spec-tools image pulled: $img"
        exit 0
    fi
    echo "spec-tools: pull failed; building Dockerfile.spec-tools as $img" >&2
    docker build -f Dockerfile.spec-tools -t "$img" .

# Type-check one Agda file (repo-root-relative path).
agda file:
    #!/usr/bin/env bash
    set -euo pipefail
    just spec-tools-ensure
    img="{{spec-tools-image}}"
    f="{{file}}"
    if [[ ! -f "$f" ]]; then
        echo "error: missing $f" >&2
        exit 1
    fi
    dir="$(dirname "$f")"
    base="$(basename "$f")"
    docker run --rm \
        -v "$PWD:/work" \
        -w "/work/$dir" \
        "$img" \
        agda --safe "$base"

# Type-check one Idris 2 file (repo-root-relative path).
idris file:
    #!/usr/bin/env bash
    set -euo pipefail
    just spec-tools-ensure
    img="{{spec-tools-image}}"
    f="{{file}}"
    if [[ ! -f "$f" ]]; then
        echo "error: missing $f" >&2
        exit 1
    fi
    dir="$(dirname "$f")"
    base="$(basename "$f")"
    docker run --rm \
        -v "$PWD:/work" \
        -w "/work/$dir" \
        "$img" \
        idris2 --check "$base"

# Compile the domain selected by SPEC_DOMAIN (or domains.toml default).
# Reads `.spec/domains.toml` → that domain's compile.toml → just agda|idris|plank.
spec-compile:
    #!/usr/bin/env bash
    set -euo pipefail
    python3 scripts/spec-compile.py
