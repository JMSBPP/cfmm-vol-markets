#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# capture-fee-split.sh -- drive the REAL GAMS 54.1 / CONOPT 4.39 toolchain
# across a boundary-bracketing fee-split grid, out of band, and record what it
# did in offchain/rig/fee-split-conformance.json.
#
# WHY THIS FILE EXISTS
# --------------------
# FEE-02's last clause is the only one in the phase that needs the real solver:
# "the Haskell admissibility verdict AGREES with the GAMS prover's verdict on
# every grid point. A disagreement is a bug in one of them and fails the phase;
# it is not absorbed by a tolerance." Everything else about the splitter is
# exact integer arithmetic asserted in-suite. This is the one place a second,
# independent implementation of the same gate gets to answer.
#
# THE DISCRIMINATOR IS THE MODEL'S SOURCE LINE, NOT THE EXIT CODE
# ---------------------------------------------------------------
# MEASURED over 160 real invocations: `gams` exits 3 for at least six different
# reasons and the abort message reaches neither stdout nor stderr. It lands in
# volume_path.log in curdir and it names the model's own source line:
#
#   *** Error at line 109: Execution halted: abort$1 'dStar outside the ...'
#
#   line 109      dStar outside the half-ellipse -- THE admissibility refusal
#   line 91       equal fees
#   line 103      kappa outside a solvable range -- a FIXTURE property
#   lines 171/173 solveStat / modelStat -- CONOPT could not solve an ADMISSIBLE
#                 point. That is admissible-but-unsolved and it is NOT a
#                 disagreement.
#
# So gams_admits is (abort_line != 109). Deriving it from the exit code instead
# reports a disagreement on every CONOPT-infeasible row, which at this fixture's
# volTgtWad is eight of the twelve grid rows.
#
# DO NOT RAISE volTgtWad TO RESCUE AN INFEASIBLE ROW. Six values and three
# nEvents settings were swept and all still abort: the model's own u box of
# [1e-3, 1e3] bounds what any volume can reach, and dStar = 0.49 already needs
# kappa >= 1.4980.
#
# THE GATE IS A VALUE, NOT A GREEN BUILD
#   jq -r '.grid | map(select(.haskell_admits != .gams_admits)) | length'   must print 0
#   jq -r '.grid | map(.haskell_admits) | unique | length'                  must print 2
#   jq -r '.controls | map(select(.control_exit != 0)) | length'            must print 0
#   jq -r '.complete'                                                       must print true
# The first is FEE-02 itself. The second is the two-sidedness that keeps the
# first from being satisfied by a function that answers one way always. The
# third is what makes an abort at a boundary ATTRIBUTABLE: a pair whose control
# produced an artifact through the unmodified production path is a pair the
# toolchain can answer at all.
#
# WHERE CFMM_REQUIRE_GAMS LIVES, AND WHY IT LIVES HERE
# ----------------------------------------------------
# HERE, and nowhere near `cabal test`. Gating the suite on it fails OPEN: a
# workflow whose env block drifts silently returns to skip-mode and reports
# green, which is this repository's advertised-and-dead defect one layer up.
# Here it means "refuse to emit an artifact at all when the solver is
# unreachable", so the failure mode is a STALE artifact -- caught by the
# freshness oracle the suite recomputes over Fee/Split.hs -- instead of a
# TRUNCATED one, which nothing catches.
#
# USAGE
#   GAMS_MODEL=/abs/path/to/volume_path.gms \
#     bash offchain/rig/capture-fee-split.sh
#
#   GAMS_BIN          the prover. Resolved with `command -v gams` when unset.
#   GAMS_MODEL        REQUIRED here. volume_path.gms is NOT in this worktree; it
#                     lives in the sibling cfmm-wt/gams worktree, whose checkout
#                     carries the model/ tree this branch does not.
#   CFMM_REQUIRE_GAMS must be 1. There is no other mode.
#
# It writes every run directory into its own scratch directory under the system
# temp directory, removes them on exit including on SIGINT, and NEVER writes
# into model/, which is another workstream's territory. The only path under
# model/ this script ever touches is the one GAMS_MODEL names, and it opens it
# read-only through the prover.
# ---------------------------------------------------------------------------
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

OUT=offchain/rig/fee-split-conformance.json
SPLITTER=offchain/lib/Fee/Split.hs

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
if [ ! -f "$SPLITTER" ]; then
  echo "CAPTURE FAIL: the freshness oracle's subject $SPLITTER is not on disk." >&2
  echo "              Every haskell_admits in the artifact comes from that module; a digest of a" >&2
  echo "              file that is gone would make the suite's oracle compare nothing." >&2
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
# after every run, never neither.
if [ -f "$OUT" ]; then
  cp -p "$OUT" "$OUT.prev"
  PREV_SHA=$(sha256sum "$OUT" | cut -d' ' -f1)
else
  PREV_SHA="(no previous artifact)"
fi

SCRATCH="$(mktemp -d "${TMPDIR:-/tmp}/cfmm-fee-split-XXXXXX")"

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

# --- The capture itself ----------------------------------------------------
# Sixteen invocations: twelve grid rows through the UNGATED renderer and the raw
# invocation (which returns the log the abort line is read from), and four
# controls through the unmodified production composition.
cabal run -v0 fee-split-conformance -- "$SCRATCH"

# Stable, sorted formatting so two runs differ only where the MEASUREMENT
# differs and never because of key ordering.
jq -S . "$OUT" > "$OUT.tmp" && mv "$OUT.tmp" "$OUT"

# --- Self-check 0: the artifact is COMPLETE and the right shape -------------
# THE CARDINALITY COMES FIRST AND FROM A DIFFERENT FIELD: a jq path that is not
# there yields "" and every comparison below would then be "" against a literal,
# which is the absent-subject defect this project's review history is dominated
# by.
COMPLETE=$(jq -r '.complete' "$OUT")
if [ "$COMPLETE" != "true" ]; then
  echo "CAPTURE FAIL: complete is $COMPLETE. The run did not reach the end." >&2
  exit 1
fi
ROWS=$(jq -r '.grid | length' "$OUT")
CTLS=$(jq -r '.controls | length' "$OUT")
if [ "$ROWS" != "12" ] || [ "$CTLS" != "4" ]; then
  echo "CAPTURE FAIL: the artifact carries $ROWS grid rows and $CTLS controls, expected 12 and 4." >&2
  echo "              A shortened grid reports every point it DID measure as agreeing." >&2
  exit 1
fi

# --- Self-check 1: THE GATE, Haskell and GAMS agree on every point ----------
DISAGREE=$(jq -r '.grid | map(select(.haskell_admits != .gams_admits)) | length' "$OUT")
if [ "$DISAGREE" != "0" ]; then
  echo "CAPTURE FAIL: $DISAGREE grid rows DISAGREE between Fee.Split and the real prover:" >&2
  jq -r '.grid[] | select(.haskell_admits != .gams_admits)
         | "              (\(.phiXpips), \(.phiMpips)) @ \(.txlVolumeRate): haskell \(.haskell_admits) gams \(.gams_admits) exit \(.gams_exit) line \(.gams_abort_line)"' "$OUT" >&2
  echo "              That is FEE-02's stated failure condition: a disagreement is a bug in one of" >&2
  echo "              them and fails the phase; it is not absorbed by a tolerance. Report it with" >&2
  echo "              the row, the exact E and the boundary. Do NOT weaken a check." >&2
  exit 1
fi

# --- Self-check 2: the grid carries BOTH verdicts ---------------------------
VERDICTS=$(jq -r '.grid | map(.haskell_admits) | unique | length' "$OUT")
if [ "$VERDICTS" != "2" ]; then
  echo "CAPTURE FAIL: the grid carries $VERDICTS distinct Haskell verdicts, expected 2." >&2
  echo "              A one-sided grid makes the agreement above vacuous in one direction: a" >&2
  echo "              predicate that answered the same way always would pass it." >&2
  exit 1
fi

# --- Self-check 3: every control SOLVED, so every abort is attributable -----
BADCTL=$(jq -r '.controls | map(select(.control_exit != 0)) | length' "$OUT")
if [ "$BADCTL" != "0" ]; then
  echo "CAPTURE FAIL: $BADCTL of $CTLS controls did not exit 0:" >&2
  jq -r '.controls[] | select(.control_exit != 0)
         | "              (\(.phiXpips), \(.phiMpips)) @ \(.txlVolumeRate): exit \(.control_exit)"' "$OUT" >&2
  echo "              A pair whose control cannot be solved at all leaves its boundary aborts" >&2
  echo "              UNATTRIBUTED. Pick a control target the sweep measured as solvable for that" >&2
  echo "              pair; do NOT raise volTgtWad, which was measured not to work." >&2
  exit 1
fi

# --- Self-check 4: the refusal rows really are the ELLIPSE, by LINE ---------
# The one observation the whole differential exists for. Without it the capture
# can pass having proven nothing: every row could have aborted for a reason that
# has nothing to do with the fee pair.
LINE=$(jq -r '.ellipse_abort_line' "$OUT")
REFUSED=$(jq -r --argjson l "$LINE" '.grid | map(select(.gams_abort_line == $l)) | length' "$OUT")
if [ "$REFUSED" != "4" ]; then
  echo "CAPTURE FAIL: $REFUSED grid rows aborted at model line $LINE, expected 4." >&2
  echo "              Line $LINE is the half-ellipse refusal and it is the ONLY place GAMS is ever" >&2
  echo "              observed rejecting anything in this repository. One row per pair -- the" >&2
  echo "              boundary minus one pip -- must land there." >&2
  exit 1
fi

# --- Report ----------------------------------------------------------------
echo "wrote $OUT"
echo "  AGREEMENT: $DISAGREE disagreements over $ROWS grid rows, $VERDICTS distinct verdicts"
echo "  ELLIPSE:   $REFUSED rows refused at model line $LINE"
echo "  CONTROLS:  $((CTLS - BADCTL))/$CTLS exited 0"
echo "  TOOLCHAIN: GAMS $(jq -r '.gams_version' "$OUT")  CONOPT $(jq -r '.conopt_version' "$OUT")"
echo "  MODEL:     $(jq -r '.model_sha256' "$OUT")"
echo "  SPLITTER:  $(jq -r '.splitter_source_sha256' "$OUT")"
echo "  LEAVES:    $(jq -r 'paths(scalars) | join(".")' "$OUT" | wc -l)  (the sentinel budget input; the harness mutates JSON nulls too and jq omits them, so its count is the larger one)"
