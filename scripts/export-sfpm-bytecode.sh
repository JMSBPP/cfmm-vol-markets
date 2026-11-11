#!/usr/bin/env bash
# Export SemiFungiblePositionManagerV4 creation bytecode into .bytecode/panoptic/
# for NoFeeVarianceClaimBuilderTest (avoids compiling SFPM under root via_ir).
#
# Builds inside lib/panoptic-v2-core with that package's foundry.toml (viaIR=false).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PANOPTIC="$ROOT/lib/panoptic-v2-core"
OUT="$ROOT/.bytecode/panoptic"

mkdir -p "$OUT"

if [[ ! -f "$PANOPTIC/contracts/SemiFungiblePositionManagerV4.sol" ]]; then
  echo "error: missing $PANOPTIC (init submodule lib/panoptic-v2-core)" >&2
  exit 1
fi

(
  cd "$PANOPTIC"
  forge build --contracts contracts/SemiFungiblePositionManagerV4.sol
)

JSON="$(ls "$PANOPTIC"/out/SemiFungiblePositionManagerV4.sol/SemiFungiblePositionManagerV4.*.json | sort | tail -n1)"
jq -r '.bytecode.object // .bytecode' "$JSON" | tr -d '\n' > "$OUT/SemiFungiblePositionManagerV4.bytecode"

echo "wrote $OUT/SemiFungiblePositionManagerV4.bytecode ($(wc -c < "$OUT/SemiFungiblePositionManagerV4.bytecode") bytes) from $JSON"
