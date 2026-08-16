#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# capture-store-conformance.sh -- stand a real Postgres up, drive every
# database-requiring observation against it, and record the result in
# offchain/rig/store-conformance.json.
#
# WHY THIS FILE EXISTS
# --------------------
# Seven of Phase 23's guards can only be OBSERVED against a server: the Binary
# wart's silent value-level corruption, the jsonb exhibit, the checksum-drift
# exit code, the migration lock, the double run from an empty database,
# key_scheme orphaning against real SQL, and the live catalogue's constraint
# columns. A guard never seen rejecting is treated as absent, so each one is
# DRIVEN here rather than argued. This is the only place in the phase that needs
# a database at all -- `cabal test` opens no socket, by construction.
#
# THE GATE IS A VALUE, NOT A GREEN BUILD
#   jq -r '.corpus[] | select(.name=="octal-escape") | .bare_out_len'
# must print 3 while .in_len prints 6 and .bare_outcome is "returned" -- six
# bytes in, three bytes out, statement succeeded, no error raised. That is the
# only corpus member whose broken-path behaviour is a WRONG VALUE rather than an
# exception, and an exception is shaped exactly like a dead connection.
#
# WHERE CFMM_REQUIRE_DB LIVES, AND WHY IT MOVED
# ---------------------------------------------
# HERE, and nowhere near `cabal test`. Gating the suite on it fails OPEN: a
# workflow whose env block drifts silently returns to skip-mode and reports
# green, which is this repository's advertised-and-dead defect one layer up.
# Here it means "refuse to emit an artifact at all when the database is
# unreachable", so its failure mode is a STALE artifact -- caught by the
# computed freshness oracle -- instead of a TRUNCATED one, which nothing
# catches.
#
# WHY THE ARTIFACT IS COMMITTED
# -----------------------------
# So `cabal test` can assert over real database evidence while STAYING
# database-independent. A fresh checkout has the artifact; there is nothing to
# provision and nothing to skip.
#
# USAGE
#   bash offchain/rig/capture-store-conformance.sh
#
# It provisions and REMOVES its own container. It does not touch the chain rig,
# it does not read another worktree, and it never writes to offchain/migrations.
# ---------------------------------------------------------------------------
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

OUT=offchain/rig/store-conformance.json
GOLDEN=offchain/rig/volume-path-golden.json
MIGRATIONS=offchain/migrations

# Configuration, not credentials. The image tag is a deliberate, documented pin
# (DB-04) and the port is deliberately NOT the default: a developer's own local
# Postgres must not be able to silently satisfy this connection and hand the
# capture a schema nobody in this repository created.
STORE_PG_IMAGE="${STORE_PG_IMAGE:-postgres:18-alpine}"
STORE_PG_PORT="${STORE_PG_PORT:-55433}"
CFMM_REQUIRE_DB="${CFMM_REQUIRE_DB:-1}"

# Per-run, never a shared singleton. Two captures on one machine must not be
# able to observe each other's migrations.
DB_NAME="cfmm_store_$$"
CONTAINER="cfmm-store-conformance-$$"

# Generated per run and never written to a tracked file. It exists only in this
# process's environment and in the container that is destroyed on exit.
DB_PASSWORD="$(head -c 24 /dev/urandom | od -An -tx1 | tr -d ' \n')"

export STORE_PG_IMAGE
export CFMM_REQUIRE_DB

# --- Preconditions: fail loudly, never default -----------------------------
if [ "$CFMM_REQUIRE_DB" != "1" ]; then
  echo "CAPTURE FAIL: CFMM_REQUIRE_DB is '$CFMM_REQUIRE_DB', expected 1." >&2
  echo "              This capture has exactly one mode. There is no skip path, because a" >&2
  echo "              capture that skips writes a stale artifact and reports success." >&2
  exit 1
fi
if ! command -v docker >/dev/null 2>&1; then
  echo "CAPTURE FAIL: docker is not on PATH, so no database can be provisioned." >&2
  echo "              CFMM_REQUIRE_DB=1: this script emits NO artifact rather than a partial" >&2
  echo "              one. The committed $OUT is left exactly as it was." >&2
  exit 1
fi
if ! command -v jq >/dev/null 2>&1; then
  echo "CAPTURE FAIL: jq is not on PATH; the value-level self-checks below cannot run." >&2
  echo "              A capture whose gate cannot be evaluated must not write an artifact." >&2
  exit 1
fi
if [ ! -f "$GOLDEN" ]; then
  echo "CAPTURE FAIL: no golden artifact at $(realpath -m "$GOLDEN")." >&2
  echo "              The jsonb exhibit has no subject, and BYTE-02 cannot be exercised by" >&2
  echo "              synthetic bytes -- the key reorder is a function of the real key names." >&2
  exit 1
fi
if [ ! -d "$MIGRATIONS" ] || [ -z "$(ls -A "$MIGRATIONS" 2>/dev/null)" ]; then
  echo "CAPTURE FAIL: $(realpath -m "$MIGRATIONS") is missing or empty." >&2
  echo "              There is no schema to migrate, so every observation below would be" >&2
  echo "              taken against a database with no tables in it." >&2
  exit 1
fi

# --- VALIDATE FIRST, REPLACE SECOND ----------------------------------------
# The writer renames into place, so there is no truncation window -- but a
# capture that FAILS one of the self-checks below would already have destroyed
# the good committed evidence by the time the check fired. The previous artifact
# is kept beside the target and put BACK on any non-zero exit, including a
# SIGINT. On success it is removed. `git status` is therefore clean-or-correct
# after every run, never neither. Same shape as capture-cheat-swap-proof.sh, and
# for the same measured reason.
if [ -f "$OUT" ]; then
  cp -p "$OUT" "$OUT.prev"
  PREV_SHA=$(sha256sum "$OUT" | cut -d' ' -f1)
else
  PREV_SHA="(no previous artifact)"
fi

cleanup() {
  local rc=$?
  docker rm -f "$CONTAINER" >/dev/null 2>&1 || true
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

# --- Provision -------------------------------------------------------------
echo "  starting $STORE_PG_IMAGE as $CONTAINER on 127.0.0.1:$STORE_PG_PORT"
if ! docker run -d --rm \
      --name "$CONTAINER" \
      -e POSTGRES_PASSWORD="$DB_PASSWORD" \
      -e POSTGRES_DB="$DB_NAME" \
      -p "127.0.0.1:$STORE_PG_PORT:5432" \
      "$STORE_PG_IMAGE" >/dev/null; then
  echo "CAPTURE FAIL: docker run did not start $STORE_PG_IMAGE." >&2
  echo "              No artifact was written." >&2
  exit 1
fi

# Bounded, and it fails loudly rather than hanging. A readiness poll with no
# ceiling turns "the database never came up" into "the capture is still going".
READY=0
for _ in $(seq 1 60); do
  if docker exec "$CONTAINER" pg_isready -U postgres -d "$DB_NAME" >/dev/null 2>&1; then
    READY=1
    break
  fi
  sleep 0.5
done
if [ "$READY" != "1" ]; then
  echo "CAPTURE FAIL: $STORE_PG_IMAGE did not become ready within 30 seconds." >&2
  echo "              Container log tail:" >&2
  docker logs --tail 20 "$CONTAINER" >&2 2>&1 || true
  echo "              No artifact was written." >&2
  exit 1
fi

export PGSTORE_DSN="host=127.0.0.1 port=$STORE_PG_PORT user=postgres password=$DB_PASSWORD dbname=$DB_NAME"

# --- The capture itself ----------------------------------------------------
cabal run -v0 store-conformance

# Stable, sorted formatting so two runs differ only where the MEASUREMENT
# differs and never because of key ordering.
jq -S . "$OUT" > "$OUT.tmp" && mv "$OUT.tmp" "$OUT"

# --- Self-check 0: the artifact is COMPLETE and accounts for every law ------
# sc_complete is written false and flipped only after every block returned, so a
# truncated run is a FACT in the file rather than a shorter file. sc_law_count
# comes from `length store_laws` in the library, so a verdict map that is short
# by one is arithmetic, not a judgement call.
COMPLETE=$(jq -r '.sc_complete' "$OUT")
N_LAWS=$(jq -r '.sc_law_count' "$OUT")
N_VERDICTS=$(jq -r '.law_verdicts | length' "$OUT")
if [ "$COMPLETE" != "true" ]; then
  echo "CAPTURE FAIL: sc_complete is $COMPLETE. The run did not reach the end." >&2
  exit 1
fi
if [ "$N_VERDICTS" != "$N_LAWS" ]; then
  echo "CAPTURE FAIL: $N_VERDICTS law verdicts recorded but the library defines $N_LAWS laws." >&2
  echo "              A law whose verdict nothing recorded is a law that skipped." >&2
  exit 1
fi
FAILED_LAWS=$(jq -r '.law_verdicts | to_entries | map(select(.value != "pass")) | length' "$OUT")
if [ "$FAILED_LAWS" != "0" ]; then
  echo "CAPTURE FAIL: $FAILED_LAWS of $N_LAWS laws did not pass against a real Postgres:" >&2
  jq -r '.law_verdicts | to_entries[] | select(.value != "pass") | "              \(.key): \(.value)"' "$OUT" >&2
  echo "              The SAME laws pass against Store.Memory inside cabal test. A law that" >&2
  echo "              holds in tier B and fails in tier C is a FINDING about the store, not a" >&2
  echo "              number to adjust." >&2
  exit 1
fi

# --- Self-check 1: THE GATE, the silent value-level corruption -------------
# THE CARDINALITY COMES FIRST AND FROM A DIFFERENT FIELD. `select(.name==...)`
# over a member that is not there yields nothing, and every comparison below
# would then be "" against a literal -- which is the absent-subject defect this
# project's review history is dominated by. So the row is COUNTED before it is
# read.
N_OCTAL=$(jq -r '[.corpus[] | select(.name=="octal-escape")] | length' "$OUT")
if [ "$N_OCTAL" != "1" ]; then
  echo "CAPTURE FAIL: the artifact carries $N_OCTAL corpus rows named octal-escape, expected 1." >&2
  echo "              It is the ONLY member whose broken-path behaviour is a wrong VALUE rather" >&2
  echo "              than an exception. Without it the whole negative control is vacuous." >&2
  exit 1
fi
read -r O_IN O_BARE O_OUTCOME O_INSHA O_BINSHA O_BARESHA <<<"$(jq -r '.corpus[]
  | select(.name=="octal-escape")
  | "\(.in_len) \(.bare_out_len) \(.bare_outcome) \(.in_sha256) \(.binary_out_sha256) \(.bare_out_sha256)"' "$OUT")"
if [ "$O_OUTCOME" != "returned" ]; then
  echo "CAPTURE FAIL: octal-escape's bare path recorded outcome '$O_OUTCOME', expected returned." >&2
  echo "              An exception here would mean the statement FAILED. The whole point of this" >&2
  echo "              member is that it SUCCEEDS and hands back the wrong bytes -- 'it threw'" >&2
  echo "              cannot be told apart from the database being down." >&2
  exit 1
fi
if [ "$O_IN" != "6" ] || [ "$O_BARE" != "3" ]; then
  echo "CAPTURE FAIL: octal-escape went in at $O_IN bytes and the bare path returned $O_BARE," >&2
  echo "              expected 6 -> 3. If these are equal the server stopped re-reading the" >&2
  echo "              legacy escape format and the Binary wart has lost its subject; report it" >&2
  echo "              as a FINDING rather than adjusting the numbers." >&2
  exit 1
fi
if [ "$O_BINSHA" != "$O_INSHA" ]; then
  echo "CAPTURE FAIL: octal-escape did not round-trip through the Binary path." >&2
  echo "              in $O_INSHA / out $O_BINSHA" >&2
  exit 1
fi
if [ "$O_BARESHA" = "$O_INSHA" ]; then
  echo "CAPTURE FAIL: the bare path returned the INPUT digest for octal-escape." >&2
  echo "              Then the two paths agree and this member proves nothing." >&2
  exit 1
fi

# --- Self-check 1b: the corpus is whole, and the loud half is loud ----------
# The value-level kill above is one member. The exception behaviour is the OTHER
# measured half and it is asserted separately so that a corpus which silently
# lost its ServerRejects members still fails here.
N_CORPUS=$(jq -r '.corpus | length' "$OUT")
if [ "$N_CORPUS" -lt 7 ]; then
  echo "CAPTURE FAIL: the corpus block has $N_CORPUS members, expected at least 7." >&2
  exit 1
fi
N_REJECTS=$(jq -r '[.corpus[] | select(.bare_outcome=="SqlError")] | length' "$OUT")
if [ "$N_REJECTS" -lt 1 ]; then
  echo "CAPTURE FAIL: not one corpus member made the bare path raise. The three ServerRejects" >&2
  echo "              members are measured to produce an encoding error; zero of them doing so" >&2
  echo "              means the bare path is not the bare path." >&2
  exit 1
fi

# --- Self-check 2: bytea is authoritative and jsonb is not -----------------
read -r J_LEN J_IN J_OUT J_DOC <<<"$(jq -r '.jsonb_exhibit
  | "\(.raw_len) \(.raw_in_sha256) \(.raw_out_sha256) \(.doc_text_sha256)"' "$OUT")"
if [ "$J_LEN" != "606" ]; then
  echo "CAPTURE FAIL: the exhibit ran over $J_LEN bytes, expected the real artifact's 606." >&2
  exit 1
fi
if [ "$J_IN" != "$J_OUT" ]; then
  echo "CAPTURE FAIL: the real artifact did NOT round-trip through bytea." >&2
  echo "              in  $J_IN" >&2
  echo "              out $J_OUT" >&2
  echo "              This is BYTE-01 failing on the only corpus that can exercise BYTE-02." >&2
  exit 1
fi
if [ "$J_DOC" = "$J_OUT" ]; then
  echo "CAPTURE FAIL: the jsonb rendering digests EQUAL to the bytea round-trip." >&2
  echo "              Then jsonb preserved the bytes, the exhibit has lost its subject, and" >&2
  echo "              'bytea is authoritative' is being demonstrated by a comparison that could" >&2
  echo "              not have failed. Report it; do not adjust it." >&2
  exit 1
fi

# --- Self-check 3: the migration observations, each with its control -------
read -r M_RUN1 M_RUN2 M_DRIFT M_TRY M_APPLIED M_FREEDTRY M_FREEDAPPLIED <<<"$(jq -r '.migration_checks
  | "\(.empty_db_run1) \(.empty_db_run2_applied) \(.checksum_drift_exit) \(.second_migrator_try_lock) \(.second_migrator_applied) \(.after_release_try_lock) \(.after_release_applied)"' "$OUT")"
if [ "$M_RUN1" != "true" ] || [ "$M_RUN2" != "0" ]; then
  echo "CAPTURE FAIL: the empty-database double run recorded run1=$M_RUN1 run2_applied=$M_RUN2," >&2
  echo "              expected true and 0." >&2
  exit 1
fi
if [ "$M_DRIFT" != "1" ]; then
  echo "CAPTURE FAIL: a corrupted migration checksum exited $M_DRIFT, expected 1." >&2
  echo "              The library RETURNS an error and lets the process exit 0; the 1 is the" >&2
  echo "              runner's own exitFailure and it is the whole of DB-01's 'exits non-zero'." >&2
  exit 1
fi
if [ "$M_TRY" != "false" ] || [ "$M_APPLIED" != "0" ]; then
  echo "CAPTURE FAIL: the excluded migrator recorded try_lock=$M_TRY applied=$M_APPLIED," >&2
  echo "              expected false and 0." >&2
  exit 1
fi
# THE POSITIVE CONTROL. Without it, "applied 0" is satisfied by a migrator that
# could never apply anything, by a closed connection, and by a directory with
# nothing new in it. The probe directory carries a THIRD migration, so after the
# lock is released exactly one must land.
if [ "$M_FREEDTRY" != "true" ] || [ "$M_FREEDAPPLIED" != "1" ]; then
  echo "CAPTURE FAIL: after the lock was released the second migrator recorded" >&2
  echo "              try_lock=$M_FREEDTRY applied=$M_FREEDAPPLIED, expected true and 1." >&2
  echo "              Then the exclusion above excluded nothing: a migrator that cannot apply" >&2
  echo "              anything reports applied 0 whether the lock works or not." >&2
  exit 1
fi

# --- Self-check 4: the LIVE catalogue names all three columns --------------
# Read from pg_constraint, not from the .sql. The file half is already asserted
# inside cabal test; this is the half that proves the file was actually applied.
COLUMNS=$(jq -c '.unique_constraint.columns' "$OUT")
if [ "$COLUMNS" != '["model","key_scheme","key"]' ]; then
  echo "CAPTURE FAIL: the live identity constraint reports columns $COLUMNS," >&2
  echo '              expected ["model","key_scheme","key"].' >&2
  echo "              Dropping key_scheme makes a key-formula change CORRUPT the old rows" >&2
  echo "              instead of orphaning them (KEY-07)." >&2
  exit 1
fi

# --- Self-check 5: the freshness oracle has something to bite on -----------
N_MIGRATIONS=$(jq -r '.migrations | length' "$OUT")
N_ON_DISK=$(ls -A "$MIGRATIONS" | wc -l)
if [ "$N_MIGRATIONS" != "$N_ON_DISK" ]; then
  echo "CAPTURE FAIL: $N_MIGRATIONS migration digests recorded but $N_ON_DISK files are on disk." >&2
  echo "              The migration library applies EVERY entry in that directory with no" >&2
  echo "              extension filter, so a file the artifact does not digest is a file that" >&2
  echo "              runs unobserved." >&2
  exit 1
fi

# --- Report ----------------------------------------------------------------
echo "wrote $OUT"
echo "  GATE:      octal-escape  in=$O_IN bare_out=$O_BARE outcome=$O_OUTCOME  (silent, no error)"
echo "  BYTE-01:   the 606-byte artifact round-tripped through bytea"
echo "  BYTE-02:   the jsonb rendering digests DIFFERENTLY -- bytea is authoritative"
echo "  DB-01:     checksum drift exited $M_DRIFT; empty-db second run applied $M_RUN2"
echo "  LOCK:      excluded try=$M_TRY applied=$M_APPLIED, after release try=$M_FREEDTRY applied=$M_FREEDAPPLIED"
echo "  KEY-07:    live catalogue columns $COLUMNS"
echo "  LAWS:      $N_VERDICTS/$N_LAWS pass against $(jq -r '.server_version' "$OUT") ($(jq -r '.image_tag' "$OUT"))"
echo "  LEAVES:    $(jq -r 'paths(scalars) | join(".")' "$OUT" | wc -l)  (plan 23-05's sentinel budget input)"
