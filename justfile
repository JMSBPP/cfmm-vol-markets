set dotenv-load

# Global for every recipe subprocess. Deploy recipes also upsert these into
# the repo-root `.env` (gitignored) so forge / later shells can `source .env`.
export ANVIL_RPC_URL := "http://127.0.0.1:8545"

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
anvil-rpc := ANVIL_RPC_URL

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

# Run one Foundry test file at full verbosity (-vvvv). Profile / fork / offline follow the path.
# Usage: just test test/types/LiquidityChunkMinterAlgebra.t.sol
#        just test LiquidityChunkMinterRunAlgebra.t.sol   # unique basename under test/
test file:
    #!/usr/bin/env bash
    set -euo pipefail
    # Stale FOUNDRY_REMAPPINGS breaks merge with foundry.toml (comma-glued remaps).
    unset FOUNDRY_REMAPPINGS

    f="{{file}}"
    f="${f#./}"
    if [[ "$f" != test/* ]]; then
        if [[ -f "test/$f" ]]; then
            f="test/$f"
        fi
    fi
    if [[ ! -f "$f" && "$(basename "$f")" == *.t.sol ]]; then
        base="$(basename "$f")"
        mapfile -t hits < <(find test -name "$base" -type f 2>/dev/null | sort)
        if [[ ${#hits[@]} -eq 1 ]]; then
            f="${hits[0]}"
        elif [[ ${#hits[@]} -gt 1 ]]; then
            echo "error: ambiguous test basename $base (matches:" >&2
            printf '  %s\n' "${hits[@]}" >&2
            echo "pass a repo-root path, e.g. just test test/types/$base" >&2
            exit 1
        fi
    fi
    if [[ ! -f "$f" ]]; then
        echo "error: missing test file: $f" >&2
        echo "usage: just test test/types/Foo.t.sol" >&2
        exit 1
    fi

    if [[ ! -f node_modules/@cryptoalgebra/integral-core/contracts/interfaces/IAlgebraFactory.sol ]]; then
        just npm-ci
    fi

    # Foundry 1.5 drops these short prefixes from the compile remapping set; tests import
    # `@cryptoalgebra/integral-core/interfaces/…` (not …/contracts/interfaces/…).
    algebra_remaps=(
        --remappings '@cryptoalgebra/integral-core/=node_modules/@cryptoalgebra/integral-core/contracts/'
        --remappings '@cryptoalgebra/integral-periphery/=node_modules/@cryptoalgebra/integral-periphery/contracts/'
        --remappings '@cryptoalgebra/abstract-plugin/=node_modules/@cryptoalgebra/abstract-plugin/contracts/'
    )

    profile=""
    extra=()

    case "$f" in
        test/types/SigmaF.t.sol)
            profile=sigmaf
            just ensure-anvil
            extra+=(--fork-url "{{anvil-rpc}}")
            ;;
        test/types/TokenHistory.t.sol | test/types/TokenHistoryFlow.t.sol | test/types/RealizedVolatilityInitIndex.t.sol)
            profile=rv-init
            extra+=(--offline)
            ;;
        test/weiner_gen/*)
            profile=weiner
            extra+=(--offline)
            ;;
        *)
            extra+=(--offline)
            ;;
    esac

    cmd=(forge test --match-path "$f" --via-ir -vvvv "${algebra_remaps[@]}" "${extra[@]}")
    if [[ -n "$profile" ]]; then
        FOUNDRY_PROFILE="$profile" "${cmd[@]}"
    else
        "${cmd[@]}"
    fi

# SigmaF TokenAmount product + IO run (#128). All txs on the Anvil backend.
test-sigmaf:
    just test test/types/SigmaF.t.sol

# TokenHistory intro len=K + step_k fuzz K < n(dt). Offline (no Anvil).
test-tokenhistory:
    just test test/types/TokenHistory.t.sol

# TokenHistoryFlow run_k: all j<K Xfers, fuzz K≤128. Offline.
test-tokenhistoryflow:
    just test test/types/TokenHistoryFlow.t.sol

# RealizedVolatility init→one-bin write vs TimeIndex.lastIndex (cfmm-types pin).
test-rv-init-index:
    just test test/types/RealizedVolatilityInitIndex.t.sol

# --- Spec tools (Agda + Idris 2 via pinned Docker image) ---------------------
# Image ref: `.github/spec-tools-image` (GHCR tag). Build only when Dockerfile.spec-tools changes.
# Always Docker locally and in CI (no host-Agda escape). See AGENTS.md.

spec-tools-image := `test -f .github/spec-tools-image && tr -d '[:space:]' < .github/spec-tools-image || true`

# Pull GHCR pin only (fail closed). Rebuilds belong in `spec-tools-build` /
# `.github/workflows/spec-tools-image.yml` so push-build never spends ~10m on docker build.
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
    echo "error: missing $img — pull failed; publish via just spec-tools-build + workflow spec-tools-image.yml" >&2
    exit 1

# Build and tag Dockerfile.spec-tools as the pin (local or image-publish workflow).
spec-tools-build:
    #!/usr/bin/env bash
    set -euo pipefail
    img="{{spec-tools-image}}"
    echo "spec-tools: building Dockerfile.spec-tools as $img" >&2
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
    # Image runs as root; reclaim build artifacts so self-hosted checkout can clean.
    if [[ -d "$dir/build" ]]; then
        sudo chown -R "$(id -u):$(id -g)" "$dir/build" || true
    fi

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
    # Image runs as root; reclaim build artifacts so self-hosted checkout can clean.
    if [[ -d "$dir/build" ]]; then
        sudo chown -R "$(id -u):$(id -g)" "$dir/build" || true
    fi

# Compile the domain selected by SPEC_DOMAIN (or domains.toml default).
# Reads `.spec/domains.toml` → that domain's compile.toml → just agda|idris|plank.
spec-compile:
    #!/usr/bin/env bash
    set -euo pipefail
    python3 scripts/spec-compile.py


# Clone/update latest plank-monorepo into ./plank-target (does not move the
# lib/plank-monorepo submodule pin), compile {{file}} with that compiler+std,
# write creation bytecode to .bytecode/app/App.bytecode, deploy it on
# local anvil via cast rpc, export APP_ADDRESS, log the tx hash.
# Usage: just RunApp src/Tick.plk
plank-target-dir := "plank-target"
plank-monorepo-url := "https://github.com/plankevm/plank-monorepo.git"
app-bytecode-dir := ".bytecode/app"
app-bytecode := ".bytecode/app/App.bytecode"



RunApp file:
    #!/usr/bin/env bash
    set -euo pipefail
    src="{{file}}"
    if [[ ! -f "$src" ]]; then
        echo "error: missing $src" >&2
        exit 1
    fi

    dep="{{plank-target-dir}}"
    url="{{plank-monorepo-url}}"
    if [[ ! -d "$dep/.git" ]]; then
        echo "cloning $url -> $dep (latest main)"
        git clone --branch main "$url" "$dep"
    else
        echo "updating $dep to origin/main"
        git -C "$dep" fetch origin
        git -C "$dep" checkout --detach origin/main 2>/dev/null || git -C "$dep" checkout main
        git -C "$dep" pull --ff-only origin main 2>/dev/null || git -C "$dep" reset --hard origin/main
    fi

    plank_bin="$dep/plankc/target/release/plank"
    echo "building plankc --release in $dep"
    (cd "$dep/plankc" && cargo build --release)
    if [[ ! -x "$plank_bin" ]]; then
        echo "error: missing $plank_bin" >&2
        exit 127
    fi
    echo "plank $($plank_bin --version 2>/dev/null || true) @ $plank_bin"

    out_dir="{{app-bytecode-dir}}"
    out="{{app-bytecode}}"
    mkdir -p "$out_dir"
    echo "compiling $src -> $out"
    "$plank_bin" build "$src" --dep std="$dep/std/" > "$out"
    hex="$(tr -d '[:space:]' < "$out")"
    if [[ -z "$hex" ]]; then
        echo "error: empty bytecode at $out" >&2
        exit 1
    fi
    if [[ "$hex" != 0x* && "$hex" != 0X* ]]; then
        hex="0x$hex"
        printf '%s' "$hex" > "$out"
    fi
    echo "wrote $out ($(wc -c < "$out") bytes)"

    just ensure-anvil
    rpc="{{anvil-rpc}}"
    from="$(cast rpc --rpc-url "$rpc" eth_accounts | jq -r 'if type == "string" then fromjson[0] else .[0] end')"
    if [[ -z "$from" || "$from" == "null" ]]; then
        echo "error: no unlocked account at $rpc" >&2
        exit 1
    fi
    payload="$(jq -n --arg from "$from" --arg data "$hex" '{from:$from, data:$data, gas:"0x1c9c380"}')"
    echo "deploying $out from $from via cast rpc eth_sendTransaction"
    tx_raw="$(cast rpc --rpc-url "$rpc" eth_sendTransaction "$payload")"
    tx="$(printf '%s' "$tx_raw" | jq -r 'if type == "string" then . else .result // . end')"
    echo "tx hash: $tx"

    receipt=""
    addr=""
    for _ in $(seq 1 50); do
        receipt="$(cast rpc --rpc-url "$rpc" eth_getTransactionReceipt "$tx" 2>/dev/null || true)"
        addr="$(printf '%s' "$receipt" | jq -r 'if . == null then empty elif type == "string" then (fromjson.contractAddress // empty) else (.contractAddress // empty) end' 2>/dev/null || true)"
        if [[ -n "$addr" && "$addr" != "null" ]]; then
            break
        fi
        sleep 0.1
    done
    if [[ -z "$addr" || "$addr" == "null" ]]; then
        echo "error: no contractAddress in receipt for $tx" >&2
        echo "$receipt" >&2
        exit 1
    fi

    export APP_ADDRESS="$addr"
    export APP_TX_HASH="$tx"
    export ANVIL_RPC_URL="{{ANVIL_RPC_URL}}"
    printf '%s\n' "$addr" > "$out_dir/APP_ADDRESS"
    printf '%s\n' "$tx" > "$out_dir/TX_HASH"
    just run-app
    echo "APP_ADDRESS=$APP_ADDRESS"
    echo "export APP_ADDRESS=$APP_ADDRESS"
    echo "export ANVIL_RPC_URL=$ANVIL_RPC_URL"
    just deploy-multicaller
    echo "source .env"

# Clone Vectorized/solady into lib/solady (no `forge install`: that inits every
# empty lib/ submodule). Solady has no deployable Multicaller — the contract is
# Vectorized/multicaller, cloned to lib/multicaller. Isolated forge inspect,
# then cast rpc deploy on local anvil. Writes export MULTICALLER_ADDRESS=.
solady-url := "https://github.com/vectorized/solady.git"
multicaller-url := "https://github.com/vectorized/multicaller.git"

deploy-multicaller:
    #!/usr/bin/env bash
    set -euo pipefail
    if [[ ! -d lib/solady/.git ]]; then
        echo "cloning {{solady-url}} -> lib/solady"
        git clone --depth 1 "{{solady-url}}" lib/solady
    fi
    if [[ ! -d lib/multicaller/.git ]]; then
        echo "cloning {{multicaller-url}} -> lib/multicaller"
        git clone --depth 1 "{{multicaller-url}}" lib/multicaller
    fi
    src="lib/multicaller/src/Multicaller.sol"
    if [[ ! -f "$src" ]]; then
        echo "error: missing $src" >&2
        exit 1
    fi

    out_dir="{{app-bytecode-dir}}"
    out="$out_dir/Multicaller.bytecode"
    mkdir -p "$out_dir"
    tmp="$(mktemp -d)"
    trap 'rm -rf "$tmp"' EXIT
    mkdir -p "$tmp/src"
    cp "$src" "$tmp/src/"
    {
        echo "[profile.default]"
        echo 'src = "src"'
        echo 'out = "out"'
        echo 'solc = "0.8.24"'
        echo 'via_ir = true'
        echo 'optimizer = true'
    } > "$tmp/foundry.toml"
    echo "compiling Multicaller -> $out"
    forge inspect --root "$tmp" Multicaller bytecode | tr -d '[:space:]' > "$out"
    hex="$(cat "$out")"
    if [[ -z "$hex" ]]; then
        echo "error: empty bytecode at $out" >&2
        exit 1
    fi
    if [[ "$hex" != 0x* && "$hex" != 0X* ]]; then
        hex="0x$hex"
        printf '%s' "$hex" > "$out"
    fi
    echo "wrote $out ($(wc -c < "$out") bytes)"

    just ensure-anvil
    rpc="{{anvil-rpc}}"
    from="$(cast rpc --rpc-url "$rpc" eth_accounts | jq -r 'if type == "string" then fromjson[0] else .[0] end')"
    if [[ -z "$from" || "$from" == "null" ]]; then
        echo "error: no unlocked account at $rpc" >&2
        exit 1
    fi
    payload="$(jq -n --arg from "$from" --arg data "$hex" '{from:$from, data:$data, gas:"0x1c9c380"}')"
    echo "deploying $out from $from via cast rpc eth_sendTransaction"
    tx_raw="$(cast rpc --rpc-url "$rpc" eth_sendTransaction "$payload")"
    tx="$(printf '%s' "$tx_raw" | jq -r 'if type == "string" then . else .result // . end')"
    echo "tx hash: $tx"

    receipt=""
    addr=""
    for _ in $(seq 1 50); do
        receipt="$(cast rpc --rpc-url "$rpc" eth_getTransactionReceipt "$tx" 2>/dev/null || true)"
        addr="$(printf '%s' "$receipt" | jq -r 'if . == null then empty elif type == "string" then (fromjson.contractAddress // empty) else (.contractAddress // empty) end' 2>/dev/null || true)"
        if [[ -n "$addr" && "$addr" != "null" ]]; then
            break
        fi
        sleep 0.1
    done
    if [[ -z "$addr" || "$addr" == "null" ]]; then
        echo "error: no contractAddress in receipt for $tx" >&2
        echo "$receipt" >&2
        exit 1
    fi

    export MULTICALLER_ADDRESS="$addr"
    export MULTICALLER_TX_HASH="$tx"
    export ANVIL_RPC_URL="{{ANVIL_RPC_URL}}"
    printf '%s\n' "$addr" > "$out_dir/MULTICALLER_ADDRESS"
    printf '%s\n' "$tx" > "$out_dir/MULTICALLER_TX_HASH"
    if [[ -z "${APP_ADDRESS:-}" && -f "$out_dir/APP_ADDRESS" ]]; then
        export APP_ADDRESS="$(tr -d '[:space:]' < "$out_dir/APP_ADDRESS")"
    fi
    if [[ -z "${APP_TX_HASH:-}" && -f "$out_dir/TX_HASH" ]]; then
        export APP_TX_HASH="$(tr -d '[:space:]' < "$out_dir/TX_HASH")"
    fi
    just run-app
    echo "MULTICALLER_ADDRESS=$MULTICALLER_ADDRESS"
    echo "export MULTICALLER_ADDRESS=$MULTICALLER_ADDRESS"
    echo "export ANVIL_RPC_URL=$ANVIL_RPC_URL"

# Upsert deploy exports into repo `.env`, user-global `~/.config/tick-path/env`
# (sourced from ~/.bashrc.local like foundry on PATH), and systemd user env.
run-app:
    #!/usr/bin/env bash
    set -euo pipefail
    exec bash scripts/RunApp.sh . "{{app-bytecode-dir}}"


