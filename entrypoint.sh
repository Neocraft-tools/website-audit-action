#!/usr/bin/env bash
# Website audit (SEO, AI-search visibility/GEO, security, speed, accessibility) with quality gates.
set -euo pipefail
. "$(dirname "$0")/apify.sh"
check_prereqs

URLS="$(split_list "${INPUT_URL:-}")"
[ "$(jq length <<<"$URLS")" -gt 0 ] || fail "Input 'url' is required (one URL, or several separated by commas/new lines)"
MAX_PAGES="${INPUT_MAX_PAGES:-10}"
MONITOR_ID="${INPUT_MONITOR_ID:-}"
[ -z "$MONITOR_ID" ] && MONITOR_ID="$(printf '%s' "${GITHUB_REPOSITORY:-github-action}" | tr -c 'A-Za-z0-9._\n-' '-')"

BASE="$(jq -c -n --argjson urls "$URLS" --argjson pages "$MAX_PAGES" \
  --arg lang "${INPUT_LANGUAGE:-en}" --argjson psi "$(bool "${INPUT_PAGESPEED:-}" false)" \
  --arg mid "$MONITOR_ID" \
  '{startUrls: ($urls | map({url: .})), maxPagesPerSite: $pages, language: $lang,
    pagespeed: $psi, pageRecords: false, compareWithPrevious: true, monitorId: $mid}')"
INPUT="$(merge_extra "$BASE" "${INPUT_EXTRA_INPUT:-}")"

N="$(jq length <<<"$URLS")"
CAP="${INPUT_MAX_TOTAL_CHARGE_USD:-}"
if [ -z "$CAP" ] || [ "$CAP" = "auto" ]; then
  # $0.49 per site (10 pages included) + $0.01 per extra page, + a small margin
  CAP="$(awk -v n="$N" -v p="$MAX_PAGES" 'BEGIN{e=(p>10?p-10:0); printf "%.2f", n*(0.49+0.01*e)+0.05}')"
fi
OUT="${INPUT_OUTPUT_FILE:-website-audit.json}"
apify_run "neocraft~website-audit-all-in-one" "$INPUT" "$CAP" "${INPUT_TIMEOUT_SECS:-1200}" "$OUT"

MIN="${INPUT_MIN_SCORE:-0}"; DROP="${INPUT_MAX_SCORE_DROP:-0}"; FAILCRIT="$(bool "${INPUT_FAIL_ON_CRITICAL:-}" true)"
SITES="$(jq -c '[.[] | select((.type // "site") == "site" and (.summary.score != null))]' "$OUT")"
NS="$(jq length <<<"$SITES")"

{
  echo "## Website audit"
  echo
  echo "| Site | Score | Critical | High | Change vs previous audit |"
  echo "|---|---:|---:|---:|---:|"
  jq -r '.[] | "| \(.finalUrl // .domain) | **\(.summary.score)**/100 | \(.summary.critical // 0) | \(.summary.high // 0) | \(if .changes.scoreDelta == null then "first audit" else (.changes.scoreDelta | tostring) end) |"' <<<"$SITES"
  echo
  echo "Gates: min score ${MIN} · fail on critical ${FAILCRIT} · max score drop ${DROP}"
  if [ "$NS" -gt 0 ]; then
    echo
    echo "### Top priorities"
    jq -r '.[] | "**\(.domain)**", ((.topPriorities // [])[:5][] | "- [\(.severity // "info")] \(.title // .id)\(if .firstStep then ": " + .firstStep else "" end)"), ""' <<<"$SITES"
  fi
} | summary
footer "$CAP"

[ "$NS" -gt 0 ] || fail "The audit returned no site result (status ${RUN_STATUS}). See ${RUN_URL}"

SCORE="$(jq '[.[].summary.score] | min' <<<"$SITES")"
CRIT="$(jq '[.[].summary.critical // 0] | add' <<<"$SITES")"
DELTA="$(jq '[.[].changes.scoreDelta // 0] | min' <<<"$SITES")"
set_output score "$SCORE"
set_output critical "$CRIT"
set_output score-delta "$DELTA"
set_output summary "$(jq -c 'map({site: (.finalUrl // .domain), score: .summary.score, critical: (.summary.critical // 0), scoreDelta: .changes.scoreDelta})' <<<"$SITES")"

REASONS=()
[ "$MIN" != "0" ] && [ "$SCORE" -lt "$MIN" ] && REASONS+=("score ${SCORE} < ${MIN}")
[ "$FAILCRIT" = "true" ] && [ "$CRIT" -gt 0 ] && REASONS+=("${CRIT} critical issue(s)")
[ "$DROP" != "0" ] && [ "$DELTA" -le "-${DROP}" ] && REASONS+=("score dropped by ${DELTA#-} points")
if [ "${#REASONS[@]}" -gt 0 ]; then
  set_output passed false
  echo "::error::Website audit gate failed: $(IFS='; '; echo "${REASONS[*]}")"
  exit 1
fi
set_output passed true
echo "Website audit passed (lowest score ${SCORE}, critical ${CRIT}, delta ${DELTA})"
