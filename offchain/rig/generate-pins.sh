#!/usr/bin/env bash
#
# generate-pins.sh -- regenerate offchain/rig/rig-pins.json from the IMPORTED interface files.
#
# WHY THIS FILE EXISTS
# --------------------
# Every selector and topic0 the off-chain drivers use is COMPUTED here, by `cast`, from a
# signature string this script PARSED out of an interface file under src/interfaces/. Not one
# hex value appears as a literal in this script. Re-typing an imported value is precisely the
# failure mode this milestone exists to kill (research 5.6): a hand-copied selector looks
# exactly like a correct one until it is called.
#
# The in-file `const` declaration is used ONLY as a CROSS-CHECK. The computed value is what
# gets written. When the two disagree the script ABORTS with a diff -- either the parser is
# wrong or the interface file is wrong, and both are findings, not something to paper over by
# preferring one side.
#
# THE `retired` BLOCK IS NOT A PIN MAP
# -----------------------------------
# `retired` records values that must NEVER appear as live constants. It is data for the
# falsifiability test in phase 21 / plan 20-05. It is deliberately NOT part of `selectors` or
# `topics` and must never be iterated by a pin check as if it were a live pin. The same
# sentence is written into the JSON as `retired._note` so the next reader sees it there too.
#
# USAGE
#   bash offchain/rig/generate-pins.sh          # rewrites offchain/rig/rig-pins.json
#   RIG_PINS=/tmp/copy.json bash offchain/rig/generate-pins.sh   # writes the copy instead
# Re-running is idempotent: `git diff --exit-code offchain/rig/rig-pins.json` stays clean.
#
set -euo pipefail

cd "$(dirname "$0")/../.."
ROOT="$PWD"

# RIG_PINS IS HONOURED HERE, on the file that WRITES, exactly as 90765c1 made deploy-rig.sh
# honour RIG_MANIFEST. README.md:274 states the rule with no exception for the writer and
# Rig/Manifest.hs:193 honours it on the read side; this constant was the one place that
# meant something different by the same variable.
#
# MEASURED before the fix, with `RIG_PINS=<copy carrying generatedFrom:"SENTINEL" and
# create_order removed>`: the run printed "== wrote offchain/rig/rig-pins.json ==", the
# TRACKED file was the file replaced, and the pointed-at copy still read
# generatedFrom = SENTINEL afterwards. Dead on the writer, destructive to the tracked
# artifact -- the same shape as the RIG_MANIFEST defect.
#
# HONOURED rather than REFUSED, for 90765c1's reason: a refusal would leave an operator who
# exported RIG_PINS for a falsification run having to remember to unexport it before
# regenerating, and forgetting is the destructive direction. Note what it does NOT redirect:
# the INPUTS are still the imported interface files and notes/DATA_CONTRACT.md, unconditionally.
OUT="${RIG_PINS:-offchain/rig/rig-pins.json}"
REF_FILE="offchain/rig/import-ref.txt"
DATA_CONTRACT="notes/DATA_CONTRACT.md"

# FLOORS. Without them a parse that matched NOTHING was a successful run: every awk
# still exits 0 on zero matches, the compute loop is vacuous, and the final `jq -n`
# wrote {"selectors":{},"topics":{},...} OVER the tracked file while printing
# "0 unique pins". FALSIFIED by drifting the const declarations to `const bytes32
# NAME = 0x..;` (a type annotation the :136 regex does not match): the old form
# exited 0 and replaced rig-pins.json, sha f4814d4f -> 5040c858.
#
# These are MEASURED counts at import-ref 2039f278, not guesses. They are a FLOOR,
# not an equality: adding an interface pin is expected and must not need an edit
# here. REMOVING one must -- that is the point.
MIN_SELECTORS=30
MIN_TOPICS=5
MIN_PINS=$((MIN_SELECTORS + MIN_TOPICS))

# WHERE THE STALE E1 TOPIC0 IS READ FROM, AND WHY IT MOVED
# -------------------------------------------------------
# Until plan 20-05 this value was parsed out of offchain/lib/VolOrder/Decode.hs, which carried it
# as a hardcoded constant. 20-05's literal purge deleted that constant, so this generator now
# reads it from the file the constant was originally transcribed FROM: the superseded duplicate
# module src/modules/VolOrderManagerMod.plk (the live module is src/modules/pos_spec/
# VolOrderManagerMod.plk). That is strictly better provenance -- it names the actual origin of the
# rot rather than one of its copies -- and it keeps the rule intact that no retired value is ever
# TYPED into this script. It is another track's file and is only ever READ here.
#
# If plank ever deletes that superseded module this script fails LOUDLY (the count != 1 abort
# below), which is the correct outcome: the retired value would then need a new recorded home,
# not a silently dropped entry.
STALE_TOPIC_SRC="src/modules/VolOrderManagerMod.plk"

IFACES=(
  "src/interfaces/pos_spec/VolOrderManagerInterface.plk"
  "src/interfaces/market_state_measurements/RealizedVolatilityInterface.plk"
  "src/interfaces/premium/DynamicFeeInterface.plk"
  "src/interfaces/protocol_integrations/DynamicFeeHookInterface.plk"
  "src/interfaces/protocol_integrations/IMarketStateSocket.plk"
  "src/interfaces/exposure/VegaAccountInterface.plk"
)

for f in "${IFACES[@]}" "$REF_FILE" "$STALE_TOPIC_SRC" "$DATA_CONTRACT"; do
  [ -f "$f" ] || { echo "FATAL: missing input $ROOT/$f" >&2; exit 1; }
done
command -v cast >/dev/null || { echo "FATAL: cast (foundry) not on PATH" >&2; exit 1; }
command -v jq   >/dev/null || { echo "FATAL: jq not on PATH" >&2; exit 1; }

# The destination is checked NOW, not at the emit step. The emit is the last thing this
# script does; a typo'd RIG_PINS discovered there costs the whole parse-and-`cast` pass.
OUT_DIR=$(dirname "$OUT")
[ -d "$OUT_DIR" ] && [ -w "$OUT_DIR" ] || {
  echo "FATAL: cannot write the pin file to $(realpath -m "$OUT")" >&2
  echo "       its directory '$OUT_DIR' does not exist or is not writable." >&2
  if [ -n "${RIG_PINS:-}" ]; then
    echo "       RIG_PINS is set to '$RIG_PINS'; unset it to use the default path." >&2
  else
    echo "       RIG_PINS is unset, so this is the default path -- the repo tree is wrong." >&2
  fi
  exit 1
}
if [ -n "${RIG_PINS:-}" ]; then
  echo "note: RIG_PINS is set -- writing the pin file to $(realpath -m "$OUT")"
  echo "      offchain/rig/rig-pins.json will NOT be touched. The INPUTS are unchanged."
fi

REF="$(tr -d ' \t\n\r' < "$REF_FILE")"
# The SHAPE, not merely the existence, of the anchor. `[ -f ]` above cannot tell a valid ref
# from an EMPTY file, and an empty $REF is written straight through to the pin file's
# generatedFrom -- where every downstream freshness check then compares one empty string to
# another. Measured on the sibling artifact: with import-ref.txt emptied, the cheat-swap
# capture wrote generatedFrom "" and its self-check 4 passed on "" == "", exit 0.
case "$REF" in
  [0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]) ;;
  *) echo "FATAL: $ROOT/$REF_FILE does not hold a 40-digit lowercase sha (got '$REF')." >&2
     echo "       generatedFrom would carry it into the pin file. Re-record the ref:" >&2
     echo "         bash offchain/rig/check-upstream.sh" >&2
     exit 1 ;;
esac

TMP="$(mktemp -d)"
# "$OUT.tmp" is in the trap too: `> "$OUT"` TRUNCATES BEFORE the command that fills
# it runs, so a jq that dies mid-emit used to leave the tracked pin file empty or
# half-written. The generator now writes beside it and renames only on success --
# rename(2) is atomic on the same filesystem, so $OUT is either the old file or the
# whole new one, never a truncation.
trap 'rm -rf "$TMP"; rm -f "$OUT.tmp"' EXIT
SELS="$TMP/selectors.jsonl"; : > "$SELS"
TOPS="$TMP/topics.jsonl";    : > "$TOPS"
RETS="$TMP/retired.jsonl";   : > "$RETS"

# --------------------------------------------------------------------------------------------
# PARSER
#
# Anchored on the `const` declarations, NOT on the comments -- so every declared pin is reached
# and none is hand-picked. For each `const NAME = <hex>;` the parser walks BACKWARD through the
# contiguous comment block directly above it and takes the CLOSEST signature source:
#
#   1. a `// signature::` / `// event::` marker line   (the documented convention), else
#   2. a bare `// name(args)` line                     (the shape DynamicFeeInterface.plk uses)
#
# From that line it accumulates characters until the parenthesis OPENED BY THE SIGNATURE is
# closed, appending continuation `//` lines as needed, and discards everything after that
# closing paren. A single-line regex would silently truncate a wrapped signature and compute a
# wrong hash that still looks exactly like a hash (research 7.3).
#
# A `const NAME =` line with no hex value on the right is SKIPPED DELIBERATELY and counted --
# IMarketStateSocket.plk is seven such lines with no values and no terminators.
# --------------------------------------------------------------------------------------------
PARSER='
function trim(s) { sub(/^[ \t\r]+/, "", s); sub(/[ \t\r]+$/, "", s); return s }

# first non-"indexed" whitespace token of an argument atom == its TYPE; the rest is a
# parameter identifier and is dropped. Idempotent on an already-canonical atom.
function atom_type(a,   n, t, j) {
  n = split(trim(a), t, /[ \t]+/)
  for (j = 1; j <= n; j++) {
    if (t[j] == "indexed" || t[j] == "") continue
    return t[j]
  }
  return ""
}

# Name(uint256 indexed id, uint88 x)  ->  Name(uint256,uint88)
# Nested tuple parens are preserved because "(" and ")" are treated as atom delimiters.
function canon(sig,   i, name, args, res, atom, ch) {
  i    = index(sig, "(")
  name = trim(substr(sig, 1, i - 1))
  args = substr(sig, i + 1)
  args = substr(args, 1, length(args) - 1)
  res  = ""
  atom = ""
  for (i = 1; i <= length(args); i++) {
    ch = substr(args, i, 1)
    if (ch == "," || ch == "(" || ch == ")") { res = res atom_type(atom) ch; atom = "" }
    else                                     { atom = atom ch }
  }
  return name "(" res atom_type(atom) ")"
}

# NOTE: this MUST go to stderr. Parser output is redirected into a TSV file, so a diagnostic
# printed on stdout would land in that file and the operator would see an exit code and nothing
# else -- the same silent-failure class 20-02 removed from verify-import.sh.
function die(msg) { printf("FATAL: parser: %s: %s\n", src, msg) > "/dev/stderr"; exit 3 }

{ line[NR] = $0 }

END {
  n = NR
  skipped = 0
  for (i = 1; i <= n; i++) {
    if (line[i] !~ /^[ \t]*const[ \t]+[A-Za-z_][A-Za-z0-9_]*[ \t]*=/) continue

    cname = line[i]
    sub(/^[ \t]*const[ \t]+/, "", cname)
    sub(/[ \t]*=.*$/, "", cname)

    rhs = line[i]
    sub(/^[ \t]*const[ \t]+[A-Za-z_][A-Za-z0-9_]*[ \t]*=/, "", rhs)
    rhs = trim(rhs); sub(/;[ \t]*$/, "", rhs); rhs = trim(rhs)

    # DELIBERATE SKIP: a const with no hex value on the right-hand side.
    if (rhs !~ /^0[xX][0-9a-fA-F]+$/) {
      skipped++
      printf("SKIP\t%s\t%d\t%s\n", src, i, cname)
      continue
    }
    declared = tolower(rhs)

    # walk backward through the contiguous comment block; keep the CLOSEST candidate of each kind
    mark = 0; bare = 0
    for (j = i - 1; j >= 1; j--) {
      if (line[j] !~ /^[ \t]*\/\//) break
      if (mark == 0 && line[j] ~ /^[ \t]*\/\/[ \t]*(signature|event)::/)              mark = j
      if (bare == 0 && line[j] ~ /^[ \t]*\/\/[ \t]*[A-Za-z_][A-Za-z0-9_]*[ \t]*\(/)   bare = j
    }
    start = (mark != 0) ? mark : bare
    if (start == 0) die("no signature comment above const " cname " (line " i ")")
    shape = (mark != 0) ? "marker" : "bare"

    marker = ""
    if (mark != 0) { marker = (line[start] ~ /event::/) ? "event" : "signature" }

    cur = line[start]
    sub(/^[ \t]*\/\/[ \t]*/, "", cur)
    sub(/^(signature|event)::[ \t]*/, "", cur)

    # balanced-paren accumulation across continuation // lines
    acc = ""; depth = 0; started = 0; j = start
    while (1) {
      done = 0
      for (k = 1; k <= length(cur); k++) {
        ch = substr(cur, k, 1)
        acc = acc ch
        if (ch == "(") { depth++; started = 1 }
        else if (ch == ")") { depth--; if (started && depth == 0) { done = 1; break } }
      }
      if (done) break
      if (!started) die("no open paren in signature comment at line " start)
      j++
      if (j > n || line[j] !~ /^[ \t]*\/\//) die("unterminated signature starting line " start)
      cur = line[j]
      sub(/^[ \t]*\/\/[ \t]*/, "", cur)
      acc = acc " "
    }

    sig = canon(acc)
    if (sig ~ /[ \t]/) die("canonicalised signature still has whitespace: " sig)

    # the DECLARED length decides the kind; the marker must agree with it
    hexlen = length(declared) - 2
    if      (hexlen == 8)  kind = "selector"
    else if (hexlen == 64) kind = "topic"
    else                   die("const " cname " value is neither 8 nor 64 hex digits")
    if (marker == "event"     && kind != "topic")    die("event:: marker on a 4-byte value: " cname)
    if (marker == "signature" && kind != "selector") die("signature:: marker on a 32-byte value: " cname)

    printf("PIN\t%s\t%s\t%s\t%s\t%s\t%d\t%s\n", kind, sig, declared, src, cname, start, shape)
  }
  printf("SKIPPED\t%s\t%d\n", src, skipped)
}
'

echo "== parsing imported interface files =="
PARSED="$TMP/parsed.tsv"
: > "$PARSED"
for f in "${IFACES[@]}"; do
  if ! awk -v src="$f" "$PARSER" "$f" >> "$PARSED"; then
    echo "FATAL: parser aborted on $f -- see the parser message above; no pin file was written" >&2
    exit 3
  fi
done

# the deliberate valueless-const exclusions, named and counted
echo
echo '-- valueless "const NAME =" lines SKIPPED DELIBERATELY (no hex value on the right) --'
if grep -q '^SKIP	' "$PARSED"; then
  awk -F'\t' '$1 == "SKIP" { printf("   skipped  %-56s line %-4s %s\n", $2, $3, $4) }' "$PARSED"
else
  echo "   (none)"
fi
awk -F'\t' '$1 == "SKIPPED" && $3 > 0 { printf("   TOTAL %d skipped in %s\n", $3, $2) }' "$PARSED"
TOTAL_SKIPPED=$(awk -F'\t' '$1 == "SKIPPED" { s += $3 } END { print s + 0 }' "$PARSED")
echo "   grand total skipped: $TOTAL_SKIPPED"
echo

# --------------------------------------------------------------------------------------------
# COMPUTE + CROSS-CHECK
# --------------------------------------------------------------------------------------------
echo "== computing selectors and topic0s with cast =="
declare -A SEEN_SIG=()
declare -A SEEN_VAL=()
declare -A SEEN_SRC=()
n_dup=0
n_pin=0

while IFS=$'\t' read -r tag kind sig declared src cname lineno shape; do
  [ "$tag" = "PIN" ] || continue
  name="${sig%%(*}"

  if [ "$kind" = "selector" ]; then
    computed="$(cast sig "$sig")"
  else
    computed="$(cast keccak "$sig")"
  fi
  computed="$(printf '%s' "$computed" | tr 'A-F' 'a-f')"

  # The interface file's own const is the CROSS-CHECK; the computed value is what is written.
  if [ "$computed" != "$declared" ]; then
    {
      echo "FATAL: computed value disagrees with the declared const"
      echo "  source     : $src:$lineno  ($cname, shape=$shape)"
      echo "  signature  : $sig"
      echo "  declared   : $declared"
      echo "  computed   : $computed"
      echo "  Either the parser truncated the signature or the interface file is wrong."
      echo "  Both are findings. Do not resolve this by preferring one side."
    } >&2
    exit 1
  fi

  if [ -n "${SEEN_SIG[$name]+x}" ]; then
    # the same name declared in two files -- accept ONLY if both sides agree exactly
    if [ "${SEEN_SIG[$name]}" != "$sig" ] || [ "${SEEN_VAL[$name]}" != "$computed" ]; then
      {
        echo "FATAL: $name declared twice with DIFFERENT content"
        echo "  first : ${SEEN_SRC[$name]}  ${SEEN_SIG[$name]}  ${SEEN_VAL[$name]}"
        echo "  second: $src  $sig  $computed"
      } >&2
      exit 1
    fi
    n_dup=$((n_dup + 1))
    printf '   dup-agree  %-28s %s == %s\n' "$name" "$src" "${SEEN_SRC[$name]}"
    continue
  fi
  SEEN_SIG[$name]="$sig"; SEEN_VAL[$name]="$computed"; SEEN_SRC[$name]="$src"
  n_pin=$((n_pin + 1))

  if [ "$kind" = "selector" ]; then
    jq -nc --arg k "$name" --arg s "$sig" --arg v "$computed" --arg f "$src" \
      '{key:$k, entry:{signature:$s, selector:$v, source:$f}}' >> "$SELS"
  else
    jq -nc --arg k "$name" --arg s "$sig" --arg v "$computed" --arg f "$src" \
      '{key:$k, entry:{signature:$s, topic0:$v, source:$f}}' >> "$TOPS"
  fi
  printf '   ok         %-28s %s\n' "$name" "$sig"
done < "$PARSED"

echo "   $n_pin unique pins, $n_dup duplicate declarations cross-file (all agreed)"

# --- THE FLOOR. Nothing below may run on an empty parse. --------------------
n_sel=$(grep -c . "$SELS" || true)
n_top=$(grep -c . "$TOPS" || true)
if [ "$n_pin" -lt "$MIN_PINS" ] || [ "$n_sel" -lt "$MIN_SELECTORS" ] || [ "$n_top" -lt "$MIN_TOPICS" ]; then
  {
    echo "FATAL: the parser produced too few pins to be a real parse."
    echo "  got      : $n_pin pins ($n_sel selectors, $n_top topics)"
    echo "  floor    : $MIN_PINS pins ($MIN_SELECTORS selectors, $MIN_TOPICS topics)"
    echo "  $OUT was NOT touched."
    echo
    echo "  This is what a DRIFTED const syntax looks like. The parser anchors on"
    echo "    ^[ \\t]*const[ \\t]+NAME[ \\t]*="
    echo "  so a type annotation (\`const bytes4 NAME =\`), a keyword rename, or a"
    echo "  moved declaration matches nothing -- and every awk still exits 0. Without"
    echo "  this floor the run ended '0 unique pins' and OVERWROTE the tracked pin file"
    echo "  with empty maps."
    echo
    echo "  If a pin was REMOVED on purpose, lower MIN_SELECTORS/MIN_TOPICS at the top"
    echo "  of this script in the same commit. Do not delete the floor."
  } >&2
  exit 1
fi
echo

# --------------------------------------------------------------------------------------------
# RETIRED VALUES -- parsed from the files that carry them, never typed.
#
# Truncated values (a hex prefix followed by an ellipsis) are REJECTED, because expanding one
# from memory is exactly the re-typing this file forbids. The v1 E1 topic0 appears truncated in
# VolOrderManagerInterface.plk but VERBATIM AND COMPLETE in the imported notes/DATA_CONTRACT.md,
# so it is parsed from there.
#
# Each row is: key | file | a NON-HEX textual anchor on the defining line | expected hex digits
# --------------------------------------------------------------------------------------------
RETIRED_SPECS=(
  "create_order_v1|src/interfaces/pos_spec/VolOrderManagerInterface.plk|RETIRED-NEVER-LIVE (nothing was deployed)|8"
  "topic_vol_order_created_v1|$DATA_CONTRACT|superseded by v2 before any deployment|64"
  "topic_order_created_stale|$STALE_TOPIC_SRC|TOPIC_ORDER_CREATED =|8"
)

# drop truncated tokens BEFORE extracting, so a prefix can never be mistaken for a value
strip_truncated() { sed -E 's/0x[0-9a-fA-F]+(\.\.\.|…)/TRUNCATED-VALUE-NOT-USABLE/g'; }

echo "== parsing retired values =="
RETIRED_VALUES=""
RETIRED_PAIRS=()          # "key|file|value", for the reverse-direction sweep assertion below
for spec in "${RETIRED_SPECS[@]}"; do
  IFS='|' read -r rkey rfile ranchor rlen <<< "$spec"
  hits="$(grep -F -- "$ranchor" "$rfile" | strip_truncated | grep -oE '0x[0-9a-fA-F]+' \
          | tr 'A-F' 'a-f' | awk -v w="$rlen" 'length($0) == w + 2' | sort -u || true)"
  count="$(printf '%s' "$hits" | grep -c . || true)"
  if [ "$count" != "1" ]; then
    echo "FATAL: retired '$rkey' matched $count values in $rfile (anchor: $ranchor)" >&2
    exit 1
  fi
  jq -nc --arg k "$rkey" --arg v "$hits" '{key:$k, value:$v}' >> "$RETS"
  RETIRED_VALUES="$RETIRED_VALUES $hits"
  RETIRED_PAIRS+=("$rkey|$rfile|$hits")
  printf '   retired    %-28s %s  (%s)\n' "$rkey" "$hits" "$rfile"
done

# SWEEP: every FULL value on a RETIRED line in the scanned files must be covered above, so a
# newly retired value cannot be silently dropped by this generator.
#
# IT USED TO PASS ON ZERO MATCHES, and worse, on a PARTIAL loss. `cat ... | grep 'RETIRED' >
# "$SWEEP_SRC" || true` swallowed both a grep no-match and a genuine `cat` failure under
# pipefail, and the loop that follows is vacuous over an empty file: zero iterations, zero
# complaints, exit 0, tracked pin file replaced. Every other parse in this script has a floor;
# the sweep -- the check that exists so a retired value cannot be silently dropped -- had none.
#
# MEASURED. A `cat` shim recasing "**RETIRED-NEVER-LIVE**" to "**Retired-never-live**" on the
# E1 (v1) row of notes/DATA_CONTRACT.md (another track's file, simulated rather than edited;
# the per-key `grep -F` anchor "superseded by v2 before any deployment" is untouched by the
# recase, so the per-key parse still succeeds exactly as it would under the real drift):
#   BEFORE: "covered 0x6501fe94" ONLY -- the 64-digit E1 topic0 silently left the sweep --
#           exit 0, rig-pins.json replaced.
#
# THE FIX IS A SET IDENTITY, NOT A FLOOR. A floor of "at least 2 covered values" would pass a
# count-preserving swap: one line loses its marker while another gains a spurious one carrying
# a value the retired block also holds. So the sweep is asserted in BOTH directions:
#   forward (this loop)  : every value the sweep FINDS is in the retired block;
#   reverse (below)      : every retired value whose SOURCE FILE is in the scan set is FOUND
#                          by the sweep.
# The reverse side is derived from RETIRED_SPECS and SWEEP_SCAN, never typed -- adding a
# retired value needs no edit here, and losing one from the sweep is a named FATAL.
#
# NOTE ON THE PRESCRIPTION THIS FIXES: it said "a marker rename yields 0 lines and exit 0".
# The zero-line case is NOT reachable by a marker rename, because create_order_v1's own anchor
# CONTAINS the string RETIRED-NEVER-LIVE -- rename it and the per-key parse FATALs first. What
# is reachable by a rename is the PARTIAL loss measured above; the zero-line case is reachable
# when `cat` itself fails, which the `|| true` also swallowed. Both are closed here.
echo "   -- sweep: RETIRED lines across the interface files + $DATA_CONTRACT --"
SWEEP_SCAN=("${IFACES[@]}" "$DATA_CONTRACT")
SWEEP_ALL="$TMP/sweep-all.txt"
SWEEP_SRC="$TMP/retired-lines.txt"
if ! cat "${SWEEP_SCAN[@]}" > "$SWEEP_ALL"; then
  echo "FATAL: could not read the retired-sweep sources:" >&2
  printf '       %s\n' "${SWEEP_SCAN[@]}" >&2
  echo "       This used to be swallowed by '|| true' and reported as 'no RETIRED lines'." >&2
  exit 1
fi
sweep_rc=0
grep 'RETIRED' "$SWEEP_ALL" > "$SWEEP_SRC" || sweep_rc=$?
if [ "$sweep_rc" -gt 1 ]; then
  echo "FATAL: grep failed (exit $sweep_rc) while sweeping for RETIRED lines" >&2
  exit 1
fi
n_sweep_lines="$(grep -c . "$SWEEP_SRC" || true)"
n_trunc="$(grep -coE '0x[0-9a-fA-F]+(\.\.\.|…)' "$SWEEP_SRC" || true)"
sweep_full="$(strip_truncated < "$SWEEP_SRC" | grep -oE '0x[0-9a-fA-F]+' | tr 'A-F' 'a-f' | sort -u || true)"
for v in $sweep_full; do
  hexlen=$(( ${#v} - 2 ))
  if [ "$hexlen" != "8" ] && [ "$hexlen" != "64" ]; then
    echo "FATAL: retired sweep found a value of $hexlen hex digits: $v" >&2
    exit 1
  fi
  case " $RETIRED_VALUES " in
    *" $v "*) printf '   covered    %s\n' "$v" ;;
    *) echo "FATAL: retired value $v is marked RETIRED in a scanned file but is not in the retired block" >&2
       exit 1 ;;
  esac
done

# REVERSE DIRECTION. Scoped to the retired values whose defining file the sweep actually
# scans -- topic_order_created_stale is parsed from $STALE_TOPIC_SRC, which is deliberately
# NOT in SWEEP_SCAN, and demanding it here would be asserting something false.
sweep_flat="$(printf '%s ' $sweep_full)"
for pair in "${RETIRED_PAIRS[@]}"; do
  IFS='|' read -r rkey rfile rval <<< "$pair"
  in_scan=0
  for f in "${SWEEP_SCAN[@]}"; do [ "$f" = "$rfile" ] && in_scan=1; done
  [ "$in_scan" -eq 1 ] || { printf '   out-of-scan %-24s %s  (%s)\n' "$rkey" "$rval" "$rfile"; continue; }
  case " $sweep_flat " in
    *" $rval "*) ;;
    *) {
         echo "FATAL: the RETIRED sweep did not find '$rkey' ($rval)."
         echo "       It is parsed from $rfile, which IS in the sweep's scan set, so its"
         echo "       defining line must still carry the RETIRED marker -- and does not."
         echo "       The sweep matched $n_sweep_lines line(s) and $(printf '%s' "$sweep_full" | grep -c . || true) full value(s)."
         echo "       This is the sweep losing coverage SILENTLY, which is the one failure it"
         echo "       exists to prevent. Either the marker moved (find it: grep -n RETIRED $rfile)"
         echo "       or the value is no longer marked retired -- both are findings."
         echo "       $OUT was NOT replaced."
       } >&2
       exit 1 ;;
  esac
done
echo "   swept $n_sweep_lines RETIRED line(s); truncated (ellipsis) occurrences deliberately EXCLUDED: $n_trunc"
echo

# --------------------------------------------------------------------------------------------
# EMIT
# --------------------------------------------------------------------------------------------
NOTE="retired values must NEVER appear as live constants; this block is data for the plan 20-05 falsifiability test and must never be iterated by a pin check as if it were a live pin"

jq -n \
  --arg generatedFrom "$REF" \
  --arg note "$NOTE" \
  --slurpfile sels "$SELS" \
  --slurpfile tops "$TOPS" \
  --slurpfile rets "$RETS" \
  '{
     generatedFrom: $generatedFrom,
     selectors: ($sels | map({key: .key, value: .entry}) | from_entries),
     topics:    ($tops | map({key: .key, value: .entry}) | from_entries),
     retired:   (($rets | map({key: .key, value: .value}) | from_entries) + {_note: $note})
   }' > "$OUT.tmp"

# Re-check the emitted document before it replaces the tracked one. jq -n can exit 0
# having written less than intended if a --slurpfile input is empty, and that is the
# same silent-empty failure the floor above catches upstream.
emitted_sel=$(jq -r '.selectors | length' "$OUT.tmp")
emitted_top=$(jq -r '.topics    | length' "$OUT.tmp")
if [ "$emitted_sel" -lt "$MIN_SELECTORS" ] || [ "$emitted_top" -lt "$MIN_TOPICS" ]; then
  echo "FATAL: the emitted document carries $emitted_sel selectors and $emitted_top topics," >&2
  echo "       below the floor ($MIN_SELECTORS / $MIN_TOPICS). $OUT was NOT replaced." >&2
  exit 1
fi
mv "$OUT.tmp" "$OUT"

echo "== wrote $OUT =="
jq -r '"   selectors: \(.selectors | length)   topics: \(.topics | length)   retired: \((.retired | length) - 1)   generatedFrom: \(.generatedFrom)"' "$OUT"
