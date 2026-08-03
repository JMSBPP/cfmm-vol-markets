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
PATHS=offchain/rig/import-paths.txt

# (0) THE PATH LIST IS ITSELF PINNED, BEFORE IT IS USED FOR ANYTHING.
#
# import-paths.txt is simultaneously the git-diff pathspec in (a) AND the sha-loop input in
# (b), so a line dropped from it removes that file from BOTH checks at once. Nothing noticed:
# `n` was counted and printed and never compared. MEASURED against a 1-line list --
#   $ head -1 offchain/rig/import-paths.txt > offchain/rig/import-paths.txt.new && mv ...
#   $ bash offchain/rig/verify-import.sh
#   SC-1 OK: 1 imported paths content-identical to 2039f278... and sha256-matched
#   EXIT=0
# -- 36 of the 37 source-of-truth files verified by nothing, on the ONE rig script CI runs
# as the SC-1 gate.
#
# The instrument is a SET, not a floor. Agent B measured that a count-preserving swap sails
# straight through any floor, and this list is exactly that shape: duplicate one line over
# another and `n` still reads 37 while a real path has silently left both checks. So the
# list is compared, as a set, against the paths IMPORT-PIN.md carries a digest row for --
# the independent artifact that already defines what "imported" means. Equality is asserted
# in BOTH directions: `<` catches a path that lost its pin row, `>` catches a pinned path
# dropped from the list. Adding an import means adding both, in the same commit, which is
# what the pin file is for.
[ -f "$PATHS" ] || { echo "SC-1 FAIL: missing $PATHS"; exit 1; }
[ -f "$PIN" ]   || { echo "SC-1 FAIL: missing $PIN"; exit 1; }

listed=$(sort "$PATHS")
pinned=$(grep -oE '^\| `[0-9a-f]{64}` \| `[^`]+`' "$PIN" | sed 's/.*| `//; s/`$//' | sort)
n=$(printf '%s\n' "$listed" | grep -c . || true)
n_pinned=$(printf '%s\n' "$pinned" | grep -c . || true)

# A blank line in the list becomes an empty pathspec, which `git diff` reads as "everything";
# a duplicate makes the set smaller than the file without changing the line count. Both are
# degeneracies that pass a count and fail a set, so both are named explicitly.
if [ "$n" -eq 0 ] || [ "$n_pinned" -eq 0 ]; then
  echo "SC-1 FAIL: $PATHS lists $n paths and $PIN pins $n_pinned. Zero on either side is an"
  echo "           UNRUN gate, never a clean one."; exit 1
fi
if [ "$(grep -c '^[[:space:]]*$' "$PATHS" || true)" -ne 0 ]; then
  echo "SC-1 FAIL: $PATHS contains a blank line. An empty pathspec makes (a) diff EVERYTHING,"
  echo "           and the sha loop then stats the empty string."; exit 1
fi
if [ "$(printf '%s\n' "$listed" | wc -l)" -ne "$(printf '%s\n' "$listed" | sort -u | wc -l)" ]; then
  echo "SC-1 FAIL: $PATHS contains a DUPLICATE path. The line count is preserved and a real"
  echo "           path has left both checks:"; printf '%s\n' "$listed" | uniq -d | sed 's/^/             /'
  exit 1
fi
if ! diff_out=$(diff <(printf '%s\n' "$pinned") <(printf '%s\n' "$listed")); then
  echo "SC-1 FAIL: $PATHS and $PIN do not describe the SAME set of imported paths."
  echo "           '<' = pinned in $PIN but absent from the list -- it is verified by NOTHING."
  echo "           '>' = in the list but carries no digest row -- (b) cannot check it."
  printf '%s\n' "$diff_out" | sed 's/^/             /'
  exit 1
fi

# (a) content diff against the recorded ref
if ! git diff --exit-code "$REF" -- $(tr '\n' ' ' < "$PATHS"); then
  echo "SC-1 FAIL: working tree differs from $REF on an imported path"; exit 1
fi

# (b) sha256 recompute against the pin file
fail=0
checked=0
while read -r p; do
  checked=$((checked + 1))
  want=$(grep -F "| \`$p\` |" "$PIN" | grep -oE '[0-9a-f]{64}' | head -1 || true)
  if [ -z "$want" ]; then
    echo "SC-1 FAIL: no pin row in $PIN for $p"; fail=1; continue
  fi
  got=$(sha256sum "$p" | cut -d' ' -f1)
  if [ "$want" != "$got" ]; then
    echo "SC-1 FAIL sha256 $p: pinned=$want actual=$got"; fail=1
  fi
done < "$PATHS"
test "$fail" -eq 0 || exit 1

# The loop ITERATION COUNT is compared to the pinned set size, not merely reported. A final
# newline missing from $PATHS makes `read` drop the last line silently, which (0) cannot see
# because it reads the same file through `sort`. This is the one thing here that must be a
# count: it is asserting that the loop above ran once per pinned path.
if [ "$checked" -ne "$n_pinned" ]; then
  echo "SC-1 FAIL: the sha loop ran $checked times for $n_pinned pinned paths."
  echo "           A missing trailing newline in $PATHS makes \`read\` drop the last line."; exit 1
fi

# (c) the superseded file must stay gone
test ! -e src/lib/TickUtils.plk || { echo "SC-1 FAIL: src/lib/TickUtils.plk reappeared"; exit 1; }

echo "SC-1 OK: $n imported paths (the exact set IMPORT-PIN.md pins) content-identical to $REF"
echo "         and sha256-matched to IMPORT-PIN.md"
