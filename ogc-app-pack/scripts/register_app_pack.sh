#!/usr/bin/env bash
# Register (or update) an OGC Application Package process with MAAP.
#
# POSTs {"executionUnit": {"href": "<cwl-url>"}} with the MAAP token in a
# `proxy-ticket` header. On HTTP 409 (the process already exists) it re-submits
# as PUT /<processID> -- so registration is an UPSERT that overwrites whatever
# is published under that name. Same behavior as the generator's
# deploy_app_pack.py, without needing its venv.
#
# The token is read from $MAAP_TOKEN or --token-file. It is never echoed, never
# written to disk by this script, and never placed in argv (it goes to curl
# through a mode-600 config file), so it stays out of `ps` and shell history.
#
# Usage:
#   register_app_pack.sh --cwl-url <url> [--endpoint <url>] [--token-file <path>] [--dry-run]
set -uo pipefail

ENDPOINT="https://api.maap-project.org/api/ogc/processes"
CWL_URL=""
TOKEN_FILE=""
DRY_RUN=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --cwl-url)    CWL_URL="$2"; shift 2 ;;
    --endpoint)   ENDPOINT="$2"; shift 2 ;;
    --token-file) TOKEN_FILE="$2"; shift 2 ;;
    --dry-run)    DRY_RUN=1; shift ;;
    -h|--help)    sed -n '2,20p' "$0"; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; exit 2 ;;
  esac
done

if [[ -z "$CWL_URL" ]]; then
  echo "ERROR: --cwl-url is required (a publicly reachable URL to the generated CWL)." >&2
  exit 2
fi

# --- Resolve the token, preferring the environment ---------------------------
TOKEN=""
TOKEN_SOURCE=""
if [[ -n "$TOKEN_FILE" ]]; then
  if [[ ! -f "$TOKEN_FILE" ]]; then
    echo "ERROR: token file not found: $TOKEN_FILE" >&2
    exit 1
  fi
  TOKEN="$(tr -d '[:space:]' < "$TOKEN_FILE")"
  TOKEN_SOURCE="--token-file $TOKEN_FILE"
elif [[ -n "${MAAP_TOKEN:-}" ]]; then
  TOKEN="$MAAP_TOKEN"
  TOKEN_SOURCE="\$MAAP_TOKEN"
fi

if [[ -z "$TOKEN" ]]; then
  cat >&2 <<'MSG'
ERROR: no MAAP token available.

  $MAAP_TOKEN is unset or empty and no --token-file was given.

  Either export it in the shell that runs this script:
      export MAAP_TOKEN='<token>'
  or put it in a file readable only by you and pass --token-file:
      printf '%s' '<token>' > ~/.maap_token && chmod 600 ~/.maap_token
MSG
  exit 1
fi

# --- Pre-flight: MAAP fetches the CWL itself, so it must be publicly reachable
echo "Checking that the CWL URL is publicly reachable ..."
HTTP_CODE="$(curl -sS -L -o /dev/null -w '%{http_code}' "$CWL_URL" 2>/dev/null)"
if [[ "$HTTP_CODE" != "200" ]]; then
  echo "ERROR: GET $CWL_URL returned HTTP $HTTP_CODE (anonymously)." >&2
  echo "MAAP fetches this URL server-side, so it must resolve without credentials." >&2
  echo "Commit and push the CWL, then use its raw URL pinned to a commit SHA." >&2
  exit 1
fi
echo "  HTTP 200 -- reachable."

BODY="$(printf '{"executionUnit": {"href": "%s"}}' "$CWL_URL")"

echo
echo "Endpoint : $ENDPOINT"
echo "CWL URL  : $CWL_URL"
echo "Body     : $BODY"
echo "Token    : ${#TOKEN} chars from $TOKEN_SOURCE (not printed)"

if [[ $DRY_RUN -eq 1 ]]; then
  echo
  echo "--dry-run: nothing submitted."
  exit 0
fi

# --- Keep the token out of argv: curl reads the header from a 600 config file -
CURL_CFG="$(mktemp)"
chmod 600 "$CURL_CFG"
trap 'rm -f "$CURL_CFG"' EXIT
{
  printf 'header = "proxy-ticket: %s"\n' "$TOKEN"
  printf 'header = "Content-Type: application/json"\n'
} > "$CURL_CFG"

submit() {  # $1 = method, $2 = url; prints "<body>\n<status>"
  curl -sS -K "$CURL_CFG" -X "$1" -d "$BODY" -w '\n%{http_code}' "$2"
}

echo
echo "== POST $ENDPOINT =="
RESPONSE="$(submit POST "$ENDPOINT")"
STATUS="$(printf '%s' "$RESPONSE" | tail -n1)"
PAYLOAD="$(printf '%s' "$RESPONSE" | sed '$d')"
echo "$PAYLOAD"
echo "HTTP $STATUS"

if [[ "$STATUS" == "409" ]]; then
  echo
  echo "409 Conflict -- the process already exists. Re-submitting as PUT (overwrites it)."
  PROCESS_ID="$(printf '%s' "$PAYLOAD" | python3 -c \
    'import json,sys; print(json.load(sys.stdin).get("additionalProperties",{}).get("processID",""))' 2>/dev/null)"
  if [[ -z "$PROCESS_ID" ]]; then
    echo "ERROR: response had no additionalProperties.processID; cannot build the PUT URL." >&2
    exit 1
  fi
  echo "== PUT $ENDPOINT/$PROCESS_ID =="
  RESPONSE="$(submit PUT "$ENDPOINT/$PROCESS_ID")"
  STATUS="$(printf '%s' "$RESPONSE" | tail -n1)"
  PAYLOAD="$(printf '%s' "$RESPONSE" | sed '$d')"
  echo "$PAYLOAD"
  echo "HTTP $STATUS"
fi

case "$STATUS" in
  2*)
    PIPELINE="$(printf '%s' "$PAYLOAD" | python3 -c \
      'import json,sys; print(json.load(sys.stdin).get("processPipelineLink",{}).get("href",""))' 2>/dev/null)"
    echo
    echo "Registered."
    [[ -n "$PIPELINE" ]] && echo "Deployment status: $PIPELINE"
    exit 0 ;;
  401|403)
    echo >&2
    echo "ERROR: HTTP $STATUS -- the token was rejected. It may be expired, or issued for a" >&2
    echo "different MAAP environment than $ENDPOINT." >&2
    exit 1 ;;
  *)
    echo >&2
    echo "ERROR: registration failed with HTTP $STATUS. See the response body above." >&2
    exit 1 ;;
esac
