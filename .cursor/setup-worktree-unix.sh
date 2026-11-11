#!/usr/bin/env bash
# Cursor runs this on worktree create (Agents Window, IDE, CLI).
# New worktrees are cut from whatever HEAD was checked out — often a stale
# local develop. Always re-point at the fetched origin/develop tip.
set -euo pipefail

git fetch origin develop
sha="$(git rev-parse origin/develop)"
git reset --hard "$sha"
echo "worktree HEAD=$(git rev-parse --short HEAD) origin/develop=$(git rev-parse --short origin/develop)"
