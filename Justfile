
plank file:
    plank build {{file}} \
      --dep v3=lib/plankified-univ3/plank/lib/ \
      --dep std=lib/plank-monorepo/std/ \
      --dep lib=src/lib \
      --dep types=src/types \
      --dep interfaces=src/interfaces \
      --backend sona

# Plank compile output from a GitHub Actions run (plank job / plank step only).
ci-plank-log run_id job_id="":
    #!/usr/bin/env bash
    set -euo pipefail
    run="{{run_id}}"
    job="{{job_id}}"
    if [[ -z "$job" ]]; then
      job=$(gh run view "$run" --json jobs --jq '.jobs[] | select(.name=="plank") | .databaseId')
    fi
    gh run view "$run" --log --job "$job" \
      | sed -n 's/^plank\tplank\t[0-9TZ:.\+-]*Z //p' \
      | { grep -vE '^##\[(group|endgroup)\]|^\^|^(shell|env):' || true; } \
      | awk '/^0x/ { printf "bytecode: %d bytes (%s…%s)\n", length($0), substr($0,1,18), substr($0,length($0)-7); next } { print }'

# Latest tmp_push run on the current branch.
ci-plank-log-latest:
    #!/usr/bin/env bash
    set -euo pipefail
    run=$(gh run list --workflow=tmp_push.yml --branch="$(git branch --show-current)" --limit 1 --json databaseId --jq '.[0].databaseId')
    exec just ci-plank-log "$run"
