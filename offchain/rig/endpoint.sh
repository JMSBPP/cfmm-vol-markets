#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# THE SHELL HALF OF THE ONE ENDPOINT RULE (CHAIN-06, CHAIN-07).
#
# SOURCED, never executed:
#
#     cd "$(git rev-parse --show-toplevel)"
#     . offchain/rig/endpoint.sh
#
# On return it has set, and marked readonly-by-convention:
#
#     RPC_URL    the resolved endpoint, verbatim
#     RPC_HOST   its host, for `anvil --host`
#     RPC_PORT   its port, for `anvil --port` and for owning the listener by port
#
# Its Haskell twin is offchain/lib/Chain/Endpoint.hs. That module states the default once for the
# Haskell tree and this file states it once for the three bash sites; bash cannot import a Haskell
# module, so the value is written down in two languages and the SUITE ASSERTS THE TWO ARE
# BYTE-EQUAL (the_producer_and_the_consumers_bind_one_endpoint). A duplication a check compares is
# a checked agreement. A duplication nothing compares is the defect this file exists to close.
#
# WHY `${ETH_RPC_URL:-...}` AND NOT `${ETH_RPC_URL-...}`
# ------------------------------------------------------
# The colon form falls back for an UNSET variable AND for an exported-but-EMPTY one. The form
# without it honours `export ETH_RPC_URL=` as the empty string, and an empty value that flows
# onward until it is compared against another empty value is this repository's most-hit defect --
# six recorded instances, including the one narrated in deploy-rig.sh's import-ref block, where an
# empty ref wrote an empty generatedFrom and every downstream freshness check then compared "" to
# "" and exited 0. `export ETH_RPC_URL=` means "I did not supply one".
#
# NO TRIMMING, deliberately. " " is not empty. A resolver that silently repaired whitespace would
# be interpreting an operator's input; a value with a space in it reaches cast, and cast says so.
# ---------------------------------------------------------------------------

# The default authority, stated ONCE on the shell side.
ETH_RPC_URL_DEFAULT="http://127.0.0.1:8545"

RPC_URL="${ETH_RPC_URL:-$ETH_RPC_URL_DEFAULT}"

# --- the split. IT FAILS LOUDLY RATHER THAN DEFAULTING. --------------------
#
# A half-parsed endpoint is worse than an unparsed one HERE specifically, because the producer
# starts a chain with what comes out. `anvil --port ""` and `anvil --port 127.0.0.1` do not start
# the chain the reader is about to attach to, and the reader's failure would then be reported as
# "the chain refused" -- a diagnosis pointing at anvil for a parse this file got wrong.
#
# Every branch below names the value it actually saw. `${_authority##*:}` returns the HOST when
# there is no port at all, which is the sharp case: `ETH_RPC_URL=http://127.0.0.1` would otherwise
# yield RPC_PORT=127.0.0.1, and `anvil --port 127.0.0.1` fails with anvil's own message about an
# invalid port -- naming neither this file nor the variable that produced it.
_authority="${RPC_URL#*://}"     # drop the scheme, if any
_authority="${_authority%%/*}"   # drop any path, query or fragment
_authority="${_authority%%\?*}"
RPC_HOST="${_authority%%:*}"
RPC_PORT="${_authority##*:}"

if [ -z "$RPC_HOST" ]; then
  echo "FATAL: no host in the resolved endpoint '$RPC_URL'." >&2
  echo "       Resolved from ETH_RPC_URL='${ETH_RPC_URL-<unset>}'; the default is" >&2
  echo "       $ETH_RPC_URL_DEFAULT. Expected scheme://host:port." >&2
  exit 1
fi

case "$RPC_PORT" in
  ''|*[!0-9]*)
    echo "FATAL: no numeric port in the resolved endpoint '$RPC_URL' (parsed port '$RPC_PORT')." >&2
    echo "       Resolved from ETH_RPC_URL='${ETH_RPC_URL-<unset>}'." >&2
    echo "       The port is not optional here: the rig OWNS its listener by port -- it kills a" >&2
    echo "       stale one and starts anvil on it -- so a missing port is not a value that can be" >&2
    echo "       defaulted, it is a request this rig cannot carry out. Expected scheme://host:port," >&2
    echo "       e.g. $ETH_RPC_URL_DEFAULT." >&2
    exit 1 ;;
esac

if [ "$RPC_PORT" -lt 1 ] || [ "$RPC_PORT" -gt 65535 ]; then
  echo "FATAL: port $RPC_PORT (from '$RPC_URL') is outside 1-65535." >&2
  exit 1
fi

unset _authority
