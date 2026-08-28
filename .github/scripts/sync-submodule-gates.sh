#!/usr/bin/env bash
# Resolve d2p-finance/main for root submodules, verify upstream check-runs, auto-bump gitlinks.
set -euo pipefail

ROOT_SUBMODULES=(spec offchain evm-spec-bridge refs)

declare -A SUBMODULE_REPOS
SUBMODULE_REPOS[spec]=d2p-finance/cfmm-vol-markets-spec
SUBMODULE_REPOS[offchain]=d2p-finance/gams-evm-transport
SUBMODULE_REPOS[evm-spec-bridge]=d2p-finance/evm-spec-bridge
SUBMODULE_REPOS[refs]=d2p-finance/cfmm-refs

declare -A SUBMODULE_CHECKS
SUBMODULE_CHECKS[spec]='stack build && stack test'
SUBMODULE_CHECKS[offchain]='build-test|gate'
SUBMODULE_CHECKS[evm-spec-bridge]='seam|build'
SUBMODULE_CHECKS[refs]='shelf'

checks_for_path() {
  local path=$1
  local IFS='|'
  read -r -a _checks <<< "${SUBMODULE_CHECKS[$path]}"
  printf '%s\n' "${_checks[@]}"
}

gh_token() {
  printf '%s' "${GH_TOKEN:-${GITHUB_TOKEN:-}}"
}

check_runs_conclusion() {
  local repo=$1 sha=$2 name=$3
  if [[ -n "${SYNC_GATE_TEST_JSON:-}" ]]; then
    printf '%s' "$SYNC_GATE_TEST_JSON" | jq -r "[.check_runs[] | select(.name == \"${name}\") | .conclusion] | first // \"missing\""
    return 0
  fi
  GH_TOKEN="$(gh_token)" gh api "repos/${repo}/commits/${sha}/check-runs" --paginate \
    --jq "[.check_runs[] | select(.name == \"${name}\") | .conclusion] | first // \"missing\""
}

require_check_run_success() {
  local repo=$1 sha=$2 name=$3
  local conclusion
  conclusion=$(check_runs_conclusion "$repo" "$sha" "$name")
  if [[ "$conclusion" != "success" ]]; then
    echo "::error::${repo}@${sha:0:7} check-run '${name}' is '${conclusion}' (need success)" >&2
    return 1
  fi
}

verify_checks_on_sha() {
  local repo=$1 sha=$2
  shift 2
  local name
  for name in "$@"; do
    require_check_run_success "$repo" "$sha" "$name"
  done
}

count_check_runs() {
  local repo=$1 sha=$2
  if [[ -n "${SYNC_GATE_TEST_TOTAL:-}" ]]; then
    printf '%s' "$SYNC_GATE_TEST_TOTAL"
    return 0
  fi
  GH_TOKEN="$(gh_token)" gh api "repos/${repo}/commits/${sha}/check-runs" --jq '.total_count'
}

verify_with_history() {
  local repo=$1 start_sha=$2
  shift 2
  local sha=$start_sha
  local i
  for i in $(seq 1 15); do
    if verify_checks_on_sha "$repo" "$sha" "$@" 2>/dev/null; then
      if [[ "$sha" != "$start_sha" ]]; then
        echo "note: ${repo}@${start_sha:0:7} had no check-runs; accepted ${sha:0:7} from history" >&2
      fi
      printf '%s' "$sha"
      return 0
    fi
    sha=$(GH_TOKEN="$(gh_token)" gh api "repos/${repo}/commits/${sha}" --jq '.parents[0].sha // empty' 2>/dev/null || true)
    [[ -z "$sha" || "$sha" == "null" ]] && break
  done
  echo "::error::${repo}: no commit within 15 of main head has green checks ($*)" >&2
  return 1
}

resolve_latest() {
  local url=$1
  git ls-remote "$url" refs/heads/main | awk '{print $1; exit}'
}

submodule_url() {
  git config -f .gitmodules --get "submodule.$1.url"
}

pinned_sha() {
  git rev-parse ":$1" 2>/dev/null || git ls-tree HEAD "$1" | awk '{print $3}'
}

gh_run_success_on_commit_or_parents() {
  local repo=$1 sha=$2 wf=$3
  local ok parent
  ok=$(GH_TOKEN="$(gh_token)" gh run list -R "$repo" --commit "$sha" \
    --json workflowName,conclusion \
    --jq "any(.[]; .workflowName==\"${wf}\" and .conclusion==\"success\")")
  if [[ "$ok" == "true" ]]; then
    return 0
  fi
  while read -r parent; do
    [[ -z "$parent" ]] && continue
    ok=$(GH_TOKEN="$(gh_token)" gh run list -R "$repo" --commit "$parent" \
      --json workflowName,conclusion \
      --jq "any(.[]; .workflowName==\"${wf}\" and .conclusion==\"success\")")
    [[ "$ok" == "true" ]] && return 0
  done < <(GH_TOKEN="$(gh_token)" gh api "repos/${repo}/commits/${sha}" --jq '.parents[].sha')
  return 1
}

verify_offchain_gate() {
  local repo=$1 latest=$2
  if [[ "$(count_check_runs "$repo" "$latest")" != "0" ]]; then
    verify_checks_on_sha "$repo" "$latest" build-test gate
    printf '%s' "$latest"
    return 0
  fi
  if gh_run_success_on_commit_or_parents "$repo" "$latest" haskell; then
    echo "note: ${repo}@${latest:0:7} has no check-runs on merge; accepted via haskell workflow on PR head" >&2
    printf '%s' "$latest"
    return 0
  fi
  verify_with_history "$repo" "$latest" build-test gate
}

verify_submodule_gate() {
  local path=$1 repo=$2 latest=$3
  local -a checks
  if [[ "$path" == "offchain" ]]; then
    verify_offchain_gate "$repo" "$latest"
    return $?
  fi
  mapfile -t checks < <(checks_for_path "$path")
  verify_checks_on_sha "$repo" "$latest" "${checks[@]}"
  printf '%s' "$latest"
}

sync_submodule_at() {
  local path=$1 latest=$2
  git submodule update --init "$path"
  git -C "$path" fetch origin main
  git -C "$path" checkout "$latest"
}

auto_bump_if_needed() {
  if git diff --cached --quiet; then
    echo "submodule pins already at verified LATEST"
    return 0
  fi

  if [[ "${GITHUB_EVENT_NAME:-}" != "pull_request" ]]; then
    echo "::error::submodule pins stale but auto-bump runs only on pull_request" >&2
    exit 1
  fi

  if [[ "${PR_HEAD_REPO_FULL_NAME:-}" != "${GITHUB_REPOSITORY:-}" ]]; then
    echo "::error::submodule pins stale; open PR from a branch on ${GITHUB_REPOSITORY} (not a fork head) or bump gitlinks manually" >&2
    exit 1
  fi

  git config user.name "github-actions[bot]"
  git config user.email "41898282+github-actions[bot]@users.noreply.github.com"

  local spec_sha offchain_sha bridge_sha refs_sha
  spec_sha=$(git rev-parse :spec)
  offchain_sha=$(git rev-parse :offchain)
  bridge_sha=$(git rev-parse :evm-spec-bridge)
  refs_sha=$(git rev-parse :refs)

  git commit -m "chore(ci): auto-bump root submodule pins to d2p-finance/main

spec@${spec_sha} offchain@${offchain_sha} evm-spec-bridge@${bridge_sha} refs@${refs_sha}"

  git push origin "HEAD:${GITHUB_HEAD_REF:?}"
}

main() {
  local path url latest pinned verified changed=0

  for path in "${ROOT_SUBMODULES[@]}"; do
    url=$(submodule_url "$path")
    latest=$(resolve_latest "$url")
    if [[ -z "$latest" ]]; then
      echo "::error::could not resolve main for ${path} (${url})" >&2
      exit 1
    fi
    echo "${path}: LATEST=${latest:0:7} repo=${SUBMODULE_REPOS[$path]}"
    verified=$(verify_submodule_gate "$path" "${SUBMODULE_REPOS[$path]}" "$latest")
    pinned=$(pinned_sha "$path")
    sync_submodule_at "$path" "$verified"
    if [[ "$pinned" != "$verified" ]]; then
      git add "$path"
      changed=1
      echo "${path}: bump ${pinned:0:7} -> ${verified:0:7}"
    fi
  done

  if [[ "$changed" -eq 0 ]]; then
    echo "submodule pins already at verified LATEST"
    exit 0
  fi

  auto_bump_if_needed
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
