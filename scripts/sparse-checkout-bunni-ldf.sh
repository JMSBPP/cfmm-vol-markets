#!/usr/bin/env bash
# Local-only: trim lib/bunni-v2 to LDF oracle paths in the type/ldf worktree.
# CI uses a full submodule checkout; do not commit sparse state on the parent repo.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUNNI="$ROOT/lib/bunni-v2"

git -C "$ROOT" submodule update --init lib/bunni-v2
cd "$BUNNI"

git sparse-checkout init --no-cone
git sparse-checkout set \
  /src/interfaces/ILiquidityDensityFunction.sol \
  /src/ldf/GeometricDistribution.sol \
  /src/ldf/LibGeometricDistribution.sol \
  /src/ldf/ShiftMode.sol \
  /src/lib/Math.sol \
  /src/lib/ExpMath.sol \
  /src/lib/FullMathX96.sol \
  /src/lib/SqrtPriceMath.sol \
  /src/base/Constants.sol \
  /src/base/Guarded.sol \
  /src/types/LDFType.sol \
  /test/ldf/ \
  /test/mocks/MockLDF.sol \
  /test/mocks/MockCarpetedLDF.sol

echo "bunni-v2 sparse checkout (LDF oracle paths):"
find . -type f | sort
