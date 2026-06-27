#!/usr/bin/env bash
# Idempotent worktree-per-peer setup. Creates `develop` (from the EXACT $DEVELOP_BASE)
# and one git worktree per row of scripts/peers.tsv under ../cfmm-wt/<name>. NEVER
# switches the main checkout's branch. Re-running is a clean no-op (modulo one network
# ls-remote check). Two passes: create all worktrees first, THEN init submodules
# (non-fatal) so a Solidity-init failure never blocks the source-only peers.
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"; cd "$REPO_ROOT"
WT_HOME="$REPO_ROOT/../cfmm-wt"
MAP="$REPO_ROOT/scripts/peers.tsv"

# peers.tsv MUST end in a newline, else `while read` silently drops the last row.
[ -s "$MAP" ] && [ -z "$(tail -c1 "$MAP")" ] \
  || { echo "ERROR: $MAP missing/empty or has no trailing newline (last row would be dropped)" >&2; exit 1; }

git worktree prune                                            # clear stale registrations

# --- develop: create from the EXACT pinned base, or validate an existing one ---
if git show-ref --verify --quiet refs/heads/develop; then
  if [ -n "${DEVELOP_BASE:-}" ] && \
     [ "$(git rev-parse develop)" != "$(git rev-parse "$DEVELOP_BASE")" ]; then
    echo "ERROR: develop is at $(git rev-parse --short develop) but DEVELOP_BASE=$(git rev-parse --short "$DEVELOP_BASE")" >&2
    exit 1
  fi
else
  : "${DEVELOP_BASE:?set DEVELOP_BASE to the exact post-freeze SHA, e.g. DEVELOP_BASE=\$(git rev-parse HEAD)}"
  git branch develop "$DEVELOP_BASE"
  echo "created develop from $DEVELOP_BASE ($(git rev-parse --short develop))"
fi

# push develop. ls-remote is a network call EVERY run; distinguish absent(2) from unreachable.
set +e; git ls-remote --exit-code origin develop >/dev/null 2>&1; rc=$?; set -e
case "$rc" in
  0) git rev-parse --abbrev-ref develop@{upstream} >/dev/null 2>&1 \
       || git branch --set-upstream-to=origin/develop develop ;;
  2) git push -u origin develop ;;
  *) echo "ERROR: cannot reach origin to check develop (ls-remote rc=$rc)" >&2; exit 1 ;;
esac

# --- pass 1: create every worktree (read tolerates a missing final newline) ---
while IFS=$'\t' read -r name branch init_sub || [ -n "${name:-}" ]; do
  [ -z "${name:-}" ] && continue
  case "$name" in \#*) continue;; esac                        # allow comments
  path="$WT_HOME/$name"
  git show-ref --verify --quiet "refs/heads/$branch" || git branch "$branch" develop
  target="$(readlink -f "$(dirname "$path")" 2>/dev/null)/$(basename "$path")"
  if git worktree list --porcelain | grep -qxF "worktree $target"; then
    echo "skip (registered): $path"
  elif git worktree list --porcelain | grep -qxF "branch refs/heads/$branch"; then
    echo "WARN: $branch already checked out in another worktree — skipping $path" >&2
  elif [ -e "$path" ]; then
    echo "WARN: $path exists but is not a registered worktree — skipping (inspect / prune)" >&2
  else
    git worktree add "$path" "$branch" && echo "added: $path -> $branch"
  fi
done < "$MAP"

# --- pass 2: submodule init for flagged peers — NON-FATAL, resumable on re-run ---
while IFS=$'\t' read -r name branch init_sub || [ -n "${name:-}" ]; do
  [ -z "${name:-}" ] && continue
  case "$name" in \#*) continue;; esac
  [ "${init_sub:-no}" = "yes" ] || continue
  path="$WT_HOME/$name"
  echo "init submodules in $path (fresh per-worktree clone; network+creds)..."
  ( cd "$path" && git submodule update --init --recursive ) \
    || echo "WARN: submodule init failed for $path — worktree created; re-run after fixing creds/network" >&2
done < "$MAP"

echo "--- worktrees ---"; git worktree list
