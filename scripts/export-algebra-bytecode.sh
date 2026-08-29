#!/usr/bin/env bash
# Export Algebra Integral creation bytecode into .bytecode/algebra/ for test deployers.
#
# Primary path (CI / after npm ci): read pinned artifacts from node_modules.
# Optional path (maintainer): set ALGEBRA_SRC to a cryptoalgebra/Algebra checkout and run
#   forge inspect AlgebraFactory bytecode
# after wiring a foundry compile of src/core — then copy output here.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/.bytecode/algebra"
CORE_ART="$ROOT/node_modules/@cryptoalgebra/integral-core/artifacts/contracts"
PERI_ART="$ROOT/node_modules/@cryptoalgebra/integral-periphery/artifacts/contracts"

mkdir -p "$OUT"

_extract() {
  local json="$1" out="$2"
  jq -r '.bytecode | if type == "string" then . else .object end' "$json" | tr -d '\n' > "$out"
}

if [[ ! -f "$CORE_ART/AlgebraFactory.sol/AlgebraFactory.json" ]]; then
  echo "error: run npm ci --ignore-scripts first (integral-core artifacts missing)" >&2
  exit 1
fi

_extract "$CORE_ART/AlgebraFactory.sol/AlgebraFactory.json" "$OUT/AlgebraFactory.bytecode"
_extract "$CORE_ART/AlgebraPoolDeployer.sol/AlgebraPoolDeployer.json" "$OUT/AlgebraPoolDeployer.bytecode"
_extract "$PERI_ART/AlgebraCustomPoolEntryPoint.sol/AlgebraCustomPoolEntryPoint.json" \
  "$OUT/AlgebraCustomPoolEntryPoint.bytecode"

echo "wrote $OUT/AlgebraFactory.bytecode ($(wc -c < "$OUT/AlgebraFactory.bytecode") bytes)"
echo "wrote $OUT/AlgebraPoolDeployer.bytecode ($(wc -c < "$OUT/AlgebraPoolDeployer.bytecode") bytes)"
echo "wrote $OUT/AlgebraCustomPoolEntryPoint.bytecode ($(wc -c < "$OUT/AlgebraCustomPoolEntryPoint.bytecode") bytes)"
