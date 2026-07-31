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
# Re-running is idempotent: `git diff --exit-code offchain/rig/rig-pins.json` stays clean.
#
set -euo pipefail

cd "$(dirname "$0")/../.."
ROOT="$PWD"

OUT="offchain/rig/rig-pins.json"
REF_FILE="offchain/rig/import-ref.txt"
DECODE_HS="offchain/lib/VolOrder/Decode.hs"
DATA_CONTRACT="notes/DATA_CONTRACT.md"

IFACES=(
  "src/interfaces/pos_spec/VolOrderManagerInterface.plk"
  "src/interfaces/market_state_measurements/RealizedVolatilityInterface.plk"
  "src/interfaces/premium/DynamicFeeInterface.plk"
  "src/interfaces/protocol_integrations/DynamicFeeHookInterface.plk"
  "src/interfaces/protocol_integrations/IMarketStateSocket.plk"
  "src/interfaces/exposure/VegaAccountInterface.plk"
)

for f in "${IFACES[@]}" "$REF_FILE" "$DECODE_HS" "$DATA_CONTRACT"; do
  [ -f "$f" ] || { echo "FATAL: missing input $ROOT/$f" >&2; exit 1; }
done
command -v cast >/dev/null || { echo "FATAL: cast (foundry) not on PATH" >&2; exit 1; }
command -v jq   >/dev/null || { echo "FATAL: jq not on PATH" >&2; exit 1; }

REF="$(tr -d ' \t\n\r' < "$REF_FILE")"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
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
  "topic_order_created_stale|$DECODE_HS|topic_order_created =|8"
)

# drop truncated tokens BEFORE extracting, so a prefix can never be mistaken for a value
strip_truncated() { sed -E 's/0x[0-9a-fA-F]+(\.\.\.|…)/TRUNCATED-VALUE-NOT-USABLE/g'; }

echo "== parsing retired values =="
RETIRED_VALUES=""
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
  printf '   retired    %-28s %s  (%s)\n' "$rkey" "$hits" "$rfile"
done

# SWEEP: every FULL value on a RETIRED line in the scanned files must be covered above, so a
# newly retired value cannot be silently dropped by this generator.
echo "   -- sweep: RETIRED lines across the interface files + $DATA_CONTRACT --"
SWEEP_SRC="$TMP/retired-lines.txt"
cat "${IFACES[@]}" "$DATA_CONTRACT" | grep 'RETIRED' > "$SWEEP_SRC" || true
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
echo "   truncated (ellipsis) occurrences deliberately EXCLUDED: $n_trunc"
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
   }' > "$OUT"

echo "== wrote $OUT =="
jq -r '"   selectors: \(.selectors | length)   topics: \(.topics | length)   retired: \((.retired | length) - 1)   generatedFrom: \(.generatedFrom)"' "$OUT"
