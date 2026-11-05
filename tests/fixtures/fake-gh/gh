#!/usr/bin/env bash
# Stands in for gh in tests/settings.bats. Every call is logged to
# $FAKE_GH_LOG: one line with the method and endpoint, then a BODY line with
# whatever was sent on stdin. Answers come from $FAKE_GH_RESPONSES, in files
# named <METHOD>_<endpoint with / as _>.json, with an optional .status file
# holding an HTTP error code.
set -euo pipefail

log() {
  printf '%s\n' "$*" >>"$FAKE_GH_LOG"
}

case "${1:-}" in
  auth)
    log "auth ${*:2}"
    exit "$(cat "$FAKE_GH_RESPONSES/auth.status" 2>/dev/null || echo 0)"
    ;;
  secret)
    log "secret ${*:2}"
    log "BODY $(cat)"
    exit 0
    ;;
  api) shift ;;
  *)
    echo "fake gh: unsupported command: $*" >&2
    exit 2
    ;;
esac

method=GET endpoint="" input=false filter=""
while (($#)); do
  case "$1" in
    -X | --method)
      method="$2"
      shift 2
      ;;
    --input)
      input=true
      shift 2
      ;;
    -q | --jq)
      filter="$2"
      shift 2
      ;;
    --silent)
      shift
      ;;
    -H)
      shift 2
      ;;
    *)
      endpoint="$1"
      shift
      ;;
  esac
done

log "$method $endpoint"
if [[ "$input" == "true" ]]; then
  log "BODY $(jq -c . </dev/stdin)"
fi

key="${method}_${endpoint//\//_}"
status="$(cat "$FAKE_GH_RESPONSES/$key.status" 2>/dev/null || echo 0)"
out=""
if [[ -f "$FAKE_GH_RESPONSES/$key.json" ]]; then
  out="$(cat "$FAKE_GH_RESPONSES/$key.json")"
fi
if [[ "$status" != "0" ]]; then
  echo "gh: ${out:-request failed} (HTTP $status)" >&2
  exit 1
fi
if [[ -n "$filter" && -n "$out" ]]; then
  jq -r "$filter" <<<"$out"
else
  printf '%s' "$out"
fi
