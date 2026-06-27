#!/usr/bin/env bash
# Remove one peer's worktree and its branch safely. Usage: wt-teardown.sh <peer-name>
# Uses `git branch -d` (refuses unmerged branches — keep that safety).
set -euo pipefail
REPO_ROOT="$(git rev-parse --show-toplevel)"; cd "$REPO_ROOT"
name="${1:?usage: wt-teardown.sh <peer-name>}"
path="$REPO_ROOT/../cfmm-wt/$name"
branch="$(awk -F'\t' -v n="$name" '$1==n{print $2}' scripts/peers.tsv)"
[ -n "$branch" ] || { echo "no map row for '$name'" >&2; exit 1; }

target="$(readlink -f "$(dirname "$path")" 2>/dev/null)/$(basename "$path")"
if git worktree list --porcelain | grep -qxF "worktree $target"; then   # -qxF: exact line, no substring/regex (gams vs gamsdiff)
  git worktree remove "$path"
  echo "removed worktree: $path"
fi
git worktree prune
if git show-ref --verify --quiet "refs/heads/$branch"; then
  git branch -d "$branch" && echo "deleted branch: $branch" \
    || echo "branch $branch not fully merged — left in place (use -D to force)" >&2
fi
