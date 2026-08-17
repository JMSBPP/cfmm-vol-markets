#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# capture-gams-conformance.sh -- drive the REAL GAMS 54.1 / CONOPT 4.39
# toolchain once, out of band, and record what it did in
# offchain/rig/gams-conformance.json.
#
# WHY THIS FILE EXISTS
# --------------------
# Nine of Phase 24's guards can only be OBSERVED against a real solver: the
# golden bytes coming out of a real solve, a compile-only run exiting 0 with no
# artifact at all, the two invocations that run no model and still report a
# version, the exit-code taxonomy, CONOPT's true version standing beside both of
# its decoys, the minimal environment vector, the hostile one, and the argv
# token whose leading zero changes the bytes while every VOLUME_PATH.md section
# 4 gate stays green. A guard never seen rejecting is treated as absent, so each
# one is DRIVEN here rather than argued. This is the only place in the phase
# that needs a solver at all -- `cabal test` invokes none, by construction, and
# a scanning check inside the suite forbids it from even naming one.
#
# THE GATE IS A VALUE, NOT A GREEN BUILD
#   jq -r '.action_c.artifact_present'   must print false
#   jq -r '.action_c.exit'               must print 0
#   jq -r '.leading_zero_run.sha256'     must DIFFER from .golden.sha256
#   jq -r '.conopt_version'              must DIFFER from .conopt_link_version
# The first pair is GAMS-02's firing input produced by the real binary; an
# artifact recording a present file there has stopped exercising the case. The
# second is the measurement that makes the argv renderer load-bearing. The third
# is the decoy the whole of GAMS-04 exists to be told apart from, and equality
# there means the exhibit lost its subject.
#
# WHERE CFMM_REQUIRE_GAMS LIVES, AND WHY IT LIVES HERE
# ----------------------------------------------------
# HERE, and nowhere near `cabal test`. Gating the suite on it fails OPEN: a
# workflow whose env block drifts silently returns to skip-mode and reports
# green, which is this repository's advertised-and-dead defect one layer up.
# That is 23-RESEARCH's ruling about its store-side twin, applied verbatim. Here
# it means "refuse to emit an artifact at all when the solver is unreachable",
# so the failure mode is a STALE artifact -- caught by the freshness oracle the
# suite recomputes -- instead of a TRUNCATED one, which nothing catches.
#
# WHY THE ARTIFACT IS COMMITTED
# -----------------------------
# So `cabal test` can assert over real-solver evidence while staying
# solver-independent. A fresh checkout has the artifact; there is nothing to
# provision and nothing to skip.
#
# USAGE
#   GAMS_MODEL=/abs/path/to/volume_path.gms \
#     bash offchain/rig/capture-gams-conformance.sh
#
#   GAMS_BIN          the prover. Resolved with `command -v gams` when unset.
#   GAMS_MODEL        REQUIRED here. volume_path.gms is NOT in this worktree; it
#                     lives in the sibling cfmm-wt/gams worktree, whose checkout
#                     carries the model/ tree this branch does not.
#   CFMM_REQUIRE_GAMS must be 1. There is no other mode.
#
# It writes every probe model and every run directory into its own scratch
# directory under the system temp directory, removes them on exit, and NEVER
# writes into model/, which is another workstream's territory.
# ---------------------------------------------------------------------------
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

OUT=offchain/rig/gams-conformance.json
GOLDEN=offchain/rig/volume-path-golden.json

CFMM_REQUIRE_GAMS="${CFMM_REQUIRE_GAMS:-1}"
export CFMM_REQUIRE_GAMS

# --- Preconditions: fail loudly, never default -----------------------------
if [ "$CFMM_REQUIRE_GAMS" != "1" ]; then
  echo "CAPTURE FAIL: CFMM_REQUIRE_GAMS is '$CFMM_REQUIRE_GAMS', expected 1." >&2
  echo "              This capture has exactly one mode. There is no skip path, because a" >&2
  echo "              capture that skips writes a stale artifact and reports success." >&2
  exit 1
fi
if ! command -v gams >/dev/null 2>&1 && [ -z "${GAMS_BIN:-}" ]; then
  echo "CAPTURE FAIL: gams is not on PATH and GAMS_BIN is unset, so no solver can be driven." >&2
  echo "              CFMM_REQUIRE_GAMS=1: this script emits NO artifact rather than a partial" >&2
  echo "              one. The committed $OUT is left exactly as it was." >&2
  exit 1
fi
if ! command -v jq >/dev/null 2>&1; then
  echo "CAPTURE FAIL: jq is not on PATH; the value-level self-checks below cannot run." >&2
  echo "              A capture whose gate cannot be evaluated must not write an artifact." >&2
  exit 1
fi
if ! command -v sha256sum >/dev/null 2>&1; then
  echo "CAPTURE FAIL: sha256sum is not on PATH; the restore check below cannot compare digests." >&2
  echo "              An exit code is not evidence that the artifact survived -- phase 23's first" >&2
  echo "              probe passed its exit-code check while the artifact changed underneath it." >&2
  exit 1
fi
if [ -z "${GAMS_MODEL:-}" ]; then
  echo "CAPTURE FAIL: GAMS_MODEL is unset and it is REQUIRED here." >&2
  echo "              volume_path.gms does NOT exist in this worktree: it lives in the sibling" >&2
  echo "              cfmm-wt/gams worktree, whose checkout carries the model/ tree this branch" >&2
  echo "              does not. Point GAMS_MODEL at it; the path is machine-specific and belongs" >&2
  echo "              in the shell, never in a tracked file." >&2
  exit 1
fi
if [ ! -f "$GAMS_MODEL" ]; then
  echo "CAPTURE FAIL: GAMS_MODEL points at $GAMS_MODEL, which is not a file." >&2
  exit 1
fi
if [ ! -f "$GOLDEN" ]; then
  echo "CAPTURE FAIL: no committed golden artifact at $(realpath -m "$GOLDEN")." >&2
  echo "              Every byte claim in the artifact is stated AGAINST it, so without it the" >&2
  echo "              three environment runs would be compared only with each other." >&2
  exit 1
fi

GAMS_BIN="${GAMS_BIN:-$(command -v gams)}"
export GAMS_BIN
export GAMS_MODEL

# --- VALIDATE FIRST, REPLACE SECOND ----------------------------------------
# The writer renames into place, so there is no truncation window -- but a
# capture that FAILS one of the self-checks below would already have destroyed
# the good committed evidence by the time the check fired. The previous artifact
# is kept beside the target and put BACK on any non-zero exit, including a
# SIGINT. On success it is removed. `git status` is therefore clean-or-correct
# after every run, never neither. Same shape as capture-store-conformance.sh,
# and for the same measured reason.
if [ -f "$OUT" ]; then
  cp -p "$OUT" "$OUT.prev"
  PREV_SHA=$(sha256sum "$OUT" | cut -d' ' -f1)
else
  PREV_SHA="(no previous artifact)"
fi

SCRATCH="$(mktemp -d "${TMPDIR:-/tmp}/cfmm-gams-conformance-XXXXXX")"

cleanup() {
  local rc=$?
  rm -rf "$SCRATCH"
  rm -f "$OUT.tmp"
  if [ "$rc" -ne 0 ] && [ -f "$OUT.prev" ]; then
    mv -f "$OUT.prev" "$OUT"
    echo "  RESTORED $OUT to its previous contents (sha256 $PREV_SHA)." >&2
    echo "           The capture failed, so the evidence it would have replaced is kept." >&2
  fi
  rm -f "$OUT.prev"
  exit "$rc"
}
trap cleanup EXIT

# --- The probe models ------------------------------------------------------
# Every one of these lives in $SCRATCH and nowhere else. model/ is the GAMS
# workstream's tree and this script does not write there; offchain/ would mean a
# fifth file type for four scans to decide about.

# The 8-line hermetic NLP. It costs 0.008 s and its only job is to make CONOPT
# print its OWN banner, so the true version is obtainable without a production
# solve. The GAMS-side link line and the shared object sit beside it in the same
# output, which is what makes the three-way distinction observable at all.
cat > "$SCRATCH/probe_conopt.gms" <<'GMS'
variable z, x;  equation e;
e.. z =e= sqr(x-1) + 1;
x.lo = -10; x.up = 10;
model m /e/;  option nlp = conopt;
solve m using nlp minimizing z;
GMS

# Exit 2 -- a compilation error.
cat > "$SCRATCH/probe_compile_error.gms" <<'GMS'
scalar x;
x = = 1;
GMS

# Exit 3 -- a NAMED abort, the shape VOLUME_PATH.md section 4 uses.
cat > "$SCRATCH/probe_abort.gms" <<'GMS'
scalar a /1/;
abort$(a = 1) 'named abort from the conformance capture';
GMS

# Exit 3 AGAIN, and that is the finding: an unhandled execution error is
# indistinguishable from a named abort by exit code alone.
cat > "$SCRATCH/probe_exec_error.gms" <<'GMS'
scalar a;
a = 1/0;
GMS

# --- The capture itself ----------------------------------------------------
cabal run -v0 gams-conformance -- "$SCRATCH"

# Stable, sorted formatting so two runs differ only where the MEASUREMENT
# differs and never because of key ordering.
jq -S . "$OUT" > "$OUT.tmp" && mv "$OUT.tmp" "$OUT"

# --- Self-check 0: the artifact is COMPLETE and every observation passed ----
COMPLETE=$(jq -r '.gc_complete' "$OUT")
if [ "$COMPLETE" != "true" ]; then
  echo "CAPTURE FAIL: gc_complete is $COMPLETE. The run did not reach the end." >&2
  exit 1
fi
N_OBS=$(jq -r '.observations | length' "$OUT")
if [ "$N_OBS" -lt 9 ]; then
  echo "CAPTURE FAIL: the artifact records $N_OBS observations, expected at least 9." >&2
  echo "              A shortened list reports every observation it DID make passing." >&2
  exit 1
fi
N_BAD=$(jq -r '[.observations[] | select(.verdict != "pass")] | length' "$OUT")
if [ "$N_BAD" != "0" ]; then
  echo "CAPTURE FAIL: $N_BAD of $N_OBS observations did not pass against the real toolchain:" >&2
  jq -r '.observations[] | select(.verdict != "pass") | "              \(.name)"' "$OUT" >&2
  echo "              Report it as a FINDING about the toolchain; do not adjust the numbers." >&2
  exit 1
fi

# --- Self-check 1: THE GATE, action=c exits 0 and writes NOTHING ------------
# THE CARDINALITY COMES FIRST AND FROM A DIFFERENT FIELD, following the store
# capture: a jq path that is not there yields "" and every comparison below
# would then be "" against a literal, which is the absent-subject defect this
# project's review history is dominated by.
N_AC=$(jq -r '[.action_c] | map(select(. != null)) | length' "$OUT")
if [ "$N_AC" != "1" ]; then
  echo "CAPTURE FAIL: the artifact carries $N_AC action_c blocks, expected 1." >&2
  exit 1
fi
AC_EXIT=$(jq -r '.action_c.exit' "$OUT")
AC_PRESENT=$(jq -r '.action_c.artifact_present' "$OUT")
if [ "$AC_EXIT" != "0" ] || [ "$AC_PRESENT" != "false" ]; then
  echo "CAPTURE FAIL: action=c recorded exit $AC_EXIT with artifact_present $AC_PRESENT," >&2
  echo "              expected 0 and false. That pair IS GAMS-02's firing input produced by the" >&2
  echo "              real binary: exit 0 means GAMS ran, not that the model solved. If the" >&2
  echo "              toolchain has started writing volume_path.json under action=c, report it" >&2
  echo "              as a FINDING rather than adjusting the expectation." >&2
  exit 1
fi

# --- Self-check 2: the leading-zero token changed the bytes -----------------
GOLDEN_SHA=$(jq -r '.golden.sha256' "$OUT")
ZERO_SHA=$(jq -r '.leading_zero_run.sha256' "$OUT")
ZERO_EXIT=$(jq -r '.leading_zero_run.exit' "$OUT")
if [ -z "$ZERO_SHA" ] || [ "$ZERO_SHA" = "null" ]; then
  echo "CAPTURE FAIL: the leading-zero run recorded no digest at all." >&2
  exit 1
fi
if [ "$ZERO_EXIT" != "0" ]; then
  echo "CAPTURE FAIL: the leading-zero run exited $ZERO_EXIT, expected 0." >&2
  echo "              The whole point is that it SUCCEEDS with every gate green and different" >&2
  echo "              bytes; a non-zero exit is a refusal, which proves nothing about rendering." >&2
  exit 1
fi
if [ "$ZERO_SHA" = "$GOLDEN_SHA" ]; then
  echo "CAPTURE FAIL: the leading-zero run digests EQUAL to the golden." >&2
  echo "              Then two spellings of one value give one artifact, the renderer is not" >&2
  echo "              load-bearing, and Phase 25's key normalisation has lost its motivation." >&2
  echo "              Report it; do not adjust it." >&2
  exit 1
fi

# --- Self-check 3: the true CONOPT version still has its decoy --------------
CONOPT=$(jq -r '.conopt_version' "$OUT")
CONOPT_LINK=$(jq -r '.conopt_link_version' "$OUT")
CONOPT_SO=$(jq -r '.conopt_so_name' "$OUT")
if [ -z "$CONOPT" ] || [ "$CONOPT" = "null" ]; then
  echo "CAPTURE FAIL: no CONOPT version was recorded." >&2
  exit 1
fi
if [ "$CONOPT" = "$CONOPT_LINK" ] || [ "$CONOPT" = "$CONOPT_SO" ]; then
  echo "CAPTURE FAIL: the true CONOPT version '$CONOPT' equals a decoy" >&2
  echo "              (link '$CONOPT_LINK', shared object '$CONOPT_SO')." >&2
  echo "              Equality means the exhibit lost the decoy it exists to distinguish, and" >&2
  echo "              the inequality cabal test asserts would then be unfalsifiable." >&2
  exit 1
fi

# --- Self-check 4: the whitelist run reproduced the committed golden --------
WL_SHA=$(jq -r '.whitelist_run.sha256' "$OUT")
GOLDEN_DISK=$(sha256sum "$GOLDEN" | cut -d' ' -f1)
if [ "$GOLDEN_SHA" != "$GOLDEN_DISK" ]; then
  echo "CAPTURE FAIL: the artifact records golden.sha256 $GOLDEN_SHA and $GOLDEN digests" >&2
  echo "              $GOLDEN_DISK on this disk. The anchor every byte claim is stated against" >&2
  echo "              is not the file it names." >&2
  exit 1
fi
if [ "$WL_SHA" != "$GOLDEN_SHA" ]; then
  echo "CAPTURE FAIL: the whitelisted solve produced $WL_SHA and the committed golden is" >&2
  echo "              $GOLDEN_SHA. The real toolchain no longer reproduces the bytes this" >&2
  echo "              repository was built against. Report it as a FINDING." >&2
  exit 1
fi

# --- Report ----------------------------------------------------------------
echo "wrote $OUT"
echo "  GATE:      action=c  exit=$AC_EXIT  artifact_present=$AC_PRESENT  (exit 0, nothing written)"
echo "  RENDERER:  leading zero -> $ZERO_SHA at exit $ZERO_EXIT (golden $GOLDEN_SHA)"
echo "  CONOPT:    true $CONOPT   link decoy $CONOPT_LINK   object decoy $CONOPT_SO"
echo "  BYTES:     whitelist=$WL_SHA minimal=$(jq -r '.minimal_run.sha256' "$OUT") hostile=$(jq -r '.hostile_env_run.sha256' "$OUT")"
echo "  VERDICTS:  $((N_OBS - N_BAD))/$N_OBS pass"
echo "  LEAVES:    $(jq -r 'paths(scalars) | join(".")' "$OUT" | wc -l)  (plan 24-05's sentinel budget input; the harness mutates JSON nulls too and jq omits them, so its count is the larger one)"
