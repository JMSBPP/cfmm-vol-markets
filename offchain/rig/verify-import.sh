#!/usr/bin/env bash
# SC-1: the imported artifacts are content-identical to the RECORDED origin/develop ref.
# Two independent checks: (a) git content diff, (b) sha256 recompute vs IMPORT-PIN.md.
#
# Re-runnable at any time. (a) survives the branch moving only while the ref object is
# still reachable; (b) survives regardless, because it recomputes from the working tree
# against digests committed in the pin file. That is why BOTH are run.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
REF=$(cat offchain/rig/import-ref.txt)
PIN=.planning/phases/20-deploy-rig-source-of-truth-import/IMPORT-PIN.md

# (a) content diff against the recorded ref
if ! git diff --exit-code "$REF" -- $(tr '\n' ' ' < offchain/rig/import-paths.txt); then
  echo "SC-1 FAIL: working tree differs from $REF on an imported path"; exit 1
fi

# (b) sha256 recompute against the pin file
fail=0
n=0
while read -r p; do
  n=$((n + 1))
  want=$(grep -F "| \`$p\` |" "$PIN" | grep -oE '[0-9a-f]{64}' | head -1 || true)
  if [ -z "$want" ]; then
    echo "SC-1 FAIL: no pin row in $PIN for $p"; fail=1; continue
  fi
  got=$(sha256sum "$p" | cut -d' ' -f1)
  if [ "$want" != "$got" ]; then
    echo "SC-1 FAIL sha256 $p: pinned=$want actual=$got"; fail=1
  fi
done < offchain/rig/import-paths.txt
test "$fail" -eq 0 || exit 1

# (c) the superseded file must stay gone
test ! -e src/lib/TickUtils.plk || { echo "SC-1 FAIL: src/lib/TickUtils.plk reappeared"; exit 1; }

echo "SC-1 OK: $n imported paths content-identical to $REF and sha256-matched to IMPORT-PIN.md"
